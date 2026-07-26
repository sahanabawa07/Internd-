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
        Research 6–8 internships, early-talent programs, fellowships, exploration programs, and pre-internships.
        Prioritize first- and second-year student eligibility. Targets: \(profile.targetCompanies). Locations: \(profile.locations).
        Work authorization constraints: \(profile.workAuthorization). Student context: \(context).
        Search official employer career and program sites first. LinkedIn may be a supporting source only; never the only source.
        Return JSON only, using snake_case keys for candidate program objects with company, program, career_area,
        fit_reason, eligibility, location, status, posting_date, deadline, application_url, official_program_url, linkedin_url, source_notes.
        Do not make up URLs, eligibility, deadlines, or open status. Keep every field concise and return no more than eight candidates.
        """
    }

    private func verificationPrompt(candidateJSON: String) -> String {
        """
        You are the Link Verifier agent. Check each candidate below using web search. Keep only programs with an official
        employer, university, or program URL. An application URL must be employer-owned. Mark status open only if the
        official source shows an active opening today; otherwise use recurring_watch or unknown. Never substitute a job-board
        link. Return corrected candidate JSON only.\n\nCandidates:\n\(candidateJSON)
        """
    }

    private func rankingPrompt(profile: StudentProfile, verifiedJSON: String) -> String {
        """
        You are the Opportunity Ranker agent. Rank the verified opportunities for this student, favoring first/second-year fit,
        stated interests, location constraints, and evidence from the resume. Return JSON only in this exact shape:
        {"career_suggestions":[{"title":"","why":"","next_step":""}],"opportunities":[{"company":"","program":"","career_area":"","fit_reason":"","eligibility":"","location":"","status":"open|recurring_watch|unknown","posting_date":null,"deadline":null,"application_url":null,"official_program_url":"","linkedin_url":null,"source_notes":""}],"research_notes":[""]}
        Use every verified URL exactly as given; never invent a URL. Student: \(profile.careerInterests). Verified input:\n\(verifiedJSON)
        """
    }

    private func decodeReport(_ text: String) throws -> ResearchReport {
        try decode(text, as: ResearchReport.self)
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
