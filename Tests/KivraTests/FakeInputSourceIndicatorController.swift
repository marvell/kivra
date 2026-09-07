@testable import Kivra

@MainActor
final class FakeInputSourceIndicatorController: InputSourceIndicatorControlling {
    var isHidden = false
    var appliedValues: [Bool] = []
    var shouldFail = false
    var shouldFailAfterWrite = false

    func setHidden(_ hidden: Bool) throws {
        appliedValues.append(hidden)
        if shouldFail {
            throw InputSourceIndicatorError.couldNotSave
        }
        isHidden = hidden
        if shouldFailAfterWrite {
            throw InputSourceIndicatorError.couldNotSave
        }
    }
}
