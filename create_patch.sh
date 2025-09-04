#!/bin/bash

# Script to create a patch file from staged files and verify it can be applied

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default patch filename with timestamp
PATCH_FILE="patch_$(date +%Y%m%d_%H%M%S).patch"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            PATCH_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [-o|--output filename.patch]"
            echo "Creates a patch file from staged Git files and validates it"
            echo ""
            echo "Options:"
            echo "  -o, --output    Specify output patch filename (default: patch_YYYYMMDD_HHMMSS.patch)"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${YELLOW}Creating patch from staged files...${NC}"

# Check if there are any staged files
if ! git diff --cached --quiet; then
    # Store current git config if needed
    NEED_CONFIG=false
    if ! git config user.email > /dev/null 2>&1; then
        NEED_CONFIG=true
        git config user.email "patch@generator.local"
        git config user.name "Patch Generator"
    fi
    
    # Create a temporary commit to use format-patch
    COMMIT_MESSAGE="Temporary patch commit $(date +%s)"
    git commit -m "$COMMIT_MESSAGE" --no-verify --quiet
    
    if [ $? -eq 0 ]; then
        # Generate the patch using format-patch (more robust than diff)
        git format-patch -1 HEAD --stdout > "$PATCH_FILE"
        
        # Reset the temporary commit
        git reset --soft HEAD~1 --quiet
        
        # Clean up git config if we set it
        if [ "$NEED_CONFIG" = true ]; then
            git config --unset user.email
            git config --unset user.name
        fi
        
        if [ -s "$PATCH_FILE" ]; then
            echo -e "${GREEN}✓ Patch created: $PATCH_FILE${NC}"
            echo "  Size: $(du -h "$PATCH_FILE" | cut -f1)"
            echo "  Lines: $(wc -l < "$PATCH_FILE")"
            
            # Show files included in the patch
            echo -e "\n${YELLOW}Files included in patch:${NC}"
            git diff --cached --name-status | while read status file; do
                case $status in
                    A) echo -e "  ${GREEN}+ $file (added)${NC}" ;;
                    M) echo -e "  ${YELLOW}⚡ $file (modified)${NC}" ;;
                    D) echo -e "  ${RED}- $file (deleted)${NC}" ;;
                    R*) echo -e "  ${YELLOW}↻ $file (renamed)${NC}" ;;
                    *) echo "  $status $file" ;;
                esac
            done
            
            echo -e "\n${YELLOW}Validating patch...${NC}"
            
            # Test if the patch can be applied cleanly
            # First, reverse apply to simulate clean state, then check forward apply
            git apply --check --reverse "$PATCH_FILE" 2>/dev/null
            if [ $? -eq 0 ]; then
                # The patch can be reversed, meaning current state matches the "after" state
                echo -e "${GREEN}✓ Patch validation successful${NC}"
                echo "  The patch can be cleanly applied to the base branch"
                
                # Additional validation: check for whitespace errors
                git apply --check --whitespace=warn "$PATCH_FILE" 2>/dev/null
                if [ $? -ne 0 ]; then
                    echo -e "${YELLOW}⚠ Warning: Patch contains whitespace issues${NC}"
                    git apply --check --whitespace=warn "$PATCH_FILE" 2>&1 | grep "trailing whitespace" | head -5 | sed 's/^/  /'
                fi
            else
                # Try forward apply check as fallback
                git apply --check "$PATCH_FILE" 2>/dev/null
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Patch validation successful${NC}"
                    echo "  The patch can be applied to the current working tree"
                else
                    echo -e "${YELLOW}⚠ Patch created but cannot be validated${NC}"
                    echo "  This is normal if the changes are already in your working tree"
                fi
            fi
            
            echo -e "\n${GREEN}To apply this patch later, use:${NC}"
            echo "  git am $PATCH_FILE"
            echo ""
            echo -e "${GREEN}Or with git apply (if there are conflicts):${NC}"
            echo "  git apply --3way $PATCH_FILE"
            
        else
            echo -e "${RED}✗ Failed to create patch${NC}"
            # Clean up git config if we set it
            if [ "$NEED_CONFIG" = true ]; then
                git config --unset user.email
                git config --unset user.name
            fi
            exit 1
        fi
    else
        echo -e "${RED}✗ Failed to create temporary commit${NC}"
        # Clean up git config if we set it
        if [ "$NEED_CONFIG" = true ]; then
            git config --unset user.email
            git config --unset user.name
        fi
        exit 1
    fi
else
    echo -e "${YELLOW}No staged files found!${NC}"
    echo "Stage files first with: git add <files>"
    echo ""
    echo "Current status:"
    git status --short
    exit 1
fi