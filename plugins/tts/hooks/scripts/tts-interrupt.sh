#!/bin/bash
# Claude Code TTS Interrupt Hook - kills TTS playback and adds TTS Response instruction
# Triggered on the "UserPromptSubmit" event

# Source common TTS library (contains all TTS logic)
source "${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh"

# Configuration
ADD_TTS_INSTRUCTION="true"  # Set to "false" to disable automatic TTS Response section requests
TTS_INSTRUCTION_TEMPLATE="${CLAUDE_PLUGIN_ROOT}/scripts/tts-instruction-template.txt"

# Read the hook input JSON from stdin
INPUT=$(cat)

# Extract session ID and transcript path
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Interrupt TTS and mark messages as read
interrupt_tts_and_mark_read "$TRANSCRIPT_PATH" "$SESSION_ID"

# If TTS instructions are disabled, just pass through the input
if [ "$ADD_TTS_INSTRUCTION" != "true" ]; then
    echo "$INPUT"
    exit 0
fi

# Extract the user's message
USER_MESSAGE=$(echo "$INPUT" | jq -r '.message // empty')

if [ -z "$USER_MESSAGE" ]; then
    # No message to modify, pass through original input
    echo "$INPUT"
    exit 0
fi

# Read TTS instruction template
TTS_INSTRUCTION=$(cat "$TTS_INSTRUCTION_TEMPLATE" 2>/dev/null)

# If template file doesn't exist or is empty, use a simple fallback
if [ -z "$TTS_INSTRUCTION" ]; then
    TTS_INSTRUCTION="---
IMPORTANT: At the end of your response, add a \"## TTS Response\" section optimized for text-to-speech."
fi

# Append TTS instruction to the user's message
MODIFIED_MESSAGE="${USER_MESSAGE}

${TTS_INSTRUCTION}"

# Create modified JSON with the new message
echo "$INPUT" | jq --arg msg "$MODIFIED_MESSAGE" '.message = $msg'

exit 0
