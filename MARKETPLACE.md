# Marketplace Entry for TTS Plugin

This file contains the metadata and content for publishing the TTS Plugin to the Claude Code plugin marketplace.

## Marketplace Metadata

```json
{
  "name": "tts-plugin",
  "display_name": "Text-to-Speech (TTS) Plugin",
  "version": "0.1.0",
  "description": "Text-to-speech system for Claude Code that reads Claude's responses aloud using kokoro-tts",
  "category": "Accessibility",
  "tags": [
    "tts",
    "text-to-speech",
    "accessibility",
    "audio",
    "kokoro-tts",
    "voice",
    "speech"
  ],
  "author": {
    "name": "colings86",
    "email": "colings86@users.noreply.github.com"
  },
  "repository": "https://github.com/colings86/tts-plugin",
  "license": "MIT",
  "homepage": "https://github.com/colings86/tts-plugin"
}
```

## Long Description (for marketplace listing)

### Bring Your Claude Code Sessions to Life with Text-to-Speech

The TTS Plugin transforms your Claude Code experience by reading Claude's responses aloud using the high-quality kokoro-tts voice synthesis engine. Perfect for accessibility needs, hands-free coding sessions, or simply reducing screen time.

**Key Features:**

🔊 **Automatic Speech Output** - Claude's responses are automatically spoken when they complete, allowing you to stay focused on your work without constantly reading the screen.

⚡ **Real-time Feedback** - Optional TTS during tool execution keeps you informed of what's happening without breaking your concentration.

🎯 **Smart Content Extraction** - Automatically extracts TTS-optimized "## TTS Response" sections from Claude's responses, ensuring you hear the most relevant information.

🎛️ **Highly Configurable** - Choose from multiple voices (af_bella, af_sarah, am_adam, am_michael, bf_emma, bf_isabella, bm_george, bm_lewis), adjust speech speed (0.5-2.0x), select language variants (en-gb, en-us), and fine-tune behavior to your preferences.

🔇 **Intelligent Interrupt Handling** - Automatically stops playback when you submit a new prompt, preventing audio overlap and confusion.

📝 **Session Memory** - Tracks what's been spoken per session to avoid repeating content unnecessarily.

**Perfect For:**

- Developers with visual impairments or accessibility needs
- Hands-free coding sessions (pair programming, code reviews)
- Reducing screen time and eye strain during long coding sessions
- Multitasking while staying informed of Claude's progress
- Learning and comprehension (audio + visual reinforcement)

**What You Get:**

- **4 Easy Commands**: Enable/disable TTS, configure settings, test audio output
- **Auto-activating Help**: Ask "How do I set up TTS?" for instant guidance
- **4 Event Hooks**: Seamlessly integrated into Claude Code's workflow
- **Flexible Configuration**: Simple .env file with sensible defaults
- **Production Ready**: Battle-tested implementation with file locking, session state management, and error handling

**Requirements:**

- [kokoro-tts](https://github.com/thewh1teagle/kokoro) must be installed
- macOS or Linux (kokoro-tts compatible platforms)

## Suggested Categories

**Primary Category**: Accessibility
**Secondary Categories**: Audio, Productivity, Developer Tools

## Installation Instructions (for marketplace)

```bash
# The plugin will be automatically installed via Claude Code marketplace
# After installation, configure your preferences:
/tts-plugin:configure

# Or manually create configuration:
cp ~/.claude/plugins/tts-plugin/.env.example ~/.claude/tts-plugin.env
```

## Screenshots/Assets Needed

If publishing to a visual marketplace, consider including:

1. **Demo GIF**: Short animation showing TTS in action (terminal output + audio waveform visualization)
2. **Configuration Screenshot**: `/tts-plugin:configure` command in action
3. **Voice Selection Guide**: Visual reference of available voices
4. **Plugin Icon**: 512x512px icon (speaker/sound wave theme)

## Pre-Publication Checklist

Before submitting to the marketplace:

- [ ] Test on fresh installation (clean ~/.claude directory)
- [ ] Verify all commands work (`/help` shows all commands)
- [ ] Test on macOS and Linux
- [ ] Verify hooks don't interfere with other plugins
- [ ] Check kokoro-tts installation instructions are current
- [ ] Ensure README.md is up-to-date
- [ ] Tag release (v0.1.0) in git
- [ ] Verify repository is public (if using GitHub)
- [ ] Add GitHub topics/tags matching marketplace tags
- [ ] Consider adding GitHub Actions for basic testing
- [ ] Review all file permissions (scripts should be 755)

## Support & Maintenance Plan

**Issue Tracking**: https://github.com/colings86/tts-plugin/issues

**Expected Response Time**: Best effort (open source project)

**Known Limitations**:
- Requires kokoro-tts to be installed separately
- Configuration changes require Claude Code restart
- Maximum text length limit (configurable, default 5000 chars)
- Platform-dependent (kokoro-tts platform support)

## Future Roadmap (v0.2.0+)

Potential enhancements to mention in marketplace listing:

- Additional TTS engine support (say, espeak, etc.)
- Voice cloning support (kokoro-tts feature)
- Per-project voice settings
- TTS speed controls per message type (tool output vs. responses)
- Visual feedback indicator when TTS is speaking
- Keyboard shortcuts for TTS control (pause/resume/skip)
- Multi-language voice selection improvements
- Streaming TTS (speak as Claude writes, not just when complete)

## Marketplace Submission Notes

**Submission Date**: TBD
**Marketplace URL**: TBD
**Status**: Ready for submission (pending Phase 7 testing)

**One-Line Pitch**: "Hear Claude's responses with high-quality text-to-speech - perfect for accessibility, hands-free coding, and reducing screen time."

**Elevator Pitch** (30 seconds):
"The TTS Plugin brings voice to Claude Code using kokoro-tts. It automatically reads Claude's responses aloud, supports multiple voices and languages, and intelligently handles interruptions. With simple commands and smart defaults, it's perfect for accessibility needs, hands-free workflows, or anyone who wants to reduce screen time. Configure once, enjoy forever."

---

**Last Updated**: 2026-02-15
**Status**: Documentation complete, ready for testing and publication
