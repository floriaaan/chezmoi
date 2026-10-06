## --- appssh: real CLI parsing/discovery, fake ssh, no network ---
_appssh_test_repo="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

_appssh_fixture() {
    emulate -L bash 2>/dev/null
    _appssh_tmp=$(mktemp -d)
    mkdir -p "$_appssh_tmp/bin" "$_appssh_tmp/includes with spaces"
    printf 'Host apiexemple-dev apiexemple-recette apiexemple-production\nHost apiexemple-recette-db-tunnel apiexemple-production-db-tunnel\n' > "$_appssh_tmp/includes with spaces/apps.conf"
    printf 'Include "%s/includes with spaces/*.conf" "%s/missing/*.conf"\nHost portail-production\nHost demo-production apidemo-production\nHost wildcard-* !excluded-production\nHost excluded-production !excluded-production\nHost *\n  User nobody\n' "$_appssh_tmp" "$_appssh_tmp" > "$_appssh_tmp/config"
    printf '#!/bin/bash\nprintf "ssh argument: <%%s>\\n" "$@"\nexit "${APPSSH_TEST_SSH_STATUS:-0}"\n' > "$_appssh_tmp/bin/ssh"
    chmod +x "$_appssh_tmp/bin/ssh"
}

_appssh_invoke() {
    PATH="$_appssh_tmp/bin:$PATH" bash -c 'source "$1/appssh.sh"; shift; main "$@"' \
        appssh "$_appssh_test_repo" "$_appssh_tmp/config" "$@"
}

test_appssh_resolution_and_actions() {
    (
        _appssh_fixture
        trap 'rm -rf "$_appssh_tmp"' EXIT
        assert_eq 'ssh argument: <apiexemple-recette>' "$(_appssh_invoke exemple -r)" 'short name resolves from included aliases'
        assert_eq 'ssh argument: <apiexemple-recette-db-tunnel>' "$(_appssh_invoke exemple --recette db)" 'DB resolves its own alias'
        assert_eq 'ssh argument: <portail-production>' "$(_appssh_invoke portail -p 2>/dev/null)" 'no artificial api prefix'
        assert_eq 'ssh argument: <apidemo-production>' "$(_appssh_invoke apidemo -p 2>/dev/null)" 'full name disambiguates'
        local out
        out=$(_appssh_invoke exemple -p logs -n 100 2>&1)
        assert_match '\[production\] apiexemple-production -> pm2 logs --lines 100' "$out" 'production prints target and command'
        assert_match 'ssh argument: <pm2 logs --lines 100>' "$out" 'remote command is one argument'
        assert_match 'ssh argument: <pm2 logs>' "$(_appssh_invoke exemple -r logs)" 'default PM2 logs'
        assert_eq "$(_appssh_invoke exemple -r logs -n 100)" "$(_appssh_invoke exemple -r logs --lines 100)" 'line option aliases'
        APPSSH_TEST_SSH_STATUS=37 _appssh_invoke exemple -r >/dev/null
        assert_eq 37 "$?" 'SSH exit status is preserved'
    )
}

test_appssh_discovery_and_errors() {
    (
        _appssh_fixture
        trap 'rm -rf "$_appssh_tmp"' EXIT
        local out appssh_status
        out=$(_appssh_invoke demo -p 2>&1); appssh_status=$?
        assert_eq 1 "$appssh_status" 'ambiguous aliases fail'
        assert_match 'Ambiguous service "demo"' "$out" 'ambiguity explains the service'
        assert_match 'apidemo-production' "$out" 'ambiguity lists candidates'
        assert_failure 'Host * does not invent aliases' -- _appssh_invoke absent -p
        assert_failure 'wildcard rules are not aliases' -- _appssh_invoke wildcard-any -p
        assert_failure 'negative patterns exclude literals' -- _appssh_invoke excluded -p
        assert_failure 'missing DB tunnel fails' -- _appssh_invoke portail -p db
        assert_failure 'missing environment fails' -- _appssh_invoke exemple
        assert_failure 'conflicting environments fail' -- _appssh_invoke exemple -d -p
        assert_failure 'unknown action fails' -- _appssh_invoke exemple -r reboot
        assert_failure 'line option requires logs' -- _appssh_invoke exemple -r --lines 100
        for invalid in 0 000 -1 1.5 '1;echo bad'; do
            assert_failure "invalid line count: $invalid" -- _appssh_invoke exemple -r logs -n "$invalid"
        done
        out=$(_appssh_invoke exemple --resolve)
        assert_eq 5 "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" 'resolve lists all environments and tunnels'
        assert_match 'apiexemple-production-db-tunnel' "$out" 'resolve includes DB aliases'
        assert_match 'exemple' "$(_appssh_invoke --services)" 'services strips api prefix'
        printf 'Include "%s/config"\n' "$_appssh_tmp" > "$_appssh_tmp/config"
        assert_failure 'Include cycle fails clearly' -- _appssh_invoke exemple -r
    )
}

