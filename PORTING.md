# Porting TTS Plugin from Bash to Rust

**Status**: Planning Phase
**Date**: 2026-02-16
**Decision**: Port to Rust with external CLI (Phase 1), future ONNX integration (Phase 2)
**Updated**: 2026-02-16 - Revised after GPL licensing discovery

---

## Executive Summary

This document outlines the research, analysis, and decision to port the TTS plugin's core logic from bash (`tts-common.sh`) to Rust.

**Revised Approach** (after licensing review): The port will be completed in two phases:
- **Phase 1**: Rust implementation calling external `kokoro-tts` CLI (maintains current architecture, gains Rust benefits)
- **Phase 2**: Future integration of ONNX runtime directly (once permissive-licensed solution is available)

This phased approach avoids GPL-3.0 licensing conflicts while still delivering the maintainability, performance, and type-safety benefits of Rust.

---

## Current State

### The Problem

The `tts-common.sh` bash script has grown to **522 lines** and is becoming increasingly difficult to maintain. It handles:

- **JSON configuration** with hierarchical merging (using `jq`)
- **Transcript processing** with UUID tracking for session state
- **Session state management** across multiple hook invocations
- **Process coordination** with external `kokoro-tts` CLI tool
- **Tool handler registry** system for extensible TTS behaviors
- **File I/O** with atomic writes and lock management

### Key Pain Points

1. **Complexity**: String manipulation, command substitution, and jq piping make the code hard to follow
2. **Fragility**: Bash's loose typing leads to silent failures
3. **Testing**: Unit testing bash is difficult and often neglected
4. **Maintenance**: Adding features requires careful navigation of nested subshells and process management
5. **External dependency**: Users must install `kokoro-tts` CLI separately

### Current Architecture

```
plugins/tts/
├── scripts/
│   ├── tts-common.sh (522 lines - core logic)
│   └── tts-tool-handlers/
│       ├── handler-registry.sh
│       └── ask-user-question.sh
├── hooks/
│   ├── Stop.sh
│   ├── PreToolUse.sh
│   ├── SessionStart.sh
│   ├── SessionEnd.sh
│   └── UserPromptSubmit.sh
└── settings.default.json
```

**Dependencies**:
- `jq` (JSON processing)
- `kokoro-tts` CLI (external TTS engine)
- `bash` 4.0+
- `flock` (file locking)

---

## Language Research & Analysis

We evaluated three programming languages for the port: **Go**, **Python**, and **Rust**.

### Research Questions

1. **Kokoro Integration**: Would the dependency remain external, or could we integrate it?
2. **Cross-Platform Distribution**: How to handle macOS/Linux binaries?
3. **Performance**: Hook invocation overhead matters (hooks fire on every Stop, UserPromptSubmit event)
4. **Maintainability**: Long-term code quality and extensibility
5. **Development Speed**: Time to port and iterate

### Key Findings

#### Kokoro TTS Ecosystem by Language

