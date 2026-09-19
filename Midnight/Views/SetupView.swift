import SwiftUI

/// One-time Shortcuts automation. Apple gives no API to create automations, so this is a
/// checklist with the exact taps. One automation covers every app the user wants locked.
enum Setup {
    private static let key = "setup.done.v2"
    static var isDone: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var done = Setup.isDone

    var body: some View {
        ZStack {
            Color.clear.background(MidnightBackground(tint: Theme.accent2))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { IconButton(system: "xmark") { dismiss() }; Spacer() }
                    Text("How blocking works.")
                        .display(34)
                    Text("Apple only lets apps block other apps with a paid developer account. Midnight uses a Shortcuts automation instead: every time one of your distracting apps opens, it asks Midnight whether a commitment is locked, and if so opens Midnight on top. Silent, instant, nothing to cancel. One automation, set up once, covers every app.")
                        .font(.system(.body))
                        .foregroundStyle(Theme.text2)

                    VStack(alignment: .leading, spacing: 14) {
                        step(1, "Open **Shortcuts**, tap **Automation**, then **+**. Choose **App**, select **every app** you want locked, keep **Is Opened** on, tap *Done*.")
                        step(2, "Select **Run Immediately**, turn **Notify When Run** off, tap *Next*, then **New Blank Automation**.")
                        step(3, "Add action **Get Midnight Lock Status** (search \"Midnight\").")
                        step(4, "Add action **If**. It should already read *If Lock Status*. Set the condition to **is** and type just the word **LOCKED** in the text box.")
                        step(5, "Inside the If, above *Otherwise*, add action **Open App** and pick **Midnight**. Tap *Done*.")
                    }
                    .glass(20)

                    Toggle(isOn: $done) {
                        Text("I've set up the automation")
                            .font(.system(.headline))
                    }
                    .tint(Theme.mint)
                    .glass(18)
                    .onChange(of: done) { _, v in Setup.isDone = v; Haptics.tick() }

                    Button {
                        if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
                    } label: { Label("Open Shortcuts", systemImage: "arrow.up.forward.app") }
                        .buttonStyle(PrimaryButtonStyle(tint: Theme.accent2))

                }
                .padding(22)
            }
            TopScrim()
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(n)")
                .font(.system(.subheadline).weight(.bold))
                .foregroundStyle(.black.opacity(0.85))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.accent2))
            Text(.init(text))
                .font(.system(.subheadline))
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}