test_appssh_available_from_shell_module() {
    assert_success 'SSH module exposes appssh' -- declare -f appssh
    assert_match 'Usage:' "$(appssh --help)" 'shell wrapper invokes the Bash CLI'
}

test_appssh_excluded_from_remote_payload() {
    (
        _SSH_CHEZMOI_MODULES="appssh ssh git-aliases"
        local payload
        payload=$(_ssh_build_payload)
        assert_not_match 'appssh' "$payload" 'local CLI and its wrapper are excluded even when explicitly selected'
        assert_match 'alias ga=' "$payload" 'selected remote modules are still included'
    )
}

test_appssh_two_tunnels() {
    (
        _appssh_fixture
        trap 'rm -rf "$_appssh_tmp"' EXIT
        printf 'Host portail-recette-db-tunnel portail-production-db-tunnel\n' >> "$_appssh_tmp/config"
        assert_failure 'both services require db' -- _appssh_invoke exemple portail -r
        assert_failure 'logs accepts only one service' -- _appssh_invoke exemple portail -r logs
        assert_failure 'same alias cannot be launched twice' -- _appssh_invoke exemple apiexemple -r db
        assert_failure 'both aliases must exist' -- _appssh_invoke exemple absent -r db

        cat > "$_appssh_tmp/bin/ssh" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$APPSSH_TEST_EVENTS"
sleep 10 &
hold_pid=$!
trap 'kill "$hold_pid" 2>/dev/null; wait "$hold_pid" 2>/dev/null; printf "stopped %s\n" "${!#}" >> "$APPSSH_TEST_EVENTS"; exit 0' TERM
if [[ "${!#}" == portail-recette-db-tunnel && "$APPSSH_TEST_MODE" == fail ]]; then
    sleep 0.2
    kill "$hold_pid" 2>/dev/null
    wait "$hold_pid" 2>/dev/null
    exit 23
fi
wait "$hold_pid"
EOF
        local cli_pid watchdog_pid pair_status out attempt
        export APPSSH_TEST_EVENTS="$_appssh_tmp/events" APPSSH_TEST_MODE=fail
        PATH="$_appssh_tmp/bin:$PATH" bash -c 'source "$1/appssh.sh"; main "$2" exemple portail -r db' \
            appssh "$_appssh_test_repo" "$_appssh_tmp/config" > "$_appssh_tmp/output" 2>&1 &
        cli_pid=$!
        (sleep 3; kill -TERM "$cli_pid" 2>/dev/null) &
        watchdog_pid=$!
        wait "$cli_pid"; pair_status=$?
        kill "$watchdog_pid" 2>/dev/null
        wait "$watchdog_pid" 2>/dev/null
        assert_eq 23 "$pair_status" 'second tunnel failure stops the first and preserves its exit status'
        out=$(cat "$APPSSH_TEST_EVENTS")
        assert_match 'stopped apiexemple-recette-db-tunnel' "$out" 'remaining tunnel is cleaned up'
        assert_match 'ExitOnForwardFailure=yes' "$out" 'forwarding failures are fatal'
        assert_match '\[db\] portail-recette-db-tunnel' "$(cat "$_appssh_tmp/output")" 'both targets are displayed'

        : > "$APPSSH_TEST_EVENTS"
        APPSSH_TEST_MODE=hold
        PATH="$_appssh_tmp/bin:$PATH" bash -c 'source "$1/appssh.sh"; main "$2" exemple portail -p db' \
            appssh "$_appssh_test_repo" "$_appssh_tmp/config" > "$_appssh_tmp/output" 2>&1 &
        cli_pid=$!
        for attempt in 1 2 3 4 5 6 7 8 9 10; do
            [ "$(wc -l < "$APPSSH_TEST_EVENTS" | tr -d ' ')" -ge 2 ] && break
            sleep 0.1
        done
        kill -TERM "$cli_pid"
        wait "$cli_pid"; pair_status=$?
        assert_eq 143 "$pair_status" 'termination stops the tunnel command'
        out=$(cat "$APPSSH_TEST_EVENTS")
        assert_match 'stopped apiexemple-production-db-tunnel' "$out" 'termination cleans up first tunnel'
        assert_match 'stopped portail-production-db-tunnel' "$out" 'termination cleans up second tunnel'
        assert_match '\[production\] portail-production-db-tunnel' "$(cat "$_appssh_tmp/output")" 'production displays both tunnel targets'
    )
}
