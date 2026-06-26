// Coordinates app startup, controller wiring, and startup error alerts.
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = MenuStore()
    private var menuBarController: MenuBarController?
    private var editorController: EditorWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.load()

        if let loadErrorMessage = store.consumeLastLoadErrorMessage() {
            showLoadErrorAlert(message: loadErrorMessage)
        }

        menuBarController = MenuBarController(store: store, onEdit: { [weak self] in
            self?.showEditor()
        })

        editorController = EditorWindowController(store: store, onApply: { [weak self] in
            self?.menuBarController?.rebuildMenu()
            self?.editorController?.window?.close()
        })

        menuBarController?.rebuildMenu()
    }

    private func showEditor() {
        editorController?.show()
    }

    private func showLoadErrorAlert(message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "My Custom Menu could not load menu.json"
        alert.informativeText = message
        alert.addButton(withTitle: "Open Config Folder")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let folderURL = store.configURL.deletingLastPathComponent()
            NSWorkspace.shared.activateFileViewerSelecting([folderURL])
        }
    }
}
