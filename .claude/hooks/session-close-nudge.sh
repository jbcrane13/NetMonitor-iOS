#!/bin/bash
# Session close nudge — fires on Stop, checks for uncommitted work and stale ADR.
# Returns a reminder if there are things to do before closing the session.
set -euo pipefail

CWD=$(cat | jq -r '.cwd // "."')
cd "$CWD" 2>/dev/null || exit 0

# Only run in git repos
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

REMINDERS=""

# Check for uncommitted changes (staged or unstaged, excluding .beads/)
DIRTY=$(git status --porcelain 2>/dev/null | grep -v '^\s*[?!]' | grep -v '.beads/' | head -5)
if [ -n "$DIRTY" ]; then
  REMINDERS="${REMINDERS}\n- Uncommitted code changes detected. Run /session-close before ending."
fi

# Check for unpushed commits
UNPUSHED=$(git log @{u}..HEAD --oneline 2>/dev/null | head -3)
if [ -n "$UNPUSHED" ]; then
  REMINDERS="${REMINDERS}\n- $(echo "$UNPUSHED" | wc -l | tr -d ' ') unpushed commit(s). Remember to push."
fi

# Check if ADR exists and whether it was modified this session (in the last 2 hours)
ADR_FILE="docs/ADR.md"
if [ -f "$ADR_FILE" ]; then
  # Check if ADR was modified in any unpushed commits or working tree
  ADR_IN_DIFF=$(git diff HEAD --name-only 2>/dev/null | grep -c "ADR.md" || true)
  ADR_IN_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -c "ADR.md" || true)
  ADR_IN_LOG=$(git log @{u}..HEAD --name-only --pretty=format: 2>/dev/null | grep -c "ADR.md" || true)

  if [ "$ADR_IN_DIFF" -eq 0 ] && [ "$ADR_IN_STAGED" -eq 0 ] && [ "$ADR_IN_LOG" -eq 0 ]; then
    # ADR not touched — only nudge if there were actual code commits this session
    CODE_COMMITS=$(git log @{u}..HEAD --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CODE_COMMITS" -gt 0 ]; then
      REMINDERS="${REMINDERS}\n- docs/ADR.md not updated this session. Consider adding ADR entries for any architectural decisions."
    fi
  fi
fi

# Check for open beads
if command -v bd &>/dev/null; then
  IN_PROGRESS=$(bd list --status=in_progress 2>/dev/null | grep -c "●" || true)
  if [ "$IN_PROGRESS" -gt 0 ]; then
    REMINDERS="${REMINDERS}\n- $IN_PROGRESS bead(s) still in_progress. Close or update them."
  fi
fi

if [ -n "$REMINDERS" ]; then
  echo "Session close reminder:${REMINDERS}"
fi
