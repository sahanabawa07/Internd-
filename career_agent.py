"""Core prompts and response parsing for the Internd app."""

from __future__ import annotations

import json
import re
from typing import Any

from openai import OpenAI


INTAKE_PROMPT = """
You are a thoughtful career coach for a college student. Read the resume below and
return exactly five concise questions that would materially improve internship
recommendations. Cover missing information such as year/expected graduation,
location/work authorization, preferred work style, career interests, and constraints.
Do not ask for protected personal information. Return valid JSON only:
{"resume_summary":"...", "possible_directions":["..."], "questions":["..."]}

RESUME:
{resume}
"""

RESEARCH_PROMPT = """
You are an exacting early-talent program researcher. Research internships,
exploration programs, fellowships, pre-internships, and similar experiences for a
college student. Use web search. The current date is {today}.

Student profile:
{profile}

Requirements:
1. Look at the student’s named target companies first, then leading companies and
   credible organizations in the student’s stated fields. Include adjacent career
   directions only when the resume/interview supports the fit.
2. Prioritize first- and second-year-friendly programs. Regular internships that
   explicitly accept the student’s year can be included too.
3. For every item, verify its existence on an employer-owned careers, university,
   or program page. Use an employer-owned application URL when one is available.
4. LinkedIn can be a discovery/corroboration source only. Do not log in, scrape,
   bypass access controls, or use LinkedIn as the only source for a recommendation.
5. Never guess URLs, deadlines, eligibility, sponsorship, compensation, or open
   status. If a program is recurring but no current application is found, label it
   "recurring_watch" and provide its official program or careers URL instead.
6. Only label an opportunity "open" when the official page indicates it is open
   now. Use "unknown" if the status cannot be established.
7. Give 8–15 non-duplicative recommendations, sorted by fit. A mix of targets and
   well-matched suggestions is better than a list of famous companies.

Return valid JSON only, matching this schema:
{
  "career_suggestions":[{"title":"string","why":"string","next_step":"string"}],
  "opportunities":[{
    "company":"string", "program":"string", "career_area":"string",
    "fit_reason":"string", "eligibility":"string", "location":"string",
    "status":"open|recurring_watch|unknown", "deadline":"string|null",
    "application_url":"string|null", "official_program_url":"string",
    "linkedin_url":"string|null", "source_notes":"string"
  }],
  "research_notes":["string"]
}
"""


def extract_json(text: str) -> dict[str, Any]:
    """Parse model JSON even if it was accidentally wrapped in a code fence."""
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip())
    start, end = cleaned.find("{"), cleaned.rfind("}")
    if start < 0 or end < start:
        raise ValueError("The research response did not contain JSON.")
    return json.loads(cleaned[start : end + 1])


def ask_intake_questions(client: OpenAI, model: str, resume_text: str) -> dict[str, Any]:
    response = client.responses.create(
        model=model,
        input=INTAKE_PROMPT.format(resume=resume_text[:18000]),
    )
    return extract_json(response.output_text)


def research_opportunities(
    client: OpenAI, model: str, profile: dict[str, Any], today: str
) -> dict[str, Any]:
    response = client.responses.create(
        model=model,
        tools=[{"type": "web_search"}],
        input=RESEARCH_PROMPT.format(
            profile=json.dumps(profile, indent=2), today=today
        ),
    )
    results = extract_json(response.output_text)
    return validate_research(results)


def validate_research(results: dict[str, Any]) -> dict[str, Any]:
    """Keep the UI safe if the model omits essential source fields."""
    allowed_statuses = {"open", "recurring_watch", "unknown"}
    valid: list[dict[str, Any]] = []
    for item in results.get("opportunities", []):
        official_url = item.get("official_program_url")
        if not isinstance(official_url, str) or not official_url.startswith(("https://", "http://")):
            continue
        item["status"] = item.get("status") if item.get("status") in allowed_statuses else "unknown"
        for key in ("application_url", "linkedin_url"):
            if item.get(key) and not str(item[key]).startswith(("https://", "http://")):
                item[key] = None
        valid.append(item)
    results["opportunities"] = valid
    results.setdefault("career_suggestions", [])
    results.setdefault("research_notes", [])
    return results
