//
//  AWSConsole.swift
//  spatial-aws-basic
//
//  Created by walter on 1/19/24.
//

import AWSSSO
import SwiftUI
import WebKit
import XDK
import XDKAWSSSO

struct AWSConsoleView: View {
	@EnvironmentObject var userSession: WebSessionManager

	var body: some View {
		VStack {
//			Text("\(self.userSession.currentAccount?.accountName ?? "none")")
////				.tint(.white)
//			Text("\(self.userSession.currentWebview)")
//				.tint(.white)
			WebViewWrapper()
//				.frame(height: 300)

		}.background(.blue)
	}
}

// preview
struct AWSConsoleView_Previews: PreviewProvider {
	static var previews: some View {
		AWSConsoleView()
	}
}


#if os(macOS)
	struct WebViewWrapper: NSViewRepresentable {
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

		func makeNSView(context _: Context) -> NSView {
			let container = NSView()
			let curr = self.userSession.currentWebview()
			container.addSubview(curr) // Assume model.currentWebView is your initial WKWebView

			// Configure constraints or frame to ensure the web view fills the container
			curr.frame = container.bounds
			curr.autoresizingMask = [.width, .height]

			return container
		}

		func updateNSView(_ nsView: NSView, context _: Context) {
			let curr = self.userSession.currentWebview()

			// Ensure the container only contains the current web view
			nsView.subviews.forEach { $0.removeFromSuperview() }
			nsView.addSubview(curr)

			// Update frame or constraints if necessary
			curr.frame = nsView.bounds
			curr.autoresizingMask = [.width, .height]
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
			let curr = self.userSession.currentWebview()

			container.addSubview(curr) // Assume model.currentWebView is your initial WKWebView

			// Configure constraints or frame to ensure the web view fills the container
			curr.frame = container.bounds
			curr.autoresizingMask = .init([.flexibleWidth, .flexibleHeight])

			return container
		}

		func updateUIView(_ nsView: UIView, context _: Context) {
			let curr = self.userSession.currentWebview()

			// Ensure the container only contains the current web view
			nsView.subviews.forEach { $0.removeFromSuperview() }
			nsView.addSubview(curr)

			// Update frame or constraints if necessary
			curr.frame = nsView.bounds
			curr.autoresizingMask = .init([.flexibleWidth, .flexibleHeight])
		}
	}
#endif

// struct AWSConsoleWebViewControllerRepresentable: PlatformViewControllerRepresentable {
//	@EnvironmentObject var userSession: XDKAWSSSO.AWSSSOUserSession
//	@Environment(\.authentication) var authentication
//	@Environment(\.storage) var storage
//	@Environment(\.config) var config
//
//	func makeUIViewController(context _: Self.Context) -> AWSConsoleWebViewController {
//		return AWSConsoleWebViewController(userSession: self.userSession, authentication: self.authentication, storage: self.storage, config: self.config)
//	}
//
//	func updateUIViewController(_ uiViewController: AWSConsoleWebViewController, context _: Self.Context) {
//		uiViewController.loadView()
//	}
//
//	func makeNSViewController(context: Self.Context) -> AWSConsoleWebViewController {
//		return self.makeUIViewController(context: context)
//	}
//
//	func updateNSViewController(_ nsViewController: AWSConsoleWebViewController, context _: Self.Context) {
//		nsViewController.loadView()
//	}
//
//	func makeCoordinator() -> Coordinator {
//		return Coordinator()
//	}
//
//	class Coordinator: NSObject, WKNavigationDelegate {
////		var parent: WKWebView
////
////		init(_ webView: WKWebView) {
////			self.parent = webView
////		}
//
//		func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//			// Handle completion of navigation
//		}
//
//		// Implement other delegate methods as needed
//	}
// }
//
// struct AWSConsoleWebViewController_Previews: PreviewProvider {
//	static var previews: some View {
//		AWSConsoleWebViewControllerRepresentable()
//	}
// }
//
// #if os(macOS)
//	typealias PlatformViewContoller = NSViewController
// #else
//	typealias PlatformViewContoller = UIViewController
// #endif
//
// class AWSConsoleWebViewController: PlatformViewContoller, WKUIDelegate {
//	var userSession: XDKAWSSSO.AWSSSOUserSession
//	var authentication: any XDK.AuthenticationAPI
//	var storage: any XDK.StorageAPI
//
//	init(userSession: XDKAWSSSO.AWSSSOUserSession, authentication: any XDK.AuthenticationAPI, storage: any XDK.StorageAPI, config _: any XDK.ConfigAPI) {
//		self.userSession = userSession
//		self.authentication = authentication
//		self.storage = storage
//		super.init(nibName: nil, bundle: Bundle.main)
//	}
//
//	@available(*, unavailable)
//	required init?(coder _: NSCoder) {
//		fatalError("init(coder:) has not been implemented")
//	}
//
//	override func loadView() {
//		XDK.Log(.debug).send("attempting to load view")
//
//		super.loadView()
////
////		let res = self.userSession.apply(wkuiDelegate: self, storageAPI: self.storage)
////		if let value = res.value {
////			view = value
////		} else {
////			x.log(.critical).err(res.error!).send("unable to load console view")
////			view = NSView()
////		}
//	}
// }
//
//// an nsview that just displays the name of the account
//
// class AWSConsoleWebViewNameView: NSView {
//	var account: String
//
//	init(webview _: WKWebView, account: String) {
//		self.account = account
//		super.init(frame: .infinite)
//	}
//
//	@available(*, unavailable)
//	required init?(coder _: NSCoder) {
//		fatalError("init(coder:) has not been implemented")
//	}
//
//	override func draw(_ dirtyRect: NSRect) {
//		let paragraphStyle = NSMutableParagraphStyle()
//		paragraphStyle.alignment = .center
//		let attrs: [NSAttributedString.Key: Any] = [
//			.font: NSFont.systemFont(ofSize: 24),
//			.paragraphStyle: paragraphStyle,
//			.foregroundColor: NSColor.white,
//		]
//		let string = NSAttributedString(string: self.account, attributes: attrs)
//		string.draw(with: self.bounds, options: .usesLineFragmentOrigin)
//		super.draw(dirtyRect)
//	}
// }
//
//// a nsview that wraps a webview so we can see the name of the account overlayed on the webview itself
//
// class AWSConsoleWebView: NSView {
//	var webview: WKWebView
//	var account: String
//
//	init(webview: WKWebView, account: String) {
//		self.webview = webview
//		self.account = account
//		super.init(frame: .zero)
//		self.addSubview(self.webview)
//	}
//
//	@available(*, unavailable)
//	required init?(coder _: NSCoder) {
//		fatalError("init(coder:) has not been implemented")
//	}
//
//	override func layout() {
//		super.layout()
//		self.webview.frame = self.bounds
//	}
//
//	override func draw(_ dirtyRect: NSRect) {
//		super.draw(dirtyRect)
//		let paragraphStyle = NSMutableParagraphStyle()
//		paragraphStyle.alignment = .center
//		let attrs: [NSAttributedString.Key: Any] = [
//			.font: NSFont.systemFont(ofSize: 24),
//			.paragraphStyle: paragraphStyle,
//			.foregroundColor: NSColor.white,
//		]
//		let string = NSAttributedString(string: self.account, attributes: attrs)
//		string.draw(with: self.bounds, options: .usesLineFragmentOrigin)
//	}
// }
