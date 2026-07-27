import SwiftUI

struct ResearchView: View {
    let store: AppStore
    @State private var section: ResearchSection = .opportunities
    @State private var opportunityCompany = ""
    @State private var opportunityProgram = ""
    @State private var opportunityDescription = ""
    @State private var opportunityURL = ""
    @State private var watchCompany = ""
    @State private var watchReason = ""
    @State private var watchProgram = ""
    @State private var watchURL = ""

    private enum ResearchSection: String, CaseIterable, Identifiable {
        case opportunities = "Opportunities"
        case watchList = "Watch List"
        var id: String { rawValue }
    }

    private var visibleOpportunities: [Opportunity] {
        store.report.opportunities.filter { !store.dismissedOpportunityIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your opportunity list").font(.system(size: 28, weight: .semibold))
                        Text("Official program links for open roles and credible next-cycle programs. Nothing enters your tracker until you choose it.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh now", systemImage: "arrow.clockwise") { Task { await store.runResearch() } }
                        .disabled(!store.canResearch)
                }

                Picker("Research section", selection: $section) {
                    ForEach(ResearchSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if store.profileRefreshQueued {
                    Label("Your profile changed. Internd is preparing a fresh recommendation set.", systemImage: "arrow.clockwise")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                }

                if section == .opportunities {
                    opportunitiesSection
                } else {
                    watchListSection
                }

                if section == .opportunities && !store.report.skillSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skills emerging from your research").font(.system(size: 25, weight: .semibold))
                        ForEach(store.report.skillSuggestions) { skill in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(skill.title).font(.system(size: 20, weight: .semibold))
                                Text(skill.why).foregroundStyle(.secondary)
                                Text("Next step: \(skill.nextStep)").font(.system(size: 17))
                            }.padding(12).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(22)
        }
    }

    @ViewBuilder
    private var opportunitiesSection: some View {
        manualOpportunityForm
        if let run = store.run {
            ResearchProgressCard(run: run)
        } else if visibleOpportunities.isEmpty {
            ContentUnavailableView("No opportunities shown yet", systemImage: "sparkle.magnifyingglass", description: Text(store.researchReadinessMessage ?? "Refresh now to look for internships, fellowships, programs, and early-career opportunities."))
        } else {
            Text("\(visibleOpportunities.count) opportunities · each has an official link and can be added to your tracker")
                .font(.system(size: 15)).foregroundStyle(.secondary)
            ForEach(visibleOpportunities) { opportunity in
                OpportunityCard(
                    opportunity: opportunity,
                    isTracked: store.applications.contains(where: { $0.company == opportunity.company && $0.program == opportunity.program }),
                    add: { store.track(opportunity) },
                    dismiss: { store.dismiss(opportunity) }
                )
            }
        }

        if !store.dismissedOpportunityIDs.isEmpty {
            Button("Restore dismissed opportunities") { store.restoreDismissedResearch() }
                .font(.system(size: 15))
        }
    }

    @ViewBuilder
    private var watchListSection: some View {
        manualWatchForm
        if store.watchCompanies.isEmpty {
            ContentUnavailableView("No companies on your Watch List", systemImage: "eye", description: Text("Internd will place companies here when there is no confirmed live posting to apply to yet."))
        } else {
            Text("Watch companies are monitored when Internd refreshes. Open a company to see every named program lead it found.")
                .font(.system(size: 17)).foregroundStyle(.secondary)
            ForEach(store.watchCompanies) { watch in
                WatchCompanyCard(watch: watch, store: store)
            }
        }
    }

    private var manualOpportunityForm: some View {
        DisclosureGroup("Add an opportunity manually") {
            VStack(alignment: .leading, spacing: 9) {
                Text("Save a program you found yourself. Add an official program or application link so it is ready for your tracker.")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                TextField("Company or organization", text: $opportunityCompany)
                TextField("Program, internship, or fellowship name", text: $opportunityProgram)
                TextField("Short description (optional)", text: $opportunityDescription)
                TextField("Official program or application link", text: $opportunityURL)
                Button("Add to opportunities") {
                    store.addManualOpportunity(company: opportunityCompany, program: opportunityProgram, description: opportunityDescription, officialURLText: opportunityURL)
                    opportunityCompany = ""; opportunityProgram = ""; opportunityDescription = ""; opportunityURL = ""
                }
                .buttonStyle(.borderedProminent).tint(InterndPalette.ink)
                .disabled(opportunityCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || opportunityProgram.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || opportunityURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .font(.system(size: 17, weight: .medium))
        .padding(13).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 17))
    }

    private var manualWatchForm: some View {
        DisclosureGroup("Add a company or program lead manually") {
            VStack(alignment: .leading, spacing: 9) {
                Text("A program name and official link are optional. If you include them, the company card will show that program as a lead.")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
                TextField("Company or organization", text: $watchCompany)
                TextField("Why you want to watch it (optional)", text: $watchReason)
                TextField("Program lead name (optional)", text: $watchProgram)
                TextField("Official careers or program link (optional)", text: $watchURL)
                Button("Add to Watch List") {
                    store.addManualWatchCompany(company: watchCompany, reason: watchReason, program: watchProgram, officialURLText: watchURL)
                    watchCompany = ""; watchReason = ""; watchProgram = ""; watchURL = ""
                }
                .buttonStyle(.borderedProminent).tint(InterndPalette.ink)
                .disabled(watchCompany.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .font(.system(size: 17, weight: .medium))
        .padding(13).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct WatchCompanyCard: View {
    let watch: WatchCompany
    let store: AppStore
    @State private var programName = ""
    @State private var programURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(watch.company).font(.system(size: 20, weight: .semibold))
                Spacer()
                Button("Remove", role: .destructive) { store.removeFromWatchList(watch) }
                    .buttonStyle(.bordered)
            }
            Text(watch.reason).font(.system(size: 17)).foregroundStyle(.secondary)

            if let leads = watch.programLeads, !leads.isEmpty {
                DisclosureGroup("View \(leads.count) program lead\(leads.count == 1 ? "" : "s")") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(leads) { lead in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(lead.program).font(.system(size: 18, weight: .semibold))
                                    Text(lead.statusLabel).font(.system(size: 15)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(store.applications.contains(where: { $0.company == lead.company && $0.program == lead.program }) ? "Added" : "Add to tracker") { store.track(lead) }
                                    .buttonStyle(.borderedProminent).tint(InterndPalette.ink)
                                    .disabled(store.applications.contains(where: { $0.company == lead.company && $0.program == lead.program }))
                            }
                            Link("Official program page", destination: lead.officialProgramURL).font(.system(size: 16, weight: .medium))
                        }
                    }.padding(.top, 6)
                }.font(.system(size: 17, weight: .medium))
            }

            DisclosureGroup("Add a program lead") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a program you found for \(watch.company). It will appear above with its own Add to tracker button.")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                    TextField("Program, internship, or fellowship name", text: $programName)
                    TextField("Official program or application link", text: $programURL)
                    Button("Save program lead") {
                        store.addManualWatchCompany(company: watch.company, reason: "", program: programName, officialURLText: programURL)
                        programName = ""; programURL = ""
                    }
                    .buttonStyle(.borderedProminent).tint(InterndPalette.ink)
                    .disabled(programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || programURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(.top, 6)
            }
            .font(.system(size: 17, weight: .medium))

            if let url = watch.officialCareersURL { Link("Official careers page", destination: url).font(.system(size: 16, weight: .medium)) }
        }
        .padding(13).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct NetworkingLeadCard: View {
    let lead: NetworkingLead
    let research: () -> Void
    let network: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lead.organization).font(.system(size: 20, weight: .semibold))
                    Text(lead.category).font(.system(size: 16, weight: .medium)).foregroundStyle(InterndPalette.ink)
                }
                Spacer()
                Text(lead.status).font(.system(size: 15)).foregroundStyle(.secondary)
            }
            Text(lead.whyNetwork).font(.system(size: 17))
            Text("Conversation angle: \(lead.outreachAngle)").font(.system(size: 15)).foregroundStyle(.secondary)
            HStack {
                Button("Research organization", action: research).buttonStyle(.bordered)
                Link("Find people on LinkedIn", destination: linkedInSearchURL).buttonStyle(.bordered)
                Button("Save a contact", action: network).buttonStyle(.borderedProminent).tint(InterndPalette.ink)
            }
            if let url = lead.officialURL { Link("Official website", destination: url).font(.system(size: 16, weight: .medium)) }
        }
        .padding(13).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 17))
    }

    private var linkedInSearchURL: URL {
        let query = lead.organization.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? lead.organization
        return URL(string: "https://www.linkedin.com/search/results/people/?keywords=\(query)")!
    }
}

