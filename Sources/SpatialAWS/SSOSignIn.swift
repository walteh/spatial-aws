//
//  SSOSignIn.swift
//  spatial-aws-basic
//
//  Created by walter on 1/19/24.
//

import AuthenticationServices // For web-based authentication
import AWSSSOOIDC
import Combine
import Foundation
import SwiftUI
import XDK
import XDKAWSSSO
import XDKKeychain

struct SSOSignInView: View {
	@Environment(\.authentication) var authentication
	@Environment(\.storage) var storage
	@EnvironmentObject var userSession: WebSessionManager
	@Environment(\.appSession) var appSession

	//	@State private var currentViewController: UIViewController?

	@State private var promptURL: AWSSSOSignInCodeData? = nil
	@State private var shouldPresent: Bool = false
	@State private var activityItems: [Any] = []
	@State private var showSignInDetail = false

	// State properties to bind to the input fields
	@State private var startURL = ""
	@State private var selectedRegion = "us-east-1" // Default value or use a sensible default for your case
	// An example list of regions
	let regions = ["us-east-1", "us-west-2", "eu-west-1", "ap-southeast-1", "ap-northeast-1"]

	var body: some View {
		VStack {
			
			
			Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())

		
			TextField("aws sso start url", text: self.$startURL)
				.textFieldStyle(RoundedBorderTextFieldStyle())
				.padding()
				//				.autocapitalization()
				.disableAutocorrection(true)
			// Add your validation logic here

			Picker("aws sso region", selection: self.$selectedRegion) {
				ForEach(self.regions, id: \.self) {
					Text($0)
				}
			}
			.pickerStyle(MenuPickerStyle())

			// Here you would add the foundation logic for the sign-in action
			Button(action: self.signInUsingSSO) {
				Text("generate sign in code")
			}
			
			if showSignInDetail {
				if let userSignInData = promptURL {
					SignInDetailView(userSignInData: userSignInData)
				}
			}
		}
		.padding()
//		.sheet(isPresented: self.$showSignInDetail) {
//			if let userSignInData = promptURL {
//				SignInDetailView(userSignInData: userSignInData)
//			}
//		}
		.onChange(of: self.promptURL, initial: false) { _, _ in
			self.showSignInDetail = (self.promptURL != nil)
		}
	}

//	@MainActor
	// The function that gets called when the sign in button is pressed
	private func signInUsingSSO() {
		let myselectedregion = selectedRegion
		Task {
			do {
				var err = Error?.none

				let val = "https://\(self.startURL).awsapps.com/start#/"
				guard let startURI = URL(string: val) else {
					throw URLError(.init(rawValue: 0), userInfo: ["uri": val])
				}

				guard let ssooidc = XDKAWSSSO.buildAWSSSOSDKProtocolWrapped(ssoRegion: selectedRegion).to(&err) else {
					throw XDK.Err("problem refreshing access token", root: err)
				}
				

				guard let resp = await XDKAWSSSO.generateSSOAccessTokenUsingBrowserIfNeeded(
					client: ssooidc,
					storage: storage,
					session: appSession,
					ssoRegion: myselectedregion,
					startURL: startURI,
					callback: { url in
						DispatchQueue.main.async {
							self.promptURL = url
						}
					}
				).to(&err) else {
					throw XDK.Err("problem signing in with sso", root: err)
				}

				guard let _ = await self.userSession.refresh(session: appSession, storageAPI: storage, accessToken: resp).err(&err) else {
					throw XDK.Err("problem refreshing access token", root: err)
				}

				try print(resp.encodeToJSON())
			} catch {
				x.log(.critical).err(error).send("problem signing in with soo")
			}
		}
	}
}

struct SignInDetailView: View {
	let userSignInData: XDKAWSSSO.AWSSSOSignInCodeData

	var body: some View {
//		VStack {
			// if this isa macos catalyst, add option to open in browser
			#if os(macOS)
				Button(action: {
					NSWorkspace.shared.open(self.userSignInData.activationURLWithCode)
				}) { Text("open in browser") }

			#else
				Link("Open In Safari", destination: self.userSignInData.activationURLWithCode)
					.padding()
				// if this is an iOS device, add option to share
				ShareLink(item: self.userSignInData.activationURLWithCode)
					.padding()
			#endif

//			Spacer()
//		}
	}
}

struct SSOSignInView_Previews: PreviewProvider {
	static var previews: some View {
		SSOSignInView()
	}
}
