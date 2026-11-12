import MarginCore
import SwiftUI

/// Five-step welcome tour: what Margin is, the chat shortcut (animated), connecting, shortcuts, privacy.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("onboarded") private var onboarded = false
    @State private var step: Int
    @State private var forward = true
    private let count = 5

    init(startStep: Int = 0) { _step = State(initialValue: startStep) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Group {
                    switch step {
                    case 0: WelcomeStep()
                    case 1: ChatDemoStep()
                    case 2: ConnectStep()
                    case 3: ShortcutsStep()
                    default: DoneStep()
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            HStack {
                Button("Skip") { finish() }.buttonStyle(.plain).foregroundStyle(.secondary)
                    .opacity(step < count - 1 ? 1 : 0)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { i in
                        Capsule().fill(Color(palette: i == step ? Palette.accent : Palette.hairline))
                            .frame(width: i == step ? 22 : 7, height: 7)
                    }
                }
                .animation(.spring(duration: 0.4, bounce: 0.3), value: step)
                Spacer()
                HStack(spacing: 8) {
                    if step > 0 {
                        Button("Back") { go(-1) }.buttonStyle(.bordered)
                    }
                    Button(step == count - 1 ? "Start using Margin" : "Continue") {
                        step == count - 1 ? finish() : go(1)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 720, height: 520)
        .background(Color(palette: Palette.canvas))
        .tint(Color(palette: Palette.accent))
    }

    private func go(_ delta: Int) {
        forward = delta > 0
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        withAnimation(.spring(duration: 0.5, bounce: 0.15)) { step = max(0, min(count - 1, step + delta)) }
    }

    private func finish() {
        onboarded = true
        dismiss()
    }
}

// MARK: Steps

private struct StepTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 26, weight: .semibold)).multilineTextAlignment(.center)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 480)
        }
    }
}

private struct WelcomeStep: View {
    @State private var shown = false
    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                ForEach(0..<3) { i in
                    MiniCard(lines: [0.8, 0.55, 0.65], accent: i == 1)
                        .rotationEffect(.degrees(Double(i - 1) * 9))
                        .offset(x: CGFloat(i - 1) * 70, y: shown ? CGFloat(abs(i - 1)) * 10 : 60)
                        .opacity(shown ? 1 : 0)
                        .animation(.spring(duration: 0.8, bounce: 0.35).delay(0.15 + Double(i) * 0.12), value: shown)
                }
                Image(systemName: "text.append")
                    .font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(palette: Palette.accent)))
                    .shadow(color: Color(palette: Palette.accent).opacity(0.35), radius: 14, y: 6)
                    .scaleEffect(shown ? 1 : 0.4)
                    .offset(y: -78)
                    .animation(.spring(duration: 0.7, bounce: 0.5), value: shown)
            }
            .frame(height: 190)
            StepTitle(title: "Welcome to Margin", subtitle: "The notes app your AI writes into. Say it in Claude, find it here, on your Mac and iPhone.")
        }
        .onAppear { shown = true }
    }
}

private struct ChatDemoStep: View {
    @State private var typed = ""
    @State private var showNote = false
    @State private var showCheck = false
    private var full: String { "\(MarginSettings.load().smartPrefix) " + String(localized: "add SQL to my skills") }

    var body: some View {
        VStack(spacing: 26) {
            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 0) {
                        Text(typed).font(.system(size: 14, design: .monospaced))
                        Rectangle().fill(Color(palette: Palette.accent)).frame(width: 2, height: 16).opacity(showNote ? 0 : 1)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(palette: Palette.accentWash)))
                    if showCheck {
                        Label("Saved to Career › Skills", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12)).foregroundStyle(Color(palette: Palette.accent))
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .frame(width: 280, alignment: .trailing)
                Image(systemName: "arrow.right").foregroundStyle(.tertiary).opacity(showNote ? 1 : 0.2)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skills").font(.system(size: 15, weight: .semibold))
                    checkRow("System design", fresh: false)
                    checkRow("Public speaking", fresh: false)
                    if showNote {
                        checkRow("SQL", fresh: true).transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(16)
                .frame(width: 220, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(palette: Palette.card)))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(palette: showNote ? Palette.accentBorder : Palette.hairline), lineWidth: showNote ? 1.2 : 0.5))
            }
            .frame(height: 190)
            StepTitle(title: "Just say it in chat", subtitle: "Start a message with your shortcut and Claude files it into the right note, without asking.")
        }
        .task { await play() }
    }

    private func checkRow(_ text: LocalizedStringKey, fresh: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4).strokeBorder(Color(palette: Palette.tertiary), lineWidth: 1.3).frame(width: 14, height: 14)
            Text(text).font(.system(size: 13))
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color(palette: fresh ? Palette.accentWash : .clear)))
    }

    private func play() async {
        while !Task.isCancelled {
            typed = ""; showNote = false; showCheck = false
            try? await Task.sleep(for: .milliseconds(500))
            for ch in full {
                typed.append(ch)
                try? await Task.sleep(for: .milliseconds(55))
            }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(duration: 0.55, bounce: 0.35)) { showNote = true }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(duration: 0.4)) { showCheck = true }
            try? await Task.sleep(for: .seconds(2.6))
        }
    }
}

