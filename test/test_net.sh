## --- Tests: net.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/net.sh"

test_myip_tries_next_provider_on_failure() {
    (
        curl() {
            case "$*" in
                *icanhazip*) return 1 ;;
                *ifconfig.me*) printf '203.0.113.42\n'; return 0 ;;
                *) return 1 ;;
            esac
        }
        local out
        out=$(myip)
        assert_eq "203.0.113.42" "$out" "myip: repli sur le fournisseur suivant si le premier échoue"
    )
}

test_myip_fails_when_all_providers_fail() {
    (
        curl() { return 1; }
        assert_failure "myip échoue proprement si aucun fournisseur ne répond" -- myip
    )
}

test_myip_fails_without_curl() {
    (
        command() { [ "$2" = "curl" ] && return 1; builtin command "$@"; }
        assert_failure "myip échoue si curl est indisponible" -- myip
    )
}

test_localip_uses_ip_route_when_available() {
    (
        ip() { printf '1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.42 uid 1000\n'; }
        command() { [ "$2" = "ip" ] && return 0; builtin command "$@"; }
        local out
        out=$(localip)
        assert_eq "192.168.1.42" "$out" "localip: extrait l'IP source de 'ip route get'"
    )
}

test_localip_fails_without_any_tool() {
    (
        command() { return 1; }
        assert_failure "localip échoue si ip/ifconfig/ipconfig sont tous absents" -- localip
    )
}

test_weather_returns_output_from_wttr() {
    (
        curl() { printf 'Paris: +22°C\n'; }
        local out
        out=$(weather Paris)
        assert_eq "Paris: +22°C" "$out" "weather: affiche la sortie de wttr.in"
    )
}

test_weather_fails_on_empty_response() {
    (
        curl() { :; }
        assert_failure "weather échoue si wttr.in ne répond rien" -- weather
    )
}
