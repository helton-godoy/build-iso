# BP_COMPONENT: tempdir
BP_TMPDIR=
bp_make_tempdir() {
    local base=${TMPDIR:-/tmp}
    BP_TMPDIR=$(mktemp -d "${base%/}/bp.XXXXXXXX") || return
    declare -F bp_cleanup >/dev/null || trap bp_remove_tempdir EXIT
}
bp_remove_tempdir() {
    local status=$?
    trap - EXIT
    if [[ -n ${BP_TMPDIR:-} && -d $BP_TMPDIR ]]; then rm -rf -- "$BP_TMPDIR"; fi
    BP_TMPDIR=
    return "$status"
}
