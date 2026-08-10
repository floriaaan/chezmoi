## --- Prompt façon powerlevel10k (couleurs douces, sans nerd font) [zsh] ---
setopt PROMPT_SUBST
autoload -Uz add-zsh-hook

## Thème du prompt (posé par config.sh depuis "chezmoi config set prompt.theme ..."). Thèmes
## disponibles :
##   default   2 lignes : heure, user@host, chemin, git (branche+dirty+ahead/behind), version de
##             paquet, durée de la commande précédente si >=3s
##   minimal   1 ligne : chemin + git compact (branche+dirty), rien d'autre
##   agnoster  équivalent du thème oh-my-zsh "agnoster" : blocs de couleur pleine (contexte
##             user@host si ssh/root, chemin, git, code de sortie si échec), sans police
##             powerline/nerd font (séparateur ▶ au lieu de la flèche  qui en nécessite une)
## Valeur inconnue -> fallback silencieux sur "default" (cf. _chezmoi_precmd plus bas).
##
## Les blocs "## chezmoi:theme-begin <nom>" / "## chezmoi:theme-end <nom>" ci-dessous délimitent
## le code propre à chaque thème : ssh.sh (_ssh_build_payload) s'en sert pour n'embarquer sur
## l'hôte distant que le code du thème réellement sélectionné (évite de surcharger la charge utile
## avec le rendu des thèmes non utilisés). Ça ne change rien au chargement local, où les deux
## thèmes restent chargés en même temps pour permettre un changement à chaud (cf. config.sh).
CHEZMOI_PROMPT_THEME="${CHEZMOI_PROMPT_THEME:-default}"

_PROMPT_PATH_MAXLEN=60

## --- Repère SSH : testé une seule fois au chargement, $SSH_CONNECTION ne change pas pendant la session ---
if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
    _CHEZMOI_IS_SSH=1
else
    _CHEZMOI_IS_SSH=0
fi

