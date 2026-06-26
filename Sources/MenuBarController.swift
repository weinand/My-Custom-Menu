// Builds and maintains the menu bar status item and dynamic menu content.
import AppKit
import Foundation

final class MenuBarController: NSObject, NSMenuDelegate {
    private struct FolderMenuContext {
        let directoryPath: String
        let visitedDirectories: Set<String>
    }

    private let store: MenuStore
    private let statusItem: NSStatusItem
    private let onEdit: () -> Void
    private let fileManager = FileManager.default
    private let faviconService = FaviconService.shared
    private var folderMenuContexts: [ObjectIdentifier: FolderMenuContext] = [:]

    init(store: MenuStore, onEdit: @escaping () -> Void) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onEdit = onEdit
        super.init()
    }

    func rebuildMenu() {
        folderMenuContexts.removeAll()

        if let button = statusItem.button {
            button.title = store.configuration.menuTitle.isEmpty ? "MCM" : store.configuration.menuTitle
        }

        let menu = NSMenu()

        var addedGroupContent = false
        for group in store.configuration.groups {
            let groupHasContent = !group.items.isEmpty
            guard groupHasContent else {
                continue
            }

            if addedGroupContent {
                menu.addItem(.separator())
            }

            let headerItem = NSMenuItem(title: group.title, action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            headerItem.attributedTitle = NSAttributedString(
                string: group.title,
                attributes: [.foregroundColor: NSColor.secondaryLabelColor]
            )
            menu.addItem(headerItem)

            for item in group.items {
                menu.addItem(menuEntry(for: item))
            }

            addedGroupContent = true
        }

        if addedGroupContent {
            menu.addItem(.separator())
        }

        let editItem = NSMenuItem(title: "Edit Menu...", action: #selector(editMenu), keyEquivalent: ",")
        editItem.target = self
        menu.addItem(editItem)

        let quitItem = NSMenuItem(title: "Quit My Custom Menu", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc
    private func openPathMenuItem(_ sender: NSMenuItem) {
        if let targetURL = sender.representedObject as? URL {
            NSWorkspace.shared.open(targetURL)
            return
        }

        guard let storedPath = sender.representedObject as? String else {
            return
        }

        if let filePath = fileSystemPath(from: storedPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: filePath))
            return
        }

        guard let url = URL(string: storedPath), !storedPath.isEmpty else {
            NSLog("Invalid menu path value '%@'", storedPath)
            return
        }

        NSWorkspace.shared.open(url)
    }

    @objc
    private func editMenu() {
        onEdit()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func fileIcon(for item: MenuItemDefinition) -> NSImage? {
        guard let path = item.resolvedFilePath() else {
            return nil
        }

        return sizedIcon(forFileAtPath: path)
    }

    private func sizedIcon(forFileAtPath path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 16, height: 16)
        return icon
    }

    private func menuEntry(for item: MenuItemDefinition) -> NSMenuItem {
        if let folderPath = folderPath(for: item) {
            return folderMenuItem(title: item.title, path: folderPath)
        }

        let menuItem = NSMenuItem(title: item.title, action: #selector(openPathMenuItem(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = item.resolvedURL() ?? item.path
        if let icon = fileIcon(for: item) {
            menuItem.image = icon
        } else if let url = webURL(for: item) {
            if let favicon = faviconService.cachedFavicon(for: url) {
                menuItem.image = favicon
            } else {
                faviconService.fetchFavicon(for: url) { [weak self] image in
                    guard image != nil else {
                        return
                    }

                    self?.rebuildMenu()
                }
            }
        }
        return menuItem
    }

    private func webURL(for item: MenuItemDefinition) -> URL? {
        guard let url = item.resolvedURL(),
              !url.isFileURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        return url
    }

    private func fileSystemPath(from storedPath: String) -> String? {
        guard !storedPath.isEmpty else {
            return nil
        }

        if let url = URL(string: storedPath), url.isFileURL {
            return url.path
        }

        if storedPath.contains("://") {
            return nil
        }

        return storedPath
    }

    private func folderPath(for item: MenuItemDefinition) -> String? {
        guard let path = item.resolvedFilePath() else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        let isPackage = (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
        guard !isPackage else {
            return nil
        }

        return path
    }

    private func folderMenuItem(title: String, path: String) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")

        menuItem.image = sizedIcon(forFileAtPath: path)

        let submenu = NSMenu(title: title)
        submenu.delegate = self
        folderMenuContexts[ObjectIdentifier(submenu)] = FolderMenuContext(directoryPath: path, visitedDirectories: [])
        menuItem.submenu = submenu

        return menuItem
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        populateFolderSubmenu(menu)
    }

    private func populateFolderSubmenu(_ menu: NSMenu) {
        guard let context = folderMenuContexts[ObjectIdentifier(menu)] else {
            return
        }

        menu.removeAllItems()

        let resolvedPath = NSString(string: context.directoryPath).resolvingSymlinksInPath
        guard !context.visitedDirectories.contains(resolvedPath) else {
            let cycleItem = NSMenuItem(title: "(Cycle detected)", action: nil, keyEquivalent: "")
            cycleItem.isEnabled = false
            menu.addItem(cycleItem)
            return
        }

        let nextVisited = context.visitedDirectories.union([resolvedPath])

        guard let entries = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: context.directoryPath),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            let unreadableItem = NSMenuItem(title: "(Unreadable)", action: nil, keyEquivalent: "")
            unreadableItem.isEnabled = false
            menu.addItem(unreadableItem)
            return
        }

        let sortedEntries = entries.sorted { lhs, rhs in
            let lhsIsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rhsIsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if lhsIsDirectory != rhsIsDirectory {
                return lhsIsDirectory && !rhsIsDirectory
            }

            return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
        }

        if sortedEntries.isEmpty {
            let emptyItem = NSMenuItem(title: "(Empty)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
            return
        }

        for entry in sortedEntries {
            let path = entry.path
            let title = fileManager.displayName(atPath: path)
            let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let isPackage = (try? entry.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false

            let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            menuItem.image = sizedIcon(forFileAtPath: path)

            if isDirectory && !isPackage {
                let submenu = NSMenu(title: title)
                submenu.delegate = self
                folderMenuContexts[ObjectIdentifier(submenu)] = FolderMenuContext(directoryPath: path, visitedDirectories: nextVisited)
                menuItem.submenu = submenu
            } else {
                menuItem.action = #selector(openPathMenuItem(_:))
                menuItem.target = self
                menuItem.representedObject = path
            }

            menu.addItem(menuItem)
        }
    }
}
