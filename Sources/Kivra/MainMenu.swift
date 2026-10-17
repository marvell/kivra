import AppKit

/// The menu bar shown while one of Kivra's windows is in front.
enum MainMenu {
    @MainActor
    static func make(applicationName: String) -> NSMenu {
        let mainMenu = NSMenu()

        let applicationMenu = NSMenu(title: applicationName)
        applicationMenu.addItem(
            item(
                "About \(applicationName)",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:))
            )
        )
        applicationMenu.addItem(.separator())
        // The app delegate receives this through the responder chain.
        applicationMenu.addItem(
            item("Settings…", action: #selector(AppDelegate.showSettingsFromMenu), key: ",")
        )
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(item("Hide \(applicationName)", action: #selector(NSApplication.hide(_:)), key: "h"))
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(
            item("Quit \(applicationName)", action: #selector(NSApplication.terminate(_:)), key: "q")
        )
        addSubmenu(applicationMenu, to: mainMenu)

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(item("Close", action: #selector(NSWindow.performClose(_:)), key: "w"))
        addSubmenu(windowMenu, to: mainMenu)
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }

    private static func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }

    private static func addSubmenu(_ submenu: NSMenu, to menu: NSMenu) {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }
}
