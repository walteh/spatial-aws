//
//  ContentView.swift
//  spatial-aws-basic
//
//  Created by walter on 1/19/24.
//

// import RealityKit

// import RealityKitContent
import SwiftUI
import XDK
import XDKAWSSSO
import XDKKeychain

struct ContentView: View {
	@EnvironmentObject var userSession: WebSessionManager
	@State private var isUserLoggedIn: Bool = false

	@State var resources: [String] = []
	var body: some View {
		Group {
			if self.isUserLoggedIn {
				HStack {
					AWSConsoleView()
				}
			} else {
				SSOSignInView()
			}
		}
		.onAppearAndReceive(self.userSession.accessTokenPublisher, of: self.userSession.accessToken) { tkn in
			// Update the state based on the new value of accessToken
			self.isUserLoggedIn = tkn != nil
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
