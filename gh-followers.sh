#!/bin/bash

# GitHub Follower Manager
# Manages followers/following with dry-run support and rate limiting

set -e

# Safer increment function that doesn't fail with set -e
increment() {
    eval "$1=\$((\$$1 + 1))"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="$SCRIPT_DIR/.github-token"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
WAIT_BETWEEN_REQUESTS=2  # seconds between API calls
WAIT_BETWEEN_ACTIONS=5   # seconds between follow/unfollow actions
LOG_FILE="gh-follower-manager.log"
TEMP_DIR="$(mktemp -d)"
FOLLOWERS_FILE="$TEMP_DIR/followers.txt"
FOLLOWING_FILE="$TEMP_DIR/following.txt"
RATE_LIMIT_REMAINING=5000
RATE_LIMIT_RESET=0

# Cleanup temp files on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

# Load token from file if it exists
if [ -f "$TOKEN_FILE" ] && [ -z "$GITHUB_TOKEN" ]; then
    GITHUB_TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null)
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

print_info() { 
    echo -e "${BLUE}ℹ ${NC}$1"; 
    log_message "INFO" "$1";
}
print_success() { 
    echo -e "${GREEN}✓ ${NC}$1"; 
    log_message "SUCCESS" "$1";
}
print_warning() { 
    echo -e "${YELLOW}⚠ ${NC}$1"; 
    log_message "WARNING" "$1";
}
print_error() { 
    echo -e "${RED}✗ ${NC}$1"; 
    log_message "ERROR" "$1";
}

# Show rate limit status
show_rate_limit() {
    if [ "$RATE_LIMIT_REMAINING" -lt 100 ]; then
        print_warning "Rate limit: $RATE_LIMIT_REMAINING requests remaining"
    else
        print_info "Rate limit: $RATE_LIMIT_REMAINING requests remaining"
    fi
}

# GitHub API call wrapper with rate limiting and error detection
gh_api() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local temp_response="$TEMP_DIR/api_response.txt"
    local temp_headers="$TEMP_DIR/api_headers.txt"
    
    sleep "$WAIT_BETWEEN_REQUESTS"
    
    # Make API call and capture headers
    local http_code
    if [ -z "$data" ]; then
        http_code=$(curl -s -w "%{http_code}" -D "$temp_headers" -o "$temp_response" -X "$method" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com$endpoint")
    else
        http_code=$(curl -s -w "%{http_code}" -D "$temp_headers" -o "$temp_response" -X "$method" \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "https://api.github.com$endpoint")
    fi
    
    # Parse rate limit headers
    if [ -f "$temp_headers" ]; then
        RATE_LIMIT_REMAINING=$(grep -i "x-ratelimit-remaining:" "$temp_headers" | tail -1 | awk '{print $2}' | tr -d '\r')
        RATE_LIMIT_RESET=$(grep -i "x-ratelimit-reset:" "$temp_headers" | tail -1 | awk '{print $2}' | tr -d '\r')
    fi
    
    # Check for errors
    if [ "$http_code" -ge 400 ]; then
        local error_msg=$(cat "$temp_response" 2>/dev/null | jq -r '.message // "Unknown error"' 2>/dev/null || echo "API Error")
        print_error "API Error (HTTP $http_code): $error_msg"
        log_message "ERROR" "API call to $endpoint failed with HTTP $http_code: $error_msg"
        return 1
    fi
    
    # Check for rate limit
    if [ "${RATE_LIMIT_REMAINING:-0}" -lt 10 ]; then
        print_warning "Rate limit nearly exhausted! Remaining: $RATE_LIMIT_REMAINING"
        if [ "${RATE_LIMIT_RESET:-0}" -gt 0 ]; then
            local reset_time=$(date -d "@$RATE_LIMIT_RESET" 2>/dev/null || date -r "$RATE_LIMIT_RESET" 2>/dev/null || echo "soon")
            print_warning "Rate limit resets at: $reset_time"
        fi
    fi
    
    cat "$temp_response"
}

