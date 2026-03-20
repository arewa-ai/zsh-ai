#!/usr/bin/env zsh

# Tests for Arewa AI provider

# Source test helper and the files we're testing
source "${0:A:h}/../test_helper.zsh"
source "${PLUGIN_DIR}/lib/config.zsh"
source "${PLUGIN_DIR}/lib/context.zsh"
source "${PLUGIN_DIR}/lib/providers/arewa.zsh"
source "${PLUGIN_DIR}/lib/utils.zsh"

# Mock curl to test API interactions
curl() {
    if [[ "$*" == *"api.arewa.ai"* ]]; then
        # Simulate successful response
        cat <<EOF
{
    "choices": [
        {
            "message": {
                "content": "ls -la"
            }
        }
    ]
}
EOF
        return 0
    fi
    # Call real curl for other requests
    command curl "$@"
}

test_arewa_query_success() {
    export AREWA_API_KEY="test-key"
    export ZSH_AI_AREWA_MODEL="Qwen3-4B-Thinking-2507"
    export ZSH_AI_AREWA_URL="https://api.arewa.ai/inference/v1/chat/completions"

    local result=$(_zsh_ai_query_arewa "list files")
    assert_equals "$result" "ls -la"
}

test_arewa_query_error_response() {
    export AREWA_API_KEY="test-key"
    
    # Override curl to return an error
    curl() {
        if [[ "$*" == *"api.arewa.ai"* ]]; then
            cat <<EOF
{
    "error": {
        "message": "Invalid API key"
    }
}
EOF
            return 0
        fi
        command curl "$@"
    }
    
    local result=$(_zsh_ai_query_arewa "list files")
    assert_contains "$result" "API Error:"
}

test_arewa_validation() {
    unset AREWA_API_KEY
    unset ZSH_AI_AREWA_API_KEY
    export ZSH_AI_PROVIDER="arewa"
    
    local result
    result=$(_zsh_ai_validate_config 2>&1)
    local exit_code=$?
    
    assert_equals "$exit_code" "1" || return 1
    assert_contains "$result" "AREWA_API_KEY not set" || return 1
    
    export AREWA_API_KEY="test-key"
    _zsh_ai_validate_config >/dev/null
    assert_equals "$?" "0" || return 1
}

test_arewa_zsh_ai_key_takes_precedence() {
    export AREWA_API_KEY="original-key"
    export ZSH_AI_AREWA_API_KEY="override-key"
    export ZSH_AI_PROVIDER="arewa"
    local curl_args_file=$(mktemp)

    curl() {
        if [[ "$*" == *"api.arewa.ai"* ]]; then
            echo "$*" > "$curl_args_file"
            echo '{"choices":[{"message":{"content":"ls -la"}}]}'
            return 0
        fi
        command curl "$@"
    }

    _zsh_ai_query_arewa "list files" >/dev/null
    local curl_args=$(cat "$curl_args_file")
    rm -f "$curl_args_file"

    # Should use the override key, not the original
    if [[ "$curl_args" != *"override-key"* ]]; then
        echo "FAIL: ZSH_AI_AREWA_API_KEY should take precedence"
        return 1
    fi
    if [[ "$curl_args" == *"original-key"* ]]; then
        echo "FAIL: AREWA_API_KEY should not be used when ZSH_AI_AREWA_API_KEY is set"
        return 1
    fi
    return 0
}

# Run tests
echo "Running Arewa AI provider tests..."
test_arewa_query_success && echo "✓ Arewa AI query success" || exit 1
test_arewa_query_error_response && echo "✓ Arewa AI error response handling" || exit 1
test_arewa_validation && echo "✓ Arewa AI validation" || exit 1
test_arewa_zsh_ai_key_takes_precedence && echo "✓ ZSH_AI_AREWA_API_KEY takes precedence" || exit 1