private struct CompanySuggestionCard: View {
    let company: CompanySuggestion
    let isWatched: Bool
    let addToWatch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(company.company).font(.system(size: 20, weight: .semibold))
                    Text(company.category).font(.system(size: 16, weight: .medium)).foregroundStyle(InterndPalette.ink)
                }
                Spacer()
                Button(isWatched ? "Watching" : "Add to Watch List", systemImage: isWatched ? "eye.fill" : "eye", action: addToWatch)
                    .buttonStyle(.bordered).disabled(isWatched)
            }
            Text(company.whyItFits).font(.system(size: 17))
            Text("Early-talent path: \(company.earlyTalentPathway)").font(.system(size: 15)).foregroundStyle(.secondary)
            if let url = company.officialCareersURL { Link("Official careers page", destination: url).font(.system(size: 16, weight: .medium)) }
        }
        .padding(13).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct OpportunityCard: View {
    let opportunity: Opportunity
    let isTracked: Bool
    let add: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).frame(width: 26, height: 26).background(.black.opacity(0.06), in: Circle()) }
                    .buttonStyle(.plain).accessibilityLabel("Remove this result")
                Spacer()
                Button(isTracked ? "Added to tracker" : "Add to tracker", systemImage: isTracked ? "checkmark.circle.fill" : "plus.circle.fill", action: add)
                    .buttonStyle(.borderedProminent).tint(isTracked ? .secondary : InterndPalette.ink).disabled(isTracked)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(opportunity.program).font(.system(size: 25, weight: .semibold))
                    Text(opportunity.company).foregroundStyle(.secondary)
                }
                Spacer()
                Text(opportunity.statusLabel.uppercased()).font(.system(size: 16, weight: .bold)).foregroundStyle(statusColor).padding(.horizontal, 8).padding(.vertical, 5).background(statusColor.opacity(0.12), in: Capsule())
            }
            Text(opportunity.sourceNotes).font(.system(size: 17))
            ResearchAudit(sourceType: opportunity.officialSourceType, facts: opportunity.verifiedFacts, fallbackURL: opportunity.officialProgramURL)
            Label("Why this matches you: \(opportunity.fitReason)", systemImage: "sparkles").font(.system(size: 17)).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Label(opportunity.careerArea, systemImage: "briefcase")
                Label(opportunity.location, systemImage: "mappin.and.ellipse")
            }.font(.system(size: 15)).foregroundStyle(.secondary)
            Text("Eligibility & requirements: \(opportunity.eligibility)").font(.system(size: 15)).foregroundStyle(.secondary)
            if opportunity.status == "recurring_watch" {
                Label("Expected timing: \(opportunity.expectedApplicationTiming)", systemImage: "calendar.badge.clock").font(.system(size: 15)).foregroundStyle(.secondary)
                if !opportunity.preparationChecklist.isEmpty {
                    Text("Prepare now: \(opportunity.preparationChecklist.joined(separator: " · "))").font(.system(size: 15)).foregroundStyle(.secondary)
                }
            }
            HStack {
                if let date = opportunity.postingDate { Text("Posted: \(date)") }
                if let deadline = opportunity.deadline { Text("Deadline: \(deadline)") }
            }.font(.system(size: 15)).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Link("Official program page", destination: opportunity.officialProgramURL)
                if let url = opportunity.applicationURL { Link("Application link", destination: url) }
            }.font(.system(size: 18, weight: .medium))
        }
        .padding(17)
        .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.7)))
    }

    private var statusColor: Color { opportunity.status == "open" ? .green : opportunity.status == "recurring_watch" ? .orange : .secondary }
}

