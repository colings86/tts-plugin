---
name: disable
description: Disable text-to-speech for Claude Code responses
argument-hint: "[--persistent]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# Disable TTS Command

Disable text-to-speech for Claude Code. Can disable for current session only or persistently by modifying the .env file.

## Instructions

When the user runs this command, follow these steps:

1. **Check if --persistent flag is provided**:
   - If `--persistent` flag is present, disable TTS persistently by modifying ~/.claude/tts-plugin.env
   - Otherwise, disable only for current session (export environment variable)

2. **For persistent disable**:
   - Check if ~/.claude/tts-plugin.env exists
   - If it exists, update TTS_ENABLED=false using Edit tool
   - If it doesn't exist, create it from .env.example and set TTS_ENABLED=false
   - Inform user: "TTS disabled persistently. Configuration saved to ~/.claude/tts-plugin.env"

3. **For session-only disable**:
   - Export TTS_ENABLED=false for current shell
   - Inform user: "TTS disabled for current session only. Use --persistent flag to save this setting."

4. **Stop any running TTS**:
   - Kill any running kokoro-tts processes: `pkill -f kokoro-tts`
   - Inform user if TTS was interrupted

5. **Provide next steps**:
   - Remind user that hook changes require restarting Claude Code
   - Suggest re-enabling if needed: `/tts-plugin:enable`

## Examples

### Disable for current session
```
/tts-plugin:disable
```

Output: "TTS disabled for current session only. Any running TTS stopped."

### Disable persistently
```
/tts-plugin:disable --persistent
```

Output: "TTS disabled persistently. Configuration saved to ~/.claude/tts-plugin.env. Any running TTS stopped."

## Tips

- Use session-only mode for temporary silence
- Use persistent mode to save the setting permanently
- Remember to restart Claude Code after disabling for hooks to fully deactivate
- You can re-enable TTS anytime with `/tts-plugin:enable`
