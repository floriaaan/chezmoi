#!/usr/bin/env bash
## --- chezmoi: barrel file ---

CHEZMOI_REPO="floriaaan/chezmoi"

# Détection du chemin du script, compatible bash ET zsh
_chezmoi_self="${BASH_SOURCE[0]:-$0}"
CHEZMOI_DIR="$(cd "$(dirname "$_chezmoi_self")" && pwd)"
unset _chezmoi_self

# Le fichier VERSION est l'unique source de vérité (pas de numéro dupliqué en dur ici)
CHEZMOI_VERSION="$(cat "$CHEZMOI_DIR/VERSION" 2>/dev/null)"
[ -z "$CHEZMOI_VERSION" ] && CHEZMOI_VERSION="0.0.0"

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
## config en premier : ssh.sh (modules embarqués), prompt.sh/.zsh (thème) et le reste du barrel
## (modules.disabled, cf. ci-dessous) lisent les valeurs qu'il pose. history ensuite : certaines
## options d'historique doivent être posées tôt. completion/colors restent en toute fin, juste
## avant le prompt (comportement inchangé depuis 1.3.0). "config" n'est jamais désactivable (c'est
## lui qui porte la liste des modules désactivés -- cf. _chezmoi_modules_cmd) : le filtre ci-dessous
## ne s'applique qu'à partir du 2e module de la liste, une fois CHEZMOI_MODULES_DISABLED déjà posée.
## Liste en mots littéraux (pas une variable "for x in $VAR") à dessein : zsh natif (sans
## "emulate -L bash") ne découpe PAS un scalaire non guillemeté sur les espaces (contrairement à
## bash, où c'est le comportement par défaut) -- une boucle sur une variable multi-mots itérerait
## ici sur un seul "mot" (toute la chaîne). _CHEZMOI_MODULES_LIST est construite ci-dessous par
## simple concaténation de chaîne (sûr, aucun découpage requis) pour l'affichage/les recherches
## par motif ("chezmoi modules", "chezmoi doctor", complétion...), jamais pour boucler dessus.
_CHEZMOI_MODULES_LIST=""
for _f in config history z git-aliases gtag ports extract ssh docker net completion colors; do
    _CHEZMOI_MODULES_LIST="${_CHEZMOI_MODULES_LIST:+$_CHEZMOI_MODULES_LIST }$_f"
    case " ${CHEZMOI_MODULES_DISABLED:-} " in
        *" $_f "*) continue ;;
    esac
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
        reload)
            printf "%b\n" "${_CHEZMOI_INFO}chezmoi: rechargement...${_CHEZMOI_RESET}"
            source "$CHEZMOI_DIR/chezmoi.sh"
            ;;
        version|-v|--version)
            printf "%b\n" "${_CHEZMOI_OK}chezmoi${_CHEZMOI_RESET} ${_CHEZMOI_INFO}v${CHEZMOI_VERSION}${_CHEZMOI_RESET}"
            ;;
        doctor)
            _chezmoi_doctor
            ;;
        config)
            shift
            _chezmoi_config_cmd "$@"
            ;;
        modules)
            shift
            _chezmoi_modules_cmd "$@"
            ;;
        bench)
            _chezmoi_bench
            ;;
        ""|help|-h|--help)
            cat <<EOF
chezmoi - gestion de la config shell perso

Usage:
  chezmoi update     met à jour les fichiers depuis origin/main et recharge
  chezmoi reload     resource les fichiers depuis le disque, sans git pull (relit une modif locale)
  chezmoi version    affiche la version installée
  chezmoi doctor     vérifie les dépendances et l'état des modules
  chezmoi config     préférences persistantes (thème du prompt, modules ssh) ; 'chezmoi config help' pour le détail
  chezmoi modules    active/désactive des modules du barrel ; 'chezmoi modules help' pour le détail
  chezmoi bench      mesure le temps de chargement de chaque module du barrel
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

    declare -f _chezmoi_config_cmd >/dev/null 2>&1 && ok=1 || ok=0
    _chezmoi_doctor_check "module config chargé" "$ok"

    if [ -n "$CHEZMOI_REMOTE" ]; then
        printf "%b\n" "  ${_CHEZMOI_INFO}ℹ${_CHEZMOI_RESET} CHEZMOI_REMOTE actif — session distante (injectée via ssh)"
    fi
    if [ -n "$CHEZMOI_MODULES_DISABLED" ]; then
        printf "%b\n" "  ${_CHEZMOI_WARN}○${_CHEZMOI_RESET} modules désactivés: ${CHEZMOI_MODULES_DISABLED}"
    fi
}