# Get all followers (paginated) - saves to temp file
get_followers() {
    local username="$1"
    local page=1
    local count=0
    local temp_file="$TEMP_DIR/followers_raw.txt"
    
    print_info "Fetching followers..."
    > "$temp_file"  # Clear temp file
    
    while true; do
        local response=$(gh_api "/users/$username/followers?per_page=100&page=$page")
        if [ $? -ne 0 ]; then
            print_error "Failed to fetch followers page $page"
            return 1
        fi
        
        local users=$(echo "$response" | jq -r '.[].login' 2>/dev/null)
        
        if [ -z "$users" ]; then
            break
        fi
        
        echo "$users" >> "$temp_file"
        count=$((count + $(echo "$users" | wc -l)))
        echo -ne "\r${BLUE}ℹ${NC} Fetched $count followers (page $page)..."
        ((page++))
    done
    
    # Clean up: remove carriage returns, trim whitespace, deduplicate, convert to lowercase for comparison
    cat "$temp_file" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -uf > "$FOLLOWERS_FILE"
    count=$(wc -l < "$FOLLOWERS_FILE" | tr -d ' ')
    
    echo ""  # New line after progress
    print_success "Fetched $count followers"
}

# Get all following (paginated) - saves to temp file
get_following() {
    local username="$1"
    local page=1
    local count=0
    local temp_file="$TEMP_DIR/following_raw.txt"
    
    print_info "Fetching following..."
    > "$temp_file"  # Clear temp file
    
    while true; do
        local response=$(gh_api "/users/$username/following?per_page=100&page=$page")
        if [ $? -ne 0 ]; then
            print_error "Failed to fetch following page $page"
            return 1
        fi
        
        local users=$(echo "$response" | jq -r '.[].login' 2>/dev/null)
        
        if [ -z "$users" ]; then
            break
        fi
        
        echo "$users" >> "$temp_file"
        count=$((count + $(echo "$users" | wc -l)))
        echo -ne "\r${BLUE}ℹ${NC} Fetched $count following (page $page)..."
        ((page++))
    done
    
    # Clean up: remove carriage returns, trim whitespace, deduplicate, convert to lowercase for comparison
    cat "$temp_file" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort -uf > "$FOLLOWING_FILE"
    count=$(wc -l < "$FOLLOWING_FILE" | tr -d ' ')
    
    echo ""  # New line after progress
    print_success "Fetched $count following"
}

# Get authenticated user
get_current_user() {
    gh_api "/user" | jq -r '.login'
}

# Follow a user
follow_user() {
    local username="$1"
    local dry_run="$2"
    
    if [ "$dry_run" = "true" ]; then
        print_warning "[DRY RUN] Would follow: $username"
        return 0
    fi
    
    local response=$(gh_api "/user/following/$username" "PUT")
    if [ $? -eq 0 ]; then
        sleep "$WAIT_BETWEEN_ACTIONS"
        print_success "Followed: $username"
    else
        print_error "Failed to follow: $username"
        return 1
    fi
}

# Unfollow a user
unfollow_user() {
    local username="$1"
    local dry_run="$2"
    
    if [ "$dry_run" = "true" ]; then
        print_warning "[DRY RUN] Would unfollow: $username"
        return 0
    fi
    
    local response=$(gh_api "/user/following/$username" "DELETE")
    if [ $? -eq 0 ]; then
        sleep "$WAIT_BETWEEN_ACTIONS"
        print_success "Unfollowed: $username"
    else
        print_error "Failed to unfollow: $username"
        return 1
    fi
}

# Main menu
show_menu() {
    echo ""
    echo "========================================="
    echo "    GitHub Follower Manager"
    echo "========================================="
    echo "1) Show who you follow but they don't follow back"
    echo "2) Show your followers you don't follow back"
    echo "3) Unfollow users who don't follow you back (bulk)"
    echo "4) Unfollow users (selective - choose each)"
    echo "5) Follow back your followers (bulk)"
    echo "6) Show rate limit status"
    echo "7) Change GitHub token"
    echo "8) Debug: Show counts"
    echo "9) Auto-sync: Unfollow non-followers + Follow back"
    echo "0) Exit"
    echo "========================================="
    echo -n "Choose an option: "
}

