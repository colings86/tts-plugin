#!/bin/bash
# PreToolUse hook for tool-specific TTS handling

# DEBUG: Log environment to help diagnose issues
DEBUG_LOG="$HOME/.local/state/claude-tts/logs/pretooluse-debug.log"
mkdir -p "$(dirname "$DEBUG_LOG")" 2>/dev/null
echo "=== PreToolUse Hook Debug at $(date) ===" >> "$DEBUG_LOG"
echo "CLAUDE_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}" >> "$DEBUG_LOG"
echo "PWD=$PWD" >> "$DEBUG_LOG"

# Source common TTS library
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh"

# Read hook input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
echo "TOOL_NAME=$TOOL_NAME" >> "$DEBUG_LOG"
echo "INPUT (first 200 chars)=${INPUT:0:200}" >> "$DEBUG_LOG"

# Check if TTS is enabled
echo "TTS_ENABLED=$TTS_ENABLED" >> "$DEBUG_LOG"
if [ "$TTS_ENABLED" != "true" ]; then
    echo "Exiting: TTS not enabled" >> "$DEBUG_LOG"
    exit 0
fi

# Check if PreToolUse TTS is enabled
echo "TTS_PRETOOL_ENABLED=$TTS_PRETOOL_ENABLED" >> "$DEBUG_LOG"
if [ "$TTS_PRETOOL_ENABLED" != "true" ]; then
    echo "Exiting: PreToolUse TTS not enabled" >> "$DEBUG_LOG"
    exit 0
fi

# Dispatch to tool-specific handler
echo "Dispatching to handler registry..." >> "$DEBUG_LOG"
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-tool-handlers/handler-registry.sh"
echo "Calling dispatch_tool_handler..." >> "$DEBUG_LOG"
dispatch_tool_handler "$TOOL_NAME" "$INPUT"
echo "Handler dispatch completed" >> "$DEBUG_LOG"

exit 0
