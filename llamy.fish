# ~/.config/fish/functions/llamy.fish
#
# Usage:
#   llamy                        # start with saved default model
#   llamy mistral                # pull & use a specific model
#   llamy llama3.1:8b            # model tags work too
#   llamy --set                  # toggle which models are enabled for llamy
#   llamy --list                 # list models currently enabled for llamy
#   llamy --set-default          # pick a default from locally installed models
#   llamy --stop                 # stop Ollama + Open WebUI
#   llamy --logs                 # tail both logs

function llamy --description "Start Ollama + Open WebUI in the background"

    set CONFIG_DIR      "$HOME/.config/llamy"
    set DEFAULT_FILE    "$CONFIG_DIR/default_model"
    set ENABLED_FILE    "$CONFIG_DIR/enabled_models"
    set BUILTIN_DEFAULT "llama3.2"
    set LOG_DIR         "$HOME/.local/log"
    set OLLAMA_LOG      "$LOG_DIR/llamy-ollama.log"
    set WEBUI_LOG       "$LOG_DIR/llamy-webui.log"
    set PID_FILE        "$LOG_DIR/llamy.pids"
    set WEBUI_URL       "http://localhost:8080"

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
    function _llamy_warn
        echo (set_color yellow)"[llamy]"(set_color normal) $argv
    end

    function _llamy_saved_default --argument-names default_file builtin_default
        if test -n "$default_file"; and test -f "$default_file"
            set saved_model (string trim -- (cat "$default_file" 2>/dev/null))
            if test -n "$saved_model"
                echo $saved_model
            else
                echo $builtin_default
            end
        else
            echo $builtin_default
        end
    end

    function _llamy_enabled_models --argument-names enabled_file
        if test -f "$enabled_file"
            for model in (cat "$enabled_file" 2>/dev/null | string trim | string match -rv '^$')
                echo $model
            end
        end
    end

    function _llamy_local_models
        set _started_ollama 0
        if not pgrep -x ollama > /dev/null
            _llamy_info "Starting Ollama server briefly to list models..."
            ollama serve > /dev/null 2>&1 &
            set _tmp_ollama_pid $last_pid
            set _started_ollama 1
            sleep 2
        end

        set models (ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

        if test $_started_ollama -eq 1
            kill $_tmp_ollama_pid 2>/dev/null
        end

        for model in $models
            echo $model
        end
    end

    function _llamy_pull_model --argument-names model_name
        set _started_ollama 0
        if not pgrep -x ollama > /dev/null
            _llamy_info "Starting Ollama server briefly to pull '$model_name'..."
            ollama serve > /dev/null 2>&1 &
            set _tmp_ollama_pid $last_pid
            set _started_ollama 1
            sleep 2
        end

        ollama pull $model_name
        set pull_status $status

        if test $_started_ollama -eq 1
            kill $_tmp_ollama_pid 2>/dev/null
        end

        return $pull_status
    end

    # ── --help ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--help" -o "$argv[1]" = "-h"
        set current (_llamy_saved_default $DEFAULT_FILE $BUILTIN_DEFAULT)
        echo ""
        echo (set_color --bold)"llamy"(set_color normal)" — Ollama + Open WebUI launcher"
        echo ""
        echo (set_color --bold)"USAGE"(set_color normal)
        echo "  llamy [model]          Start Ollama and Open WebUI"
        echo "                         Omit [model] to use the saved default"
        echo ""
        echo (set_color --bold)"OPTIONS"(set_color normal)
        printf "  %-22s %s\n" "--set"         "Interactively toggle which local models are enabled for llamy"
        printf "  %-22s %s\n" "--list"        "Show currently enabled models"
        printf "  %-22s %s\n" "--set-default" "Interactively pick the default model"
        printf "  %-22s %s\n" "--stop"        "Stop Ollama and Open WebUI background processes"
        printf "  %-22s %s\n" "--logs"        "Tail the Ollama and Open WebUI log files (Ctrl-C to exit)"
        printf "  %-22s %s\n" "--help, -h"    "Show this help message"
        echo ""
        echo (set_color --bold)"EXAMPLES"(set_color normal)
        echo "  llamy                  # start with default model ($current)"
        echo "  llamy mistral          # start with mistral (pulls if not cached)"
        echo "  llamy --set            # choose which models llamy is allowed to use"
        echo "  llamy --list           # list currently enabled models"
        echo "  llamy --set-default    # choose a new default"
        echo "  llamy --stop           # shut everything down"
        echo "  llamy --logs           # watch logs in real time"
        echo ""
        echo (set_color --bold)"FILES"(set_color normal)
        printf "  %-38s %s\n" "$DEFAULT_FILE" "Saved default model"
        printf "  %-38s %s\n" "$ENABLED_FILE" "Enabled model allowlist"
        printf "  %-38s %s\n" "$OLLAMA_LOG"   "Ollama server log"
        printf "  %-38s %s\n" "$WEBUI_LOG"    "Open WebUI log"
        printf "  %-38s %s\n" "$PID_FILE"     "PIDs of background processes"
        echo ""
        echo (set_color --bold)"NOTES"(set_color normal)
        echo "  If '$ENABLED_FILE' exists, only listed models can be launched with llamy."
        echo "  Open WebUI is launched with --offline so it works without internet"
        echo "  once the uvx cache is warm (i.e. after the first successful run)."
        echo "  Ollama models are fully local after their initial pull."
        echo ""
        return 0
    end

    # ── --list ─────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--list"
        set current (_llamy_saved_default $DEFAULT_FILE $BUILTIN_DEFAULT)

        if not test -f "$ENABLED_FILE"
            _llamy_info "No explicit enabled list set. All installed models are allowed."
            return 0
        end

        set enabled_models (_llamy_enabled_models $ENABLED_FILE)
        if test (count $enabled_models) -eq 0
            _llamy_warn "No models are currently enabled."
            return 0
        end

        echo ""
        echo (set_color --bold)"Enabled models for llamy:"(set_color normal)
        for model in $enabled_models
            if test "$model" = "$current"
                echo (set_color yellow)"  • $model  ✓ current default"(set_color normal)
            else
                echo "  • $model"
            end
        end
        echo ""
        return 0
    end

    # ── --set ──────────────────────────────────────────────────────────────

    if test "$argv[1]" = "--set"
        mkdir -p $CONFIG_DIR

        set models (_llamy_local_models)
        if test -f "$ENABLED_FILE"
            set enabled_models (_llamy_enabled_models $ENABLED_FILE)
        else
            set enabled_models $models
        end

        while true
            set current (_llamy_saved_default $DEFAULT_FILE $BUILTIN_DEFAULT)

            echo ""
            echo (set_color --bold)"llamy model selector"(set_color normal)
            if test (count $models) -eq 0
                _llamy_warn "No local models found yet. Use 'pull <model>' to add one."
            else
                for i in (seq (count $models))
                    set model $models[$i]
                    set marker " "
                    if contains -- $model $enabled_models
                        set marker "x"
                    end

                    if test "$model" = "$current"
                        echo (set_color yellow)"  $i) [$marker] $model  ✓ current default"(set_color normal)
                    else
                        echo "  $i) [$marker] $model"
                    end
                end
            end

            echo ""
            echo "  number      toggle model"
            echo "  pull <name> pull model from Ollama and enable it"
            echo "  all         enable all listed models"
            echo "  none        disable all listed models"
            echo "  save        save and exit"
            echo "  q           cancel"

            read --prompt-str (set_color cyan)"[llamy]"(set_color normal)" set> " choice
            set choice (string trim -- "$choice")
            if test -z "$choice"
                continue
            end

            if string match -qri '^(q|quit)$' -- $choice
                _llamy_info "No changes saved."
                return 0
            else if string match -qri '^(save|s)$' -- $choice
                set normalized_enabled
                for model in $models
                    if contains -- $model $enabled_models
                        set -a normalized_enabled $model
                    end
                end
                set enabled_models $normalized_enabled

                if test (count $enabled_models) -gt 0
                    printf "%s\n" $enabled_models > $ENABLED_FILE
                else
                    cat /dev/null > $ENABLED_FILE
                end

                _llamy_ok "Saved "(count $enabled_models)" enabled model(s)."
                return 0
            else if string match -qri '^(all|a)$' -- $choice
                set enabled_models $models
                _llamy_ok "Enabled all listed models."
            else if string match -qri '^(none|n)$' -- $choice
                set enabled_models
                _llamy_ok "Disabled all listed models."
            else if string match -qri '^pull\s+\S+$' -- $choice
                set model_to_pull (string replace -r '^[Pp][Uu][Ll][Ll]\s+' '' -- $choice)
                _llamy_info "Pulling model '$model_to_pull'..."
                if _llamy_pull_model $model_to_pull
                    set models (_llamy_local_models)
                    if not contains -- $model_to_pull $enabled_models
                        set -a enabled_models $model_to_pull
                    end

                    set normalized_enabled
                    for model in $models
                        if contains -- $model $enabled_models
                            set -a normalized_enabled $model
                        end
                    end
                    set enabled_models $normalized_enabled

                    _llamy_ok "Pulled and enabled: $model_to_pull"
                else
                    _llamy_err "Failed to pull model: $model_to_pull"
                end
            else if string match -qr '^\d+$' -- $choice
                if test (count $models) -eq 0
                    _llamy_err "No models to toggle yet. Use: pull <model>"
                    continue
                end

                if test $choice -ge 1; and test $choice -le (count $models)
                    set selected $models[$choice]
                    if contains -- $selected $enabled_models
                        set idx (contains -i -- $selected $enabled_models)
                        set -e enabled_models[$idx]
                        _llamy_info "Disabled: $selected"
                    else
                        set -a enabled_models $selected
                        _llamy_info "Enabled: $selected"
                    end
                else
                    _llamy_err "Please enter a number between 1 and "(count $models)"."
                end
            else
                _llamy_err "Unknown input. Use a number, pull <name>, all, none, save, or q."
            end
        end
    end

    # ── --set-default ──────────────────────────────────────────────────────

    if test "$argv[1]" = "--set-default"
        set models (_llamy_local_models)
        set enabled_file_exists 0

        if test -f "$ENABLED_FILE"
            set enabled_file_exists 1
            set enabled_models (_llamy_enabled_models $ENABLED_FILE)

            if test (count $enabled_models) -eq 0
                _llamy_err "No models are enabled for llamy. Run: llamy --set"
                return 1
            end

            set filtered_models
            for model in $models
                if contains -- $model $enabled_models
                    set -a filtered_models $model
                end
            end
            set models $filtered_models
        end

        if test (count $models) -eq 0
            if test $enabled_file_exists -eq 1
                _llamy_err "No enabled models are installed. Run: llamy --set (and use pull <model> if needed)."
            else
                _llamy_err "No models found. Pull one first with: ollama pull <model>"
            end
            return 1
        end

        # Print numbered list
        echo ""
        echo (set_color --bold)"Available models:"(set_color normal)
        set current (_llamy_saved_default $DEFAULT_FILE $BUILTIN_DEFAULT)
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

    set enabled_file_exists 0
    set enabled_models
    if test -f "$ENABLED_FILE"
        set enabled_file_exists 1
        set enabled_models (_llamy_enabled_models $ENABLED_FILE)
    end

    # Use passed model, or fall back to saved/builtin default
    if test (count $argv) -gt 0
        set MODEL $argv[1]

        if test $enabled_file_exists -eq 1
            if test (count $enabled_models) -eq 0
                _llamy_err "No models are enabled. Run: llamy --set"
                return 1
            end

            if not contains -- $MODEL $enabled_models
                _llamy_err "Model '$MODEL' is not enabled for llamy. Run: llamy --set"
                return 1
            end
        end
    else
        set MODEL (_llamy_saved_default $DEFAULT_FILE $BUILTIN_DEFAULT)

        if test $enabled_file_exists -eq 1
            if test (count $enabled_models) -eq 0
                _llamy_err "No models are enabled. Run: llamy --set"
                return 1
            end

            if not contains -- $MODEL $enabled_models
                set MODEL $enabled_models[1]
                _llamy_warn "Saved default is not enabled; using first enabled model: $MODEL"
            else
                _llamy_info "Using default model: $MODEL"
            end
        else
            _llamy_info "Using default model: $MODEL"
        end
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
    _llamy_info "  Enabled models: llamy --list"
    _llamy_info "  Logs:           llamy --logs"
    _llamy_info "  Stop:           llamy --stop"
    _llamy_info "  Change default: llamy --set-default"

end