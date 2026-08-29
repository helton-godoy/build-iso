# BP_COMPONENT: retry
bp_retry() { local attempts=$1 delay=$2 status=0; shift 2; ((attempts > 0)) || return 64; while ((attempts-- > 0)); do "$@" && return 0; status=$?; ((attempts == 0)) || sleep "$delay"; done; return "$status"; }
