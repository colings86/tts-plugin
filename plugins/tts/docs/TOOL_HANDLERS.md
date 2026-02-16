# Creating Tool TTS Handlers

This guide explains how to add TTS support for new tools in the Claude Code TTS plugin.

## Overview

The TTS plugin can speak outputs from specific tools, not just Claude's text responses. The system uses:

- **PreToolUse Hook** - Fires when tools are about to be called
- **Handler Registry** - Discovers and dispatches to tool-specific handlers
- **Tool Handlers** - Custom logic for extracting and speaking tool-specific content

## Quick Start

1. Create handler file: `scripts/tts-tool-handlers/your-tool-handler.sh`
2. Implement `handle_tool_output()` function
3. Add configuration to `settings.default.json`
4. Test with your tool

## Handler Template

```bash
#!/bin/bash
# TTS handler for YourTool

handle_tool_output() {
    local input_json="$1"

    # Get log file from settings
    local session_id=$(echo "$input_json" | jq -r '.session_id // "default"')
    local log_file="${TTS_LOG_DIR}/claude-tts-${session_id}.log"
    mkdir -p "$TTS_LOG_DIR" 2>/dev/null

    echo "=== YourTool TTS Handler ===" >> "$log_file" 2>&1

    # Extract tool input (parameters being passed to the tool)
    local tool_input=$(echo "$input_json" | jq -r '.tool_input // empty')

    if [ -z "$tool_input" ] || [ "$tool_input" == "null" ]; then
        echo "No tool_input found" >> "$log_file" 2>&1
        return 0
    fi

    # Extract relevant data from input
    local data=$(echo "$tool_input" | jq -r '.your_field // empty')

    # Format for speech
    local speech_text="Your formatted text: $data"

    # Speak it
    speak_text "$speech_text" "$log_file"
}

# Speak text using kokoro-tts (runs in background)
speak_text() {
    local text="$1"
    local log_file="$2"

    # Use settings from TTS_* environment variables (loaded by tts-common.sh)
    echo "$text" | kokoro-tts - --stream \
        --voice "$TTS_VOICE" \
        --lang "$TTS_LANG" \
        --speed "$TTS_SPEED" \
        --model "$TTS_MODEL" \
        --voices "$TTS_VOICES" \
        >> "$log_file" 2>&1 &
}
```

## Naming Convention

Tool name → Handler filename:
- `AskUserQuestion` → `ask-user-question-handler.sh`
- `WebSearch` → `web-search-handler.sh`
- `Bash` → `bash-handler.sh`
- `NotebookRead` → `notebook-read-handler.sh`

The handler registry automatically converts CamelCase tool names to kebab-case filenames.

## Configuration

Add to `settings.default.json`:

```json
{
  "tools": {
    "speak": true,
    "YourTool": {
      "speak": true,
      "customSetting": "value"
    }
  }
}
```

### Configuration Hierarchy

Settings are checked in this order:
1. `tools.YourTool.speak` - Tool-specific setting
2. `tools.speak` - Global tool TTS enable/disable

Use `get_setting()` from handler-registry.sh to read custom settings:

```bash
local custom_value=$(get_setting "tools.YourTool.customSetting" "default_value")
```

## PreToolUse Hook Input

The `handle_tool_output()` function receives JSON input with these fields:

```json
{
  "tool_name": "AskUserQuestion",
  "tool_input": {
    // Tool-specific parameters (what's being passed to the tool)
  },
  "session_id": "abc123...",
  "transcript_path": "/path/to/transcript.jsonl"
}
```

Extract the data you need from `tool_input` and format it for speech.

## Available TTS Settings

Your handler has access to these environment variables (loaded from `tts-common.sh`):

- `$TTS_ENABLED` - Global TTS enable/disable
- `$TTS_PRETOOL_ENABLED` - PreToolUse TTS enable/disable
- `$TTS_VOICE` - Voice name (e.g., "af_bella")
- `$TTS_LANG` - Language code (e.g., "en-gb")
- `$TTS_SPEED` - Speech speed (e.g., 1.3)
- `$TTS_MODEL` - Path to kokoro model file
- `$TTS_VOICES` - Path to voices file
- `$TTS_LOG_DIR` - Log directory path
- `$TTS_STATE_DIR` - State directory path

## Best Practices

### 1. Run Speech in Background

Always use `&` at the end of `kokoro-tts` command to run in background:

```bash
echo "$text" | kokoro-tts - --stream ... >> "$log_file" 2>&1 &
```

This prevents blocking the tool from executing.

### 2. Log Everything

Use the session log file for debugging:

```bash
echo "Processing tool input..." >> "$log_file" 2>&1
echo "Extracted data: $data" >> "$log_file" 2>&1
```

### 3. Handle Missing Data Gracefully

Always check if required fields exist:

```bash
if [ -z "$data" ] || [ "$data" == "null" ]; then
    echo "No data found, skipping TTS" >> "$log_file" 2>&1
    return 0
fi
```

### 4. Format for Speech, Not Display

Text that looks good on screen may not sound good when spoken. Consider:
- Remove markdown formatting
- Expand abbreviations
- Add pauses with punctuation
- Use natural phrasing

### 5. Respect Configuration

Always check if TTS is enabled for your tool:

```bash
local tool_enabled=$(get_setting "tools.YourTool.speak" "false")
if [ "$tool_enabled" != "true" ]; then
    return 0
fi
```

Note: The handler registry already checks this, but you can add extra checks for specific features.

## Example: AskUserQuestion Handler

The `ask-user-question-handler.sh` is a complete reference implementation that shows:

- Extracting questions array from tool_input
- Processing multiple questions
- Formatting options in different styles (sentence/list/simple)
- Configurable formatting via settings
- Proper logging and error handling

See: `scripts/tts-tool-handlers/ask-user-question-handler.sh`

## Future Tool Ideas

Tools that could benefit from TTS handlers:

1. **WebSearch** - Read search results summary
2. **Bash** - Speak command output (opt-in for important commands)
3. **Task** - Announce subagent completion
4. **NotebookRead** - Read cell outputs aloud
5. **AskUserQuestion** - Already implemented! ✓

Each would just need a new handler file in `tts-tool-handlers/`.

## Testing Your Handler

1. **Enable debug logging:**
   ```bash
   tail -f ~/.local/state/claude-tts/logs/claude-tts-*.log
   ```

2. **Trigger your tool:**
   Use the tool in Claude Code and watch the logs

3. **Check handler discovery:**
   Verify your handler filename matches the tool name conversion

4. **Test configuration:**
   Try disabling via `tools.YourTool.speak: false`

5. **Verify async behavior:**
   Ensure tool execution isn't blocked by TTS

## Troubleshooting

### Handler not running

- Check filename matches tool name (CamelCase → kebab-case)
- Verify `tools.speak` or `tools.YourTool.speak` is true
- Check `enabled.pretool` is true in settings
- Look for errors in log file

### No audio output

- Verify kokoro-tts is installed and working
- Check TTS_VOICE and other settings are valid
- Look for kokoro-tts errors in log file
- Test kokoro-tts manually: `echo "test" | kokoro-tts -`

### Tool execution blocked

- Ensure `&` is at the end of kokoro-tts command
- Check async: true in hooks.json for PreToolUse
- Verify timeout is sufficient (default 60s)

## Contributing

When adding a new tool handler:

1. Create the handler file
2. Add configuration to `settings.default.json`
3. Test thoroughly with different inputs
4. Document any custom settings
5. Add example to this guide

---

**Need Help?** Check the example handlers in `scripts/tts-tool-handlers/` or review the handler registry code.
