#!/bin/bash
# Claude Code TTS Hook - reads Claude's last response and speaks it via kokoro-tts
# Triggered on the "Stop" event (when Claude finishes responding)

# Source common TTS library (contains all configuration and logic)
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh"

# Read the hook input JSON from stdin
INPUT=$(cat)

# Extract required fields
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Process and speak new messages
process_and_speak_new_messages "$TRANSCRIPT_PATH" "$SESSION_ID"

exit 0
