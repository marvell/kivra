import Foundation

struct ApplicationIdentity: Equatable {
    enum Variant: String {
        case stable
        case dev
    }

    static let current = ApplicationIdentity(infoDictionary: Bundle.main.infoDictionary ?? [:])

    let displayName: String
    let variant: Variant
    let version: String?

    var isDevelopment: Bool {
        variant == .dev
    }

    init(infoDictionary: [String: Any]) {
        displayName = infoDictionary["CFBundleDisplayName"] as? String ?? "Kivra"
        version = infoDictionary["CFBundleShortVersionString"] as? String
        variant =
            Variant(
                rawValue: infoDictionary["KivraBuildVariant"] as? String ?? Variant.stable.rawValue
            ) ?? .stable
    }
}
