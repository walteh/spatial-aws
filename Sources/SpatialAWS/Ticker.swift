//
//  Ticker.swift
//  app
//
//  Created by walter on 10/14/22.
//

import Combine
import SwiftUI

struct Ticker: View {
	var watch: Double
	@State var rock: Double = 0

	var fmt: (Double) -> String

	func setRock(current: Double) {
		if current < 0 {
			self.rock = 0
		} else {
			self.rock = current
		}
	}

	var body: some View {
		Text(verbatim: self.fmt(self.rock))
			.monospacedDigit()
//			.animatingNumber(for: self.rock, like: self.fmt)
			.onChange(of: self.watch) { _, val in
				withAnimation(.easeOut) {
					self.setRock(current: val)
				}
			}
			.onAppear {
				self.setRock(current: self.watch)
			}
	}
}

public extension Binding where Value == Int64 {
	func double() -> Binding<Double> {
		return Binding<Double>(get: { Double(self.wrappedValue) },
		                       set: { self.wrappedValue = Int64($0) })
	}
}

struct TimeTicker: View {
	@Binding var endDate: Date?

	class Formatter {
		private let formatter = DateComponentsFormatter()

		init() {
			self.formatter.allowedUnits = [.minute, .second]
			self.formatter.zeroFormattingBehavior = .pad
		}

		public func formatSeconds(_ interval: Double) -> String {
			return self.formatter.string(from: .init(interval)) ?? "0"
		}
	}

	public static let formatter = Formatter()

	@State private var value: Double = 0
	@State private var timer: AnyCancellable?

	var body: some View {
		Ticker(watch: self.value, fmt: TimeTicker.formatter.formatSeconds)
			.onAppear {
				self.value = self.endDate?.timeIntervalSinceNow ?? 0
				self.startTimer()
			}
			.onChange(of: self.endDate) { _, newValue in
				self.value = newValue?.timeIntervalSinceNow ?? 0
				self.startTimer()
			}
			.onDisappear {
				self.stopTimer()
			}
	}

	private func startTimer() {
		self.stopTimer()
		self.timer = Timer.publish(every: 1, on: .main, in: .common)
			.autoconnect()
			.sink { _ in
				self.updateTimer()
			}
	}

	private func stopTimer() {
		self.timer?.cancel()
		self.timer = nil
	}

	private func updateTimer() {
		if let endDate = self.endDate {
			let newValue = endDate.timeIntervalSinceNow
			if newValue > 0 {
				self.value = newValue
			} else {
				self.value = 0
				self.stopTimer()
			}
		} else {
			self.value = 0
			self.stopTimer()
		}
	}
}
