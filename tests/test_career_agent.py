from career_agent import extract_json, validate_research


def test_extract_json_handles_fence():
    assert extract_json("```json\n{\"questions\": []}\n```") == {"questions": []}


def test_validate_removes_unverified_opportunities():
    result = validate_research(
        {"opportunities": [
            {"company": "Good", "official_program_url": "https://example.com", "status": "open"},
            {"company": "Bad", "official_program_url": "not-a-url"},
        ]}
    )
    assert len(result["opportunities"]) == 1
    assert result["opportunities"][0]["status"] == "open"
