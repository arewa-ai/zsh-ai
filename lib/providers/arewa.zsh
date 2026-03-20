#!/usr/bin/env zsh

# Arewa AI API provider for zsh-ai

# Function to call Arewa AI API
_zsh_ai_query_arewa() {
    local query="$1"
    local response
    
    # Build context
    local context=$(_zsh_ai_build_context)
    local escaped_context=$(_zsh_ai_escape_json "$context")
    local system_prompt=$(_zsh_ai_get_system_prompt "$escaped_context")
    local escaped_system_prompt=$(_zsh_ai_escape_json "$system_prompt")
    
    # Prepare the JSON payload - escape quotes in the query
    local escaped_query=$(_zsh_ai_escape_json "$query")

    local json_payload=$(cat <<EOF
{
    "model": "${ZSH_AI_AREWA_MODEL}",
    "messages": [
        {
            "role": "system",
            "content": "$escaped_system_prompt"
        },
        {
            "role": "user",
            "content": "$escaped_query"
        }
    ],
    "max_tokens": 4000,
    "stream": false
}
EOF
)
    
    # Call the API - only add auth header if API key is set
    local auth_args=()
    local api_key="${ZSH_AI_AREWA_API_KEY:-$AREWA_API_KEY}"
    [[ -n "$api_key" ]] && auth_args=(--header "Authorization: Bearer $api_key")

    response=$(curl -s "${ZSH_AI_AREWA_URL}" \
        "${auth_args[@]}" \
        --header "content-type: application/json" \
        --data "$json_payload" 2>&1)
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to connect to Arewa AI API"
        return 1
    fi
    
    # Extract the content from the response
    if command -v jq &> /dev/null; then
        local result=$(printf "%s" "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
        if [[ -z "$result" ]]; then
            # Check for error message
            local error=$(printf "%s" "$response" | jq -r '.error.message // empty' 2>/dev/null)
            if [[ -n "$error" ]]; then
                echo "API Error: $error"
            else
                echo "Error: Unable to parse response"
            fi
            return 1
        fi
        # Clean up the response - remove newlines and trailing whitespace
        result=$(printf "%s" "$result" | tr -d '\n' | sed 's/[[:space:]]*$//')
        printf "%s" "$result"
    else
        # Fallback parsing without jq
        local result=$(printf "%s" "$response" | sed -n 's/.*"content":"\([^"]*\)".*/\1/p' | head -1)

        if [[ -z "$result" ]]; then
            result=$(printf "%s" "$response" | perl -0777 -ne 'print $1 if /"content":"((?:[^"\\]|\\.)*)"/s' 2>/dev/null)
        fi

        if [[ -z "$result" ]]; then
            echo "Error: Unable to parse response (install jq for better reliability)"
            return 1
        fi

        # Unescape JSON string
        result=$(printf "%s" "$result" | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\r/\r/g; s/\\"/"/g; s/\\\\/\\/g')
        result=$(printf "%s" "$result" | sed 's/[[:space:]]*$//')
        printf "%s" "$result"
    fi
}
