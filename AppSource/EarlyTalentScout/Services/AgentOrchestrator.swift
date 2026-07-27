import Foundation

actor AgentOrchestrator {
    private let client: ResponsesClient

    init(apiKey: String) { client = ResponsesClient(apiKey: apiKey) }

    func run(profile: StudentProfile, onProgress: @Sendable (String, AgentProgress.Status) async -> Void) async throws -> ResearchReport {
        async let profileAnalysis: String = ask(
            """
            You are the Resume Analyst agent. Summarize this student's demonstrated skills,
            evidence, and plausible career directions. Do not infer sensitive traits. Resume:
            \(profile.resumeText)
            """,
            web: false, name: "Resume Analyst", progress: onProgress
        )
        async let strategy: String = ask(
            """
            You are the Career Strategist agent. Propose career directions and concise follow-up
            questions for this student. Student year: \(profile.schoolYear). Interests: \(profile.careerInterests).
            Targets: \(profile.targetCompanies).
            """,
            web: false, name: "Career Strategist", progress: onProgress
        )

        let context = "Resume analysis:\n\(try await profileAnalysis)\n\nCareer strategy:\n\(try await strategy)"
        async let researcher = ask(researchPrompt(profile: profile, context: context), web: true, name: "Program Researcher", progress: onProgress)
        async let discovery = ask(discoveryPrompt(profile: profile, context: context), web: true, name: "Ecosystem Scout", progress: onProgress)
        let rawPrograms = try await researcher
        let discoveryResults = try await discovery
        let verified = try await ask(verificationPrompt(candidateJSON: rawPrograms), web: true, name: "Link Verifier", progress: onProgress)
        let ranked = try await ask(rankingPrompt(profile: profile, verifiedJSON: verified, discoveryJSON: discoveryResults), web: false, name: "Opportunity Ranker", progress: onProgress)
        let rawReport = try? decodeReport(rawPrograms)
        let verifiedReport = try? decodeReport(verified)
        let discoveryReport = try? decodeReport(discoveryResults)
        let rankedReport = try? decodeReport(ranked)
        return strongestReport(ranked: rankedReport, verified: verifiedReport, raw: rawReport, discovery: discoveryReport)
    }

    private func ask(_ prompt: String, web: Bool, name: String, progress: @Sendable (String, AgentProgress.Status) async -> Void) async throws -> String {
        await progress(name, .working)
        do {
            let result = try await client.run(prompt: prompt, useWebSearch: web)
            await progress(name, .complete)
            return result
        } catch {
            await progress(name, .failed)
            throw error
        }
    }

    private func researchPrompt(profile: StudentProfile, context: String) -> String {
        """
        You are the Program Researcher agent. Current date: \(Date.now.formatted(date: .abbreviated, time: .omitted)).
        Your only job is to return 10–12 concrete sophomore-accessible internships, exploration programs, fellowships, or pre-internships for the student's NEXT summer. Include target-company programs first, then high-fit programs outside the list. This is a planning search: keep a credible recurring program in the opportunity list even if it is not open today.
        Prioritize first/second-year eligibility. Search official employer, university recruiting, or program sites. Use sources like Microsoft Explore, Google STEP, NVIDIA Ignite, Bain BEL/CREW, BCG Advance, Girls Who Invest, and early-insight programs as leads only when relevant and supported by an official page—do not invent facts.
        Student: \(context). Targets: \(profile.targetCompanies). Interests: \(profile.careerInterests). Locations: \(profile.locations). Work authorization: \(profile.workAuthorization).
        Return JSON only: {"opportunities":[...]}. Every opportunity needs company, program, career_area, fit_reason, eligibility, location, status, posting_date, deadline, application_url, official_program_url, linked_in_url, source_notes, expected_application_timing, preparation_checklist, resume_focus, skill_focus, official_source_type, verified_facts. Use empty/null values when unknown rather than dropping a credible official program.
        """
    }

    private func discoveryPrompt(profile: StudentProfile, context: String) -> String {
        """
        You are the Ecosystem Scout agent. Find organizations, firms, access programs, fellowships, and networking-first leads the student may not already know. Start from interests, resume, and preferred locations—not their target-company list.
        Cover relevant adjacent paths such as banking, quant/trading, VC/private equity, economic consulting/advisory, government/multilateral/UN/public interest, startup accelerators, and access programs such as Girls Who Invest, SEO, INROADS, or MLT. If locations include NYC or Chicago, actively seek relevant organizations there. Do not claim an internship exists when it does not.
        Student: \(context). Interests: \(profile.careerInterests). Locations: \(profile.locations).
        Return JSON only: {"suggested_companies":[{"company":"","category":"","why_it_fits":"","early_talent_pathway":"","official_careers_url":null}],"networking_leads":[{"organization":"","category":"","why_network":"","outreach_angle":"","official_url":null}],"watch_companies":[{"company":"","reason":"","official_careers_url":null}]}. Return 8–12 suggested_companies and 3–6 networking_leads when credible sources exist.
        """
    }

    private func verificationPrompt(candidateJSON: String) -> String {
        """
        You are the Link Verifier agent. Verify only the opportunity candidates below using web search. Keep a candidate only when its official employer, university recruiting, or program page supports that the program exists. An application URL must be employer-owned.
        This is a NEXT-SUMMER planning search. Keep credible recurring or recently closed official programs even when no role is open today; label those recurring_watch and retain the official program or careers page. Use open only when an official source confirms an active opening today. Use unknown when availability is unclear. Remove a candidate only when its program claim or official URL cannot be supported.
        Rebuild verified_facts from the official source. Label page-supported current facts confirmed, previous-cycle facts historical, and preparation advice guidance. Do not invent a deadline, eligibility rule, requirement, or availability claim. Never use a job-board URL as the official source.
        Return JSON only in this exact shape: {"opportunities":[...]}. Do not return prose or any other categories.\n\nCandidates:\n\(candidateJSON)
        """
    }

    private func rankingPrompt(profile: StudentProfile, verifiedJSON: String, discoveryJSON: String) -> String {
        """
        You are the Opportunity Ranker agent. Rank the verified opportunities for this student, favoring first/second-year fit,
        stated interests, location constraints, and evidence from the resume. Rank suggested_companies by how much they expand the student's awareness beyond named targets while still fitting their interests; preserve a mix of direct employers and relevant programs/ecosystem pathways when justified. Preserve as many verified candidates as possible, including recurring next-cycle programs.
        Never move an opportunity into watch_companies merely because it is not currently open; watch_companies are only companies with no credible program pathway. Return JSON only in this exact shape:
        {"career_suggestions":[{"title":"","why":"","next_step":""}],"opportunities":[{"company":"","program":"","career_area":"","fit_reason":"","eligibility":"","location":"","status":"open|recurring_watch|unknown","posting_date":null,"deadline":null,"application_url":null,"official_program_url":"","linkedin_url":null,"source_notes":"","expected_application_timing":"","preparation_checklist":[""],"resume_focus":[""],"skill_focus":[""],"official_source_type":"","verified_facts":[{"label":"","value":"","classification":"confirmed|historical|guidance","source_url":""}]}],"suggested_companies":[{"company":"","category":"","why_it_fits":"","early_talent_pathway":"","official_careers_url":null}],"networking_leads":[{"organization":"","category":"","why_network":"","outreach_angle":"","official_url":null}],"watch_companies":[{"company":"","reason":"","official_careers_url":null}],"skill_suggestions":[{"title":"","why":"","next_step":""}],"research_notes":[""]}
        Preserve verified_facts, their classifications, and their source URLs exactly as supplied by the verifier; do not add facts. Use every verified URL exactly as given; never invent a URL. Student: \(profile.careerInterests). Verified opportunity input:\n\(verifiedJSON)\n\nDiscovery input:\n\(discoveryJSON)
        """
    }

    private func decodeReport(_ text: String) throws -> ResearchReport {
        let loose = try decode(text, as: LooseResearchReport.self)
        let directions = (loose.careerSuggestions ?? []).compactMap { direction -> CareerDirection? in
            guard let title = direction.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            return CareerDirection(
                title: title,
                why: direction.why ?? "A possible direction based on your profile.",
                nextStep: direction.nextStep ?? "Explore relevant early-talent programs."
            )
        }
        let opportunities = (loose.opportunities ?? []).compactMap { item -> Opportunity? in
            let officialText = item.officialProgramURL ?? item.applicationURL
            guard let officialText,
                  let officialURL = URL(string: officialText),
                  !officialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let status = ["open", "recurring_watch", "unknown"].contains(item.status ?? "") ? item.status! : "unknown"
            return Opportunity(
                company: item.company ?? "Unknown company",
                program: item.program ?? "Early-talent program",
                careerArea: item.careerArea ?? "General",
                fitReason: item.fitReason ?? "Review the official program page to assess fit.",
                eligibility: item.eligibility ?? "Verify eligibility on the official page.",
                location: item.location ?? "Verify location",
                status: status,
                postingDate: item.postingDate,
                deadline: item.deadline,
                applicationURL: item.applicationURL.flatMap(URL.init(string:)),
                officialProgramURL: officialURL,
                linkedInURL: item.linkedInURL.flatMap(URL.init(string:)),
                sourceNotes: item.sourceNotes ?? "Official program page supplied by the research agent.",
                expectedApplicationTiming: item.expectedApplicationTiming ?? "Check the official page for the next application window.",
                preparationChecklist: item.preparationChecklist ?? [],
                resumeFocus: item.resumeFocus ?? [],
                skillFocus: item.skillFocus ?? [],
                officialSourceType: item.officialSourceType ?? "Official program or careers page",
                verifiedFacts: (item.verifiedFacts ?? []).compactMap { fact in
                    guard let label = fact.label, let value = fact.value, ["confirmed", "historical", "guidance"].contains(fact.classification ?? "") else { return nil }
                    return VerifiedFact(label: label, value: value, classification: fact.classification ?? "guidance", sourceURL: fact.sourceURL.flatMap(URL.init(string:)) ?? officialURL)
                }
            )
        }
        let watched = (loose.watchCompanies ?? []).compactMap { item -> WatchCompany? in
            guard let company = item.company?.trimmingCharacters(in: .whitespacesAndNewlines), !company.isEmpty else { return nil }
            return WatchCompany(company: company, reason: item.reason ?? "No suitable early-talent role was confirmed during the latest check.", officialCareersURL: item.officialCareersURL.flatMap(URL.init(string:)))
        }
        let suggestedCompanies = (loose.suggestedCompanies ?? []).compactMap { item -> CompanySuggestion? in
            guard let company = item.company?.trimmingCharacters(in: .whitespacesAndNewlines), !company.isEmpty else { return nil }
            return CompanySuggestion(company: company, category: item.category ?? "Career match", whyItFits: item.whyItFits ?? "A strong company to explore based on your interests.", earlyTalentPathway: item.earlyTalentPathway ?? "Check the official careers page for early-talent opportunities.", officialCareersURL: item.officialCareersURL.flatMap(URL.init(string:)))
        }
        let networkingLeads = (loose.networkingLeads ?? []).compactMap { item -> NetworkingLead? in
            guard let organization = item.organization?.trimmingCharacters(in: .whitespacesAndNewlines), !organization.isEmpty else { return nil }
            return NetworkingLead(organization: organization, category: item.category ?? "Networking lead", whyNetwork: item.whyNetwork ?? "A relevant organization to learn from.", outreachAngle: item.outreachAngle ?? "Ask for a brief perspective on the field and early-career paths.", officialURL: item.officialURL.flatMap(URL.init(string:)))
        }
        let skills = (loose.skillSuggestions ?? []).compactMap { item -> SkillSuggestion? in
            guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            return SkillSuggestion(title: title, why: item.why ?? "This skill appears often in your strongest matches.", nextStep: item.nextStep ?? "Choose one small practice step this week.")
        }
        return ResearchReport(
            careerSuggestions: directions,
            opportunities: opportunities,
            suggestedCompanies: suggestedCompanies,
            networkingLeads: networkingLeads,
            watchCompanies: watched,
            skillSuggestions: skills,
            researchNotes: loose.researchNotes ?? []
        )
    }

    private func strongestReport(ranked: ResearchReport?, verified: ResearchReport?, raw: ResearchReport?, discovery: ResearchReport?) -> ResearchReport {
        let fallback = verified ?? raw ?? ResearchReport.empty
        let discoveryFallback = discovery ?? ResearchReport.empty
        let rankedReport = ranked ?? ResearchReport.empty
        let chosenOpportunities = !rankedReport.opportunities.isEmpty ? rankedReport.opportunities : fallback.opportunities
        let chosenSuggestions = !rankedReport.suggestedCompanies.isEmpty ? rankedReport.suggestedCompanies : discoveryFallback.suggestedCompanies
        let chosenNetworking = !rankedReport.networkingLeads.isEmpty ? rankedReport.networkingLeads : discoveryFallback.networkingLeads
        let chosenWatch = !rankedReport.watchCompanies.isEmpty ? rankedReport.watchCompanies : discoveryFallback.watchCompanies
        let chosenSkills = !rankedReport.skillSuggestions.isEmpty ? rankedReport.skillSuggestions : fallback.skillSuggestions
        let chosenDirections = !rankedReport.careerSuggestions.isEmpty ? rankedReport.careerSuggestions : fallback.careerSuggestions
        let chosenNotes = !rankedReport.researchNotes.isEmpty ? rankedReport.researchNotes : fallback.researchNotes
        return ResearchReport(careerSuggestions: chosenDirections, opportunities: chosenOpportunities, suggestedCompanies: chosenSuggestions, networkingLeads: chosenNetworking, watchCompanies: chosenWatch, skillSuggestions: chosenSkills, researchNotes: chosenNotes)
    }

    private struct LooseResearchReport: Decodable {
        var careerSuggestions: [LooseCareerDirection]?
        var opportunities: [LooseOpportunity]?
        var suggestedCompanies: [LooseCompanySuggestion]?
        var networkingLeads: [LooseNetworkingLead]?
        var watchCompanies: [LooseWatchCompany]?
        var skillSuggestions: [LooseSkillSuggestion]?
        var researchNotes: [String]?
    }

    private struct LooseWatchCompany: Decodable {
        var company: String?
        var reason: String?
        var officialCareersURL: String?
    }

    private struct LooseCompanySuggestion: Decodable {
        var company: String?
        var category: String?
        var whyItFits: String?
        var earlyTalentPathway: String?
        var officialCareersURL: String?
    }

    private struct LooseNetworkingLead: Decodable {
        var organization: String?
        var category: String?
        var whyNetwork: String?
        var outreachAngle: String?
        var officialURL: String?
    }

    private struct LooseSkillSuggestion: Decodable {
        var title: String?
        var why: String?
        var nextStep: String?
    }

    private struct LooseCareerDirection: Decodable {
        var title: String?
        var why: String?
        var nextStep: String?
    }

    private struct LooseOpportunity: Decodable {
        var company: String?
        var program: String?
        var careerArea: String?
        var fitReason: String?
        var eligibility: String?
        var location: String?
        var status: String?
        var postingDate: String?
        var deadline: String?
        var applicationURL: String?
        var officialProgramURL: String?
        var linkedInURL: String?
        var sourceNotes: String?
        var expectedApplicationTiming: String?
        var preparationChecklist: [String]?
        var resumeFocus: [String]?
        var skillFocus: [String]?
        var officialSourceType: String?
        var verifiedFacts: [LooseVerifiedFact]?
    }

    private struct LooseVerifiedFact: Decodable {
        var label: String?
        var value: String?
        var classification: String?
        var sourceURL: String?
    }

    func findConnections(profile: StudentProfile, connectionRows: [[String: String]]) async throws -> [NetworkContact] {
        let connections = connectionRows.prefix(120).map { $0.description }.joined(separator: "\n")
        let text = try await client.run(prompt: """
        You are the Network Scout agent. Match this student's school, past internships, interests, and target companies to people
        in their own exported LinkedIn connections. You may use public web search to find relevant alumni context, but do not log in,
        scrape LinkedIn, or invent private connection data. Return JSON only: [{"name":"","headline":"","company":"","shared_context":"","profile_url":null,"reach_out_reason":""}].
        Student school/past experience/resume: \(profile.resumeText). Targets: \(profile.targetCompanies). Connections export:\n\(connections)
        """, useWebSearch: true)
        return try decode(text, as: [NetworkContact].self)
    }

    func tailorResume(profile: StudentProfile, jobDescription: String) async throws -> TailoredResume {
        let text = try await client.run(prompt: """
        You are the Resume Tailor agent. Tailor suggestions for the student and role below. Preserve truth: do not add skills,
        metrics, titles, employers, or achievements absent from the resume. Return JSON only with role_summary, priority_keywords,
        suggested_changes, tailored_bullet_examples, and cautions. Resume:\n\(profile.resumeText)\n\nRole:\n\(jobDescription)
        """, useWebSearch: false)
        return try decode(text, as: TailoredResume.self)
    }

    func buildSkillsPlan(profile: StudentProfile, targetRole: String) async throws -> SkillsPlan {
        let text = try await client.run(prompt: """
        You are the Skills-Gap Planner agent. Compare the student's evidence with their desired role. Suggest only realistic,
        low-cost next steps that can be completed within four weeks. Return JSON only with target_role, strengths, gaps,
        four_week_plan, portfolio_idea. Student resume: \(profile.resumeText). Target role: \(targetRole)
        """, useWebSearch: false)
        return try decode(text, as: SkillsPlan.self)
    }

    func researchCompany(_ company: String, interests: String) async throws -> CompanyBrief {
        let text = try await client.run(prompt: """
        You are the Company Intelligence agent. Research this company with web search using primary sources first. Summarize its
        business, early-talent information, useful conversation starters, and likely interview themes relevant to the student's
        interests. Do not invent details. Return JSON only with company, business_summary, early_talent_notes,
        conversation_starters, interview_themes, source_caveat. Company: \(company). Interests: \(interests)
        """, useWebSearch: true)
        return try decode(text, as: CompanyBrief.self)
    }

    func checkApplication(profile: StudentProfile, application: ApplicationRecord, extraMaterials: String) async throws -> ApplicationQualityCheck {
        let text = try await client.run(prompt: """
        You are the Application Quality Check agent. Assess whether this application is ready. Do not claim that a requirement is
        complete unless it appears in the supplied materials. Return JSON only with ready_to_apply, missing_items, resume_checks,
        application_checks, recommended_next_action. Resume: \(profile.resumeText). Application: \(application). Extra materials: \(extraMaterials)
        """, useWebSearch: false)
        return try decode(text, as: ApplicationQualityCheck.self)
    }

    func prepareInterview(profile: StudentProfile, role: String, company: String) async throws -> InterviewPrep {
        let text = try await client.run(prompt: """
        You are the Interview Prep agent. Build practical interview preparation grounded only in the student's resume and target.
        Return JSON only with role, behavioral_questions, technical_or_role_questions, story_prompts, preparation_plan.
        Resume: \(profile.resumeText). Role: \(role). Company: \(company)
        """, useWebSearch: true)
        return try decode(text, as: InterviewPrep.self)
    }

    func draftOutreach(profile: StudentProfile, contact: NetworkContact, opportunity: ApplicationRecord?, template: String) async throws -> OutreachDraft {
        let text = try await client.run(prompt: """
        You are the Outreach Drafter agent. Write a warm, concise networking message (under 120 words) for the student to manually
        review and send. Do not claim a referral, relationship, or shared experience that has not been supplied. Never ask for a job;
        ask for a brief perspective or advice. Use the student's template as a starting structure and personalize it, but do not
        retain placeholder braces. Return JSON only with recipient_name, subject, message, rationale.
        Student interests: \(profile.careerInterests). Contact: \(contact). Opportunity: \(String(describing: opportunity)). Template: \(template)
        """, useWebSearch: false)
        return try decode(text, as: OutreachDraft.self)
    }

    private func decode<T: Decodable>(_ text: String, as type: T.Type) throws -> T {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let objectStart = cleaned.firstIndex(of: "{")
        let arrayStart = cleaned.firstIndex(of: "[")
        guard let start = [objectStart, arrayStart].compactMap({ $0 }).min(),
              let end = [cleaned.lastIndex(of: "}"), cleaned.lastIndex(of: "]")].compactMap({ $0 }).max() else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No JSON object returned."))
        }
        let data = Data(cleaned[start...end].utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}
