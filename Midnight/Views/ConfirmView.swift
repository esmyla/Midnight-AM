import SwiftUI

/// "Your contract." Read it once, tweak, lock.
struct ConfirmView: View {
    @EnvironmentObject var engine: CommitmentEngine
    @Environment(\.dismiss) private var dismiss
    @State var draft: Commitment
    var onLocked: () -> Void

    @State private var newApp = ""
    @State private var showSetup = false
    @State private var showLock = false
    @State private var setupDone = Setup.isDone
    @FocusState private var appFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.clear.background(MidnightBackground(tint: Theme.accent2))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        IconButton(system: "xmark") { dismiss() }
                        Spacer()
                    }
                    .padding(.bottom, 10)

                    Text("Your contract.")
                        .display(40)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("I WILL").eyebrow()
                        Text(draft.title)
                            .display(28)
                            .padding(.top, 6)
                        if !draft.quantityLine.isEmpty, (draft.quantity ?? 0) > 1, !draft.title.localizedCaseInsensitiveContains(draft.unit ?? "\u{0}") {
                            Text(draft.quantityLine)
                                .font(.system(.subheadline).weight(.medium))
                                .foregroundStyle(Theme.accent)
                                .padding(.top, 2)
                        }
                        Divider().overlay(Theme.stroke).padding(.vertical, 16)
                        ContractRow("Starts") {
                            DatePicker("", selection: $draft.activationTime, in: Date()...).labelsHidden()
                        }
                        ContractRow("Deadline") {
                            DatePicker("", selection: $draft.deadline, in: draft.activationTime...).labelsHidden()
                        }
                        ContractRow("Proof") {
                            Picker("", selection: $draft.verification) {
                                ForEach(VerificationMethod.allCases) { Text($0.label).tag($0) }
                            }
                            .labelsHidden()
                        }
                        ContractRow("If I quit, unlock at") {
                            DatePicker("", selection: $draft.penaltyReleaseTime, displayedComponents: .hourAndMinute).labelsHidden()
                        }
                    }
                    .glass(20)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("LOCKED UNTIL THEN").eyebrow()
                            Spacer()
                            Button { showSetup = true } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: setupDone ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                    Text(setupDone ? "Automation on" : "Set up blocking")
                                }
                                .font(.system(.caption).weight(.semibold))
                                .foregroundStyle(setupDone ? Theme.mint : Theme.amber)
                            }
                        }
                        FlowLayout(spacing: 8) {
                            ForEach(draft.blockedApps, id: \.self) { app in
                                Chip(text: app, icon: "lock.fill") {
                                    withAnimation(.smooth) { draft.blockedApps.removeAll { $0 == app } }
                                }
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "plus").font(.caption.weight(.bold))
                                TextField("Add app", text: $newApp)
                                    .focused($appFieldFocused)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .submitLabel(.done)
                                    .onSubmit(addApp)
                                    .frame(width: 84)
                            }
                            .font(.system(.subheadline).weight(.medium))
                            .foregroundStyle(Theme.text2)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                        }
                    }
                    .glass(20)

                    Button(action: lock) {
                        Label("Lock it in", systemImage: "lock.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 8)

                }
                .padding(22)
            }
            .scrollDismissesKeyboard(.interactively)

            TopScrim()

            if showLock {
                LockInOverlay { onLocked() }
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
        .task { await engine.requestNotificationPermission() }
        .sheet(isPresented: $showSetup, onDismiss: { setupDone = Setup.isDone }) {
            SetupView()
        }
    }

    private func addApp() {
        let name = newApp.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              !draft.blockedApps.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { newApp = ""; return }
        Haptics.tick()
        withAnimation(.smooth) { draft.blockedApps.append(name) }
        newApp = ""
    }

    private func lock() {
        appFieldFocused = false
        Task {
            _ = await engine.lock(draft)
            withAnimation(.easeOut(duration: 0.25)) { showLock = true }
        }
    }
}

private struct ContractRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) { self.label = label; self.content = content() }
    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline))
                .foregroundStyle(Theme.text2)
            Spacer()
            content
        }
        .padding(.vertical, 6)
    }
}
