enum InputSourceSelectionResult: Equatable {
    case selected
    case unavailable
    case failed(Int32)
}

@MainActor
protocol InputSourceSystem {
    func refresh() -> [String: InputSource]
    /// A per-process cache that lags another process's switch until the main
    /// run loop handles its notification.
    func currentSourceID() -> String?
    func selectSource(id: String) -> InputSourceSelectionResult
}
