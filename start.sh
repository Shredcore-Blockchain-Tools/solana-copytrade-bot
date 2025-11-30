#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# shredcore-copytrade-bot start.sh
# Interactive setup and launch script for the Solana copytrade bot.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_FILE="config.toml"
CONFIG_EXAMPLE="config.example.toml"
NONCE_FILE=".durable_nonce.json"
NONCE_SCRIPT="setup_nonce.sh"
BINARY_NAME="shredcore-copytrade-bot"

# ============================================================================
# TOML Editing Helpers
# ============================================================================

# Escape special characters for sed replacement
escape_sed() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g' -e 's/"/\\"/g'
}

# Escape special characters for TOML string values
escape_toml_string() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Set a TOML string value: KEY = "VALUE"
set_toml_string() {
    local key="$1"
    local value="$2"
    local escaped_value
    escaped_value=$(escape_toml_string "$value")
    
    if ! grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$CONFIG_FILE"; then
        echo "ERROR: Key '$key' not found in $CONFIG_FILE" >&2
        return 1
    fi
    
    sed -i -E "s|^([[:space:]]*)${key}[[:space:]]*=.*|\1${key} = \"${escaped_value}\"|" "$CONFIG_FILE"
}

# Set a TOML boolean value: KEY = true/false
set_toml_bool() {
    local key="$1"
    local value="$2"
    
    if ! grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$CONFIG_FILE"; then
        echo "ERROR: Key '$key' not found in $CONFIG_FILE" >&2
        return 1
    fi
    
    sed -i -E "s|^([[:space:]]*)${key}[[:space:]]*=.*|\1${key} = ${value}|" "$CONFIG_FILE"
}

# Set a TOML integer value: KEY = VALUE
set_toml_int() {
    local key="$1"
    local value="$2"
    
    if ! grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$CONFIG_FILE"; then
        echo "ERROR: Key '$key' not found in $CONFIG_FILE" >&2
        return 1
    fi
    
    sed -i -E "s|^([[:space:]]*)${key}[[:space:]]*=.*|\1${key} = ${value}|" "$CONFIG_FILE"
}

# Set a TOML inline string array from comma-separated input
# Usage: set_toml_string_array KEY "item1,item2,item3"
set_toml_string_array() {
    local key="$1"
    local csv="$2"
    local array_content=""
    
    if [[ -n "$csv" ]]; then
        IFS=',' read -ra items <<< "$csv"
        local first=true
        for item in "${items[@]}"; do
            # Trim whitespace
            item=$(echo "$item" | xargs)
            if [[ -n "$item" ]]; then
                local escaped_item
                escaped_item=$(escape_toml_string "$item")
                if $first; then
                    array_content="\"${escaped_item}\""
                    first=false
                else
                    array_content="${array_content}, \"${escaped_item}\""
                fi
            fi
        done
    fi
    
    # Use awk to replace the array (handles multi-line arrays)
    awk -v key="$key" -v content="$array_content" '
    BEGIN { in_array = 0; found = 0 }
    {
        if (match($0, "^[[:space:]]*" key "[[:space:]]*=")) {
            found = 1
            # Check if this is a single-line array
            if (match($0, /\]$/)) {
                print key " = [" content "]"
                next
            }
            # Multi-line array starts here
            in_array = 1
            print key " = [" content "]"
            next
        }
        if (in_array) {
            # Skip lines until we find the closing bracket
            if (match($0, /^[[:space:]]*\]/)) {
                in_array = 0
                next
            }
            # Skip array content lines
            next
        }
        print
    }
    END { if (!found) { print "ERROR: Key " key " not found" > "/dev/stderr"; exit 1 } }
    ' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
}

# ============================================================================
# Prompt Helpers
# ============================================================================

# Prompt for a required (non-empty) value
prompt_required() {
    local prompt_text="$1"
    local var_name="$2"
    local value=""
    
    while [[ -z "$value" ]]; do
        read -rp "$prompt_text: " value
        if [[ -z "$value" ]]; then
            printf "This field is required. Please enter a value.\n" >/dev/tty
        fi
    done
    
    eval "$var_name=\"\$value\""
}

# Prompt for an optional value with a default
prompt_optional() {
    local prompt_text="$1"
    local default_value="$2"
    local var_name="$3"
    local value=""
    
    read -rp "$prompt_text [$default_value]: " value
    if [[ -z "$value" ]]; then
        value="$default_value"
    fi
    
    eval "$var_name=\"\$value\""
}

# Prompt for a selection from numbered options
# Returns the selected value (not the number)
prompt_selection() {
    local prompt_text="$1"
    shift
    local options=("$@")
    local choice=""
    
    # Print to /dev/tty so it's always visible when function is called in subshell
    printf "%s\n" "$prompt_text" >/dev/tty
    for i in "${!options[@]}"; do
        printf "  [%d] %s\n" $((i+1)) "${options[$i]}" >/dev/tty
    done
    printf "\n" >/dev/tty
    
    while true; do
        read -rp "Select option (1-${#options[@]}): " choice < /dev/tty
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            echo "${options[$((choice-1))]}"
            return 0
        fi
        printf "Invalid choice. Please enter a number between 1 and %d.\n" "${#options[@]}" >/dev/tty
    done
}

# ============================================================================
# Base Configuration (shared across all bots)
# ============================================================================

