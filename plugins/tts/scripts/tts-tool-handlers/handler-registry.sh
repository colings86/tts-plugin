#!/bin/bash
# Handler registry for tool-specific TTS logic

# Get the directory where handlers are stored
HANDLERS_DIR="${CLAUDE_PLUGIN_ROOT}/scripts/tts-tool-handlers"

# Dispatch to appropriate handler based on tool name
dispatch_tool_handler() {
    local tool_name="$1"
    local input_json="$2"

    # Check if tool TTS is enabled in config
    local tool_enabled=$(get_tool_tts_enabled "$tool_name")
    if [ "$tool_enabled" != "true" ]; then
        return 0
    fi

    # Convert tool name to handler filename
    # "AskUserQuestion" → "ask-user-question-handler.sh"
    local handler_name=$(echo "$tool_name" | sed 's/\([A-Z]\)/-\L\1/g' | sed 's/^-//')
    local handler_path="${HANDLERS_DIR}/${handler_name}-handler.sh"

    # Check if handler exists
    if [ -f "$handler_path" ]; then
        # Source and execute handler
        source "$handler_path"
        handle_tool_output "$input_json"
    fi

    return 0
}

# Check if TTS is enabled for specific tool
get_tool_tts_enabled() {
    local tool_name="$1"

    # Check tool-specific setting first
    local tool_setting=$(get_setting "tools.${tool_name}.speak" "")
    if [ -n "$tool_setting" ]; then
        echo "$tool_setting"
        return
    fi

    # Fall back to global tools setting
    local global_setting=$(get_setting "tools.speak" "false")
    echo "$global_setting"
}

# Helper function to get settings from MERGED_SETTINGS
get_setting() {
    local key="$1"
    local default="$2"

    # Convert dot notation to jq path
    # "tools.AskUserQuestion.speak" → .tools.AskUserQuestion.speak
    local jq_path=$(echo "$key" | sed 's/^/./')

    local value=$(echo "$MERGED_SETTINGS" | jq -r "$jq_path // empty")

    if [ -n "$value" ] && [ "$value" != "null" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}
