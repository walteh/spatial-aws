//
//  WebSession.swift
//  SpatialAWS
//
//  Created by walter on 5/30/24.
//

import Combine
import Foundation
import WebKit
import XDK
import XDKAWSSSO

@MainActor
func createWebView() -> WKWebView {
	let webViewConfig = WKWebViewConfiguration()
	webViewConfig.websiteDataStore = WKWebsiteDataStore.nonPersistent()
	let webView = WKWebView(frame: .zero, configuration: webViewConfig)

	let userScript: WKUserScript = .init(
		source:
		"""
		(function injectWebkitAppRegionStyle(){
		const styleEle = document.createElement('style');
		styleEle.type = 'text/css';
		styleEle.innerHTML = 'div#h { display: none; }';
		document.head.appendChild(styleEle);
		})();
		""",
		injectionTime: WKUserScriptInjectionTime.atDocumentEnd,
		forMainFrameOnly: false
	)

	webView.configuration.userContentController.addUserScript(userScript)

	return webView
}

@MainActor
public class WebSessionInstance: NSObject, ObservableObject {
	public var currentURL: URL? = nil

	public let account: AccountInfo
	public let role: RoleInfo
	public let service: String
	public let region: String

	public let webview: WKWebView
	public let parent: WebSessionManager
	@Published public var expiry: Date? = nil
	public var isLoggedIn: Bool = false
	
	public var expiryPublisher: Published<Date?>.Publisher { self.$expiry }


	public func rebuildURL() async {
		var err: Error? = nil

		guard let (url, exp) = await regenerate(appSession: parent.appSession, account: account, role: role, isLoggedIn: self.isLoggedIn).to(&err) else {
			XDK.Log(.error).err(err).send("error generating console url")
			return
		}

		self.isLoggedIn = true
		self.expiry = exp

		guard let _ = webview.load(URLRequest(url: url)) else {
			XDK.Log(.error).send("error loading webview")
			return
		}
	}

	public func regenerate(appSession: AppSessionAPI, account: AccountInfo, role: RoleInfo, isLoggedIn: Bool) async -> Result<(URL, Date), Error> {
		var err: Error? = nil

		guard let res = XDKAWSSSO.getSignedInSSOUserFromKeychain(session: appSession, storage: self.parent.storageAPI).to(&err) else {
			return .failure(x.error("getting access token", root: err))
		}

		guard let accessToken = res else {
			return .failure(x.error("access token not set"))
		}

		return
			await XDKAWSSSO.generateAWSConsoleURLWithExpiryWithDefaultClient(
				account: account,
				role: role,
				managedRegion: SimpleManagedRegionService(region: self.region, service: self.service == "console-home" ? "" : self.service),
				storageAPI: self.parent.storageAPI,
				accessToken: accessToken,
				isSignedIn: isLoggedIn
			)
	}

	public init(webview: WKWebView, account: AccountInfo, role: RoleInfo, parent: WebSessionManager, service: String, region: String) {
		self.webview = webview
		self.parent = parent
		self.account = account
		self.role = role
		self.region = region
		self.service = service
		super.init()

		webview.navigationDelegate = self

		Task {
			XDK.Log(.info).info("rebuilding", "url").send("rebuilding")
			await self.rebuildURL()
		}
	}
}

extension WebSessionInstance: WKNavigationDelegate {
	public nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
		Task { @MainActor in
			XDK.Log(.info).info("url", webView.url).send("webview navigation start")
		}
	}

	public nonisolated func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
		Task { @MainActor in
			XDK.Log(.info).info("url", webView.url).send("webview navigation navigation")
			self.currentURL = webView.url
		}
	}

	public nonisolated func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
		XDK.Log(.error).err(error).send("webview navigation error")
	}

	public nonisolated func webView(_ webView: WKWebView, decidePolicyFor _: WKNavigationResponse) async -> WKNavigationResponsePolicy {
		Task { @MainActor in
			XDK.Log(.info).add("url", webView.url).send("webView decideNavicagtionPOclidy")
		}
		return .allow
	}
}

@MainActor
public class WebSessionManager: ObservableObject {
	public var accessTokenPublisher: Published<SecureAWSSSOAccessToken?>.Publisher { self.$accessToken }

	@Published public var accessToken: SecureAWSSSOAccessToken? = nil
	@Published public var accountsList: AccountInfoList = .init(accounts: [])
	@Published public var webSessionInstanceCache: [String: WebSessionInstance] = [:]
	@Published public var lastRoleForAccount: [String: RoleInfo] = [:]

	let storageAPI: any XDK.StorageAPI
	let appSession: any AppSessionAPI
	
	@Published public var roleExpiration: Date? = nil
	@Published public var tokenExpiration: Date? = nil

