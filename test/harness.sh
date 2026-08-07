## --- Mini harness de test, pure bash/zsh, zero dépendance ---

_TEST_OK='\033[38;5;108m'
_TEST_ERR='\033[38;5;196m'
_TEST_RESET='\033[0m'

## Beaucoup de tests s'isolent dans un sous-shell "( ... )" (cd temporaire, overrides de fonctions...).
## Un compteur en mémoire (_t_pass/_t_fail) ne survit pas à ce sous-shell : on tallie donc sur disque,
## seul mécanisme qui traverse fork() de façon fiable.
_TEST_TALLY_FILE=$(mktemp)
: > "$_TEST_TALLY_FILE"

_test_tally() {
    printf '%s\n' "$1" >> "$_TEST_TALLY_FILE"
}

assert_eq() {
    emulate -L bash 2>/dev/null
    local expected="$1" actual="$2" msg="${3:-}"
    if [ "$expected" = "$actual" ]; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _test_tally P
    else
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} (attendu: '${expected}', obtenu: '${actual}')"
        _test_tally F
    fi
}

assert_match() {
    emulate -L bash 2>/dev/null
    local pattern="$1" string="$2" msg="${3:-}"
    if [[ "$string" =~ $pattern ]]; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _test_tally P
    else
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} ('${string}' ne matche pas '${pattern}')"
        _test_tally F
    fi
}

assert_not_match() {
    emulate -L bash 2>/dev/null
    local pattern="$1" string="$2" msg="${3:-}"
    if [[ "$string" =~ $pattern ]]; then
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} ('${string}' matche '${pattern}', ne devrait pas)"
        _test_tally F
    else
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _test_tally P
    fi
}

assert_success() {
    emulate -L bash 2>/dev/null
    local msg="$1"; shift
    [ "$1" = "--" ] && shift
    if "$@" >/dev/null 2>&1; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _test_tally P
    else
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} (exit != 0: $*)"
        _test_tally F
    fi
}

assert_failure() {
    emulate -L bash 2>/dev/null
    local msg="$1"; shift
    [ "$1" = "--" ] && shift
    if ! "$@" >/dev/null 2>&1; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _test_tally P
    else
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} (exit == 0, attendu échec: $*)"
        _test_tally F
    fi
}

run_test() {
    emulate -L bash 2>/dev/null
    local name="$1"
    printf "%b\n" "${_TEST_OK}# ${name}${_TEST_RESET}"
    "$name"
}

_test_report_summary() {
    emulate -L bash 2>/dev/null
    local pass fail
    pass=$(grep -c '^P$' "$_TEST_TALLY_FILE" 2>/dev/null)
    fail=$(grep -c '^F$' "$_TEST_TALLY_FILE" 2>/dev/null)
    pass=${pass:-0}
    fail=${fail:-0}
    printf "%b\n" "${_TEST_OK}${pass} passed${_TEST_RESET}, ${_TEST_ERR}${fail} failed${_TEST_RESET}"
    rm -f "$_TEST_TALLY_FILE"
    [ "$fail" -eq 0 ]
}
