#!/bin/bash
# PreToolUse hook for TTS - processes transcript including tool uses
# Triggered on PreToolUse and PermissionRequest events

# Source common TTS library (contains all TTS logic)
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh"

# Read the hook input JSON from stdin
INPUT=$(cat)

# Extract session ID, transcript path, and current message
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
CURRENT_MESSAGE=$(echo "$INPUT" | jq -c '.message // null')

# Check if TTS is enabled (global TTS_ENABLED is checked in the function)
if [ "$TTS_ENABLED" != "true" ]; then
    exit 0
fi

# Check if PreToolUse TTS is enabled
if [ "$TTS_PRETOOL_ENABLED" != "true" ]; then
    exit 0
fi

# Process and speak new messages (including tool uses and current message)
process_and_speak_new_messages "$TRANSCRIPT_PATH" "$SESSION_ID" "$CURRENT_MESSAGE"

exit 0
