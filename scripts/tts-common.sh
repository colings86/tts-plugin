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

# Get the last processed line number for a session
_get_session_state() {
    local session_id="$1"
    local state_file="${TTS_STATE_DIR}/claude-tts-state-${session_id}.txt"

    # Read and strip all whitespace (wc -l adds leading spaces)
    local last_line=$(cat "$state_file" 2>/dev/null | tr -d ' \t\n\r' || echo "0")

    # Validate it's a number
    if ! [[ "$last_line" =~ ^[0-9]+$ ]]; then
        last_line=0
    fi

    echo "$last_line"
}

# Update the last processed line number for a session
_update_session_state() {
    local session_id="$1"
    local line_number="$2"
    local state_file="${TTS_STATE_DIR}/claude-tts-state-${session_id}.txt"

    echo "$line_number" > "$state_file"
}

# Extract assistant transcript lines with their line numbers
# Each line in the transcript is processed as a complete unit
# Outputs: line_number|all_text_content_from_that_line (one output per transcript line)
_extract_assistant_messages_with_lines() {
    local start_line="$1"
    local transcript_path="$2"

    local current_line=$start_line
    tail -n +$((start_line + 1)) "$transcript_path" | while IFS= read -r json_line; do
        current_line=$((current_line + 1))

        TYPE=$(echo "$json_line" | jq -r '.type // empty' 2>/dev/null)
        MSG_ROLE=$(echo "$json_line" | jq -r '.message.role // empty' 2>/dev/null)

        if [ "$TYPE" = "assistant" ] && [ "$MSG_ROLE" = "assistant" ]; then
            # Extract ALL text content from this line and combine into one string
            MESSAGE_TEXT=$(echo "$json_line" | jq -r '[.message.content[]? | select(.type == "text") | .text] | join(" ")' 2>/dev/null)
            if [ -n "$MESSAGE_TEXT" ]; then
                echo "${current_line}|${MESSAGE_TEXT}"
            fi
        fi
    done
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
    local lock_file="/tmp/tts-lock-${session_id}"
    exec 200>"$lock_file"
    if ! flock -n 200; then
        echo "Another TTS instance is running, skipping..." >> "$log_file" 2>&1
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

    # Get session state (last processed line)
    local last_line=$(_get_session_state "$session_id")
    echo "Last processed line: $last_line" >> "$log_file"

    # Get total lines in transcript
    local total_lines=$(wc -l < "$transcript_path")
    echo "Total transcript lines: $total_lines" >> "$log_file"

    # Check if there are new lines
    if [ "$total_lines" -le "$last_line" ]; then
        echo "No new messages to process" >> "$log_file"
        return 0
    fi

    # Extract messages with line numbers
    echo "Extracting messages..." >> "$log_file"
    local messages_found=0

    # Process all transcript lines and pipe through ONE TTS process
    # This is much more efficient than creating a new process per line
    local last_processed_line=$last_line
    echo "Starting single kokoro-tts process for all new messages..." >> "$log_file"

    {
        while IFS='|' read -r msg_line msg_text; do
            messages_found=1
            echo "Processing transcript line $msg_line..." >> "$log_file"
            echo "Raw text (first 200 chars): ${msg_text:0:200}" >> "$log_file"

            # Process: extract TTS section and truncate
            local tts_text=$(_extract_tts_section "$msg_text")
            tts_text=$(_truncate_text "$tts_text")

            if [ -z "$tts_text" ]; then
                echo "No text to speak after processing, skipping" >> "$log_file"
                last_processed_line=$msg_line
                continue
            fi

            echo "TTS text (first 300 chars): ${tts_text:0:300}" >> "$log_file"
            echo "TTS text length: ${#tts_text} characters" >> "$log_file"

            # Output text to the TTS pipe
            echo "$tts_text"
            last_processed_line=$msg_line
            echo "Queued line $msg_line for TTS" >> "$log_file"
        done < <(_extract_assistant_messages_with_lines "$last_line" "$transcript_path")
    } | kokoro-tts - --stream \
        --voice "$TTS_VOICE" \
        --lang "$TTS_LANG" \
        --speed "$TTS_SPEED" \
        --model "$TTS_MODEL" \
        --voices "$TTS_VOICES" \
        >> "$log_file" 2>&1

    echo "TTS process completed" >> "$log_file"

    if [ "$messages_found" -eq 0 ]; then
        echo "No assistant messages found in new lines" >> "$log_file"
        return 0
    fi

    # Update session state to the last processed line after all TTS completes
    _update_session_state "$session_id" "$last_processed_line"
    echo "Updated session state to line $last_processed_line" >> "$log_file"

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
        # Get current line count (strip whitespace from wc output)
        local current_lines=$(wc -l < "$transcript_path" | tr -d ' ')

        # Update state using shared function
        _update_session_state "$session_id" "$current_lines"
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
