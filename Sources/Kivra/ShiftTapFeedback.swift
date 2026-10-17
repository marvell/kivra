import SwiftUI

/// Briefly lights up the Shift key the person just tapped in Kivra's windows.
@MainActor
final class ShiftTapFeedback: ObservableObject {
    @Published private(set) var highlightedSide: ShiftSide?
    /// Shift keys tapped so far, so setup can confirm that both work.
    @Published private(set) var triedSides: Set<ShiftSide> = []
    private var highlightTask: Task<Void, Never>?

    func record(_ side: ShiftSide) {
        highlightTask?.cancel()
        highlightedSide = side
        triedSides.insert(side)
        highlightTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(700))
            } catch {
                return
            }
            self?.highlightedSide = nil
        }
    }

    /// Asks the person to try a key again, for example after its layout changed.
    func forgetTries(on sides: Set<ShiftSide> = [.left, .right]) {
        triedSides.subtract(sides)
    }
}
