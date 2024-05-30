//
//  AWSMenu.swift
//  spatial-aws-basic
//
//  Created by walter on 1/19/24.
//

import SwiftUI

// import UIKit
import WebKit
import XDKAWSSSO

struct AWSConsoleSidebarMenuView: View {
	@EnvironmentObject var userSession: WebSessionManager

	@State var regions: [String] = ["us-east-1", "us-east-2"]
	@State var services: [String] = ["S3", "appsync"]
	@State var resources: [String] = []

	var body: some View {
		VStack(alignment: .center) {
//			ForEach(self.userSession.accountsList.accounts, id: \.self) { account in
//				AccountButton(account: account)
//			}
			 MenuView(title: "Account", selection: self.$userSession.currentAccount, options: self.$userSession.accountsList.accounts, format: {
			 	"\($0.accountName) - \($0.role?.roleName ?? "unknown")"
			 })
			 MenuView(title: "Region", selection: self.$userSession.region, options: self.$regions, format: { v in v })
			 MenuView(title: "Service", selection: self.$userSession.service, options: self.$services, format: { v in v })
//			MenuView(title: "Resource", selection: self.$userSession.resource, options: self.$resources, format: { v in v })
			Spacer()
			Button("Sign out") {
				// Handle sign out logic
			}
		}
		.padding()
		// Add any styling you wish here
	}
}

struct AccountButton: View {
	@EnvironmentObject var userSession: WebSessionManager

	let account: XDKAWSSSO.AccountInfo

	var body: some View {
		Button(self.account.accountName) {
			self.userSession.currentAccount = self.account
		}
		// selected account should be highlighted
		.background(self.userSession.currentAccount == self.account ? Color.blue : Color.clear)
	}
}

struct MenuView<T: Hashable>: View {
	let title: String
	@Binding var selection: T?
	@Binding var options: [T]
	let format: (T) -> String

	var body: some View {
		Menu {
			Picker(self.title, selection: self.$selection) {
				ForEach(self.options, id: \.self) { option in
					Text(self.format(option)).tag(Optional(option))
				}
			}
		} label: {
			HStack {
				Text(self.$selection.wrappedValue != nil ? self.format(self.$selection.wrappedValue!) : "Select \(self.title)")
				Spacer()
				Image(systemName: "chevron.down")
			}
		}
		.padding()
	}
}

// preview
struct AWSConsoleSidebarMenuView_Previews: PreviewProvider {
	static var previews: some View {
		AWSConsoleSidebarMenuView()
	}
}
