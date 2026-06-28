// Encapsulates editor selection and mutation logic for groups and items.
import Foundation

struct EditorCoordinator {
    func selectedGroupIndex(in configuration: MenuConfiguration, selectedGroupID: UUID?) -> Int? {
        guard let selectedGroupID else {
            return nil
        }

        return configuration.groups.firstIndex { $0.id == selectedGroupID }
    }

    func selectedItemIndex(
        in configuration: MenuConfiguration,
        selectedGroupID: UUID?,
        selectedItemID: UUID?
    ) -> Int? {
        guard let groupIndex = selectedGroupIndex(in: configuration, selectedGroupID: selectedGroupID),
              let selectedItemID else {
            return nil
        }

        return configuration.groups[groupIndex].items.firstIndex { $0.id == selectedItemID }
    }

    func syncSelectedGroup(in configuration: MenuConfiguration, selectedGroupID: UUID?) -> UUID? {
        if let selectedGroupID,
           configuration.groups.contains(where: { $0.id == selectedGroupID }) {
            return selectedGroupID
        }

        return configuration.groups.first?.id
    }

    func syncSelectedItem(
        in configuration: MenuConfiguration,
        selectedGroupID: UUID?,
        selectedItemID: UUID?
    ) -> UUID? {
        guard let groupIndex = selectedGroupIndex(in: configuration, selectedGroupID: selectedGroupID) else {
            return nil
        }

        let items = configuration.groups[groupIndex].items
        guard !items.isEmpty else {
            return nil
        }

        if let selectedItemID,
           items.contains(where: { $0.id == selectedItemID }) {
            return selectedItemID
        }

        return nil
    }

    func addGroup(to configuration: inout MenuConfiguration, title: String = "untitled") -> UUID {
        let group = MenuGroupDefinition(title: title)
        configuration.groups.append(group)
        return group.id
    }

    func updateGroupTitle(in configuration: inout MenuConfiguration, groupID: UUID, title: String) {
        guard let groupIndex = configuration.groups.firstIndex(where: { $0.id == groupID }) else {
            return
        }

        configuration.groups[groupIndex].title = title
    }

    func deleteSelectedGroup(in configuration: inout MenuConfiguration, selectedGroupID: UUID?) -> UUID? {
        guard let groupIndex = selectedGroupIndex(in: configuration, selectedGroupID: selectedGroupID) else {
            return selectedGroupID
        }

        configuration.groups.remove(at: groupIndex)

        if configuration.groups.isEmpty {
            return nil
        }

        if groupIndex < configuration.groups.count {
            return configuration.groups[groupIndex].id
        }

        return configuration.groups.last?.id
    }

    func deleteSelectedItem(
        in configuration: inout MenuConfiguration,
        selectedGroupID: UUID?,
        selectedItemID: UUID?
    ) {
        guard let groupIndex = selectedGroupIndex(in: configuration, selectedGroupID: selectedGroupID),
              let itemIndex = selectedItemIndex(
                  in: configuration,
                  selectedGroupID: selectedGroupID,
                  selectedItemID: selectedItemID
              ) else {
            return
        }

        configuration.groups[groupIndex].items.remove(at: itemIndex)
    }

    func selectedItemAfterDeletingItems(
        in configuration: MenuConfiguration,
        selectedGroupID: UUID?,
        deleting indexSet: IndexSet
    ) -> UUID? {
        guard let groupIndex = selectedGroupIndex(in: configuration, selectedGroupID: selectedGroupID) else {
            return nil
        }

        let items = configuration.groups[groupIndex].items
        let remainingItems = items.enumerated().compactMap { index, item in
            indexSet.contains(index) ? nil : item
        }

        guard !remainingItems.isEmpty else {
            return nil
        }

        let precedingIndex = min(max((indexSet.min() ?? 0) - 1, 0), remainingItems.count - 1)
        return remainingItems[precedingIndex].id
    }

    func moveItem(
        in configuration: inout MenuConfiguration,
        itemID: UUID,
        fromGroupID: UUID,
        toGroupID: UUID
    ) {
        guard fromGroupID != toGroupID,
              let sourceIndex = configuration.groups.firstIndex(where: { $0.id == fromGroupID }),
              let itemIndex = configuration.groups[sourceIndex].items.firstIndex(where: { $0.id == itemID }),
              let destinationIndex = configuration.groups.firstIndex(where: { $0.id == toGroupID }) else {
            return
        }

        let item = configuration.groups[sourceIndex].items.remove(at: itemIndex)
        configuration.groups[destinationIndex].items.append(item)
    }
}