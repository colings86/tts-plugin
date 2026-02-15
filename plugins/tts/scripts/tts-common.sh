#!/bin/bash
# Claude Code TTS Common Library - holistic TTS workflow engine
# Source this file in TTS hooks with: source ${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh

# ============================================================================
# Load Configuration from .env file
# ============================================================================

# Load .env file if it exists, otherwise fall back to environment variables
TTS_ENV_FILE="$HOME/.claude/tts-plugin.env"
if [ -f "$TTS_ENV_FILE" ]; then
    # Source .env file (exports variables)
    set -a  # automatically export all variables
    source "$TTS_ENV_FILE"
    set +a  # stop auto-export
fi

# ============================================================================
# Configuration Defaults (used if not set in .env or environment)
# ============================================================================

# Master TTS enable/disable switches
: ${TTS_ENABLED:="true"}                # Global TTS enable/disable (affects all hooks)
: ${TTS_PRETOOL_ENABLED:="true"}        # PreToolUse hook enable/disable (only if TTS_ENABLED=true)

# TTS Voice Configuration
: ${TTS_VOICE:="af_bella"}              # Voice to use (run 'kokoro-tts --help-voices' to see all)
: ${TTS_LANG:="en-gb"}                  # Language (run 'kokoro-tts --help-languages' to see all)
: ${TTS_SPEED:="1.3"}                   # Speech speed (0.5-2.0)
: ${TTS_MODEL:="$HOME/.local/share/kokoro-tts/kokoro-v1.0.onnx"}
: ${TTS_VOICES:="$HOME/.local/share/kokoro-tts/voices-v1.0.bin"}

# Text Processing Configuration
: ${TTS_USE_TTS_SECTION:="true"}                                  # Extract "## TTS Response" section if present
: ${TTS_MAX_LENGTH:="5000"}                                       # Max characters to speak per message
: ${TTS_STATE_DIR:="$HOME/.local/state/claude-tts/session-state"}     # Directory for session state files
: ${TTS_LOG_DIR:="$HOME/.local/state/claude-tts/logs"}                # Directory for TTS log files

# ============================================================================
# Internal Helper Functions
# ============================================================================

# Extract "## TTS Response" section from text, or return full text if not found
_extract_tts_section() {
    local text="$1"

    if [ "$TTS_USE_TTS_SECTION" = "true" ]; then
        # Extract content after "## TTS Response" heading using awk
        local tts_section=$(awk '/^##[[:space:]]*TTS Response[[:space:]]*$/{flag=1; next} flag' <<< "$text")

        if [ -n "$tts_section" ]; then
            echo "$tts_section"
        else
            echo "$text"
        fi
    else
        echo "$text"
    fi
}

# Truncate text to max length
_truncate_text() {
    local text="$1"
    local max_length="${2:-$TTS_MAX_LENGTH}"
    echo "$text" | head -c "$max_length"
}

# Kill any existing kokoro-tts processes
_kill_tts() {
    pkill -f "kokoro-tts" 2>/dev/null
}

# Speak text using kokoro-tts (waits for completion by default)
_speak_text() {
    local text="$1"
    local log_file="$2"
    local background="${3:-false}"  # Optional: run in background

    if [ -z "$text" ]; then
        return 1
    fi

    if [ "$background" = "true" ]; then
        # Background mode: don't wait, don't kill existing
        echo "$text" | kokoro-tts - --stream \
            --voice "$TTS_VOICE" \
            --lang "$TTS_LANG" \
            --speed "$TTS_SPEED" \
            --model "$TTS_MODEL" \
            --voices "$TTS_VOICES" \
            >> "$log_file" 2>&1 &
    else
        # Foreground mode: wait for completion (default)
        echo "$text" | kokoro-tts - --stream \
            --voice "$TTS_VOICE" \
            --lang "$TTS_LANG" \
            --speed "$TTS_SPEED" \
            --model "$TTS_MODEL" \
            --voices "$TTS_VOICES" \
            >> "$log_file" 2>&1
    fi
}

# Get the last processed UUID for a session
_get_session_state() {
    local session_id="$1"
    local state_file="${TTS_STATE_DIR}/claude-tts-state-${session_id}.txt"

    # Read and strip whitespace (returns empty string if file doesn't exist)
    local last_uuid=$(cat "$state_file" 2>/dev/null | tr -d ' \t\n\r' || echo "")

    echo "$last_uuid"
}

# Update the last processed UUID for a session
_update_session_state() {
    local session_id="$1"
    local uuid="$2"
    local state_file="${TTS_STATE_DIR}/claude-tts-state-${session_id}.txt"

    # Use atomic write: write to temp file, then move
    # This ensures the file is fully written before it's visible
    local temp_file="${state_file}.tmp.$$"
    echo "$uuid" > "$temp_file"
    mv "$temp_file" "$state_file"
}

