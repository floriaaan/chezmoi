## --- gtag: crée et pousse un tag semver ---

_GTAG_RESET='\033[0m'
_GTAG_BOLD='\033[1m'
_GTAG_PROD='\033[38;5;108m'
_GTAG_RC='\033[38;5;179m'
_GTAG_DEV='\033[38;5;167m'
_GTAG_INFO='\033[38;5;110m'
_GTAG_WARN='\033[38;5;208m'
_GTAG_ERR='\033[38;5;196m'
_GTAG_TREE_LIMIT=4   # nombre de tags affichés par environnement dans l'arbre (0 = illimité)

_gtag_confirm() {
    emulate -L bash 2>/dev/null
    local msg="$1" answer
    printf "%b" "${_GTAG_INFO}${msg}${_GTAG_RESET} [y/N] "
    read -r answer
    [[ "$answer" =~ ^[yY]$ ]]
}

_gtag_tree() {
    emulate -L bash 2>/dev/null
    local filter="$1"
    local all_tags prod=() rc=() dev=()
    all_tags=$(git tag -l | sort -V)

    if [ -z "$all_tags" ]; then
        printf "%b\n" "${_GTAG_ERR}gtag: aucun tag trouvé${_GTAG_RESET}"
        return 0
    fi

    while IFS= read -r t; do
        if [[ "$t" =~ -dev$ ]]; then
            dev+=("$t")
        elif [[ "$t" =~ -rc\.[0-9]+$ ]]; then
            rc+=("$t")
        elif [[ "$t" =~ ^[a-zA-Z]*[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            prod+=("$t")
        fi
    done <<< "$all_tags"

    printf "%b\n" "${_GTAG_BOLD}Tags${_GTAG_RESET}"

    _gtag_print_section() {
        emulate -L bash 2>/dev/null
        local label="$1" color="$2" prefix_char="$3"; shift 3
        local -a items=("$@")
        local total=${#items[@]}
        local hidden=0

        if [ "$_GTAG_TREE_LIMIT" -gt 0 ] && [ "$total" -gt "$_GTAG_TREE_LIMIT" ]; then
            hidden=$((total - _GTAG_TREE_LIMIT))
            items=("${items[@]: -$_GTAG_TREE_LIMIT}")
        fi

        printf "%b\n" "${color}${prefix_char} ${label}${_GTAG_RESET}"
        local n=${#items[@]}

        if [ "$hidden" -gt 0 ]; then
            printf "%b\n" "│   ${color}⋯ (${hidden} de plus)${_GTAG_RESET}"
        fi

        local i
        for i in "${!items[@]}"; do
            local branch="├─"; [ "$i" -eq $((n - 1)) ] && branch="└─"
            local mark=""; [ "$i" -eq $((n - 1)) ] && [ "$n" -gt 0 ] && mark=" ${_GTAG_BOLD}(latest)${_GTAG_RESET}${color}"
            printf "%b\n" "│   ${branch} ${items[$i]}${mark}${_GTAG_RESET}"
        done
        [ "$n" -eq 0 ] && printf "%b\n" "│   └─ (aucun)"
    }

    [ -z "$filter" ] || [ "$filter" = "prod" ] && \
        _gtag_print_section "PROD" "$_GTAG_PROD" "├─" "${prod[@]}"

    [ -z "$filter" ] || [ "$filter" = "rc" ] || [ "$filter" = "recette" ] && \
        _gtag_print_section "RECETTE (rc)" "$_GTAG_RC" "├─" "${rc[@]}"

    [ -z "$filter" ] || [ "$filter" = "dev" ] && \
        _gtag_print_section "DEV" "$_GTAG_DEV" "└─" "${dev[@]}"

    unset -f _gtag_print_section
}

gtag() {
    emulate -L bash 2>/dev/null
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf "%b\n" "${_GTAG_ERR}gtag: pas un dépôt git${_GTAG_RESET}" >&2
        return 1
    fi

    if [ $# -eq 0 ]; then
        _gtag_tree
        return 0
    fi

    if [ "$1" = "list" ]; then
        _gtag_tree "$2"
        return 0
    fi

    local bump="" prefix="" force=0 rc=0 dev=0 dry_run=0

    for arg in "$@"; do
        case "$arg" in
            major|minor|patch) bump="$arg" ;;
            --force)           force=1 ;;
            --prefix=*)        prefix="${arg#--prefix=}" ;;
            --rc)               rc=1 ;;
            --dev)              dev=1 ;;
            --dry-run)          dry_run=1 ;;
            *)
                printf "%b\n" "${_GTAG_ERR}gtag: option inconnue '$arg'${_GTAG_RESET}" >&2
                return 1
                ;;
        esac
    done

    if [ -z "$bump" ]; then
        printf "%b\n" "${_GTAG_ERR}gtag: usage: gtag <major|minor|patch> [--force] [--prefix=v] [--rc] [--dev] [--dry-run]${_GTAG_RESET}" >&2
        printf "%b\n" "${_GTAG_INFO}       gtag list [prod|rc|dev]${_GTAG_RESET}" >&2
        return 1
    fi

    [ "$dev" -eq 1 ] && force=1

    local last_tag last_ver major_n minor_n patch_n
    last_tag=$(git tag -l | grep -E "^${prefix}[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -n1)

    if [ -z "$last_tag" ]; then
        major_n=0; minor_n=0; patch_n=0
    else
        last_ver="${last_tag#$prefix}"
        major_n=$(echo "$last_ver" | cut -d. -f1)
        minor_n=$(echo "$last_ver" | cut -d. -f2)
        patch_n=$(echo "$last_ver" | cut -d. -f3)
    fi

    case "$bump" in
        major) major_n=$((major_n + 1)); minor_n=0; patch_n=0 ;;
        minor) minor_n=$((minor_n + 1)); patch_n=0 ;;
        patch) patch_n=$((patch_n + 1)) ;;
    esac

    local base_ver="${major_n}.${minor_n}.${patch_n}"
    local suffix="" seg_color="$_GTAG_PROD" env_label="PROD"

    if [ "$rc" -eq 1 ]; then
        local last_rc rc_n
        last_rc=$(git tag -l \
            | grep -E "^${prefix}${base_ver}-rc\.[0-9]+$" \
            | sed -E "s/^${prefix}${base_ver}-rc\.([0-9]+)\$/\1/" \
            | sort -n | tail -n1)
        [ -z "$last_rc" ] && rc_n=1 || rc_n=$((last_rc + 1))
        suffix="-rc.${rc_n}"
        seg_color="$_GTAG_RC"
        env_label="RECETTE"
    fi

    if [ "$dev" -eq 1 ]; then
        suffix="-dev"
        seg_color="$_GTAG_DEV"
        env_label="DEV"
    fi

    local new_tag="${prefix}${base_ver}${suffix}"

    if [ "$dry_run" -eq 1 ]; then
        printf "%b\n" "${_GTAG_INFO}[dry-run] gtag créerait '${new_tag}' (${env_label}) et le pousserait sur origin${_GTAG_RESET}"
        [ "$force" -eq 1 ] && printf "%b\n" "${_GTAG_INFO}[dry-run] supprimerait aussi le tag existant en local + origin (--force)${_GTAG_RESET}"
        return 0
    fi

    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$current_branch" ] && [[ ! "$current_branch" =~ ^(main|master)$ ]]; then
        printf "%b\n" "${_GTAG_WARN}gtag: tu es sur la branche '${current_branch}' (pas main/master)${_GTAG_RESET}"
        if ! _gtag_confirm "Continuer quand même ?"; then
            printf "%b\n" "${_GTAG_ERR}gtag: annulé${_GTAG_RESET}"
            return 1
        fi
    fi

    if [ "$force" -eq 1 ]; then
        git tag -d "$new_tag" >/dev/null 2>&1
    elif git rev-parse "$new_tag" >/dev/null 2>&1; then
        printf "%b\n" "${_GTAG_ERR}gtag: le tag '$new_tag' existe déjà (utilise --force pour le remplacer)${_GTAG_RESET}" >&2
        return 1
    fi

    if ! _gtag_confirm "Créer et pousser le tag '${new_tag}' (${env_label}) sur origin ?"; then
        printf "%b\n" "${_GTAG_ERR}gtag: annulé${_GTAG_RESET}"
        return 1
    fi

    [ "$force" -eq 1 ] && git push origin ":refs/tags/${new_tag}" >/dev/null 2>&1

    git tag "$new_tag" || { printf "%b\n" "${_GTAG_ERR}gtag: échec création du tag${_GTAG_RESET}" >&2; return 1; }
    git push origin "$new_tag" || { printf "%b\n" "${_GTAG_ERR}gtag: échec push du tag${_GTAG_RESET}" >&2; return 1; }

    printf "%b\n" "${seg_color}${_GTAG_BOLD}gtag: tag '${new_tag}' créé et poussé sur origin${_GTAG_RESET}"
}