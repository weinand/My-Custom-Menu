import SwiftUI

struct AddMenuAction: Identifiable {
    let id: String
    let title: String
    let action: () -> Void

    init(id: String? = nil, title: String, action: @escaping () -> Void) {
        self.id = id ?? title
        self.title = title
        self.action = action
    }
}

struct AddRemoveControlPill: View {
    let onAdd: () -> Void
    let onRemove: () -> Void
    let canRemove: Bool
    let addAccessibilityLabel: String
    let removeAccessibilityLabel: String
    var addMenuActions: [AddMenuAction] = []
    var onSubmitURLText: ((String) -> Void)?

    @State private var isShowingAddMenu = false
    @State private var urlInput = ""
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            addSegment

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 22)

            glyphButton(
                systemName: "minus",
                action: onRemove,
                isEnabled: canRemove,
                accessibilityLabel: removeAccessibilityLabel,
                horizontalOffset: 2
            )
        }
        .padding(3)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                .blendMode(.plusLighter)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
    }

    private var addSegment: some View {
        Group {
            if addMenuActions.isEmpty {
                glyphButton(
                    systemName: "plus",
                    action: onAdd,
                    isEnabled: true,
                    accessibilityLabel: addAccessibilityLabel,
                    horizontalOffset: -2
                )
            } else {
                glyphButton(
                    systemName: "plus",
                    action: { isShowingAddMenu.toggle() },
                    isEnabled: true,
                    accessibilityLabel: addAccessibilityLabel,
                    horizontalOffset: -2
                )
                .popover(isPresented: $isShowingAddMenu, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(addMenuActions) { menuAction in
                            Button(menuAction.title) {
                                isShowingAddMenu = false
                                menuAction.action()
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }

                        if let onSubmitURLText {
                            Divider()
                                .padding(.horizontal, 10)

                            HStack(spacing: 6) {
                                TextField("Enter or paste URL", text: $urlInput)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 220)
                                    .focused($isURLFieldFocused)
                                    .onSubmit {
                                        submitURLText(onSubmitURLText)
                                    }

                                Button("Add") {
                                    submitURLText(onSubmitURLText)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(6)
                    .frame(minWidth: 140)
                    .onAppear {
                        urlInput = clipboardURLString() ?? ""

                        DispatchQueue.main.async {
                            isURLFieldFocused = true
                        }
                    }
                }
            }
        }
    }

    private func clipboardURLString() -> String? {
        let pasteboard = NSPasteboard.general
        let rawValue = pasteboard.string(forType: .URL) ?? pasteboard.string(forType: .string)
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme,
              !scheme.isEmpty else {
            return nil
        }

        return trimmed
    }

    private func submitURLText(_ handler: (String) -> Void) {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        isShowingAddMenu = false
        urlInput = ""
        handler(trimmed)
    }

    private func glyphButton(
        systemName: String,
        action: @escaping () -> Void,
        isEnabled: Bool,
        accessibilityLabel: String,
        horizontalOffset: CGFloat
    ) -> some View {
        Button(action: action) {
            glyphLabel(systemName: systemName)
        }
        .offset(x: horizontalOffset)
        .buttonStyle(PillSegmentButtonStyle())
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.55))
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func glyphLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 34, height: 30)
            .contentShape(Circle())
    }
}

private struct PillSegmentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(
                        configuration.isPressed
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                    )
            )
            .clipShape(Circle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}