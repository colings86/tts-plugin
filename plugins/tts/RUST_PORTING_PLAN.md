# Rust Porting Plan: TTS Plugin Phase 1

## Context

This plan outlines the step-by-step approach to port the TTS plugin from Bash to Rust (Phase 1: External CLI architecture). The current implementation is a 522-line Bash script (`tts-common.sh`) that has become difficult to maintain.

**Goal**: Replace Bash with Rust while maintaining the current external `kokoro-tts` CLI architecture, gaining benefits in maintainability, type safety, and performance while preserving MIT licensing.

**Timeline**: 2-3 days (broken into ~15 incremental tasks)

**Key Decisions**:
- Phase 1 only (external CLI, not ONNX integration)
- JSON-based structured state (not plain text)
- No backward compatibility with Bash state files (clean break)
- Target platforms: macOS (arm64/x86_64), Linux (x86_64/arm64)

## Critical Files

**Current Implementation** (to be replaced):
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/scripts/tts-common.sh` (522 lines)
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/scripts/tts-tool-handlers/handler-registry.sh`
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/scripts/tts-tool-handlers/ask-user-question-handler.sh`

**Hook Scripts** (to be updated):
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/hooks/scripts/tts-hook.sh`
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/hooks/scripts/tts-pretooluse-hook.sh`
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/hooks/scripts/tts-interrupt.sh`
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/hooks/scripts/tts-session-stopped.sh`

**Configuration**:
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/settings.default.json`

**New Rust Implementation** (to be created):
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/rust/` (entire Rust project)

**Output Plan Document** (final deliverable):
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/RUST_PORTING_PLAN.md`

---

## Incremental Tasks (Sequential Execution)

### Task 1: Initialize Rust Project Structure

**Goal**: Create the basic Rust project with initial directory structure and dependencies.

**Actions**:
1. Create `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/rust/` directory
2. Run `cargo init --name tts` in the rust/ directory
3. Update `Cargo.toml` with initial dependencies:
   - `serde = { version = "1.0", features = ["derive"] }`
   - `serde_json = "1.0"`
   - `anyhow = "1.0"` (error handling)
   - `clap = { version = "4.0", features = ["derive"] }` (CLI argument parsing)
4. Create module structure:
   - `src/main.rs` (entry point)
   - `src/config/mod.rs`
   - `src/transcript/mod.rs`
   - `src/tts/mod.rs`
   - `src/handlers/mod.rs`
   - `src/state/mod.rs`

**Verification**:
- `cargo build` succeeds
- Directory structure matches planned architecture
- Dependencies resolve without errors

**Estimated Time**: 15 minutes

---

### Task 2: Implement Configuration Types and Defaults

**Goal**: Create type-safe configuration structs matching `settings.default.json` schema.

**Actions**:
1. Create `src/config/types.rs` with structs:
   - `Config` (root)
   - `EnabledSettings`
   - `VoiceSettings`
   - `ModelPaths`
   - `ProcessingSettings`
   - `PathSettings`
   - `ToolSettings`
   - `AskUserQuestionSettings`
2. Derive `Serialize`, `Deserialize` for all structs
3. Create `src/config/defaults.rs` with default values matching `settings.default.json`
4. Implement environment variable expansion for paths (`$HOME`, `$CLAUDE_PROJECT_ROOT`)

**Reference**: `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/settings.default.json`

**Verification**:
- All fields from settings.default.json are represented
- Default config can be serialized/deserialized
- Path expansion works for `$HOME` variables

**Estimated Time**: 30 minutes

---

### Task 3: Implement Hierarchical Configuration Loading

**Goal**: Replace Bash `jq` merging with Rust hierarchical config loading.

**Actions**:
1. Create `src/config/loader.rs` with `load_config()` function
2. Implement 4-tier merging logic (default < user < project < local):
   - Default: hardcoded in `defaults.rs`
   - User: `~/.claude/plugins/tts/settings.json`
   - Project: `./.claude/plugins/tts/settings.json`
   - Local: `./.claude/plugins/tts/settings.local.json`
3. Implement JSON merge strategy (deep merge, later values override earlier)
4. Add error handling for missing/malformed JSON files (warn but continue with defaults)
5. Export final merged config

**Verification**:
- Unit test with sample config files
- Verify override behavior (local > project > user > default)
- Test missing file handling (should not crash)