# Token management
setup_token() {
    echo ""
    echo "========================================="
    echo "  GitHub Personal Access Token Setup"
    echo "========================================="
    echo ""
    echo "To create a token:"
    echo "  1. Go to: https://github.com/settings/tokens"
    echo "  2. Click 'Generate new token (classic)'"
    echo "  3. Select scope: 'user:follow'"
    echo "  4. Copy the generated token"
    echo ""
    echo -n "Paste your GitHub token: "
    read -r token_input
    
    if [ -z "$token_input" ]; then
        print_error "No token provided!"
        exit 1
    fi
    
    # Save token to file
    echo "$token_input" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"  # Secure the file (owner read/write only)
    
    export GITHUB_TOKEN="$token_input"
    echo ""
    print_success "Token saved and set successfully!"
}

# ============================================
# Script Initialization
# ============================================

# Check for Windows and Git Bash
IS_WINDOWS=false
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    IS_WINDOWS=true
    echo -e "${BLUE}ℹ${NC} Detected Windows environment (Git Bash)"
fi

# Function to install Scoop on Windows
install_scoop() {
    echo ""
    echo "Installing Scoop package manager..."
    powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" 2>/dev/null
    powershell -Command "Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Scoop installed successfully!"
        # Add Scoop to current session PATH
        export PATH="$HOME/scoop/shims:$PATH"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to install Scoop"
        return 1
    fi
}

# Function to install jq using Scoop
install_jq_windows() {
    echo ""
    echo "Installing jq..."
    
    # Check if Scoop is installed
    if ! command -v scoop >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC} Scoop package manager not found"
        echo -n "Install Scoop and jq automatically? (y/n): "
        read -r install_scoop_choice
        
        if [ "$install_scoop_choice" = "y" ] || [ "$install_scoop_choice" = "Y" ]; then
            if install_scoop; then
                # Reload PATH for current session
                export PATH="$HOME/scoop/shims:$PATH"
                
                scoop install jq
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓${NC} jq installed successfully!"
                    echo ""
                    echo -e "${YELLOW}⚠${NC} Important: Close this terminal and open a new one for PATH changes to take effect."
                    echo ""
                    echo -n "Press Enter to exit, then run the script again in a new terminal..."
                    read
                    exit 0
                fi
            fi
        fi
        return 1
    else
        scoop install jq
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} jq installed successfully!"
            # Update PATH for current session
            export PATH="$HOME/scoop/shims:$PATH"
            
            # Verify installation
            if command -v jq >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC} jq is now available in current session!"
                return 0
            else
                echo ""
                echo -e "${YELLOW}⚠${NC} jq installed but not available in current session."
                echo "Please close this terminal and open a new one, then run the script again."
                echo ""
                echo -n "Press Enter to exit..."
                read
                exit 0
            fi
        fi
        return 1
    fi
}

# Check dependencies and offer installation help
echo ""
echo "Checking dependencies..."

# Check curl first
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} curl is not installed"
    echo ""
    echo "curl is required for API calls."
    echo ""
    if [ "$IS_WINDOWS" = true ]; then
        echo "  curl is usually pre-installed in Git Bash."
        echo "  If missing, reinstall Git for Windows: https://git-scm.com/download/win"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  macOS: curl is pre-installed"
    else
        echo "  Linux: sudo apt install curl (Debian/Ubuntu)"
        echo "  Linux: sudo dnf install curl (Fedora)"
    fi
    echo ""
    exit 1
fi