## --- chezmoi modules : active/désactive des modules du barrel sans éditer chezmoi.sh (façon
## "apt"/"brew"), via la clé de config modules.disabled (cf. config.sh) ---
## Même liste littérale que la boucle du barrel plus haut (pas "for m in $_CHEZMOI_MODULES_LIST" :
## même piège de découpage sous zsh natif, cf. commentaire sur la boucle du barrel).
_chezmoi_modules_list() {
    printf "%b\n" "${_CHEZMOI_INFO}chezmoi modules${_CHEZMOI_RESET}"
    local m
    for m in config history z git-aliases gtag ports extract ssh docker net completion colors; do
        case " ${CHEZMOI_MODULES_DISABLED:-} " in
            *" $m "*) printf "%b\n" "  ${_CHEZMOI_WARN}○${_CHEZMOI_RESET} ${m} (désactivé)" ;;
            *)        printf "%b\n" "  ${_CHEZMOI_OK}✔${_CHEZMOI_RESET} ${m}" ;;
        esac
    done
}

## Recherche par motif (pas une boucle) : sûr sous n'importe quel mode shell, aucun découpage requis.
_chezmoi_modules_is_known() {
    case " ${_CHEZMOI_MODULES_LIST} " in
        *" $1 "*) return 0 ;;
        *)        return 1 ;;
    esac
}

## Persiste la nouvelle liste (via config.sh si chargé) et la répercute tout de suite sur
## CHEZMOI_MODULES_DISABLED, comme les autres clés de "chezmoi config set". Liste vide -> "unset"
## plutôt que "set ... ''" : _chezmoi_config_set traite une valeur vide comme "pas de valeur"
## (liste les choix au lieu d'écrire, cf. config.sh), donc "set modules.disabled ''" n'écrirait rien.
## "emulate -L bash" ici : $1 est une liste dynamique (contenu de CHEZMOI_MODULES_DISABLED + un
## nom ajouté/retiré), son découpage par le "printf ... $1" a besoin du comportement bash (même
## convention que _ssh_prompt_segments_sanitize dans ssh.sh pour une liste dynamique similaire) --
## sans risque ici, cette fonction ne source aucun fichier de module.
_chezmoi_modules_persist_disabled() {
    emulate -L bash 2>/dev/null
    local list
    list=$(printf '%s\n' $1 | sort -u | tr '\n' ' ')
    list="${list% }"
    if [ -z "$list" ]; then
        if declare -f _chezmoi_config_unset >/dev/null 2>&1; then
            _chezmoi_config_unset modules.disabled >/dev/null
        else
            CHEZMOI_MODULES_DISABLED=""
        fi
        return
    fi
    if declare -f _chezmoi_config_set >/dev/null 2>&1; then
        _chezmoi_config_set modules.disabled "$list" >/dev/null
    else
        CHEZMOI_MODULES_DISABLED="$list"
    fi
}

## "emulate -L bash" : la branche "enable" reconstruit la liste en bouclant sur
## CHEZMOI_MODULES_DISABLED (liste dynamique) -- même raison que _chezmoi_modules_persist_disabled.
_chezmoi_modules_cmd() {
    emulate -L bash 2>/dev/null
    case "$1" in
        ""|list)
            _chezmoi_modules_list
            ;;
        disable)
            local name="$2"
            if [ -z "$name" ]; then
                printf "%b\n" "${_CHEZMOI_ERR}chezmoi modules: usage: chezmoi modules disable <module>${_CHEZMOI_RESET}" >&2
                return 1
            fi
            if [ "$name" = "config" ]; then
                printf "%b\n" "${_CHEZMOI_ERR}chezmoi modules: 'config' ne peut pas être désactivé (porte modules.disabled lui-même)${_CHEZMOI_RESET}" >&2
                return 1
            fi
            if ! _chezmoi_modules_is_known "$name"; then
                printf "%b\n" "${_CHEZMOI_ERR}chezmoi modules: module inconnu '${name}' (modules: ${_CHEZMOI_MODULES_LIST})${_CHEZMOI_RESET}" >&2
                return 1
            fi
            case " ${CHEZMOI_MODULES_DISABLED:-} " in
                *" $name "*) ;;
                *) _chezmoi_modules_persist_disabled "${CHEZMOI_MODULES_DISABLED:-} $name" ;;
            esac
            printf "%b\n" "${_CHEZMOI_OK}chezmoi modules: '${name}' désactivé (effectif au prochain 'chezmoi reload' ou nouveau shell)${_CHEZMOI_RESET}"
            ;;
        enable)
            local name="$2" kept="" m
            if [ -z "$name" ]; then
                printf "%b\n" "${_CHEZMOI_ERR}chezmoi modules: usage: chezmoi modules enable <module>${_CHEZMOI_RESET}" >&2
                return 1
            fi
            for m in ${CHEZMOI_MODULES_DISABLED:-}; do
                [ "$m" = "$name" ] || kept="${kept:+$kept }$m"
            done
            _chezmoi_modules_persist_disabled "$kept"
            printf "%b\n" "${_CHEZMOI_OK}chezmoi modules: '${name}' réactivé (effectif au prochain 'chezmoi reload' ou nouveau shell)${_CHEZMOI_RESET}"
            ;;
        help|-h|--help)
            cat <<EOF
