//
//  SpatialAWSApp.swift
//  spatial-aws
//
//  Created by walter on 5/28/24.
//

import SwiftUI

import SwiftUI

import AWSSSO
import AWSSSOOIDC
import ClientRuntime
import Combine
import Logging
import XDK
import XDKAWSSSO
import XDKKeychain
import XDKLogging

@main
struct SpatialAWSApp: App {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.locale) var locale

    let authenticationAPI: any XDK.AuthenticationAPI
    let storageAPI: any XDK.StorageAPI
    let userSessionAPI: WebSessionManager
    let appSessionAPI: any XDK.AppSessionAPI
    let configAPI: any XDK.ConfigAPI
    let errorHandler: any XDK.ErrorHandler

    let keychainGroup = "\(XDK.getTeamID()!).main.keychain.group"
    let keychainStorageVersion = "1.0.15"

    public init() {
        if !XDK.IS_BEING_UNIT_TESTED() {
            LoggingSystem.bootstrap { label in
                var level: Logger.Level = .trace
                switch label {
                case "URLSessionHTTPClient", "SSOClient", "SSOOIDCClient":
                    level = .error
                default:
                    level = .trace
                }
                return XDKLogging.ConsoleLogger(label: label, level: level, metadata: .init())
            }
        }

        XDK.Log(.info).add("teamid", keychainGroup).send("getting team id")

        let loc = XDKKeychain.LocalAuthenticationClient(group: keychainGroup, version: keychainStorageVersion)

        let usersession = WebSessionManager(storageAPI: loc)

        storageAPI = loc
        configAPI = XDK.BundleConfig(bundle: Bundle.main)
        authenticationAPI = loc
        appSessionAPI = try! XDK.StoredAppSession(storageAPI: storageAPI)
        userSessionAPI = usersession
        errorHandler = XDK.NotificationCenterErrorHandler {
            XDK.Log(.error).err($0).send("error caught by notification handler")
        }

        XDK.AddLoggerMetadataToContext { ev in
            ev.add("device", XDK.GetDeviceFamily(using: self.configAPI).value)
        }

        let res = XDKAWSSSO.signin(storage: storageAPI)
        if let err = res.error {
            XDK.Log(.error).err(err).send("error caught by notification handler")
        } else {
            Task {
                XDK.Log(.warning).send("we are here, not sure what is happening")
                var err = Error?.none
                guard let _ = await usersession.refresh(accessToken: res.value!, storageAPI: loc).err(&err) else {
                    XDK.Log(.error).err(err).send("not sure what happened")
                    throw XDK.Err("problem refreshing access token", root: err)
                }
            }
        }
    }

    //	func scene(_ scene: UIScene,
    //			   willConnectTo session: UISceneSession,
    //			   options connectionOptions: UIScene.ConnectionOptions) {
//
//
    //		// Determine who sent the URL.
    //		if let urlContext = connectionOptions.urlContexts.first {
//
//
    //			let sendingAppID = urlContext.options.sourceApplication
    //			let url = urlContext.url
    //			print("source application = \(sendingAppID ?? "Unknown")")
    //			print("url = \(url)")
//
//
    //			// Process the URL similarly to the UIApplicationDelegate example.
    //		}
//
//
    //		/*
    //		 *
    //		 */
    //	}

    var body: some Scene {
        WindowGroup {
            if XDK.IS_BEING_UNIT_TESTED() {
                Text(verbatim: "running unit tests")
            } else {
                ContentView().onOpenURL(perform: { url in print(url) })
                    .environment(\.authentication, self.authenticationAPI)
                    .environment(\.appSession, self.appSessionAPI)
                    .environment(\.storage, self.storageAPI)
                    .environment(\.config, self.configAPI)
                    .environmentObject(self.userSessionAPI)
                //					.environment(\.managedObjectContext, self.mocAPI.viewContext)
            }

        }.onChange(of: scenePhase) { _, next in
            switch next {
            case .active:
                x.log(.info).send("scene phase updated: ACTIVE")
            case .background:
                x.log(.info).send("scene phase updated: BACKGROUND")
            case .inactive:
                x.log(.info).send("scene phase updated: INACTIVE")
            @unknown default:
                x.log(.info).send("scene phase updated: UNKNOWN")
            }
        }
    }
}

public extension View {
    @inlinable func onAppearAndChange<V>(of value: V, perform action: @escaping (V, V) -> Void) -> some View where V: Equatable {
        return onAppear { action(value, value) }.onChange(of: value, action)
    }

    @inlinable func onAppearAndReceive<P>(_ publisher: P, of value: P.Output, perform action: @escaping (P.Output) -> Void) -> some View where P: Publisher, P.Failure == Never, P.Output: Equatable {
        return onAppear { action(value) }.onChange(of: value) { action($1) }.onReceive(publisher, perform: action)
    }
}

private struct AuthenticationContextKey: EnvironmentKey {
    static let defaultValue: any XDK.AuthenticationAPI = XDK.NoopAuthentication()
}

private struct StorageContextKey: EnvironmentKey {
    static let defaultValue: any XDK.StorageAPI = XDK.NoopStorage()
}

private struct AppSessionContextKey: EnvironmentKey {
    static let defaultValue: any XDK.AppSessionAPI = XDK.NoopAppSession()
}

private struct ConfigContextKey: EnvironmentKey {
    static let defaultValue: any XDK.ConfigAPI = XDK.NoopConfig()
}

extension EnvironmentValues {
    var authentication: any XDK.AuthenticationAPI {
        get { self[AuthenticationContextKey.self] }
        set { self[AuthenticationContextKey.self] = newValue }
    }

    var appSession: any XDK.AppSessionAPI {
        get { self[AppSessionContextKey.self] }
        set { self[AppSessionContextKey.self] = newValue }
    }

    var storage: any XDK.StorageAPI {
        get { self[StorageContextKey.self] }
        set { self[StorageContextKey.self] = newValue }
    }

    var config: any XDK.ConfigAPI {
        get { self[ConfigContextKey.self] }
        set { self[ConfigContextKey.self] = newValue }
    }
}
