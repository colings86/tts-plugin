#!/bin/bash
# PreToolUse hook for tool-specific TTS handling

# Source common TTS library
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh"

# Read hook input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Check if TTS is enabled
if [ "$TTS_ENABLED" != "true" ]; then
    exit 0
fi

# Check if PreToolUse TTS is enabled
if [ "$TTS_PRETOOL_ENABLED" != "true" ]; then
    exit 0
fi

# Dispatch to tool-specific handler
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-tool-handlers/handler-registry.sh"
dispatch_tool_handler "$TOOL_NAME" "$INPUT"

exit 0
