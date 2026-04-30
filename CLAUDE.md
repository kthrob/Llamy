# llamy

## Purpose

This repository provides `llamy` — a fish shell function for macOS (Apple Silicon) that launches a local AI stack with a single command. It starts an Ollama model and an [Open WebUI](https://docs.openwebui.com/) frontend together in the background, opens the UI in your browser, and keeps your terminal free.

The stack runs entirely locally. No cloud API keys, no data leaving your machine.

### What's in this repo

| File | Description |
|---|---|
| `llamy.fish` | The fish function — this is the main deliverable |
| `setup.fish` | Installer: checks/installs dependencies and drops `llamy.fish` into the right place |
| `CLAUDE.md` | This file |

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
| `~/.open-webui/` | Open WebUI data directory |
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

## Notes for Claude Code

- **Do not modify `CLAUDE.md` without also updating `setup.fish` and `llamy.fish`** if the change affects installation steps or usage.
- The function is self-contained in `llamy.fish`. All configuration paths are defined at the top of the `llamy` function body — edit there if defaults need changing.
- `setup.fish` is idempotent — safe to re-run at any time.
- Fish shell nested functions (the `_llamy_*` helpers) are defined inside the outer `llamy` function to avoid polluting the global namespace.
- Open WebUI is intentionally run via `uvx` rather than a pinned venv so updates require no manual environment management — re-warming the cache is sufficient.
