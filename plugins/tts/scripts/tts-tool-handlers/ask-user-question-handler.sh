#!/bin/bash
# TTS handler for AskUserQuestion tool

# Main handler function called by registry
handle_tool_output() {
    local input_json="$1"

    # Get log file from settings
    local session_id=$(echo "$input_json" | jq -r '.session_id // "default"')
    local log_file="${TTS_LOG_DIR}/claude-tts-${session_id}.log"
    mkdir -p "$TTS_LOG_DIR" 2>/dev/null

    echo "=== AskUserQuestion TTS Handler ===" >> "$log_file" 2>&1

    # Extract tool input from PreToolUse input
    local tool_input=$(echo "$input_json" | jq -r '.tool_input // empty')

    if [ -z "$tool_input" ] || [ "$tool_input" == "null" ]; then
        echo "No tool_input found in PreToolUse event" >> "$log_file" 2>&1
        return 0
    fi

    # Extract questions array
    local questions=$(echo "$tool_input" | jq -r '.questions // empty')

    if [ -z "$questions" ] || [ "$questions" == "null" ]; then
        echo "No questions found in tool_input" >> "$log_file" 2>&1
        return 0
    fi

    # Get formatting preference
    local format=$(get_setting "tools.AskUserQuestion.format" "sentence")
    echo "Using format: $format" >> "$log_file" 2>&1

    # Process each question
    local speech_text=""
    local question_count=$(echo "$questions" | jq 'length')
    echo "Processing $question_count question(s)" >> "$log_file" 2>&1

    for ((i=0; i<question_count; i++)); do
        local question=$(echo "$questions" | jq -c ".[$i]")
        local formatted=$(format_question_for_speech "$question" "$format")

        if [ -n "$formatted" ]; then
            if [ -n "$speech_text" ]; then
                speech_text="${speech_text}\n\n${formatted}"
            else
                speech_text="$formatted"
            fi
        fi
    done

    # Speak the formatted text
    if [ -n "$speech_text" ]; then
        echo "Speaking text: ${speech_text:0:200}..." >> "$log_file" 2>&1
        speak_text "$speech_text" "$log_file"
    else
        echo "No text to speak after formatting" >> "$log_file" 2>&1
    fi
}

# Format a single question for speech
format_question_for_speech() {
    local question_json="$1"
    local format="$2"

    local question_text=$(echo "$question_json" | jq -r '.question // empty')
    local options=$(echo "$question_json" | jq -c '.options // empty')

    if [ -z "$question_text" ] || [ "$question_text" == "null" ]; then
        return
    fi

    # Start with the question
    local result="$question_text"

    # Add options if present
    if [ -n "$options" ] && [ "$options" != "null" ] && [ "$options" != "[]" ]; then
        local formatted_options=$(format_options "$options" "$format")
        if [ -n "$formatted_options" ]; then
            result="${result} ${formatted_options}"
        fi
    fi

    echo "$result"
}

# Format options based on configured style
format_options() {
    local options_json="$1"
    local format="$2"

    local option_count=$(echo "$options_json" | jq 'length')

    if [ "$option_count" -eq 0 ]; then
        return
    fi

    local result=""

    case "$format" in
        "sentence")
            # "Your options are: Option A, Option B, or Option C"
            result="Your options are: "
            for ((i=0; i<option_count; i++)); do
                local label=$(echo "$options_json" | jq -r ".[$i].label // empty")

                if [ -z "$label" ] || [ "$label" == "null" ]; then
                    continue
                fi

                if [ $i -eq 0 ]; then
                    result="${result}${label}"
                elif [ $i -eq $((option_count - 1)) ]; then
                    result="${result}, or ${label}"
                else
                    result="${result}, ${label}"
                fi
            done
            ;;

        "list")
            # "Option 1: Option A. Option 2: Option B. Option 3: Option C."
            for ((i=0; i<option_count; i++)); do
                local label=$(echo "$options_json" | jq -r ".[$i].label // empty")

                if [ -z "$label" ] || [ "$label" == "null" ]; then
                    continue
                fi

                local num=$((i + 1))

                if [ $i -eq 0 ]; then
                    result="Option ${num}: ${label}"
                else
                    result="${result}. Option ${num}: ${label}"
                fi
            done
            result="${result}."
            ;;

        "simple")
            # "Option A. Option B. Option C."
            for ((i=0; i<option_count; i++)); do
                local label=$(echo "$options_json" | jq -r ".[$i].label // empty")

                if [ -z "$label" ] || [ "$label" == "null" ]; then
                    continue
                fi

                if [ $i -eq 0 ]; then
                    result="$label"
                else
                    result="${result}. ${label}"
                fi
            done
            result="${result}."
            ;;
    esac

    echo "$result"
}

# Speak text using kokoro-tts (runs in background to not block question display)
speak_text() {
    local text="$1"
    local log_file="$2"

    # Get TTS settings
    local voice="$TTS_VOICE"
    local speed="$TTS_SPEED"
    local lang="$TTS_LANG"
    local model="$TTS_MODEL"
    local voices="$TTS_VOICES"

    # Speak using kokoro-tts in background (async to not block question)
    echo "$text" | kokoro-tts - --stream \
        --voice "$voice" \
        --lang "$lang" \
        --speed "$speed" \
        --model "$model" \
        --voices "$voices" \
        >> "$log_file" 2>&1 &
}
