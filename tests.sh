#!/bin/bash
#############################################
# USER MODULES TEST SUITE
# Tests all QRV user modules for correctness
#############################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Source station info
source $HOME/.station-info 2>/dev/null || {
    echo -e "${RED}ERROR: Cannot source ~/.station-info${NC}"
    exit 1
}

# Paths
ARCOS_DATA=/arcHIVE
MODULE_BASE=$ARCOS_DATA/QRV/$MYCALL/arcos-linux-modules/USER/ko4dfo-user-modules
SAVE_BASE=$ARCOS_DATA/QRV/$MYCALL/SAVED

#############################################
# TEST FRAMEWORK
#############################################

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW} $1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

assert_file_exists() {
    ((TESTS_RUN++))
    if [ -f "$1" ]; then
        log_pass "File exists: $1"
        return 0
    else
        log_fail "File missing: $1"
        return 1
    fi
}

assert_dir_exists() {
    ((TESTS_RUN++))
    if [ -d "$1" ]; then
        log_pass "Directory exists: $1"
        return 0
    else
        log_fail "Directory missing: $1"
        return 1
    fi
}

assert_executable() {
    ((TESTS_RUN++))
    if [ -x "$1" ]; then
        log_pass "Executable: $1"
        return 0
    else
        log_fail "Not executable: $1"
        return 1
    fi
}

assert_symlink() {
    ((TESTS_RUN++))
    if [ -L "$1" ]; then
        local target=$(readlink "$1")
        log_pass "Symlink: $1 -> $target"
        return 0
    else
        log_fail "Not a symlink: $1"
        return 1
    fi
}

assert_symlink_target() {
    ((TESTS_RUN++))
    if [ -L "$1" ]; then
        local actual=$(readlink "$1")
        if [ "$actual" = "$2" ]; then
            log_pass "Symlink target correct: $1 -> $2"
            return 0
        else
            log_fail "Symlink target wrong: $1 -> $actual (expected $2)"
            return 1
        fi
    else
        log_fail "Not a symlink: $1"
        return 1
    fi
}

assert_command_exists() {
    ((TESTS_RUN++))
    if command -v "$1" &> /dev/null; then
        log_pass "Command available: $1"
        return 0
    else
        log_fail "Command missing: $1"
        return 1
    fi
}

assert_contains() {
    ((TESTS_RUN++))
    if grep -q "$2" "$1" 2>/dev/null; then
        log_pass "File $1 contains: $2"
        return 0
    else
        log_fail "File $1 missing: $2"
        return 1
    fi
}

assert_gsetting() {
    ((TESTS_RUN++))
    local actual=$(gsettings get "$1" "$2" 2>/dev/null | tr -d "'")
    if [ "$actual" = "$3" ]; then
        log_pass "gsetting $1 $2 = $3"
        return 0
    else
        log_fail "gsetting $1 $2 = $actual (expected $3)"
        return 1
    fi
}

#############################################
# PRE-FLIGHT CHECKS
#############################################

test_preflight() {
    log_section "PRE-FLIGHT CHECKS"

    log_test "Checking station info..."
    ((TESTS_RUN++))
    if [ -n "$MYCALL" ]; then
        log_pass "MYCALL is set: $MYCALL"
    else
        log_fail "MYCALL not set"
    fi

    assert_dir_exists "$MODULE_BASE"
    assert_dir_exists "$SAVE_BASE"
    assert_file_exists "$HOME/.station-info"
}

#############################################
# PAT-WEBVIEW MODULE TESTS
#############################################

test_pat_webview_structure() {
    log_section "PAT-WEBVIEW: Module Structure"

    local MODULE_DIR=$MODULE_BASE/PAT-WEBVIEW

    assert_file_exists "$MODULE_DIR/PAT-WEBVIEW.sh"
    assert_executable "$MODULE_DIR/PAT-WEBVIEW.sh"
    assert_file_exists "$MODULE_DIR/pat-webview.desktop"
    assert_dir_exists "$MODULE_DIR/bin"
    assert_file_exists "$MODULE_DIR/bin/pat-webview"
    assert_executable "$MODULE_DIR/bin/pat-webview"
}

