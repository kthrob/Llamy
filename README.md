```
    ██╗     ██╗      █████╗ ███╗   ███╗██╗   ██╗
    ██║     ██║     ██╔══██╗████╗ ████║╚██╗ ██╔╝
    ██║     ██║     ███████║██╔████╔██║ ╚████╔╝
    ██║     ██║     ██╔══██║██║╚██╔╝██║  ╚██╔╝
    ███████╗███████╗██║  ██║██║ ╚═╝ ██║   ██║
    ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝   ╚═╝

              |\_/|
              | @ @   one command.
              |   <>              _
              |  _/\------____ ((|))
              | ||  ||     |   \/
         _____|_||  ||_____|    |
        (______)___)_______)    |
                           local AI. no cloud. no drama.
```

---

A [fish shell](https://fishshell.com/) function for **macOS Apple Silicon** that spins up a full local AI stack — [Ollama](https://ollama.com) + [Open WebUI](https://docs.openwebui.com/) — in the background with a single command, opens the UI in your browser, and leaves your terminal free.

Everything runs on your machine. Models are fully local. The optional ElevenLabs TTS integration is the only feature that calls an external API.

---

## Install

```fish
git clone https://github.com/kthrob/Llamy.git
cd llamy
fish setup.fish
```

The setup script installs and updates all dependencies via Homebrew in order:

1. **Homebrew** — package manager
2. **Python 3** — required by Open WebUI's build steps
3. **uv** — runs Open WebUI via `uvx`, no manual venv needed
4. **Ollama** — serves local LLM models
5. **OrbStack** — container runtime
6. Copies `llamy.fish` → `~/.config/fish/functions/` and makes it executable
7. Warms the `uvx` cache so `llamy` works **offline** after the first run

Open a new terminal when it's done.

---

## Usage

```fish
llamy                    # start with your saved default model
llamy mistral            # use a specific model (pulls if not cached)
llamy llama3.1:8b        # model tags work too
llamy --set-default      # pick a default from your installed models
llamy --stop             # stop everything
llamy --logs             # tail Ollama + Open WebUI logs live
llamy --help             # show all commands
```

### Picking a default model

```
$ llamy --set-default

Available models:
  1) llama3.2:latest  ✓ current default
  2) mistral:latest
  3) llama3.1:8b

[llamy] Select a number (1-3): 2
[llamy] ✓ Default model set to: mistral:latest
```

The choice is saved to `~/.config/llamy/default_model` and used whenever you run `llamy` with no arguments.

---

## Optional: ElevenLabs Text-to-Speech

Open WebUI supports ElevenLabs for high-quality voice responses, or Kokoro for a fully local alternative. Use `--tts-set` to choose:

```fish
llamy --tts-set
# [llamy] TTS engine
#
#   1) None (text only)
#   2) Kokoro (local, built-in)
#   3) ElevenLabs (cloud, high quality)  ✓ current
#
# [llamy] Select (1-3):
```

Selecting **ElevenLabs** will prompt for your API key and voice ID, saving them to `~/.config/llamy/` (outside the repo, never committed). You can also set them manually:

```fish
echo 'sk_your_api_key' > ~/.config/llamy/elevenlabs_api_key
echo 'your_voice_id'   > ~/.config/llamy/elevenlabs_voice
# optional — defaults to eleven_multilingual_v2
echo 'eleven_turbo_v2_5' > ~/.config/llamy/elevenlabs_model
```

Get your API key from [elevenlabs.io/app/settings/api-keys](https://elevenlabs.io/app/settings/api-keys). Get voice IDs from [elevenlabs.io/voice-library](https://elevenlabs.io/voice-library).

**Restart llamy** after changing TTS:

```fish
llamy --stop && llamy
```

**3. Configure the Admin Panel** — this step is required and easy to miss.

Open WebUI has two separate audio settings pages. The TTS engine dropdown in your **user settings** only shows "Default" and "Kokoro.js" — ElevenLabs does not appear there. You must configure it in the **Admin Panel**:

> **[http://localhost:8080/admin/settings/audio](http://localhost:8080/admin/settings/audio)**

On that page: set the TTS engine to **ElevenLabs**, enter your API key, select your voice from the dropdown that appears, and save.

Once saved, go back to your user settings and leave the TTS engine on **Default** — Open WebUI will route TTS through ElevenLabs automatically.

---

## Offline use

After the first successful run, `llamy` works entirely without internet:

- **Ollama models** are stored locally after their initial `ollama pull`
- **Open WebUI** is launched with `uvx --offline`, so it loads from the local cache with no network check

To pull a newer version of Open WebUI when you're back online:

```fish
uvx --python 3.11 --with pip open-webui@latest --help
```

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS (Apple Silicon) | M1 / M2 / M3 |
| [Fish shell](https://fishshell.com/) | `llamy` is a native fish function |
| [Homebrew](https://brew.sh) | All other deps installed through it |
| [Ollama](https://ollama.com) | Installed by `setup.fish` |
| [uv](https://github.com/astral-sh/uv) | Installed by `setup.fish` |
| [OrbStack](https://orbstack.dev) | Installed by `setup.fish` |

---

## File locations

| Path | What it is |
|---|---|
| `~/.config/fish/functions/llamy.fish` | The installed function |
| `~/.config/llamy/default_model` | Your saved default model |
| `~/.config/llamy/enabled_models` | Allowlist of models llamy can use |
| `~/.config/llamy/tts_engine` | Saved TTS engine choice (`kokoro`, `elevenlabs`, `none`) |
| `~/.config/llamy/elevenlabs_api_key` | ElevenLabs API key (optional, never committed) |
| `~/.config/llamy/elevenlabs_voice` | ElevenLabs voice ID (optional) |
| `~/.config/llamy/elevenlabs_model` | ElevenLabs model name (optional) |
| `~/.open-webui/` | Open WebUI data and settings |
| `~/.local/log/llamy-ollama.log` | Ollama server log |
| `~/.local/log/llamy-webui.log` | Open WebUI log |
| `~/.local/log/llamy.pids` | PIDs of background processes |

---

## Updating

Re-run the setup script at any time — it's fully idempotent:

```fish
fish setup.fish
```

---

## Repo structure

```
llamy/
├── llamy.fish    # the fish function
├── setup.fish    # dependency installer
├── CLAUDE.md     # context for AI agents working in this repo
├── BACKLOG.md    # planned features, improvements, and bug fixes
└── README.md     # you are here
```

---

## Backlog

Planned work is tracked in [`BACKLOG.md`](./BACKLOG.md). Each entry is a self-contained task with a status, description, implementation notes, and acceptance criteria — written so an agent or a human can pick it up and execute it without needing additional context.

To see what's planned:

```fish
cat BACKLOG.md
```

To contribute a task, follow the template in `BACKLOG.md` and assign the next `LLAMY-N` ID.
