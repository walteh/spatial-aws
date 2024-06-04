//
//  MenuSlider.swift
//  SpatialAWS
//
//  Created by walter on 6/3/24.
//

import Combine
import SwiftUI

struct MenuSlider: SwiftUI.View {
	@Binding var selectedIndex: Int
	let items: [String]

	@State private var rotationAngle = Angle(degrees: 0)
	@State private var progress = 0.0

	private var minValue = 0.0
	private var maxValue: Double {
		return Double(items.count)
	}

	init(selectedIndex: Binding<Int>, items: [String]) {
		self._selectedIndex = selectedIndex
		self.items = items
		self.progress = Double(selectedIndex.wrappedValue)
	}

	private var progressFraction: Double {
		return ((self.progress - self.minValue) / (self.maxValue - self.minValue))
	}


	private func changeAngle(location: CGPoint) {
	 let vector = CGVector(dx: location.x, dy: -location.y)
	 let angleRadians = atan2(vector.dx, vector.dy)
	 let positiveAngle = angleRadians < 0.0 ? angleRadians + (2.0 * .pi) : angleRadians
	 let newProgress = ((positiveAngle / (2.0 * .pi)) * (self.maxValue - self.minValue)) + self.minValue

	 // Check if an item was passed
	 let oldIndex = Int(round(self.progress))
	 let newIndex = Int(round(newProgress))
	 if oldIndex != newIndex {
		 FeedbackGenerator.shared.triggerFeedback()
	 }

	 self.progress = newProgress
	 self.rotationAngle = Angle(radians: positiveAngle)
 }

	private func snapToNearest() {
		let nearestIndex = Int(round(self.progress))
		var nearestIndexSelected = nearestIndex
		if nearestIndex == self.items.count {
			nearestIndexSelected = 0
		}
		withAnimation {
			self.selectedIndex = nearestIndexSelected
			self.progress = Double(nearestIndex)
			self.rotationAngle = Angle(degrees: self.progressFraction * 360.0)
		}
	}

	var body: some View {
		GeometryReader { gr in
			let radius = (min(gr.size.width, gr.size.height) / 2.0)
			let sliderWidth = radius * 0.2

			VStack(spacing: 0) {
				ZStack {
					Circle()
										 .stroke(.ultraThickMaterial, style: StrokeStyle(lineWidth: sliderWidth))
										 .overlay {
											 ForEach(0..<Int(self.items.count)) { index in
												 TextView(text: self.items[index], scale: self.scale(for: index))
													 .position(self.position(for: index, in: gr.size))
													 .foregroundColor(index == self.selectedIndex ? .blue : .primary)
											 }
										 }

					Circle()
						.trim(from: 0, to: self.progressFraction)
						.stroke(Color(hue: 0.0, saturation: 0.5, brightness: 0.9),
								style: StrokeStyle(lineWidth: sliderWidth, lineCap: .round))
						.rotationEffect(Angle(degrees: -90))
					Circle()
						.fill(.thinMaterial)
						.frame(width: sliderWidth * 2, height: sliderWidth * 2, alignment: .center)
						.shadow(radius: sliderWidth * 0.3)
						.offset(x: 2, y: -radius)
						.rotationEffect(self.rotationAngle)
						.highPriorityGesture(
							DragGesture(minimumDistance: 0.0)
								.onChanged { x in
									self.changeAngle(location: x.location)
								}
								.onEnded { _ in
									self.snapToNearest()
								}
						)
				}
				.frame(width: radius * 2.0, height: radius * 2.0, alignment: .center)
				.padding(radius * 0.1)
			}
			.onAppear {
				self.rotationAngle = Angle(degrees: self.progressFraction * 360.0)
			}
		}.scaledToFit()
	}

	private func position(for index: Int, in size: CGSize) -> CGPoint {
		let angle = 2.0 * .pi * (Double(index) / Double(self.items.count))
		let baseRadius = (min(size.width, size.height) / 2.0)
		let labelRadius = baseRadius + 45 // Adjust this value to control the distance of the labels from the circle

		let x = size.width / 2 + labelRadius * cos(angle - .pi / 2)
		let y = size.height / 2 + labelRadius * sin(angle - .pi / 2)

		return CGPoint(x: x, y: y)
	}

	private func scale(for index: Int) -> CGFloat {
		let itemCount = Double(items.count)
		let distance = min(abs(self.progress - Double(index)), itemCount - abs(self.progress - Double(index)))

		switch distance {
		case 0:
			return 2.0
		case 0..<1:
			return 2.0 - 0.5 * distance // Smoothly interpolate between 2.0 and 1.5
		case 1..<2:
			return 1.5 - 0.5 * (distance - 1) // Smoothly interpolate between 1.5 and 1.0
		default:
			return 1.0
		}
	}

}

#if os(iOS)
import UIKit

class FeedbackGenerator {
	static let shared = FeedbackGenerator()
	private var feedbackGenerator: UIImpactFeedbackGenerator?

	private init() {
		feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
		feedbackGenerator?.prepare()
	}

	func triggerFeedback() {
		feedbackGenerator?.impactOccurred()
		feedbackGenerator?.prepare()
	}
}
#else
class FeedbackGenerator {
	static let shared = FeedbackGenerator()

	func triggerFeedback() {
		print("trigger")
		// No haptic feedback on macOS
	}
}
#endif



struct TextView: View {
	var text: String
	var scale: CGFloat
	
	var body: some View {
		Text(text)
			.font(.system(size: 14 * scale)) // Adjust the font size based on scale
			.frame(width: 50 * scale, height: 50 * scale) // Adjust frame size based on scale
			.background(Color.clear) // Ensure background does not affect position
	}
}

/* //////////////////////////////////////////////////////////////
  ///                        PREVIEWS
 /////////////////////////////////////////////////////////////// */

private struct PreviewDummy: View {
	@State var selectedIndex = 2
	let items = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6", "Item 7", "Item 8"]

	var body: some View {
		Section {
			MenuSlider(selectedIndex: self.$selectedIndex, items: self.items)
				.padding(30)
		}.frame(width: 150, height: 150)
	}
}

struct MenuSlider_Previews: PreviewProvider {
	static var previews: some View {
		PreviewDummy()
	}
}
