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
	return webView
}

@MainActor
public class WebSessionInstance: NSObject, ObservableObject {
	public var currentURL: URL? = nil

	public let account: AccountInfo
	public let role: RoleInfo
	public let webview: WKWebView
	public let parent: WebSessionManager
	@Published public var expiry: Date? = nil
	public var isLoggedIn: Bool = false

	public func rebuildURL() async {
		var err: Error? = nil

		guard let (url, exp) = await parent.regenerate(appSession: parent.appSession, account: account, role: role, isLoggedIn: self.isLoggedIn).to(&err) else {
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

	public init(webview: WKWebView, account: AccountInfo, role: RoleInfo, parent: WebSessionManager) {
		self.webview = webview
		self.parent = parent
		self.account = account
		self.role = role
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

	@Published public var role: RoleInfo? = nil {
		didSet {
			if let me = role {
				self.lastRoleForAccount[me.accountID] = me
				if let cache = webSessionInstanceCache[me.uniqueID] {
					self.currentWebSession = cache
				}
//				else {
//					self.webSessionInstanceCache[me.uniqueID] = WebSessionInstance(webview: createWebView(), account: currentAccount!, role: me, parent: self)
//					
//				}
//				
			}
			XDK.Log(.info).info("role updated", self.role).send("okay")
//			Task {
//				await self.currentWebSession?.rebuildURL()
//			}
		}
		willSet {}
	}
	
	@Published public var currentAccount: AccountInfo? = nil {
		didSet {
			if let me = currentAccount {
				self.role = self.lastRoleForAccount[me.accountID] ?? me.roles.first ?? nil
//				self.displayExpiry = self.accounts[self.currentAccountOrFirst]?.expiry
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

		for account in accounts {
			self.addAccount(account: account)
		}

		self.role = accounts.accounts.first?.roles.first
	}

	public func addAccount(account: AccountInfo) {
		for role in account.roles {
			if self.webSessionInstanceCache[role.uniqueID] == nil {
				let viewer = WebSessionInstance(webview: createWebView(), account: account, role: role, parent: self)
				self.webSessionInstanceCache[role.uniqueID] = viewer
			}
		}
	}

	public func regenerate(appSession: AppSessionAPI, account: AccountInfo, role: RoleInfo, isLoggedIn: Bool) async -> Result<(URL, Date), Error> {
		var err: Error? = nil
		
		guard let res = XDKAWSSSO.getSignedInSSOUserFromKeychain(session: appSession, storage: self.storageAPI).to(&err) else {
			return .failure(x.error("getting access token", root: err))
		}
		
		guard let accessToken = res else {
			return .failure(x.error("access token not set"))
		}
		
		return
			await XDKAWSSSO.generateAWSConsoleURLWithExpiryWithDefaultClient(
				account: account,
				role: role,
				managedRegion: self.managedRegionService(),
				storageAPI: self.storageAPI,
				accessToken: accessToken,
				isSignedIn: isLoggedIn
			)
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


//	public init(storageAPI: any XDK.StorageAPI, account: AccountInfo? = nil) {
//		self.currentAccount = account
//		self.storageAPI = storageAPI
//	}

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

	@Published public var region: String? {
		didSet {
			if oldValue != self.region {
				//				DispatchQueue.main.async {
				for (_, viewer) in self.webSessionInstanceCache {
					Task {
						XDK.Log(.info).info("rebuilding", "region").send("rebuilding")
						await viewer.rebuildURL()
					}
					//					}
				}
			}
		}
	}

	@Published public var service: String? = nil {
		didSet {
			if oldValue != self.service {
				//                DispatchQueue.main.async {
				for (_, viewer) in self.webSessionInstanceCache {
					Task {
						XDK.Log(.info).info("rebuilding", "service").send("rebuilding")
						await viewer.rebuildURL()
					}
				}
				//                }
			}
		}
	}

	func managedRegionService() -> ManagedRegionService {
		return SimpleManagedRegionService(region: self.region, service: self.service)
	}
}
