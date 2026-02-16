#!/bin/bash
# Claude Code TTS Common Library - holistic TTS workflow engine
# Source this file in TTS hooks with: source ${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh

# ============================================================================
# Load Configuration from settings.json (hierarchical)
# ============================================================================

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is required for TTS plugin. Install: brew install jq (macOS) or apt-get install jq (Linux)" >&2
    exit 1
fi

# Define settings file paths (priority: local > project > user > defaults)
DEFAULT_SETTINGS="${CLAUDE_PLUGIN_ROOT}/settings.default.json"
USER_SETTINGS="$HOME/.claude/plugins/tts/settings.json"
PROJECT_SETTINGS="${CLAUDE_PROJECT_ROOT:-.}/.claude/plugins/tts/settings.json"
LOCAL_SETTINGS="${CLAUDE_PROJECT_ROOT:-.}/.claude/plugins/tts/settings.local.json"

# Load and merge JSON settings from all hierarchy levels
_load_json_settings() {
    local merged_settings=""
    merged_settings=$(cat "$DEFAULT_SETTINGS")

    # Merge in priority order: defaults < user < project < local
    [ -f "$USER_SETTINGS" ] && merged_settings=$(jq -s '.[0] * .[1]' <(echo "$merged_settings") "$USER_SETTINGS")
    [ -f "$PROJECT_SETTINGS" ] && merged_settings=$(jq -s '.[0] * .[1]' <(echo "$merged_settings") "$PROJECT_SETTINGS")
    [ -f "$LOCAL_SETTINGS" ] && merged_settings=$(jq -s '.[0] * .[1]' <(echo "$merged_settings") "$LOCAL_SETTINGS")

    echo "$merged_settings"
}

# Export JSON settings to environment variables
_export_json_to_env() {
    local json="$1"

    export TTS_ENABLED=$(echo "$json" | jq -r 'if .enabled.global == null then true else .enabled.global end')
    export TTS_PRETOOL_ENABLED=$(echo "$json" | jq -r 'if .enabled.pretool == null then true else .enabled.pretool end')
    export TTS_VOICE=$(echo "$json" | jq -r '.voice.name // "af_bella"')
    export TTS_LANG=$(echo "$json" | jq -r '.voice.language // "en-gb"')
    export TTS_SPEED=$(echo "$json" | jq -r '.voice.speed // 1.3')
    export TTS_MODEL=$(echo "$json" | jq -r '.models.model // "$HOME/.local/share/kokoro-tts/kokoro-v1.0.onnx"')
    export TTS_VOICES=$(echo "$json" | jq -r '.models.voices // "$HOME/.local/share/kokoro-tts/voices-v1.0.bin"')
    export TTS_USE_TTS_SECTION=$(echo "$json" | jq -r 'if .processing.useTtsSection == null then true else .processing.useTtsSection end')
    export TTS_MAX_LENGTH=$(echo "$json" | jq -r '.processing.maxLength // 5000')
    export TTS_STATE_DIR=$(echo "$json" | jq -r '.paths.stateDir // "$HOME/.local/state/claude-tts/session-state"')
    export TTS_LOG_DIR=$(echo "$json" | jq -r '.paths.logDir // "$HOME/.local/state/claude-tts/logs"')

    # Expand $HOME in paths
    TTS_MODEL="${TTS_MODEL/#\$HOME/$HOME}"
    TTS_VOICES="${TTS_VOICES/#\$HOME/$HOME}"
    TTS_STATE_DIR="${TTS_STATE_DIR/#\$HOME/$HOME}"
    TTS_LOG_DIR="${TTS_LOG_DIR/#\$HOME/$HOME}"
}

# Load merged settings and export to environment
MERGED_SETTINGS=$(_load_json_settings)
_export_json_to_env "$MERGED_SETTINGS"

# ============================================================================
# Internal Helper Functions
# ============================================================================

