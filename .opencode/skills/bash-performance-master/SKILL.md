---
name: bash-performance-master
description: Create, refactor, review, debug, and optimize GNU Bash scripts with deterministic scaffolds, reusable components, compatibility guidance, and automated validation. Use for new .sh files, Bash CLIs, batch file processing, stream filters, scripts managing temporary resources or signals, ShellCheck remediation, and performance work where correctness, safety, portability, and measured efficiency matter.
---

# Bash Performance Master

Resolve `SKILL_DIR` as the directory containing this `SKILL.md` from the loader-provided skill location. Invoke every bundled helper as `"$SKILL_DIR/scripts/HELPER"`; never assume the project working directory contains the helpers. Generate Bash from tested archetypes. Preserve this priority: correctness, safety, observable behavior, required compatibility, maintainability, then measured performance.

## Required workflow

1. Inspect the request and existing code.
2. Run `"$SKILL_DIR/scripts/bash-harness" doctor` and resolve missing required tooling before implementation.
3. Select an archetype with `"$SKILL_DIR/scripts/bash-new" --list-types`.
4. Generate new scripts with `"$SKILL_DIR/scripts/bash-new"`; do not recreate standard infrastructure manually.
5. Add supported capabilities with `"$SKILL_DIR/scripts/bash-add"`.
6. Implement only task-specific behavior in the marked region.
7. Run `"$SKILL_DIR/scripts/bash-harness" check PROJECT` (or `"$SKILL_DIR/scripts/bash-check" SCRIPT`) after every material edit and fix all errors.
8. Test hostile filenames, empty inputs, command failures, and relevant signals.
9. Make performance claims only after establishing semantic equivalence and measuring with `"$SKILL_DIR/scripts/bash-bench"`.
10. Before publishing improvements to a real project, run
    `"$SKILL_DIR/scripts/bash-release-init" PROJECT` once, then run
    `"$SKILL_DIR/scripts/bash-release-gate" PROJECT BASE_REF`. Do not push, merge,
    tag, or report publication complete unless the project version changed with
    the improvements. An explicit user request for an unreleased development
    branch is the only exception; state that no release/version bump was made.

## Select an archetype

| Type | Select for |
|---|---|
| `minimal` | Small single-purpose automation |
| `cli` | Flags, help text, and positional arguments |
| `batch-files` | Safe filesystem processing |
| `stream-filter` | stdin-to-stdout transformations |
| `managed-resource` | Temporary state, child processes, or cleanup |

```bash
"$SKILL_DIR/scripts/bash-new" --type cli --output ./tool.sh \
  --bash-min 4.3 --strict balanced --with logging,tempdir
```

Use `--force` only when the user explicitly authorizes overwriting the exact target.

## Add and validate

```bash
"$SKILL_DIR/scripts/bash-add" --list
"$SKILL_DIR/scripts/bash-add" ./tool.sh logging retry
"$SKILL_DIR/scripts/bash-check" ./tool.sh
"$SKILL_DIR/scripts/bash-harness" check .
```

Use `"$SKILL_DIR/scripts/bash-harness" init PROJECT` to create conservative `.shellcheckrc` and `.editorconfig` files without overwriting existing configuration. Use `"$SKILL_DIR/scripts/bash-harness" fix PROJECT` only when formatting changes are authorized, inspect the diff, then rerun `check`. The validator always runs `bash -n` and policy checks. It runs ShellCheck when installed. Do not claim optional checks passed when their tools are unavailable.

## Gate publication with a version change

Treat “published” as a release outcome, not merely a pushed branch or merged PR.
Use the installed pre-push hook for fast local feedback and the installed GitHub
Actions workflow as the authoritative gate. A hook is bypassable; require the
`version-gate` check in branch protection to make the policy enforceable.
Before any real-project publication:

1. Identify the canonical version source and the repository's bump/release tool.
2. Choose the semantic increment from user-visible impact.
3. Update the canonical version, changelog, generated metadata, and package/manual
   versions that the project contract requires.
4. Run `"$SKILL_DIR/scripts/bash-release-gate" PROJECT BASE_REF`.
5. Run project tests, commit the bump, push, merge as authorized, create the tag,
   and publish the release artifacts.
