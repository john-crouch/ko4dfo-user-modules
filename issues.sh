#!/bin/bash
# Simple Issue Tracking System
# Usage: ./issues.sh [command] [arguments]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUES_FILE="$SCRIPT_DIR/issues.json"

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    exit 1
fi

# Initialize file if it doesn't exist
if [[ ! -f "$ISSUES_FILE" ]]; then
    echo '{"next_id": 1, "issues": []}' > "$ISSUES_FILE"
fi

show_help() {
    cat << EOF
Issue Tracking System

Usage: ./issues.sh <command> [arguments]

Commands:
  add <title> [priority]    Add a new issue (priority: low/medium/high, default: medium)
  list [status]             List issues (status: open/closed/all, default: open)
  show <id>                 Show details of a specific issue
  close <id>                Close an issue
  reopen <id>               Reopen a closed issue
  note <id> <note>          Add a note to an issue
  priority <id> <level>     Set priority (low/medium/high)
  delete <id>               Delete an issue permanently
  summary                   Show summary statistics

Examples:
  ./issues.sh add "Fix login bug" high
  ./issues.sh list
  ./issues.sh close 1
  ./issues.sh note 2 "Investigated - needs more work"
EOF
}

add_issue() {
    local title="$1"
    local priority="${2:-medium}"
    local timestamp=$(date -Iseconds)

    if [[ -z "$title" ]]; then
        echo "Error: Title is required"
        exit 1
    fi

    local next_id=$(jq '.next_id' "$ISSUES_FILE")

    jq --arg title "$title" \
       --arg priority "$priority" \
       --arg timestamp "$timestamp" \
       --argjson id "$next_id" \
       '.issues += [{
         "id": $id,
         "title": $title,
         "status": "open",
         "priority": $priority,
         "created": $timestamp,
         "updated": $timestamp,
         "notes": []
       }] | .next_id += 1' "$ISSUES_FILE" > "$ISSUES_FILE.tmp" && mv "$ISSUES_FILE.tmp" "$ISSUES_FILE"

    echo "Created issue #$next_id: $title"
}

list_issues() {
    local filter="${1:-open}"

    echo ""
    echo "=== Issues ($filter) ==="
    echo ""

    local jq_filter
    case "$filter" in
        open)   jq_filter='select(.status == "open")' ;;
        closed) jq_filter='select(.status == "closed")' ;;
        all)    jq_filter='.' ;;
        *)      jq_filter='select(.status == "open")' ;;
    esac

    local count=$(jq "[.issues[] | $jq_filter] | length" "$ISSUES_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "No issues found."
        return
    fi

    jq -r ".issues[] | $jq_filter | \"#\\(.id) [\\(.priority|ascii_upcase)] [\\(.status|ascii_upcase)] \\(.title)\"" "$ISSUES_FILE"
    echo ""
    echo "Total: $count issue(s)"
}

show_issue() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Error: Issue ID required"
        exit 1
    fi

    local issue=$(jq ".issues[] | select(.id == $id)" "$ISSUES_FILE")

    if [[ -z "$issue" ]]; then
        echo "Error: Issue #$id not found"
        exit 1
    fi

    echo ""
    echo "$issue" | jq -r '"=== Issue #\(.id) ==="'
    echo ""
    echo "$issue" | jq -r '"Title:    \(.title)"'
    echo "$issue" | jq -r '"Status:   \(.status)"'
    echo "$issue" | jq -r '"Priority: \(.priority)"'
    echo "$issue" | jq -r '"Created:  \(.created)"'
    echo "$issue" | jq -r '"Updated:  \(.updated)"'

    local notes_count=$(echo "$issue" | jq '.notes | length')
    if [[ "$notes_count" -gt 0 ]]; then
        echo ""
        echo "Notes:"
        echo "$issue" | jq -r '.notes[] | "  [\(.timestamp)] \(.text)"'
    fi
}

close_issue() {
    local id="$1"
    local timestamp=$(date -Iseconds)

    if [[ -z "$id" ]]; then
        echo "Error: Issue ID required"
        exit 1
    fi

    local exists=$(jq ".issues[] | select(.id == $id)" "$ISSUES_FILE")
    if [[ -z "$exists" ]]; then
        echo "Error: Issue #$id not found"
        exit 1
    fi

    jq --argjson id "$id" --arg timestamp "$timestamp" \
       '(.issues[] | select(.id == $id)) |= (.status = "closed" | .updated = $timestamp)' \
       "$ISSUES_FILE" > "$ISSUES_FILE.tmp" && mv "$ISSUES_FILE.tmp" "$ISSUES_FILE"

    echo "Closed issue #$id"
}

