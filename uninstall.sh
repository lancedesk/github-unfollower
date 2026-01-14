#!/bin/bash

# Uninstall script for GitHub Follower Manager
# Removes 'followers' command from PATH

COMMAND_NAME="followers"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "========================================="
echo "  GitHub Follower Manager - Uninstaller"
echo "========================================="
echo ""

# Remove from all possible locations
removed=false

if [ -f "$HOME/bin/$COMMAND_NAME" ]; then
    rm -f "$HOME/bin/$COMMAND_NAME"
    echo -e "${GREEN}✓${NC} Removed from ~/bin"
    removed=true
fi

if [ -L "/usr/local/bin/$COMMAND_NAME" ]; then
    rm -f "/usr/local/bin/$COMMAND_NAME" 2>/dev/null || sudo rm -f "/usr/local/bin/$COMMAND_NAME"
    echo -e "${GREEN}✓${NC} Removed from /usr/local/bin"
    removed=true
fi

if [ -L "$HOME/.local/bin/$COMMAND_NAME" ]; then
    rm -f "$HOME/.local/bin/$COMMAND_NAME"
    echo -e "${GREEN}✓${NC} Removed from ~/.local/bin"
    removed=true
fi

if [ "$removed" = false ]; then
    echo -e "${YELLOW}⚠${NC} Command '$COMMAND_NAME' was not found in PATH"
fi

echo ""
echo -e "${YELLOW}Note:${NC} PATH entries in ~/.bashrc were not removed."
echo "      You can manually edit ~/.bashrc if needed."
echo ""
echo "========================================="
echo -e "${GREEN}Uninstall complete!${NC}"
echo "========================================="
