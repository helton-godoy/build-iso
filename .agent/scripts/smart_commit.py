#!/usr/bin/env python3
import re
import subprocess
import sys
from pathlib import Path


def run_command(command):
    """Executes a shell command and returns the output."""
    try:
        result = subprocess.run(
            command,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {command}")
        print(e.stderr)
        return None


def get_changed_files():
    """Returns a list of changed files (staged and unstaged)."""
    # Check for unstaged changes
    unstaged = run_command("git diff --name-only")
    # Check for staged changes
    staged = run_command("git diff --name-only --cached")

    files = set()
    if unstaged:
        files.update(unstaged.splitlines())
    if staged:
        files.update(staged.splitlines())

    return list(files)


def determine_commit_type(files):
    """Determines the semantic commit type based on file patterns."""

    # Priority rules
    patterns = {
        "test": [r"test/", r"tests/", r"spec/", r"\.bats$", r"test_.*\.py$"],
        "docs": [r"docs/", r"\.md$", r"LICENSE", r"COPYING"],
        "ci": [
            r"\.github/",
            r"\.gitlab-ci",
            r"\.trunk/",
            r"Makefile",
            r"Dockerfile",
            r"docker-compose",
        ],
        "style": [r"\.css$", r"\.scss$", r"\.less$", r"trunk.yaml", r"\.editorconfig"],
        "feat": [
            r"src/",
            r"app/",
            r"lib/",
            r"scripts/",
            r"\.py$",
            r"\.sh$",
            r"\.js$",
            r"\.ts$",
        ],
    }

    counts = {key: 0 for key in patterns}

    for file in files:
        for type_key, regex_list in patterns.items():
            for regex in regex_list:
                if re.search(regex, file):
                    counts[type_key] += 1
                    break

    # Determine dominant type
    if not files:
        return "chore"

    # If mostly tests
    if counts["test"] > 0 and counts["test"] >= len(files) * 0.5:
        return "test"

    # If mostly docs
    if counts["docs"] > 0 and counts["docs"] >= len(files) * 0.8:
        return "docs"

    # If CI/Build configs
    if counts["ci"] > 0 and counts["ci"] >= len(files) * 0.5:
        return "ci"

    # If source code
    if counts["feat"] > 0:
        return "feat"  # Default to feature for code changes, agent can refine if needed

    return "chore"


def generate_commit_message(commit_type, files):
    """Generates a simple semantic commit message."""

    if len(files) == 1:
        subject = f"update {files[0]}"
    elif len(files) <= 3:
        filenames = ", ".join([Path(f).name for f in files])
        subject = f"update {filenames}"
    else:
        # Identify common directory
        common_path = Path(files[0]).parent
        subject = f"update files in {common_path}"

    return f"{commit_type}: {subject}"


def main():
    print("🤖 Agent Smart Commit System")

    # 1. Check for changes
    files = get_changed_files()
    if not files:
        print("No changes to commit.")
        sys.exit(0)

    print(f"Found {len(files)} changed file(s).")

    # 2. Stage all changes
    print("Staging changes...")
    run_command("git add -A")

    # 3. Analyze and Commit
    commit_type = determine_commit_type(files)
    message = generate_commit_message(commit_type, files)

    print(f"Committing with message: '{message}'")
    run_command(f'git commit -m "{message}"')

    print("✅ Smart Commit complete.")


if __name__ == "__main__":
    main()
