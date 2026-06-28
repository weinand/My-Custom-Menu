// Renders and manages the items pane used by the menu editor.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorItemPane: View {
    let groups: [MenuGroupDefinition]
    let selectedGroupIndex: Int?
    let acceptedDropTypeIdentifiers: [String]
    @Binding var selectedItemID: UUID?
    let canAddItem: Bool
    let canDeleteSelectedItem: Bool
    @Binding var isFileDropTargeted: Bool
    let itemsBindingForGroupIndex: (Int) -> Binding<[MenuItemDefinition]>
    let onAddItemsFromFileDialog: () -> Void
    let onAddURLFromText: (String) -> Void
    let onDeleteSelectedItem: () -> Void
    let onSelectItem: (UUID) -> Void
    let onDeleteItems: (IndexSet, Int) -> Void
    let onMoveItems: (IndexSet, Int, Int) -> Void
    let onHandleItemDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("Items")
                    .font(.headline)

                AddRemoveControlPill(
                    onAdd: onAddItemsFromFileDialog,
                    onRemove: onDeleteSelectedItem,
                    canAdd: canAddItem,
                    canRemove: canDeleteSelectedItem,
                    addAccessibilityLabel: "Add item",
                    removeAccessibilityLabel: "Remove item",
                    addMenuActions: [
                        AddMenuAction(id: "add-file", title: "Select File", action: onAddItemsFromFileDialog)
                    ],
                    onSubmitURLText: onAddURLFromText
                )

                Spacer()
            }
            .padding(.leading, 8)

            if let groupIndex = selectedGroupIndex {
                itemDropSurface {
                    itemList(groupIndex: groupIndex)
                }

                Text("Drag a document or app here to create a menu item that opens it with open.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("You can also drag a website URL from your browser.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                itemDropSurface {
                    emptyState
                }
            }
        }
    }

    private func itemDropSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .fileDropTargetOverlay(isTargeted: isFileDropTargeted)
            .onDrop(of: acceptedDropTypeIdentifiers, isTargeted: $isFileDropTargeted, perform: onHandleItemDrop)
    }

    private func itemList(groupIndex: Int) -> some View {
        let groupID = groups[groupIndex].id
        let itemsBinding = itemsBindingForGroupIndex(groupIndex)

        return List(selection: $selectedItemID) {
            ForEach(itemsBinding.indices, id: \.self) { index in
                EditorItemRow(
                    item: itemsBinding[index],
                    sourceGroupID: groupID,
                    onSelect: {
                        onSelectItem(itemsBinding.wrappedValue[index].id)
                    }
                )
                .tag(itemsBinding.wrappedValue[index].id)
            }
            .onDelete { indexSet in
                onDeleteItems(indexSet, groupIndex)
            }
            .onMove { indices, destination in
                onMoveItems(indices, destination, groupIndex)
            }
        }
        .padding(.leading, 0)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select or create a group to view its items.")
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 8)
        .padding(.top, 4)
    }
}

private struct EditorItemRow: View {
    @Binding var item: MenuItemDefinition
    let sourceGroupID: UUID
    let onSelect: () -> Void
    @State private var favicon: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            if let icon = displayIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 18, height: 18)
            }

            TextField("Item Name", text: $item.title)
                .textFieldStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onAppear(perform: loadFavicon)
        .onChange(of: item.path) { _ in
            loadFavicon()
        }
        .onDrag {
            dragProvider
        }
    }

    private var displayIcon: NSImage? {
        fileIcon ?? favicon
    }

    private var fileIcon: NSImage? {
        guard let path = item.resolvedFilePath() else {
            return nil
        }

        return NSWorkspace.shared.icon(forFile: path)
    }

    private func loadFavicon() {
        guard fileIcon == nil,
              let url = item.resolvedURL(),
              !url.isFileURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            favicon = nil
            return
        }

        if let cached = FaviconService.shared.cachedFavicon(for: url) {
            favicon = cached
            return
        }

        FaviconService.shared.fetchFavicon(for: url) { image in
            favicon = image
        }
    }

    private var dragProvider: NSItemProvider {
        let provider = NSItemProvider()

        if let data = EditorItemDragPayload(itemID: item.id, sourceGroupID: sourceGroupID).encodedData {
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.editorItemDragPayload.identifier,
                visibility: .all
            ) { completion in
                completion(data, nil)
                return nil
            }
        }

        return provider
    }
}
