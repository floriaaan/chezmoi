#!/usr/bin/env bash
## --- chezmoi: barrel file ---

CHEZMOI_VERSION="1.3.0"
CHEZMOI_REPO="floriaaan/chezmoi"

# Détection du chemin du script, compatible bash ET zsh
_chezmoi_self="${BASH_SOURCE[0]:-$0}"
CHEZMOI_DIR="$(cd "$(dirname "$_chezmoi_self")" && pwd)"
unset _chezmoi_self

CHEZMOI_CACHE="$HOME/.cache/chezmoi_last_check"

# Couleurs
_CHEZMOI_OK='\033[38;5;108m'
_CHEZMOI_WARN='\033[38;5;179m'
_CHEZMOI_INFO='\033[38;5;110m'
_CHEZMOI_RESET='\033[0m'

## --- Activation de la compat "complete" bash sous zsh (pour l'autocomplétion de z) ---
if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz compinit && compinit -u
    autoload -Uz bashcompinit && bashcompinit
fi

## --- Source des modules communs (bash + zsh) ---
for _f in z git-aliases gtag completion colors; do
    [ -f "$CHEZMOI_DIR/$_f.sh" ] && source "$CHEZMOI_DIR/$_f.sh"
done
unset _f

## --- Prompt : fichier différent selon le shell ---
if [ -n "$ZSH_VERSION" ]; then
    [ -f "$CHEZMOI_DIR/prompt.zsh" ] && source "$CHEZMOI_DIR/prompt.zsh"
else
    [ -f "$CHEZMOI_DIR/prompt.sh" ] && source "$CHEZMOI_DIR/prompt.sh"
fi

## --- Plugins zsh externes (syntax-highlighting/autosuggestions) : doit être sourcé en dernier ---
[ -n "$ZSH_VERSION" ] && declare -f _chezmoi_load_zsh_syntax_plugins >/dev/null 2>&1 && _chezmoi_load_zsh_syntax_plugins

## --- Commande chezmoi ---
chezmoi() {
    case "$1" in
        update)
            if [ ! -d "$CHEZMOI_DIR/.git" ]; then
                printf "%b\n" "${_CHEZMOI_WARN}chezmoi: '$CHEZMOI_DIR' n'est pas un dépôt git, impossible de mettre à jour${_CHEZMOI_RESET}" >&2
                return 1
            fi
            printf "%b\n" "${_CHEZMOI_INFO}chezmoi: mise à jour en cours...${_CHEZMOI_RESET}"
            local before after
            before=$(git -C "$CHEZMOI_DIR" rev-parse HEAD 2>/dev/null)
            if ! git -C "$CHEZMOI_DIR" pull --ff-only origin main; then
                printf "%b\n" "${_CHEZMOI_WARN}chezmoi: échec du pull (conflits locaux ?)${_CHEZMOI_RESET}" >&2
                return 1
            fi
            after=$(git -C "$CHEZMOI_DIR" rev-parse HEAD 2>/dev/null)
            if [ "$before" = "$after" ]; then
                printf "%b\n" "${_CHEZMOI_OK}chezmoi: déjà à jour${_CHEZMOI_RESET}"
                return 0
            fi
            date +%s > "$CHEZMOI_CACHE"
            printf "%b\n" "${_CHEZMOI_OK}chezmoi: mis à jour, rechargement...${_CHEZMOI_RESET}"
            source "$CHEZMOI_DIR/chezmoi.sh"
            ;;
        version|-v|--version)
            printf "%b\n" "${_CHEZMOI_OK}chezmoi${_CHEZMOI_RESET} ${_CHEZMOI_INFO}v${CHEZMOI_VERSION}${_CHEZMOI_RESET}"
            ;;
        ""|help|-h|--help)
            cat <<EOF
chezmoi - gestion de la config shell perso

Usage:
  chezmoi update     met à jour les fichiers depuis origin/main et recharge
  chezmoi version    affiche la version installée
  chezmoi help       affiche cette aide
EOF
            ;;
        *)
            printf "%b\n" "${_CHEZMOI_WARN}chezmoi: commande inconnue '$1' (essaie 'chezmoi help')${_CHEZMOI_RESET}" >&2
            return 1
            ;;
    esac
}

## --- Vérification de version (async, non bloquant) ---
_chezmoi_check_update() {
    mkdir -p "$(dirname "$CHEZMOI_CACHE")"
    local now last_check
    now=$(date +%s)
    last_check=$(cat "$CHEZMOI_CACHE" 2>/dev/null || echo 0)
    [ $((now - last_check)) -lt 86400 ] && return
    (
        local remote_version
        remote_version=$(curl -fsSL --max-time 1 \
            "https://raw.githubusercontent.com/${CHEZMOI_REPO}/main/VERSION" 2>/dev/null)
        if [ -n "$remote_version" ] && [ "$remote_version" != "$CHEZMOI_VERSION" ]; then
            printf "%b\n" "${_CHEZMOI_WARN}chezmoi: nouvelle version disponible (${remote_version}, actuelle: ${CHEZMOI_VERSION})${_CHEZMOI_RESET}" >&2
        fi
        echo "$now" > "$CHEZMOI_CACHE"
    ) & disown 2>/dev/null
}
[ -z "$CHEZMOI_NO_UPDATE_CHECK" ] && _chezmoi_check_update

## --- Bannière de chargement ---
[ -z "$CHEZMOI_NO_BANNER" ] && printf "%b\n" "${_CHEZMOI_OK}chezmoi${_CHEZMOI_RESET} ${_CHEZMOI_INFO}v${CHEZMOI_VERSION}${_CHEZMOI_RESET} chargé"