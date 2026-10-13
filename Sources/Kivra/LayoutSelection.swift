enum LayoutSelection {
    static let thresholdRange = 100...500
    static let thresholdStep = 50

    static func resolve(
        sources: [InputSource],
        leftID: String?,
        rightID: String?
    ) -> (left: String, right: String) {
        let left =
            leftID.flatMap { id in
                sources.contains { $0.id == id } ? id : nil
            } ?? sources.first?.id ?? ""
        let fallbackRight = sources.first { $0.id != left }?.id ?? left
        let right =
            rightID.flatMap { id in
                sources.contains { $0.id == id && id != left } ? id : nil
            } ?? fallbackRight
        return (left, right)
    }

    static func alternative(to id: String, in sources: [InputSource]) -> String? {
        sources.first { $0.id != id }?.id
    }

    static func normalizedThreshold(_ milliseconds: Int) -> Int {
        let clampedValue = min(
            max(milliseconds, thresholdRange.lowerBound),
            thresholdRange.upperBound
        )
        let step = Double(thresholdStep)
        return Int((Double(clampedValue) / step).rounded() * step)
    }
}