chezmoi modules - active/désactive des modules du barrel sans éditer chezmoi.sh

Usage:
  chezmoi modules                    liste les modules et leur état (alias: chezmoi modules list)
  chezmoi modules disable <module>   désactive un module (persisté, effectif au prochain reload/shell)
  chezmoi modules enable <module>    réactive un module

Modules: ${_CHEZMOI_MODULES_LIST}
'config' ne peut pas être désactivé (porte la liste des modules désactivés).
EOF
            ;;
        *)
            printf "%b\n" "${_CHEZMOI_ERR}chezmoi modules: sous-commande inconnue '${1}' (essaie 'chezmoi modules help')${_CHEZMOI_RESET}" >&2
            return 1
            ;;
    esac
}

## --- chezmoi bench : temps de chargement (source) de chaque module du barrel, dans l'ordre réel
## de chargement -- utile pour repérer un module devenu lent (ex: un hookup de complétion qui
## fork/exec un binaire). Tourne dans un sous-shell dédié : ne pollue jamais la session courante,
## et reflète le comportement réel (modules déjà désactivés via "chezmoi modules" restent sautés).
_chezmoi_bench_now() {
    emulate -L bash 2>/dev/null
    ## EPOCHREALTIME est formatée selon LC_NUMERIC (ex: "1700000000,123456" en locale fr_FR) :
    ## la virgule casserait l'arithmétique awk faite dessus par l'appelant (awk n'y verrait que
    ## la partie entière). Normalisée en notation décimale à point ici, une bonne fois.
    if [ -n "$EPOCHREALTIME" ]; then
        printf '%s' "${EPOCHREALTIME//,/.}"
        return
    fi
    if [ -n "$ZSH_VERSION" ]; then
        zmodload zsh/datetime 2>/dev/null
        if [ -n "$EPOCHREALTIME" ]; then
            printf '%s' "${EPOCHREALTIME//,/.}"
            return
        fi
    fi
    ## Repli (bash < 5.0 sans EPOCHREALTIME, ou zsh/datetime indisponible) : nanosecondes GNU date
    ## si dispo, sinon la seconde entière (précision dégradée mais jamais de plantage). LC_NUMERIC=C
    ## pour le même motif que ci-dessus : awk formate "%.9f" selon la locale sans ça.
    local ns
    ns=$(date +%s%N 2>/dev/null)
    case "$ns" in
        *[!0-9]*|"") date +%s ;;
        *)           LC_NUMERIC=C awk -v n="$ns" 'BEGIN{printf "%.9f", n/1000000000}' ;;
    esac
}

## Pas d'"emulate -L bash" ici (contrairement à la plupart des fonctions de ce fichier) : le
## sous-shell ci-dessous "source" les vrais modules du barrel, exactement comme le fait le vrai
## barrel (sans émulation) -- il hérite donc du mode ambiant de l'appelant, ni plus ni moins,
## comme "chezmoi reload"/"chezmoi update" (qui font le même "source" du barrel complet). La liste
## ci-dessous est en mots littéraux, pas "for mod in $_CHEZMOI_MODULES_LIST" (même piège de
## découpage que la boucle du barrel, cf. son commentaire plus haut).
_chezmoi_bench() {
    printf "%b\n" "${_CHEZMOI_INFO}chezmoi bench${_CHEZMOI_RESET} (ordre réel de chargement du barrel)"
    (
        CHEZMOI_NO_BANNER=1
        CHEZMOI_NO_UPDATE_CHECK=1
        local mod file start end ms total_ms=0
        for mod in config history z git-aliases gtag ports extract ssh docker net completion colors; do
            case " ${CHEZMOI_MODULES_DISABLED:-} " in
                *" $mod "*)
                    printf "%b\n" "  ${_CHEZMOI_WARN}○${_CHEZMOI_RESET} ${mod} (désactivé, sauté)"
                    continue
                    ;;
            esac
            file="$CHEZMOI_DIR/$mod.sh"
            [ -f "$file" ] || continue
            start=$(_chezmoi_bench_now)
            source "$file"
            end=$(_chezmoi_bench_now)
            ms=$(LC_NUMERIC=C awk -v a="$start" -v b="$end" 'BEGIN{printf "%.1f", (b-a)*1000}')
            total_ms=$(LC_NUMERIC=C awk -v a="$total_ms" -v b="$ms" 'BEGIN{printf "%.1f", a+b}')
            printf "  %-14s %8s ms\n" "$mod" "$ms"
        done
        printf "%b\n" "${_CHEZMOI_OK}total: ${total_ms} ms${_CHEZMOI_RESET}"
    )
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