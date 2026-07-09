import AppKit

let app = NSApplication.shared
let delegate = StatusBarController()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