# Extract TTS Response section from text, or return full text if not found
_extract_tts_section() {
    local text="$1"

    if [ "$TTS_USE_TTS_SECTION" = "true" ]; then
        # Extract content after heading containing "TTS Response" (with or without emoji)
        # Also strips italic markdown (underscores) from the content
        local tts_section=$(awk '/^##.*TTS Response/{flag=1; next} flag' <<< "$text" | \
            sed 's/^_//;s/_$//' | \
            sed 's/_/ /g')

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

# Extract assistant messages AND tool uses since a given UUID
# Outputs: uuid|type|content (one output per entry)
# Types: "text" for assistant messages, "tool" for tool uses
# Content: For text, the message text; for tool, JSON with tool_name and tool_input
_extract_entries_since_uuid() {
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
                echo "${ENTRY_UUID}|text|${MESSAGE_TEXT_ENCODED}"
            fi
        # Extract tool use entries
        elif [ "$TYPE" = "tool_use" ]; then
            # Extract tool_name and tool_input from the entry
            TOOL_NAME=$(echo "$json_line" | jq -r '.tool_name // empty' 2>/dev/null)
            TOOL_INPUT=$(echo "$json_line" | jq -c '.tool_input // {}' 2>/dev/null)

            if [ -n "$TOOL_NAME" ]; then
                # Create JSON payload for handler, encode it so it's a single line
                TOOL_JSON=$(jq -nc --arg name "$TOOL_NAME" --argjson input "$TOOL_INPUT" '{tool_name: $name, tool_input: $input}')
                TOOL_JSON_ENCODED=$(printf '%s' "$TOOL_JSON" | sed 's/$/|||NL|||/g' | tr -d '\n' | sed 's/|||NL|||$//')
                echo "${ENTRY_UUID}|tool|${TOOL_JSON_ENCODED}"
            fi
        fi
    done < "$transcript_path"
}

# Backward compatibility: keep old function name as alias
_extract_assistant_messages_since_uuid() {
    _extract_entries_since_uuid "$@" | grep '|text|' | sed 's/|text|/|/'
}

# ============================================================================
# Main Public Function
# ============================================================================

# Process and speak new messages from transcript
# Usage: process_and_speak_new_messages "$transcript_path" "$session_id" "$current_message_json"
process_and_speak_new_messages() {
    local transcript_path="$1"
    local session_id="$2"
    local current_message_json="$3"  # Optional: current message from hook input

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

    # Extract messages and tool uses with UUIDs
    echo "Extracting entries..." >> "$log_file"
    local messages_found=0

    # Source handler registry for tool-specific TTS
    if [ -f "${CLAUDE_PLUGIN_ROOT}/scripts/tts-tool-handlers/handler-registry.sh" ]; then
        source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-tool-handlers/handler-registry.sh"
    fi

    # Process all transcript entries and pipe through ONE TTS process
    # This is much more efficient than creating a new process per entry
    # Use temp files to track last UUID and all processed UUIDs
    local uuid_tracker="/tmp/tts-uuid-tracker-${session_id}-$$"
    local all_uuids_tracker="/tmp/tts-all-uuids-${session_id}-$$"
    rm -f "$uuid_tracker" "$all_uuids_tracker"
    echo "Starting TTS processing for all new entries..." >> "$log_file"

    {
        while IFS='|' read -r entry_uuid entry_type entry_content; do
            echo "Processing entry UUID: $entry_uuid, Type: $entry_type" >> "$log_file"

            # Track all processed UUIDs
            echo "$entry_uuid" >> "$all_uuids_tracker"

            # Handle tool use entries
            if [ "$entry_type" = "tool" ]; then
                # Decode the JSON content
                entry_content=$(printf '%s' "$entry_content" | sed 's/|||NL|||/\n/g')

                echo "Tool use detected" >> "$log_file"

                # Extract tool_name for logging and dispatch
                TOOL_NAME=$(echo "$entry_content" | jq -r '.tool_name // empty')
                echo "Tool name: $TOOL_NAME" >> "$log_file"

                # Check if tool TTS is enabled and handler exists
                if [ "$TTS_PRETOOL_ENABLED" = "true" ] && type dispatch_tool_handler >/dev/null 2>&1; then
                    # Create input for handler (add session_id and transcript_path)
                    HANDLER_INPUT=$(echo "$entry_content" | jq -c --arg sid "$session_id" --arg tp "$transcript_path" '. + {session_id: $sid, transcript_path: $tp}')

                    echo "Dispatching to tool handler..." >> "$log_file"
                    dispatch_tool_handler "$TOOL_NAME" "$HANDLER_INPUT" 2>> "$log_file"
                else
                    echo "Tool TTS disabled or handler not available" >> "$log_file"
                fi

                # Track UUID and continue
                echo "$entry_uuid" > "$uuid_tracker"
                continue
            fi

            # Handle text entries (assistant messages)
            if [ "$entry_type" = "text" ]; then
                # Decode newlines from placeholder (|||NL|||) back to actual newlines
                msg_text=$(printf '%s' "$entry_content" | sed 's/|||NL|||/\n/g')

                echo "Raw text (first 200 chars): ${msg_text:0:200}" >> "$log_file"

                # Process: extract TTS section and truncate
                local tts_text=$(_extract_tts_section "$msg_text")
                tts_text=$(_truncate_text "$tts_text")

                # Skip empty messages
                if [ -z "$tts_text" ]; then
                    echo "No text to speak after processing, skipping" >> "$log_file"
                    echo "$entry_uuid" > "$uuid_tracker"
                    continue
                fi

                # Skip "No response requested" messages from local commands
                if [ "$tts_text" = "No response requested." ]; then
                    echo "Skipping 'No response requested' message" >> "$log_file"
                    echo "$entry_uuid" > "$uuid_tracker"
                    continue
                fi

                echo "TTS text (first 300 chars): ${tts_text:0:300}" >> "$log_file"
                echo "TTS text length: ${#tts_text} characters" >> "$log_file"

                # Output text to the TTS pipe
                echo "$tts_text"
                # Track last processed UUID in temp file (survives subshell)
                echo "$entry_uuid" > "$uuid_tracker"
                echo "Queued UUID $entry_uuid for TTS" >> "$log_file"
            fi
        done < <(_extract_entries_since_uuid "$last_uuid" "$transcript_path")
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

    # Process current message from hook input (if provided)
    # This ensures the message that triggered the hook is also processed
    if [ -n "$current_message_json" ] && [ "$current_message_json" != "null" ]; then
        echo "Processing current message from hook input..." >> "$log_file"

        # Extract message details
        local current_uuid=$(echo "$current_message_json" | jq -r '.uuid // empty')
        local current_type=$(echo "$current_message_json" | jq -r '.type // empty')
        local current_role=$(echo "$current_message_json" | jq -r '.message.role // empty')

        echo "Current message UUID: $current_uuid, Type: $current_type, Role: $current_role" >> "$log_file"

        # Check if this UUID was already processed in the transcript
        local already_processed=false
        if [ -f "$all_uuids_tracker" ] && grep -q "^${current_uuid}$" "$all_uuids_tracker" 2>/dev/null; then
            already_processed=true
            echo "Current message UUID already processed in transcript, skipping" >> "$log_file"
        fi

        # Only process if it has a UUID and wasn't already processed
        if [ -n "$current_uuid" ] && [ "$already_processed" = "false" ]; then
            # Handle tool use messages
            if [ "$current_type" = "tool_use" ]; then
                TOOL_NAME=$(echo "$current_message_json" | jq -r '.tool_name // empty')
                TOOL_INPUT=$(echo "$current_message_json" | jq -c '.tool_input // {}')

                echo "Current message is tool use: $TOOL_NAME" >> "$log_file"

                if [ "$TTS_PRETOOL_ENABLED" = "true" ] && type dispatch_tool_handler >/dev/null 2>&1; then
                    HANDLER_INPUT=$(jq -nc --arg name "$TOOL_NAME" --argjson input "$TOOL_INPUT" --arg sid "$session_id" --arg tp "$transcript_path" '{tool_name: $name, tool_input: $input, session_id: $sid, transcript_path: $tp}')
                    dispatch_tool_handler "$TOOL_NAME" "$HANDLER_INPUT" 2>> "$log_file"
                fi

                last_processed_uuid="$current_uuid"
            # Handle assistant text messages
            elif [ "$current_type" = "assistant" ] && [ "$current_role" = "assistant" ]; then
                MESSAGE_TEXT=$(echo "$current_message_json" | jq -r '[.message.content[]? | select(.type == "text") | .text] | join(" ")')

                echo "Current message is assistant text (first 200 chars): ${MESSAGE_TEXT:0:200}" >> "$log_file"

                if [ -n "$MESSAGE_TEXT" ]; then
                    local tts_text=$(_extract_tts_section "$MESSAGE_TEXT")
                    tts_text=$(_truncate_text "$tts_text")

                    if [ -n "$tts_text" ] && [ "$tts_text" != "No response requested." ]; then
                        echo "Speaking current message text..." >> "$log_file"
                        _speak_text "$tts_text" "$log_file" false
                    fi

                    last_processed_uuid="$current_uuid"
                fi
            fi
        else
            echo "Current message already processed or no UUID" >> "$log_file"
        fi

        # Clean up all UUIDs tracker
        rm -f "$all_uuids_tracker"
    fi

    # Check if any messages were processed
    if [ -z "$last_processed_uuid" ]; then
        echo "No messages processed" >> "$log_file"
        rm -f "$all_uuids_tracker"
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
