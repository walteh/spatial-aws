//
//  NumberAnimate.swift
//  app
//
//  Created by walter on 10/15/22.
//

import Foundation
import SwiftUI

@MainActor
struct AnimatableNumberModifier: Animatable, ViewModifier {
	var animatableDataz: Double

	var formatter: (_: Double) -> String

	init(number: Binding<Int64>, formatter fmt: @escaping (_: Double) -> String) {
		self.init(number: Double(Int(number.wrappedValue)), formatter: fmt)
	}

	init(number: Binding<Double>, formatter fmt: @escaping (_: Double) -> String) {
		self.init(number: number.wrappedValue, formatter: fmt)
	}

	init(number: Double, formatter fmt: @escaping (_: Double) -> String) {
		self.formatter = fmt
		self.animatableDataz = number
	}

	func body(content: Content) -> some View {
		content
			.overlay(
				Text(self.formatter(self.animatableDataz))
					.monospacedDigit()
			)
	}
}

extension View {
	func animatingNumber(for number: Binding<Int64>, like format: @escaping (_: Double) -> String) -> some View {
		modifier(AnimatableNumberModifier(number: number, formatter: format))
	}

	func animatingNumber(for number: Binding<Double>, like format: @escaping (_: Double) -> String) -> some View {
		modifier(AnimatableNumberModifier(number: number, formatter: format))
	}

	func animatingNumber(for number: Double, like format: @escaping (_: Double) -> String) -> some View {
		modifier(AnimatableNumberModifier(number: number, formatter: format))
	}
}
