---
name: configure
description: Interactive configuration wizard for TTS settings
argument-hint: ""
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# Configure TTS Command

Interactive configuration wizard that helps users customize all TTS settings. Shows current values and allows modification of voice, speed, language, and advanced settings.

## Instructions

When the user runs this command, follow these steps:

1. **Check if .env file exists**:
   - Check if ~/.claude/tts-plugin.env exists
   - If not, create it from .env.example:
     ```bash
     cp ${CLAUDE_PLUGIN_ROOT}/.env.example ~/.claude/tts-plugin.env
     ```

2. **Read current configuration**:
   - Read ~/.claude/tts-plugin.env
   - Parse current values for all settings
   - Display current configuration to user in readable format

3. **Offer configuration sections using AskUserQuestion**:
   - Ask which settings to configure:
     - "Quick Setup" (voice, speed, language, enabled)
     - "Advanced Setup" (all settings including PreToolUse, max length, etc.)
     - "View Current Settings" (just display, no changes)

4. **For Quick Setup**:
   Use AskUserQuestion to configure:
   - TTS_ENABLED (true/false)
   - TTS_VOICE (show common options: af_bella, af_sarah, af_sky, bf_emma, bf_isabella)
   - TTS_LANG (show common options: en-gb, en-us, es, fr, de, ja)
   - TTS_SPEED (numeric input, 0.5-2.0)

5. **For Advanced Setup**:
   Also configure:
   - TTS_PRETOOL_ENABLED (true/false)
   - TTS_USE_TTS_SECTION (true/false)
   - TTS_MAX_LENGTH (numeric input)
   - TTS_MODEL path
   - TTS_VOICES path
   - TTS_STATE_DIR path
   - TTS_LOG_DIR path

6. **Update .env file**:
   - Use Edit tool to update each changed setting
   - Confirm changes were saved
   - Show summary of what was changed

7. **Provide next steps**:
   - Remind user to restart Claude Code for changes to take effect
   - Suggest testing: `/tts-plugin:test`
   - Provide voice/language reference:
     - Run `kokoro-tts --help-voices` to see all voices
     - Run `kokoro-tts --help-languages` to see all languages

## Example Flow

### Quick Setup
```
User: /tts-plugin:configure

Claude: Current TTS Configuration:
  TTS_ENABLED: true
  TTS_VOICE: af_bella
  TTS_LANG: en-gb
  TTS_SPEED: 1.3

What would you like to configure?
[Quick Setup] [Advanced Setup] [View Current Settings]

User selects: Quick Setup

Claude: Configure Voice (current: af_bella):
[af_bella] [af_sarah] [af_sky] [bf_emma] [bf_isabella] [Other]

User selects: af_sarah

Claude: Configure Speed (current: 1.3):
[Slower (1.0)] [Current (1.3)] [Faster (1.5)] [Custom]

...continues for all quick setup options...

Claude: Configuration updated successfully:
  - Voice changed: af_bella → af_sarah
  - Speed unchanged: 1.3

Saved to ~/.claude/tts-plugin.env
Restart Claude Code for changes to take effect.
Test with: /tts-plugin:test
```

## Tips

- Start with Quick Setup for common settings
- Use Advanced Setup only when you need fine-grained control
- View Current Settings to see what's configured without making changes
- Run `kokoro-tts --help-voices` and `kokoro-tts --help-languages` for full reference
- Changes require restarting Claude Code to take effect
