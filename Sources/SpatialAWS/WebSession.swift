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

    //	public let session: AWSSSOUserSession
    public let account: AccountInfo
    public let webview: WKWebView
	public let parent: WebSessionManager
    //	public let storage: XDK.StorageAPI


    public var isLoggedIn: Bool = false

    public func rebuildURL() async {
        var err: Error? = nil

		guard let url = await self.parent.regenerate(account: account, isLoggedIn: isLoggedIn).to(&err) else {
            XDK.Log(.error).err(err).send("error generating console url")
            return
        }

        isLoggedIn = true
		

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

	nonisolated public func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
		Task { @MainActor in
			XDK.Log(.info).info("url", webView.url).send("webview navigation start")
		}
	}

	nonisolated public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
		Task { @MainActor in
			XDK.Log(.info).info("url", webView.url).send("webview navigation navigation")
			currentURL = webView.url
		}
	}

	nonisolated public func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
		XDK.Log(.error).err(error).send("webview navigation error")
	}
	
	nonisolated public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
		Task { @MainActor in
			XDK.Log(.info).add("url", webView.url).send("webView decideNavicagtionPOclidy")
		}
		return .allow
	}
}

@MainActor
public class WebSessionManager: ObservableObject, ManagedRegionService {

	
    public var accessTokenPublisher: Published<SecureAWSSSOAccessToken?>.Publisher { $accessToken }

    @Published public var accessToken: SecureAWSSSOAccessToken? = nil
    @Published public var accountsList: AccountInfoList = .init(accounts: [])

    @Published public var accounts: [AccountInfo: WebSessionInstance] = [:]
	@Published public var role: RoleInfo? = nil {
		didSet {
			XDK.Log(.info).info("role updated", role).send("okay")
		}
	}
	
	init(accounts: AccountInfoList, storage: StorageAPI) async {
		self.accountsList = accounts
		self.storageAPI = storage
	
		
		for account in accounts {
			addAccount(account: account)
		}
		
		
		self.role = accounts.accounts.first?.roles.first

	}
	
	public func addAccount(account: AccountInfo) -> Void {
		if accounts[account] != nil {
			return
		}
		let viewer = WebSessionInstance(webview: createWebView(), account: account, parent: self)
		accounts[account] = viewer
	}
	
	public func regenerate(account: AccountInfo, isLoggedIn: Bool) async -> Result<URL, Error> {
		let tkn = self.accessToken!
		Log(.info).meta(["account": .string(account.accountName), "role": .string(account.roles.first!.roleName)]).send("regenerating")
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
		return accessToken
	}
	
	public func currentStorageAPI() -> StorageAPI {
		return storageAPI
	}


    let storageAPI: any XDK.StorageAPI

    @Published public var currentAccount: AccountInfo? = nil

    public var currentAccountOrFirst: AccountInfo {
        get {
            if let account = currentAccount {
                return account
            } else {
                return accountsList.accounts.first!
            }
        }
        set {
            currentAccount = newValue
        }
    }

    public func currentWebview() -> WKWebView? {
		let wv = accounts[currentAccountOrFirst]?.webview
		Log(.info).info("wv", wv).info("currentAccount", currentAccount).info("currentAccountOrFirst", currentAccountOrFirst).send("ok")
		return wv
    }

    public init(storageAPI: any XDK.StorageAPI, account: AccountInfo? = nil) {
        currentAccount = account
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
			addAccount(account: account)
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
			if oldValue != region {
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
			if oldValue != service {
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




