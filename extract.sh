## --- extract: décompresse n'importe quelle archive, détection par extension ---
## --- compress: sens inverse, détection par l'extension du fichier cible ---

_EXTRACT_OK='\033[38;5;108m'
_EXTRACT_WARN='\033[38;5;179m'
_EXTRACT_ERR='\033[38;5;196m'
_EXTRACT_INFO='\033[38;5;110m'
_EXTRACT_RESET='\033[0m'

_EXTRACT_FORMATS_LIST=".tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz .tar.zst .tar .gz .bz2 .xz .zip .7z .rar"

_extract_confirm() {
    emulate -L bash 2>/dev/null
    local msg="$1" answer
    printf "%b" "${_EXTRACT_INFO}${msg} [Y/n]${_EXTRACT_RESET} "
    read -r answer
    [[ -z "$answer" || "$answer" =~ ^[yY]$ ]]
}

## Nom de dossier suggéré : archive sans son extension
_extract_basename() {
    local f="$1"
    local base="$f"
    case "$f" in
        *.tar.gz)  base="${f%.tar.gz}"  ;;
        *.tgz)     base="${f%.tgz}"     ;;
        *.tar.bz2) base="${f%.tar.bz2}" ;;
        *.tbz2)    base="${f%.tbz2}"    ;;
        *.tar.xz)  base="${f%.tar.xz}"  ;;
        *.txz)     base="${f%.txz}"     ;;
        *.tar.zst) base="${f%.tar.zst}" ;;
        *.tar)     base="${f%.tar}"     ;;
        *.gz)      base="${f%.gz}"      ;;
        *.bz2)     base="${f%.bz2}"     ;;
        *.xz)      base="${f%.xz}"      ;;
        *.zip)     base="${f%.zip}"     ;;
        *.7z)      base="${f%.7z}"      ;;
        *.rar)     base="${f%.rar}"     ;;
    esac
    basename "$base"
}

## Binaire requis par format, vide si aucun (formats couverts par tar/gzip/bzip2/xz, toujours présents)
_extract_required_bin() {
    case "$1" in
        *.zip) echo "unzip" ;;
        *.7z)  echo "7z" ;;
        *.rar) echo "unrar" ;;
        *)     echo "" ;;
    esac
}

## Liste des entrées de premier niveau d'une archive tar/zip (une par ligne, sans doublon)
_extract_list_roots() {
    local archive="$1"
    case "$archive" in
        *.tar.gz|*.tgz)  tar -tzf "$archive" 2>/dev/null ;;
        *.tar.bz2|*.tbz2) tar -tjf "$archive" 2>/dev/null ;;
        *.tar.xz|*.txz)  tar -tJf "$archive" 2>/dev/null ;;
        *.tar.zst)       tar --zstd -tf "$archive" 2>/dev/null ;;
        *.tar)           tar -tf "$archive" 2>/dev/null ;;
        *.zip)           unzip -Z1 "$archive" 2>/dev/null ;;
    esac | sed -E 's#^\./##' | cut -d/ -f1 | sort -u | sed '/^$/d'
}

## Protection anti-tarbomb : si l'archive a >1 entrée racine, propose un dossier dédié.
## Positionne _EXTRACT_TARGET_DIR (".": pas de proposition/refusée, sinon le dossier créé).
_extract_check_tarbomb() {
    emulate -L bash 2>/dev/null
    local archive="$1" roots count suggested
    _EXTRACT_TARGET_DIR="."
    case "$archive" in
        *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.zst|*.tar|*.zip) ;;
        *) return 0 ;;   # formats mono-fichier (gz/bz2/xz seuls) : pas de notion de racine multiple
    esac

    roots=$(_extract_list_roots "$archive")
    count=$(printf '%s\n' "$roots" | sed '/^$/d' | wc -l | tr -d ' ')
    [ "$count" -le 1 ] && return 0

    suggested="$(_extract_basename "$archive")"
    printf "%b\n" "${_EXTRACT_WARN}extract: '${archive}' contient ${count} entrées à la racine (tarbomb potentiel)${_EXTRACT_RESET}"
    if _extract_confirm "Créer '${suggested}/' et y extraire ?"; then
        mkdir -p "$suggested" || return 1
        _EXTRACT_TARGET_DIR="$suggested"
    fi
    return 0
}

_extract_run() {
    local archive="$1" dir="$2"
    case "$archive" in
        *.tar.gz|*.tgz)   tar -xzf "$archive" -C "$dir" ;;
        *.tar.bz2|*.tbz2) tar -xjf "$archive" -C "$dir" ;;
        *.tar.xz|*.txz)   tar -xJf "$archive" -C "$dir" ;;
        *.tar.zst)        tar --zstd -xf "$archive" -C "$dir" ;;
        *.tar)            tar -xf "$archive" -C "$dir" ;;
        *.gz)
            if [ "$dir" = "." ]; then gunzip -k "$archive"
            else gunzip -k -c "$archive" > "$dir/$(basename "${archive%.gz}")"; fi ;;
        *.bz2)
            if [ "$dir" = "." ]; then bunzip2 -k "$archive"
            else bunzip2 -k -c "$archive" > "$dir/$(basename "${archive%.bz2}")"; fi ;;
        *.xz)
            if [ "$dir" = "." ]; then unxz -k "$archive"
            else unxz -k -c "$archive" > "$dir/$(basename "${archive%.xz}")"; fi ;;
        *.zip) unzip -q "$archive" -d "$dir" ;;
        *.7z)  7z x "$archive" -o"$dir" >/dev/null ;;
        *.rar) unrar x -y "$archive" "$dir/" >/dev/null ;;
    esac
}

