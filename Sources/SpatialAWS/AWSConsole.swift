//
//  AWSConsole.swift
//  spatial-aws-basic
//
//  Created by walter on 1/19/24.
//

import AWSSSO
import Combine
import SwiftUI
import WebKit
import XDK
import XDKAWSSSO

struct AWSConsoleView: View {
	@EnvironmentObject var userSession: WebSessionManager

	@Binding var expiry: Date?

	init() {
//		super.init()
		self._expiry = Binding.constant(Date())
	}

	var body: some View {
		VStack(spacing: 0) {
			// Top bar
			TopBar(
				selectedAccount: self.$userSession.currentAccount,
				selectedRole: self.$userSession.role,
				selectedService: self.$userSession.service,
				selectedRegion: self.$userSession.region,
				roleExpiration: self.$userSession.roleExpiration,
				tokenExpiration: self.$userSession.tokenExpiration,
				accounts: self.userSession.accountsList.accounts,
				onRefresh: {
					return
				}
			)

			WebViewWrapper()
//				.edgesIgnoringSafeArea(.all)
		}
		.edgesIgnoringSafeArea(.bottom)
	}
}

// preview
// struct AWSConsoleView_Previews: PreviewProvider {
//	static var previews: some View {
//		AWSConsoleView()
//			.environmentObject(
//				WebSessionManager(accounts:
//					AccountInfoList(accounts: [
//						AccountInfo(accountID: "111", accountName: "ho", roles: [
//							RoleInfo(roleName: "me", accountID: "111")], accountEmail: "ok@me.com"),
//					]), storage: NoopStorage()))
//	}
// }

@MainActor
func injectCustomCSS(_ view: WKWebView) {
	let cssString = "div#h { display: none; }"
	let jsString = "var style = document.createElement('style'); style.innerHTML = '\(cssString)'; document.head.appendChild(style);"

	view.evaluateJavaScript(jsString, completionHandler: { result, error in
		if let error {
			print("JavaScript evaluation error: \(error.localizedDescription), result \(result.debugDescription)")
		} else {
			print("CSS injected successfully")
		}
	})
}

#if os(macOS)

	struct WebViewWrapper: NSViewRepresentable {
		@EnvironmentObject var userSession: WebSessionManager

		class Coordinator: NSObject, WKNavigationDelegate {
			var parent: WebViewWrapper

			init(_ parent: WebViewWrapper) {
				self.parent = parent
			}

			func webView(_: WKWebView, didFinish _: WKNavigation!) {
//				Task(priority: .userInitiated)  { @MainActor in
//					injectCustomCSS(webView)
//				}
			}
		}

		func makeCoordinator() -> Coordinator {
			Coordinator(self)
		}

		func makeNSView(context: Context) -> NSView {
			let container = NSView()

			if let curr = userSession.currentWebview() {
				curr.navigationDelegate = context.coordinator // Set the navigation delegate
				container.addSubview(curr)
//				injectCustomCSS(curr)

				curr.frame = CGRect(x: 0, y: 0, width: container.bounds.width, height: container.bounds.height)
				curr.autoresizingMask = [.width, .height]
			}

			return container
		}

		func updateNSView(_ nsView: NSView, context: Context) {
			// Ensure the container only contains the current web view
			if let curr = userSession.currentWebview() {
				nsView.subviews.forEach { $0.removeFromSuperview() }

				nsView.addSubview(curr)

				curr.frame = CGRect(x: 0, y: 0, width: nsView.bounds.width, height: nsView.bounds.height)
				curr.autoresizingMask = [.width, .height]
				curr.navigationDelegate = context.coordinator // Ensure delegate is set on update
			}
		}

		func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
			injectCustomCSS(webView)
		}
	}
#else
	struct WebViewWrapper: UIViewRepresentable {
		@EnvironmentObject var userSession: WebSessionManager

		class Coordinator: NSObject {
			var parent: WebViewWrapper

			init(_ parent: WebViewWrapper) {
				self.parent = parent
			}

			// Add methods to manage dynamic switching here if needed
		}

		func makeCoordinator() -> Coordinator {
			Coordinator(self)
		}

		func makeUIView(context _: Context) -> UIView {
			let container = UIView()
			if let curr = userSession.currentWebview() {
				container.addSubview(curr)

				// Configure constraints or frame to ensure the web view fills the container
				curr.frame = CGRect(x: 0, y: 0, width: container.bounds.width, height: container.bounds.height)
				curr.autoresizingMask = .init([.flexibleWidth, .flexibleHeight])
			}

			return container
		}

		func updateUIView(_ nsView: UIView, context _: Context) {
			if let curr = userSession.currentWebview() {
				nsView.subviews.forEach { $0.removeFromSuperview() }

				nsView.addSubview(curr)

				// Update frame or constraints if necessary
				curr.frame = CGRect(x: 0, y: 0, width: nsView.bounds.width, height: nsView.bounds.height)
				curr.autoresizingMask = .init([.flexibleWidth, .flexibleHeight])
			}
		}
	}
#endif
