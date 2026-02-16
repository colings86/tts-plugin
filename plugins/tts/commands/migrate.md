---
name: migrate
description: Migrate legacy .env configuration to settings.json
argument-hint: ""
allowed-tools:
  - Bash
  - Read
  - Write
---

# Migrate TTS Configuration

Migrates legacy ~/.claude/tts-plugin.env to the new hierarchical settings.json format.

## Instructions

When the user runs this command, follow these steps:

1. **Check for legacy .env file**:
   - Check if ~/.claude/tts-plugin.env exists
   - If it doesn't exist: "No legacy .env file found at ~/.claude/tts-plugin.env. Nothing to migrate."
   - If exists: proceed to migration

2. **Parse .env file**:
   - Read ~/.claude/tts-plugin.env using Read tool
   - Extract each TTS_* variable value (lines like TTS_ENABLED=true)
   - Build mapping:
     - TTS_ENABLED → enabled.global (convert "true"/"false" to boolean)
     - TTS_PRETOOL_ENABLED → enabled.pretool (convert to boolean)
     - TTS_VOICE → voice.name (string)
     - TTS_LANG → voice.language (string)
     - TTS_SPEED → voice.speed (convert to number)
     - TTS_MODEL → models.model (string)
     - TTS_VOICES → models.voices (string)
     - TTS_USE_TTS_SECTION → processing.useTtsSection (convert to boolean)
     - TTS_MAX_LENGTH → processing.maxLength (convert to number)
     - TTS_STATE_DIR → paths.stateDir (string)
     - TTS_LOG_DIR → paths.logDir (string)

3. **Build settings.json**:
   - Create nested JSON structure with proper types:
     ```json
     {
       "enabled": {
         "global": <boolean>,
         "pretool": <boolean>
       },
       "voice": {
         "name": "<string>",
         "language": "<string>",
         "speed": <number>
       },
       "models": {
         "model": "<string>",
         "voices": "<string>"
       },
       "processing": {
         "useTtsSection": <boolean>,
         "maxLength": <number>
       },
       "paths": {
         "stateDir": "<string>",
         "logDir": "<string>"
       }
     }
     ```
   - Use 2-space indentation for pretty-printing

4. **Write settings.json**:
   - Create directory: `mkdir -p ~/.claude/plugins/tts`
   - Write to ~/.claude/plugins/tts/settings.json using Write tool
   - Ensure proper JSON formatting

5. **Backup original**:
   - Rename ~/.claude/tts-plugin.env to ~/.claude/tts-plugin.env.backup
   - Use: `mv ~/.claude/tts-plugin.env ~/.claude/tts-plugin.env.backup`

6. **Report success**:
   Show summary:
   ```
   ✅ Migration completed successfully!

   Migrated settings:
     - Global enabled: <value>
     - PreTool enabled: <value>
     - Voice: <value>
     - Language: <value>
     - Speed: <value>
     [... other settings ...]

   New configuration location:
     ~/.claude/plugins/tts/settings.json

   Original .env backed up to:
     ~/.claude/tts-plugin.env.backup

   Next steps:
     - Restart Claude Code for changes to take effect
     - Test TTS: /tts-plugin:test
     - Configure further: /tts-plugin:configure
   ```

## Error Handling

- If .env file has invalid syntax, report specific line and continue with defaults for that value
- If directories can't be created, report error with permissions guidance
- If backup fails, warn but continue (don't block migration)

## Example

```
User: /tts-plugin:migrate

Claude: Found legacy configuration at ~/.claude/tts-plugin.env

Migrating to new format...

✅ Migration completed successfully!

Migrated settings:
  - Global enabled: true
  - PreTool enabled: true
  - Voice: af_bella
  - Language: en-gb
  - Speed: 1.3
  - Model: $HOME/.local/share/kokoro-tts/kokoro-v1.0.onnx
  - Voices: $HOME/.local/share/kokoro-tts/voices-v1.0.bin
  - Use TTS Section: true
  - Max Length: 5000
  - State Dir: $HOME/.local/state/claude-tts/session-state
  - Log Dir: $HOME/.local/state/claude-tts/logs

New configuration location:
  ~/.claude/plugins/tts/settings.json

Original .env backed up to:
  ~/.claude/tts-plugin.env.backup

Restart Claude Code for changes to take effect.
Test with: /tts-plugin:test
```
