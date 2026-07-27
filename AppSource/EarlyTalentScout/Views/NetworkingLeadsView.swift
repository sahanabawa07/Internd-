import SwiftUI

struct NetworkingLeadsView: View {
    let store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Organizations and people to explore").font(.system(size: 28, weight: .semibold))
                    Text("Use this space for organizations without a confirmed opening, career-access programs, and thoughtful informational outreach. Apply-ready opportunities stay in Research.")
                        .foregroundStyle(.secondary)
                }

                if !store.networkingLeads.isEmpty {
                    leadSection
                }

                if !store.report.suggestedCompanies.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Organizations worth exploring").font(.system(size: 25, weight: .semibold))
                        Text("These are interest-based ideas, not confirmed applications. Research the organization or find a person before you reach out.").foregroundStyle(.secondary)
                        ForEach(store.report.suggestedCompanies) { company in
                            CompanyLeadCard(company: company, research: {
                                store.companyResearchTarget = company.company
                                store.selection = .companies
                            }, network: {
                                store.networkLeadOrganization = company.company
                                store.selection = .network
                            })
                        }
                    }
                }

                if !store.watchCompanies.isEmpty {
                    watchSection
                }

                if store.networkingLeads.isEmpty && store.report.suggestedCompanies.isEmpty && store.watchCompanies.isEmpty {
                    ContentUnavailableView("No networking-first leads yet", systemImage: "person.crop.circle.badge.questionmark", description: Text("Refresh Research after completing your profile to discover organizations and outreach ideas."))
                }
            }
            .padding(22)
        }
    }

    private var leadSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Networking-first leads").font(.system(size: 25, weight: .semibold))
            Text("These organizations may not have a formal internship. Internd does not imply that an unofficial role exists; use them to learn and build a genuine relationship.").foregroundStyle(.secondary)
            ForEach(store.networkingLeads) { lead in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lead.organization).font(.system(size: 20, weight: .semibold))
                            Text(lead.category).font(.system(size: 16, weight: .medium)).foregroundStyle(InterndPalette.ink)
                        }
                        Spacer()
                    }
                    Text(lead.whyNetwork).font(.system(size: 17))
                    Text("Conversation angle: \(lead.outreachAngle)").font(.system(size: 15)).foregroundStyle(.secondary)
                    HStack {
                        Button("Research organization") { store.startCompanyResearch(for: lead) }.buttonStyle(.bordered)
                        Button("Find people") { store.startNetworking(for: lead) }.buttonStyle(.borderedProminent).tint(InterndPalette.ink)
                        if let url = lead.officialURL { Link("Official website", destination: url).buttonStyle(.bordered) }
                    }
                }
                .padding(13).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 17))
            }
        }
    }

    private var watchSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Watch list and program leads").font(.system(size: 25, weight: .semibold))
            Text("A watched company has no confirmed live posting. If Internd has named program leads for it, open the company card to review and track each one.").foregroundStyle(.secondary)
            ForEach(store.watchCompanies) { watch in
                VStack(alignment: .leading, spacing: 6) {
                    Text(watch.company).font(.system(size: 20, weight: .semibold))
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
                    if let url = watch.officialCareersURL { Link("Official careers page", destination: url).font(.system(size: 16, weight: .medium)) }
                }
                .padding(13).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 17))
            }
        }
    }
}

private struct CompanyLeadCard: View {
    let company: CompanySuggestion
    let research: () -> Void
    let network: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(company.company).font(.system(size: 20, weight: .semibold))
            Text(company.category).font(.system(size: 16, weight: .medium)).foregroundStyle(InterndPalette.ink)
            Text(company.whyItFits).font(.system(size: 17))
            Text("Path to investigate: \(company.earlyTalentPathway)").font(.system(size: 15)).foregroundStyle(.secondary)
            HStack {
                Button("Research organization", action: research).buttonStyle(.bordered)
                Button("Find people", action: network).buttonStyle(.borderedProminent).tint(InterndPalette.ink)
                if let url = company.officialCareersURL { Link("Official page", destination: url).buttonStyle(.bordered) }
            }
        }
        .padding(13).background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 17))
    }
}
