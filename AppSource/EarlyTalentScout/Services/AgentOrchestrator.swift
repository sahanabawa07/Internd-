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
        let researcher = try await ask(researchPrompt(profile: profile, context: context), web: true, name: "Program Researcher", progress: onProgress)
        let verified = try await ask(verificationPrompt(candidateJSON: researcher), web: true, name: "Link Verifier", progress: onProgress)
        let ranked = try await ask(rankingPrompt(profile: profile, verifiedJSON: verified), web: false, name: "Opportunity Ranker", progress: onProgress)
        return try decodeReport(ranked)
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
        Research 10–12 internships, early-talent programs, fellowships, exploration programs, and pre-internships for the student's NEXT summer.
        This is a planning search, not only a "what is open today" search. Include target-company programs first. Keep credible recurring, recently closed, or expected-next-cycle programs in the opportunities list if they have an official employer program, university recruiting, or careers page. Mark those recurring_watch, state the known or expected application timing in source_notes, and preserve the official URL.
        Do not move a company to watch_companies merely because its program is not open today.
        Build the discovery list from the student's interests, resume, career directions, and preferred locations first; the target-company list is only a secondary signal. Then add strong programs from other companies that match the student's stated career interests.
        Independently identify 8–12 additional organizations, firms, programs, fellowships, or ecosystem pathways outside the student's target list that they are unlikely to have thought of. Favor credible sophomore-accessible programs, early-insight pathways, or standard internships that credibly accept sophomores. Do not limit this list to large employers.
        Map adjacent paths deliberately when relevant: VC and private-equity firms or pipelines; banks and quant/trading firms; economic consulting and economic-advisory firms; government, multilateral, UN, and public-interest organizations; startup accelerators and startup ecosystems (for example Y Combinator-style organizations); and access programs such as Girls Who Invest, SEO, INROADS, or MLT. If the student lists cities such as New York City or Chicago, actively look for organizations and programs in those cities. Recommend only categories that genuinely connect to the student's interests and explain the connection.
        Prioritize first- and second-year student eligibility. Targets: \(profile.targetCompanies). Locations: \(profile.locations).
        Work authorization constraints: \(profile.workAuthorization). Student context: \(context).
        Search official employer career and program sites first. LinkedIn may be a supporting source only; never the only source.
        Return JSON only in this outer shape: {"opportunities":[...],"suggested_companies":[...],"watch_companies":[...]}. Use snake_case keys for each candidate program object:
        company, program, career_area, fit_reason, eligibility, location, status, posting_date, deadline, application_url, official_program_url, linkedin_url, source_notes, expected_application_timing, preparation_checklist, resume_focus, skill_focus.
        For every recurring or future program, provide an honest pre-application plan: expected_application_timing, preparation_checklist (2–4 actions), resume_focus (2–4 truthful themes/keywords), and skill_focus (1–3 skills to build). Clearly distinguish confirmed current requirements from historical, recurring, or inferred preparation guidance in source_notes. Each suggested_companies item may name a company, firm, nonprofit, government body, program provider, or accelerator; it needs company, category, why_it_fits, early_talent_pathway, official_careers_url. Do not repeat a target company. Use a real official careers/program URL when available; otherwise leave it null rather than inventing it. Use watch_companies only for relevant companies where you could not identify any credible sophomore-accessible program or recurring early-talent pathway. Each item needs company, reason, and official_careers_url. Do not make up URLs, eligibility, deadlines, or open status. Keep every field concise and return 10–12 candidates whenever official pages exist. In source_notes, say whether it is a target-company or interest match and whether it is open now, closed, or expected to return.
        """
    }

    private func verificationPrompt(candidateJSON: String) -> String {
        """
        You are the Link Verifier agent. Check each candidate below using web search. Keep only programs with an official
        employer, university, or program URL. An application URL must be employer-owned. This is a NEXT-SUMMER planning search:
        keep credible recurring or recently closed official programs in the candidate list even when no role is open today. Mark them recurring_watch,
        retain the official program, university recruiting, or careers page, and describe the availability honestly in source_notes. Use status open only if the
        official source shows an active opening today; otherwise use recurring_watch or unknown. Only remove a candidate when the program claim or official URL cannot be supported.
        Preserve expected_application_timing, preparation_checklist, resume_focus, and skill_focus when they are reasonable; remove or soften any item not supported by the source and keep it clearly framed as preparation guidance rather than a confirmed requirement. For suggested_companies, keep only non-target employers, organizations, programs, or accelerators with a credible interest-based reason to explore and an official URL when one was supplied. Never substitute a job-board link. Return the corrected JSON in the same outer shape {"opportunities":[...],"suggested_companies":[...],"watch_companies":[...]}; do not return prose.\n\nCandidates:\n\(candidateJSON)
        """
    }

    private func rankingPrompt(profile: StudentProfile, verifiedJSON: String) -> String {
        """
        You are the Opportunity Ranker agent. Rank the verified opportunities for this student, favoring first/second-year fit,
        stated interests, location constraints, and evidence from the resume. Rank suggested_companies by how much they expand the student's awareness beyond named targets while still fitting their interests; preserve a mix of direct employers and relevant programs/ecosystem pathways when justified. Preserve as many verified candidates as possible, including recurring next-cycle programs.
        Never move an opportunity into watch_companies merely because it is not currently open; watch_companies are only companies with no credible program pathway. Return JSON only in this exact shape:
        {"career_suggestions":[{"title":"","why":"","next_step":""}],"opportunities":[{"company":"","program":"","career_area":"","fit_reason":"","eligibility":"","location":"","status":"open|recurring_watch|unknown","posting_date":null,"deadline":null,"application_url":null,"official_program_url":"","linkedin_url":null,"source_notes":"","expected_application_timing":"","preparation_checklist":[""],"resume_focus":[""],"skill_focus":[""]}],"suggested_companies":[{"company":"","category":"","why_it_fits":"","early_talent_pathway":"","official_careers_url":null}],"watch_companies":[{"company":"","reason":"","official_careers_url":null}],"skill_suggestions":[{"title":"","why":"","next_step":""}],"research_notes":[""]}
        Use every verified URL exactly as given; never invent a URL. Student: \(profile.careerInterests). Verified input:\n\(verifiedJSON)
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
                skillFocus: item.skillFocus ?? []
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
        let skills = (loose.skillSuggestions ?? []).compactMap { item -> SkillSuggestion? in
            guard let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            return SkillSuggestion(title: title, why: item.why ?? "This skill appears often in your strongest matches.", nextStep: item.nextStep ?? "Choose one small practice step this week.")
        }
        return ResearchReport(
            careerSuggestions: directions,
            opportunities: opportunities,
            suggestedCompanies: suggestedCompanies,
            watchCompanies: watched,
            skillSuggestions: skills,
            researchNotes: loose.researchNotes ?? []
        )
    }

    private struct LooseResearchReport: Decodable {
        var careerSuggestions: [LooseCareerDirection]?
        var opportunities: [LooseOpportunity]?
        var suggestedCompanies: [LooseCompanySuggestion]?
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
