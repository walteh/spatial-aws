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

func createWebView() -> WKWebView {
	let webViewConfig = WKWebViewConfiguration()
	webViewConfig.websiteDataStore = WKWebsiteDataStore.nonPersistent()
	let webView = WKWebView(frame: .zero, configuration: webViewConfig)
	return webView
}

public class WebSessionInstance: NSObject, ObservableObject, WKNavigationDelegate {
	public var currentURL: URL? = nil

//	public let session: AWSSSOUserSession
	public let account: AccountInfo
	public let webview: WKWebView
//	public let storage: XDK.StorageAPI
	
	public let regenerateFunc: (_ account: AccountInfo, _ isLoggedIn: Bool) async -> Result<URL, Error>

	public var isLoggedIn: Bool = false

	public func rebuildURL() async {
		var err: Error? = nil

		guard let url = await regenerateFunc(self.account, self.isLoggedIn).to(&err) else {
			XDK.Log(.error).err(err).send("error generating console url")
			return
		}

		self.isLoggedIn = true

//		guard let _ = session.configureCookies(accessToken: session.accessToken!, webview: webview).to(&err) else {
//			XDK.Log(.error).err(err).send("error configuring cookies")
//			return
//		}

		guard let _ = await webview.load(URLRequest(url: url)) else {
			XDK.Log(.error).send("error loading webview")
			return
		}
	}

	public init(webview: WKWebView, account: AccountInfo, regenerateFunc: @escaping (_ account: AccountInfo, _ isLoggedIn: Bool) async -> Result<URL, Error> ) {
		self.webview = webview
		self.regenerateFunc = regenerateFunc
//		self.session = session
		self.account = account
//		self.storage = storage

		super.init()

		self.webview.navigationDelegate = self

		Task {
			XDK.Log(.info).info("rebuilding", "url").send("rebuilding")
			await self.rebuildURL()
		}
	}

	// when the webview starts up
	public func webView(_ webview: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
		XDK.Log(.info).info("url", webview.url).send("webview navigation start")
	}

	public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
		XDK.Log(.info).info("url", self.webview.url).send("webview navigation navigation")

		self.currentURL = webView.url
	}

	public func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
		XDK.Log(.error).err(error).send("webview navigation error")

		// constructSimpleConsoleURL(region: session.region ?? session.accessToken?.region ?? "us-east-1", service: session.service)
	}
}

public class WebSessionManager: ObservableObject, XDKAWSSSO.ManagedRegionService {
	public var accessTokenPublisher: Published<SecureAWSSSOAccessToken?>.Publisher { self.$accessToken }
	
	@Published public var accessToken: SecureAWSSSOAccessToken? = nil
	@Published public var accountsList: AccountInfoList = .init(accounts: [])

	@Published public var accounts: [AccountInfo: WebSessionInstance] = [:]

	@Published public var region: String? {
		didSet {
			if oldValue != region {
				DispatchQueue.main.async {
					for (_, viewer) in self.accounts {
						Task {
							XDK.Log(.info).info("rebuilding", "region").send("rebuilding")
							await viewer.rebuildURL()
						}
					}
				}
			}
		}
	}

	@Published public var service: String? = nil {
		didSet {
			if oldValue != service {
				DispatchQueue.main.async {
					for (_, viewer) in self.accounts {
						Task {
							XDK.Log(.info).info("rebuilding", "service").send("rebuilding")
							await viewer.rebuildURL()
						}
					}
				}
			}
		}
	}

	let storageAPI: any XDK.StorageAPI

	@Published public var currentAccount: AccountInfo? = nil
	
	
	public func currentWebview() -> WKWebView {
		if let currentAccount {
			if let wk = self.accounts[currentAccount] {
				return wk.webview
			} else {
				let viewer = WebSessionInstance(webview: createWebView(), account: currentAccount) { account, isLoggedIn in
					await XDKAWSSSO.generateAWSConsoleURLWithDefaultClient(
						account: account,
						managedRegion: self,
						storageAPI: self.storageAPI,
						accessToken: self.accessToken!,
						isSignedIn: isLoggedIn
					)
				}
				DispatchQueue.main.async {
					self.accounts[currentAccount] = viewer
				}
				return viewer.webview
			}
		}
		let wv = createWebView()
		// load google.com
		wv.load(URLRequest(url: URL(string: "https://www.google.com")!))
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

		// guard let client = Result.X({ try AWSSSO.SSOClient(region: accessToken.region) }).to(&err) else {
		// 	return .failure(x.error("error updating sso client", root: err))
		// }

		// guard let ssooidcClient = Result.X({ try AWSSSOOIDC.SSOOIDCClient(region: accessToken.region) }).to(&err) else {
		// 	return .failure(x.error("error updating ssooidc client", root: err))
		// }

		DispatchQueue.main.async {
			self.accessToken = accessToken
			self.accountsList = accounts
//			self.ssooidcClient = ssooidcClient
		}

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
}
