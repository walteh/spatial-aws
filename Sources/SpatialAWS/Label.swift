//
//  Label.swift
//  SpatialAWS
//
//  Created by walter on 10/14/22.
//

import SwiftUI

public extension View {
	@inlinable func defaultShadow() -> some View {
		shadow(color: Color.black.opacity(0.01), radius: 1, x: 0, y: 0)
			.shadow(color: Color.black.opacity(0.04), radius: 8, x: 4, y: 0)
			.shadow(color: Color.black.opacity(0.04), radius: 24, x: 16, y: 0)
			.shadow(color: Color.black.opacity(0.01), radius: 32, x: 24, y: 0)
	}
}

struct Label<Content: View>: View {
	var content: () -> Content // change to closure

	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}

	var body: some View {
		Section {
			self.content()
		}
		.font(.system(.body, design: .rounded).weight(.heavy))
		.foregroundColor(.primary)
		.padding(.horizontal, 10)
		.padding(.vertical, 10)
		.background(.thinMaterial).cornerRadius(16)
		.defaultShadow()
	}
}

struct Label_Previews: PreviewProvider {
	static var previews: some View {
		VStack {
			Label {
				Text(verbatim: "Hello")
			}.padding(5.0).background(.primary)
			Label {
				Text(verbatim: "12:43")
			}.padding(5.0).background(.white)
			Label {
				Text(verbatim: "Hello")
			}.padding(5.0).background(.blue)
			Label {
				Text(verbatim: "12:43")
			}.padding(5.0).background(.primary)
		}
	}
}
