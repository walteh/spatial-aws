//
//  WebSessionNew.swift
//  SpatialAWS
//
//  Created by walter on 5/30/24.
//

import Combine
import Foundation
import WebKit
import XDK
import XDKAWSSSO

func createWebView() async -> WKWebView {
	let webViewConfig = WKWebViewConfiguration()
	webViewConfig.websiteDataStore = WKWebsiteDataStore.nonPersistent()
	let webView = await WKWebView(frame: .zero, configuration: webViewConfig)
	return webView
}

@MainActor
public class WebSessionInstance: NSObject, ObservableObject {
	public var currentURL: URL? = nil

	//	public let session: AWSSSOUserSession
	public let account: AccountInfo
	public let webview: WKWebView
	public let parent: WebSessionManager
	//	public let storage: XDK.StorageAPI

	public var isLoggedIn: Bool = false

	public func rebuildURL() async {
		var err: Error? = nil

		guard let url = await parent.regenerate(account: account, isLoggedIn: isLoggedIn).to(&err) else {
			XDK.Log(.error).err(err).send("error generating console url")
			return
		}

		self.isLoggedIn = true

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
public class WebSessionManager: ObservableObject, ManagedRegionService {
	public var accessTokenPublisher: Published<SecureAWSSSOAccessToken?>.Publisher { self.$accessToken }

	@Published public var accessToken: SecureAWSSSOAccessToken? = nil
	@Published public var accountsList: AccountInfoList = .init(accounts: [])

	@Published public var accounts: [AccountInfo: WebSessionInstance] = [:]
	@Published public var role: RoleInfo? = nil

	init(accounts: AccountInfoList, storage: StorageAPI) async {
		self.accountsList = accounts
		self.storageAPI = storage

		//		super.init()

		//		self.accounts = [:]

		var working: [AccountInfo: WebSessionInstance] = [:]
		for account in accounts {
			let viewer = await WebSessionInstance(webview: createWebView(), account: account, parent: self)
			working[account] = viewer
		}

		self.accounts = working

		self.role = accounts.accounts.first?.roles.first
	}

	public func regenerate(account: AccountInfo, isLoggedIn: Bool) async -> Result<URL, Error> {
		let tkn = self.accessToken!
		return
			await XDKAWSSSO.generateAWSConsoleURLWithDefaultClient(
				account: account,
				role: account.roles.first!,
				managedRegion: self,
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

	//	public func currentManagedRegion() -> ManagedRegionService {
	//		return self
	//	}

	let storageAPI: any XDK.StorageAPI

	@Published public var currentAccount: AccountInfo? = nil
	//	@Published public var currentWebview:

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
		return self.accounts[self.currentAccountOrFirst]?.webview
		//        if let currentAccount {
		//            if let wk = accounts[currentAccount] {
		//                return wk.webview
		//            } else {
//
		//                return viewer.webview
		//            }
		//        }
		//        let wv = createWebView()
		//        // load google.com
		//        wv.load(URLRequest(url: URL(string: "https://www.google.com")!))
		//        return wv
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

		// guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
		// 	return .failure(x.error("error updating sso client", root: err))
		// }

		// guard let ssooidcClient = Result.X({ try AWSSSOOIDC.SSOOIDCClient(region: accessToken.region) }).to(&err) else {
		// 	return .failure(x.error("error updating ssooidc client", root: err))
		// }
		self.accessToken = accessToken
		self.accountsList = accounts
		//        DispatchQueue.main.async {
//
		//            //			self.ssooidcClient = ssooidcClient
		//        }

		return .success(())
	}

	// 	public func initialize(accessToken: SecureAWSSSOAccessToken?, storageAPI: XDK.StorageAPI)  -> Result<Void, Error> {
	// 	var err: Error? = nil

	// 	guard let accessToken = accessToken ?? self.accessToken else {
	// 		return .failure(x.error("accessToken not set"))
	// 	}

	// 	guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
	// 		return .failure(x.error("error updating sso client", root: err))
	// 	}

	// 	guard let ssooidcClient = Result.X({ try AWSSSOOIDC.SSOOIDCClient(region: accessToken.region) }).to(&err) else {
	// 		return .failure(x.error("error updating ssooidc client", root: err))
	// 	}

	// 	DispatchQueue.main.async {
	// 		self.accessToken = accessToken
	// 		self.ssoClient = client
	// 		self.ssooidcClient = ssooidcClient
	// 		self.accountsList = accounts
	// 	}

	// 	return .success(())
	// }

	// private func buildSSOClient(accessToken: SecureAWSSSOAccessToken) async -> Result<AWSSSO.SSOClient, Error> {
	// 	var err: Error? = nil

	// 	guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
	// 		return .failure(x.error("error creating client", root: err))
	// 	}

	// 	return .success(client)
	// }

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
}
