#!/usr/bin/env bash
## --- chezmoi: barrel file ---

CHEZMOI_VERSION="1.4.0"
CHEZMOI_REPO="floriaaan/chezmoi"

# Détection du chemin du script, compatible bash ET zsh
_chezmoi_self="${BASH_SOURCE[0]:-$0}"
CHEZMOI_DIR="$(cd "$(dirname "$_chezmoi_self")" && pwd)"
unset _chezmoi_self

CHEZMOI_CACHE="$HOME/.cache/chezmoi_last_check"

# Couleurs
_CHEZMOI_OK='\033[38;5;108m'
_CHEZMOI_WARN='\033[38;5;179m'
_CHEZMOI_ERR='\033[38;5;196m'
_CHEZMOI_INFO='\033[38;5;110m'
_CHEZMOI_RESET='\033[0m'

## --- Activation de la compat "complete" bash sous zsh (pour l'autocomplétion de z) ---
if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz compinit && compinit -u
    autoload -Uz bashcompinit && bashcompinit
fi

## --- Source des modules communs (bash + zsh) ---
## history en premier : certaines options d'historique doivent être posées tôt.
## completion/colors restent en toute fin, juste avant le prompt (comportement inchangé depuis 1.3.0).
for _f in history z git-aliases gtag ports extract ssh completion colors; do
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
            if [ -n "$CHEZMOI_REMOTE" ]; then
                printf "%b\n" "${_CHEZMOI_ERR}chezmoi: session distante (CHEZMOI_REMOTE), pas de dépôt git à jour ici${_CHEZMOI_RESET}" >&2
                return 1
            fi
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
        doctor)
            _chezmoi_doctor
            ;;
        ""|help|-h|--help)
            cat <<EOF
chezmoi - gestion de la config shell perso

Usage:
  chezmoi update     met à jour les fichiers depuis origin/main et recharge
  chezmoi version    affiche la version installée
  chezmoi doctor     vérifie les dépendances et l'état des modules
  chezmoi help       affiche cette aide
EOF
            ;;
        *)
            printf "%b\n" "${_CHEZMOI_WARN}chezmoi: commande inconnue '$1' (essaie 'chezmoi help')${_CHEZMOI_RESET}" >&2
            return 1
            ;;
    esac
}

## --- chezmoi doctor : checklist colorée des dépendances/modules ---
_chezmoi_doctor_check() {
    local desc="$1" ok="$2" optional="${3:-0}"
    if [ "$ok" -eq 1 ]; then
        printf "%b\n" "  ${_CHEZMOI_OK}✔${_CHEZMOI_RESET} ${desc}"
    elif [ "$optional" -eq 1 ]; then
        printf "%b\n" "  ${_CHEZMOI_WARN}○${_CHEZMOI_RESET} ${desc} (optionnel, absent)"
    else
        printf "%b\n" "  ${_CHEZMOI_ERR}✘${_CHEZMOI_RESET} ${desc}"
    fi
}

_chezmoi_doctor() {
    emulate -L bash 2>/dev/null
    printf "%b\n" "${_CHEZMOI_INFO}chezmoi doctor${_CHEZMOI_RESET}"
    local ok

    command -v git >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "git présent" "$ok"

    command -v curl >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "curl présent (vérification de version)" "$ok"

    { command -v ss >/dev/null 2>&1 || command -v netstat >/dev/null 2>&1; } && ok=1 || ok=0
    _chezmoi_doctor_check "ss ou netstat présent (ports)" "$ok"

    command -v tar >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "tar présent (extract)" "$ok"

    command -v unzip >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "unzip présent (extract)" "$ok"

    command -v 7z >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "7z présent (.7z)" "$ok" 1

    command -v unrar >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "unrar présent (.rar)" "$ok" 1

    declare -f ports >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "module ports chargé" "$ok"

    declare -f extract >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "module extract chargé" "$ok"

    declare -f ssh >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "module ssh chargé" "$ok"

    if [ -n "$CHEZMOI_REMOTE" ]; then
        printf "%b\n" "  ${_CHEZMOI_INFO}ℹ${_CHEZMOI_RESET} CHEZMOI_REMOTE actif — session distante (injectée via ssh)"
    fi
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
[ -z "$CHEZMOI_NO_UPDATE_CHECK" ] && [ -z "$CHEZMOI_REMOTE" ] && _chezmoi_check_update

## --- Bannière de chargement ---
if [ -z "$CHEZMOI_NO_BANNER" ]; then
    if [ -n "$CHEZMOI_REMOTE" ]; then
        printf "%b\n" "${_CHEZMOI_OK}chezmoi${_CHEZMOI_RESET} ${_CHEZMOI_INFO}v${CHEZMOI_VERSION}${_CHEZMOI_RESET} chargé, remote"
    else
        printf "%b\n" "${_CHEZMOI_OK}chezmoi${_CHEZMOI_RESET} ${_CHEZMOI_INFO}v${CHEZMOI_VERSION}${_CHEZMOI_RESET} chargé"
    fi
fi