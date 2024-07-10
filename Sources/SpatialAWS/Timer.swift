//
//  Timer.swift
//  spatial-aws
//
//  Created by walter on 7/10/24.
//



import Foundation
import Combine

import Foundation
import Combine

class TimerViewModel: ObservableObject {
	@Binding var endDate: Date?
	@Published var timeRemaining: TimeInterval = 0

	private var timer: AnyCancellable?

	init(endDate: Binding<Date?>) {
		self._endDate = endDate
		
		self.timeRemaining = endDate.wrappedValue?.timeIntervalSinceNow ?? 0
		startTimer()
	}

	private func startTimer() {
		timer = Timer.publish(every: 1, on: .main, in: .common)
			.autoconnect()
			.sink { [weak self] _ in
				self?.updateTimeRemaining()
			}
	}

	private func updateTimeRemaining() {
		timeRemaining = endDate?.timeIntervalSinceNow ?? 0
		if timeRemaining <= 0 {
			timer?.cancel()
		}
	}
}


import SwiftUI

struct TimerView: View {
	@ObservedObject var viewModel: TimerViewModel

	var body: some View {
		Text(timeString(from: viewModel.timeRemaining))
			.font(.largeTitle)
			.padding()
	}

	private func timeString(from timeInterval: TimeInterval) -> String {
		let minutes = Int(timeInterval) / 60
		let seconds = Int(timeInterval) % 60
		return String(format: "%02d:%02d", minutes, seconds)
	}
}
