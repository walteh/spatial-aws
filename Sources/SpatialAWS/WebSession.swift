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

	public let webview: WKWebView
	public let parent: WebSessionManager
	public var lastSuccessfulRole: RoleInfo?
	public var expiry: Date?

	public var isLoggedIn: Bool = false

	public func rebuildURL() async {
		var err: Error? = nil

		guard let (url, expiry) = await parent.regenerate(account: account, isLoggedIn: self.lastSuccessfulRole != nil && self.lastSuccessfulRole == self.parent.role).to(&err) else {
			XDK.Log(.error).err(err).send("error generating console url")
			return
		}

		self.isLoggedIn = true
		self.lastSuccessfulRole = self.parent.role
		self.expiry = expiry
		
		guard let _ = webview.load(URLRequest(url: url)) else {
			XDK.Log(.error).send("error loading webview")
			return
		}
	}

	public init(webview: WKWebView, account: AccountInfo, parent: WebSessionManager) {
		self.webview = webview
		self.parent = parent
		self.account = account

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

	@Published public var accounts: [AccountInfo: WebSessionInstance] = [:]

	@Published public var role: RoleInfo? = nil {
		didSet {
			XDK.Log(.info).info("role updated", self.role).send("okay")
			Task {
				await self.currentWebSession?.rebuildURL()
			}
		}
		willSet {}
	}

	init(accounts: AccountInfoList, storage: StorageAPI) {
		self.accountsList = accounts
		self.storageAPI = storage

		for account in accounts {
			self.addAccount(account: account)
		}

		self.role = accounts.accounts.first?.roles.first
	}

	public func addAccount(account: AccountInfo) {
		if self.accounts[account] != nil {
			return
		}
		let viewer = WebSessionInstance(webview: createWebView(), account: account, parent: self)
		self.accounts[account] = viewer
	}

	public func regenerate(account: AccountInfo, isLoggedIn: Bool) async -> Result<(URL,Date), Error> {
		if self.accessToken == nil {
			return .failure(x.error("oops"))
		}
		let tkn = self.accessToken!
		Log(.info).meta(["account": .string(account.accountName), "role": .string(self.role?.roleName ?? "none")]).send("regenerating")
		return
			await XDKAWSSSO.generateAWSConsoleURLWithExpiryWithDefaultClient(
				account: account,
				role: self.role ?? account.roles.first!,
				managedRegion: self.managedRegionService(),
				storageAPI: self.storageAPI,
				accessToken: tkn,
				isSignedIn: isLoggedIn
			)
	}

	public func currentAccessToken() -> SecureAWSSSOAccessToken? {
		return self.accessToken
	}

	public func currentStorageAPI() -> StorageAPI {
		return self.storageAPI
	}

	let storageAPI: any XDK.StorageAPI

	@Published public var currentAccount: AccountInfo? = nil

	public var currentAccountOrFirst: AccountInfo {
		get {
			if let account = currentAccount {
				return account
			} else {
				return self.accountsList.accounts.first!
			}
		}
		set {
			self.currentAccount = newValue
		}
	}

	public func currentWebview() -> WKWebView? {
		return self.currentWebSession?.webview
	}

	public var currentWebSession: WebSessionInstance? {
		let wv = self.accounts[self.currentAccountOrFirst]
		return wv
	}

	public init(storageAPI: any XDK.StorageAPI, account: AccountInfo? = nil) {
		self.currentAccount = account
		self.storageAPI = storageAPI
	}

	public func refresh(accessToken: SecureAWSSSOAccessToken?, storageAPI: XDK.StorageAPI) async -> Result<Void, Error> {
		var err: Error? = nil

		guard let accessToken = accessToken ?? self.accessToken else {
			return .failure(x.error("accessToken not set"))
		}

		guard let awsClient = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: accessToken.region).to(&err) else {
			return .failure(x.error("creating aws client", root: err))
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
				for (_, viewer) in self.accounts {
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
				for (_, viewer) in self.accounts {
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