private struct ConnectStep: View {
    @State private var connection = ClaudeConnection()
    var body: some View {
        VStack(spacing: 22) {
            StepTitle(title: "Connect your AI", subtitle: "One click. Margin adds itself to Claude; Gemini CLI, Cursor, VS Code and Codex are in Settings.")
            VStack(spacing: 6) {
                ConnectionRow(title: "Claude Code", detail: "Code tab in the Claude app, and the terminal", symbol: "chevron.left.forwardslash.chevron.right", client: .claudeCode, connection: connection)
                Divider()
                ConnectionRow(title: "Claude Desktop and Cowork", detail: "Claude restarts once to load Margin", symbol: "sparkles", client: .claudeDesktop, connection: connection)
            }
            .padding(16)
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(palette: Palette.card)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(palette: Palette.hairline), lineWidth: 0.5))
            if let error = connection.lastError { Text(error).font(.callout).foregroundStyle(.red) }
        }
        .onAppear { connection.refresh() }
    }
}

private struct ShortcutsStep: View {
    @State private var settings = MarginSettings.load()
    var body: some View {
        VStack(spacing: 22) {
            StepTitle(title: "Make the shortcuts yours", subtitle: "Change them any time in Settings › Shortcuts.")
            VStack(spacing: 14) {
                row(symbol: "sparkles", title: "Smart save", detail: "Claude files it into the right note", value: $settings.smartPrefix)
                row(symbol: "bolt", title: "Instant capture", detail: "Saved word for word, never sent to Claude", value: $settings.instantPrefix)
                HStack(spacing: 12) {
                    icon("keyboard")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick note window").font(.system(size: 13, weight: .medium))
                        Text("Jot something down from any app").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HotkeyRecorder()
                }
            }
            .padding(18)
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(palette: Palette.card)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(palette: Palette.hairline), lineWidth: 0.5))
        }
        .onChange(of: settings) { _, new in if new.sanitized() == new { try? new.save() } }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 14)).foregroundStyle(Color(palette: Palette.accent))
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(palette: Palette.accentWash)))
    }

    private func row(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey, value: Binding<String>) -> some View {
        HStack(spacing: 12) {
            icon(symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            TextField("", text: value).textFieldStyle(.roundedBorder).frame(width: 80).font(.system(.body, design: .monospaced))
        }
    }
}

private struct DoneStep: View {
    @State private var burst = false
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<14, id: \.self) { i in
                    let angle = Double(i) / 14 * 2 * .pi
                    Circle()
                        .fill(TopicStyle.colors[i % TopicStyle.colors.count].color)
                        .frame(width: 8, height: 8)
                        .offset(x: burst ? cos(angle) * 90 : 0, y: burst ? sin(angle) * 90 : 0)
                        .opacity(burst ? 0 : 1)
                        .animation(.easeOut(duration: 1.1).delay(0.25), value: burst)
                }
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(Color(palette: Palette.accent)))
                    .scaleEffect(burst ? 1 : 0.3)
                    .animation(.spring(duration: 0.6, bounce: 0.55), value: burst)
            }
            .frame(height: 200)
            StepTitle(title: "You're all set", subtitle: "Your notes are plain Markdown files on your Mac. Every AI change can be undone, and you can lock Margin with Touch ID in Settings.")
        }
        .onAppear {
            burst = true
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }
}

struct MiniCard: View {
    let lines: [CGFloat]
    var accent = false
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 3).fill(Color(palette: Palette.text).opacity(0.75)).frame(width: 70, height: 7)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, w in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(Color(palette: Palette.tertiary), lineWidth: 1).frame(width: 8, height: 8)
                    RoundedRectangle(cornerRadius: 2).fill(Color(palette: Palette.tertiary).opacity(0.5)).frame(width: 90 * w, height: 5)
                }
            }
        }
        .padding(14)
        .frame(width: 140, height: 104, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(palette: accent ? Palette.accentWash : Palette.card)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(palette: accent ? Palette.accentBorder : Palette.hairline), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }
}
