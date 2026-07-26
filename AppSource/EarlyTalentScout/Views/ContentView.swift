import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ContentView: View {
    let store: AppStore
    @State private var showingImporter = false
    @State private var hasStarted = false

    var body: some View {
        Group {
            if hasStarted {
                workspace
            } else {
                WelcomeView { hasStarted = true }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf, .plainText]) { result in
            guard case .success(let url) = result else { return }
            do {
                store.profile.resumeText = try extractText(from: url)
            } catch {
                store.errorMessage = "Could not read this file. Use a text-based PDF or plain-text resume."
            }
        }
        .alert("Research issue", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.errorMessage ?? "") }
    }

    private var workspace: some View {
        Group {
            if let selection = store.selection {
                DetailPageShell(section: selection, returnToGarden: { store.selection = nil }) {
                    destination(for: selection)
                }
            } else {
                WorkspaceHomeView(store: store)
            }
        }
        .tint(InterndPalette.ink)
    }

    @ViewBuilder
    private func destination(for section: WorkspaceSection) -> some View {
        switch section {
        case .today: DashboardView(store: store)
        case .profile: ProfileView(store: store, showingImporter: $showingImporter)
        case .research: ResearchView(store: store)
        case .network: NetworkView(store: store)
        case .tracker: TrackerView(store: store)
        case .tailor: ResumeTailorView(store: store)
        case .outreach: OutreachView(store: store)
        case .skills: SkillsPlanView(store: store)
        case .companies: CompanyResearchView(store: store)
        case .quality: ApplicationQualityView(store: store)
        case .interview: InterviewPrepView(store: store)
        case .insights: InsightsPrivacyView(store: store)
        }
    }

    private func extractText(from url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
        defer { url.stopAccessingSecurityScopedResource() }
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { throw CocoaError(.fileReadCorruptFile) }
            return document.string ?? ""
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