	@Published public var role: RoleInfo? = nil {
		didSet {
			if let me = role {
				self.lastRoleForAccount[me.accountID] = me
				
				var err: Error? = nil
				
				if let accessToken = accessToken {
					
					
					
					guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: accessToken.stsRegion()).to(&err) else {
						return
					}
					
					Task {
						guard let res = await getRoleCredentialsUsing(sso: awsClient,storage: storageAPI, accessToken: accessToken, role: me).to(&err) else {
							return
						}
						
						roleExpiration = res.data.expiresAt
					}
					
					XDK.Log(.info).info("role updated", self.role).send("okay")
				}
			}
			self.updateCurrentWebSession()
			


		}
		willSet {}
	}

	public func updateCurrentWebSession() {
		if let me = role {
			if let cache = webSessionInstanceCache[uniqueIDFor(role: me)] {
				self.currentWebSession = cache
				self.currentExpiration = cache.expiry
			} else {
				let created = WebSessionInstance(webview: createWebView(), account: currentAccount!, role: me, parent: self, service: service, region: region)
				self.currentWebSession = created
				self.currentExpiration = created.expiry
				self.webSessionInstanceCache[self.uniqueIDFor(role: me)] = created
			}
		}
	}

	@Published public var currentAccount: AccountInfo? = nil {
		didSet {
			if let me = currentAccount {
				self.role = self.lastRoleForAccount[me.accountID] ?? me.roles.first ?? nil
			}
		}
	}

	@Published public var currentWebSession: WebSessionInstance? = nil {
		didSet {
			// refresh here if needed (is expired)
		}
	}

	init(accounts: AccountInfoList, storage: StorageAPI, appSession: AppSessionAPI) {
		self.accountsList = accounts
		self.storageAPI = storage
		self.appSession = appSession
		self.role = accounts.accounts.first?.roles.first
		self.currentAccount = accounts.accounts.first
		self.region = "us-east-1"
		self.service = "console-home"
	}

	@Published public var currentExpiration: Date?

	public func addAccount(account: AccountInfo) {
		for role in account.roles {
			if self.webSessionInstanceCache[self.uniqueIDFor(role: role)] == nil {
				let viewer = WebSessionInstance(webview: createWebView(), account: account, role: role, parent: self, service: "", region: self.accessToken?.stsRegion() ?? "us-east-1")
				self.webSessionInstanceCache[self.uniqueIDFor(role: role)] = viewer
			}
		}
	}

	func uniqueIDFor(role: RoleInfo) -> String {
		return "\(role.uniqueID)_\(self.service)_\(self.region)"
	}

	public func currentAccessToken() -> SecureAWSSSOAccessToken? {
		return self.accessToken
	}

	public func currentStorageAPI() -> StorageAPI {
		return self.storageAPI
	}

	public func currentWebview() -> WKWebView? {
		return self.currentWebSession?.webview
	}

	public func refresh(session: XDK.AppSessionAPI, storageAPI: XDK.StorageAPI, accessToken: AccessToken) async -> Result<Void, Error> {
		var err: Error? = nil

		guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: accessToken.stsRegion()).to(&err) else {
			return .failure(x.error("creating aws client", root: err))
		}

		guard let res = XDKAWSSSO.getSignedInSSOUserFromKeychain(session: session, storage: self.storageAPI).to(&err) else {
			return .failure(x.error("getting access token", root: err))
		}

		guard let accessToken = res else {
			return .failure(x.error("access token not set"))
		}

		guard let accounts = await getAccountsRoleList(client: awsClient, storage: storageAPI, accessToken: accessToken).to(&err) else {
			return .failure(x.error("error updating accounts", root: err))
		}

		self.accessToken = accessToken
		self.accountsList = accounts
		
		self.tokenExpiration = accessToken.expiresAt

		for account in accounts {
			self.addAccount(account: account)
		}

		return .success(())
	}

	func configureCookies(accessToken: SecureAWSSSOAccessToken, webview: WKWebView) -> Result<Void, Error> {
		if let cookie = HTTPCookie(properties: [
			.domain: "aws.amazon.com",
			.path: "/",
			.name: "AWSALB", // Adjust the name based on the actual cookie name required by AWS
			.value: accessToken.accessToken,
			.secure: true,
			.expires: accessToken.expiresAt,
		]) {
			DispatchQueue.main.async {
				webview.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
			}
			return .success(())
		} else {
			return .failure(x.error("error creating cookie"))
		}
	}

	@Published public var region: String {
		didSet {
			if oldValue != self.region {
				self.updateCurrentWebSession()
			}
		}
	}

	@Published public var service: String {
		didSet {
			if oldValue != self.service {
				self.updateCurrentWebSession()
			}
		}
	}

	let services = XDKAWSSSO.loadTheServices()

	func managedRegionService() -> ManagedRegionService {
		return SimpleManagedRegionService(region: self.region, service: self.service)
	}
}
