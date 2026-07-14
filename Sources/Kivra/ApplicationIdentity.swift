import Foundation

struct ApplicationIdentity: Equatable {
    enum Variant: String {
        case stable
        case dev
    }

    static let current = ApplicationIdentity(infoDictionary: Bundle.main.infoDictionary ?? [:])

    let displayName: String
    let variant: Variant

    var isDevelopment: Bool {
        variant == .dev
    }

    init(infoDictionary: [String: Any]) {
        displayName = infoDictionary["CFBundleDisplayName"] as? String ?? "Kivra"
        variant = Variant(
            rawValue: infoDictionary["KivraBuildVariant"] as? String ?? Variant.stable.rawValue
        ) ?? .stable
    }
}
