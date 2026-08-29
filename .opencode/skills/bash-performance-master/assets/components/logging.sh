# BP_COMPONENT: logging
bp_log() { local level=$1; shift; printf '[%s] %s\n' "$level" "$*" >&2; }
