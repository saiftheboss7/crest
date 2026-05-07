import Foundation
import Observation
import Combine

@MainActor @Observable
final class ClockService {
    private(set) var currentTime = Date()
    private var timer: Timer?

    init() {
        startTimer()
    }

    func formattedTime(format: String, showSeconds: Bool) -> String {
        DateFormatting.menuBarString(date: currentTime, format: format, showSeconds: showSeconds)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
}
