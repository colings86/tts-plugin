#!/bin/bash
# Claude Code TTS Hook - reads Claude's last response and speaks it via kokoro-tts
# Triggered on the "Stop" event (when Claude finishes responding)

# DEBUG: Log environment to help diagnose CLAUDE_PLUGIN_ROOT issues
DEBUG_LOG="$HOME/.local/state/claude-tts/logs/hook-debug.log"
mkdir -p "$(dirname "$DEBUG_LOG")" 2>/dev/null
echo "=== Stop Hook Debug at $(date) ===" >> "$DEBUG_LOG"
echo "CLAUDE_PLUGIN_ROOT=${CLAUDE_PLUGIN_ROOT}" >> "$DEBUG_LOG"
echo "PWD=$PWD" >> "$DEBUG_LOG"
echo "Attempting to source: ${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh" >> "$DEBUG_LOG"

# Source common TTS library (contains all configuration and logic)
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh" 2>> "$DEBUG_LOG"

# Read the hook input JSON from stdin
INPUT=$(cat)

# Extract required fields
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# WORKAROUND: Add delay to allow transcript to be fully written
# The Stop event fires before text content is written to transcript
# Wait 1 second to ensure text content is available
echo "Waiting 1 second for transcript to update..." >> "$DEBUG_LOG"
sleep 1

# Process and speak new messages
process_and_speak_new_messages "$TRANSCRIPT_PATH" "$SESSION_ID"

exit 0
