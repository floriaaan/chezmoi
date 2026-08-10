## --- config: préférences persistantes chezmoi (thème du prompt, modules embarqués en ssh...) ---
## Fichier texte simple "clé=valeur" (une par ligne). Chargé tôt dans le barrel (avant ssh.sh et
## prompt.sh/.zsh) pour que ces modules voient la valeur dès le démarrage ; `chezmoi config set`
## l'applique aussi immédiatement à la session en cours (pas besoin de relancer le shell).
##
## Clés connues aujourd'hui :
##   prompt.theme   thème du prompt : "default", "minimal" ou "agnoster" (cf. prompt.sh)
##   ssh.modules    modules chezmoi embarqués par le wrapper ssh (défaut: "prompt git-aliases gtag")
##
## "chezmoi config set <clé>" sans valeur, pour une clé à choix fermé (ex: prompt.theme), liste les
## valeurs possibles au lieu d'échouer (cf. _chezmoi_config_choices).

CHEZMOI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"

_CHEZMOI_CONFIG_KEYS="prompt.theme ssh.modules"

_CONFIG_OK='\033[38;5;108m'
_CONFIG_WARN='\033[38;5;179m'
_CONFIG_ERR='\033[38;5;196m'
_CONFIG_INFO='\033[38;5;110m'
_CONFIG_RESET='\033[0m'

_chezmoi_config_is_known() {
    local key="$1" k
    for k in $_CHEZMOI_CONFIG_KEYS; do
        [ "$k" = "$key" ] && return 0
    done
    return 1
}

_chezmoi_config_default() {
    case "$1" in
        prompt.theme) printf '%s' "default" ;;
        ssh.modules)  printf '%s' "prompt git-aliases gtag" ;;
    esac
}

## Valeurs possibles pour une clé à choix fermé, vide si la clé accepte une valeur libre
## (ex: ssh.modules, dont les valeurs possibles ne sont pas énumérables).
_chezmoi_config_choices() {
    case "$1" in
        prompt.theme) printf '%s' "default minimal agnoster" ;;
        *) printf '%s' "" ;;
    esac
}

## Valeur persistée pour une clé (dernière ligne "clé=..." qui matche dans le fichier), sinon le défaut.
_chezmoi_config_get() {
    local key="$1" val=""
    [ -f "$CHEZMOI_CONFIG_FILE" ] && val=$(grep "^${key}=" "$CHEZMOI_CONFIG_FILE" 2>/dev/null | tail -n1 | cut -d= -f2-)
    [ -n "$val" ] && printf '%s' "$val" || _chezmoi_config_default "$key"
}

## Répercute la valeur d'une clé connue sur la variable d'environnement lue par le module concerné.
_chezmoi_config_apply() {
    local key="$1" val
    val="$(_chezmoi_config_get "$key")"
    case "$key" in
        prompt.theme) CHEZMOI_PROMPT_THEME="$val" ;;
        ssh.modules)  _SSH_CHEZMOI_MODULES="$val" ;;
    esac
}

_chezmoi_config_load_all() {
    local k
    for k in $_CHEZMOI_CONFIG_KEYS; do
        _chezmoi_config_apply "$k"
    done
}

_chezmoi_config_list() {
    local k v
    printf "%b\n" "${_CONFIG_INFO}chezmoi config${_CONFIG_RESET}"
    for k in $_CHEZMOI_CONFIG_KEYS; do
        v=$(_chezmoi_config_get "$k")
        printf "%b\n" "  ${_CONFIG_OK}${k}${_CONFIG_RESET} = ${v}"
    done
}

