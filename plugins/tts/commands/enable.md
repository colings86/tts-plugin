---
name: enable
description: Enable text-to-speech for Claude Code responses
argument-hint: "[--user|--project|--local]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
---

# Enable TTS Command

Enable text-to-speech for Claude Code at different configuration levels.

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
   - Update using jq to set enabled.global to true:
     ```bash
     jq '.enabled.global = true' <target_file> > <target_file>.tmp && mv <target_file>.tmp <target_file>
     ```

4. **Report success**:
   ```
   ✅ TTS enabled at <level> level

   Settings file: <file_path>

   Next steps:
     - Restart Claude Code for hooks to activate
     - Test TTS: /tts-plugin:test
     - Configure further: /tts-plugin:configure
   ```

## Examples

### Enable at user level (default, all projects)
```
/tts-plugin:enable
```
or
```
/tts-plugin:enable --user
```

Output:
```
✅ TTS enabled at user level

Settings file: ~/.claude/plugins/tts/settings.json

Next steps:
  - Restart Claude Code for hooks to activate
  - Test TTS: /tts-plugin:test
```

### Enable at project level (committed to git)
```
/tts-plugin:enable --project
```

Output:
```
✅ TTS enabled at project level

Settings file: /path/to/project/.claude/plugins/tts/settings.json

This setting will be committed to git and shared with your team.
```

### Enable at local level (not committed)
```
/tts-plugin:enable --local
```

Output:
```
✅ TTS enabled at local level

Settings file: /path/to/project/.claude/plugins/tts/settings.local.json

This setting is local to your machine and will not be committed to git.
```

## Tips

- **User level**: Use for your personal default across all projects
- **Project level**: Use to share TTS settings with your team (committed to git)
- **Local level**: Use to override project/user settings on your machine only (add to .gitignore)
- Remember to restart Claude Code after enabling for hooks to take effect
