# llamy — Backlog

<!--
AGENT INSTRUCTIONS — READ THIS BEFORE MODIFYING THIS FILE
──────────────────────────────────────────────────────────
This file is the shared backlog for llamy. It is read and written by both
humans and AI agents. Follow these rules exactly.

## Task format

Each task is a level-3 heading followed by a metadata block, a description,
and optional sections. The full schema:

```
### [STATUS] Short imperative title (#ID)

- **ID**: LLAMY-N          (increment from last used ID)
- **Type**: bug | feature | improvement | refactor
- **Priority**: high | medium | low
- **Effort**: small | medium | large
- **Added**: YYYY-MM-DD
- **Updated**: YYYY-MM-DD
- **Author**: name or "agent"

#### Problem / Motivation
Why this needs doing.

#### Proposed Solution
What to build and how.

#### Implementation Notes
Specific code locations, edge cases, decisions already made.

#### Acceptance Criteria
- [ ] Checkable outcomes that define "done"

#### Dependencies
Other tasks or external requirements this depends on.
```

## Status values

- `[PLANNED]`   — approved, not yet started
- `[IN PROGRESS]` — actively being worked on (update the file to reflect this)
- `[BLOCKED]`   — waiting on something external
- `[DONE]`      — completed (move to ## Completed section, keep for reference)
- `[REJECTED]`  — decided not to do; leave a brief reason

## Rules for agents

1. Before starting a task, change its status to `[IN PROGRESS]` and update
   the **Updated** date.
2. When complete, change status to `[DONE]`, fill in any relevant outcomes,
   and move the entire task block to the ## Completed section.
3. Never delete a task — use `[REJECTED]` with a reason instead.
4. When adding a new task, assign the next sequential ID (check the highest
   existing ID first).
5. Keep the Planned section sorted by Priority (high → medium → low), then
   by Added date within the same priority.
6. Update **Updated** date whenever you edit a task, even just to add a note.
-->

---

## Planned

---

### [PLANNED] Integrate llmfit for per-model scoring in model pickers (#LLAMY-1)

- **ID**: LLAMY-1
- **Type**: feature
- **Priority**: medium
- **Effort**: medium
- **Added**: 2026-04-30
- **Updated**: 2026-04-30
- **Author**: agent

#### Problem / Motivation

The `llamy --set` and `llamy --set-default` model pickers display raw Ollama
model names with no context about how each model performs on the user's
specific hardware. A user with three models installed has no way to know from
the list alone which one is fastest, most capable, or fits comfortably in
their RAM — they have to go look it up externally.

#### Proposed Solution

Integrate [llmfit](https://github.com/AlexsJones/llmfit) as a soft optional
dependency. When present, llmfit annotates the model picker lines with
hardware-aware scores. When absent, llamy behaves exactly as it does today.

Three specific touchpoints:

1. **Annotated pickers** (`--set`, `--set-default`): when llmfit is available,
   fetch scores for each listed model and display them inline:

   ```
     1) qwen2.5-coder:latest  ✓ default   quality ●●●●○  speed ●●●○○  fit ✓
     2) llama3.1:8b                        quality ●●●○○  speed ●●●●○  fit ✓
     3) mixtral:8x7b                       quality ●●●●●  speed ●○○○○  fit ⚠ tight
   ```

2. **New `llamy --fit` command**: runs `llmfit recommend --json` scoped to
   installed Ollama models, formats the output as a readable table. Gives the
   user llmfit's full power without baking it into every flow.

3. **Optional install in `setup.fish`**: prompt user to install llmfit via
   Homebrew (`brew install llmfit`) during setup. If declined or missing at
   runtime, all scoring is silently skipped.

#### Implementation Notes

**Name mapping is the critical risk.** llmfit uses Hugging Face-style names
(`Mistral-7B`, `Qwen/Qwen3-4B`). Ollama uses its own tag format
(`mistral:latest`, `qwen2.5-coder:7b`). These don't match directly.

llmfit has a model name mapping system, but coverage is not guaranteed. Before
building the UI, test `llmfit info <model>` against your actual installed
Ollama model names and confirm the resolution rate. If fewer than ~70% of
models resolve, the feature will feel broken more than helpful.

Mitigation options:
- Use `llmfit search <partial-name>` to fuzzy-match and pick the best result.
- Strip the Ollama tag suffix (`:latest`, `:7b`) before querying.
- Fall back to showing "unscored" for unresolved models rather than hiding them.

**Score semantics.** llmfit's scores are pre-computed estimates based on model
architecture and hardware specs — not live measured tok/s. The community
benchmarks feature (`b` key in TUI) shows real-world numbers from other users,
but requires a `LOCALMAXXING_API_KEY`. Do not represent the scores as
measured performance; label them "estimated" or use a ≈ prefix.

**Latency.** Fetching scores for a list of 5–10 models adds a noticeable pause
before the picker appears. Options:
- Fetch scores async while the picker is drawn (hard in fish without subshells).
- Cache the score output per-model in `~/.config/llamy/score_cache.json` with
  a 24h TTL.
- Only fetch scores when user passes an explicit flag: `llamy --set --scores`.

**llmfit CLI output format.** Use `--json` for machine-readable output and
`--cli` for table output. The `llmfit recommend --json --limit N` command is
the most useful for the picker use case. Parse the JSON with `jq` if available,
otherwise fall back to line-by-line text parsing.

**Relevant llmfit commands:**
```
llmfit recommend --json --limit 10          # top N models for this hardware
llmfit info "Mistral-7B"                   # details for a specific model
llmfit search "llama 8b"                   # fuzzy search by name
llmfit system                              # show detected hardware
llmfit fit --perfect -n 5                  # only models that fit fully
```

**llmfit install:**
```fish
brew install llmfit      # macOS
```

Available as a Homebrew formula. Check with `command -q llmfit` before use.

**Code locations to modify in llamy.fish:**
- `_llamy_local_models` — add optional score annotation
- `_llamy_pick_model_interactive` — does not exist yet (this would be a good
  time to extract one from the duplicated picker code, mirroring lobby's
  `_lobby_pick_model_interactive`)
- `--set` handler (interactive loop, model display block)
- `--set-default` handler (model display block)
- Main start path — add `llamy --fit` as a new top-level flag

**setup.fish change:** add a new optional step after Ollama install:
```fish
header "llmfit (optional — model scoring)"
read --prompt-str "[setup] Install llmfit for hardware-aware model scoring? [Y/n]: " ans
if test "$ans" != "n" -a "$ans" != "N"
    brew install llmfit
end
```

#### Acceptance Criteria

- [ ] `llmfit` absent: llamy behavior is identical to today, no errors
- [ ] `llmfit` present: `--set` and `--set-default` pickers show inline scores
- [ ] Scores are labeled as estimated (not measured)
- [ ] `llamy --fit` command works and shows a ranked table of installed models
- [ ] Unresolved model names show "unscored" gracefully, not an error
- [ ] `setup.fish` offers optional llmfit install with a skip option
- [ ] Name mapping tested against real Ollama model names before UI is built
- [ ] Score display is skipped silently (not an error) if llmfit returns nothing

#### Dependencies

- llmfit must be installable via `brew install llmfit` (confirmed ✓)
- Test the Ollama name → llmfit name mapping before committing to the UI design
- Consider extracting `_llamy_pick_model_interactive` (mirrors lobby) as a
  prerequisite refactor — makes the annotation easier to add in one place

---

## Completed

<!-- Completed tasks are moved here. Keep them for reference. -->

*(none yet)*
