#!/bin/bash

# Install script for GitHub Follower Manager
# Adds 'followers' command to your PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/gh-followers.sh"
COMMAND_NAME="followers"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "========================================="
echo "  GitHub Follower Manager - Installer"
echo "========================================="
echo ""

# Detect OS
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    # Windows (Git Bash)
    echo -e "${YELLOW}Detected: Windows (Git Bash)${NC}"
    
    # Create bin directory if it doesn't exist
    mkdir -p "$HOME/bin"
    
    # Create wrapper script
    cat > "$HOME/bin/$COMMAND_NAME" << EOF
#!/bin/bash
"$SCRIPT_PATH" "\$@"
EOF
    chmod +x "$HOME/bin/$COMMAND_NAME"
    
    # Add to PATH in .bashrc if not already there
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
        echo '' >> "$HOME/.bashrc"
        echo '# Added by GitHub Follower Manager' >> "$HOME/.bashrc"
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        echo -e "${GREEN}✓${NC} Added ~/bin to PATH in ~/.bashrc"
    fi
    
    # Also update current session
    export PATH="$HOME/bin:$PATH"
    
    echo -e "${GREEN}✓${NC} Created command: $COMMAND_NAME"
    echo ""
    echo -e "${YELLOW}To use immediately, run:${NC}"
    echo "  source ~/.bashrc"
    echo ""
    echo -e "${YELLOW}Or restart your terminal, then run:${NC}"
    echo "  $COMMAND_NAME"
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo -e "${YELLOW}Detected: macOS${NC}"
    
    # Check if /usr/local/bin exists and is writable
    if [ -w "/usr/local/bin" ]; then
        ln -sf "$SCRIPT_PATH" "/usr/local/bin/$COMMAND_NAME"
        echo -e "${GREEN}✓${NC} Created symlink in /usr/local/bin"
    else
        # Fall back to ~/bin
        mkdir -p "$HOME/bin"
        ln -sf "$SCRIPT_PATH" "$HOME/bin/$COMMAND_NAME"
        
        # Add to PATH in .zshrc (default shell on modern macOS)
        SHELL_RC="$HOME/.zshrc"
        [ -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.zshrc" ] && SHELL_RC="$HOME/.bashrc"
        
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$SHELL_RC" 2>/dev/null; then
            echo '' >> "$SHELL_RC"
            echo '# Added by GitHub Follower Manager' >> "$SHELL_RC"
            echo 'export PATH="$HOME/bin:$PATH"' >> "$SHELL_RC"
            echo -e "${GREEN}✓${NC} Added ~/bin to PATH in $SHELL_RC"
        fi
        
        echo -e "${GREEN}✓${NC} Created symlink in ~/bin"
    fi
    
    echo ""
    echo -e "${YELLOW}Restart your terminal, then run:${NC}"
    echo "  $COMMAND_NAME"
    
else
    # Linux
    echo -e "${YELLOW}Detected: Linux${NC}"
    
    # Check if /usr/local/bin exists and is writable
    if [ -w "/usr/local/bin" ]; then
        ln -sf "$SCRIPT_PATH" "/usr/local/bin/$COMMAND_NAME"
        echo -e "${GREEN}✓${NC} Created symlink in /usr/local/bin"
    elif [ -w "$HOME/.local/bin" ] || mkdir -p "$HOME/.local/bin" 2>/dev/null; then
        # Use ~/.local/bin (standard user bin on modern Linux)
        mkdir -p "$HOME/.local/bin"
        ln -sf "$SCRIPT_PATH" "$HOME/.local/bin/$COMMAND_NAME"
        
        # Add to PATH in .bashrc if not already there
        if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
            echo '' >> "$HOME/.bashrc"
            echo '# Added by GitHub Follower Manager' >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            echo -e "${GREEN}✓${NC} Added ~/.local/bin to PATH in ~/.bashrc"
        fi
        
        echo -e "${GREEN}✓${NC} Created symlink in ~/.local/bin"
    else
        echo -e "${RED}✗${NC} Could not find writable bin directory"
        echo "  Try running with sudo: sudo ./install.sh"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}Restart your terminal or run:${NC}"
    echo "  source ~/.bashrc"
    echo ""
    echo -e "${YELLOW}Then use:${NC}"
    echo "  $COMMAND_NAME"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Installation complete!${NC}"
echo "========================================="
