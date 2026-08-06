## --- gtag: crée et pousse un tag semver ---

# Couleurs
_GTAG_RESET='\033[0m'
_GTAG_BOLD='\033[1m'
_GTAG_PROD='\033[38;5;108m'   # vert sauge
_GTAG_RC='\033[38;5;179m'     # jaune sable
_GTAG_DEV='\033[38;5;167m'    # rouge saumon
_GTAG_INFO='\033[38;5;110m'   # bleu ardoise
_GTAG_ERR='\033[38;5;196m'    # rouge vif

_gtag_confirm() {
    local msg="$1" answer
    read -rp "$(printf "%b" "${_GTAG_INFO}${msg}${_GTAG_RESET} [y/N] ")" answer
    [[ "$answer" =~ ^[yY]$ ]]
}

_gtag_tree() {
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

    printf "%b\n" "${_GTAG_PROD}├─ PROD${_GTAG_RESET}"
    local n=${#prod[@]}
    for i in "${!prod[@]}"; do
        local branch="├─"; [ "$i" -eq $((n - 1)) ] && branch="└─"
        local mark=""; [ "$i" -eq $((n - 1)) ] && [ "$n" -gt 0 ] && mark=" ${_GTAG_BOLD}(latest)${_GTAG_RESET}${_GTAG_PROD}"
        printf "%b\n" "│   ${branch} ${prod[$i]}${mark}${_GTAG_RESET}"
    done
    [ "$n" -eq 0 ] && printf "%b\n" "│   └─ (aucun)"

    printf "%b\n" "${_GTAG_RC}├─ RECETTE (rc)${_GTAG_RESET}"
    n=${#rc[@]}
    for i in "${!rc[@]}"; do
        local branch="├─"; [ "$i" -eq $((n - 1)) ] && branch="└─"
        local mark=""; [ "$i" -eq $((n - 1)) ] && [ "$n" -gt 0 ] && mark=" ${_GTAG_BOLD}(latest)${_GTAG_RESET}${_GTAG_RC}"
        printf "%b\n" "│   ${branch} ${rc[$i]}${mark}${_GTAG_RESET}"
    done
    [ "$n" -eq 0 ] && printf "%b\n" "│   └─ (aucun)"

    printf "%b\n" "${_GTAG_DEV}└─ DEV${_GTAG_RESET}"
    n=${#dev[@]}
    for i in "${!dev[@]}"; do
        local branch="├─"; [ "$i" -eq $((n - 1)) ] && branch="└─"
        local mark=""; [ "$i" -eq $((n - 1)) ] && [ "$n" -gt 0 ] && mark=" ${_GTAG_BOLD}(latest)${_GTAG_RESET}${_GTAG_DEV}"
        printf "%b\n" "    ${branch} ${dev[$i]}${mark}${_GTAG_RESET}"
    done
    [ "$n" -eq 0 ] && printf "%b\n" "    └─ (aucun)"
}

gtag() {
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf "%b\n" "${_GTAG_ERR}gtag: pas un dépôt git${_GTAG_RESET}" >&2
        return 1
    fi

    if [ $# -eq 0 ]; then
        _gtag_tree
        return 0
    fi

    local bump="" prefix="" force=0 rc=0 dev=0

    for arg in "$@"; do
        case "$arg" in
            major|minor|patch) bump="$arg" ;;
            --force)           force=1 ;;
            --prefix=*)        prefix="${arg#--prefix=}" ;;
            --rc)               rc=1 ;;
            --dev)              dev=1 ;;
            *)
                printf "%b\n" "${_GTAG_ERR}gtag: option inconnue '$arg'${_GTAG_RESET}" >&2
                return 1
                ;;
        esac
    done

    if [ -z "$bump" ]; then
        printf "%b\n" "${_GTAG_ERR}gtag: usage: gtag <major|minor|patch> [--force] [--prefix=v] [--rc] [--dev]${_GTAG_RESET}" >&2
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
    local suffix="" seg_color="$_GTAG_PROD"

    if [ "$rc" -eq 1 ]; then
        local last_rc rc_n
        last_rc=$(git tag -l \
            | grep -E "^${prefix}${base_ver}-rc\.[0-9]+$" \
            | sed -E "s/^${prefix}${base_ver}-rc\.([0-9]+)\$/\1/" \
            | sort -n | tail -n1)
        [ -z "$last_rc" ] && rc_n=1 || rc_n=$((last_rc + 1))
        suffix="-rc.${rc_n}"
        seg_color="$_GTAG_RC"
    fi

    if [ "$dev" -eq 1 ]; then
        suffix="-dev"
        seg_color="$_GTAG_DEV"
    fi

    local new_tag="${prefix}${base_ver}${suffix}"

    if [ "$force" -eq 1 ]; then
        git tag -d "$new_tag" >/dev/null 2>&1
        git push origin ":refs/tags/${new_tag}" >/dev/null 2>&1
    elif git rev-parse "$new_tag" >/dev/null 2>&1; then
        printf "%b\n" "${_GTAG_ERR}gtag: le tag '$new_tag' existe déjà (utilise --force pour le remplacer)${_GTAG_RESET}" >&2
        return 1
    fi

    if ! _gtag_confirm "Créer et pousser le tag '${new_tag}' sur origin ?"; then
        printf "%b\n" "${_GTAG_ERR}gtag: annulé${_GTAG_RESET}"
        return 1
    fi

    git tag "$new_tag" || { printf "%b\n" "${_GTAG_ERR}gtag: échec création du tag${_GTAG_RESET}" >&2; return 1; }
    git push origin "$new_tag" || { printf "%b\n" "${_GTAG_ERR}gtag: échec push du tag${_GTAG_RESET}" >&2; return 1; }

    printf "%b\n" "${seg_color}${_GTAG_BOLD}gtag: tag '${new_tag}' créé et poussé sur origin${_GTAG_RESET}"
}