- **Go**: No mature Kokoro implementation; ONNX bindings exist but require CGO (complex cross-compilation)
- **Python**: Excellent tooling ([nazdridoy/kokoro-tts](https://github.com/nazdridoy/kokoro-tts)), mature ONNX support
- **Rust**: Production-ready [kokorox](https://github.com/byteowlz/kokorox) library with streaming support ("insanely fast, realtime TTS")

#### Cross-Platform Distribution

All compiled languages (Go, Rust) require platform-specific binaries:
- **Recommended approach**: One plugin with binaries in `bin/{os}-{arch}/` subdirectories
- **Setup script**: Auto-detects platform and installs appropriate binary
- **Distribution size**: ~10-15MB per binary × 4 platforms = ~40-60MB total

---

## Language Comparison

### 1. Go

**Pros**:
- Single binary per platform (no runtime dependencies)
- Fast startup (instant, no interpreter overhead)
- Clean concurrency with goroutines
- Native JSON handling
- Good cross-platform support
- 2-3 day porting effort

**Cons**:
- **No mature Kokoro integration** (weakest of the three)
- External `kokoro-tts` CLI still required
- ONNX integration requires CGO (complex cross-compilation)
- More verbose than Python

**Best For**: Middle ground - better than bash, but doesn't excel at TTS integration

**Estimated Effort**: 2-3 days

---

### 2. Python

**Pros**:
- **Fastest development** (1.5-2 days to port)
- **Best Kokoro CLI tooling** (Python-native implementations)
- Excellent ONNX support for future integration
- Easy to read and modify
- Extensive audio processing libraries

**Cons**:
- **Requires Python 3.9+ runtime** (users must install separately)
- **200-500ms startup overhead** per hook invocation (noticeable)
- Distribution complexity (PyInstaller creates 50-100MB binaries)
- Less strict type checking (more runtime errors possible)

**Best For**: Rapid iteration and eventual ONNX integration, if startup overhead is acceptable

**Estimated Effort**: 1.5-2 days (but +1-2 days for packaging)

---

### 3. Rust ⭐ **SELECTED**

**Pros**:
- ✅ **Native Kokoro integration**: [kokorox](https://github.com/byteowlz/kokorox) library available
- ✅ **Eliminates external dependency**: No separate `kokoro-tts` installation needed
- ✅ **Single binary**: Everything bundled (TTS engine, models, logic)
- ✅ **Maximum performance**: Compiled, no GC, instant startup
- ✅ **Memory safety**: Compile-time guarantees prevent entire classes of bugs
- ✅ **Best ONNX support**: Mature bindings for model handling
- ✅ **Type safety**: Most expressive type system catches errors early
- ✅ **Production-grade**: Ideal for long-term reliability

**Cons**:
- Steeper learning curve (borrow checker, lifetimes)
- Longer compile times during development
- 3-5 day porting effort (higher initial investment)

**Best For**: Production-grade, self-contained solution with no external dependencies

**Estimated Effort**: 3-5 days

---

## Decision: Rust

### Why Rust Won

Given the research findings, Rust emerged as the clear winner for the following reasons:

1. **Eliminate External Dependency**: The [kokorox](https://github.com/byteowlz/kokorox) library allows us to integrate Kokoro TTS directly into the binary. Users won't need to install anything separately.

2. **True Self-Contained Plugin**: With ONNX models bundled (or downloaded on first run), the entire TTS system becomes one executable.

3. **Best Long-Term Architecture**: While Go and Python would still require external `kokoro-tts` CLI, Rust offers a path to full integration.

4. **Performance**: Hooks fire frequently (Stop, UserPromptSubmit on every interaction). Rust's instant startup and zero overhead ensure TTS doesn't slow down the user experience.

5. **Reliability**: Compile-time safety prevents entire classes of bugs that plague bash (null handling, type mismatches, race conditions).

6. **Future-Proof**: The Rust TTS ecosystem is growing (kokorox, Kokoros crate). Investing in Rust positions us well for future enhancements.

### Trade-Offs Accepted

- **Learning Curve**: Rust is harder to learn, but the investment pays off in maintainability
- **Development Time**: 3-5 days vs 1.5-2 days (Python), but we gain a superior final product
- **Compile Times**: Slower iteration during development, but negligible for end users

### Why Not Go or Python?

**Go**: Since Kokoro would still be external, we'd lose the "single binary" advantage. Go's weaker TTS ecosystem doesn't justify the port over staying with bash or choosing Python.

**Python**: While fastest to develop, the 200-500ms startup overhead per hook invocation is noticeable. Since we're investing in a rewrite anyway, Rust's superior architecture justifies the extra effort.

---

## ⚠️ CRITICAL LICENSING DISCOVERY

**Date**: 2026-02-16

After the initial decision to use Rust with kokorox integration, a comprehensive licensing review revealed a **critical GPL-3.0 licensing conflict** that blocks the direct integration approach.

### The Problem

**Kokorox is GPL-3.0 licensed** because it statically links `espeak-ng` (also GPL-3.0) for phoneme conversion. When you link GPL-3.0 code into your binary, **the entire binary becomes GPL-3.0**.

#### License Breakdown

| Component | License | Compatible with MIT? |
|-----------|---------|---------------------|
| **Kokorox** | **GPL-3.0** | ❌ **NO - BLOCKER** |
| ├─ espeak-rs-sys | MIT (wrapper) | ⚠️ (wraps GPL code) |
| └─ espeak-ng | GPL-3.0 | ❌ Contamination source |
| **Kokoro Models** | Apache 2.0 | ✅ YES |
| **ONNX Runtime** | MIT | ✅ YES |
| **Current Plugin** | MIT | ✅ (must preserve) |

### Implications

1. **Cannot use kokorox** in MIT-licensed plugin without violating license
2. **GPL-3.0 contamination**: Linking kokorox forces entire plugin to be GPL-3.0
3. **Must preserve MIT license**: Plugin is currently MIT, users expect permissive licensing

### Good News

- ✅ **Kokoro ONNX models**: Apache 2.0 (permissive, can use freely)
- ✅ **ONNX Runtime**: MIT (permissive, can use freely)
- ✅ **Problem is only the wrapper**: The models and runtime are clean

### Revised Strategy: Phased Approach

Given the licensing constraints, we've adopted a **two-phase strategy**:

#### **Phase 1: Rust + External CLI** (Initial Port)
- Port bash logic to Rust
- Call external `kokoro-tts` CLI (like current bash implementation)
- Maintain MIT license
- Deliver all Rust benefits (maintainability, performance, type safety)
- **Timeline**: 2-3 days

**Benefits**:
- ✅ No GPL licensing conflicts
- ✅ Immediate maintainability improvement over bash
- ✅ Fast startup (Rust binary calls CLI)
- ✅ Preserves MIT license
- ✅ Users keep existing `kokoro-tts` installation

#### **Phase 2: ONNX Integration** (Future Enhancement)
- Build permissive-licensed ONNX wrapper OR
- Wait for MIT/Apache Rust Kokoro implementation OR
- Use ONNX Runtime directly with custom IPA conversion

**Benefits**:
- ✅ Eventually eliminate external CLI dependency
- ✅ Self-contained binary
- ✅ Maintains MIT license

**Timeline**: Future (after Phase 1 is proven and stable)

### Why This Is Better

1. **Incremental Value**: Phase 1 delivers immediate benefits (better than bash) without licensing risk
2. **Risk Mitigation**: Validate Rust architecture before investing in complex ONNX integration
3. **License Preservation**: MIT license maintained throughout
4. **Future Flexibility**: Can integrate ONNX when permissive solution exists
5. **User Experience**: Minimal disruption (users already have `kokoro-tts` installed)

### Alternatives Considered (and Why Rejected)

❌ **Switch to GPL-3.0**: Would impact adoption and commercial use
❌ **Use Python**: Hook startup overhead is noticeable, less type safety
❌ **Use Go**: Weaker TTS ecosystem, similar external CLI limitation
❌ **Build ONNX wrapper first**: Too complex for initial port, higher risk

### Licensing Requirements (Phase 1)

Since we're using external CLI, no changes to current licensing:
- ✅ Plugin remains **MIT**
- ✅ Users install `kokoro-tts` separately (their responsibility)
- ✅ Clean separation between MIT code and GPL tool

### Licensing Requirements (Phase 2 - Future)

If/when we integrate ONNX directly with permissive licensing:
- Must use MIT or Apache 2.0 licensed components only
- Include attribution for Kokoro models (Apache 2.0 requirement)
- Include attribution for ONNX Runtime (MIT requirement)

---

## Goals of the Port

### Phase 1 Goals (Initial Port - 2-3 days)

**Primary Goals**:
1. ✅ **Replace bash with Rust** for better maintainability
2. ✅ **Call external `kokoro-tts` CLI** (preserve current architecture)
3. ✅ **Preserve MIT license** (no GPL dependencies)
4. ✅ **Maintain all existing functionality** (hooks, handlers, state management)
5. ✅ **Cross-platform support** (macOS arm64/x86_64, Linux x86_64/arm64)
6. ✅ **Type safety** through Rust's type system
7. ✅ **Better error handling** than bash (explicit errors, no silent failures)

**Secondary Goals**:
- **Easier testing**: Unit and integration tests for core logic
- **Performance**: Fast Rust startup (~50ms) calling external CLI
- **Extensibility**: Clean handler registry pattern using Rust traits
- **Code clarity**: Structured modules vs nested bash functions

### Phase 2 Goals (Future - ONNX Integration)

**When**: After Phase 1 is stable and proven

**Primary Goals**:
1. ✅ **Eliminate `kokoro-tts` CLI dependency** via permissive ONNX integration
2. ✅ **Single binary** with embedded TTS engine
3. ✅ **Maintain MIT license** (use only MIT/Apache components)
4. ✅ **Bundle or cache ONNX models** locally

**Approach Options**:
- Build MIT-licensed Rust wrapper for ONNX + Kokoro
- Use ONNX Runtime directly with custom text-to-IPA conversion
- Wait for community MIT/Apache Kokoro implementation

### Non-Goals (Out of Scope for Both Phases)

- Changing user-facing behavior or configuration format
- Adding new features beyond current functionality
- Supporting Windows (can be added later if needed)
- Switching to GPL-3.0 license

---

## Proposed Architecture

### Phase 1 Structure (External CLI)

```
tts-plugin/
├── rust/                          # NEW: Rust implementation
│   ├── Cargo.toml                 # Dependencies (serde, serde_json, etc.)
│   ├── src/
│   │   ├── main.rs                # Entry point (hook dispatcher)
│   │   ├── config/
│   │   │   ├── mod.rs             # Config loading & merging
│   │   │   └── defaults.rs        # Default settings
│   │   ├── transcript/
│   │   │   ├── mod.rs             # Parse transcript NDJSON
│   │   │   └── extractor.rs       # Extract entries since UUID
│   │   ├── tts/
│   │   │   ├── mod.rs             # Main TTS workflow
│   │   │   ├── cli.rs             # Call external kokoro-tts CLI
│   │   │   └── state.rs           # Session state management
│   │   └── handlers/
│   │       ├── mod.rs             # Handler registry
│   │       └── ask_user_question.rs
│   └── build.rs                   # Build script (cross-compilation)
├── bin/                           # Compiled binaries
│   ├── darwin-arm64/tts
│   ├── darwin-x86_64/tts
│   ├── linux-x86_64/tts
│   └── linux-arm64/tts
├── hooks/                         # Call Rust binary
│   ├── Stop.sh → calls `tts stop`
│   └── PreToolUse.sh → calls `tts pretooluse`
└── scripts/setup.sh               # Platform detection & installation
```

**Key Change**: `tts/cli.rs` replaces `tts/kokorox.rs` - calls external `kokoro-tts` via `std::process::Command`

### Phase 2 Structure (ONNX Integration - Future)

```diff
  ├── tts/
  │   ├── mod.rs
- │   ├── cli.rs             # External CLI (Phase 1)
+ │   ├── onnx.rs            # Direct ONNX integration (Phase 2)
  │   └── state.rs
```

### Key Design Decisions (Phase 1)

1. ~~**Kokorox Integration**~~: **External CLI** via `std::process::Command` (avoids GPL)
2. **Config Format**: Keep existing JSON hierarchy (defaults → user → project → local)
3. **State Management**: Replace file-based UUID tracking with structured Rust types (JSON files)
4. **Handlers**: Type-safe registry pattern using Rust traits
5. **Distribution**: Setup script auto-detects platform and installs correct binary
6. **CLI Interaction**: Pipe text to `kokoro-tts` stdin, capture output (same as current bash)

---

## Implementation Phases (Phase 1 - External CLI)

### Day 1: Core Infrastructure
- Set up Rust project structure (`cargo init`)
- Dependencies: `serde`, `serde_json`, `anyhow` (error handling)
- Config loader (replaces jq-based merging) - hierarchical JSON merging
- Transcript parser (NDJSON parsing with `serde_json::Deserializer`)
- Session state management (structured types vs file-based UUID tracking)

### Day 2: TTS Integration (External CLI)
- **CLI wrapper** (`tts/cli.rs`): Call `kokoro-tts` via `std::process::Command`
- Text preprocessing: TTS section extraction, truncation
- Process management: Pipe text to stdin, handle output
- Lock management for concurrent hook invocations (file-based or mutex)

### Day 2-3: Hooks & Handlers
- Hook entry point (dispatch by hook type: Stop, PreToolUse, etc.)
- Handler registry pattern using Rust traits
- Port existing handlers (AskUserQuestion, etc.)
- Main workflow: `process_and_speak_new_messages` port

### Day 3: Cross-Platform Builds
- Cross-compilation for all platforms (darwin-arm64, darwin-x86_64, linux-x86_64, linux-arm64)
- Setup script for installation (platform detection)
- Binary packaging in `bin/{os}-{arch}/` directories
- Hook scripts updated to call Rust binary

### Day 3: Testing & Polish
- Unit tests for config loading, transcript parsing
- Integration tests with sample transcripts
- Error handling refinement (replace bash silent failures)
- Documentation updates (README, migration guide)

**Timeline**: 2-3 days total

---

## Future Implementation (Phase 2 - ONNX Integration)

**When**: After Phase 1 is stable and validated in production

**Scope**:
- Replace `tts/cli.rs` with `tts/onnx.rs`
- Integrate permissive-licensed ONNX wrapper (when available)
- Bundle or download Kokoro models on first run
- Eliminate external `kokoro-tts` dependency

**Prerequisites**:
- MIT or Apache 2.0 licensed Rust Kokoro implementation available, OR
- Custom implementation using ONNX Runtime directly

**Timeline**: 4-6 days (complex, includes ONNX learning curve)

---

## Success Criteria

### Phase 1 Success Criteria

The Phase 1 port is successful when:

1. ✅ All existing functionality works identically to bash version
2. ✅ Users continue using existing `kokoro-tts` CLI (no change)
3. ✅ Rust binary runs on macOS (arm64/x86_64) and Linux (x86_64/arm64)
4. ✅ Hooks have fast startup (<100ms for Rust binary + CLI invocation)
5. ✅ Code is maintainable with clear structure and tests
6. ✅ Configuration format remains unchanged (backward compatible)
7. ✅ Error messages are clear and actionable (better than bash)
8. ✅ MIT license preserved (no GPL dependencies)
9. ✅ No regressions in TTS quality or behavior

### Phase 2 Success Criteria (Future)

The Phase 2 ONNX integration is successful when:

1. ✅ Users no longer need to install `kokoro-tts` CLI separately
2. ✅ Single self-contained binary with embedded TTS engine
3. ✅ Hooks have negligible startup overhead (<50ms total)
4. ✅ MIT license maintained (permissive ONNX integration)
5. ✅ TTS quality matches or exceeds CLI version
6. ✅ Model management (download/caching) is transparent to user

---

## Resources

### Phase 1 Libraries & Tools

- **Serde**: https://serde.rs/ - JSON serialization/deserialization
- **Anyhow**: https://github.com/dtolnay/anyhow - Error handling
- **Rust Cross-Compilation**: https://rust-lang.github.io/rustup/cross-compilation.html
- **std::process::Command**: Call external `kokoro-tts` CLI

### Phase 2 Libraries & Tools (Future)

- ~~**Kokorox**~~: ❌ GPL-3.0 - Cannot use (see licensing section)
- **ONNX Runtime Rust**: https://github.com/pykeio/ort - MIT licensed ONNX runtime bindings
- **Potential**: Custom MIT-licensed Kokoro wrapper (to be developed)

### Licensing References

- **Kokorox License Issue**: https://github.com/byteowlz/kokorox - GPL-3.0 (espeak-ng contamination)
- **Kokoro Models**: https://huggingface.co/hexgrad/Kokoro-82M - Apache 2.0 (permissive)
- **ONNX Runtime License**: https://github.com/microsoft/onnxruntime/blob/main/LICENSE - MIT

### Kokoro Implementations (for reference)

- **Python**: https://github.com/nazdridoy/kokoro-tts - CLI tool (what we call externally)
- **Rust (GPL)**: https://github.com/byteowlz/kokorox - Cannot use due to licensing
- **C#**: https://github.com/Lyrcaxis/KokoroSharp
- **JavaScript**: https://github.com/thewh1teagle/kokoro-onnx

---

## Migration Path

### For Users (Phase 1)

1. **Ensure `kokoro-tts` CLI is installed** (same as current requirement)
2. **Update plugin** to new Rust version
3. **Run setup script**: `~/.claude/plugins/tts/scripts/setup.sh` (installs Rust binary)
4. **Verify installation**: TTS should work identically to bash version
5. **No behavior changes**: Same voices, same quality, same configuration

**What Changes**:
- ✅ Hooks call Rust binary instead of bash script
- ✅ Better error messages
- ✅ Faster hook startup

**What Stays the Same**:
- ✅ Still requires `kokoro-tts` CLI installed
- ✅ Same configuration files
- ✅ Same TTS quality and behavior

### For Users (Phase 2 - Future)

1. **Update to Phase 2 version**
2. **First run downloads ONNX models** (or bundled in binary)
3. **Uninstall `kokoro-tts` CLI** (no longer needed)

### For Developers

**Phase 1**:
- Bash hooks replaced with calls to Rust binary
- Configuration format unchanged (JSON hierarchy)
- Handler development in Rust (replace bash functions with Rust traits)
- Test framework: Rust unit tests + integration tests

**Phase 2**:
- Same as Phase 1, but with ONNX integration instead of CLI calls

---

## Open Questions

### Phase 1 (Current)

1. **State File Format**: Use JSON or keep plain text for UUID tracking?
2. **Error Handling**: How verbose should error messages be? (can be more detailed than bash)
3. **Backward Compatibility**: Support reading old bash session state files?
4. **Windows Support**: Add later, or include in Phase 1?
5. **CLI Validation**: Should Rust binary check if `kokoro-tts` is installed and provide helpful error?

### Phase 2 (Future)

1. **Model Bundling**: Include ONNX models in binary (~80MB) or download on first run?
2. **Voice Selection**: How many voices to support? (af_bella is current default)
3. **ONNX Wrapper**: Build custom MIT implementation or wait for community solution?
4. **IPA Conversion**: Use existing library or implement minimal converter?

---

## Conclusion

### Revised Strategy: Phased Rust Port

After comprehensive research and licensing review, the TTS plugin will be ported to Rust in **two phases**:

#### **Phase 1: Rust + External CLI** (2-3 days)
- Replaces 522-line bash script with structured Rust code
- Calls external `kokoro-tts` CLI (preserves current architecture)
- Delivers immediate maintainability, type safety, and performance benefits
- Avoids GPL-3.0 licensing conflicts (maintains MIT license)
- Low risk, proven approach

**Value Delivered**:
- ✅ Better than bash (type safety, error handling, testability)
- ✅ Faster than Python (no 200-500ms interpreter overhead)
- ✅ Cleaner than Go (better for this use case with similar external CLI)
- ✅ No licensing issues (MIT preserved)

#### **Phase 2: ONNX Integration** (Future - 4-6 days)
- Eliminates external `kokoro-tts` CLI dependency
- Integrates permissive-licensed ONNX solution (when available)
- Creates truly self-contained binary
- Maintains MIT license throughout

**Strategic Benefits**:
1. **Incremental Value**: Phase 1 delivers immediate improvements without betting on ONNX complexity
2. **Risk Mitigation**: Validate Rust architecture before complex ONNX integration
3. **License Safety**: MIT license maintained, no GPL contamination
4. **User Impact**: Minimal disruption (users already have CLI installed)
5. **Future Flexibility**: Can integrate ONNX when permissive solution exists

### Why This Approach Wins

The phased strategy combines the best of all worlds:
- **Better than staying with bash**: Type safety, maintainability, testing
- **Better than Python**: No interpreter overhead on hook invocations
- **Better than Go**: Equivalent for Phase 1, stronger ecosystem for future Phase 2
- **Better than immediate ONNX**: Lower risk, faster delivery, proven architecture

The investment in Rust aligns with the goal of creating a **reliable, performant, and maintainable** TTS solution for Claude Code users, while preserving licensing flexibility and minimizing migration risk.
