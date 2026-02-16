# Migration Guide: .env to settings.json

This guide helps you migrate from the legacy `.env` configuration format to the new hierarchical `settings.json` format introduced in v0.2.0.

## Why Migrate?

The new `settings.json` format provides several benefits:

### Hierarchical Configuration
- **User-level** (~/.claude/plugins/tts/settings.json): Personal defaults across all projects
- **Project-level** (.claude/plugins/tts/settings.json): Team settings committed to git
- **Local-level** (.claude/plugins/tts/settings.local.json): Machine-specific overrides not committed

### Better Collaboration
- Commit project-level settings to share TTS configuration with your team
- Override team settings locally without modifying committed files
- Consistent configuration across all team members

### Improved Structure
- Nested JSON structure for logical grouping
- JSON schema validation for type safety
- Better defaults and fallback handling
- Matches Claude Code's configuration patterns (CLAUDE.md, settings.json)

### Flexibility
- Configure at different scopes (local > project > user > defaults)
- Deep merging of settings across hierarchy levels
- Easy to understand what setting comes from where

## Automatic Migration

The easiest way to migrate is using the automatic migration command:

```bash
/tts-plugin:migrate
```

This command will:
1. Read your existing ~/.claude/tts-plugin.env
2. Convert all settings to the new JSON format
3. Write to ~/.claude/plugins/tts/settings.json
4. Back up the original to ~/.claude/tts-plugin.env.backup
5. Show you a summary of migrated settings

**Example output:**
```
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
```

## Manual Migration

If you prefer to migrate manually or need to understand the mapping:

### 1. Create the new settings file

```bash
mkdir -p ~/.claude/plugins/tts
cp ~/.claude/plugins/tts-plugin/settings.default.json ~/.claude/plugins/tts/settings.json
```

### 2. Configuration mapping

Map your old .env variables to the new JSON structure:

| Old .env Variable | New JSON Path | Type | Example |
|------------------|---------------|------|---------|
| TTS_ENABLED | enabled.global | boolean | true |
| TTS_PRETOOL_ENABLED | enabled.pretool | boolean | true |
| TTS_VOICE | voice.name | string | "af_bella" |
| TTS_LANG | voice.language | string | "en-gb" |
| TTS_SPEED | voice.speed | number | 1.3 |
| TTS_MODEL | models.model | string | "$HOME/..." |
| TTS_VOICES | models.voices | string | "$HOME/..." |
| TTS_USE_TTS_SECTION | processing.useTtsSection | boolean | true |
| TTS_MAX_LENGTH | processing.maxLength | number | 5000 |
| TTS_STATE_DIR | paths.stateDir | string | "$HOME/..." |
| TTS_LOG_DIR | paths.logDir | string | "$HOME/..." |

### 3. Example conversion

**Old .env format:**
```bash
TTS_ENABLED=true
TTS_PRETOOL_ENABLED=true
TTS_VOICE=af_sarah
TTS_LANG=en-us
TTS_SPEED=1.5
TTS_MODEL=$HOME/.local/share/kokoro-tts/kokoro-v1.0.onnx
TTS_VOICES=$HOME/.local/share/kokoro-tts/voices-v1.0.bin
TTS_USE_TTS_SECTION=true
TTS_MAX_LENGTH=5000
TTS_STATE_DIR=$HOME/.local/state/claude-tts/session-state
TTS_LOG_DIR=$HOME/.local/state/claude-tts/logs
```

**New settings.json format:**
```json
{
  "enabled": {
    "global": true,
    "pretool": true
  },
  "voice": {
    "name": "af_sarah",
    "language": "en-us",
    "speed": 1.5
  },
  "models": {
    "model": "$HOME/.local/share/kokoro-tts/kokoro-v1.0.onnx",
    "voices": "$HOME/.local/share/kokoro-tts/voices-v1.0.bin"
  },
  "processing": {
    "useTtsSection": true,
    "maxLength": 5000
  },
  "paths": {
    "stateDir": "$HOME/.local/state/claude-tts/session-state",
    "logDir": "$HOME/.local/state/claude-tts/logs"
  }
}
```

### 4. Backup and remove old .env

