// Hosts the main editor screen and orchestrates pane callbacks.
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @ObservedObject var store: MenuStore
    var onApply: () -> Void

    private let coordinator = EditorCoordinator()
    private let itemImportService = EditorItemImportService()
    private let launchAtLoginManager = LaunchAtLoginManager.shared
    private let menuTitleCharacterLimit = 3

    @State private var errorMessage: String?
    @State private var isFileDropTargeted = false
    @State private var launchAtLoginEnabled = false
    @State private var selectedGroupID: UUID?
    @State private var selectedItemID: UUID?
    @FocusState private var focusedGroupID: UUID?

    var body: some View {
        VStack(spacing: 12) {
            HSplitView {
                groupPane
                    .frame(minWidth: 220, idealWidth: 240, maxWidth: 300)

                itemPane
                    .frame(minWidth: 360)
            }

            HStack(alignment: .center, spacing: 16) {
                Text("Menu Title")
                    .font(.headline)

                TextField("Menu Bar Title", text: menuTitleBinding)
                    .frame(width: 64)

                Text("1-3 characters")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.leading, 8)
            .padding(.top, 12)

            HStack(alignment: .center, spacing: 16) {
                Text("Launch at Login")
                    .font(.headline)

                Toggle("", isOn: $launchAtLoginEnabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(!launchAtLoginManager.isConfigurable)

                Spacer()
            }
            .padding(.leading, 8)
            .padding(.top, 8)

            HStack {
                Spacer()

                Button("Apply") {
                    do {
                        if launchAtLoginEnabled != launchAtLoginManager.isEnabled {
                            try launchAtLoginManager.setEnabled(launchAtLoginEnabled)
                        }

                        try store.save()
                        errorMessage = nil
                        onApply()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 520)
        .onAppear {
            launchAtLoginEnabled = launchAtLoginManager.isEnabled
            syncSelectedGroup()
            syncSelectedItem()
        }
        .onChange(of: groupIDs) { _ in
            syncSelectedGroup()
            syncSelectedItem()
        }
        .onChange(of: selectedGroupID) { _ in
            syncSelectedItem()
        }
        .onChange(of: itemIDsInSelectedGroup) { _ in
            syncSelectedItem()
        }
    }

    private var groupIDs: [UUID] {
        store.configuration.groups.map(\.id)
    }

    private var selectedGroupIndex: Int? {
        coordinator.selectedGroupIndex(in: store.configuration, selectedGroupID: selectedGroupID)
    }

    private var itemIDsInSelectedGroup: [UUID] {
        guard let selectedGroupIndex else {
            return []
        }

        return store.configuration.groups[selectedGroupIndex].items.map(\.id)
    }

    private var selectedItemIndex: Int? {
        coordinator.selectedItemIndex(
            in: store.configuration,
            selectedGroupID: selectedGroupID,
            selectedItemID: selectedItemID
        )
    }

    private var menuTitleBinding: Binding<String> {
        Binding(
            get: { store.configuration.menuTitle },
            set: { newValue in
                store.configuration.menuTitle = String(newValue.prefix(menuTitleCharacterLimit))
            }
        )
    }

    private var groupPane: some View {
        EditorGroupPane(
            groups: store.configuration.groups,
            selectedGroupID: $selectedGroupID,
            focusedGroupID: $focusedGroupID,
            canDeleteSelectedGroup: selectedGroupIndex != nil,
            groupTitleBinding: groupTitleBinding(for:),
            onAddGroup: addGroupAction,
            onDeleteSelectedGroup: deleteSelectedGroup,
            onSelectGroup: selectGroup,
            onDropItems: handleGroupDrop(providers:into:),
            onMoveGroups: moveGroups(indices:destination:)
        )
    }

    private func addGroupAction() {
        addGroup()
    }

    private var itemPane: some View {
        EditorItemPane(
            groups: store.configuration.groups,
            selectedGroupIndex: selectedGroupIndex,
            acceptedDropTypeIdentifiers: itemImportService.supportedDropTypeIdentifiers,
            selectedItemID: $selectedItemID,
            canDeleteSelectedItem: selectedItemIndex != nil,
            isFileDropTargeted: $isFileDropTargeted,
            itemsBindingForGroupIndex: itemsBinding(for:),
            onAddItemsFromFileDialog: addItemsFromFileDialog,
            onAddURLFromText: addItem(fromURLText:),
            onDeleteSelectedItem: deleteSelectedItem,
            onSelectItem: selectItem,
            onDeleteItems: deleteItems(indexSet:groupIndex:),
            onMoveItems: moveItems(indices:destination:groupIndex:),
            onHandleItemDrop: handleItemDrop(providers:)
        )
    }

    private func selectGroup(_ groupID: UUID) {
        selectedGroupID = groupID
    }

    private func moveGroups(indices: IndexSet, destination: Int) {
        store.configuration.groups.move(fromOffsets: indices, toOffset: destination)
    }

    private func selectItem(_ itemID: UUID) {
        selectedItemID = itemID
    }

    private func deleteItems(indexSet: IndexSet, groupIndex: Int) {
        selectedItemID = coordinator.selectedItemAfterDeletingItems(
            in: store.configuration,
            selectedGroupID: selectedGroupID,
            deleting: indexSet
        )
        store.configuration.groups[groupIndex].items.remove(atOffsets: indexSet)
    }

    private func moveItems(indices: IndexSet, destination: Int, groupIndex: Int) {
        store.configuration.groups[groupIndex].items.move(fromOffsets: indices, toOffset: destination)
        syncSelectedItem()
    }

    private func syncSelectedGroup() {
        selectedGroupID = coordinator.syncSelectedGroup(in: store.configuration, selectedGroupID: selectedGroupID)
    }

    private func addGroup(selecting title: String = "untitled") {
        let groupID = coordinator.addGroup(to: &store.configuration, title: title)
        selectedGroupID = groupID
        focusedGroupID = groupID
    }

    private func syncSelectedItem() {
        selectedItemID = coordinator.syncSelectedItem(
            in: store.configuration,
            selectedGroupID: selectedGroupID,
            selectedItemID: selectedItemID
        )
    }

    private func updateGroupTitle(groupID: UUID, title: String) {
        coordinator.updateGroupTitle(in: &store.configuration, groupID: groupID, title: title)
    }

    private func groupTitleBinding(for groupID: UUID) -> Binding<String> {
        Binding(
            get: {
                store.configuration.groups.first(where: { $0.id == groupID })?.title ?? ""
            },
            set: { newValue in
                updateGroupTitle(groupID: groupID, title: newValue)
            }
        )
    }

    private func deleteSelectedGroup() {
        selectedGroupID = coordinator.deleteSelectedGroup(
            in: &store.configuration,
            selectedGroupID: selectedGroupID
        )
    }

    private func deleteSelectedItem() {
        guard let selectedGroupIndex,
              let selectedItemIndex else {
            return
        }

        selectedItemID = coordinator.selectedItemAfterDeletingItems(
            in: store.configuration,
            selectedGroupID: selectedGroupID,
            deleting: IndexSet(integer: selectedItemIndex)
        )

        store.configuration.groups[selectedGroupIndex].items.remove(at: selectedItemIndex)
    }

    private func ensureSelectedGroupIndex() -> Int {
        if let selectedGroupIndex {
            return selectedGroupIndex
        }

        addGroup()
        return store.configuration.groups.count - 1
    }

    private func itemsBinding(for groupIndex: Int) -> Binding<[MenuItemDefinition]> {
        Binding(
            get: { store.configuration.groups[groupIndex].items },
            set: { store.configuration.groups[groupIndex].items = $0 }
        )
    }

    private func handleItemDrop(providers: [NSItemProvider]) -> Bool {
        itemImportService.loadDroppedItemURLs(
            from: providers,
            onURL: handleDroppedURL,
            onError: handleDropError
        )
    }

    private func handleDroppedURL(_ url: URL) {
        DispatchQueue.main.async {
            appendMenuItems(from: [url])
            errorMessage = nil
        }
    }

    private func handleDropError(_ message: String) {
        DispatchQueue.main.async {
            errorMessage = message
        }
    }

    private func addItemsFromFileDialog() {
        guard let urls = itemImportService.chooseFileSystemURLs() else {
            return
        }

        appendMenuItems(from: urls)
    }

    private func addItem(fromURLText text: String) {
        guard let item = itemImportService.makeMenuItem(fromURLString: text) else {
            errorMessage = "Please enter a valid URL."
            return
        }

        appendMenuItems([item])
        errorMessage = nil
    }

    private func appendMenuItems(from urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        let items = itemImportService.makeMenuItems(from: urls)

        appendMenuItems(items)
    }

    private func appendMenuItems(_ items: [MenuItemDefinition]) {
        guard !items.isEmpty else {
            return
        }

        let groupIndex = ensureSelectedGroupIndex()

        store.configuration.groups[groupIndex].items.append(contentsOf: items)
        syncSelectedItem()
    }

    private func handleGroupDrop(providers: [NSItemProvider], into destinationGroupID: UUID) -> Bool {
        let matchingProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.editorItemDragPayload.identifier)
        }
        guard !matchingProviders.isEmpty else {
            return false
        }

        for provider in matchingProviders {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.editorItemDragPayload.identifier) { data, error in
                if let error {
                    DispatchQueue.main.async {
                        errorMessage = error.localizedDescription
                    }
                    return
                }

                guard let data,
                      let dragInfo = EditorItemDragPayload.decode(from: data) else {
                    DispatchQueue.main.async {
                        errorMessage = "Dropped item data is invalid or unsupported."
                    }
                    return
                }

                DispatchQueue.main.async {
                    moveItem(itemID: dragInfo.itemID, fromGroupID: dragInfo.sourceGroupID, toGroupID: destinationGroupID)
                }
            }
        }

        return true
    }

    private func moveItem(itemID: UUID, fromGroupID: UUID, toGroupID: UUID) {
        coordinator.moveItem(
            in: &store.configuration,
            itemID: itemID,
            fromGroupID: fromGroupID,
            toGroupID: toGroupID
        )
    }
}
