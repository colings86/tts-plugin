#!/bin/bash
# Handler registry for tool-specific TTS logic

# Get the directory where handlers are stored
HANDLERS_DIR="${CLAUDE_PLUGIN_ROOT}/scripts/tts-tool-handlers"

# Dispatch to appropriate handler based on tool name
dispatch_tool_handler() {
    local tool_name="$1"
    local input_json="$2"

    local DEBUG_LOG="$HOME/.local/state/claude-tts/logs/pretooluse-debug.log"

    echo "  dispatch_tool_handler called for: $tool_name" >> "$DEBUG_LOG"

    # Check if tool TTS is enabled in config
    local tool_enabled=$(get_tool_tts_enabled "$tool_name")
    echo "  tool_enabled result: '$tool_enabled'" >> "$DEBUG_LOG"
    if [ "$tool_enabled" != "true" ]; then
        echo "  Exiting: tool not enabled (tool_enabled='$tool_enabled')" >> "$DEBUG_LOG"
        return 0
    fi

    # Convert tool name to handler filename
    # "AskUserQuestion" → "ask-user-question-handler.sh"
    local handler_name=$(echo "$tool_name" | sed 's/\([A-Z]\)/-\1/g' | sed 's/^-//' | tr '[:upper:]' '[:lower:]')
    local handler_path="${HANDLERS_DIR}/${handler_name}-handler.sh"

    echo "  handler_name: $handler_name" >> "$DEBUG_LOG"
    echo "  handler_path: $handler_path" >> "$DEBUG_LOG"
    echo "  handler exists: $([ -f "$handler_path" ] && echo 'yes' || echo 'no')" >> "$DEBUG_LOG"

    # Check if handler exists
    if [ -f "$handler_path" ]; then
        echo "  Sourcing and executing handler..." >> "$DEBUG_LOG"
        # Source and execute handler
        source "$handler_path"
        handle_tool_output "$input_json"
        echo "  Handler execution completed" >> "$DEBUG_LOG"
    else
        echo "  Handler file not found" >> "$DEBUG_LOG"
    fi

    return 0
}

# Check if TTS is enabled for specific tool
get_tool_tts_enabled() {
    local tool_name="$1"

    local DEBUG_LOG="$HOME/.local/state/claude-tts/logs/pretooluse-debug.log"
    echo "    get_tool_tts_enabled called for: $tool_name" >> "$DEBUG_LOG"

    # Check tool-specific setting first
    local tool_setting=$(get_setting "tools.${tool_name}.speak" "")
    echo "    tool-specific setting (tools.${tool_name}.speak): '$tool_setting'" >> "$DEBUG_LOG"
    if [ -n "$tool_setting" ]; then
        echo "    Returning tool-specific: '$tool_setting'" >> "$DEBUG_LOG"
        echo "$tool_setting"
        return
    fi

    # Fall back to global tools setting
    local global_setting=$(get_setting "tools.speak" "false")
    echo "    global setting (tools.speak): '$global_setting'" >> "$DEBUG_LOG"
    echo "    Returning global: '$global_setting'" >> "$DEBUG_LOG"
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
