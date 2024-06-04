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

//struct AWSConsoleSidebarMenuView: View {
//	@EnvironmentObject var userSession: WebSessionManager
//
//	@State var regions: [String] = ["us-east-1", "us-east-2"]
//	@State var services: [String] = ["S3", "appsync"]
//	@State var resources: [String] = []
//
//	var body: some View {
//		VStack(alignment: .center) {
//			 MenuView(title: "Account", selection: self.$userSession.currentAccount, options: self.$userSession.accountsList.accounts, format: {
//			 	"\($0.accountName) - \($0.role?.roleName ?? "unknown")"
//			 })
//			 MenuView(title: "Region", selection: self.$userSession.region, options: self.$regions, format: { v in v })
//			 MenuView(title: "Service", selection: self.$userSession.service, options: self.$services, format: { v in v })
//			Spacer()
//			Button("Sign out") {
//			}
//		}
//		.padding()
//		// Add any styling you wish here
//	}
//}
//
//struct AccountButton: View {
//	@EnvironmentObject var userSession: WebSessionManager
//
//	let account: XDKAWSSSO.AccountInfo
//
//	var body: some View {
//		Button(self.account.accountName) {
//			self.userSession.currentAccount = self.account
//		}
//		// selected account should be highlighted
//		.background(self.userSession.currentAccount == self.account ? Color.blue : Color.clear)
//	}
//}


struct MenuView3<T: Hashable>: View {
	let title: String
	@Binding var selection: T?
	@Binding var options: [T]
	let format: (T) -> String
	@State private var isExpanded: Bool = false

	var body: some View {
		ZStack {
			if isExpanded {
				Color.black.opacity(0.5)
					.edgesIgnoringSafeArea(.all)
					.transition(.opacity)
					.onTapGesture {
						withAnimation {
							isExpanded.toggle()
						}
					}

				VStack(spacing: 20) {
					Text(title)
						.font(.headline)
						.padding(.top, 20)

					MenuSlider(
						selectedIndex: Binding(
							get: { selection.flatMap({ options.firstIndex(of: $0) }) ?? 0 },
							set: { newIndex in
								selection = options[newIndex]
							}
						),
						items: options.map { format($0) }
					)
					.padding()

					Spacer()

					Button(action: {
						withAnimation {
							isExpanded.toggle()
						}
					}) {
						Text("Close")
							.font(.title)
							.padding()
							.background(Color.blue)
							.foregroundColor(.white)
							.cornerRadius(10)
							.shadow(radius: 5)
					}
					.padding(.bottom, 20)
				}
				.frame(width: 300, height: 400)
				.background(Color.white)
				.cornerRadius(10)
				.shadow(radius: 10)
				.transition(.scale)
			} else {
				HStack {
					Spacer()
					VStack {
						Spacer()
						Button(action: {
							withAnimation {
								isExpanded.toggle()
							}
						}) {
							Text("Options")
								.font(.system(size: 16, weight: .bold))
								.foregroundColor(.white)
								.padding()
								.background(Color.blue)
								.cornerRadius(10)
								.shadow(radius: 5)
						}
						.padding()
					}
				}
			}
		}
	}
}

//
//
//struct MenuView<T: Hashable>: View {
//	let title: String
//	@Binding var selection: T?
//	@Binding var options: [T]
//	let format: (T) -> String
//
//	var body: some View {
//		VStack {
//			Text(title)
//				.font(.headline)
//				.padding(.bottom, 20)
//			MenuSlider(
//				selectedIndex: Binding(
//					get: { selection.flatMap({ options.firstIndex(of: $0) }) ?? 0 },
//					set: { newIndex in
//						selection = options[newIndex]
//					}
//				),
//				items: options.map { format($0) }
//			)
//			.frame(height: 300)
//			.padding()
//			
//		}
//	}
//}

// preview
//struct AWSConsoleSidebarMenuView_Previews: PreviewProvider {
//	static var previews: some View {
//		AWSConsoleSidebarMenuView()
//	}
//}
