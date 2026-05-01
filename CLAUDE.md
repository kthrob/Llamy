# llamy

## Purpose

This repository provides `llamy` — a fish shell function for macOS (Apple Silicon) that launches a local AI stack with a single command. It starts an Ollama model and an [Open WebUI](https://docs.openwebui.com/) frontend together in the background, opens the UI in your browser, and keeps your terminal free.

The stack runs entirely locally. No cloud API keys, no data leaving your machine.

### What's in this repo

| File | Description |
|---|---|
| `llamy.fish` | The fish function — this is the main deliverable |
| `setup.fish` | Installer: checks/installs dependencies and drops `llamy.fish` into the right place |
| `CLAUDE.md` | This file — context for agents |
| `README.md` | Human-facing documentation |
| `BACKLOG.md` | Planned features, improvements, and bug fixes (see below) |

---

## Requirements

All dependencies are managed via Homebrew. The setup script handles installation and upgrades automatically.

- **macOS on Apple Silicon (M1/M2/M3)**
- **[Homebrew](https://brew.sh)**
- **Python 3** (system python3, used by open-webui build steps)
- **[uv](https://github.com/astral-sh/uv)** — runs Open WebUI via `uvx` without a manual venv
- **[Ollama](https://ollama.com)** — serves local LLM models
- **[OrbStack](https://orbstack.dev)** — Docker/Linux container runtime (used alongside, not required by llamy itself)
- **Fish shell** — `llamy` is a native fish function

---

## Installation

Run the setup script from the repository root:

```fish
fish setup.fish
```

The script will, in order:

1. Install or update **Homebrew**
2. Install or update **Python 3**
3. Install or update **uv**
4. Install or update **Ollama**
5. Install or update **OrbStack** (Homebrew Cask)
6. Copy `llamy.fish` → `~/.config/fish/functions/llamy.fish` and `chmod +x` it
7. Warm the `uvx` cache so `llamy` works offline after first run

Then open a new terminal and verify:

```fish
llamy --help
```

---

## Usage

```fish
llamy                    # start with your saved default model
llamy mistral            # start with a specific model (pulls if not cached)
llamy llama3.1:8b        # model tags are supported
llamy --set-default      # interactively pick a default from installed models
llamy --stop             # stop Ollama + Open WebUI
llamy --logs             # tail both log files (Ctrl-C to exit)
llamy --help             # show all commands
```

On first run, Ollama will pull the model from the internet. After that, everything works offline — `llamy` uses `uvx --offline` so Open WebUI launches from the local cache without any network check.

---

## File locations

| Path | Purpose |
|---|---|
| `~/.config/fish/functions/llamy.fish` | The installed function |
| `~/.config/llamy/default_model` | Persisted default model name |
| `~/.config/llamy/enabled_models` | Allowlist of models llamy can use |
| `~/.config/llamy/tts_engine` | Persisted TTS engine choice: `kokoro` or `none` |
| `~/.open-webui/` | Open WebUI data directory |
| `~/.open-webui/webui.db` | SQLite DB storing Open WebUI settings |
| `~/.local/log/llamy-ollama.log` | Ollama server log |
| `~/.local/log/llamy-webui.log` | Open WebUI log |
| `~/.local/log/llamy.pids` | PIDs of background processes |

---

## Updating

To update dependencies and reinstall the function, just re-run the setup script:

```fish
fish setup.fish
```

To update Open WebUI itself, run it once without `--offline` to pull the latest version into the uvx cache:

```fish
uvx --python 3.11 --with pip open-webui@latest --help
```

---

## Notes for agents

- **Do not modify `CLAUDE.md` without also updating `setup.fish` and `llamy.fish`** if the change affects installation steps or usage.
- The function is self-contained in `llamy.fish`. All configuration paths are defined at the top of the `llamy` function body — edit there if defaults need changing.
- `setup.fish` is idempotent — safe to re-run at any time.
- Fish shell nested functions (the `_llamy_*` helpers) are defined inside the outer `llamy` function to avoid polluting the global namespace.
- Open WebUI is intentionally run via `uvx` rather than a pinned venv so updates require no manual environment management — re-warming the cache is sufficient.

---

## Backlog

Planned work lives in [`BACKLOG.md`](./BACKLOG.md). It is the authoritative source for what needs doing in this repo — bugs, features, and improvements.

### How the backlog works

Each task in `BACKLOG.md` has a status, a unique ID (`LLAMY-N`), metadata, a full description, implementation notes, and acceptance criteria. The format is designed so an agent can open the file, pick up a task, implement it, and mark it done — without needing additional context from a human.

### Agent workflow for backlog tasks

1. **Read `BACKLOG.md` first.** Before starting any work session, scan for `[PLANNED]` or `[IN PROGRESS]` tasks relevant to the work being requested.
2. **Claim the task.** Change its status from `[PLANNED]` to `[IN PROGRESS]` and update the `Updated` date before touching any code.
3. **Follow the implementation notes.** Each task includes specific file locations, known edge cases, and decisions already made — use them.
4. **Mark done and move.** When complete, change status to `[DONE]` and move the task block to the `## Completed` section at the bottom of `BACKLOG.md`.
5. **Add new tasks as discovered.** If work reveals a new bug or improvement, add it to `BACKLOG.md` with the next sequential ID rather than silently fixing or ignoring it.

### Adding a task

Use this minimal template and append it to the `## Planned` section, maintaining priority order (high → medium → low):

```markdown
### [PLANNED] Short imperative title (#LLAMY-N)

- **ID**: LLAMY-N
- **Type**: bug | feature | improvement | refactor
- **Priority**: high | medium | low
- **Effort**: small | medium | large
- **Added**: YYYY-MM-DD
- **Updated**: YYYY-MM-DD
- **Author**: name or "agent"

#### Problem / Motivation
...

#### Proposed Solution
...

#### Implementation Notes
...

#### Acceptance Criteria
- [ ] ...
```
