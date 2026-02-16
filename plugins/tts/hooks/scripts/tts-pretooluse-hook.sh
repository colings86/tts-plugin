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

# For PreToolUse, build current message from tool_name and tool_input
# The hook input has: {tool_name, tool_input, session_id, transcript_path, ...}
# We need to create a message structure with type="tool_use"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')

if [ -n "$TOOL_NAME" ]; then
    CURRENT_MESSAGE=$(jq -nc --arg name "$TOOL_NAME" --argjson input "$TOOL_INPUT" '{type: "tool_use", tool_name: $name, tool_input: $input, uuid: "current"}')
else
    CURRENT_MESSAGE="null"
fi

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
