#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

# Mapa de Personas e Skills (Baseado no GEMINI.md e estrutura de diretórios)
PERSONA_MAP = {
    "frontend": {
        "agent": "frontend-specialist",
        "skills": ["frontend-design", "webapp-testing", "clean-code"],
    },
    "backend": {
        "agent": "backend-specialist",
        "skills": ["api-patterns", "database-design", "clean-code"],
    },
    "devops": {
        "agent": "devops-engineer",
        "skills": ["deployment-procedures", "bash-linux", "powershell-windows"],
    },
    "security": {
        "agent": "security-auditor",
        "skills": ["vulnerability-scanner", "red-team-tactics"],
    },
    "planner": {
        "agent": "project-planner",
        "skills": ["plan-writing", "brainstorming"],
    },
    "tester": {
        "agent": "test-engineer",
        "skills": ["testing-patterns", "tdd-workflow"],
    },
}


def analyze_intent(query):
    """Simple keyword matching to suggest persona."""
    query = query.lower()

    if any(x in query for x in ["css", "html", "react", "ui", "ux", "design"]):
        return "frontend"
    if any(x in query for x in ["api", "db", "database", "sql", "server"]):
        return "backend"
    if any(
        x in query for x in ["ci", "cd", "deploy", "docker", "pipeline", "iso", "linux"]
    ):
        return "devops"
    if any(x in query for x in ["security", "hack", "audit", "vuln"]):
        return "security"
    if any(x in query for x in ["plan", "roadmap", "architecture"]):
        return "planner"
    if any(x in query for x in ["test", "quality", "bug", "fix"]):
        return "tester"

    return "devops"  # Default for this project (build-iso)


def main():
    parser = argparse.ArgumentParser(description="Agent Task Router")
    parser.add_argument("query", nargs="*", help="The user task or query")
    args = parser.parse_args()

    query_text = " ".join(args.query)
    category = analyze_intent(query_text)
    recommendation = PERSONA_MAP.get(category)

    print("\n🤖 **INTELLIGENT ROUTING SYSTEM**")
    print("===============================")
    print(f"Detected Intent: {category.upper()}")
    print(f"Recommended Persona: @{recommendation['agent']}")
    print(f"Suggested Skills: {', '.join(recommendation['skills'])}")
    print("===============================")
    print("INSTRUCTIONS FOR AGENT:")
    print("1. Read the recommended Agent File (.agent/agents/...)")
    print("2. Read the recommended Skill Files (.agent/skills/...)")
    print("3. Execute task.")
    print("4. RUN .agent/scripts/smart_commit.py AT THE END.")
    print("================================\n")


if __name__ == "__main__":
    main()