6. Verify remotely that the default branch, tag, release title, and runtime
   `--version` agree before reporting success.

The gate accepts explicit version paths after `BASE_REF` for unusual projects.
Never create a tag or release automatically unless the user authorized that
external publication.

## Optimize with constraints

- Prefer builtins for small in-memory scalar operations when semantics remain equivalent.
- Emit a static multi-line menu, help message, or banner with one `printf` call and one quoted multi-line argument; do not stack one `echo` per line. Use `assets/snippets/multiline-output.sh` as the model.
- Prefer streaming tools for large data, complex records, sorting, or recursive queries.
- Do not replace `touch` with truncation, `dirname`/`basename` blindly with parameter expansion, `find` universally with `globstar`, or `2>/dev/null` with a closed descriptor.
- Avoid unbounded brace expansions, `eval`, predictable temporary paths, parsing `ls`, and implicit word splitting.
- Treat `set -e` as a control-flow choice, not a universal safety switch.

Read [references/toolchain.md](references/toolchain.md) before installing or configuring development tools. Read [references/decision-matrix.md](references/decision-matrix.md) before refactoring or selecting strictness. Read [references/bash-compatibility.md](references/bash-compatibility.md) when the Bash version matters. Read [references/optimization-rules.md](references/optimization-rules.md) before performance work.

## Preserve behavior

Record inputs, outputs, exit codes, stderr, filesystem effects, signal behavior, environment/export requirements, translation interpolation, and supported Bash version before refactoring. Add characterization tests when behavior is not covered. Reject an optimization when equivalence cannot be demonstrated.

## Orchestrate a small model

For an autonomous repository improvement performed by a small model, run `"$SKILL_DIR/scripts/bash-cognitive-loop"` as the outer controller. Do not delegate control of the loop to an inner LLM session. The controller isolates work in a detached worktree, separates analysis, implementation, and review contexts, validates JSON contracts, limits repair to one pass, and runs this SKILL's harness between stages. Read [references/cognitive-loop.md](references/cognitive-loop.md) before using it.

Prefer the dependency-free `opencode` backend. Use `bmad-http` when BMAD Loop's
hermetic HTTP/SSE transport, stall handling, and token budget justify the extra
dependency. Treat the complete `bmad-loop` backend as optional and only for an
already-configured BMAD v6 project. Transport hardening does not replace this
SKILL's contracts, behavioral tests, or independent review.

When a small model runs through complete BMAD, require a plan checkpoint before
implementation. Reject any plan that cannot state one observable failure and a
behavioral test that fails with the uncorrected production artifact. Read
[references/cognitive-loop.md](references/cognitive-loop.md) for the complete
BMAD safeguards.

To measure inference quality, run `"$SKILL_DIR/scripts/bash-inference-loop"` as
the outer controller. Require its hypothesis probe, independent checkpoint,
fixed/perturbed/restored proof, harness, review, and score.


## Test behavior, not source shape

Prefer behavioral assertions over tests that only grep implementation text. Execute or source the production artifact under test; never copy the production function into a fixture or inline test and claim that the copy validates production. Fixtures may replace external dependencies, but not the implementation being tested. Every test must contain an assertion that can fail because of an observed output, exit status, signal, or filesystem effect. Never use `true`, `[ true ]`, `:`, or a successful command alone as proof. Do not substitute `trap -p`, `declare -f`, `grep` of source text, or similar implementation-shape checks for the claimed runtime behavior. Deliberately revert or perturb the production change and confirm the regression test fails before accepting it. Cover cleanup on success, failure, `INT`, and `TERM`; preserve the original exit status; verify exported variables required by subprocesses and `eval_gettext`; and test argument values at option boundaries. A passing syntax check or a test that merely finds a function name does not demonstrate behavior.

Do not run project-wide formatting as part of a focused semantic change. The initialized harness blocks ShellCheck warnings/errors, treats formatting as advisory, and caps `fix` at 200 changed lines per file. Treat pre-existing info/style findings as a separate ratchet instead of expanding a focused patch. If the cap is exceeded, keep the semantic patch focused and propose formatting adoption as a separate user-authorized change. Never bypass the cap by invoking shfmt directly.