test_pat_webview_script() {
    log_section "PAT-WEBVIEW: Script Validation"

    local SCRIPT=$MODULE_BASE/PAT-WEBVIEW/PAT-WEBVIEW.sh

    # Check script contains correct path
    assert_contains "$SCRIPT" "ko4dfo-user-modules"
    assert_contains "$SCRIPT" 'source $HOME/.station-info'
    assert_contains "$SCRIPT" "MODULE_DIR="
}

test_pat_webview_installed() {
    log_section "PAT-WEBVIEW: Installation State"

    # Check if installed correctly
    if [ -f /opt/arcOS/bin/pat-webview ]; then
        assert_executable "/opt/arcOS/bin/pat-webview"
    else
        log_skip "pat-webview not installed in /opt/arcOS/bin/"
    fi

    assert_file_exists "$HOME/.local/share/applications/pat-webview.desktop"
}

#############################################
# VSCODIUM MODULE TESTS
#############################################

test_vscodium_structure() {
    log_section "VSCODIUM: Module Structure"

    local MODULE_DIR=$MODULE_BASE/VSCODIUM

    assert_file_exists "$MODULE_DIR/VSCODIUM.sh"
    assert_executable "$MODULE_DIR/VSCODIUM.sh"
    assert_dir_exists "$MODULE_DIR/bin"
}

test_vscodium_script() {
    log_section "VSCODIUM: Script Validation"

    local SCRIPT=$MODULE_BASE/VSCODIUM/VSCODIUM.sh

    assert_contains "$SCRIPT" "ko4dfo-user-modules"
    assert_contains "$SCRIPT" '.config/VSCodium'
    assert_contains "$SCRIPT" '.vscode-oss/extensions'
}

test_vscodium_persistence() {
    log_section "VSCODIUM: Persistence Configuration"

    local SAVE_DIR=$SAVE_BASE/VSCODIUM

    # Check save directory exists
    assert_dir_exists "$SAVE_DIR"

    # Check config symlink
    if [ -e "$HOME/.config/VSCodium" ]; then
        assert_symlink "$HOME/.config/VSCodium"
        assert_symlink_target "$HOME/.config/VSCodium" "$SAVE_DIR"
    else
        log_skip "VSCodium config not set up"
    fi

    # Check extensions symlink
    if [ -e "$HOME/.vscode-oss/extensions" ]; then
        assert_symlink "$HOME/.vscode-oss/extensions"
        assert_symlink_target "$HOME/.vscode-oss/extensions" "$SAVE_DIR/extensions"
    else
        log_skip "VSCodium extensions not set up"
    fi
}

test_vscodium_extensions() {
    log_section "VSCODIUM: Extensions"

    local EXT_DIR=$SAVE_BASE/VSCODIUM/extensions

    if [ -d "$EXT_DIR" ]; then
        # Check Claude Code extension exists
        ((TESTS_RUN++))
        if ls "$EXT_DIR"/anthropic.claude-code-* &>/dev/null; then
            log_pass "Claude Code extension present"
        else
            log_fail "Claude Code extension missing"
        fi
    else
        log_skip "Extensions directory not found"
    fi
}

#############################################
# CLAUDE-CODE MODULE TESTS
#############################################

test_claude_code_structure() {
    log_section "CLAUDE-CODE: Module Structure"

    local MODULE_DIR=$MODULE_BASE/CLAUDE-CODE

    assert_file_exists "$MODULE_DIR/CLAUDE-CODE.sh"
    assert_executable "$MODULE_DIR/CLAUDE-CODE.sh"
    assert_dir_exists "$MODULE_DIR/bin"
    assert_file_exists "$MODULE_DIR/bin/save-claude-code.sh"
    assert_dir_exists "$MODULE_DIR/packages"
}