```bash
mv ~/.claude/tts-plugin.env ~/.claude/tts-plugin.env.backup
```

## Using the New System

### User-level settings (global)

Configure your personal defaults across all projects:

```bash
/tts-plugin:enable --user
/tts-plugin:configure --user
```

Settings saved to: `~/.claude/plugins/tts/settings.json`

### Project-level settings (team)

Share TTS configuration with your team by committing to git:

```bash
/tts-plugin:enable --project
/tts-plugin:configure --project
```

Settings saved to: `.claude/plugins/tts/settings.json`

**Add to .gitignore:**
```
# Keep local TTS overrides private
.claude/plugins/tts/settings.local.json
```

### Local-level settings (machine-specific)

Override project/user settings on your machine only:

```bash
/tts-plugin:enable --local
/tts-plugin:configure --local
```

Settings saved to: `.claude/plugins/tts/settings.local.json` (not committed to git)

## Configuration Priority

Settings are merged with this priority (highest to lowest):

1. **Local** (.claude/plugins/tts/settings.local.json)
2. **Project** (.claude/plugins/tts/settings.json)
3. **User** (~/.claude/plugins/tts/settings.json)
4. **Defaults** (shipped with plugin)

Example: If you have:
- User sets voice to "af_bella"
- Project sets voice to "af_sarah" and speed to 1.5
- Local sets speed to 1.8

Result:
- Voice: "af_sarah" (from project, overrides user)
- Speed: 1.8 (from local, overrides project)
- All other settings: from user or defaults

## Troubleshooting

### Migration command not found

Make sure you're running TTS plugin v0.2.0 or later:
```bash
cat ~/.claude/plugins/tts-plugin/plugin.json | grep version
```

### Settings not taking effect

1. Restart Claude Code after changing settings
2. Verify settings file syntax (must be valid JSON):
   ```bash
   jq . ~/.claude/plugins/tts/settings.json
   ```
3. Check for typos in JSON paths

### Can't find settings.json

Settings files may not exist until you configure them. Use commands to create:
```bash
/tts-plugin:configure
```

Or copy from defaults manually:
```bash
mkdir -p ~/.claude/plugins/tts
cp ~/.claude/plugins/tts-plugin/settings.default.json ~/.claude/plugins/tts/settings.json
```

### jq not found error

The plugin requires `jq` for JSON parsing. Install it:

**macOS:**
```bash
brew install jq
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install jq
```

**Linux (RHEL/Fedora):**
```bash
sudo yum install jq
```

### Want to rollback to .env

If you need to rollback:

1. Restore your backup:
   ```bash
   mv ~/.claude/tts-plugin.env.backup ~/.claude/tts-plugin.env
   ```

2. Remove settings.json:
   ```bash
   rm ~/.claude/plugins/tts/settings.json
   ```

3. Downgrade to TTS plugin v0.1.x

## New Features Enabled by settings.json

### Team Collaboration

Project-level settings allow teams to share TTS configuration:

```json
# .claude/plugins/tts/settings.json (committed to git)
{
  "enabled": {
    "global": true,
    "pretool": false
  },
  "voice": {
    "name": "af_sarah",
    "language": "en-gb",
    "speed": 1.3
  }
}
```

Team members automatically get these settings, but can override locally.

### Per-Project Customization

Different projects can have different TTS settings:

```bash
# In project A
cd ~/projects/projectA
/tts-plugin:configure --project
# Set voice to af_bella, speed 1.0

# In project B
cd ~/projects/projectB
/tts-plugin:configure --project
# Set voice to af_sarah, speed 1.5
```

Each project maintains its own settings.

### Machine-Specific Overrides

Override settings on specific machines without affecting committed files:

```bash
# On your laptop (prefer slower speed)
/tts-plugin:configure --local
# Set speed to 1.0

# On your desktop (prefer faster speed)
/tts-plugin:configure --local
# Set speed to 1.8
```

`.local.json` files are in .gitignore and won't be committed.

## Getting Help

- Run `/tts-plugin:test` to verify configuration
- Run `/tts-plugin:configure` for interactive setup
- Check README.md for full documentation
- Report issues: https://github.com/colings86/tts-plugin/issues
