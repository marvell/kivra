import AppKit

let app = NSApplication.shared
let instanceLock: ApplicationInstanceLock

do {
    instanceLock = try ApplicationInstanceLock()
} catch ApplicationInstanceLock.LockError.alreadyHeld {
    app.setActivationPolicy(.accessory)
    app.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "Kivra is already running"
    alert.informativeText = "Quit the running Kivra variant before opening another one."
    alert.addButton(withTitle: "OK")
    alert.runModal()
    exit(EXIT_SUCCESS)
} catch {
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Kivra could not start"
    alert.informativeText = "The application instance lock could not be created."
    alert.addButton(withTitle: "OK")
    alert.runModal()
    exit(EXIT_FAILURE)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
withExtendedLifetime(instanceLock) {
    app.run()
}
