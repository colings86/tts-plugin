#!/bin/bash
# Claude Code TTS Session End Hook - cleanup session state file
# Triggered on the "SessionEnd" event

# Source common TTS library (contains all TTS logic)
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh"

# Read the hook input JSON from stdin
INPUT=$(cat)

# Extract session ID
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# Clean up session state
cleanup_session "$SESSION_ID"

exit 0
