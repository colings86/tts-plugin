# TTS Plugin for Claude Code

Text-to-speech system for Claude Code that reads Claude's responses aloud using [kokoro-tts](https://github.com/thewh1teagle/kokoro).

## Features

- 🔊 **Automatic TTS**: Speaks Claude's responses when they complete
- 🛠️ **Tool-specific TTS**: Extensible system for speaking tool outputs (e.g., AskUserQuestion)
- ⚡ **Real-time feedback**: Optional TTS during tool execution
- 🎯 **Smart extraction**: Extracts TTS-optimized "## TTS Response" sections
- 🎛️ **Configurable**: Customize voice, language, speed, and behavior
- 🔇 **Interrupt handling**: Automatically stops playback when you submit a new prompt
- 📝 **Session tracking**: Prevents re-speaking already-heard messages

## Tool TTS Support

The TTS plugin can speak outputs from specific tools, not just Claude's text responses. This is implemented using an extensible **PreToolUse hook** system with tool-specific handlers.

### Supported Tools

- **AskUserQuestion** - Speaks questions and options when Claude asks for input (before you answer!)

### How It Works

1. PreToolUse hook fires when a tool is about to be called
2. Handler registry checks if a handler exists for that tool
3. Tool-specific handler extracts and formats the relevant content
4. Text is spoken asynchronously (doesn't block the tool)

### Configuration

Enable/disable tool TTS globally:

```json
{
  "tools": {
    "speak": true
  }
}
```

Configure specific tools:

```json
{
  "tools": {
    "AskUserQuestion": {
      "speak": true,
      "format": "sentence"
    }
  }
}
```

**Format options for AskUserQuestion:**
- `"sentence"` - "Your options are: Option A, Option B, or Option C" (default)
- `"list"` - "Option 1: Option A. Option 2: Option B. Option 3: Option C."
- `"simple"` - "Option A. Option B. Option C."

### Adding New Tool Handlers

The system is designed to be easily extensible. To add TTS support for a new tool:

1. Create a handler file in `scripts/tts-tool-handlers/`
2. Implement the `handle_tool_output()` function
3. Add configuration to `settings.default.json`

See [docs/TOOL_HANDLERS.md](docs/TOOL_HANDLERS.md) for detailed guide and examples.

**Future tool ideas:**
- WebSearch - Read search results summary
- Bash - Speak command output (opt-in)
- Task - Announce subagent completion
- NotebookRead - Read cell outputs aloud

## Prerequisites

This plugin requires [kokoro-tts](https://github.com/thewh1teagle/kokoro) to be installed:

```bash
# Install kokoro-tts (follow official installation guide)
# Verify installation
kokoro-tts --help
```

## Installation

1. Clone or copy this plugin to your Claude Code plugins directory:
   ```bash
   git clone https://github.com/colings86/tts-plugin ~/.claude/plugins/tts-plugin
   ```

2. Enable the plugin in Claude Code settings or via:
   ```bash
   cc --plugin-dir ~/.claude/plugins/tts-plugin
   ```

3. Configure TTS settings (optional):
   ```bash
   # Interactive configuration wizard
   /tts-plugin:configure
   ```

## Configuration

The plugin uses a hierarchical `settings.json` configuration system that supports user-level, project-level, and local-level settings.

### Configuration Hierarchy

Settings are loaded and merged in this priority order (highest to lowest):

1. **Local** (`.claude/plugins/tts/settings.local.json`) - Machine-specific overrides, not committed to git
2. **Project** (`.claude/plugins/tts/settings.json`) - Team settings, committed to git
3. **User** (`~/.claude/plugins/tts/settings.json`) - Personal defaults across all projects
4. **Defaults** (shipped with plugin) - Base configuration

This allows you to:
- Set personal preferences globally
- Share team settings via git
- Override settings locally without affecting committed files

### Quick Start

Use the interactive configure command:
```bash
/tts-plugin:configure
```

This wizard will:
1. Ask which configuration level to modify (user/project/local)
2. Show current merged settings
3. Guide you through Quick Setup or Advanced Setup
4. Save settings to the appropriate file

### Configuration Levels

#### User-Level (Global)
Personal defaults that apply to all projects:
```bash
/tts-plugin:configure --user
```
Location: `~/.claude/plugins/tts/settings.json`

#### Project-Level (Team)
Settings for a specific project, shared with your team via git:
```bash
/tts-plugin:configure --project
```
Location: `.claude/plugins/tts/settings.json`

**Recommended .gitignore entry:**
```
# Keep local TTS overrides private
.claude/plugins/tts/settings.local.json
```

#### Local-Level (Machine-Specific)
Override project/user settings on your machine only:
```bash
/tts-plugin:configure --local
```
Location: `.claude/plugins/tts/settings.local.json` (automatically ignored by git)

### Configuration Format

Settings are stored in JSON format with logical grouping:

```json
{
  "enabled": {
    "global": true,
    "pretool": true
  },
  "voice": {
    "name": "af_bella",
    "language": "en-gb",
    "speed": 1.3
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
  },
  "tools": {
    "speak": true,
    "AskUserQuestion": {
      "speak": true,
      "format": "sentence",
      "pause": 0.5
    }
  }
}
```

### Available Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `enabled.global` | boolean | true | Global TTS enable/disable (affects all hooks) |
| `enabled.pretool` | boolean | true | PreToolUse hook enable/disable |
| `voice.name` | string | "af_bella" | Voice to use (run `kokoro-tts --help-voices`) |
| `voice.language` | string | "en-gb" | Language code (run `kokoro-tts --help-languages`) |
| `voice.speed` | number | 1.3 | Speech speed (0.5-2.0, where 1.0 is normal) |
| `models.model` | string | (path) | Path to kokoro-tts model file |
| `models.voices` | string | (path) | Path to kokoro-tts voices file |
| `processing.useTtsSection` | boolean | true | Extract "## TTS Response" section if present |
| `processing.maxLength` | number | 5000 | Maximum characters to speak per message |
| `paths.stateDir` | string | (path) | Directory for session state files |
| `paths.logDir` | string | (path) | Directory for TTS log files |
| `tools.speak` | boolean | true | Global enable/disable for all tool TTS |
| `tools.AskUserQuestion.speak` | boolean | true | Enable TTS for AskUserQuestion tool |
| `tools.AskUserQuestion.format` | string | "sentence" | Format for options (sentence/list/simple) |
| `tools.AskUserQuestion.pause` | number | 0.5 | Pause before speaking (reserved for future use) |

### Migrating from .env

If you have an existing `.env` configuration file, migrate automatically:
```bash
/tts-plugin:migrate
```

This will:
- Convert your `.env` to `settings.json`
- Back up the original to `.env.backup`
- Show you what was migrated

See [MIGRATION.md](MIGRATION.md) for detailed migration guide.

## Usage

### Commands

- `/tts-plugin:enable [--user|--project|--local]` - Enable TTS at specified level
- `/tts-plugin:disable [--user|--project|--local]` - Disable TTS at specified level
- `/tts-plugin:configure [--user|--project|--local]` - Interactive configuration wizard
- `/tts-plugin:test [message] [--voice VOICE] [--speed SPEED] [--lang LANG]` - Test TTS
- `/tts-plugin:migrate` - Migrate from legacy .env to settings.json

### Skills

- **tts-setup** - Automatically activates when you ask about TTS setup, configuration, or troubleshooting

### How It Works

1. **UserPromptSubmit Hook**: When you submit a prompt, the plugin:
   - Interrupts any ongoing TTS playback
   - Adds a request for Claude to include a "## TTS Response" section

2. **Stop Hook**: When Claude finishes responding:
   - Extracts new messages from the transcript
   - Looks for "## TTS Response" section (if configured)
   - Speaks the text using kokoro-tts
   - Updates session state to track what's been spoken

3. **PreToolUse Hook** (optional): Before each tool executes:
   - Speaks any new text that appeared
   - Provides real-time audio feedback during execution

4. **SessionEnd Hook**: When session ends:
   - Cleans up session state files

## Examples

### Test TTS
```bash
# Use default test text
/tts-plugin:test

# Custom text
/tts-plugin:test "Hello, this is a custom message"

# Test with different voice
/tts-plugin:test "Testing voice" --voice af_sarah

# Test with different speed
/tts-plugin:test "Testing speed" --speed 1.5
```

### Enable/Disable TTS
```bash
# Enable at user level (default, all projects)
/tts-plugin:enable
/tts-plugin:enable --user

# Enable at project level (committed to git, shared with team)
/tts-plugin:enable --project

# Enable at local level (this machine only, not committed)
/tts-plugin:enable --local

# Disable at user level
/tts-plugin:disable
/tts-plugin:disable --user

# Disable at project level
/tts-plugin:disable --project

# Disable at local level
/tts-plugin:disable --local
```

### Get Help
Just ask Claude:
- "How do I set up TTS?"
- "How can I change the TTS voice?"
- "TTS isn't working, help me troubleshoot"

The `tts-setup` skill will automatically activate with relevant guidance.

## Troubleshooting

### TTS Not Speaking

1. Verify kokoro-tts is installed: `kokoro-tts --help`
2. Check TTS is enabled: `/tts-plugin:configure` (check `enabled.global`)
3. Test manually: `/tts-plugin:test`
4. Check logs: `~/.local/state/claude-tts/logs/`
5. Verify settings are valid JSON: `jq . ~/.claude/plugins/tts/settings.json`

### Wrong Voice or Speed

Use the configure command to update settings:
```bash
/tts-plugin:configure
```

Or manually edit your settings file:
```bash
# Edit user-level settings
vim ~/.claude/plugins/tts/settings.json

# Edit project-level settings
vim .claude/plugins/tts/settings.json
```

### TTS Too Verbose

Disable the PreToolUse hook in configuration:
```bash
/tts-plugin:configure
# Set enabled.pretool to false
```

### Configuration Not Taking Effect

1. Restart Claude Code after changing settings
2. Check which level settings are coming from - local overrides project, project overrides user
3. Verify JSON syntax is valid: `jq . <settings-file>`

### Migration Issues

If you're migrating from .env and having issues:
```bash
# Automatic migration
/tts-plugin:migrate

# Or see detailed migration guide
cat ~/.claude/plugins/tts-plugin/MIGRATION.md
```

## Development

### Directory Structure

```
tts-plugin/
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest
├── commands/                      # User commands
│   ├── enable.md
│   ├── disable.md
│   ├── configure.md
│   ├── test.md
│   └── migrate.md                # NEW: Migration from .env
├── skills/                        # Auto-activating skills
│   └── tts-setup/
│       └── SKILL.md
├── hooks/                         # Event handlers
│   ├── hooks.json                # Hook configuration
│   └── scripts/                  # Hook scripts
├── scripts/                       # Shared utilities
│   ├── tts-common.sh             # Core TTS library (JSON-based config)
│   ├── tts-instruction-template.txt
│   └── tts-tool-handlers/        # Tool-specific TTS handlers
│       ├── handler-registry.sh   # Handler discovery/dispatch
│       └── ask-user-question-handler.sh  # AskUserQuestion TTS logic
├── docs/                          # Documentation
│   └── TOOL_HANDLERS.md          # Guide for creating tool handlers
├── settings.default.json         # NEW: Default settings (shipped)
├── MIGRATION.md                  # NEW: Migration guide
├── .env.example                  # DEPRECATED: Legacy config template
└── README.md
```

### Configuration Files (User's Machine)

```
~/.claude/plugins/tts/
└── settings.json                 # User-level settings

<project-root>/.claude/plugins/tts/
├── settings.json                 # Project-level settings (committed)
└── settings.local.json           # Local overrides (not committed)
```

## License

MIT

## Contributing

Issues and pull requests welcome at https://github.com/colings86/tts-plugin
