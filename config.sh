## --- config: préférences persistantes chezmoi (thème du prompt, modules embarqués en ssh...) ---
## Fichier texte simple "clé=valeur" (une par ligne). Chargé tôt dans le barrel (avant ssh.sh et
## prompt.sh/.zsh) pour que ces modules voient la valeur dès le démarrage ; `chezmoi config set`
## l'applique aussi immédiatement à la session en cours (pas besoin de relancer le shell).
##
## Clés connues aujourd'hui :
##   prompt.theme      thème du prompt : "default", "minimal" ou "agnoster" (cf. prompt.sh)
##   prompt.segments   liste ordonnée (espacée) des segments affichés par le prompt, quel que soit
##                     le thème actif ; vide -> liste par défaut du thème (cf. prompt.sh)
##   ssh.modules       modules chezmoi embarqués par le wrapper ssh (défaut: "prompt git-aliases gtag")
##
## "chezmoi config set <clé>" sans valeur, pour une clé à choix fermé (ex: prompt.theme), liste les
## valeurs possibles au lieu d'échouer (cf. _chezmoi_config_choices). prompt.segments est une clé à
## valeur libre (la combinatoire des listes n'est pas énumérable) mais bénéficie du même traitement
## que prompt.theme sans valeur : liste le catalogue de segments valides plutôt que d'échouer
## (cf. _chezmoi_config_set, cas spécial avant le fallback générique clé-libre).

CHEZMOI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"

_CHEZMOI_CONFIG_KEYS="prompt.theme prompt.segments ssh.modules"

## Catalogue des segments valides pour prompt.segments (cf. prompt.sh pour le détail de chacun).
_CHEZMOI_PROMPT_SEGMENT_NAMES="time user dir git pkg node duration exitcode"

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
        prompt.theme)    printf '%s' "default" ;;
        prompt.segments) printf '%s' "" ;;
        ssh.modules)     printf '%s' "prompt git-aliases gtag" ;;
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

## Aperçu (statique, indépendant du répertoire/état git réels) d'un choix pour une clé donnée, vide
## si la clé n'en a pas. Utilise des couleurs ANSI brutes (imprimées via "printf %b", même mécanisme
## que _CONFIG_OK etc. plus haut) plutôt que les échappements PS1/PROMPT (\D{}/\u/\h, %F/%K) : ça
## reste indépendant de bash vs zsh et s'affiche correctement avec un simple printf, pas seulement
## une fois posé comme PS1 réel.
_chezmoi_config_preview() {
    local key="$1" choice="$2"
    [ "$key" = "prompt.theme" ] || return 0
    case "$choice" in
        default)
            printf '%b\n' "      \033[38;5;244m[2026-08-10T12:00:03]\033[0m \033[38;5;110m[user@host]\033[0m \033[38;5;73m~/dev/myproject\033[0m on \033[38;5;179m⎇ main\033[0m \033[38;5;167m●\033[0m \033[38;5;108m↑1\033[0m \033[38;5;108mv1.2.3\033[0m"
            printf '%b\n' "      \033[38;5;108m❯\033[0m "
            ;;
        minimal)
            printf '%b\n' "      \033[38;5;73m~/dev/myproject\033[0m \033[38;5;244m(main●)\033[0m \033[38;5;108m❯\033[0m "
            ;;
        agnoster)
            printf '%b\n' "      \033[48;5;73m\033[38;5;0m ~/dev/myproject \033[0m\033[38;5;73m▶\033[0m\033[48;5;179m\033[38;5;0m ⎇ main ± \033[0m\033[38;5;179m▶\033[0m "
            ;;
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
        prompt.theme)    CHEZMOI_PROMPT_THEME="$val" ;;
        prompt.segments) CHEZMOI_PROMPT_SEGMENTS="$val" ;;
        ssh.modules)     _SSH_CHEZMOI_MODULES="$val" ;;
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
        ## prompt.segments : valeur libre (liste), donc pas de combinatoire énumérable via
        ## _chezmoi_config_choices, mais on liste quand même le catalogue de noms valides plutôt
        ## que d'échouer bêtement -- même confort que prompt.theme sans valeur.
        if [ "$key" = "prompt.segments" ]; then
            current="$(_chezmoi_config_get "$key")"
            printf "%b\n" "${_CONFIG_INFO}chezmoi config: prompt.segments = liste ordonnée (espacée) de segments${_CONFIG_RESET}"
            printf "%b\n" "  ${_CONFIG_OK}actuel${_CONFIG_RESET} = ${current:-<vide, défaut du thème>}"
            printf "%b\n" "  ${_CONFIG_INFO}segments valides:${_CONFIG_RESET} ${_CHEZMOI_PROMPT_SEGMENT_NAMES}"
            printf "%b\n" "  ${_CONFIG_INFO}exemple:${_CONFIG_RESET} chezmoi config set prompt.segments \"time dir git node\""
            return 0
        fi
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
            _chezmoi_config_preview "$key" "$c"
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
  chezmoi config set <clé>          sans valeur : liste les choix possibles (clés à choix fermé),
                                     avec un aperçu pour prompt.theme ; pour prompt.segments,
                                     liste le catalogue de segments valides
  chezmoi config unset <clé>        réinitialise une clé à sa valeur par défaut

Clés connues:
  prompt.theme     thème du prompt : "default" (2 lignes, complet), "minimal" (1 ligne, compact)
                   ou "agnoster" (équivalent oh-my-zsh, blocs de couleur, sans nerd font)
  prompt.segments  liste ordonnée (espacée) des segments affichés, ex: "time dir git node".
                   Vide -> liste par défaut du thème actif. Catalogue: ${_CHEZMOI_PROMPT_SEGMENT_NAMES}
  ssh.modules      modules chezmoi embarqués par le wrapper ssh (défaut: "prompt git-aliases gtag")
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
