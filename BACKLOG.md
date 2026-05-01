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

### [PLANNED] Docker/OrbStack variant of Open WebUI launcher (#LLAMY-2)

- **ID**: LLAMY-2
- **Type**: feature
- **Priority**: low
- **Effort**: medium
- **Added**: 2026-04-30
- **Updated**: 2026-04-30
- **Author**: agent

#### Problem / Motivation

The current stack runs Open WebUI via `uvx open-webui@latest`. This works but has practical friction:

- The cached version is frozen until manually re-warmed (`uvx --python 3.11 --with pip open-webui@latest --help`)
- Environment variables must be threaded through fish list expansion into `env`, which is fragile
- No standard `.env` file support — config needs the bespoke `~/.config/llamy/` file approach
- `--offline` makes the package manager offline, not the app — the distinction confuses troubleshooting
- There is no pinned version; `@latest` can silently break between runs

Open WebUI's official deployment target is Docker. OrbStack is already installed by `setup.fish`. A Docker-based variant would eliminate most of the above friction.

#### Proposed Solution

**Research first, implement second.** Before writing any code, evaluate the Docker approach against the current uvx approach across the dimensions below. If the tradeoffs favour Docker, implement `llamy-docker.fish` as a parallel variant that can be tested side-by-side with the existing `llamy.fish`. Do not replace `llamy.fish` until the Docker variant is validated.

The Docker variant would:
- Pull `ghcr.io/open-webui/open-webui:main` (or a pinned tag)
- Run the container via OrbStack's `docker` CLI
- Mount `~/.open-webui` as the data volume (same path as today — DB and uploads are preserved)
- Pass config via a `~/.config/llamy/.env` file (natively supported by `docker run --env-file`)
- Connect to the host Ollama instance via `host.docker.internal:11434` or OrbStack's host networking

#### Research Questions (answer before implementing)

These must be answered by reading OrbStack and Open WebUI documentation, and by running small experiments, before writing `llamy-docker.fish`:

1. **Cold start time.** How long does `docker run ghcr.io/open-webui/open-webui` take to be ready vs the current uvx path? Is the difference noticeable in practice?

2. **Image size.** The Open WebUI Docker image is ~2 GB. Is this a one-time cost or does it balloon on updates? How does OrbStack manage image storage on macOS?

3. **Ollama connectivity.** OrbStack containers can reach the host via `host.docker.internal`. Does Open WebUI's `OLLAMA_BASE_URL=http://host.docker.internal:11434` work reliably, or does OrbStack's networking require a different approach?

4. **Data persistence.** Confirm that mounting `~/.open-webui:/app/backend/data` preserves the existing sqlite DB, uploaded files, and vector DB — so switching from uvx to Docker doesn't lose any settings or chat history.

5. **`.env` file handling.** Does `docker run --env-file ~/.config/llamy/.env` handle TTS env vars correctly? Confirm the key names (`AUDIO_TTS_ENGINE`, `AUDIO_TTS_MODEL`, etc.) are the same in the Docker image as in the uvx-run version.

6. **Pinned vs latest.** Should the variant track `:main` (rolling), `:latest` (stable releases), or a pinned tag? What is the update workflow for each?

7. **OrbStack-specific behaviour.** Does OrbStack expose a `docker` binary that works identically to Docker Desktop's CLI? Are there any OrbStack-specific flags or config needed? Does `orb` CLI offer anything useful here (e.g., `orb run`)?

8. **GPU/Metal acceleration.** The uvx approach runs natively on macOS and can use Metal. Does the Docker container get any GPU access through OrbStack, or does it run CPU-only? What is the performance difference for inference if Ollama is the backend (it runs on the host regardless)?

9. **Stop/restart behaviour.** How does `docker stop` compare to `kill $pid` in terms of graceful shutdown? Does Open WebUI need a graceful stop to flush its DB?

10. **Coexistence.** Can both `llamy` (uvx) and `llamy-docker` run concurrently for comparison, or do they conflict on port 8080 / the data directory?

#### Implementation Notes (for after research is complete)

- Implement as `llamy-docker.fish`, installed alongside `llamy.fish` — not as a replacement
- Use the same `~/.config/llamy/` config directory and the same `~/.open-webui/` data directory
- Use `~/.config/llamy/.env` for all env vars passed to the container (already gitignored via `.env.*` in `.gitignore`)
- Keep `llamy-docker` command surface identical to `llamy` where possible (`--stop`, `--logs`, `--help`) so it can be compared without re-learning
- The `--logs` command should tail the container log: `docker logs -f open-webui`
- `--stop` should run `docker stop open-webui && docker rm open-webui`
- Update `setup.fish` to optionally install the Docker variant alongside the uvx one
- Update README with a side-by-side comparison table once both variants exist

#### Acceptance Criteria

- [ ] All research questions above answered and documented in this task before any code is written
- [ ] `llamy-docker.fish` installed and working alongside `llamy.fish` without conflicts
- [ ] `~/.open-webui/` data (DB, uploads) is preserved when switching between variants
- [ ] `llamy-docker --stop/--logs/--help` work correctly
- [ ] Cold start time and image size documented in the task for future reference
- [ ] README updated with comparison table and Docker setup instructions

#### Dependencies

- OrbStack must be installed (already ensured by `setup.fish`)
- Research questions must be answered before implementation begins
- Consider doing this after LLAMY-1 (llmfit) to avoid two large parallel work streams

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

### [DONE] Remove ElevenLabs TTS implementation (#LLAMY-3)

- **ID**: LLAMY-3
- **Type**: refactor
- **Priority**: high
- **Effort**: small
- **Added**: 2026-04-30
- **Updated**: 2026-04-30
- **Author**: agent

#### Problem / Motivation

ElevenLabs is a cloud TTS service that conflicts with the project's fully-local, offline-first goal. The voice ID mismatch error (ElevenLabs voice ID passed to Kokoro) is a symptom of unnecessary complexity. The user wants to keep everything local with Kokoro only.

#### Acceptance Criteria

- [x] `llamy --tts-set` shows only `none` and `kokoro` (no ElevenLabs option)
- [x] No ElevenLabs env vars are set at startup
- [x] `--help` and all docs contain no ElevenLabs references
- [x] Open WebUI DB has no ElevenLabs credentials or engine config
- [x] `llamy` starts cleanly with Kokoro
