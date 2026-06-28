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
    var canAdd: Bool = true
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
                    isEnabled: canAdd,
                    accessibilityLabel: addAccessibilityLabel,
                    horizontalOffset: -2
                )
            } else {
                glyphButton(
                    systemName: "plus",
                    action: { isShowingAddMenu.toggle() },
                    isEnabled: canAdd,
                    accessibilityLabel: addAccessibilityLabel,
                    horizontalOffset: -2
                )
                .popover(isPresented: $isShowingAddMenu, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Add")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        ForEach(Array(addMenuActions.enumerated()), id: \.element.id) { index, menuAction in
                            if index == 0 {
                                actionRowButton(for: menuAction)
                                    .keyboardShortcut(.defaultAction)
                            } else {
                                actionRowButton(for: menuAction)
                            }
                        }

                        if let onSubmitURLText {
                            Divider()
                                .padding(.horizontal, 10)

                            HStack(spacing: 6) {
                                TextField("Enter or paste URL", text: $urlInput)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 220)
                                    .focused($isURLFieldFocused)
                                    .onTapGesture {
                                        isURLFieldFocused = true
                                    }
                                    .onSubmit {
                                        submitURLText(onSubmitURLText)
                                    }

                                Button("Add") {
                                    submitURLText(onSubmitURLText)
                                }
                                .controlSize(.small)
                                .buttonStyle(.bordered)
                                .disabled(trimmedURLInput.isEmpty)
                                .keyboardShortcut(.return, modifiers: [.command])
                            }
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(minWidth: 300)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .defaultFocus($isURLFieldFocused, true)
                    .onExitCommand {
                        isShowingAddMenu = false
                    }
                    .onAppear {
                        urlInput = clipboardURLString() ?? ""

                        DispatchQueue.main.async {
                            isURLFieldFocused = true

                            // Popovers can keep focus on the triggering button; retry shortly after presentation.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                isURLFieldFocused = true
                            }
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

    private func submitURLText(_ handler: @escaping (String) -> Void) {
        guard !trimmedURLInput.isEmpty else {
            return
        }

        let value = trimmedURLInput
        runPopoverAction {
            urlInput = ""
            handler(value)
        }
    }

    private func runPopoverAction(_ action: @escaping () -> Void) {
        isShowingAddMenu = false

        // Execute after dismissal so keyboard-triggered actions (Return) can still present modal UI.
        DispatchQueue.main.async {
            action()
        }
    }

    private var trimmedURLInput: String {
        urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func actionRowButton(for menuAction: AddMenuAction) -> some View {
        Button {
            runPopoverAction(menuAction.action)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 12, weight: .semibold))

                Text(menuAction.title)
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(TahoeMenuActionButtonStyle())
        .padding(.horizontal, 8)
    }

    private func glyphLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 34, height: 30)
            .contentShape(Circle())
    }
}

private struct TahoeMenuActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(configuration.isPressed ? 0.18 : 0), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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