# Check jq with auto-install option for Windows
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} jq is not installed"
    echo ""
    echo "jq is required for JSON parsing."
    
    if [ "$IS_WINDOWS" = true ]; then
        echo ""
        echo -n "Would you like to install jq automatically? (y/n): "
        read -r install_choice
        
        if [ "$install_choice" = "y" ] || [ "$install_choice" = "Y" ]; then
            if install_jq_windows; then
                echo ""
                echo -e "${GREEN}✓${NC} Installation complete! Continuing..."
            else
                echo ""
                echo -e "${RED}✗${NC} Automatic installation failed."
                echo ""
                echo "Manual installation options:"
                echo "  1. Run: scoop install jq"
                echo "  2. Download from: https://jqlang.github.io/jq/download/"
                echo ""
                exit 1
            fi
        else
            echo ""
            echo "Please install jq manually:"
            echo "  1. Install Scoop: https://scoop.sh"
            echo "  2. Run: scoop install jq"
            echo "  3. Or download from: https://jqlang.github.io/jq/download/"
            echo ""
            exit 1
        fi
    else
        # Non-Windows systems
        echo ""
        echo "Install jq with:"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  macOS (Homebrew): brew install jq"
        else
            echo "  Linux (Debian/Ubuntu): sudo apt install jq"
            echo "  Linux (Fedora):        sudo dnf install jq"
        fi
        echo ""
        exit 1
    fi
fi

echo -e "${GREEN}✓${NC} All dependencies found"

# Check if token is set
if [ -z "$GITHUB_TOKEN" ]; then
    setup_token
else
    print_info "GitHub token is already set"
    echo -n "Use existing token? (y/n): "
    read -r use_existing
    
    if [ "$use_existing" != "y" ] && [ "$use_existing" != "Y" ]; then
        setup_token
    fi
fi

# Get current user
echo ""
print_info "Authenticating..."
CURRENT_USER=$(get_current_user)

if [ -z "$CURRENT_USER" ]; then
    print_error "Authentication failed! Check your token."
    echo ""
    echo -n "Try again with a different token? (y/n): "
    read -r retry
    if [ "$retry" = "y" ] || [ "$retry" = "Y" ]; then
        setup_token
        CURRENT_USER=$(get_current_user)
        if [ -z "$CURRENT_USER" ]; then
            print_error "Authentication failed again. Exiting."
            exit 1
        fi
    else
        exit 1
    fi
fi

print_success "Authenticated as: $CURRENT_USER"
echo ""
print_info "Rate limit: $RATE_LIMIT_REMAINING requests remaining"

