# Internd

## Native macOS multi-agent app

The project now also includes a native macOS SwiftUI app under `Sources/`. It has five bounded roles:

1. **Resume Analyst** — extracts evidence-backed skills and directions.
2. **Career Strategist** — maps interests and constraints to possible paths.
3. **Program Researcher** — searches official early-talent programs.
4. **Link Verifier** — checks official pages, application URLs, and open status.
5. **Opportunity Ranker** — returns a tailored, source-preserving shortlist.
6. **Network Scout** — matches an exported LinkedIn-connections CSV with the student's school, past experience, and targets; it never accesses a logged-in LinkedIn account.
7. **Resume Tailor** — provides truth-preserving, role-specific resume suggestions.
8. **Outreach Drafter** — creates editable, personalized networking-message drafts from the user's template; it never sends messages automatically.
9. **Skills-Gap Planner** — produces a realistic four-week development and portfolio plan for a target role.
10. **Company Intelligence** — researches primary-source company and early-talent context, interview themes, and conversation starters.
11. **Application Quality Check** — checks materials before submission and names what is still missing.
12. **Interview Prep** — creates tailored behavioral, role-specific, and story-practice prompts.

The application tracker saves locally on the Mac and captures program, posting date, deadline, requirements, application link, outreach status, and notes. It exports a CSV compatible with Excel, Numbers, and Google Sheets. The relationship CRM records shared context, last contact, follow-up date, relationship strength, and conversation notes. The Insights & Privacy screen gives basic funnel metrics and lets the user delete locally stored tracker and relationship data.

Run it on macOS 14 or later with `./script/build_and_run.sh`. Add your OpenAI API key from the app’s Settings window; it is stored in macOS Keychain, not in the app’s preferences or source files.

An AI career-research assistant for college students. It reads a resume, runs a short career interview, and researches internships and early-talent programs that fit the student — with direct application links and source URLs.

## What it does

- Extracts skills, experiences, and possible career directions from a PDF, DOCX, or TXT resume.
- Generates a small set of useful career questions rather than a generic long questionnaire.
- Accepts target companies, locations, work authorization, interests, and year in school.
- Searches the web for first- and second-year-friendly opportunities across the student’s fields and target companies.
- Ranks opportunities by fit and labels them as `open`, `recurring / watch`, or `unknown`.
- Requires a primary company careers or program page for each recommendation. LinkedIn is a secondary discovery signal, never the sole application source.

## Run locally

1. Use Python 3.11+ and create a virtual environment.
2. Install dependencies: `pip install -r requirements.txt`
3. Copy `.env.example` to `.env` and add your OpenAI API key.
4. Start the app: `streamlit run app.py`

The app uses the OpenAI Responses API with web search enabled. Search results change constantly, so it checks the live company page before presenting an application URL. No result should be treated as an application guarantee; students should always re-check eligibility and deadline on the employer page.

## Responsible research rules built into the prompt

- Prefer the employer’s own careers and university-program pages.
- Never invent an application URL, deadline, eligibility rule, or LinkedIn URL.
- Do not scrape, log into, or bypass LinkedIn. Public LinkedIn pages may be cited only when the search tool can access them.
- Do not filter or rank based on protected traits. The student controls their career interests and targets.

## Next production steps

For a multi-user deployment, add authentication, encrypted resume storage with a deletion control, a database for saved searches, a background refresh job, rate limits, and human review for high-stakes eligibility claims.
