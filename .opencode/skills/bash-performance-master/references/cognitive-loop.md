# Cognitive loop

Use `scripts/bash-cognitive-loop` as the outer controller for a small model. Do not ask an inner model session to launch this tool.

## Default OpenCode backend

```bash
"$SKILL_DIR/scripts/bash-cognitive-loop" preflight --backend opencode --project PROJECT
"$SKILL_DIR/scripts/bash-cognitive-loop" run --backend opencode \
  --project PROJECT --model MODEL --task "ONE FOCUSED TASK"
```

Use `--run-dir DIR` to select the artifact directory and `--timeout SECONDS` to bound each LLM session. The default is 900 seconds.

The controller creates a detached Git worktree and never commits, merges, or pushes. It executes these bounded stages:

1. read-only analysis returning a JSON plan;
2. implementation with this SKILL explicitly loaded;
3. deterministic harness and whitespace verification;
4. fresh, read-only adversarial review returning a JSON verdict;
5. at most one repair session when the verdict is `fix`;
6. final deterministic verification.

`reject`, missing JSON, an unauthorized edit, no diff, timeout, missing skill activation, or failed verification ends the run as failed.

## Artifacts

Read `state.json` first. Each LLM stage has:

- `STAGE.jsonl`: complete OpenCode event transcript;
- `STAGE.json`: validated plan or review contract, where applicable;
- `STAGE-metrics.json`: event, tool-call, and maximum-token counts.

Each verification has harness and `git diff --check` output files. Review the worktree diff manually before moving a patch into a real branch.

## Optional BMAD backend

### Specialized BMAD transport

`bmad-http` runs the same Bash-only state machine through BMAD Loop's hardened
OpenCode HTTP/SSE adapter. It creates one hermetic `opencode serve` process per
stage, exposes only the project copy of this SKILL, captures server events and
usage, bounds stalls, and requires an on-disk completion artifact.

```bash
"$SKILL_DIR/scripts/bash-cognitive-loop" preflight --backend bmad-http --project PROJECT
"$SKILL_DIR/scripts/bash-cognitive-loop" run --backend bmad-http \
  --project PROJECT --model MODEL --task "ONE FOCUSED BASH TASK"
```

Install the adapter in an isolated environment with
`pipx install 'bmad-loop[opencode]'`. This mode deliberately does not require a
BMAD sprint, `bmad-dev-auto`, or a BMAD Method installation: the controller's
scope remains Bash and this SKILL remains the implementation authority.

### Complete BMAD Method project

The `bmad-loop` backend delegates to a complete existing BMAD project:

```bash
"$SKILL_DIR/scripts/bash-cognitive-loop" preflight --backend bmad-loop --project PROJECT
```

It requires tmux, BMAD Method 6.10 or newer, `_bmad/bmm/config.yaml`, a configured
story queue, `bmad-dev-auto`, and its review skills. Use it only when those
requirements already exist. Do not install the entire BMAD Method merely to run
a focused Bash change; prefer `bmad-http` for this SKILL.

For a small model, require all of these safeguards:

- install BMM into both the OpenCode tree and BMAD Loop's hermetic tree with
  `--tools opencode,claude-code`;
- copy this SKILL to `.claude/skills/bash-performance-master`;
- set `[adapter] name = "opencode"` with a qualified free model ID;
- set `[scm] isolation = "worktree"` and keep failed worktrees;
- add this SKILL's `bash-harness check .` and `git diff --check` under
  `[verify].commands`;
- use stories mode with `spec_checkpoint: true`;
- approve a plan only when it names one observable failure and a behavioral
  regression test that fails when the proposed correction is absent.

Reject a plan before implementation when it merely improves source shape,
asserts that two trap declarations are structurally undesirable, or cannot
demonstrate an observable difference. BMAD adds planning and review capacity;
the checkpoint prevents that extra capacity from amplifying a weak premise.

The CLI backend enforces a wall-clock timeout and records usage after each turn.
The `bmad-http` backend additionally observes the turn over SSE, falls back to
HTTP polling, nudges a result-less idle turn once, and tears down its server.

## Hypothesis-first inference experiment

Run `scripts/bash-inference-loop` to test whether orchestration improves a small
model instead of merely increasing its token spend:

```bash
"$SKILL_DIR/scripts/bash-inference-loop" run --backend bmad-http \
  --project PROJECT --model MODEL --task "ONE BASH IMPROVEMENT"
```

The controller asks for one highest-confidence hypothesis, makes the model author a
baseline-failing Bats probe, executes that probe without a shell evaluator, and
uses a fresh checkpoint session to approve one observable failure. Only then
may another session implement. Acceptance requires fixed → pass, production
perturbed → fail, restored → pass, the Bash harness, a fresh review, and a
100-point `score.json`. It never commits, merges, or pushes.

Only direct `bats` argv arrays and project-local `.bats` paths are accepted. The
discovery, probe, checkpoint, and review stages receive smaller token ceilings than
implementation so rumination fails early without starving the actual correction.
Tracked `.opencode` and `.claude` skill overlays are orchestration state and are
excluded from product diffs; all other tracked changes remain guarded. Read `state.json`,
`*-evidence.json`, the three test logs, harness output, review JSON, and
`score.json`; never accept the model's prose alone.

## Interpreting results

BMAD transport improves isolation, termination evidence, logs, and budget
enforcement; it does not guarantee a better proposal. A small model can still
ruminate, broaden a one-change plan, or recommend a locally inappropriate tool.
Treat `over_budget`, missing terminal JSON, a multi-change plan, and advice that
contradicts this SKILL as failed runs. A model that repeatedly exhausts the bounded
discovery stage is unsuitable for open-ended defect selection; give it an
externally selected hypothesis or choose another model rather than raising the
budget indefinitely. Do not promote their partial patches.
