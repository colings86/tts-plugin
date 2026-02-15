# TTS Plugin for Claude Code

Text-to-speech system for Claude Code that reads Claude's responses aloud using [kokoro-tts](https://github.com/thewh1teagle/kokoro).

## Features

- 🔊 **Automatic TTS**: Speaks Claude's responses when they complete
- ⚡ **Real-time feedback**: Optional TTS during tool execution
- 🎯 **Smart extraction**: Extracts TTS-optimized "## TTS Response" sections
- 🎛️ **Configurable**: Customize voice, language, speed, and behavior
- 🔇 **Interrupt handling**: Automatically stops playback when you submit a new prompt
- 📝 **Session tracking**: Prevents re-speaking already-heard messages

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

The plugin uses a `.env` file located at `~/.claude/tts-plugin.env` for configuration.

### Creating Configuration

Use the interactive configure command:
```bash
/tts-plugin:configure
```

Or manually create `~/.claude/tts-plugin.env` (see `.env.example` for template).

### Available Settings

See `.env.example` for all available configuration options including:
- Voice selection (af_bella, af_sarah, etc.)
- Language (en-gb, en-us, etc.)
- Speech speed (0.5-2.0)
- Enable/disable hooks
- TTS section extraction
- Maximum text length

## Usage

### Commands

- `/tts-plugin:enable` - Enable TTS (persistent or session-only)
- `/tts-plugin:disable` - Disable TTS (persistent or session-only)
- `/tts-plugin:configure` - Interactive configuration wizard
- `/tts-plugin:test` - Test TTS with sample or custom text

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
# Enable for current session only
/tts-plugin:enable

# Enable persistently (updates .env)
/tts-plugin:enable --persistent

# Disable for current session
/tts-plugin:disable

# Disable persistently
/tts-plugin:disable --persistent
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
2. Check TTS is enabled: `/tts-plugin:configure` (check TTS_ENABLED)
3. Test manually: `/tts-plugin:test`
4. Check logs: `~/.local/state/claude-tts/logs/`

### Wrong Voice or Speed

Use the configure command to update settings:
```bash
/tts-plugin:configure
```

### TTS Too Verbose

Disable the PreToolUse hook in configuration:
```bash
/tts-plugin:configure
# Set TTS_PRETOOL_ENABLED=false
```

## Development

### Directory Structure

```
tts-plugin/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── commands/                 # User commands
│   ├── enable.md
│   ├── disable.md
│   ├── configure.md
│   └── test.md
├── skills/                   # Auto-activating skills
│   └── tts-setup/
│       └── SKILL.md
├── hooks/                    # Event handlers
│   ├── hooks.json           # Hook configuration
│   └── scripts/             # Hook scripts
├── scripts/                  # Shared utilities
│   ├── tts-common.sh        # Core TTS library
│   └── tts-instruction-template.txt
├── .env.example             # Configuration template
└── README.md
```

## License

MIT

## Contributing

Issues and pull requests welcome at https://github.com/colings86/tts-plugin
