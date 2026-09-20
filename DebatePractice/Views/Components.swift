import SwiftUI

struct OptionCard: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(selected ? Color.white : Theme.accent)
                        .frame(width: 36, height: 36)
                        .background(selected ? Theme.accent : Theme.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.accent : Theme.border)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.tint : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Theme.accent : Theme.border, lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct Chip: View {
    let label: String
    var icon: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.footnote) }
                Text(label).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? Theme.accent : Theme.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(selected ? Theme.accent : Theme.border))
        }
        .buttonStyle(.plain)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(value).font(.title.weight(.semibold))
            Text(label).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card()
    }
}

struct MeterBar: View {
    let metrics: SpeechMetrics
    var title: String = "Presentational accuracy"
    var compact: Bool = false

    private func color(_ value: Int) -> Color {
        value >= 90 ? Theme.accent : value >= 75 ? Theme.sandText : Theme.danger
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(metrics.overall)%").font(.caption.weight(.semibold)).foregroundStyle(color(metrics.overall))
            }
            ProgressView(value: Double(metrics.overall) / 100)
                .tint(color(metrics.overall))
            row("Filler words", metrics.fillerScore, metrics.fillerSummary)
            row("Smoothness", metrics.smoothness, metrics.smoothnessSummary)
            row("Tone", metrics.tone, metrics.toneSummary)
        }
    }

    private func row(_ label: String, _ value: Int, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 78, alignment: .leading)
                ProgressView(value: Double(value) / 100).tint(color(value))
                Text("\(value)").font(.caption2.monospacedDigit()).foregroundStyle(color(value)).frame(width: 26, alignment: .trailing)
            }
            if !compact {
                Text(note).font(.caption2).foregroundStyle(.secondary).padding(.leading, 86)
            }
        }
    }
}

struct JoinRoomSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var name = ""
    @State private var isJoining = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Room code") {
                    TextField("ABC123", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.title3.monospaced())
                }
                Section("Your name") {
                    TextField("Shown to the other debaters", text: $name)
                }
                if let error {
                    Section { Text(error).foregroundStyle(Theme.danger) }
                }
                Section {
                    Button(isJoining ? "Joining…" : "Join round") { join() }
                        .disabled(isJoining || code.trimmingCharacters(in: .whitespaces).count < 4 || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    Text("Ask the host for the six-character code on their screen. Relay server: \(RoomClient.serverURL)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Join a round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .onAppear { if name.isEmpty { name = app.currentUser?.username ?? "" } }
        }
    }

    private func join() {
        isJoining = true
        error = nil
        Task {
            do {
                let (room, playerId) = try await RoomClient().join(code: code.trimmingCharacters(in: .whitespaces), name: name.trimmingCharacters(in: .whitespaces))
                dismiss()
                app.push(.onlineSession(room.code, playerId))
            } catch {
                self.error = error.localizedDescription
            }
            isJoining = false
        }
    }
}

struct ReadAloudButton: View {
    let text: String
    let language: Language

    var body: some View {
        Button {
            Speaker.shared.speak(text, language: language)
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(.footnote)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .accessibilityLabel("Read aloud")
    }
}