# Extract assistant messages since a given UUID
# Outputs: uuid|all_text_content_from_that_entry (one output per assistant message)
_extract_assistant_messages_since_uuid() {
    local last_uuid="$1"
    local transcript_path="$2"
    local found_last=false

    # If no last_uuid, start from beginning
    if [ -z "$last_uuid" ]; then
        found_last=true
    fi

    while IFS= read -r json_line; do
        # Get entry type and UUID
        TYPE=$(echo "$json_line" | jq -r '.type // empty' 2>/dev/null)
        ENTRY_UUID=$(echo "$json_line" | jq -r '.uuid // empty' 2>/dev/null)

        # Skip entries without UUIDs (file-history-snapshot, queue-operation)
        if [ -z "$ENTRY_UUID" ]; then
            continue
        fi

        # If we found the last processed UUID, start collecting from next entry
        if [ "$found_last" = "false" ]; then
            if [ "$ENTRY_UUID" = "$last_uuid" ]; then
                found_last=true
            fi
            continue  # Skip until we find last_uuid
        fi

        # Extract assistant messages with text content
        MSG_ROLE=$(echo "$json_line" | jq -r '.message.role // empty' 2>/dev/null)
        if [ "$TYPE" = "assistant" ] && [ "$MSG_ROLE" = "assistant" ]; then
            MESSAGE_TEXT=$(echo "$json_line" | jq -r '[.message.content[]? | select(.type == "text") | .text] | join(" ")' 2>/dev/null)
            if [ -n "$MESSAGE_TEXT" ]; then
                # Encode newlines with placeholder (|||NL|||) so output is a single line
                MESSAGE_TEXT_ENCODED=$(printf '%s' "$MESSAGE_TEXT" | sed 's/$/|||NL|||/g' | tr -d '\n' | sed 's/|||NL|||$//')
                echo "${ENTRY_UUID}|${MESSAGE_TEXT_ENCODED}"
            fi
        fi
    done < "$transcript_path"
}

# ============================================================================
# Main Public Function
# ============================================================================

# Process and speak new messages from transcript
# Usage: process_and_speak_new_messages "$transcript_path" "$session_id"
process_and_speak_new_messages() {
    local transcript_path="$1"
    local session_id="$2"

    # Generate log file name from session ID
    local log_file="${TTS_LOG_DIR}/claude-tts-${session_id}.log"

    # Ensure directories exist
    mkdir -p "$TTS_LOG_DIR" 2>/dev/null
    mkdir -p "$TTS_STATE_DIR" 2>/dev/null

    # Acquire lock to prevent concurrent processing (prevents duplicates)
    # Wait up to 60 seconds for lock instead of skipping immediately
    local lock_file="/tmp/tts-lock-${session_id}"
    exec 200>"$lock_file"
    if ! flock -w 60 200; then
        echo "Failed to acquire lock after 60s, skipping..." >> "$log_file" 2>&1
        return 0
    fi
    # Lock acquired - will auto-release when function exits

    # Validate inputs
    if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
        echo "ERROR: Invalid transcript path: $transcript_path" >> "$log_file" 2>&1
        return 1
    fi

    if [ -z "$session_id" ]; then
        echo "ERROR: No session ID provided" >> "$log_file" 2>&1
        return 1
    fi

    # Check if TTS is globally enabled
    if [ "$TTS_ENABLED" != "true" ]; then
        echo "TTS is globally disabled (TTS_ENABLED=$TTS_ENABLED)" >> "$log_file" 2>&1
        return 0
    fi

    echo "=== TTS Processing Started at $(date) ===" >> "$log_file"
    echo "Voice: $TTS_VOICE, Language: $TTS_LANG, Speed: $TTS_SPEED" >> "$log_file"
    echo "Session ID: $session_id" >> "$log_file"
    echo "Transcript: $transcript_path" >> "$log_file"

    # Get session state (last processed UUID)
    local last_uuid=$(_get_session_state "$session_id")
    if [ -n "$last_uuid" ]; then
        echo "Last processed UUID: $last_uuid" >> "$log_file"
    else
        echo "No previous UUID found, processing from beginning" >> "$log_file"
    fi

    # Extract messages with UUIDs
    echo "Extracting messages..." >> "$log_file"
    local messages_found=0

    # Process all transcript entries and pipe through ONE TTS process
    # This is much more efficient than creating a new process per entry
    # Use temp file to track last UUID since variables set in subshell don't persist
    local uuid_tracker="/tmp/tts-uuid-tracker-${session_id}-$$"
    rm -f "$uuid_tracker"
    echo "Starting single kokoro-tts process for all new messages..." >> "$log_file"

    {
        while IFS='|' read -r msg_uuid msg_text; do
            # Decode newlines from placeholder (|||NL|||) back to actual newlines
            msg_text=$(printf '%s' "$msg_text" | sed 's/|||NL|||/\n/g')

            echo "Processing entry UUID: $msg_uuid" >> "$log_file"
            echo "Raw text (first 200 chars): ${msg_text:0:200}" >> "$log_file"

            # Process: extract TTS section and truncate
            local tts_text=$(_extract_tts_section "$msg_text")
            tts_text=$(_truncate_text "$tts_text")

            if [ -z "$tts_text" ]; then
                echo "No text to speak after processing, skipping" >> "$log_file"
                echo "$msg_uuid" > "$uuid_tracker"
                continue
            fi

            echo "TTS text (first 300 chars): ${tts_text:0:300}" >> "$log_file"
            echo "TTS text length: ${#tts_text} characters" >> "$log_file"

            # Output text to the TTS pipe
            echo "$tts_text"
            # Track last processed UUID in temp file (survives subshell)
            echo "$msg_uuid" > "$uuid_tracker"
            echo "Queued UUID $msg_uuid for TTS" >> "$log_file"
        done < <(_extract_assistant_messages_since_uuid "$last_uuid" "$transcript_path")
    } | kokoro-tts - --stream \
        --voice "$TTS_VOICE" \
        --lang "$TTS_LANG" \
        --speed "$TTS_SPEED" \
        --model "$TTS_MODEL" \
        --voices "$TTS_VOICES" \
        >> "$log_file" 2>&1

    echo "TTS process completed" >> "$log_file"

    # Read last processed UUID from temp file
    local last_processed_uuid=""
    if [ -f "$uuid_tracker" ]; then
        last_processed_uuid=$(cat "$uuid_tracker")
        rm -f "$uuid_tracker"
    fi

    # Check if any messages were processed
    if [ -z "$last_processed_uuid" ]; then
        echo "No assistant messages found" >> "$log_file"
        return 0
    fi

    # Update session state to the last processed UUID after all TTS completes
    _update_session_state "$session_id" "$last_processed_uuid"
    echo "Updated session state to UUID: $last_processed_uuid" >> "$log_file"

    echo "=== TTS Processing Completed ===" >> "$log_file"
    return 0
}

