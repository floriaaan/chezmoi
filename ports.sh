## --- ports: liste les ports en écoute (TCP+UDP) + kport pour tuer un process ---

_PORTS_OK='\033[38;5;108m'
_PORTS_WARN='\033[38;5;179m'
_PORTS_ERR='\033[38;5;196m'
_PORTS_INFO='\033[38;5;110m'
_PORTS_DIM='\033[38;5;244m'
_PORTS_RESET='\033[0m'

## --- Parsing : chaque parseur lit sur stdin et écrit proto\tport\tprocess\tpid, une ligne par socket ---
## Séparés du "collecteur" pour rester testables sans ss/netstat installés (cf. test/test_ports.sh).

_ports_parse_ss() {
    emulate -L bash 2>/dev/null
    awk '
    {
        proto = $1
        n = split($5, a, ":")
        port = a[n]
        pid = "-"; name = "-"
        if (match($0, /pid=[0-9]+/)) {
            s = substr($0, RSTART, RLENGTH)
            sub("pid=", "", s)
            pid = s
        }
        if (match($0, /\(\("[^"]+"/)) {
            name = substr($0, RSTART + 3, RLENGTH - 4)
        }
        if (port != "" && port != "*") print proto "\t" port "\t" name "\t" pid
    }'
}

_ports_parse_netstat() {
    emulate -L bash 2>/dev/null
    awk '
    {
        proto = $1
        if (proto != "tcp" && proto != "tcp6" && proto != "udp" && proto != "udp6") next
        n = split($4, a, ":")
        port = a[n]
        # note: netstat omet la colonne State pour udp, le champ PID/Program se decale
        pidprog = (proto ~ /^udp/) ? $6 : $7
        pid = "-"; name = "-"
        if (pidprog ~ /^[0-9]+\//) {
            split(pidprog, pp, "/")
            pid = pp[1]; name = pp[2]
        }
        if (port != "" && port != "*") print proto "\t" port "\t" name "\t" pid
    }'
}

## --- Récupération brute (proto\tport\tprocess\tpid), non triée, non dédupliquée ---
## Séparée de _ports_collect pour rester testable (mockable) sans ss/netstat réels.
_ports_fetch_raw() {
    emulate -L bash 2>/dev/null
    if command -v ss >/dev/null 2>&1; then
        ss -tulpnH 2>/dev/null | _ports_parse_ss
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn 2>/dev/null | tail -n +3 | _ports_parse_netstat
    else
        printf "%b\n" "${_PORTS_ERR}ports: ni 'ss' ni 'netstat' disponible sur ce système${_PORTS_RESET}" >&2
        return 2
    fi
}

## --- Collecte : brute + dédupliquée (proto/port/pid identiques) + triée par port croissant ---
_ports_collect() {
    emulate -L bash 2>/dev/null
    local raw
    raw=$(_ports_fetch_raw)
    local rc=$?
    [ "$rc" -eq 2 ] && return 2
    [ -z "$raw" ] && return 0
    printf '%s\n' "$raw" | sort -u | sort -t"$(printf '\t')" -k2,2n
}

ports() {
    emulate -L bash 2>/dev/null
    local filter="$1" rows rc
    rows=$(_ports_collect)
    rc=$?
    [ "$rc" -eq 2 ] && return 1

    if [ -n "$filter" ]; then
        if [[ "$filter" =~ ^[0-9]+$ ]]; then
            rows=$(printf '%s\n' "$rows" | awk -F'\t' -v p="$filter" '$2 == p')
        else
            rows=$(printf '%s\n' "$rows" | awk -F'\t' -v p="$filter" '$3 == p')
        fi
    fi

    if [ -z "$rows" ]; then
        if [ -n "$filter" ]; then
            printf "%b\n" "${_PORTS_ERR}ports: aucun port en écoute correspondant à '${filter}'${_PORTS_RESET}" >&2
        else
            printf "%b\n" "${_PORTS_ERR}ports: aucun port en écoute${_PORTS_RESET}" >&2
        fi
        return 1
    fi

    local saw_hidden=0
    printf "%b\n" "${_PORTS_INFO}PROTO  PORT   PROCESS              PID${_PORTS_RESET}"
    while IFS=$'\t' read -r proto port name pid; do
        [ -z "$proto" ] && continue
        [ "$pid" = "-" ] && saw_hidden=1
        printf "%-6s %-6s %-20s %s\n" "$proto" "$port" "$name" "$pid"
    done <<< "$rows"

    if [ "$saw_hidden" -eq 1 ] && [ "$(id -u)" -ne 0 ]; then
        printf "%b\n" "${_PORTS_DIM}note: lance 'sudo ports' pour voir le détail des process${_PORTS_RESET}"
    fi
}

_ports_confirm() {
    emulate -L bash 2>/dev/null
    local msg="$1" answer
    printf "%b" "${_PORTS_INFO}${msg}${_PORTS_RESET} [y/N] "
    read -r answer
    [[ "$answer" =~ ^[yY]$ ]]
}

kport() {
    emulate -L bash 2>/dev/null
    local port="$1" force=0
    [ "$2" = "--force" ] && force=1

    if [ -z "$port" ] || ! [[ "$port" =~ ^[0-9]+$ ]]; then
        printf "%b\n" "${_PORTS_ERR}kport: usage: kport <PORT> [--force]${_PORTS_RESET}" >&2
        return 1
    fi

    local line rows
    rows=$(_ports_collect) || return 1
    line=$(printf '%s\n' "$rows" | awk -F'\t' -v p="$port" '$2 == p {print; exit}')

    if [ -z "$line" ]; then
        printf "%b\n" "${_PORTS_ERR}kport: aucun process n'écoute sur le port ${port}${_PORTS_RESET}" >&2
        return 1
    fi

    local proto pport name pid
    # shellcheck disable=SC2034  # pport (le port) fait partie du tuple lu, non réutilisé ensuite
    IFS=$'\t' read -r proto pport name pid <<< "$line"

    if [ "$pid" = "-" ] || [ -z "$pid" ]; then
        printf "%b\n" "${_PORTS_ERR}kport: PID introuvable pour le port ${port} (droits insuffisants ? relance en root)${_PORTS_RESET}" >&2
        return 1
    fi

    if [ "$pid" = "1" ]; then
        printf "%b\n" "${_PORTS_ERR}kport: refus de tuer le PID 1${_PORTS_RESET}" >&2
        return 1
    fi

    if [ "$(id -u)" -ne 0 ]; then
        local owner
        owner=$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -z "$owner" ] || [ "$owner" != "$(id -u)" ]; then
            printf "%b\n" "${_PORTS_ERR}kport: le process ${pid} n'appartient pas à l'utilisateur courant, refus${_PORTS_RESET}" >&2
            return 1
        fi
    fi

    if ! _ports_confirm "Tuer ${name} (PID ${pid}) sur le port ${port} ?"; then
        printf "%b\n" "${_PORTS_ERR}kport: annulé${_PORTS_RESET}"
        return 1
    fi

    if [ "$force" -eq 1 ]; then
        kill -9 "$pid" && printf "%b\n" "${_PORTS_OK}kport: PID ${pid} tué (SIGKILL)${_PORTS_RESET}"
    else
        kill "$pid" && printf "%b\n" "${_PORTS_OK}kport: PID ${pid} tué (SIGTERM)${_PORTS_RESET}"
    fi
}
