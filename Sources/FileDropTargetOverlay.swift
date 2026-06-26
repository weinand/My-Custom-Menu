// Provides a reusable visual overlay for file-drop target highlighting.
import SwiftUI

struct FileDropTargetOverlayModifier: ViewModifier {
    let isTargeted: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .background(Color.accentColor.opacity(0.08))
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func fileDropTargetOverlay(isTargeted: Bool) -> some View {
        modifier(FileDropTargetOverlayModifier(isTargeted: isTargeted))
    }
}