# Interrupt TTS and mark all current messages as read
# Usage: interrupt_tts_and_mark_read "$transcript_path" "$session_id"
interrupt_tts_and_mark_read() {
    local transcript_path="$1"
    local session_id="$2"

    # Kill any running TTS
    _kill_tts

    # Mark all current messages as read (prevents re-speaking on next run)
    if [ -n "$session_id" ] && [ -f "$transcript_path" ]; then
        # Get the last UUID from the transcript (use tail -r for macOS, tac for Linux)
        local reverse_cmd="tail -r"
        if ! command -v tail >/dev/null 2>&1 || ! tail -r /dev/null >/dev/null 2>&1; then
            reverse_cmd="tac"
        fi
        local last_uuid=$(tail -n 20 "$transcript_path" | $reverse_cmd | while IFS= read -r json_line; do
            ENTRY_UUID=$(echo "$json_line" | jq -r '.uuid // empty' 2>/dev/null)
            if [ -n "$ENTRY_UUID" ]; then
                echo "$ENTRY_UUID"
                break
            fi
        done)

        # Update state with the last UUID found
        if [ -n "$last_uuid" ]; then
            _update_session_state "$session_id" "$last_uuid"
        fi
    fi
}

# Clean up session state and optionally log file
# Usage: cleanup_session "$session_id"
cleanup_session() {
    local session_id="$1"

    if [ -z "$session_id" ]; then
        return 1
    fi

    local state_file="${TTS_STATE_DIR}/claude-tts-state-${session_id}.txt"
    local log_file="${TTS_LOG_DIR}/claude-tts-${session_id}.log"

    # Remove state file
    if [ -f "$state_file" ]; then
        rm -f "$state_file"
        echo "Cleaned up TTS state file for session $session_id" >> "$log_file" 2>&1
    fi

    # Optionally remove log file (commented out by default to preserve logs)
    # if [ -f "$log_file" ]; then
    #     rm -f "$log_file"
    # fi
}

# # ============================================================================
# # Backward Compatibility Functions (deprecated, use process_and_speak_new_messages)
# # ============================================================================

# extract_tts_section() { _extract_tts_section "$@"; }
# truncate_text() { _truncate_text "$@"; }
# kill_tts() { _kill_tts "$@"; }
# speak_text() { _speak_text "$@"; }
# get_session_state() { _get_session_state "$@"; }
# update_session_state() { _update_session_state "$@"; }
# process_text_for_tts() {
#     local text="$1"
#     text=$(_extract_tts_section "$text")
#     text=$(_truncate_text "$text")
#     echo "$text"
# }
