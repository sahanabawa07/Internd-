import SwiftUI

struct ResearchView: View {
    let store: AppStore

    private var visibleOpportunities: [Opportunity] {
        store.report.opportunities.filter { !store.dismissedOpportunityIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your opportunity list").font(.title2.weight(.semibold))
                        Text("Official program links for open roles and credible next-cycle programs. Nothing enters your tracker until you choose it.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh now", systemImage: "arrow.clockwise") { Task { await store.runResearch() } }
                        .disabled(!store.canResearch)
                }

                if let run = store.run {
                    ResearchProgressCard(run: run)
                } else if visibleOpportunities.isEmpty {
                    ContentUnavailableView("No current results", systemImage: "sparkle.magnifyingglass", description: Text(store.researchReadinessMessage ?? "Internd will refresh this list whenever you open it."))
                } else {
                    Text("Last checked \(Date.now.formatted(date: .abbreviated, time: .shortened)) · \(visibleOpportunities.count) programs shown")
                        .font(.caption).foregroundStyle(.secondary)
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
                    Button("Restore dismissed results") { store.restoreDismissedResearch() }
                        .font(.caption)
                }

                if !store.report.suggestedCompanies.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("More organizations & programs worth exploring").font(.title3.weight(.semibold))
                        Text("These go beyond your target list and are based first on your interests, experience, and preferred locations. They can include firms, fellowships, public-interest organizations, and career-access programs.")
                            .foregroundStyle(.secondary)
                        ForEach(store.report.suggestedCompanies) { company in
                            CompanySuggestionCard(company: company, isWatched: store.watchCompanies.contains(where: { $0.company.caseInsensitiveCompare(company.company) == .orderedSame }), addToWatch: { store.addToWatchList(company) })
                        }
                    }
                }

                if !store.networkingLeads.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Networking-first leads").font(.title3.weight(.semibold))
                        Text("These organizations may not have a clear formal internship. Use them for informed conversations and relationship building—never assume an unofficial role exists.")
                            .foregroundStyle(.secondary)
                        ForEach(store.networkingLeads) { lead in
                            NetworkingLeadCard(lead: lead, research: { store.startCompanyResearch(for: lead) }, network: { store.startNetworking(for: lead) })
                        }
                    }
                }

                if !store.watchCompanies.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Watch list").font(.title3.weight(.semibold))
                        Text("Internd could not identify a credible early-talent pathway for these companies in the latest check. It checks them again on your next app launch and moves a match into Research when one appears.")
                            .foregroundStyle(.secondary)
                        ForEach(store.watchCompanies) { watch in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "eye").foregroundStyle(InterndPalette.ink)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(watch.company).font(.headline)
                                    Text(watch.reason).font(.subheadline).foregroundStyle(.secondary)
                                    Text("Last checked \(watch.lastChecked.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.tertiary)
                                    if let url = watch.officialCareersURL { Link("Official careers page", destination: url).font(.caption) }
                                }
                                Spacer()
                            }
                            .padding(12).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }

                if !store.report.skillSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Skills emerging from your research").font(.title3.weight(.semibold))
                        ForEach(store.report.skillSuggestions) { skill in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(skill.title).font(.headline)
                                Text(skill.why).foregroundStyle(.secondary)
                                Text("Next step: \(skill.nextStep)").font(.subheadline)
                            }.padding(12).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(22)
        }
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
                    Text(lead.organization).font(.headline)
                    Text(lead.category).font(.caption.weight(.medium)).foregroundStyle(InterndPalette.ink)
                }
                Spacer()
                Text(lead.status).font(.caption).foregroundStyle(.secondary)
            }
            Text(lead.whyNetwork).font(.subheadline)
            Text("Conversation angle: \(lead.outreachAngle)").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Research organization", action: research).buttonStyle(.bordered)
                Link("Find people on LinkedIn", destination: linkedInSearchURL).buttonStyle(.bordered)
                Button("Save a contact", action: network).buttonStyle(.borderedProminent).tint(InterndPalette.ink)
            }
            if let url = lead.officialURL { Link("Official website", destination: url).font(.caption.weight(.medium)) }
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
                    Text(company.company).font(.headline)
                    Text(company.category).font(.caption.weight(.medium)).foregroundStyle(InterndPalette.ink)
                }
                Spacer()
                Button(isWatched ? "Watching" : "Add to Watch List", systemImage: isWatched ? "eye.fill" : "eye", action: addToWatch)
                    .buttonStyle(.bordered).disabled(isWatched)
            }
            Text(company.whyItFits).font(.subheadline)
            Text("Early-talent path: \(company.earlyTalentPathway)").font(.caption).foregroundStyle(.secondary)
            if let url = company.officialCareersURL { Link("Official careers page", destination: url).font(.caption.weight(.medium)) }
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
                Button(action: dismiss) { Image(systemName: "xmark").font(.caption.weight(.bold)).frame(width: 26, height: 26).background(.black.opacity(0.06), in: Circle()) }
                    .buttonStyle(.plain).accessibilityLabel("Remove this result")
                Spacer()
                Button(isTracked ? "Added to tracker" : "Add to tracker", systemImage: isTracked ? "checkmark.circle.fill" : "plus.circle.fill", action: add)
                    .buttonStyle(.borderedProminent).tint(isTracked ? .secondary : InterndPalette.ink).disabled(isTracked)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(opportunity.program).font(.title3.weight(.semibold))
                    Text(opportunity.company).foregroundStyle(.secondary)
                }
                Spacer()
                Text(opportunity.statusLabel.uppercased()).font(.caption.weight(.bold)).foregroundStyle(statusColor).padding(.horizontal, 8).padding(.vertical, 5).background(statusColor.opacity(0.12), in: Capsule())
            }
            Text(opportunity.sourceNotes).font(.subheadline)
            ResearchAudit(sourceType: opportunity.officialSourceType, facts: opportunity.verifiedFacts, fallbackURL: opportunity.officialProgramURL)
            Label("Why this matches you: \(opportunity.fitReason)", systemImage: "sparkles").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Label(opportunity.careerArea, systemImage: "briefcase")
                Label(opportunity.location, systemImage: "mappin.and.ellipse")
            }.font(.caption).foregroundStyle(.secondary)
            Text("Eligibility & requirements: \(opportunity.eligibility)").font(.caption).foregroundStyle(.secondary)
            if opportunity.status == "recurring_watch" {
                Label("Expected timing: \(opportunity.expectedApplicationTiming)", systemImage: "calendar.badge.clock").font(.caption).foregroundStyle(.secondary)
                if !opportunity.preparationChecklist.isEmpty {
                    Text("Prepare now: \(opportunity.preparationChecklist.joined(separator: " · "))").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                if let date = opportunity.postingDate { Text("Posted: \(date)") }
                if let deadline = opportunity.deadline { Text("Deadline: \(deadline)") }
            }.font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Link("Official program page", destination: opportunity.officialProgramURL)
                if let url = opportunity.applicationURL { Link("Application link", destination: url) }
            }.font(.subheadline.weight(.medium))
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
                Text("Source: \(sourceType)").font(.caption).foregroundStyle(.secondary)
                if facts.isEmpty {
                    Text("Review the official page before relying on any application detail.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(facts) { fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(fact.label): \(fact.value)").font(.caption)
                        HStack {
                            Text(fact.classificationLabel).font(.caption2).foregroundStyle(color(for: fact.classification))
                            Link("View source", destination: fact.sourceURL ?? fallbackURL).font(.caption2)
                        }
                    }
                }
            }.padding(.top, 5)
        }
        .font(.caption.weight(.medium))
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
            Text("Refreshing your research").font(.headline)
            Text("This uses your OpenAI API credit and checks official program pages plus your Watch List.").font(.caption).foregroundStyle(.secondary)
            ForEach(run.agents) { agent in
                HStack { Text(agent.name); Spacer(); Text(agent.status.rawValue).font(.caption).foregroundStyle(agent.status == .failed ? .red : .secondary) }
            }
        }.padding(16).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
    }
}
