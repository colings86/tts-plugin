---
name: test
description: Test text-to-speech with sample or custom text
argument-hint: "[message] [--voice VOICE] [--speed SPEED] [--lang LANGUAGE]"
allowed-tools:
  - Bash
  - Read
---

# Test TTS Command

Test the text-to-speech system with sample or custom text. Allows overriding voice, speed, and language for testing different configurations without modifying .env file.

## Instructions

When the user runs this command, follow these steps:

1. **Parse command arguments**:
   - Extract custom message if provided (anything not starting with --)
   - Extract optional flags:
     - `--voice VOICE` (e.g., --voice af_sarah)
     - `--speed SPEED` (e.g., --speed 1.5)
     - `--lang LANGUAGE` (e.g., --lang en-us)

2. **Determine text to speak**:
   - If custom message provided, use it
   - Otherwise, use default: "This is a test of the text to speech system using Claude Code TTS plugin."

3. **Load configuration**:
   - Read ~/.claude/tts-plugin.env if it exists
   - Use .env values as defaults
   - Override with command-line flags if provided
   - If no .env and no flags, use reasonable defaults:
     - Voice: af_bella
     - Speed: 1.3
     - Language: en-gb
     - Model: $HOME/.local/share/kokoro-tts/kokoro-v1.0.onnx
     - Voices: $HOME/.local/share/kokoro-tts/voices-v1.0.bin

4. **Verify kokoro-tts is installed**:
   - Run `which kokoro-tts` to check installation
   - If not found, show error with installation instructions:
     ```
     Error: kokoro-tts not found

     Install kokoro-tts: https://github.com/thewh1teagle/kokoro

     Verify installation: kokoro-tts --help
     ```

5. **Test TTS**:
   - Run kokoro-tts with the determined settings:
     ```bash
     echo "message" | kokoro-tts - --stream \
       --voice $VOICE \
       --lang $LANG \
       --speed $SPEED \
       --model $MODEL \
       --voices $VOICES
     ```
   - Capture exit code and any errors

6. **Report results**:
   - If successful: "TTS test successful. You should hear the message."
   - If failed: Show error message and suggest troubleshooting
   - Show settings used:
     ```
     Settings used:
       Voice: af_sarah
       Language: en-us
       Speed: 1.5
       Message: "Custom test message"
     ```

7. **Provide next steps**:
   - If test failed, suggest checking kokoro-tts installation
   - If voice/language not working, suggest running:
     - `kokoro-tts --help-voices` for available voices
     - `kokoro-tts --help-languages` for available languages
   - If settings are good, suggest saving them: `/tts-plugin:configure`

## Examples

### Basic test with default message
```
/tts-plugin:test
```

Output:
```
TTS test successful. You should hear: "This is a test of the text to speech system using Claude Code TTS plugin."

Settings used:
  Voice: af_bella
  Language: en-gb
  Speed: 1.3
```

### Test with custom message
```
/tts-plugin:test "Hello world, this is a custom message"
```

### Test with different voice
```
/tts-plugin:test --voice af_sarah
```

### Test with different speed
```
/tts-plugin:test --speed 1.5
```

### Test with all custom settings
```
/tts-plugin:test "Testing all settings" --voice bf_emma --speed 1.8 --lang en-us
```

Output:
```
TTS test successful. You should hear: "Testing all settings"

Settings used:
  Voice: bf_emma
  Language: en-us
  Speed: 1.8
```

## Tips

- Use this command to test different voices before saving configuration
- Test different speeds to find what works best for you
- If you hear nothing, check that your system audio is working
- Run `kokoro-tts --help-voices` to see all available voices
- Run `kokoro-tts --help-languages` to see all available languages
- Once you find settings you like, save them with `/tts-plugin:configure`

## Troubleshooting

If test fails:
1. Verify kokoro-tts is installed: `which kokoro-tts`
2. Check model files exist:
   - ~/.local/share/kokoro-tts/kokoro-v1.0.onnx
   - ~/.local/share/kokoro-tts/voices-v1.0.bin
3. Try running kokoro-tts directly to isolate the issue:
   ```bash
   echo "test" | kokoro-tts - --stream --voice af_bella
   ```
4. Check system audio is working with other applications
