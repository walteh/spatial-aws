//
//  AWSMenu.swift
//  spatial-aws-basic
//
//  Created by walter on 1/19/24.
//

import SwiftUI

import WebKit
import XDKAWSSSO

struct MenuView3<T: Hashable>: View {
	let title: String
	@Binding var selection: T?
	var options: [T]
	let format: (T) -> String
	let offset: CGSize
	@State private var isExpanded: Bool = false

	var body: some View {
		ZStack {
			HStack {
				Spacer()
				VStack {
					Spacer()
					Button(
						action: {
							withAnimation {
								self.isExpanded.toggle()
							}
						}
					) {
						Text(self.title)
					}
					.offset(self.offset)
				}
			}
			if self.isExpanded {
				Color.black.opacity(0.5)
					.edgesIgnoringSafeArea(.all)
					.transition(.opacity)
					.onTapGesture {
						withAnimation {
							self.isExpanded.toggle()
						}
					}

				MenuSlider(
					selectedIndex: Binding(
						get: { self.selection.flatMap { self.options.firstIndex(of: $0) } ?? 0 },
						set: { newIndex in
							self.selection = self.options[newIndex]
						}
					),
					items: self.options.map { self.format($0) }
				)
				.padding(50)
				.frame(width: 200, height: .init(200))
				.transition(.scale)
				.scaledToFit()
			}
		}
	}
}

//
//
// struct MenuView<T: Hashable>: View {
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
// }

// @preview
struct AWSConsoleSidebarMenuView_Previews: PreviewProvider {
	static var previews: some View {
		MenuView3(title: "Account", selection: .constant(nil), options: .init(["Account 1", "Account 2", "Account 3"]), format: { $0 }, offset: .init(width: -100, height: 0))
	}
}
