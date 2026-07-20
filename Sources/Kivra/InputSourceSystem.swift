enum InputSourceSelectionResult: Equatable {
    case selected
    case unavailable
    case failed(Int32)
}

@MainActor
protocol InputSourceSystem {
    func refresh() -> [String: InputSource]
    func currentSourceID() -> String?
    func selectSource(id: String) -> InputSourceSelectionResult
}
