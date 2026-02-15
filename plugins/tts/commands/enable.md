---
name: enable
description: Enable text-to-speech for Claude Code responses
argument-hint: "[--persistent]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# Enable TTS Command

Enable text-to-speech for Claude Code. Can enable for current session only or persistently by modifying the .env file.

## Instructions

When the user runs this command, follow these steps:

1. **Check if --persistent flag is provided**:
   - If `--persistent` flag is present, enable TTS persistently by modifying ~/.claude/tts-plugin.env
   - Otherwise, enable only for current session (export environment variable)

2. **For persistent enable**:
   - Check if ~/.claude/tts-plugin.env exists
   - If it doesn't exist, copy .env.example from the plugin directory:
     ```bash
     cp ${CLAUDE_PLUGIN_ROOT}/.env.example ~/.claude/tts-plugin.env
     ```
   - Update TTS_ENABLED=true in the .env file using Edit tool
   - Inform user: "TTS enabled persistently. Configuration saved to ~/.claude/tts-plugin.env"

3. **For session-only enable**:
   - Export TTS_ENABLED=true for current shell
   - Inform user: "TTS enabled for current session only. Use --persistent flag to save this setting."

4. **Provide next steps**:
   - Remind user that hook changes require restarting Claude Code
   - Suggest testing: `/tts-plugin:test`
   - Suggest configuration if needed: `/tts-plugin:configure`

## Examples

### Enable for current session
```
/tts-plugin:enable
```

Output: "TTS enabled for current session only. Restart Claude Code for hooks to activate."

### Enable persistently
```
/tts-plugin:enable --persistent
```

Output: "TTS enabled persistently. Configuration saved to ~/.claude/tts-plugin.env. Restart Claude Code for hooks to activate."

## Tips

- Use session-only mode for quick testing
- Use persistent mode to save the setting permanently
- Remember to restart Claude Code after enabling for hooks to take effect
- Test TTS is working with `/tts-plugin:test` after enabling
