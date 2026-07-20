struct AppConfiguration: Equatable, Sendable {
    static let defaultTapThresholdMilliseconds = 250

    var leftSourceID: String?
    var rightSourceID: String?
    var tapThresholdMilliseconds: Int

    init(
        leftSourceID: String? = nil,
        rightSourceID: String? = nil,
        tapThresholdMilliseconds: Int = Self.defaultTapThresholdMilliseconds
    ) {
        self.leftSourceID = leftSourceID
        self.rightSourceID = rightSourceID
        self.tapThresholdMilliseconds = tapThresholdMilliseconds
    }

    var hasConfiguredSources: Bool {
        leftSourceID != nil && rightSourceID != nil
    }
}
