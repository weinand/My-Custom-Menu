// Renders and manages the groups pane used by the menu editor.
import SwiftUI
import UniformTypeIdentifiers

struct EditorGroupPane: View {
    let groups: [MenuGroupDefinition]
    @Binding var selectedGroupID: UUID?
    @FocusState.Binding var focusedGroupID: UUID?
    let canDeleteSelectedGroup: Bool
    let groupTitleBinding: (UUID) -> Binding<String>
    let onAddGroup: () -> Void
    let onDeleteSelectedGroup: () -> Void
    let onSelectGroup: (UUID) -> Void
    let onDropItems: ([NSItemProvider], UUID) -> Bool
    let onMoveGroups: (IndexSet, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("Groups")
                    .font(.headline)

                Button("+") {
                    onAddGroup()
                }
                .buttonStyle(.borderless)

                Button("–") {
                    onDeleteSelectedGroup()
                }
                .buttonStyle(.borderless)
                .disabled(!canDeleteSelectedGroup)

                Spacer()
            }
            .padding(.leading, 8)

            List(selection: $selectedGroupID) {
                if groups.isEmpty {
                    Text("No groups yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(groups.indices, id: \.self) { index in
                        EditorGroupRow(
                            groupTitle: groupTitleBinding(groups[index].id),
                            groupID: groups[index].id,
                            focusedGroupID: $focusedGroupID,
                            onSelect: {
                                onSelectGroup(groups[index].id)
                            },
                            onDropItems: { providers in
                                onDropItems(providers, groups[index].id)
                            }
                        )
                        .tag(groups[index].id)
                    }
                    .onMove(perform: onMoveGroups)
                }
            }
            .padding(.leading, 0)
        }
    }
}

private struct EditorGroupRow: View {
    @Binding var groupTitle: String
    let groupID: UUID
    @FocusState.Binding var focusedGroupID: UUID?
    let onSelect: () -> Void
    let onDropItems: ([NSItemProvider]) -> Bool
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 8) {
            TextField("untitled", text: $groupTitle)
                .textFieldStyle(.plain)
                .focused($focusedGroupID, equals: groupID)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onDrop(of: [UTType.editorItemDragPayload.identifier], isTargeted: $isDropTargeted, perform: onDropItems)
    }
}