private struct ResearchAudit: View {
    let sourceType: String
    let facts: [VerifiedFact]
    let fallbackURL: URL

    var body: some View {
        DisclosureGroup("Research audit · \(facts.count) sourced detail\(facts.count == 1 ? "" : "s")") {
            VStack(alignment: .leading, spacing: 7) {
                Text("Source: \(sourceType)").font(.system(size: 15)).foregroundStyle(.secondary)
                if facts.isEmpty {
                    Text("Review the official page before relying on any application detail.").font(.system(size: 15)).foregroundStyle(.secondary)
                }
                ForEach(facts) { fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(fact.label): \(fact.value)").font(.system(size: 15))
                        HStack {
                            Text(fact.classificationLabel).font(.system(size: 14)).foregroundStyle(color(for: fact.classification))
                            Link("View source", destination: fact.sourceURL ?? fallbackURL).font(.system(size: 14))
                        }
                    }
                }
            }.padding(.top, 5)
        }
        .font(.system(size: 16, weight: .medium))
        .tint(InterndPalette.ink)
    }

    private func color(for classification: String) -> Color {
        classification == "confirmed" ? .green : classification == "historical" ? .orange : .secondary
    }
}

private struct ResearchProgressCard: View {
    let run: ResearchRun
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Refreshing your research").font(.system(size: 20, weight: .semibold))
            Text("This uses your OpenAI API credit and checks official program pages plus your Watch List.").font(.system(size: 15)).foregroundStyle(.secondary)
            ForEach(run.agents) { agent in
                HStack { Text(agent.name); Spacer(); Text(agent.status.rawValue).font(.system(size: 15)).foregroundStyle(agent.status == .failed ? .red : .secondary) }
            }
        }.padding(16).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
    }
}
