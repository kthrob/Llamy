# ~/.config/fish/functions/llamy.fish
#
# Usage:
#   llamy                        # start with saved default model
#   llamy mistral                # pull & use a specific model
#   llamy llama3.1:8b            # model tags work too
#   llamy --set-default          # pick a default from locally installed models
#   llamy --stop                 # stop Ollama + Open WebUI
#   llamy --logs                 # tail both logs

function llamy --description "Start Ollama + Open WebUI in the background"

    set CONFIG_DIR    "$HOME/.config/llamy"
    set DEFAULT_FILE  "$CONFIG_DIR/default_model"
    set BUILTIN_DEFAULT "llama3.2"
    set LOG_DIR       "$HOME/.local/log"
    set OLLAMA_LOG    "$LOG_DIR/llamy-ollama.log"
    set WEBUI_LOG     "$LOG_DIR/llamy-webui.log"
    set PID_FILE      "$LOG_DIR/llamy.pids"
    set WEBUI_URL     "http://localhost:8080"

    # ── helpers ────────────────────────────────────────────────────────────

    function _llamy_info
        echo (set_color cyan)"[llamy]"(set_color normal) $argv
    end
    function _llamy_ok
        echo (set_color green)"[llamy]"(set_color normal) $argv
    end
    function _llamy_err
        echo (set_color red)"[llamy]"(set_color normal) $argv >&2
    end

    function _llamy_saved_default
        if test -f $DEFAULT_FILE
            cat $DEFAULT_FILE
        else
            echo $BUILTIN_DEFAULT
        end
    end

    # ── --help ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--help" -o "$argv[1]" = "-h"
        set current (_llamy_saved_default)
        echo ""
        echo (set_color --bold)"llamy"(set_color normal)" — Ollama + Open WebUI launcher"
        echo ""
        echo (set_color --bold)"USAGE"(set_color normal)
        echo "  llamy [model]          Start Ollama and Open WebUI"
        echo "                         Omit [model] to use the saved default"
        echo ""
        echo (set_color --bold)"OPTIONS"(set_color normal)
        printf "  %-22s %s\n" "--set-default" "Interactively pick the default model from locally installed ones"
        printf "  %-22s %s\n" "--stop"        "Stop Ollama and Open WebUI background processes"
        printf "  %-22s %s\n" "--logs"        "Tail the Ollama and Open WebUI log files (Ctrl-C to exit)"
        printf "  %-22s %s\n" "--help, -h"    "Show this help message"
        echo ""
        echo (set_color --bold)"EXAMPLES"(set_color normal)
        echo "  llamy                  # start with default model ($current)"
        echo "  llamy mistral          # start with mistral (pulls if not cached)"
        echo "  llamy llama3.1:8b      # model tags are supported"
        echo "  llamy --set-default    # choose a new default from installed models"
        echo "  llamy --stop           # shut everything down"
        echo "  llamy --logs           # watch logs in real time"
        echo ""
        echo (set_color --bold)"FILES"(set_color normal)
        printf "  %-38s %s\n" "$DEFAULT_FILE" "Saved default model"
        printf "  %-38s %s\n" "$OLLAMA_LOG"   "Ollama server log"
        printf "  %-38s %s\n" "$WEBUI_LOG"    "Open WebUI log"
        printf "  %-38s %s\n" "$PID_FILE"     "PIDs of background processes"
        echo ""
        echo (set_color --bold)"NOTES"(set_color normal)
        echo "  Open WebUI is launched with --offline so it works without internet"
        echo "  once the uvx cache is warm (i.e. after the first successful run)."
        echo "  Ollama models are fully local after their initial pull."
        echo ""
        return 0
    end

    # ── --set-default ──────────────────────────────────────────────────────

    if test "$argv[1]" = "--set-default"
        # Ensure ollama is running so `ollama list` works
        set _started_ollama 0
        if not pgrep -x ollama > /dev/null
            _llamy_info "Starting Ollama server briefly to list models..."
            ollama serve > /dev/null 2>&1 &
            set _tmp_ollama_pid $last_pid
            set _started_ollama 1
            sleep 2
        end

        # Grab model names (skip the header line)
        set models (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

        # Kill the temporary server if we started it
        if test $_started_ollama -eq 1
            kill $_tmp_ollama_pid 2>/dev/null
        end

        if test (count $models) -eq 0
            _llamy_err "No models found. Pull one first with: ollama pull <model>"
            return 1
        end

        # Print numbered list
        echo ""
        echo (set_color --bold)"Available models:"(set_color normal)
        set current (_llamy_saved_default)
        for i in (seq (count $models))
            if test "$models[$i]" = "$current"
                echo (set_color yellow)"  $i) $models[$i]  ✓ current default"(set_color normal)
            else
                echo "  $i) $models[$i]"
            end
        end
        echo ""

        # Prompt for selection
        while true
            read --prompt-str (set_color cyan)"[llamy]"(set_color normal)" Select a number (1-"(count $models)"): " choice
            if string match -qr '^\d+$' -- $choice
                and test $choice -ge 1
                and test $choice -le (count $models)
                break
            end
            _llamy_err "Please enter a number between 1 and "(count $models)"."
        end

        set selected $models[$choice]
        mkdir -p $CONFIG_DIR
        echo $selected > $DEFAULT_FILE
        _llamy_ok "Default model set to: $selected"
        return 0
    end

    # ── --stop ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--stop"
        if not test -f $PID_FILE
            _llamy_err "No PID file at $PID_FILE — nothing to stop."
            return 1
        end
        for pid in (cat $PID_FILE)
            if kill -0 $pid 2>/dev/null
                kill $pid
                _llamy_ok "Stopped PID $pid"
            end
        end
        rm -f $PID_FILE
        return 0
    end

    # ── --logs ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--logs"
        tail -f $OLLAMA_LOG $WEBUI_LOG
        return 0
    end

    # ── start ──────────────────────────────────────────────────────────────

    # Use passed model, or fall back to saved/builtin default
    if test (count $argv) -gt 0
        set MODEL $argv[1]
    else
        set MODEL (_llamy_saved_default)
        _llamy_info "Using default model: $MODEL"
    end

    mkdir -p $LOG_DIR

    # 1. Start ollama serve if not already up
    if not pgrep -x ollama > /dev/null
        _llamy_info "Starting Ollama server..."
        ollama serve >> $OLLAMA_LOG 2>&1 &
        set ollama_pid $last_pid
        sleep 2
    else
        _llamy_info "Ollama already running."
        set ollama_pid ""
    end

    # 2. Pull the model (idempotent)
    _llamy_info "Pulling model '$MODEL' (skipped if already cached)..."
    ollama pull $MODEL

    # 3. Launch Open WebUI via uvx
    #    --with pip works around the "No module named pip" bug in uv-isolated envs
    _llamy_info "Starting Open WebUI (logs → $WEBUI_LOG)..."
    DATA_DIR=$HOME/.open-webui \
    OLLAMA_BASE_URL=http://localhost:11434 \
        uvx --python 3.11 --with pip --offline open-webui@latest serve \
        >> $WEBUI_LOG 2>&1 &
    set webui_pid $last_pid

    # 4. Persist PIDs for --stop
    printf "%s\n" $ollama_pid $webui_pid | grep -v '^$' > $PID_FILE

    # 5. Wait for the UI to respond, then open it
    _llamy_info "Waiting for Open WebUI to come up..."
    set attempts 0
    while test $attempts -lt 20
        if curl -sf $WEBUI_URL > /dev/null 2>&1
            break
        end
        sleep 2
        set attempts (math $attempts + 1)
    end

    if curl -sf $WEBUI_URL > /dev/null 2>&1
        _llamy_ok "Open WebUI is up → $WEBUI_URL"
        open $WEBUI_URL
    else
        _llamy_err "Open WebUI didn't respond after 40 s — check: $WEBUI_LOG"
    end

    _llamy_ok "Running in the background."
    _llamy_info "  Model:          $MODEL"
    _llamy_info "  Logs:           llamy --logs"
    _llamy_info "  Stop:           llamy --stop"
    _llamy_info "  Change default: llamy --set-default"

end
