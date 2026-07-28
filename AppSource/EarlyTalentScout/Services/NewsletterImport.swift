import Foundation

enum NewsletterImport {
    static let cceJuly2026Key = "internd.imported.cce.july2026"

    static func cceJuly2026Opportunities() -> [Opportunity] {
        func item(_ company: String, _ program: String, _ area: String, _ url: String, deadline: String? = nil) -> Opportunity {
            let officialURL = URL(string: url)!
            return Opportunity(
                company: company,
                program: program,
                careerArea: area,
                fitReason: "Imported from Columbia CCE’s July 23, 2026 Career Opportunities Newsletter.",
                eligibility: "Confirm current eligibility and requirements on the official page.",
                location: "See official posting",
                status: "unknown",
                postingDate: "Listed by Columbia CCE · Jul 23, 2026",
                deadline: deadline,
                applicationURL: nil,
                officialProgramURL: officialURL,
                linkedInURL: nil,
                sourceNotes: "Imported from the Columbia CCE newsletter. The email did not retain the original application link, so this opens the organization’s official careers or program hub.",
                expectedApplicationTiming: "Check the official page for the live application and current deadline.",
                preparationChecklist: ["Open the official page", "Confirm eligibility and deadline", "Save the exact posting to your tracker"],
                resumeFocus: [],
                skillFocus: [],
                officialSourceType: "Columbia CCE newsletter + official careers hub",
                verifiedFacts: [VerifiedFact(label: "Newsletter source", value: "Listed in Columbia CCE Career Opportunities Newsletter dated July 23, 2026.", classification: "historical", sourceURL: officialURL)]
            )
        }

        return [
            item("Bain", "Associate Consultant Intern · Summer 2027", "Consulting", "https://www.bain.com/careers/", deadline: "August 31, 2026 (newsletter’s second deadline)"),
            item("Simon-Kucher", "Summer 2027 Intern · Healthcare & Life Sciences", "Consulting", "https://www.simon-kucher.com/en/careers"),
            item("Standard Chartered", "Strategic Solutions & Advisory Internship Programme", "Finance", "https://www.sc.com/en/global-careers/"),
            item("Standard Chartered", "Client Coverage Internship Programme", "Finance", "https://www.sc.com/en/global-careers/"),
            item("Standard Chartered", "Global Banking Internship Programme", "Finance", "https://www.sc.com/en/global-careers/"),
            item("Standard Chartered", "Transaction Services Internship Programme", "Finance", "https://www.sc.com/en/global-careers/"),
            item("Bank of America", "Summer 2027 internships · Various roles", "Finance", "https://careers.bankofamerica.com/"),
            item("Morgan Stanley", "Summer 2027 internships · Various roles", "Finance", "https://www.morganstanley.com/careers/"),
            item("AQR Capital Management", "Summer 2027 internships · Various roles", "Quantitative finance", "https://www.aqr.com/About-Us/Careers"),
            item("JPMorganChase", "Summer 2027 internships", "Finance", "https://www.jpmorganchase.com/careers/students/programs"),
            item("BNP Paribas", "Summer 2027 internships · Various roles", "Finance", "https://group.bnpparibas/en/careers"),
            item("BlackRock", "Technology & Operations Internship", "Asset management and technology", "https://careers.blackrock.com/students-and-graduates"),
            item("Optiver", "Quantitative Intern", "Quantitative trading", "https://optiver.com/working-at-optiver/"),
            item("Susquehanna International Group", "Quantitative Trader Internship", "Quantitative trading", "https://careers.sig.com/students/"),
            item("IMC Trading", "Quantitative Research Intern · BS/MS", "Quantitative trading", "https://www.imc.com/us/careers/"),
            item("D. E. Shaw", "Quantitative Analyst Intern", "Quantitative research", "https://www.deshaw.com/careers"),
            item("Two Sigma", "Quantitative Researcher Internship", "Quantitative research", "https://www.twosigma.com/careers/"),
            item("Walleye Capital", "Central Equity Quant Research Intern", "Quantitative finance", "https://walleye.com/careers/"),
            item("Veeva", "Analytics Development Program · Client Services Associate", "Marketing analytics", "https://careers.veeva.com/"),
            item("Veeva", "Analytics Development Program · Marketing Data Analyst", "Marketing analytics", "https://careers.veeva.com/"),
            item("Columbia Venture Community", "Venture Talent Network", "Startups and venture capital", "https://www.columbiaventurecommunity.com/"),
            item("W. W. Norton", "Fall 2026 Editorial Internships", "Publishing", "https://wwnorton.com/careers"),
            item("The Morgan Library & Museum", "Academic Year Internships", "Arts and culture", "https://www.themorgan.org/about/careers"),
            item("Jazz at Lincoln Center", "Intern · Oral History & Archives", "Arts and archives", "https://2024.jazz.org/careers"),
            item("Public Citizen", "Climate and Insurance Policy Internship", "Public interest and policy", "https://www.citizen.org/about/careers/"),
            item("The New York Post", "Internship Program · Video Room Control Intern", "Media", "https://nypost.com/careers/"),
            item("Democracy Now!", "Archive / Fundraising and Outreach Internships", "Media and nonprofit", "https://www.democracynow.org/about/jobs"),
            item("New York City Ballet", "Internship Program", "Arts administration", "https://www.nycballet.com/about-us/careers/"),
            item("The Legal Aid Society", "Investigative Intern", "Legal services and public interest", "https://legalaidnyc.org/careers/")
        ]
    }
}
