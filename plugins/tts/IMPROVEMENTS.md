# TTS Plugin - Potential Improvements & Enhancements

This document outlines potential improvements and enhancements for future versions of the TTS Plugin.

**Current Version**: v0.1.14
**Last Updated**: 2026-02-15

---

## ✅ Completed Improvements (v0.1.9 → v0.1.14)

These improvements were implemented during testing and refinement:

### Bug Fixes
1. ✅ **Lock Race Condition** (v0.1.5) - Fixed hooks to wait for locks instead of skipping
2. ✅ **Subshell Variable Scope** (v0.1.7-0.1.8) - UUID tracking using temp files
3. ✅ **Duplicate Messages** (v0.1.8) - State properly updated between hooks
4. ✅ **"No Response Requested" Filtering** (v0.1.9) - Skip local command responses
5. ✅ **Exit Cleanup** (v0.1.10) - TTS processes killed when Claude Code exits
6. ✅ **Instruction Injection** (v0.1.10) - UserPromptSubmit uses additionalContext
7. ✅ **Markdown Formatting in Speech** (v0.1.11-0.1.14) - Plain text TTS with visual distinction

### UX Improvements
8. ✅ **TTS Response Visual Distinction** (v0.1.14) - Emoji heading, horizontal rule, italic formatting
9. ✅ **Plain Text Speech** (v0.1.11) - No markdown artifacts (asterisks, emojis) in audio
10. ✅ **Both Sections Required** (v0.1.12) - Always provide formatted + TTS versions

### Lessons Learned
- **HTML Collapsible Blocks**: `<details>` and `<summary>` tags are not supported in Claude Code's markdown renderer (tested v0.1.13, reverted v0.1.14)
- **Bash Subshell Scope**: Variables set inside `{ } | command` blocks don't persist - use temp files for state tracking
- **Hook APIs**: UserPromptSubmit hooks use `additionalContext` field, not `.message` modification
- **File Locking**: Use `flock -w` (wait) instead of `flock -n` (non-blocking) to prevent race conditions

---

## Priority Matrix

| Priority | Effort | Description |
|----------|--------|-------------|
| 🔴 High | Low | Quick wins that significantly improve UX |
| 🟡 Medium | Medium | Valuable features requiring moderate work |
| 🟢 Low | High | Nice-to-have features requiring significant effort |

---

## v0.1.1 - Quick Wins (Post-Testing Fixes)

### 🔴 High Priority, Low Effort

1. **Add Known Limitations to README**
   - Document restart requirement for .env changes
   - Note platform dependencies (kokoro-tts support)
   - Mention max text length limits
   - **Effort**: 15 minutes

2. **Add Changelog File**
   - Create CHANGELOG.md following keep-a-changelog format
   - Track changes between versions
   - **Effort**: 15 minutes

3. **Add Validation Script**
   - Simple `scripts/validate-install.sh` to check:
     - kokoro-tts is installed
     - .env file exists (or create from template)
     - File permissions are correct
   - **Effort**: 30 minutes

4. **Add `/tts-plugin:status` Command**
   - Show current configuration
   - Display TTS_ENABLED state
   - Show which hooks are active
   - Check if kokoro-tts is available
   - **Effort**: 30 minutes

### 🟡 Medium Priority, Low Effort

5. **Enhanced Error Messages**
   - More specific error messages in hooks
   - Suggest fixes (e.g., "kokoro-tts not found, install from...")
   - Include relevant config values in errors
   - **Effort**: 1 hour

6. **Add Voice Preview in Configure**
   - Play sample for each voice during `/tts-plugin:configure`
   - Help users choose voice they prefer
   - **Effort**: 1 hour

7. **Add Debug Mode**
   - Add TTS_DEBUG setting to .env
   - Verbose logging when enabled
   - Show exact kokoro-tts commands being run
   - **Effort**: 1 hour

---

## v0.2.0 - User Experience Improvements

### 🔴 High Priority, Medium Effort

8. **Keyboard Shortcuts**
   - Add commands for:
     - Pause/Resume TTS: `/tts-plugin:pause`, `/tts-plugin:resume`
     - Skip current TTS: `/tts-plugin:skip`
     - Toggle TTS quickly: `/tts-plugin:toggle`
   - **Effort**: 2-3 hours
   - **Value**: Significantly improves hands-free workflow