reopen_issue() {
    local id="$1"
    local timestamp=$(date -Iseconds)

    if [[ -z "$id" ]]; then
        echo "Error: Issue ID required"
        exit 1
    fi

    jq --argjson id "$id" --arg timestamp "$timestamp" \
       '(.issues[] | select(.id == $id)) |= (.status = "open" | .updated = $timestamp)' \
       "$ISSUES_FILE" > "$ISSUES_FILE.tmp" && mv "$ISSUES_FILE.tmp" "$ISSUES_FILE"

    echo "Reopened issue #$id"
}

add_note() {
    local id="$1"
    shift
    local note="$*"
    local timestamp=$(date -Iseconds)

    if [[ -z "$id" || -z "$note" ]]; then
        echo "Error: Issue ID and note text required"
        exit 1
    fi

    jq --argjson id "$id" --arg note "$note" --arg timestamp "$timestamp" \
       '(.issues[] | select(.id == $id)) |= (.notes += [{"timestamp": $timestamp, "text": $note}] | .updated = $timestamp)' \
       "$ISSUES_FILE" > "$ISSUES_FILE.tmp" && mv "$ISSUES_FILE.tmp" "$ISSUES_FILE"

    echo "Added note to issue #$id"
}

set_priority() {
    local id="$1"
    local priority="$2"
    local timestamp=$(date -Iseconds)

    if [[ -z "$id" || -z "$priority" ]]; then
        echo "Error: Issue ID and priority required"
        exit 1
    fi

    jq --argjson id "$id" --arg priority "$priority" --arg timestamp "$timestamp" \
       '(.issues[] | select(.id == $id)) |= (.priority = $priority | .updated = $timestamp)' \
       "$ISSUES_FILE" > "$ISSUES_FILE.tmp" && mv "$ISSUES_FILE.tmp" "$ISSUES_FILE"

    echo "Set issue #$id priority to $priority"
}

delete_issue() {
    local id="$1"

    if [[ -z "$id" ]]; then
        echo "Error: Issue ID required"
        exit 1
    fi

    jq --argjson id "$id" '.issues |= map(select(.id != $id))' \
       "$ISSUES_FILE" > "$ISSUES_FILE.tmp" && mv "$ISSUES_FILE.tmp" "$ISSUES_FILE"

    echo "Deleted issue #$id"
}

show_summary() {
    echo ""
    echo "=== Issue Summary ==="
    echo ""

    local total=$(jq '.issues | length' "$ISSUES_FILE")
    local open=$(jq '[.issues[] | select(.status == "open")] | length' "$ISSUES_FILE")
    local closed=$(jq '[.issues[] | select(.status == "closed")] | length' "$ISSUES_FILE")
    local high=$(jq '[.issues[] | select(.status == "open" and .priority == "high")] | length' "$ISSUES_FILE")
    local medium=$(jq '[.issues[] | select(.status == "open" and .priority == "medium")] | length' "$ISSUES_FILE")
    local low=$(jq '[.issues[] | select(.status == "open" and .priority == "low")] | length' "$ISSUES_FILE")

    echo "Total:   $total"
    echo "Open:    $open"
    echo "Closed:  $closed"
    echo ""
    echo "Open by priority:"
    echo "  High:   $high"
    echo "  Medium: $medium"
    echo "  Low:    $low"
}

# Main command dispatch
case "${1:-}" in
    add)      shift; add_issue "$@" ;;
    list)     shift; list_issues "$@" ;;
    show)     shift; show_issue "$@" ;;
    close)    shift; close_issue "$@" ;;
    reopen)   shift; reopen_issue "$@" ;;
    note)     shift; add_note "$@" ;;
    priority) shift; set_priority "$@" ;;
    delete)   shift; delete_issue "$@" ;;
    summary)  show_summary ;;
    help|--help|-h|"") show_help ;;
    *)        echo "Unknown command: $1"; show_help; exit 1 ;;
esac
