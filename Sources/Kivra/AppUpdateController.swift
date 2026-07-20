import Sparkle

@MainActor
final class AppUpdateController: NSObject, SPUUpdaterDelegate {
    private lazy var updaterController: SPUStandardUpdaterController? = {
        guard Bundle.main.bundleURL.pathExtension == "app",
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        else {
            return nil
        }
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()

    var isAvailable: Bool {
        updaterController != nil
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        Self.allowedChannels(
            forVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String
        )
    }

    static func allowedChannels(forVersion version: String?) -> Set<String> {
        version?.contains("-") == true ? ["beta"] : []
    }
}
