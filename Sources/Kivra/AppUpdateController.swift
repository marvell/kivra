import Sparkle

@MainActor
final class AppUpdateController: NSObject, SPUUpdaterDelegate,
    @preconcurrency SPUStandardUserDriverDelegate
{
    private let onPresentationRequested: (_ userInitiated: Bool) -> Void
    private let onAttentionReceived: () -> Void
    private let onSessionFinished: () -> Void

    private lazy var updaterController: SPUStandardUpdaterController? = {
        guard Bundle.main.bundleURL.pathExtension == "app",
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        else {
            return nil
        }
        return SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }()

    init(
        onPresentationRequested: @escaping (_ userInitiated: Bool) -> Void = { _ in },
        onAttentionReceived: @escaping () -> Void = {},
        onSessionFinished: @escaping () -> Void = {}
    ) {
        self.onPresentationRequested = onPresentationRequested
        self.onAttentionReceived = onAttentionReceived
        self.onSessionFinished = onSessionFinished
        super.init()
    }

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

    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverWillShowModalAlert() {
        onPresentationRequested(true)
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        onPresentationRequested(state.userInitiated)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        onAttentionReceived()
    }

    func standardUserDriverWillFinishUpdateSession() {
        onSessionFinished()
    }

    static func allowedChannels(forVersion version: String?) -> Set<String> {
        version?.contains("-") == true ? ["beta"] : []
    }
}