configure_base_config() {
    echo ""
    echo "=== Base Configuration ==="
    echo ""
    
    # License Key (required)
    local license_key
    prompt_required "Enter your license key" license_key
    set_toml_string "LICENSE_KEY" "$license_key"
    
    # RPC URL (required)
    local rpc_url
    prompt_required "Enter RPC URL" rpc_url
    set_toml_string "RPC_URL" "$rpc_url"
    
    # Stream Transport
    echo ""
    local transport
    transport=$(prompt_selection "Select stream transport mode:" "gRPC (recommended)" "WebSocket")
    
    if [[ "$transport" == "gRPC (recommended)" ]]; then
        set_toml_string "STREAM_TRANSPORT" "grpc"
        
        # gRPC URL (required)
        local grpc_url
        prompt_required "Enter gRPC URL" grpc_url
        set_toml_string "GRPC_URL" "$grpc_url"
        
        # gRPC Token (optional)
        local grpc_token
        read -rp "Enter gRPC token (optional, press Enter to skip): " grpc_token
        if [[ -n "$grpc_token" ]]; then
            set_toml_string "GRPC_TOKEN" "$grpc_token"
        fi
    else
        set_toml_string "STREAM_TRANSPORT" "ws"
        
        # WebSocket URL (required)
        local ws_url
        prompt_required "Enter WebSocket URL" ws_url
        set_toml_string "WS_URL" "$ws_url"
    fi
    
    # Wallet Private Key (required)
    echo ""
    local wallet_key
    prompt_required "Enter wallet private key (Base58)" wallet_key
    set_toml_string "WALLET_PRIVATE_KEY_B58" "$wallet_key"
    
    # Preferred Region (optional with default)
    local region
    prompt_optional "Enter preferred region (NewYork, Frankfurt, Amsterdam, SLC, Tokyo, London, LosAngeles, Default)" "NewYork" region
    set_toml_string "PREFERRED_REGION" "$region"
}

# ============================================================================
# Copytrade-Specific Configuration
# ============================================================================

configure_copytrade_config() {
    echo ""
    echo "=== Copytrade Configuration ==="
    echo ""
    
    echo "Enter wallet addresses to copy-trade (comma-separated)."
    echo "These are the wallets whose trades you want to follow."
    
    local target_wallets
    read -rp "Target wallets: " target_wallets
    
    if [[ -z "$target_wallets" ]]; then
        echo ""
        echo "WARNING: No target wallets provided."
        echo "Copytrade signals will not fire until you add wallets to config.toml"
        read -rp "Continue anyway? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Aborting. Please re-run and provide target wallets."
            exit 1
        fi
        # Clear the example wallet
        set_toml_string_array "TARGET_WALLETS" ""
    else
        set_toml_string_array "TARGET_WALLETS" "$target_wallets"
    fi
    
    echo ""
    echo "Copytrade configuration complete!"
    echo "You can tune advanced settings (follow buy size, wait-for-profit, follow sells, etc.) in config.toml"
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    echo "========================================"
    echo "  shredcore-copytrade-bot Start Script"
    echo "========================================"
    
    # Check if config.toml exists
    if [[ -f "$CONFIG_FILE" ]]; then
        echo ""
        echo "Config file found: $CONFIG_FILE"
        echo "Using existing configuration. Edit config.toml directly to make changes."
    else
        # Check for config.example.toml
        if [[ ! -f "$CONFIG_EXAMPLE" ]]; then
            echo "ERROR: $CONFIG_EXAMPLE not found. Cannot initialize configuration." >&2
            exit 1
        fi
        
        echo ""
        echo "No config.toml found. Creating from $CONFIG_EXAMPLE..."
        if ! cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"; then
            echo "ERROR: Failed to copy $CONFIG_EXAMPLE to $CONFIG_FILE" >&2
            exit 1
        fi
        
        echo "Running interactive configuration..."
        configure_base_config
        configure_copytrade_config
        
        echo ""
        echo "Configuration saved to $CONFIG_FILE"
    fi
    
    # Durable nonce setup
    if [[ ! -f "$NONCE_FILE" ]]; then
        echo ""
        echo "Durable nonce file not found. Running setup..."
        
        if [[ ! -x "$NONCE_SCRIPT" ]]; then
            if [[ -f "$NONCE_SCRIPT" ]]; then
                chmod +x "$NONCE_SCRIPT"
            else
                echo "ERROR: $NONCE_SCRIPT not found. Cannot setup durable nonce." >&2
                exit 1
            fi
        fi
        
        if ! ./"$NONCE_SCRIPT"; then
            echo "ERROR: Durable nonce setup failed." >&2
            exit 1
        fi
    fi
    
    # Set environment variable
    export BOT_CONFIG="./config.toml"
    
    # Check for binary
    if [[ ! -x "$BINARY_NAME" ]]; then
        if [[ -f "$BINARY_NAME" ]]; then
            chmod +x "$BINARY_NAME"
        else
            echo ""
            echo "ERROR: Binary ./$BINARY_NAME not found." >&2
            echo "Build it with: cargo build --release" >&2
            echo "Then copy or symlink the binary here." >&2
            exit 1
        fi
    fi
    
    # Launch the bot
    echo ""
    echo "Starting $BINARY_NAME..."
    echo "========================================"
    exec ./"$BINARY_NAME"
}

main "$@"

