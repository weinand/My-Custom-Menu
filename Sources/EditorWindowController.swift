// Owns and presents the editor window that embeds the SwiftUI editor view.
import AppKit
import SwiftUI

final class EditorWindowController: NSWindowController {
    init(store: MenuStore, onApply: @escaping () -> Void) {
        let rootView = EditorView(store: store, onApply: onApply)
        let contentView = NSHostingView(rootView: rootView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Configure My Custom Menu"
        window.center()
        window.contentView = contentView

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
