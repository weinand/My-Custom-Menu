// Defines the typed, versioned payload used for item drag-and-drop.
import Foundation
import UniformTypeIdentifiers

struct EditorItemDragPayload: Codable {
    static let currentVersion = 1

    let version: Int
    let itemID: UUID
    let sourceGroupID: UUID

    init(itemID: UUID, sourceGroupID: UUID, version: Int = EditorItemDragPayload.currentVersion) {
        self.version = version
        self.itemID = itemID
        self.sourceGroupID = sourceGroupID
    }

    var encodedData: Data? {
        try? JSONEncoder().encode(self)
    }

    static func decode(from data: Data) -> EditorItemDragPayload? {
        guard let decoded = try? JSONDecoder().decode(EditorItemDragPayload.self, from: data),
              decoded.version == currentVersion else {
            return nil
        }

        return decoded
    }
}

extension UTType {
    static let editorItemDragPayload = UTType(exportedAs: "com.local.MyCustomMenu.editor-item-drag-payload")
}
