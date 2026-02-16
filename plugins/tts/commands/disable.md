---
name: disable
description: Disable text-to-speech for Claude Code responses
argument-hint: "[--user|--project|--local]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# Disable TTS Command

Disable text-to-speech for Claude Code at different configuration levels. Also stops any currently running TTS.

## Instructions

When the user runs this command, follow these steps:

1. **Determine configuration level**:
   - `--user`: User-level (global, all projects) → ~/.claude/plugins/tts/settings.json
   - `--project`: Project-level (this project, committed) → .claude/plugins/tts/settings.json
   - `--local`: Local-level (this machine, not committed) → .claude/plugins/tts/settings.local.json
   - No flag: Default to user-level

2. **Determine target file**:
   - User: `$HOME/.claude/plugins/tts/settings.json`
   - Project: `${CLAUDE_PROJECT_ROOT:-.}/.claude/plugins/tts/settings.json`
   - Local: `${CLAUDE_PROJECT_ROOT:-.}/.claude/plugins/tts/settings.local.json`

3. **Update or create settings file**:
   - Create parent directory if needed:
     ```bash
     mkdir -p <parent_directory>
     ```
   - If file doesn't exist, create from defaults:
     ```bash
     cp ${CLAUDE_PLUGIN_ROOT}/settings.default.json <target_file>
     ```
   - Update using jq to set enabled.global to false:
     ```bash
     jq '.enabled.global = false' <target_file> > <target_file>.tmp && mv <target_file>.tmp <target_file>
     ```

4. **Stop any running TTS**:
   - Kill any running kokoro-tts processes:
     ```bash
     pkill -f kokoro-tts
     ```
   - Note if TTS was interrupted

5. **Report success**:
   ```
   ✅ TTS disabled at <level> level

   Settings file: <file_path>
   <"Any running TTS stopped." if TTS was killed>

   Next steps:
     - Restart Claude Code for hooks to deactivate
     - Re-enable if needed: /tts-plugin:enable
   ```

## Examples

### Disable at user level (default, all projects)
```
/tts-plugin:disable
```
or
```
/tts-plugin:disable --user
```

Output:
```
✅ TTS disabled at user level

Settings file: ~/.claude/plugins/tts/settings.json
Any running TTS stopped.

Restart Claude Code for hooks to fully deactivate.
```

### Disable at project level (committed to git)
```
/tts-plugin:disable --project
```

Output:
```
✅ TTS disabled at project level

Settings file: /path/to/project/.claude/plugins/tts/settings.json

This setting will be committed to git and shared with your team.
```

### Disable at local level (not committed)
```
/tts-plugin:disable --local
```

Output:
```
✅ TTS disabled at local level

Settings file: /path/to/project/.claude/plugins/tts/settings.local.json

This setting is local to your machine and will not be committed to git.
```

## Tips

- **User level**: Disable TTS across all projects
- **Project level**: Disable for this project and share with team
- **Local level**: Override project/user settings on your machine only
- Any running TTS is immediately stopped when you run this command
- Remember to restart Claude Code for hook deactivation to take full effect
