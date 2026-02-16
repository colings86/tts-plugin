---
name: configure
description: Interactive configuration wizard for TTS settings
argument-hint: "[--user|--project|--local]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# Configure TTS Command

Interactive configuration wizard that helps users customize TTS settings at different hierarchy levels. Shows current merged values and allows modification of voice, speed, language, and advanced settings.

## Instructions

When the user runs this command, follow these steps:

1. **Determine configuration level**:
   - If `--user`, `--project`, or `--local` flag provided, use that level
   - Otherwise, ask user using AskUserQuestion:
     ```
     Where should these settings be saved?
     - User-level (global, all projects) [Recommended]
     - Project-level (this project only, committed to git)
     - Local-level (this machine only, not committed)
     ```
   - Map to target file:
     - User: `$HOME/.claude/plugins/tts/settings.json`
     - Project: `${CLAUDE_PROJECT_ROOT:-.}/.claude/plugins/tts/settings.json`
     - Local: `${CLAUDE_PROJECT_ROOT:-.}/.claude/plugins/tts/settings.local.json`

2. **Load current merged configuration**:
   - Source tts-common.sh to get merged settings:
     ```bash
     source ${CLAUDE_PLUGIN_ROOT}/scripts/tts-common.sh
     ```
   - This gives access to TTS_* environment variables from all hierarchy levels
   - Display current effective configuration:
     ```
     Current TTS Configuration (merged from all levels):
       Global enabled: <TTS_ENABLED>
       PreTool enabled: <TTS_PRETOOL_ENABLED>
       Voice: <TTS_VOICE>
       Language: <TTS_LANG>
       Speed: <TTS_SPEED>
       [... other settings ...]
     ```

3. **Offer configuration sections using AskUserQuestion**:
   - Ask which settings to configure:
     - "Quick Setup" (voice, speed, language, enabled)
     - "Advanced Setup" (all settings)
     - "View Current Settings" (display only, no changes)

4. **For Quick Setup**:
   Use AskUserQuestion to configure:
   - Global enabled (true/false)
   - PreTool enabled (true/false)
   - Voice (show common options: af_bella, af_sarah, af_sky, bf_emma, bf_isabella)
   - Language (show common options: en-gb, en-us, es, fr, de, ja)
   - Speed (numeric input, 0.5-2.0)

5. **For Advanced Setup**:
   Also configure:
   - Use TTS Section (true/false)
   - Max Length (numeric input)
   - Model path
   - Voices path
   - State directory path
   - Log directory path

6. **Update settings file using jq**:
   - Create parent directory if needed:
     ```bash
     mkdir -p <parent_directory>
     ```
   - If target file doesn't exist, copy from defaults:
     ```bash
     cp ${CLAUDE_PLUGIN_ROOT}/settings.default.json <target_file>
     ```
   - For each changed setting, update using jq:
     ```bash
     # Example for voice
     jq '.voice.name = "af_sarah"' <target_file> > <target_file>.tmp && mv <target_file>.tmp <target_file>

     # Example for enabled
     jq '.enabled.global = true' <target_file> > <target_file>.tmp && mv <target_file>.tmp <target_file>

     # Example for speed
     jq '.voice.speed = 1.5' <target_file> > <target_file>.tmp && mv <target_file>.tmp <target_file>
     ```
   - JSON path mappings:
     - Global enabled → `.enabled.global`
     - PreTool enabled → `.enabled.pretool`
     - Voice → `.voice.name`
     - Language → `.voice.language`
     - Speed → `.voice.speed`
     - Model → `.models.model`
     - Voices → `.models.voices`
     - Use TTS Section → `.processing.useTtsSection`
     - Max Length → `.processing.maxLength`
     - State Dir → `.paths.stateDir`
     - Log Dir → `.paths.logDir`

7. **Report success**:
   ```
   ✅ Configuration updated successfully at <level> level

   Changes made:
     - Voice: af_bella → af_sarah
     - Speed: 1.3 → 1.5
     [... list only changed settings ...]

   Settings file: <file_path>

   Next steps:
     - Restart Claude Code for changes to take effect
     - Test TTS: /tts-plugin:test

   Reference:
     - List voices: kokoro-tts --help-voices
     - List languages: kokoro-tts --help-languages
   ```

## Example Flow

### Quick Setup at User Level
```
User: /tts-plugin:configure

Claude: Where should these settings be saved?
[User-level (global, all projects) - Recommended]
[Project-level (this project only, committed to git)]
[Local-level (this machine only, not committed)]

User selects: User-level

Claude: Current TTS Configuration (merged):
  Global enabled: true
  PreTool enabled: true
  Voice: af_bella
  Language: en-gb
  Speed: 1.3

What would you like to configure?
[Quick Setup] [Advanced Setup] [View Current Settings]

User selects: Quick Setup

Claude: Configure Voice (current: af_bella):
[af_bella] [af_sarah] [af_sky] [bf_emma] [bf_isabella] [Other]

User selects: af_sarah

Claude: Configure Speed (current: 1.3):
[Slower (1.0)] [Current (1.3)] [Faster (1.5)] [Custom]

User selects: Faster (1.5)

Claude: ✅ Configuration updated successfully at user level

Changes made:
  - Voice: af_bella → af_sarah
  - Speed: 1.3 → 1.5

Settings file: ~/.claude/plugins/tts/settings.json

Next steps:
  - Restart Claude Code for changes to take effect
  - Test TTS: /tts-plugin:test
```

### Configure with Command-Line Flag
```
/tts-plugin:configure --project
```
Skips the "Where should settings be saved?" question and goes directly to project-level.

## Tips

- **User level**: Best for personal preferences across all projects
- **Project level**: Best for team-wide settings (committed to git)
- **Local level**: Best for machine-specific overrides (not committed)
- Quick Setup covers the most common settings
- Advanced Setup gives access to all configuration options
- View Current Settings shows merged configuration from all levels
- Changes require restarting Claude Code to take effect
