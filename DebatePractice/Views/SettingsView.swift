import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var message: String? = nil

    @AppStorage("support.lowPressure") private var lowPressure = false
    @AppStorage("support.readAloud") private var readAloud = false
    @AppStorage("support.plainLanguage") private var plainLanguage = false
    @AppStorage("support.showFillerMeter") private var showFillerMeter = true
    @AppStorage(RoomClient.serverKey) private var serverURL = ""
    @AppStorage("prefs.language") private var languageRaw = Language.english.rawValue

    @State private var key: String = Keychain.loadAPIKey() ?? ""

    var body: some View {
        NavigationStack {
            Form {
                if let message {
                    Section {
                        Text(message).foregroundStyle(Theme.danger)
                    }
                }

                Section {
                    Picker("Language", selection: $languageRaw) {
                        ForEach(Language.allCases) { Text($0.rawValue).tag($0.rawValue) }
                    }
                    Text("Every debate, congress round, and piece of feedback is written in this language.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Language")
                }

                Section {
                    Toggle(isOn: $lowPressure) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Low-pressure mode")
                            Text("A short grounding step before each round, a calmer opponent, and shorter replies. Same rigor, less intensity.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $plainLanguage) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Plain-language feedback")
                            Text("Short sentences, everyday words, jargon defined.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $readAloud) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Read replies aloud")
                            Text("Speaks each AI reply automatically. A speaker button is always available on replies and feedback.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $showFillerMeter) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show filler-word meter")
                            Text("Live presentational-accuracy bar under the composer. Turn off to reduce clutter.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Support & accessibility")
                } footer: {
                    Text("Tip: on a real iPhone, the keyboard's microphone dictates straight into the composer, so you can practice out loud and still get the filler-word score.")
                }

                Section {
                    TextField(RoomClient.defaultServer, text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Online 1v1, 2v2, and team rounds sync through the relay in the `server` folder of this project. Run `node server.js` and leave this blank for the simulator, or host it anywhere and paste its URL here so friends can join from their own phones.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Online rounds — relay server")
                }

                Section("Anthropic API key") {
                    SecureField("sk-ant-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Stored in the iOS Keychain on this device only. Get a key at console.anthropic.com.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Save key") {
                        app.setAPIKey(key)
                        dismiss()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if app.hasAPIKey {
                        Button("Remove key", role: .destructive) {
                            app.setAPIKey("")
                            key = ""
                        }
                    }
                }

                Section("Model") {
                    Text(ClaudeClient.model).font(.footnote.monospaced())
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