test_claude_code_script() {
    log_section "CLAUDE-CODE: Script Validation"

    local SCRIPT=$MODULE_BASE/CLAUDE-CODE/CLAUDE-CODE.sh

    assert_contains "$SCRIPT" "ko4dfo-user-modules"
    assert_contains "$SCRIPT" 'command -v claude'
    assert_contains "$SCRIPT" '.claude'

    # Check for skip-if-installed optimization
    ((TESTS_RUN++))
    if grep -q "Claude Code already installed" "$SCRIPT"; then
        log_pass "Script has skip-if-installed optimization"
    else
        log_fail "Script missing skip-if-installed optimization"
    fi
}

test_claude_code_cached_package() {
    log_section "CLAUDE-CODE: Cached Package"

    local CACHE_DIR=$MODULE_BASE/CLAUDE-CODE/packages

    ((TESTS_RUN++))
    if ls "$CACHE_DIR"/anthropic-ai-claude-code-*.tgz &>/dev/null; then
        local PKG=$(ls "$CACHE_DIR"/anthropic-ai-claude-code-*.tgz | head -1)
        local SIZE=$(stat -c%s "$PKG")
        log_pass "Cached package exists: $(basename $PKG) (${SIZE} bytes)"
    else
        log_fail "No cached package found"
    fi
}

test_claude_code_installation() {
    log_section "CLAUDE-CODE: Installation State"

    assert_command_exists "claude"

    # Check version
    ((TESTS_RUN++))
    local VERSION=$(claude --version 2>/dev/null | head -1)
    if [ -n "$VERSION" ]; then
        log_pass "Claude Code version: $VERSION"
    else
        log_fail "Could not get Claude Code version"
    fi
}

test_claude_code_persistence() {
    log_section "CLAUDE-CODE: Persistence Configuration"

    local SAVE_DIR=$SAVE_BASE/CLAUDE-CODE

    assert_dir_exists "$SAVE_DIR"

    # Check ~/.claude symlink
    if [ -e "$HOME/.claude" ]; then
        assert_symlink "$HOME/.claude"
        assert_symlink_target "$HOME/.claude" "$SAVE_DIR"
    else
        log_skip "Claude config not set up"
    fi

    # Check credentials are persisted
    if [ -f "$SAVE_DIR/.credentials.json" ]; then
        assert_file_exists "$SAVE_DIR/.credentials.json"
    else
        log_skip "No credentials saved yet"
    fi
}

#############################################
# SET-MINT-THEME MODULE TESTS
#############################################

test_set_mint_theme_structure() {
    log_section "SET-MINT-THEME: Module Structure"

    local MODULE_DIR=$MODULE_BASE/SET-MINT-THEME

    assert_file_exists "$MODULE_DIR/SET-MINT-THEME.sh"
    assert_executable "$MODULE_DIR/SET-MINT-THEME.sh"
    assert_dir_exists "$MODULE_DIR/bin"
    assert_file_exists "$MODULE_DIR/bin/save-theme"
    assert_file_exists "$MODULE_DIR/save-theme.desktop"
}

test_set_mint_theme_script() {
    log_section "SET-MINT-THEME: Script Validation"

    local SCRIPT=$MODULE_BASE/SET-MINT-THEME/SET-MINT-THEME.sh

    assert_contains "$SCRIPT" "ko4dfo-user-modules"
    assert_contains "$SCRIPT" "gsettings set"
    assert_contains "$SCRIPT" "theme.conf"
}

test_set_mint_theme_cursor() {
    log_section "SET-MINT-THEME: Cursor Theme"

    local MODULE_DIR=$MODULE_BASE/SET-MINT-THEME

    # Check cursor theme exists in module
    assert_dir_exists "$MODULE_DIR/Bibata-Modern-Amber"

    # Check cursor installed system-wide
    if [ -d /usr/share/icons/Bibata-Modern-Amber ]; then
        assert_dir_exists "/usr/share/icons/Bibata-Modern-Amber"
    else
        log_skip "Cursor theme not installed system-wide"
    fi
}