## Sans valeur : liste les choix possibles pour une clé à choix fermé (ex: prompt.theme) au lieu
## d'échouer ; pour une clé à valeur libre (ex: ssh.modules), affiche toujours l'usage.
_chezmoi_config_set() {
    local key="$1" val="$2" tmp choices current c
    if ! _chezmoi_config_is_known "$key"; then
        printf "%b\n" "${_CONFIG_ERR}chezmoi config: clé inconnue '${key}' (clés: ${_CHEZMOI_CONFIG_KEYS})${_CONFIG_RESET}" >&2
        return 1
    fi
    if [ -z "$val" ]; then
        choices="$(_chezmoi_config_choices "$key")"
        if [ -z "$choices" ]; then
            printf "%b\n" "${_CONFIG_ERR}chezmoi config: usage: chezmoi config set <clé> <valeur>${_CONFIG_RESET}" >&2
            return 1
        fi
        current="$(_chezmoi_config_get "$key")"
        printf "%b\n" "${_CONFIG_INFO}chezmoi config: valeurs possibles pour '${key}':${_CONFIG_RESET}"
        for c in $choices; do
            if [ "$c" = "$current" ]; then
                printf "%b\n" "  ${_CONFIG_OK}${c}${_CONFIG_RESET} (actif)"
            else
                printf "%b\n" "  ${c}"
            fi
        done
        return 0
    fi
    mkdir -p "$CHEZMOI_CONFIG_DIR"
    tmp=$(mktemp)
    [ -f "$CHEZMOI_CONFIG_FILE" ] && grep -v "^${key}=" "$CHEZMOI_CONFIG_FILE" > "$tmp"
    printf '%s=%s\n' "$key" "$val" >> "$tmp"
    mv "$tmp" "$CHEZMOI_CONFIG_FILE"
    _chezmoi_config_apply "$key"
    printf "%b\n" "${_CONFIG_OK}chezmoi config: ${key} = ${val}${_CONFIG_RESET}"
}

_chezmoi_config_unset() {
    local key="$1" tmp default
    if ! _chezmoi_config_is_known "$key"; then
        printf "%b\n" "${_CONFIG_ERR}chezmoi config: clé inconnue '${key}' (clés: ${_CHEZMOI_CONFIG_KEYS})${_CONFIG_RESET}" >&2
        return 1
    fi
    if [ -f "$CHEZMOI_CONFIG_FILE" ]; then
        tmp=$(mktemp)
        grep -v "^${key}=" "$CHEZMOI_CONFIG_FILE" > "$tmp"
        mv "$tmp" "$CHEZMOI_CONFIG_FILE"
    fi
    _chezmoi_config_apply "$key"
    default="$(_chezmoi_config_default "$key")"
    printf "%b\n" "${_CONFIG_OK}chezmoi config: ${key} réinitialisée (défaut: ${default})${_CONFIG_RESET}"
}

_chezmoi_config_cmd() {
    case "$1" in
        ""|list)
            _chezmoi_config_list
            ;;
        get)
            if [ -z "$2" ]; then
                printf "%b\n" "${_CONFIG_ERR}chezmoi config: usage: chezmoi config get <clé>${_CONFIG_RESET}" >&2
                return 1
            fi
            if ! _chezmoi_config_is_known "$2"; then
                printf "%b\n" "${_CONFIG_ERR}chezmoi config: clé inconnue '${2}' (clés: ${_CHEZMOI_CONFIG_KEYS})${_CONFIG_RESET}" >&2
                return 1
            fi
            _chezmoi_config_get "$2"
            printf '\n'
            ;;
        set)
            _chezmoi_config_set "$2" "$3"
            ;;
        unset)
            if [ -z "$2" ]; then
                printf "%b\n" "${_CONFIG_ERR}chezmoi config: usage: chezmoi config unset <clé>${_CONFIG_RESET}" >&2
                return 1
            fi
            _chezmoi_config_unset "$2"
            ;;
        help|-h|--help)
            cat <<EOF
chezmoi config - préférences persistantes (thème du prompt, modules embarqués en ssh)

Usage:
  chezmoi config                    liste les clés et leurs valeurs actuelles
  chezmoi config get <clé>          affiche la valeur d'une clé
  chezmoi config set <clé> <valeur> définit une clé (persisté + appliqué immédiatement)
  chezmoi config set <clé>          sans valeur : liste les choix possibles (clés à choix fermé)
  chezmoi config unset <clé>        réinitialise une clé à sa valeur par défaut

Clés connues:
  prompt.theme    thème du prompt : "default" (2 lignes, complet), "minimal" (1 ligne, compact)
                  ou "agnoster" (équivalent oh-my-zsh, blocs de couleur, sans nerd font)
  ssh.modules     modules chezmoi embarqués par le wrapper ssh (défaut: "prompt git-aliases gtag")
EOF
            ;;
        *)
            printf "%b\n" "${_CONFIG_ERR}chezmoi config: sous-commande inconnue '${1}' (essaie 'chezmoi config help')${_CONFIG_RESET}" >&2
            return 1
            ;;
    esac
}

## --- Charge la config persistée dès le source (avant ssh.sh/prompt.sh dans le barrel) ---
_chezmoi_config_load_all
