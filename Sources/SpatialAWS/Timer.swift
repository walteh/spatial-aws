//
//  Timer.swift
//  spatial-aws
//
//  Created by walter on 7/10/24.
//

import Combine
import Foundation
import XDK

class TimerViewModel: ObservableObject {}

import SwiftUI

struct TimerView: View {
	@Binding var endDate: Date?
	@State var timeRemaining: TimeInterval = 0

	@State private var timer: AnyCancellable?

	init(endDate: Binding<Date?>) {
		self._endDate = endDate

		self.timeRemaining = endDate.wrappedValue?.timeIntervalSinceNow ?? 0

		self.startTimer()
	}

	private func startTimer() {
		self.timer = Timer.publish(every: 1, on: .main, in: .common)
			.autoconnect()
			.sink { _ in
				self.updateTimeRemaining()
			}
	}

	private func updateTimeRemaining() {
		Log(.info).meta(["time": .string(self.endDate?.formatted() ?? "none"), "left": .string(self.endDate?.timeIntervalSinceNow.description ?? "none")]).send("up")
		self.timeRemaining = self.endDate?.timeIntervalSinceNow ?? 1
		if self.timeRemaining <= 0 {
			self.timer?.cancel()
		}
	}

	var body: some View {
		Text(self.timeString(from: self.timeRemaining))
			.font(.largeTitle)
			.padding()
			.monospaced()
			.onAppearAndChange(of: self.endDate) { _, n in
				self.timeRemaining = n?.timeIntervalSinceNow ?? 0
			}
	}

	private func timeString(from timeInterval: TimeInterval) -> String {
		let minutes = Int(timeInterval) / 60
		let seconds = Int(timeInterval) % 60
		return String(format: "%02d:%02d", minutes, seconds)
	}
}
