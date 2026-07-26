from __future__ import annotations

import os
from datetime import date

import streamlit as st
from docx import Document
from dotenv import load_dotenv
from openai import OpenAI
from pypdf import PdfReader

from career_agent import ask_intake_questions, research_opportunities


load_dotenv()
st.set_page_config(page_title="Internd", page_icon="🧭", layout="wide")


def resume_text(uploaded_file) -> str:
    suffix = uploaded_file.name.lower().rsplit(".", 1)[-1]
    if suffix == "pdf":
        return "\n".join(page.extract_text() or "" for page in PdfReader(uploaded_file).pages)
    if suffix == "docx":
        return "\n".join(p.text for p in Document(uploaded_file).paragraphs)
    return uploaded_file.getvalue().decode("utf-8", errors="ignore")


def require_client() -> OpenAI | None:
    key = os.getenv("OPENAI_API_KEY")
    if not key:
        st.error("Add OPENAI_API_KEY to a local .env file before running research.")
        return None
    return OpenAI(api_key=key)


def link(label: str, url: str | None) -> None:
    if url:
        st.markdown(f"[{label}]({url})")


st.title("🧭 Internd")
st.caption("Resume-led career coaching and primary-source internship research for first- and second-year students.")

with st.sidebar:
    st.header("About your search")
    school_year = st.selectbox("College year", ["First year", "Second year", "Other / prefer not to say"])
    graduation = st.text_input("Expected graduation (optional)", placeholder="May 2029")
    locations = st.text_input("Locations / remote preference", placeholder="Chicago, Austin, remote")
    work_auth = st.text_input("Work authorization or visa constraints (optional)")
    targets = st.text_area("Target companies", placeholder="Microsoft, Adobe, Deloitte")
    interests = st.text_area("Career interests", placeholder="Product management, climate tech, data analytics")

uploaded = st.file_uploader("Upload your resume", type=["pdf", "docx", "txt"])
if uploaded:
    try:
        text = resume_text(uploaded)
        if not text.strip():
            st.warning("I couldn't extract text from this resume. Try a text-based PDF, DOCX, or TXT file.")
        else:
            st.session_state["resume_text"] = text
            st.success(f"Resume loaded from {uploaded.name}")
    except Exception as exc:
        st.error(f"Could not read the resume: {exc}")

if "resume_text" in st.session_state and st.button("1. Create my career interview", type="primary"):
    client = require_client()
    if client:
        with st.spinner("Finding the most useful questions…"):
            intake = ask_intake_questions(client, os.getenv("OPENAI_MODEL", "gpt-5.6-terra"), st.session_state["resume_text"])
        st.session_state["intake"] = intake

intake = st.session_state.get("intake")
answers: dict[str, str] = {}
if intake:
    st.subheader("Your short career interview")
    st.write(intake.get("resume_summary", ""))
    st.caption("Potential directions: " + ", ".join(intake.get("possible_directions", [])))
    with st.form("career_questions"):
        for index, question in enumerate(intake.get("questions", [])):
            answers[question] = st.text_area(question, key=f"answer_{index}")
        submitted = st.form_submit_button("2. Research matching programs", type="primary")
    if submitted:
        client = require_client()
        if client:
            profile = {
                "resume": st.session_state["resume_text"][:18000],
                "school_year": school_year,
                "expected_graduation": graduation,
                "locations": locations,
                "work_authorization": work_auth,
                "target_companies": targets,
                "stated_interests": interests,
                "career_interview_answers": answers,
            }
            with st.spinner("Checking company program pages and current application links…"):
                st.session_state["results"] = research_opportunities(
                    client, os.getenv("OPENAI_MODEL", "gpt-5.6-terra"), profile, date.today().isoformat()
                )

results = st.session_state.get("results")
if results:
    st.subheader("Career directions to explore")
    for idea in results["career_suggestions"]:
        st.markdown(f"**{idea.get('title', 'Career direction')}** — {idea.get('why', '')}  \nNext step: {idea.get('next_step', '')}")

    st.subheader("Programs and internships")
    st.caption("Status is based on the official page at research time. Re-check eligibility and deadlines before applying.")
    for item in results["opportunities"]:
        icon = {"open": "🟢 Open", "recurring_watch": "🟡 Watch", "unknown": "⚪ Verify"}[item["status"]]
        with st.expander(f"{icon} · {item.get('company')} — {item.get('program')}"):
            st.write(item.get("fit_reason", ""))
            st.write(f"**Area:** {item.get('career_area', 'Not specified')}  ")
            st.write(f"**Eligibility:** {item.get('eligibility', 'Verify on source')}  ")
            st.write(f"**Location:** {item.get('location', 'Not specified')}  ")
            st.write(f"**Deadline:** {item.get('deadline') or 'Not confirmed'}")
            link("Official program page", item.get("official_program_url"))
            link("Apply", item.get("application_url"))
            link("LinkedIn (supporting source)", item.get("linkedin_url"))
            st.caption(item.get("source_notes", ""))
    if results["research_notes"]:
        st.info(" ".join(results["research_notes"]))
