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
import Err
import LogEvent
import LogDistributor

@main
struct SpatialAWSApp: App {
	@Environment(\.scenePhase) var scenePhase
	@Environment(\.locale) var locale

	let authenticationAPI: any XDK.AuthenticationAPI
	let storageAPI: any XDK.StorageAPI
	let userSessionAPI: WebSessionManager
	let appSessionAPI: any XDK.AppSessionAPI
	let configAPI: any XDK.ConfigAPI
	let errorHandler: ErrorBroadcaster.HandlerFunc

	let keychainGroup = "\(XDK.getTeamID()!).main.keychain.group"
	let keychainStorageVersion = "1.0.22"

	@err public init() {
		if !XDK.IS_BEING_UNIT_TESTED() {
			LoggingSystem.bootstrap { label in
				var level: Logger.Level = .trace
				switch label {
				case "URLSessionHTTPClient", "SSOClient", "SSOOIDCClient":
					level = .error
				default:
					level = .trace
				}
				return LogDistributor.ConsoleLogger(label: label, level: level, metadata: .init())
//				return LogDistributor.StdOutHandler(level: level)
			}
		}

		log(.info).info("teamid", self.keychainGroup).send("getting team id")

		let loc = XDKKeychain.LocalAuthenticationClient(group: self.keychainGroup, version: self.keychainStorageVersion)

		let session = try! XDK.StoredAppSession(storageAPI: loc)

		let usersession = WebSessionManager(accounts: AccountInfoList(accounts: []), storage: loc, appSession: session)

		self.storageAPI = loc
		self.configAPI = XDK.BundleConfig(bundle: Bundle.main)
		self.authenticationAPI = loc
		self.appSessionAPI = session
		self.userSessionAPI = usersession
		self.errorHandler =  {
			log(.error).err($0).send("error caught by notification handler")
		}

		AddLoggerMetadataToContext { ev in
			ev.info("device", XDK.GetDeviceFamily(using: self.configAPI).value)
		}

		let res = XDKAWSSSO.getSignedInSSOUserFromKeychain(session: self.appSessionAPI, storage: self.storageAPI)
		if let err = res.error {
			log(.error).err(err).send("error caught by notification handler")
		} else if let v = res.value {
			if let v {
				Task {
					log(.warning).send("we are here, not sure what is happening")
					guard let _ = try await usersession.refresh(session: session, storageAPI: loc, accessToken: v).get() else {
						log(.error).err(err).send("not sure what happened")
						throw x.error("problem refreshing access token", root: err)
					}
				}
			}
		}
	}

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

		}.onChange(of: self.scenePhase) { _, next in
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

extension EnvironmentValues {
	@Entry var authentication: any XDK.AuthenticationAPI = XDK.NoopAuthentication()
	@Entry var appSession: any XDK.AppSessionAPI = XDK.NoopAppSession()
	@Entry var storage: any XDK.StorageAPI = XDK.NoopStorage()
	@Entry var config: any XDK.ConfigAPI = XDK.NoopConfig()
}

//
// private struct AuthenticationContextKey: EnvironmentKey {
//    static let defaultValue: any XDK.AuthenticationAPI = XDK.NoopAuthentication()
// }
//
// private struct StorageContextKey: EnvironmentKey {
//    static let defaultValue: any XDK.StorageAPI = XDK.NoopStorage()
// }
//
// private struct AppSessionContextKey: EnvironmentKey {
//	@MainActor static let defaultValue: any XDK.AppSessionAPI = XDK.NoopAppSession()
// }
//
// private struct ConfigContextKey: EnvironmentKey {
//    static let defaultValue: any XDK.ConfigAPI = XDK.NoopConfig()
// }
//
// extension EnvironmentValues {
//    var authentication: any XDK.AuthenticationAPI {
//        get { self[AuthenticationContextKey.self] }
//        set { self[AuthenticationContextKey.self] = newValue }
//    }
//
//    var appSession: any XDK.AppSessionAPI {
//        get { self[AppSessionContextKey.self] }
//        set { self[AppSessionContextKey.self] = newValue }
//    }
//
//    var storage: any XDK.StorageAPI {
//        get { self[StorageContextKey.self] }
//        set { self[StorageContextKey.self] = newValue }
//    }
//
//    var config: any XDK.ConfigAPI {
//        get { self[ConfigContextKey.self] }
//        set { self[ConfigContextKey.self] = newValue }
//    }
// }
