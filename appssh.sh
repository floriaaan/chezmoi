#!/usr/bin/env bash
# Standalone Bash process: strict mode must not affect the interactive shell.
set -euo pipefail
shopt -s nullglob

fail() { printf 'appssh: %s\n' "$*" >&2; exit 1; }
usage_error() { printf 'appssh: %s (see --help)\n' "$*" >&2; exit 2; }

show_help() {
    printf '%s\n' \
        'Usage:' \
        '  appssh <service> <-d|-r|-p> [db]' \
        '  appssh <service> <-d|-r|-p> logs [--lines N|-n N]' \
        '  appssh <service> --resolve' \
        '  appssh --services' \
        '' \
        'Environments: -d/--dev, -r/--recette, -p/--production (required).' \
        'Examples:' \
        '  appssh exemple -r' \
        '  appssh exemple -p' \
        '  appssh exemple -r db' \
        '  appssh exemple -p logs' \
        '  appssh exemple -p logs --lines 100'
}

# Tokenize SSH directives, including quoted paths and comments, without eval.
# A sentinel keeps empty arrays compatible with Bash 3.2 + nounset (macOS).
words=('')
tokenize() {
    local line="$1" char token='' quote='' escaped=0 started=0 i
    words=('')
    for ((i=0; i<${#line}; i++)); do
        char=${line:i:1}
        if ((escaped)); then
            token+="$char"; escaped=0; started=1; continue
        fi
        if [[ "$char" == '\' ]]; then escaped=1; started=1; continue; fi
        if [[ -n "$quote" ]]; then
            if [[ "$char" == "$quote" ]]; then quote=''; else token+="$char"; fi
            continue
        fi
        case "$char" in
            '"'|"'") quote=$char; started=1 ;;
            '#') break ;;
            ' '|$'\t'|$'\r')
                if ((started)); then words+=("$token"); token=''; started=0; fi
                ;;
            '=')
                if ((${#words[@]} == 1)); then
                    words+=("$token"); token=''; started=0
                elif ((${#words[@]} == 2)) && [[ -z "$token" ]]; then
                    : # Optional separator after the keyword.
                else token+="$char"; started=1; fi
                ;;
            *) token+="$char"; started=1 ;;
        esac
    done
    [[ -z "$quote" && "$escaped" == 0 ]] || fail 'Unterminated quote or escape in SSH config'
    if ((started)); then words+=("$token"); fi
}

hosts=('')
add_host() {
    local existing
    for existing in "${hosts[@]}"; do [[ "$existing" != "$1" ]] || return 0; done
    hosts+=("$1")
}

host_matches() {
    local host="$1" pattern matched=0
    shift
    for pattern in "$@"; do
        if [[ "$pattern" == '!'* ]]; then
            [[ "$host" != ${pattern:1} ]] || return 1
        elif [[ "$host" == $pattern ]]; then matched=1; fi
    done
    ((matched))
}

# Includes are relative to ~/.ssh, as in OpenSSH, not to their containing file.
# Only unconditional Includes are enumerated: evaluating Match (notably exec)
# or conditional Include trees would require a full SSH config interpreter.
include_scope=all
discover_ssh_hosts() {
    local file="$1" depth="${2:-0}" line keyword alias pattern included
    local -a args=('') paths=('')
    ((depth <= 16)) || fail 'SSH Include nesting exceeds 16 levels (possible cycle)'
    [[ -e "$file" ]] || return 0
    [[ -r "$file" && -f "$file" ]] || fail "Cannot read SSH config: $file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        tokenize "$line"
        ((${#words[@]} > 1)) || continue
        keyword=${words[1]}
        args=('' "${words[@]:2}")
        case "$keyword" in
            [Hh][Oo][Ss][Tt])
                include_scope=conditional
                if ((${#args[@]} == 2)) && [[ "${args[1]}" == '*' ]]; then include_scope=all; fi
                for alias in "${args[@]}"; do
                    # Literal, positive aliases only; wildcard rules cannot enumerate hosts.
                    [[ "$alias" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || continue
                    if host_matches "$alias" "${args[@]}"; then add_host "$alias"; fi
                done
                ;;
            [Mm][Aa][Tt][Cc][Hh]) include_scope=conditional ;;
            [Ii][Nn][Cc][Ll][Uu][Dd][Ee])
                if [[ "$include_scope" != all ]]; then
                    printf 'appssh: skipping conditional Include in %s; put alias Includes before Host/Match blocks\n' "$file" >&2
                    continue
                fi
                for pattern in "${args[@]}"; do
                    [[ -n "$pattern" ]] || continue
                    case "$pattern" in
                        '~/'*) pattern="$HOME/${pattern:2}" ;;
                        '~'*) fail "Unsupported Include home expansion: $pattern" ;;
                        /*) ;;
                        *) pattern="$HOME/.ssh/$pattern" ;;
                    esac
                    # Intentional pathname expansion only; preserve spaces in paths.
                    local IFS=''
                    # shellcheck disable=SC2206
                    paths=('' $pattern)
                    for included in "${paths[@]}"; do
                        [[ -n "$included" ]] || continue
                        discover_ssh_hosts "$included" "$((depth + 1))"
                    done
                done
                ;;
        esac
    done < "$file"
}

main() {
    local config="$1"
    shift
    service='' environment='' action='' lines='' mode=''
    while (($#)); do
        case "$1" in
            -h|--help) show_help; exit 0 ;;
            -d|--dev|-r|--recette|-p|--production)
                [[ -z "$environment" ]] || usage_error 'Choose exactly one environment'
                case "$1" in
                    -d|--dev) environment=dev ;;
                    -r|--recette) environment=recette ;;
                    -p|--production) environment=production ;;
                esac
                ;;
            --resolve|--services)
                [[ -z "$mode" ]] || usage_error 'Choose exactly one discovery mode'
                mode=$1 ;;
            --lines|-n)
                [[ "$action" == logs && -z "$lines" && $# -ge 2 ]] || usage_error 'Use logs --lines N or logs -n N'
                shift
                [[ "$1" =~ ^[0-9]+$ && "$1" == *[1-9]* ]] || usage_error 'Line count must be a positive integer'
                lines=$1 ;;
            -*) usage_error "Unknown option: $1" ;;
            *)
                if [[ -z "$service" ]]; then
                    [[ "$1" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || usage_error "Invalid service: $1"
                    service=$1
                elif [[ -z "$action" && ( "$1" == db || "$1" == logs ) ]]; then action=$1
                else usage_error "Unexpected argument: $1"; fi
                ;;
        esac
        shift
    done

    if [[ -n "$mode" ]]; then
        [[ -z "$environment$action$lines" ]] || usage_error 'Discovery modes do not accept an environment or action'
        if [[ "$mode" == --services ]]; then
            [[ -z "$service" ]] || usage_error '--services does not accept a service'
        else [[ -n "$service" ]] || usage_error '--resolve requires a service'; fi
    else
        [[ -n "$service" && -n "$environment" ]] || usage_error 'A service and an explicit environment are required'
    fi

    discover_ssh_hosts "$config"

    service_from_host() {
        local base=${1%-db-tunnel}
        case "$base" in
            *-dev) detected_service=${base%-dev} ;;
            *-recette) detected_service=${base%-recette} ;;
            *-production) detected_service=${base%-production} ;;
            *) return 1 ;;
        esac
        [[ -n "$detected_service" ]]
    }

    if [[ "$mode" == --services ]]; then
        services=('')
        for host in "${hosts[@]}"; do
            service_from_host "$host" || continue
            short=${detected_service#api}
            [[ -n "$short" ]] || short=$detected_service
            duplicate=0
            for existing in "${services[@]}"; do [[ "$existing" != "$short" ]] || duplicate=1; done
            if ((duplicate == 0)); then services+=("$short"); printf '%s\n' "$short"; fi
        done
        exit 0
    fi

    matches=('')
    for host in "${hosts[@]}"; do
        if [[ "$mode" == --resolve ]]; then
            service_from_host "$host" || continue
            [[ "$detected_service" == "$service" || "$detected_service" == "api$service" ]] || continue
        else
            suffix="-$environment"
            [[ "$action" != db ]] || suffix+='-db-tunnel'
            [[ "$host" == "$service$suffix" || "$host" == "api$service$suffix" ]] || continue
        fi
        matches+=("$host")
    done
    ((${#matches[@]} > 1)) || fail "No explicit SSH alias found for service \"$service\"${environment:+ ($environment${action:+, $action})}"
    if [[ "$mode" == --resolve ]]; then printf '%s\n' "${matches[@]:1}"; exit 0; fi
    if ((${#matches[@]} > 2)); then
        printf 'Ambiguous service "%s":\n' "$service" >&2
        printf '  %s\n' "${matches[@]:1}" >&2
        fail 'Use the full service name'
    fi
    host=${matches[1]}

    run_logs() {
        local remote_command='pm2 logs'
        [[ -z "$lines" ]] || remote_command+=" --lines $lines"
        [[ "$environment" != production ]] || printf '[production] %s -> %s\n' "$host" "$remote_command" >&2
        exec ssh "$host" "$remote_command"
    }

    run_ssh() {
        [[ "$environment" != production ]] || printf '[production] %s\n' "$host" >&2
        exec ssh "$host"
    }

    case "$action" in
        logs) run_logs ;;
        ''|db) run_ssh ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$HOME/.ssh/config" "$@"
fi