**Estimated Time**: 45 minutes

---

### Task 4: Implement Transcript NDJSON Parser

**Goal**: Parse newline-delimited JSON transcript entries.

**Actions**:
1. Create `src/transcript/parser.rs`
2. Define transcript entry types:
   - `TranscriptEntry` enum (Message, ToolUse)
   - `MessageEntry` struct (id, role, content)
   - `ToolUseEntry` struct (id, name, input)
3. Implement `parse_transcript(path: &Path) -> Result<Vec<TranscriptEntry>>`
4. Handle NDJSON format (line-by-line JSON parsing)
5. Add error handling for malformed entries (log warning, skip entry)

**Reference**: Bash implementation in `_extract_entries_since_uuid()`

**Verification**:
- Parse sample transcript file with mixed message/tool_use entries
- Verify malformed entries are skipped gracefully
- Test with empty transcript

**Estimated Time**: 30 minutes

---

### Task 5: Implement UUID-Based Entry Filtering

**Goal**: Extract transcript entries since a given UUID.

**Actions**:
1. Create `src/transcript/extractor.rs`
2. Implement `extract_entries_since_uuid(entries: Vec<TranscriptEntry>, last_uuid: Option<String>) -> Vec<TranscriptEntry>`
3. Logic:
   - If `last_uuid` is `None`, return all entries
   - If `last_uuid` is `Some(uuid)`, find the entry with that UUID
   - Return all entries AFTER that UUID (exclusive)
   - If UUID not found, return all entries (safety fallback)
4. Filter to only assistant messages and tool_use entries

**Reference**: Bash implementation in `_extract_entries_since_uuid()`

**Verification**:
- Test with various UUID positions (start, middle, end, not found)
- Test with `None` (should return all)
- Verify only assistant/tool_use entries are included

**Estimated Time**: 30 minutes

---

### Task 6: Implement JSON Session State Management

**Goal**: Replace plain-text UUID tracking with structured JSON state.

**Actions**:
1. Create `src/state/mod.rs`
2. Define `SessionState` struct:
   ```rust
   struct SessionState {
       last_uuid: Option<String>,
       last_updated: u64,  // Unix timestamp
       session_id: String,
   }
   ```
3. Implement `load_state(session_id: &str) -> Result<SessionState>`
4. Implement `save_state(state: &SessionState) -> Result<()>`
5. Use atomic writes (write to temp file, then rename)
6. State file location: `~/.local/state/claude-tts/session-state/{session_id}.json`

**Verification**:
- Test state save/load roundtrip
- Verify atomic writes (interruption safety)
- Test missing state file (should create new)

**Estimated Time**: 30 minutes

---

### Task 7: Implement File-Based Locking

**Goal**: Prevent concurrent hook invocations from corrupting state or TTS playback.

**Actions**:
1. Add `fs2` crate to dependencies (for `flock` equivalent)
2. Create `src/state/lock.rs`
3. Implement `acquire_lock(session_id: &str) -> Result<LockFile>`
4. Lock file location: `/tmp/tts-lock-{session_id}`
5. Implement timeout (60 seconds) with retry logic
6. Use RAII pattern (lock automatically released on drop)

**Reference**: Bash implementation uses `flock` with 60s timeout

**Verification**:
- Test concurrent lock attempts (second should wait)
- Test lock timeout behavior
- Verify lock is released on process exit

**Estimated Time**: 30 minutes

---

### Task 8: Implement TTS Section Extraction

**Goal**: Extract "## 🔊 TTS Response" sections from messages.