## Joint les N derniers éléments du tableau passé en argument avec "/"
_prompt_join_last() {
    emulate -L zsh
    local count="$1"; shift
    local -a arr=("$@")
    local total=${#arr[@]}
    local start=$((total - count + 1))
    local out="" i
    for ((i = start; i <= total; i++)); do
        out="${out:+$out/}${arr[$i]}"
    done
    printf '%s' "$out"
}

## Tronque un chemin par la gauche sur les séparateurs "/", en gardant au moins les 2 derniers segments
_prompt_truncate_path() {
    emulate -L zsh
    local full="$1"
    if [ "${#full}" -le "$_PROMPT_PATH_MAXLEN" ]; then
        printf '%s' "$full"
        return
    fi
    local stripped="${full#\~}"
    stripped="${stripped#/}"
    local -a segs
    segs=("${(@s:/:)stripped}")
    local n=${#segs[@]}
    if [ "$n" -le 2 ]; then
        printf '…/%s' "$(_prompt_join_last "$n" "${segs[@]}")"
        return
    fi
    local i candidate
    for ((i = n; i >= 2; i--)); do
        candidate="…/$(_prompt_join_last "$i" "${segs[@]}")"
        if [ "${#candidate}" -le "$_PROMPT_PATH_MAXLEN" ] || [ "$i" -eq 2 ]; then
            printf '%s' "$candidate"
            return
        fi
    done
}

_prompt_path_segment() {
    emulate -L zsh
    local full="$PWD"
    case "$full" in
        "$HOME") full="~" ;;
        "$HOME"/*) full="~${full#"$HOME"}" ;;
    esac
    _prompt_truncate_path "$full"
}

_GIT_CACHE_TTL=5
_git_cache_time=0
_git_cache_pwd=""
_git_cache_branch=""
_git_cache_dirty=""
_git_cache_ahead=""
_git_cache_behind=""

_git_refresh_cache() {
    local now
    now=$(date +%s)
    if [ "$PWD" = "$_git_cache_pwd" ] && [ $((now - _git_cache_time)) -lt "$_GIT_CACHE_TTL" ]; then
        return
    fi
    _git_cache_pwd="$PWD"
    _git_cache_time=$now
    _git_cache_branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [ -z "$_git_cache_branch" ]; then
        _git_cache_dirty=""; _git_cache_ahead=""; _git_cache_behind=""
        return
    fi
    if git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
        _git_cache_dirty=""
    else
        _git_cache_dirty="1"
    fi
    local counts
    counts=$(git rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
    if [ -n "$counts" ]; then
        _git_cache_behind=$(echo "$counts" | awk '{print $1}')
        _git_cache_ahead=$(echo "$counts" | awk '{print $2}')
    else
        _git_cache_ahead=""; _git_cache_behind=""
    fi
}

## chezmoi:theme-begin default
_git_segment() {
    _git_refresh_cache
    [ -z "$_git_cache_branch" ] && return
    local dirty="" ab=""
    [ -n "$_git_cache_dirty" ] && dirty=" %F{167}●%f"
    [ -n "$_git_cache_ahead" ] && [ "$_git_cache_ahead" -gt 0 ] 2>/dev/null && ab="${ab} %F{108}↑${_git_cache_ahead}%f"
    [ -n "$_git_cache_behind" ] && [ "$_git_cache_behind" -gt 0 ] 2>/dev/null && ab="${ab} %F{167}↓${_git_cache_behind}%f"
    echo " on %F{179}⎇ $_git_cache_branch%f$dirty$ab"
}

_pkg_version_segment() {
    local file version
    if [ -f "package.json" ]; then
        file="package.json"
    elif [ -f "composer.json" ]; then
        file="composer.json"
    else
        return
    fi
    version=$(grep -m1 '"version"' "$file" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z0-9._-]*')
    [ -z "$version" ] && return
    echo " %F{108}v$version%f"
}

## --- Timer de durée de commande ---
_cmd_timer_start=""
_chezmoi_preexec() {
    _cmd_timer_start=$SECONDS
}
add-zsh-hook preexec _chezmoi_preexec

_duration_segment() {
    local dur=""
    if [ -n "$_cmd_timer_start" ]; then
        dur=$((SECONDS - _cmd_timer_start))
    fi
    _cmd_timer_start=""
    [ -z "$dur" ] && return
    [ "$dur" -lt 3 ] && return
    local h=$((dur/3600)) m=$(((dur%3600)/60)) s=$((dur%60)) out=""
    [ "$h" -gt 0 ] && out="${out}${h}h"
    [ "$m" -gt 0 ] && out="${out}${m}m"
    out="${out}${s}s"
    echo " %F{244}took ${out}%f"
}

_chezmoi_precmd_default() {
    local time_seg="%F{244}[%D{%Y-%m-%dT%H:%M:%S}]%f"
    local host_color=110 ssh_seg=""
    if [ "$_CHEZMOI_IS_SSH" = "1" ]; then
        host_color=208
        ssh_seg="%F{208}[ssh]%f "
    fi
    local host_seg="${ssh_seg}%F{${host_color}}[%n@%m]%f"
    local path_txt
    path_txt="$(_prompt_path_segment)"
    local dir_seg="%F{73}${path_txt}%f"
    PROMPT="
${time_seg} ${host_seg} ${dir_seg}$(_git_segment)$(_pkg_version_segment)$(_duration_segment)
%F{108}❯%f "
}
## chezmoi:theme-end default

## chezmoi:theme-begin minimal
## Version compacte du segment git : juste "(branche●)", pas d'ahead/behind.
_git_segment_minimal() {
    _git_refresh_cache
    [ -z "$_git_cache_branch" ] && return
    local dirty=""
    [ -n "$_git_cache_dirty" ] && dirty="●"
    echo " %F{244}(${_git_cache_branch}${dirty})%f"
}

## Une ligne : chemin + git compact, rien d'autre (pas d'heure/host/version de paquet/durée).
_chezmoi_precmd_minimal() {
    local ssh_seg=""
    [ "$_CHEZMOI_IS_SSH" = "1" ] && ssh_seg="%F{208}[ssh]%f "
    local path_txt
    path_txt="$(_prompt_path_segment)"
    local dir_seg="%F{73}${path_txt}%f"
    PROMPT="${ssh_seg}${dir_seg}$(_git_segment_minimal) %F{108}❯%f "
}
## chezmoi:theme-end minimal

## chezmoi:theme-begin agnoster
## Équivalent du thème oh-my-zsh "agnoster" sans police powerline/nerd font : blocs de couleur
## pleine (contexte/chemin/git/statut), chacun terminé par un ▶ dans sa propre couleur plutôt que
## par la flèche  qui nécessite une police patchée ("effet drapeau" au lieu d'un fondu continu).
_agnoster_segment() {
    local bg="$1" fg="$2" text="$3"
    echo "%K{${bg}}%F{${fg}} ${text} %f%k%F{${bg}}▶%f"
}

## Contexte user@host : masqué en local (bruit inutile, comme le vrai agnoster), affiché en
## orange en session ssh, en rouge si root (prioritaire sur ssh).
_agnoster_context_segment() {
    local is_root=0
    [ "${EUID:-1000}" -eq 0 ] 2>/dev/null && is_root=1
    if [ "$is_root" -eq 1 ]; then
        _agnoster_segment 196 255 "%n@%m"
        return
    fi
    [ "$_CHEZMOI_IS_SSH" = "1" ] || return
    _agnoster_segment 208 0 "%n@%m"
}

_agnoster_dir_segment() {
    local path_txt
    path_txt="$(_prompt_path_segment)"
    _agnoster_segment 73 0 "$path_txt"
}

_agnoster_git_segment() {
    _git_refresh_cache
    [ -z "$_git_cache_branch" ] && return
    local bg=108 mark="⎇ ${_git_cache_branch}"
    [ -n "$_git_cache_dirty" ] && bg=179 && mark="${mark} ±"
    _agnoster_segment "$bg" 0 "$mark"
}

## Segment de statut : uniquement affiché si la commande précédente a échoué (comme le vrai agnoster).
_agnoster_status_segment() {
    local ec="$1"
    [ -z "$ec" ] && return
    [ "$ec" -eq 0 ] 2>/dev/null && return
    _agnoster_segment 196 255 "✘ ${ec}"
}

_chezmoi_precmd_agnoster() {
    local ec=$?
    PROMPT="$(_agnoster_context_segment)$(_agnoster_dir_segment)$(_agnoster_git_segment)$(_agnoster_status_segment "$ec") "
}
## chezmoi:theme-end agnoster

_chezmoi_precmd() {
    case "$CHEZMOI_PROMPT_THEME" in
        minimal)  _chezmoi_precmd_minimal ;;
        agnoster) _chezmoi_precmd_agnoster ;;
        *)        _chezmoi_precmd_default ;;
    esac
}
add-zsh-hook precmd _chezmoi_precmd