9. **Visual Feedback**
   - Add status indicator when TTS is speaking
   - Could use status line or notification
   - Show current voice/speed in status
   - **Effort**: 2-3 hours
   - **Value**: Better awareness of TTS state

10. **Per-Project Settings**
    - Allow `.claude-plugin/tts-plugin.local.md` to override global settings
    - Different projects could use different voices/speeds
    - **Effort**: 2-3 hours
    - **Value**: Flexibility for different use cases

### 🟡 Medium Priority, Medium Effort

11. **Alternative TTS Response Presentation**
    - Explore visual collapsing alternatives (HTML details/summary doesn't work)
    - Consider: minimized font, subtle background color, or collapsible via Claude Code UI extension
    - Goal: Keep TTS Response visible but visually de-emphasized
    - **Effort**: 2-3 hours (requires Claude Code UI research)
    - **Value**: Cleaner response presentation without losing TTS content

12. **Smart Speed Adjustment**
    - Automatically slow down for code blocks
    - Speed up for natural language
    - Different speeds for errors vs. success messages
    - **Effort**: 3-4 hours
    - **Value**: Better comprehension of different content types

13. **TTS Queue Management**
    - Queue multiple messages instead of interrupting
    - Allow skipping through queue
    - Configurable queue behavior (interrupt vs. queue)
    - **Effort**: 4-5 hours
    - **Value**: Better handling of rapid responses

14. **Enhanced Content Filtering**
    - ✅ Already filters "No response requested"
    - Add: Skip TTS for specific patterns (e.g., long JSON output, code dumps)
    - Add: Configurable skip patterns in .env (regex support)
    - Add: Smart detection of "un-speakable" content (base64, hex dumps)
    - Add: Min/max length thresholds per message type
    - **Effort**: 3-4 hours
    - **Value**: Avoids frustrating TTS of raw data

---

## v0.3.0 - Advanced Features

### 🟡 Medium Priority, High Effort

15. **Multi-Engine Support**
    - Support additional TTS engines:
      - macOS `say` (native on macOS)
      - Linux `espeak` (lightweight, widely available)
      - Google Cloud TTS (cloud-based, high quality)
    - Auto-detect available engines
    - Fallback chain: kokoro → say → espeak
    - **Effort**: 8-10 hours
    - **Value**: Works out-of-box on more systems

16. **Streaming TTS**
    - Speak as Claude types, not just when complete
    - Real-time audio feedback during long responses
    - Requires monitoring transcript changes in real-time
    - **Effort**: 10-12 hours
    - **Value**: Dramatically faster perception of responses

17. **Voice Cloning**
    - Leverage kokoro-tts voice cloning features
    - Allow users to create custom voices
    - Document voice file creation process
    - **Effort**: 6-8 hours
    - **Value**: Personalization, fun factor

### 🟢 Low Priority, High Effort

18. **TTS Rate Limiting**
    - Skip TTS if responses are too frequent (e.g., <2s apart)
    - Prevents audio spam during rapid tool execution
    - Configurable threshold
    - **Effort**: 4-5 hours
    - **Value**: Reduces annoyance in verbose sessions

19. **Multi-Language Auto-Detection**
    - Detect language of response
    - Automatically switch TTS_LANG
    - Requires language detection library
    - **Effort**: 8-10 hours
    - **Value**: Better for multilingual users

20. **Audio Effects**
    - Add audio effects (e.g., different pitch for errors)
    - Sound effects for events (tool start/end)
    - Configurable effect library
    - **Effort**: 10-12 hours
    - **Value**: Enhanced audio feedback, accessibility

---

## v1.0.0 - Enterprise Features

### 🟢 Low Priority, Very High Effort

21. **Web Dashboard**
    - Visual configuration interface
    - Real-time TTS preview
    - Voice library browser
    - TTS history viewer
    - **Effort**: 20-30 hours
    - **Value**: Greatly improved UX for non-technical users

22. **Analytics & Insights**
    - Track TTS usage statistics
    - Voice preference analytics
    - Most-spoken phrases
    - Usage patterns
    - **Effort**: 15-20 hours
    - **Value**: Interesting insights, not critical

23. **Cloud Sync**
    - Sync .env settings across machines
    - Cloud-based voice preferences
    - Requires cloud backend
    - **Effort**: 30-40 hours
    - **Value**: Convenience for multi-device users

---

## Testing & Quality Improvements

### Recommended (All Priorities)

24. **Automated Testing**
    - Unit tests for tts-common.sh functions
    - Integration tests for hooks
    - CI/CD with GitHub Actions
    - **Effort**: 10-15 hours
    - **Value**: Prevents regressions, increases confidence

25. **Performance Profiling**
    - Measure hook execution time
    - Optimize slow paths
    - Reduce latency between response and TTS
    - **Effort**: 4-6 hours
    - **Value**: Better responsiveness

26. **Cross-Platform Testing**
    - Test on macOS (Intel + Apple Silicon)
    - Test on Linux (Ubuntu, Debian, Arch)
    - Document platform-specific issues
    - **Effort**: 6-8 hours
    - **Value**: Wider compatibility

---

## Documentation Improvements

### Quick Wins

27. **Video Walkthrough**
    - 3-5 minute demo video
    - Show installation, configuration, usage
    - Upload to YouTube, link from README
    - **Effort**: 2-3 hours
    - **Value**: Dramatically improves onboarding

28. **FAQ Section**
    - Expand troubleshooting into detailed FAQ
    - Common issues from GitHub issues
    - Link from README
    - **Effort**: 1-2 hours
    - **Value**: Reduces support burden

29. **Voice Comparison Table**
    - Create table comparing all voices
    - Sample audio files for each voice
    - Personality descriptions (e.g., "af_bella: warm, clear")
    - **Effort**: 2-3 hours
    - **Value**: Helps users choose voice

---

## Community & Ecosystem

### Future Considerations

30. **Plugin API for Extensions**
    - Allow other plugins to trigger TTS
    - Expose TTS functions as SDK
    - Enable TTS from custom commands/agents
    - **Effort**: 8-10 hours
    - **Value**: Ecosystem growth

31. **Voice Pack Marketplace**
    - Repository of community voice files
    - Easy voice installation
    - Voice ratings and reviews
    - **Effort**: 15-20 hours
    - **Value**: Community engagement

32. **Integrate with Claude Code UI**
    - Native TTS controls in Claude Code UI
    - Visual voice selector
    - Requires Claude Code core changes
    - **Effort**: 30-40+ hours (requires coordination with Claude Code team)
    - **Value**: First-class integration

---

## Prioritized Roadmap Suggestion

### v0.1.15 (Bug Fixes & Polish) - 1-2 days
- #1: Add Known Limitations to README
- #2: Add Changelog File
- #4: Add `/tts-plugin:status` Command
- #5: Enhanced Error Messages

### v0.2.0 (UX Improvements) - 1 week
- #8: Keyboard Shortcuts (pause, resume, skip, toggle)
- #9: Visual Feedback (status indicator)
- #10: Per-Project Settings
- #11: Alternative TTS Response Presentation
- #14: Enhanced Content Filtering (expand beyond "No response requested")

### v0.3.0 (Advanced Features) - 2-3 weeks
- #15: Multi-Engine Support (say, espeak)
- #16: Streaming TTS
- #12: Smart Speed Adjustment

### v1.0.0 (Production Release) - 1-2 months
- #24: Automated Testing
- #25: Performance Profiling
- #26: Cross-Platform Testing
- #27: Video Walkthrough
- Selected features from v0.3.0 based on user feedback

---

## How to Prioritize

**Consider these factors when choosing improvements**:

1. **User Requests**: What are users actually asking for?
2. **Pain Points**: What's causing the most friction?
3. **Quick Wins**: What provides high value for low effort?
4. **Dependencies**: What's required for other features?
5. **Maintenance**: What reduces long-term maintenance burden?

**Suggested approach**:
1. ✅ Complete Phase 7 (Testing) - Done at v0.1.14
2. ✅ Fix critical bugs found - 7 bugs fixed during testing
3. Tag v0.1.14 as stable release
4. Gather user feedback from wider testing
5. Prioritize v0.1.15 improvements based on feedback
6. Plan v0.2.0 based on most-requested features

---

**Last Updated**: 2026-02-15
**Status**: Suggestions for post-v0.1.14 development (Phase 7 testing complete)