# Main loop
while true; do
    show_menu
    read -r choice
    
    case $choice in
        1)
            print_info "Analyzing followers..."
            get_followers "$CURRENT_USER"
            get_following "$CURRENT_USER"
            
            print_info "Finding users who don't follow back..."
            not_follow_back_file="$TEMP_DIR/not_follow_back.txt"
            > "$not_follow_back_file"
            
            while IFS= read -r user; do
                if ! grep -qix "$user" "$FOLLOWERS_FILE" 2>/dev/null; then
                    echo "$user" >> "$not_follow_back_file"
                fi
            done < "$FOLLOWING_FILE"
            
            count=$(wc -l < "$not_follow_back_file" | tr -d ' ')
            echo ""
            print_warning "You follow $count users who DON'T follow you back:"
            cat "$not_follow_back_file"
            ;;
            
        2)
            print_info "Analyzing followers..."
            get_followers "$CURRENT_USER"
            get_following "$CURRENT_USER"
            
            print_info "Finding followers you don't follow back..."
            dont_follow_back_file="$TEMP_DIR/dont_follow_back.txt"
            > "$dont_follow_back_file"
            
            while IFS= read -r user; do
                if ! grep -qix "$user" "$FOLLOWING_FILE" 2>/dev/null; then
                    echo "$user" >> "$dont_follow_back_file"
                fi
            done < "$FOLLOWERS_FILE"
            
            count=$(wc -l < "$dont_follow_back_file" | tr -d ' ')
            echo ""
            print_warning "$count followers you don't follow back:"
            cat "$dont_follow_back_file"
            ;;
            
        3)
            print_info "Analyzing followers..."
            get_followers "$CURRENT_USER"
            get_following "$CURRENT_USER"
            
            unfollow_list="$TEMP_DIR/to_unfollow.txt"
            > "$unfollow_list"
            
            while IFS= read -r user; do
                if ! grep -qix "$user" "$FOLLOWERS_FILE" 2>/dev/null; then
                    echo "$user" >> "$unfollow_list"
                fi
            done < "$FOLLOWING_FILE"
            
            count=$(wc -l < "$unfollow_list" | tr -d ' ')
            if [ "$count" -eq 0 ]; then
                print_success "All users you follow also follow you back!"
                continue
            fi
            
            echo ""
            print_warning "Found $count users to unfollow"
            echo -n "Dry run first? (y/n): "
            read -r dry_run_choice
            
            dry_run="false"
            [ "$dry_run_choice" = "y" ] && dry_run="true"
            
            processed=0
            while IFS= read -r user; do
                processed=$((processed + 1))
                echo -ne "\rProgress: $processed/$count"
                unfollow_user "$user" "$dry_run"
            done < "$unfollow_list"
            echo ""  # New line
            
            if [ "$dry_run" = "true" ]; then
                echo ""
                echo -n "Execute for real? (y/n): "
                read -r execute_choice
                if [ "$execute_choice" = "y" ]; then
                    processed=0
                    while IFS= read -r user; do
                        processed=$((processed + 1))
                        echo -ne "\rProgress: $processed/$count"
                        unfollow_user "$user" "false"
                    done < "$unfollow_list"
                    echo ""  # New line
                fi
            fi
            ;;
            
        4)
            print_info "Analyzing followers..."
            get_followers "$CURRENT_USER"
            get_following "$CURRENT_USER"
            
            unfollow_list="$TEMP_DIR/to_unfollow.txt"
            > "$unfollow_list"
            
            while IFS= read -r user; do
                if ! grep -qix "$user" "$FOLLOWERS_FILE" 2>/dev/null; then
                    echo "$user" >> "$unfollow_list"
                fi
            done < "$FOLLOWING_FILE"
            
            count=$(wc -l < "$unfollow_list" | tr -d ' ')
            if [ "$count" -eq 0 ]; then
                print_success "All users you follow also follow you back!"
                continue
            fi
            
            echo ""
            print_info "Review and select users to unfollow (one by one):"
            print_info "For each user, choose: (y)es unfollow / (n)o keep / (q)uit"
            echo ""
            
            selected_file="$TEMP_DIR/selected_unfollow.txt"
            > "$selected_file"
            
            current=0
            while IFS= read -r user; do
                current=$((current + 1))
                echo -n "[$current/$count] Unfollow $user? (y/n/q): "
                read -r choice
                case $choice in
                    y|Y)
                        echo "$user" >> "$selected_file"
                        ;;
                    q|Q)
                        break
                        ;;
                esac
            done < "$unfollow_list"
            
            selected_count=$(wc -l < "$selected_file" | tr -d ' ')
            if [ "$selected_count" -eq 0 ]; then
                print_info "No users selected for unfollowing"
                continue
            fi
            
            echo ""
            print_warning "Will unfollow $selected_count users"
            echo -n "Proceed? (y/n): "
            read -r confirm
            
            if [ "$confirm" = "y" ]; then
                processed=0
                while IFS= read -r user; do
                    processed=$((processed + 1))
                    echo -ne "\rProgress: $processed/$selected_count"
                    unfollow_user "$user" "false"
                done < "$selected_file"
                echo ""  # New line
            fi
            ;;
            
        5)
            print_info "Analyzing followers..."
            get_followers "$CURRENT_USER"
            get_following "$CURRENT_USER"
            
            follow_back_list="$TEMP_DIR/to_follow_back.txt"
            > "$follow_back_list"
            
            while IFS= read -r user; do
                if ! grep -qix "$user" "$FOLLOWING_FILE" 2>/dev/null; then
                    echo "$user" >> "$follow_back_list"
                fi
            done < "$FOLLOWERS_FILE"
            
            count=$(wc -l < "$follow_back_list" | tr -d ' ')
            if [ "$count" -eq 0 ]; then
                print_success "You already follow all your followers!"
                continue
            fi
            
            echo ""
            print_warning "Found $count users to follow back"
            echo -n "Dry run first? (y/n): "
            read -r dry_run_choice
            
            dry_run="false"
            [ "$dry_run_choice" = "y" ] && dry_run="true"
            
            processed=0
            while IFS= read -r user; do
                processed=$((processed + 1))
                echo -ne "\rProgress: $processed/$count"
                follow_user "$user" "$dry_run"
            done < "$follow_back_list"
            echo ""  # New line
            
            if [ "$dry_run" = "true" ]; then
                echo ""
                echo -n "Execute for real? (y/n): "
                read -r execute_choice
                if [ "$execute_choice" = "y" ]; then
                    processed=0
                    while IFS= read -r user; do
                        processed=$((processed + 1))
                        echo -ne "\rProgress: $processed/$count"
                        follow_user "$user" "false"
                    done < "$follow_back_list"
                    echo ""  # New line
                fi
            fi
            ;;
            
        6)
            show_rate_limit
            ;;
            
        7)
            setup_token
            print_info "Authenticating with new token..."
            CURRENT_USER=$(get_current_user)
            if [ -z "$CURRENT_USER" ]; then
                print_error "Authentication failed! Token not changed."
            else
                print_success "Authenticated as: $CURRENT_USER"
            fi
            ;;
        
        8)
            print_info "Fetching data..."
            get_followers "$CURRENT_USER"
            get_following "$CURRENT_USER"
            
            follower_count=$(wc -l < "$FOLLOWERS_FILE" | tr -d ' ')
            following_count=$(wc -l < "$FOLLOWING_FILE" | tr -d ' ')
            
            echo ""
            echo "========================================="
            echo "  Debug Information"
            echo "========================================="
            echo "Total followers: $follower_count"
            echo "Total following: $following_count"
            echo ""
            echo "First 5 followers (raw):"
            head -5 "$FOLLOWERS_FILE" | cat -A
            echo ""
            echo "First 5 following (raw):"
            head -5 "$FOLLOWING_FILE" | cat -A
            echo ""
            
            # Find mutual follows
            echo "Checking for mutual follows..."
            mutual_count=0
            while IFS= read -r user; do
                if grep -qix "$user" "$FOLLOWERS_FILE" 2>/dev/null; then
                    echo "  MUTUAL: $user"
                    mutual_count=$((mutual_count + 1))
                fi
            done < "$FOLLOWING_FILE"
            echo ""
            echo "Total mutual follows: $mutual_count"
            echo "========================================="
            ;;
            
        9)
            echo ""
            echo "========================================="
            echo "  AUTO-SYNC MODE"
            echo "========================================="
            print_info "This will:"
            echo "  1. Unfollow users who don't follow you back"
            echo "  2. Follow back your followers"
            echo ""
            echo -n "Dry run first? (y/n): "
            read -r dry_run_choice
            
            dry_run="false"
            [ "$dry_run_choice" = "y" ] && dry_run="true"
            
            # Step 1: Fetch data once
            print_info "Fetching follower data..."
            get_followers "$CURRENT_USER"
            get_following "$CURRENT_USER"
            
            # Step 2: Unfollow non-followers
            echo ""
            echo "========================================="
            echo "  STEP 1: Unfollowing Non-Followers"
            echo "========================================="
            
            unfollow_list="$TEMP_DIR/to_unfollow.txt"
            > "$unfollow_list"
            
            while IFS= read -r user; do
                if ! grep -qix "$user" "$FOLLOWERS_FILE" 2>/dev/null; then
                    echo "$user" >> "$unfollow_list"
                fi
            done < "$FOLLOWING_FILE"
            
            unfollow_count=$(wc -l < "$unfollow_list" | tr -d ' ')
            
            if [ "$unfollow_count" -eq 0 ]; then
                print_success "No users to unfollow - everyone follows you back!"
            else
                print_warning "Found $unfollow_count users to unfollow"
                
                processed=0
                while IFS= read -r user; do
                    processed=$((processed + 1))
                    echo -ne "\rProgress: $processed/$unfollow_count"
                    unfollow_user "$user" "$dry_run"
                done < "$unfollow_list"
                echo ""
                
                if [ "$dry_run" = "false" ]; then
                    print_success "Unfollowed $unfollow_count users"
                else
                    print_warning "[DRY RUN] Would have unfollowed $unfollow_count users"
                fi
            fi
            
            # Step 3: Follow back followers
            echo ""
            echo "========================================="
            echo "  STEP 2: Following Back Your Followers"
            echo "========================================="
            
            # Re-fetch following list if we actually unfollowed people
            if [ "$dry_run" = "false" ] && [ "$unfollow_count" -gt 0 ]; then
                print_info "Refreshing following list..."
                get_following "$CURRENT_USER"
            fi
            
            follow_back_list="$TEMP_DIR/to_follow_back.txt"
            > "$follow_back_list"
            
            while IFS= read -r user; do
                if ! grep -qix "$user" "$FOLLOWING_FILE" 2>/dev/null; then
                    echo "$user" >> "$follow_back_list"
                fi
            done < "$FOLLOWERS_FILE"
            
            follow_count=$(wc -l < "$follow_back_list" | tr -d ' ')
            
            if [ "$follow_count" -eq 0 ]; then
                print_success "No users to follow - you already follow all your followers!"
            else
                print_warning "Found $follow_count users to follow back"
                
                processed=0
                while IFS= read -r user; do
                    processed=$((processed + 1))
                    echo -ne "\rProgress: $processed/$follow_count"
                    follow_user "$user" "$dry_run"
                done < "$follow_back_list"
                echo ""
                
                if [ "$dry_run" = "false" ]; then
                    print_success "Followed back $follow_count users"
                else
                    print_warning "[DRY RUN] Would have followed $follow_count users"
                fi
            fi
            
            # Final summary
            echo ""
            echo "========================================="
            echo "  SYNC COMPLETE"
            echo "========================================="
            if [ "$dry_run" = "true" ]; then
                print_warning "[DRY RUN] Summary:"
                echo "  - Would unfollow: $unfollow_count users"
                echo "  - Would follow: $follow_count users"
                echo ""
                echo -n "Execute for real? (y/n): "
                read -r execute_choice
                
                if [ "$execute_choice" = "y" ]; then
                    echo ""
                    print_info "Executing real sync..."
                    
                    # Unfollow for real
                    if [ "$unfollow_count" -gt 0 ]; then
                        echo ""
                        print_info "Unfollowing $unfollow_count users..."
                        processed=0
                        while IFS= read -r user; do
                            processed=$((processed + 1))
                            echo -ne "\rProgress: $processed/$unfollow_count"
                            unfollow_user "$user" "false"
                        done < "$unfollow_list"
                        echo ""
                        print_success "Unfollowed $unfollow_count users"
                    fi
                    
                    # Refresh following list
                    if [ "$unfollow_count" -gt 0 ]; then
                        get_following "$CURRENT_USER"
                        
                        # Recalculate follow back list
                        > "$follow_back_list"
                        while IFS= read -r user; do
                            if ! grep -qix "$user" "$FOLLOWING_FILE" 2>/dev/null; then
                                echo "$user" >> "$follow_back_list"
                            fi
                        done < "$FOLLOWERS_FILE"
                        follow_count=$(wc -l < "$follow_back_list" | tr -d ' ')
                    fi
                    
                    # Follow back for real
                    if [ "$follow_count" -gt 0 ]; then
                        echo ""
                        print_info "Following back $follow_count users..."
                        processed=0
                        while IFS= read -r user; do
                            processed=$((processed + 1))
                            echo -ne "\rProgress: $processed/$follow_count"
                            follow_user "$user" "false"
                        done < "$follow_back_list"
                        echo ""
                        print_success "Followed back $follow_count users"
                    fi
                    
                    echo ""
                    echo "========================================="
                    print_success "Sync completed successfully!"
                    echo "  - Unfollowed: $unfollow_count users"
                    echo "  - Followed: $follow_count users"
                    echo "========================================="
                fi
            else
                print_success "Sync completed successfully!"
                echo "  - Unfollowed: $unfollow_count users"
                echo "  - Followed: $follow_count users"
                echo "========================================="
            fi
            ;;
        
        0)
            print_success "Goodbye!"
            print_info "Log file saved to: $LOG_FILE"
            exit 0
            ;;
            
        *)
            print_error "Invalid option"
            ;;
    esac
done