extract() {
    emulate -L bash 2>/dev/null
    local archive="$1" dest="$2"

    if [ -z "$archive" ]; then
        printf "%b\n" "${_EXTRACT_ERR}extract: usage: extract <archive> [dest]${_EXTRACT_RESET}" >&2
        return 1
    fi
    if [ ! -f "$archive" ]; then
        printf "%b\n" "${_EXTRACT_ERR}extract: fichier introuvable: ${archive}${_EXTRACT_RESET}" >&2
        return 1
    fi

    local recognized=0 fmt
    # shellcheck disable=SC2086  # split volontaire d'une liste statique, pas de glob/espaces dans les valeurs
    for fmt in $_EXTRACT_FORMATS_LIST; do
        case "$archive" in
            *"$fmt") recognized=1; break ;;
        esac
    done
    if [ "$recognized" -eq 0 ]; then
        printf "%b\n" "${_EXTRACT_ERR}extract: extension non reconnue pour '${archive}'${_EXTRACT_RESET}" >&2
        printf "%b\n" "${_EXTRACT_INFO}formats supportés: ${_EXTRACT_FORMATS_LIST}${_EXTRACT_RESET}" >&2
        return 1
    fi

    local need
    need=$(_extract_required_bin "$archive")
    if [ -n "$need" ] && ! command -v "$need" >/dev/null 2>&1; then
        printf "%b\n" "${_EXTRACT_ERR}extract: binaire '${need}' manquant pour extraire '${archive}'${_EXTRACT_RESET}" >&2
        return 1
    fi

    local target_dir
    if [ -n "$dest" ]; then
        mkdir -p "$dest" || { printf "%b\n" "${_EXTRACT_ERR}extract: impossible de créer '${dest}'${_EXTRACT_RESET}" >&2; return 1; }
        target_dir="$dest"
    else
        _extract_check_tarbomb "$archive" || return 1
        target_dir="$_EXTRACT_TARGET_DIR"
    fi

    if ! _extract_run "$archive" "$target_dir"; then
        printf "%b\n" "${_EXTRACT_ERR}extract: échec de l'extraction de '${archive}'${_EXTRACT_RESET}" >&2
        return 1
    fi

    printf "%b\n" "${_EXTRACT_OK}extract: ${archive} → ${target_dir}${_EXTRACT_RESET}"
}

compress() {
    emulate -L bash 2>/dev/null
    local dest="$1"
    if [ -z "$dest" ] || [ $# -lt 2 ]; then
        printf "%b\n" "${_EXTRACT_ERR}compress: usage: compress <dest.tar.gz|...> <fichiers...>${_EXTRACT_RESET}" >&2
        return 1
    fi
    shift

    case "$dest" in
        *.tar.gz|*.tgz)   tar -czf "$dest" "$@" ;;
        *.tar.bz2|*.tbz2) tar -cjf "$dest" "$@" ;;
        *.tar.xz|*.txz)   tar -cJf "$dest" "$@" ;;
        *.tar.zst)        tar --zstd -cf "$dest" "$@" ;;
        *.tar)            tar -cf "$dest" "$@" ;;
        *.gz)
            [ $# -eq 1 ] || { printf "%b\n" "${_EXTRACT_ERR}compress: .gz ne supporte qu'un seul fichier (utilise .tar.gz pour plusieurs)${_EXTRACT_RESET}" >&2; return 1; }
            gzip -k -c "$1" > "$dest" ;;
        *.bz2)
            [ $# -eq 1 ] || { printf "%b\n" "${_EXTRACT_ERR}compress: .bz2 ne supporte qu'un seul fichier (utilise .tar.bz2 pour plusieurs)${_EXTRACT_RESET}" >&2; return 1; }
            bzip2 -k -c "$1" > "$dest" ;;
        *.xz)
            [ $# -eq 1 ] || { printf "%b\n" "${_EXTRACT_ERR}compress: .xz ne supporte qu'un seul fichier (utilise .tar.xz pour plusieurs)${_EXTRACT_RESET}" >&2; return 1; }
            xz -k -c "$1" > "$dest" ;;
        *.zip)
            command -v zip >/dev/null 2>&1 || { printf "%b\n" "${_EXTRACT_ERR}compress: binaire 'zip' manquant${_EXTRACT_RESET}" >&2; return 1; }
            zip -rq "$dest" "$@" ;;
        *.7z)
            command -v 7z >/dev/null 2>&1 || { printf "%b\n" "${_EXTRACT_ERR}compress: binaire '7z' manquant${_EXTRACT_RESET}" >&2; return 1; }
            7z a "$dest" "$@" >/dev/null ;;
        *.rar)
            command -v rar >/dev/null 2>&1 || { printf "%b\n" "${_EXTRACT_ERR}compress: binaire 'rar' manquant (unrar seul ne compresse pas)${_EXTRACT_RESET}" >&2; return 1; }
            rar a "$dest" "$@" >/dev/null ;;
        *)
            printf "%b\n" "${_EXTRACT_ERR}compress: extension non reconnue pour '${dest}'${_EXTRACT_RESET}" >&2
            printf "%b\n" "${_EXTRACT_INFO}formats supportés: ${_EXTRACT_FORMATS_LIST}${_EXTRACT_RESET}" >&2
            return 1 ;;
    esac

    local rc=$?
    if [ "$rc" -eq 0 ]; then
        printf "%b\n" "${_EXTRACT_OK}compress: ${dest} créé${_EXTRACT_RESET}"
    else
        printf "%b\n" "${_EXTRACT_ERR}compress: échec de la création de '${dest}'${_EXTRACT_RESET}" >&2
    fi
    return "$rc"
}
