import Sparkle

@MainActor
final class AppUpdateController: NSObject, SPUUpdaterDelegate,
    @preconcurrency SPUStandardUserDriverDelegate
{
    private let onPresentationRequested: (_ userInitiated: Bool) -> Void
    private let onAttentionReceived: () -> Void
    private let onSessionFinished: () -> Void
    var onAvailabilityChanged: () -> Void = {}

    private var availabilityState = UpdateAvailabilityState() {
        didSet {
            if oldValue.availability != availabilityState.availability {
                onAvailabilityChanged()
            }
        }
    }

    var availability: UpdateAvailability? {
        availabilityState.availability
    }

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

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        availabilityState.found(version: item.displayVersionString)
    }

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        availabilityState.prepared(version: item.displayVersionString)
        return false
    }

    func updater(
        _ updater: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate item: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        if choice == .skip {
            availabilityState.clear()
        } else if state.stage == .installing {
            availabilityState.prepared(version: item.displayVersionString)
        }
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: Error?
    ) {
        guard let error = error as NSError?, error.domain == SUSparkleErrorDomain else {
            return
        }
        let invalidatingErrors: [SUError] = [
            .unarchivingError, .signatureError, .validationError,
            .missingUpdateError, .notValidUpdateError,
        ]
        if invalidatingErrors.contains(where: { error.code == $0.rawValue }) {
            availabilityState.clear()
        } else if error.code == SUError.noUpdateError.rawValue {
            availabilityState.noUpdateFound()
        }
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
        if state.stage == .installing {
            availabilityState.prepared(version: update.displayVersionString)
        } else {
            availabilityState.found(version: update.displayVersionString)
        }
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