**Actions**:
1. Create `src/tts/text_processor.rs`
2. Implement `extract_tts_section(content: &str) -> Option<String>`
3. Logic:
   - Find `## 🔊 TTS Response` heading (case-insensitive, flexible emoji)
   - Extract all text after that heading
   - Stop at next `##` heading or end of content
   - Strip markdown formatting (remove `_`, `**`, `` ` ``, etc.)
4. Implement `truncate_text(text: &str, max_length: usize) -> String`

**Reference**: Bash implementation in `_extract_tts_section()` and `_truncate_text()`

**Verification**:
- Test with messages containing TTS section
- Test with messages without TTS section (should return full content)
- Test truncation at boundary
- Verify markdown stripping

**Estimated Time**: 30 minutes

---

### Task 9: Implement External CLI Wrapper

**Goal**: Call external `kokoro-tts` CLI and manage the TTS process.

**Actions**:
1. Create `src/tts/cli.rs`
2. Implement `speak_text(text: &str, config: &VoiceSettings, model_paths: &ModelPaths) -> Result<()>`
3. Use `std::process::Command` to spawn `kokoro-tts`:
   ```bash
   echo "$text" | kokoro-tts --voice {voice} --lang {lang} --speed {speed} --model {model} --voices {voices}
   ```
4. Pipe text to stdin
5. Capture stderr for error messages
6. Wait for process completion
7. Implement `kill_tts()` to terminate running TTS processes (`pkill kokoro-tts`)

**Reference**: Bash implementation in `_speak_text()` and `_kill_tts()`

**Verification**:
- Test with sample text (should play audio)
- Test with invalid kokoro-tts path (should error gracefully)
- Verify process cleanup on interruption

**Estimated Time**: 45 minutes

---

### Task 10: Implement Main TTS Workflow

**Goal**: Port the core `process_and_speak_new_messages()` logic.

**Actions**:
1. Create `src/tts/workflow.rs`
2. Implement `process_and_speak_new_messages(transcript_path: &Path, session_id: &str, config: &Config) -> Result<()>`
3. Logic flow:
   - Acquire lock
   - Load session state (last UUID)
   - Parse transcript
   - Extract entries since last UUID
   - For each entry:
     - Extract TTS section (if enabled)
     - Truncate to max length
     - Accumulate text
   - If text accumulated:
     - Speak text via CLI (single process for all text)
     - Update session state with latest UUID
   - Release lock

**Reference**: Bash implementation in `process_and_speak_new_messages()`

**Verification**:
- End-to-end test with sample transcript
- Verify state is updated after successful TTS
- Test with no new messages (should not speak)

**Estimated Time**: 60 minutes

---

### Task 11: Implement Tool Handler Registry

**Goal**: Create extensible tool handler system for tool-specific TTS behaviors.

**Actions**:
1. Create `src/handlers/mod.rs`
2. Define `ToolHandler` trait:
   ```rust
   trait ToolHandler {
       fn handle(&self, tool_use: &ToolUseEntry, config: &Config) -> Option<String>;
   }
   ```
3. Implement `HandlerRegistry` with HashMap<String, Box<dyn ToolHandler>>
4. Create default handler (returns None)
5. Auto-register handlers at startup

**Reference**: Bash implementation in `handler-registry.sh`

**Verification**:
- Register test handler
- Verify dispatch by tool name
- Test fallback to default handler

**Estimated Time**: 30 minutes

---

### Task 12: Implement AskUserQuestion Handler

**Goal**: Port the AskUserQuestion tool handler with configurable formatting.

**Actions**:
1. Create `src/handlers/ask_user_question.rs`
2. Implement `AskUserQuestionHandler` struct implementing `ToolHandler`
3. Parse `AskUserQuestion` input JSON (questions, options)
4. Support 3 format modes:
   - `"sentence"`: Natural language questions with options
   - `"list"`: Bulleted list format
   - `"simple"`: Question only, no options
5. Add configurable pause between questions

**Reference**: Bash implementation in `ask-user-question-handler.sh`

**Verification**:
- Test with sample AskUserQuestion tool_use
- Verify all 3 format modes
- Test with multiple questions

**Estimated Time**: 45 minutes

---

### Task 13: Implement CLI Argument Parser and Hook Dispatcher

**Goal**: Create main entry point that dispatches to different hooks based on CLI arguments.

**Actions**:
1. Update `src/main.rs`
2. Use `clap` to define subcommands:
   - `tts stop <transcript_path> <session_id>` - Stop hook
   - `tts pretooluse <tool_json> <session_id>` - PreToolUse hook
   - `tts interrupt <session_id>` - UserPromptSubmit hook
   - `tts cleanup <session_id>` - SessionEnd hook
   - `tts init` - SessionStart hook
3. Implement hook-specific logic:
   - `stop`: Call `process_and_speak_new_messages()`
   - `pretooluse`: Build tool_use message, call `process_and_speak_new_messages()`
   - `interrupt`: Call `kill_tts()`, mark all messages as read
   - `cleanup`: Delete session state file
   - `init`: Call `kill_tts()` (cleanup leftover processes)
4. Load config at startup
5. Add error handling and logging

**Reference**: Hook implementations in `tts-hook.sh`, `tts-pretooluse-hook.sh`, `tts-interrupt.sh`, `tts-session-stopped.sh`

**Verification**:
- Test each subcommand manually
- Verify correct workflow is invoked
- Test error handling (missing args, invalid paths)

**Estimated Time**: 60 minutes

---

### Task 14: Cross-Platform Binary Compilation

**Goal**: Build binaries for all target platforms.

**Actions**:
1. Install Rust cross-compilation targets:
   ```bash
   rustup target add x86_64-apple-darwin
   rustup target add aarch64-apple-darwin
   rustup target add x86_64-unknown-linux-gnu
   rustup target add aarch64-unknown-linux-gnu
   ```
2. Create build script: `rust/build-all.sh`
3. Build for each platform:
   ```bash
   cargo build --release --target <target>
   ```
4. Create binary distribution structure:
   ```
   plugins/tts/bin/
   ├── darwin-arm64/tts
   ├── darwin-x86_64/tts
   ├── linux-x86_64/tts
   └── linux-arm64/tts
   ```
5. Copy compiled binaries to appropriate directories
6. Make binaries executable (`chmod +x`)

**Verification**:
- All 4 binaries compile successfully
- Binaries are placed in correct directories
- Test local binary executes (basic `--help`)

**Estimated Time**: 45 minutes

---

### Task 15: Update Hook Scripts to Call Rust Binary

**Goal**: Replace Bash function calls with Rust binary invocations.

**Actions**:
1. Create platform detection script: `plugins/tts/scripts/detect-platform.sh`
   - Detects OS (darwin/linux) and architecture (arm64/x86_64)
   - Sets `TTS_BINARY` variable
2. Update `tts-hook.sh` (Stop hook):
   ```bash
   TTS_BINARY="${CLAUDE_PLUGIN_ROOT}/bin/$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)/tts"
   "${TTS_BINARY}" stop "${TRANSCRIPT_PATH}" "${SESSION_ID}"
   ```
3. Update `tts-pretooluse-hook.sh` (PreToolUse hook):
   ```bash
   "${TTS_BINARY}" pretooluse "${CURRENT_MESSAGE}" "${SESSION_ID}"
   ```
4. Update `tts-interrupt.sh` (UserPromptSubmit hook):
   ```bash
   "${TTS_BINARY}" interrupt "${SESSION_ID}"
   ```
5. Update `tts-session-stopped.sh` (SessionEnd hook):
   ```bash
   "${TTS_BINARY}" cleanup "${SESSION_ID}"
   ```
6. Update SessionStart hook:
   ```bash
   "${TTS_BINARY}" init
   ```

**Files to Modify**:
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/hooks/scripts/tts-hook.sh`
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/hooks/scripts/tts-pretooluse-hook.sh`
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/hooks/scripts/tts-interrupt.sh`
- `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/hooks/scripts/tts-session-stopped.sh`

**Verification**:
- Each hook script calls correct Rust subcommand
- Platform detection works on current system
- Binary path resolves correctly

**Estimated Time**: 30 minutes

---

### Task 16: Create Unit Tests

**Goal**: Add unit tests for core functionality.

**Actions**:
1. Create test modules:
   - `src/config/tests.rs` - Config loading and merging
   - `src/transcript/tests.rs` - Parsing and filtering
   - `src/state/tests.rs` - State save/load
   - `src/tts/tests.rs` - Text extraction and truncation
2. Add `#[cfg(test)]` modules
3. Test cases:
   - Config hierarchical merging
   - Transcript NDJSON parsing (valid/invalid entries)
   - UUID filtering (various scenarios)
   - TTS section extraction
   - Text truncation
   - State persistence roundtrip
4. Use sample data files in `rust/tests/fixtures/`

**Verification**:
- `cargo test` passes all tests
- Coverage for critical paths (config, transcript, state)

**Estimated Time**: 45 minutes

---

### Task 17: Integration Testing and Validation

**Goal**: End-to-end testing with real transcript files and TTS playback.

**Actions**:
1. Create test transcript file: `rust/tests/fixtures/sample-transcript.ndjson`
2. Create test config: `rust/tests/fixtures/test-settings.json`
3. Manual integration tests:
   - Run `tts stop <test_transcript> test-session`
   - Verify TTS plays audio
   - Verify state file is created with correct UUID
   - Run again (should not replay same messages)
   - Test `tts interrupt` (should stop TTS)
   - Test `tts cleanup` (should delete state)
4. Test tool handler:
   - Create sample AskUserQuestion tool_use JSON
   - Run `tts pretooluse <tool_json> test-session`
   - Verify formatted output is spoken
5. Test error scenarios:
   - Missing kokoro-tts binary (should error gracefully)
   - Malformed transcript (should skip bad entries)
   - Missing config files (should use defaults)

**Verification**:
- All hooks work end-to-end
- TTS quality matches Bash version
- State management prevents duplicate playback
- Error messages are clear and actionable

**Estimated Time**: 60 minutes

---

### Task 18: Documentation and Migration Guide

**Goal**: Create comprehensive documentation for the Rust port.

**Actions**:
1. Create `/Users/colings86/src/github.com/colings86/tts-plugin/plugins/tts/RUST_PORTING_PLAN.md` (this document)
2. Update main README with Rust implementation notes
3. Create `plugins/tts/rust/README.md` with:
   - Architecture overview
   - Build instructions
   - Development guide
   - Testing guide
4. Document key differences from Bash version:
   - JSON state format (not plain text)
   - Better error messages
   - No backward compatibility with old state
5. Add code comments to complex Rust functions

**Verification**:
- Documentation is clear and complete
- Build instructions work from scratch
- Architecture diagrams (if any) are accurate

**Estimated Time**: 30 minutes

---

### Task 19: Deprecation and Cleanup

**Goal**: Mark old Bash implementation as deprecated and prepare for removal.

**Actions**:
1. Rename old Bash script:
   - `tts-common.sh` → `tts-common.sh.deprecated`
2. Add deprecation notice to old hook scripts (before they're updated)
3. Keep old scripts for one release cycle (safety)
4. Update plugin version to indicate Rust port (e.g., `0.4.0-rust`)
5. Update `.claude-plugin/plugin.json` metadata

**Verification**:
- Old code is clearly marked as deprecated
- No breaking changes for users (hooks still work)

**Estimated Time**: 15 minutes

---

## Success Criteria

The Rust port is complete when:

1. ✅ All 5 hooks (Stop, PreToolUse, UserPromptSubmit, SessionStart, SessionEnd) work identically to Bash version
2. ✅ TTS quality and behavior are indistinguishable from current implementation
3. ✅ Session state management prevents duplicate playback (UUID tracking)
4. ✅ Configuration hierarchy works (default < user < project < local)
5. ✅ Tool handler registry supports AskUserQuestion with all 3 format modes
6. ✅ Binaries compile for all 4 platforms (macOS arm64/x86_64, Linux x86_64/arm64)
7. ✅ Unit tests pass for core functionality
8. ✅ Integration tests validate end-to-end workflows
9. ✅ Error messages are clear and actionable (better than Bash)
10. ✅ MIT license preserved (no GPL dependencies)
11. ✅ Documentation is complete and accurate

## Post-Port Enhancements (Optional)

After the core port is complete and stable, consider these enhancements:

1. **Setup Script**: Auto-detect platform and install appropriate binary
2. **CLI Validation**: Check if `kokoro-tts` is installed on first run
3. **Logging**: Structured logging (not just file-based)
4. **Performance Metrics**: Measure hook execution time
5. **Windows Support**: Add Windows binary compilation and testing

## Phase 2 Preparation (Future)

This port sets the foundation for Phase 2 (ONNX integration):

- The `src/tts/cli.rs` module can be replaced with `src/tts/onnx.rs`
- Same architecture, interfaces, and hook integration
- Only the TTS backend changes (CLI → embedded ONNX)

---

**Total Estimated Time**: 12-15 hours (spread across 2-3 days)

**Task Breakdown**:
- Day 1: Tasks 1-8 (infrastructure, config, parsing, state) - ~5 hours
- Day 2: Tasks 9-13 (TTS integration, handlers, CLI) - ~5 hours
- Day 3: Tasks 14-19 (builds, testing, docs, cleanup) - ~4 hours

This plan provides incremental, executable tasks suitable for sequential agent execution, with each task building on the previous ones and including clear verification steps.
