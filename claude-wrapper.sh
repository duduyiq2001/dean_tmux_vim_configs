#!/usr/bin/env bash
# Claude Code wrapper script to prevent alternate screen buffer issues in tmux
# This keeps all Claude Code output in tmux scrollback history

set -euo pipefail

# Check if we're in tmux
if [[ -z "${TMUX:-}" ]]; then
    echo "Warning: Not running in tmux. Running Claude Code directly."
    exec claude "$@"
fi

# Disable alternate screen buffer for Claude Code
# This prevents the text disappearing issue in tmux
export TERM_PROGRAM_VERSION=""
export TERM_FEATURES=""

# Force terminal to behave like a simple terminal without alternate screen support
# This makes Claude Code output stay in scrollback buffer
exec env TERM=vt100 claude --no-alternate-screen "$@" 2>/dev/null || \
exec env TERM=xterm claude "$@"