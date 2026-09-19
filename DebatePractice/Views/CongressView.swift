import SwiftUI

struct CongressView: View {
    @State private var search = ""

    private func filtered(_ chamber: Chamber) -> [Committee] {
        committees.filter { $0.chamber == chamber && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.jurisdiction.localizedCaseInsensitiveContains(search)) }
    }

    var body: some View {
        List {
            Section {
                Text("Pick your committee. Each one has its jurisdiction, the agencies it oversees, where to find reliable numbers, an AI briefing you can save, and practice legislation to debate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(Chamber.allCases, id: \.self) { chamber in
                Section(chamber.rawValue) {
                    ForEach(filtered(chamber)) { committee in
                        NavigationLink(value: Route.committee(committee)) {
                            HStack(spacing: 12) {
                                Image(systemName: "building.columns")
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(committee.name)
                                    Text(committee.jurisdiction)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search committees")
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Model Congress")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CommitteeDetailView: View {
    let committee: Committee

    @EnvironmentObject private var app: AppState
    @AppStorage("support.lowPressure") private var lowPressure = false
    @AppStorage("support.plainLanguage") private var plainLanguage = false

    @State private var briefing: String?
    @State private var isGenerating = false
    @State private var briefingError: String?
    @State private var billChoice: String = ""
    @State private var useCustomBill = false
    @State private var customBill = ""
    @State private var side: Side = .affirmative
    @State private var language: Language = .english
    @State private var difficulty: Difficulty = .medium
    @State private var showSettings = false

    private var resolvedBill: String {
        useCustomBill ? customBill.trimmingCharacters(in: .whitespacesAndNewlines) : billChoice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                referenceSection
                briefingSection
                practiceSection
            }
            .padding(20)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(committee.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            SettingsView(message: "Add an Anthropic API key to use briefings and practice rounds.")
        }
        .onAppear {
            if billChoice.isEmpty { billChoice = committee.bills[0] }
            briefing = try? app.sessions.briefing(for: committee)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(committee.chamber.rawValue).font(.caption).foregroundStyle(.secondary)
            Text(committee.fullName).font(.title3.weight(.semibold)).foregroundStyle(Theme.accent)
            Text(committee.jurisdiction).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .card(fill: Theme.tint)
    }

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Agencies it oversees")
            FlowChips(items: committee.agencies)

            SectionLabel(text: "Where to find reliable numbers").padding(.top, 6)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(committee.sources, id: \.self) { source in
                    Label(source, systemImage: "checkmark.seal")
                        .font(.subheadline)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Committee briefing")
                Spacer()
                if let briefing {
                    ReadAloudButton(text: briefing, language: .english)
                }
            }
            if isGenerating {
                ProgressView("Preparing briefing…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if let briefing {
                Text(briefing)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                Text("Numbers marked (verify) are approximate — check them against the sources above before you cite them at the podium.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Regenerate briefing") { generate() }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
            } else {
                Text("Get a saved briefing: the live policy fights in this committee, the strongest argument on each side, figures worth knowing, and where to verify them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Generate briefing") { generate() }
                    .buttonStyle(.borderedProminent)
            }
            if let briefingError {
                Text(briefingError).font(.footnote).foregroundStyle(Theme.danger)
            }
        }
    }

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Legislation to debate")
                ForEach(committee.bills, id: \.self) { bill in
                    OptionCard(title: bill, selected: !useCustomBill && billChoice == bill) {
                        useCustomBill = false
                        billChoice = bill
                    }
                }
                OptionCard(title: "Write my own bill", subtitle: useCustomBill ? nil : "Any title in the form \"A Bill to…\"", icon: "pencil", selected: useCustomBill) {
                    useCustomBill = true
                }
                if useCustomBill {
                    TextField("A Bill to…", text: $customBill, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(12)
                        .card()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Your side")
                HStack(spacing: 8) {
                    ForEach(Side.allCases) { s in
                        Chip(label: s == .affirmative ? "Affirm the bill" : "Negate the bill", selected: side == s) { side = s }
                    }
                }
            }

            ChoiceSections(language: $language, difficulty: $difficulty)

            Button {
                start()
            } label: {
                Text("Start Congress Round")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(resolvedBill.isEmpty)
        }
    }

    private func generate() {
        guard app.hasAPIKey else { showSettings = true; return }
        isGenerating = true
        briefingError = nil
        Task {
            do {
                let text = try await app.claude.committeeBriefing(committee)
                try app.sessions.saveBriefing(text, for: committee)
                briefing = text
            } catch {
                briefingError = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func start() {
        guard !resolvedBill.isEmpty else { return }
        guard app.hasAPIKey else { showSettings = true; return }
        var config = PracticeConfig(kind: .congress, topic: resolvedBill, language: language, difficulty: difficulty, mode: .congress)
        config.userSide = side
        config.committee = committee.fullName
        config.lowPressure = lowPressure
        config.plainLanguage = plainLanguage
        app.path.append(Route.session(config))
    }
}

struct FlowChips: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.border))
            }
        }
    }
}
