#!/bin/bash
# Claude Code TTS PreToolUse Hook - speaks new messages as they appear
# Triggered on PreToolUse event (before each tool executes)

# Source common TTS library (contains all configuration and logic)
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh"

# Read hook input
INPUT=$(cat)

# Extract required fields
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Check if PreToolUse TTS is enabled (global TTS_ENABLED is checked in the function)
if [ "$TTS_PRETOOL_ENABLED" != "true" ]; then
    exit 0
fi

# Process and speak new messages
process_and_speak_new_messages "$TRANSCRIPT_PATH" "$SESSION_ID"

exit 0
