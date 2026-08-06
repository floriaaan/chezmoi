## --- Mini harness de test, pure bash/zsh, zero dépendance ---

_TEST_OK='\033[38;5;108m'
_TEST_ERR='\033[38;5;196m'
_TEST_RESET='\033[0m'

_t_pass=0
_t_fail=0

assert_eq() {
    emulate -L bash 2>/dev/null
    local expected="$1" actual="$2" msg="${3:-}"
    if [ "$expected" = "$actual" ]; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _t_pass=$((_t_pass + 1))
    else
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} (attendu: '${expected}', obtenu: '${actual}')"
        _t_fail=$((_t_fail + 1))
    fi
}

assert_match() {
    emulate -L bash 2>/dev/null
    local pattern="$1" string="$2" msg="${3:-}"
    if [[ "$string" =~ $pattern ]]; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _t_pass=$((_t_pass + 1))
    else
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} ('${string}' ne matche pas '${pattern}')"
        _t_fail=$((_t_fail + 1))
    fi
}

assert_success() {
    emulate -L bash 2>/dev/null
    local msg="$1"; shift
    [ "$1" = "--" ] && shift
    if "$@" >/dev/null 2>&1; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _t_pass=$((_t_pass + 1))
    else
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} (exit != 0: $*)"
        _t_fail=$((_t_fail + 1))
    fi
}

assert_failure() {
    emulate -L bash 2>/dev/null
    local msg="$1"; shift
    [ "$1" = "--" ] && shift
    if ! "$@" >/dev/null 2>&1; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} ${msg}"
        _t_pass=$((_t_pass + 1))
    else
        printf "%b\n" "${_TEST_ERR}not ok${_TEST_RESET} ${msg} (exit == 0, attendu échec: $*)"
        _t_fail=$((_t_fail + 1))
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
    printf "%b\n" "${_TEST_OK}${_t_pass} passed${_TEST_RESET}, ${_TEST_ERR}${_t_fail} failed${_TEST_RESET}"
    [ "$_t_fail" -eq 0 ]
}
