# BP_COMPONENT: require-command
bp_require_command() { local name; for name in "$@"; do command -v "$name" >/dev/null 2>&1 || { printf 'Required command not found: %s\n' "$name" >&2; return 69; }; done; }