test_set_mint_theme_persistence() {
    log_section "SET-MINT-THEME: Persistence Configuration"

    local SAVE_DIR=$SAVE_BASE/SET-MINT-THEME

    assert_dir_exists "$SAVE_DIR"
    assert_file_exists "$SAVE_DIR/theme.conf"

    # Validate theme.conf has required keys
    assert_contains "$SAVE_DIR/theme.conf" "GTK_THEME="
    assert_contains "$SAVE_DIR/theme.conf" "ICON_THEME="
    assert_contains "$SAVE_DIR/theme.conf" "CINNAMON_THEME="
    assert_contains "$SAVE_DIR/theme.conf" "CURSOR_THEME="
}

test_set_mint_theme_save_utility() {
    log_section "SET-MINT-THEME: Save Utility"

    # Check save-theme is installed
    if [ -f /opt/arcOS/bin/save-theme ]; then
        assert_executable "/opt/arcOS/bin/save-theme"
    else
        log_skip "save-theme not installed in /opt/arcOS/bin/"
    fi

    assert_file_exists "$HOME/.local/share/applications/save-theme.desktop"
}

#############################################
# ENABLED_MODULES TESTS
#############################################

test_enabled_modules() {
    log_section "ENABLED_MODULES Configuration"

    local ENABLED=$MODULE_BASE/ENABLED_MODULES

    assert_file_exists "$ENABLED"

    # Check each enabled module exists
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        local MODULE_NAME="${line%.sh}"
        ((TESTS_RUN++))
        if [ -d "$MODULE_BASE/$MODULE_NAME" ]; then
            log_pass "Enabled module exists: $MODULE_NAME"
        else
            log_fail "Enabled module missing: $MODULE_NAME"
        fi
    done < "$ENABLED"
}

#############################################
# INTEGRATION TESTS
#############################################

test_module_execution() {
    log_section "MODULE EXECUTION (Dry Run)"

    # Test that each module script can be parsed without errors
    for MODULE_DIR in $MODULE_BASE/*/; do
        MODULE_NAME=$(basename "$MODULE_DIR")
        [[ "$MODULE_NAME" == ".git" ]] && continue
        [[ "$MODULE_NAME" == "HANDOVER" ]] && continue

        SCRIPT="$MODULE_DIR/$MODULE_NAME.sh"
        if [ -f "$SCRIPT" ]; then
            ((TESTS_RUN++))
            if bash -n "$SCRIPT" 2>/dev/null; then
                log_pass "Syntax OK: $MODULE_NAME.sh"
            else
                log_fail "Syntax error: $MODULE_NAME.sh"
            fi
        fi
    done
}

#############################################
# MAIN TEST RUNNER
#############################################

run_all_tests() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     USER MODULES TEST SUITE            ║${NC}"
    echo -e "${BLUE}║     Station: $MYCALL                      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

    # Pre-flight
    test_preflight

    # PAT-WEBVIEW tests
    test_pat_webview_structure
    test_pat_webview_script
    test_pat_webview_installed

    # VSCODIUM tests
    test_vscodium_structure
    test_vscodium_script
    test_vscodium_persistence
    test_vscodium_extensions

    # CLAUDE-CODE tests
    test_claude_code_structure
    test_claude_code_script
    test_claude_code_cached_package
    test_claude_code_installation
    test_claude_code_persistence

    # SET-MINT-THEME tests
    test_set_mint_theme_structure
    test_set_mint_theme_script
    test_set_mint_theme_cursor
    test_set_mint_theme_persistence
    test_set_mint_theme_save_utility

    # Configuration tests
    test_enabled_modules

    # Integration tests
    test_module_execution

    # Summary
    log_section "TEST SUMMARY"
    echo ""
    echo -e "  Tests Run:    ${BLUE}$TESTS_RUN${NC}"
    echo -e "  Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
    exit $?
fi
