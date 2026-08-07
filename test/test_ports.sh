## --- Tests: ports.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/ports.sh"

test_ports_parse_ss_basic() {
    local out expected
    out=$(printf 'tcp   LISTEN 0      128    127.0.0.1:5432     0.0.0.0:*     users:(("postgres",pid=1204,fd=6))\n' | _ports_parse_ss)
    expected=$(printf 'tcp\t5432\tpostgres\t1204')
    assert_eq "$expected" "$out" "parse ss: proto/port/process/pid"
}

test_ports_parse_ss_ipv6_port() {
    local out expected
    out=$(printf 'tcp   LISTEN 0      128    [::]:3000     [::]:*     users:(("node",pid=48213,fd=23))\n' | _ports_parse_ss)
    expected=$(printf 'tcp\t3000\tnode\t48213')
    assert_eq "$expected" "$out" "parse ss: port extrait correctement d'une adresse IPv6"
}

test_ports_parse_ss_no_process_info() {
    local out expected
    out=$(printf 'udp   UNCONN 0      0      0.0.0.0:68     0.0.0.0:*\n' | _ports_parse_ss)
    expected=$(printf 'udp\t68\t-\t-')
    assert_eq "$expected" "$out" "parse ss: sans droits (pas de process) -> '-'"
}

test_ports_parse_netstat_tcp() {
    local out expected
    out=$(printf 'tcp    0    0 127.0.0.1:5432    0.0.0.0:*    LISTEN    1204/postgres\n' | _ports_parse_netstat)
    expected=$(printf 'tcp\t5432\tpostgres\t1204')
    assert_eq "$expected" "$out" "parse netstat: tcp (colonne State présente)"
}

test_ports_parse_netstat_udp_shifted_columns() {
    local out expected
    out=$(printf 'udp    0    0 0.0.0.0:68    0.0.0.0:*    892/dhcpcd\n' | _ports_parse_netstat)
    expected=$(printf 'udp\t68\tdhcpcd\t892')
    assert_eq "$expected" "$out" "parse netstat: udp (pas de colonne State, décalage géré)"
}

test_ports_filters_by_exact_port() {
    (
        _ports_fetch_raw() {
            printf 'tcp\t3000\tnode\t111\n'
            printf 'tcp\t5432\tpostgres\t222\n'
        }
        local out
        out=$(ports 3000)
        assert_match "node" "$out" "ports 3000 affiche node"
        assert_not_match "postgres" "$out" "ports 3000 n'affiche pas postgres"
    )
}

test_ports_filters_by_process_name() {
    (
        _ports_fetch_raw() {
            printf 'tcp\t3000\tnode\t111\n'
            printf 'tcp\t5432\tpostgres\t222\n'
        }
        local out
        out=$(ports postgres)
        assert_match "5432" "$out" "ports postgres affiche le port 5432"
        assert_not_match "node" "$out" "ports postgres n'affiche pas node"
    )
}

test_ports_no_match_errors() {
    (
        _ports_fetch_raw() { printf 'tcp\t3000\tnode\t111\n'; }
        assert_failure "ports sur un motif absent échoue" -- ports 9999
    )
}

test_ports_dedup_and_sort() {
    (
        _ports_fetch_raw() {
            printf 'tcp\t5432\tpostgres\t222\n'
            printf 'tcp\t5432\tpostgres\t222\n'
            printf 'tcp\t3000\tnode\t111\n'
        }
        local out first_port_line dup_count
        out=$(ports)
        first_port_line=$(printf '%s\n' "$out" | grep -m1 -E '^(tcp|udp)')
        assert_match "3000" "$first_port_line" "ports: trié par port croissant (3000 avant 5432)"
        dup_count=$(printf '%s\n' "$out" | grep -c 5432)
        assert_eq "1" "$dup_count" "ports: dédupliqué (une seule ligne pour 5432)"
    )
}

test_kport_refuses_pid_1() {
    (
        _ports_collect() { printf 'tcp\t80\tinit\t1\n'; }
        assert_failure "kport refuse de tuer le PID 1" -- kport 80
    )
}

test_kport_refuses_foreign_owner() {
    (
        _ports_collect() { printf 'tcp\t80\tsshd\t99999\n'; }
        id() { printf '1000\n'; }
        ps() { printf '1\n'; }
        assert_failure "kport refuse un process d'un autre utilisateur" -- kport 80
    )
}

test_kport_confirm_declined_cancels() {
    (
        _ports_collect() { printf 'tcp\t80\tnode\t555\n'; }
        id() { printf '1000\n'; }
        ps() { printf '1000\n'; }
        kport 80 >/dev/null 2>&1 <<< "n"
        assert_eq "1" "$?" "kport: confirmation refusée -> annulé (exit 1)"
    )
}

test_kport_default_sends_sigterm() {
    (
        _ports_collect() { printf 'tcp\t80\tnode\t555\n'; }
        id() { printf '1000\n'; }
        ps() { printf '1000\n'; }
        local sig=""
        kill() { sig="$*"; return 0; }
        kport 80 >/dev/null 2>&1 <<< "y"
        assert_eq "555" "$sig" "kport sans --force: kill simple (SIGTERM)"
    )
}

test_kport_force_sends_sigkill() {
    (
        _ports_collect() { printf 'tcp\t80\tnode\t555\n'; }
        id() { printf '1000\n'; }
        ps() { printf '1000\n'; }
        local sig=""
        kill() { sig="$*"; return 0; }
        kport 80 --force >/dev/null 2>&1 <<< "y"
        assert_eq "-9 555" "$sig" "kport --force: kill -9"
    )
}
