import SwiftUI
import UniformTypeIdentifiers

struct CongressView: View {
    @State private var search = ""

    private var filtered: [Committee] {
        committees.filter {
            search.isEmpty
            || $0.name.localizedCaseInsensitiveContains(search)
            || $0.jurisdiction.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pick your committee. Each one lists its jurisdiction, the agencies it oversees, links to the data sources members actually cite, and legislation to debate.")
                    .subtext(.footnote)
                    .padding(.bottom, 4)

                SectionLabel(text: "Committees")

                ForEach(filtered) { committee in
                    NavigationLink(value: Route.committee(committee)) {
                        CommitteeRow(committee: committee)
                    }
                    .buttonStyle(.plain)
                }

                if filtered.isEmpty {
                    Text("No committee matches that search.")
                        .subtext(.subheadline)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                }
            }
            .padding(20)
            .padding(.bottom, 60)
        }
        .background(Theme.background)
        .searchable(text: $search, prompt: "Search committees")
        .navigationTitle("Model Congress")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CommitteeRow: View {
    let committee: Committee

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "building.columns")
                .font(.brand(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42)
                .background(Theme.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(committee.name)
                    .font(.brand(.body, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                    .multilineTextAlignment(.leading)
                Text(committee.chamber)
                    .font(.brand(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(committee.jurisdiction)
                    .subtext(.caption)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.brand(.caption, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(Rectangle())
    }
}

struct CommitteeDetailView: View {
    let committee: Committee

    @EnvironmentObject private var app: AppState
    @AppStorage("support.lowPressure") private var lowPressure = false
    @AppStorage("support.plainLanguage") private var plainLanguage = false
    @AppStorage("prefs.language") private var languageRaw = Language.english.rawValue

    @State private var billChoice: String = ""
    @State private var uploadedText = ""
    @State private var uploadedName = ""
    @State private var uploadedTitle = ""
    @State private var useUpload = false
    @State private var showImporter = false
    @State private var importError: String?
    @State private var showStats = false
    @State private var side: Side = .affirmative
    @State private var difficulty: Difficulty = .medium
    @State private var showSettings = false

    private var resolvedBill: String {
        useUpload ? uploadedTitle : billChoice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                referenceSection
                legislationSection
                sideSection
                ChoiceSections(difficulty: $difficulty)
                formatSection

                Button {
                    start()
                } label: {
                    Text("Start Congress Round")
                }
                .buttonStyle(.borderedProminent)
                .disabled(resolvedBill.isEmpty)
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(committee.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) {
            SettingsView(message: "Add an Anthropic API key to start a round.")
        }
        .sheet(isPresented: $showStats) {
            StatLookupSheet(committee: committee, language: Language(rawValue: languageRaw) ?? .english)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: DocumentText.allowedTypes) { result in
            handleImport(result)
        }
        .onAppear { if billChoice.isEmpty { billChoice = committee.bills[0] } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(committee.chamber).font(.brand(.caption)).foregroundStyle(Theme.secondaryText)
            Text(committee.fullName).font(.brand(.title3, weight: .semibold)).foregroundStyle(Theme.accent)
            Text(committee.jurisdiction).font(.brand(.subheadline))
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
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(committee.sources.enumerated()), id: \.element.id) { index, source in
                    if index > 0 { Divider() }
                    Link(destination: URL(string: source.url) ?? URL(string: "https://www.congress.gov")!) {
                        HStack(spacing: 10) {
                            Image(systemName: "link")
                                .font(.brand(.footnote))
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.title)
                                    .font(.brand(.subheadline))
                                    .foregroundStyle(Color.primary)
                                Text(source.url.replacingOccurrences(of: "https://", with: ""))
                                    .subtext(.caption2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right.square")
                                .font(.brand(.footnote))
                                .foregroundStyle(Theme.secondaryText.opacity(0.65))
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            Button {
                guard app.hasAPIKey else { showSettings = true; return }
                showStats = true
            } label: {
                Label("Look up a statistic", systemImage: "chart.bar.doc.horizontal")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            Text("Pull a figure for this committee's area with its source, so you can check it before using it at the podium.")
                .subtext(.caption)
        }
    }

    private var legislationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Legislation to debate")
            ForEach(committee.bills, id: \.self) { bill in
                OptionCard(title: bill, selected: !useUpload && billChoice == bill) {
                    useUpload = false
                    billChoice = bill
                }
            }

            OptionCard(title: uploadedName.isEmpty ? "Upload a bill" : uploadedTitle,
                       subtitle: uploadedName.isEmpty
                        ? "PDF, DOCX, TXT, RTF, or Markdown. The text is read and given to your opponent and the parliamentarian."
                        : "\(uploadedName) · \(uploadedText.count) characters read",
                       icon: "doc.badge.arrow.up",
                       selected: useUpload) {
                if uploadedText.isEmpty { showImporter = true } else { useUpload = true }
            }

            HStack(spacing: 10) {
                Button(uploadedText.isEmpty ? "Choose file" : "Replace file") { showImporter = true }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                if !uploadedText.isEmpty {
                    Button("Remove", role: .destructive) {
                        uploadedText = ""
                        uploadedName = ""
                        uploadedTitle = ""
                        useUpload = false
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let importError {
                Text(importError).font(.brand(.footnote)).foregroundStyle(Theme.danger)
            }

            if useUpload && !uploadedText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bill title used in the round").font(.brand(.caption, weight: .semibold)).foregroundStyle(Theme.secondaryText)
                    TextField("A Bill to…", text: $uploadedTitle, axis: .vertical)
                        .lineLimit(1...3)
                        .field()
                    DisclosureGroup("Preview the text that was read") {
                        Text(uploadedText.prefix(1500) + (uploadedText.count > 1500 ? "…" : ""))
                            .subtext(.caption)
                            .textSelection(.enabled)
                            .padding(.top, 6)
                    }
                    .font(.brand(.caption, weight: .semibold))
                    .tint(Theme.accent)
                }
            }
        }
    }

    private var sideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Your side")
            HStack(spacing: 8) {
                ForEach(Side.allCases) { s in
                    Chip(label: s == .affirmative ? "Affirm the bill" : "Negate the bill", selected: side == s) { side = s }
                }
            }
            Text(side == .affirmative
                 ? "You sponsor the bill and give the authorship speech. The AI member speaks against it."
                 : "The AI member sponsors the bill and gives the authorship speech from the author's perspective. You speak against it — useful when you've uploaded an opponent's bill.")
                .subtext(.footnote)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Round format")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(RoundScript.congress.enumerated()), id: \.offset) { index, segment in
                    let mine = (segment.stance == .pro) == (side == .affirmative)
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.brand(.caption, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 20, height: 20)
                            .background(mine ? Theme.accent : Color.secondary)
                            .clipShape(Circle())
                        Text("\(mine ? "You" : "AI member") — \(segment.title) (\(segment.stance.rawValue))")
                            .font(.brand(.subheadline))
                        Spacer(minLength: 0)
                        Text(segment.clock)
                            .font(.brand(.caption, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "hand.wave")
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 20)
                    Text("Then you choose: speak again, or yield the floor and let the AI move an amendment if one is warranted.")
                        .font(.brand(.subheadline))
                }
                HStack(spacing: 10) {
                    Image(systemName: "questionmark.circle")
                        .font(.brand(.caption))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 20)
                    Text("Rise to a point of inquiry any time — a separate parliamentarian AI answers it.")
                        .font(.brand(.subheadline))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        importError = nil
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let url):
            do {
                let text = try DocumentText.extract(from: url)
                uploadedText = text
                uploadedName = url.lastPathComponent
                uploadedTitle = DocumentText.suggestedTitle(from: text, filename: url.lastPathComponent)
                useUpload = true
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func start() {
        guard !resolvedBill.isEmpty else { return }
        guard app.hasAPIKey else { showSettings = true; return }
        var config = PracticeConfig(kind: .congress, topic: resolvedBill, language: Language(rawValue: languageRaw) ?? .english, difficulty: difficulty, mode: .congress)
        config.userSide = side
        config.committee = committee.fullName
        config.lowPressure = lowPressure
        config.plainLanguage = plainLanguage
        if useUpload {
            config.billText = uploadedText
            config.billFilename = uploadedName
        }
        app.push(.session(config))
    }
}

struct StatLookupSheet: View {
    let committee: Committee
    var language: Language = .english

    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var answer: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ask for a number in this committee's area. You'll get the figure, how to use it, and the source that publishes it.")
                        .subtext(.footnote)

                    TextField("e.g. How many satellites are in orbit right now?", text: $question, axis: .vertical)
                        .lineLimit(1...3)
                        .field()

                    Button {
                        lookUp()
                    } label: {
                        Text(isLoading ? "Looking it up…" : "Look it up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || question.trimmingCharacters(in: .whitespaces).isEmpty)

                    if answer == nil && !isLoading {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Suggested for this committee")
                            ForEach(committee.statSuggestions, id: \.self) { suggestion in
                                Button {
                                    question = suggestion
                                    lookUp()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkle.magnifyingglass")
                                            .font(.brand(.caption))
                                            .foregroundStyle(Theme.accent)
                                        Text(suggestion)
                                            .font(.brand(.subheadline))
                                            .foregroundStyle(Color.primary)
                                            .multilineTextAlignment(.leading)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .card()
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.brand(.footnote)).foregroundStyle(Theme.danger)
                    }

                    if let answer {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SectionLabel(text: "Result")
                                Spacer()
                                ReadAloudButton(text: answer, language: language)
                            }
                            Text(answer)
                                .font(.brand(.subheadline))
                                .textSelection(.enabled)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()

                        Text("This comes from the model's training data, not a live feed — anything marked (verify) should be checked against the source links before you use it in a round.")
                            .subtext(.caption)

                        SectionLabel(text: "Check it here")
                        ForEach(committee.sources) { source in
                            Link(destination: URL(string: source.url) ?? URL(string: "https://www.congress.gov")!) {
                                HStack(spacing: 8) {
                                    Image(systemName: "link").font(.brand(.caption)).foregroundStyle(Theme.accent)
                                    Text(source.title).font(.brand(.subheadline)).foregroundStyle(Color.primary)
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right.square").font(.brand(.caption)).foregroundStyle(Theme.secondaryText.opacity(0.65))
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .card()
                                .contentShape(Rectangle())
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Look up a statistic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }

    private func lookUp() {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        answer = nil
        Task {
            do {
                answer = try await app.claude.lookUpStatistic(text, committee: committee, language: language)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct FlowChips: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.brand(.subheadline))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Theme.surface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.border))
            }
        }
    }
}
