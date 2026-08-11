## --- Prompt façon powerlevel10k (couleurs douces, sans nerd font) ---

## Thème du prompt (posé par config.sh depuis "chezmoi config set prompt.theme ..."). Thèmes
## disponibles :
##   default   reproduit à l'identique le PS1 par défaut de bash (squelette Debian /etc/skel/.bashrc) :
##             user@host en vert vif, chemin en bleu vif (couleurs ANSI 01;32/01;34 brutes, pas la
##             palette 256 adoucie des autres thèmes), une seule ligne, aucun segment additionnel --
##             prompt.segments ne s'applique donc pas à ce thème (fidélité à l'original prime)
##   minimal   1 ligne : segments par défaut "dir git" (git en rendu compact, sans ahead/behind)
##   agnoster  équivalent du thème oh-my-zsh "agnoster" : segments par défaut "user dir git exitcode"
##             en blocs de couleur pleine, sans police powerline/nerd font (séparateur ▶ au lieu de
##             la flèche  qui en nécessite une)
##   floriaaan 2 lignes façon powerlevel10k : segments par défaut "time user dir git pkg duration"
## Valeur inconnue -> fallback silencieux sur "default" (cf. _build_ps1 plus bas).
##
## Segments : chaque thème affiche une LISTE ORDONNÉE de segments (séparés par des espaces),
## personnalisable via "chezmoi config set prompt.segments '<liste>'" (ex: "time dir git node"),
## appliquée quel que soit le thème actif. Vide/non posée -> liste par défaut du thème (ci-dessus).
## Nom de segment inconnu -> ignoré silencieusement (même logique de fallback que pour le thème).
## Catalogue :
##   time      heure courante
##   user      user@host (préfixé "[ssh]" en session distante ; masqué en agnoster hors ssh/root)
##   dir       chemin courant (tronqué, cf. _prompt_truncate_path)
##   git       branche + dirty + ahead/behind (rendu compact en thème minimal : pas d'ahead/behind)
##   pkg       version lue dans package.json/composer.json du répertoire courant
##   node      version node active ("node -v"), affichée seulement si node dispo et
##             package.json/.nvmrc présent dans le répertoire courant
##   duration  durée de la commande précédente si >=3s
##   exitcode  code de sortie de la commande précédente si non nul
##   docker    contexte docker actif ("docker context show"), masqué si absent/"default" (bruit)
##   battery   charge batterie (Linux /sys/class/power_supply, macOS "pmset -g batt"), masqué si
##             pas de batterie (desktop) ; icône éclair si en charge
## Le repère "[ssh]" du thème minimal reste géré à part (pas un segment) : c'est le seul indice
## ssh de ce thème compact, indépendant du segment "user" (qui affiche le user@host complet).
##
## Les blocs "## chezmoi:theme-begin <nom>" / "## chezmoi:theme-end <nom>" ci-dessous délimitent
## le code propre à chaque thème : ssh.sh (_ssh_build_payload) s'en sert pour n'embarquer sur
## l'hôte distant que le code du thème réellement sélectionné (évite de surcharger la charge utile
## avec le rendu des thèmes non utilisés). Les segments eux, sont tous communs (hors blocs
## thème) puisqu'un segment donné (ex: "node") doit rester utilisable quel que soit le thème actif
## localement ou embarqué en ssh. Ça ne change rien au chargement local, où les quatre thèmes
## restent chargés en même temps pour permettre un changement à chaud (cf. config.sh).
CHEZMOI_PROMPT_THEME="${CHEZMOI_PROMPT_THEME:-default}"
CHEZMOI_PROMPT_SEGMENTS="${CHEZMOI_PROMPT_SEGMENTS:-}"

_PROMPT_PATH_MAXLEN=60

## --- Repère SSH : testé une seule fois au chargement, $SSH_CONNECTION ne change pas pendant la session ---
if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
    _CHEZMOI_IS_SSH=1
else
    _CHEZMOI_IS_SSH=0
fi

## Joint les N derniers éléments du tableau passé en argument avec "/"
_prompt_join_last() {
    local count="$1"; shift
    local -a arr=("$@")
    local total=${#arr[@]}
    local start=$((total - count))
    local out="" i
    for ((i = start; i < total; i++)); do
        out="${out:+$out/}${arr[$i]}"
    done
    printf '%s' "$out"
}

## Tronque un chemin par la gauche sur les séparateurs "/", en gardant au moins les 2 derniers segments
_prompt_truncate_path() {
    local full="$1"
    if [ "${#full}" -le "$_PROMPT_PATH_MAXLEN" ]; then
        printf '%s' "$full"
        return
    fi
    local stripped="${full#\~}"
    stripped="${stripped#/}"
    local -a segs
    IFS='/' read -ra segs <<< "$stripped"
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
    echo " \[\033[38;5;108m\]v$version\[\033[0m\]"
}

## Version node active, seulement si node est dispo et le répertoire courant ressemble à un
## projet node (package.json ou .nvmrc) -- évite le bruit d'un "node -v" hors contexte projet.
_node_segment() {
    command -v node >/dev/null 2>&1 || return
    { [ -f package.json ] || [ -f .nvmrc ]; } || return
    local v
    v=$(node -v 2>/dev/null) || return
    [ -z "$v" ] && return
    echo " \[\033[38;5;70m\]⬡ ${v}\[\033[0m\]"
}

_DOCKER_CACHE_TTL=5
_docker_cache_time=0
_docker_cache_ctx=""

## "docker context show" fait un aller-retour disque/socket -- mis en cache comme le segment git
## (_GIT_CACHE_TTL) pour ne pas payer son coût à chaque rendu de prompt.
_docker_refresh_cache() {
    local now
    now=$(date +%s)
    [ $((now - _docker_cache_time)) -lt "$_DOCKER_CACHE_TTL" ] && return
    _docker_cache_time=$now
    if command -v docker >/dev/null 2>&1; then
        _docker_cache_ctx=$(docker context show 2>/dev/null)
    else
        _docker_cache_ctx=""
    fi
}

## Contexte docker actif, masqué si docker absent ou si le contexte est "default" (bruit -- la
## plupart des sessions locales n'ont jamais changé de contexte).
_docker_segment() {
    _docker_refresh_cache
    if [ -z "$_docker_cache_ctx" ] || [ "$_docker_cache_ctx" = "default" ]; then
        return
    fi
    echo " \[\033[38;5;110m\]🐳 ${_docker_cache_ctx}\[\033[0m\]"
}

## Batterie : Linux (/sys/class/power_supply/BAT*), macOS (pmset -g batt). Rien si pas de
## batterie détectée (desktop). Sur stdout : "<pourcentage>\t<Charging|Discharging|...>".
_battery_read_linux() {
    local bat cap bstatus
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || continue
        cap=$(cat "$bat/capacity" 2>/dev/null)
        bstatus=$(cat "$bat/status" 2>/dev/null)
        [ -n "$cap" ] || continue
        printf '%s\t%s' "$cap" "$bstatus"
        return 0
    done
    return 1
}

_battery_read_macos() {
    command -v pmset >/dev/null 2>&1 || return 1
    local line pct bstatus
    line=$(pmset -g batt 2>/dev/null | grep -m1 '%')
    [ -z "$line" ] && return 1
    pct=$(printf '%s' "$line" | grep -oE '[0-9]+%' | head -n1 | tr -d '%')
    [ -z "$pct" ] && return 1
    bstatus="Discharging"
    printf '%s' "$line" | grep -qi 'charging' && bstatus="Charging"
    printf '%s\t%s' "$pct" "$bstatus"
}

_battery_segment() {
    local raw pct bstatus color icon
    raw="$(_battery_read_linux)" || raw="$(_battery_read_macos)" || return
    [ -z "$raw" ] && return
    pct="${raw%%$'\t'*}"
    bstatus="${raw#*$'\t'}"
    [[ "$pct" =~ ^[0-9]+$ ]] || return
    if [ "$pct" -le 20 ]; then
        color=196
    elif [ "$pct" -le 50 ]; then
        color=179
    else
        color=108
    fi
    icon="🔋"
    [ "$bstatus" = "Charging" ] && icon="⚡"
    echo " \[\033[38;5;${color}m\]${icon}${pct}%\[\033[0m\]"
}

## Code de sortie de la commande précédente, affiché seulement en cas d'échec. $? doit être
## capturé par l'appelant en tout premier (avant toute substitution de commande) et passé en argument.
_exitcode_segment() {
    local ec="$1"
    [ -z "$ec" ] && return
    [ "$ec" -eq 0 ] 2>/dev/null && return
    echo " \[\033[38;5;196m\]✘ ${ec}\[\033[0m\]"
}

_time_segment() {
    echo " \[\033[38;5;244m\][\D{%Y-%m-%dT%H:%M:%S}]\[\033[0m\]"
}

## user@host, préfixé "[ssh]" en session distante (orange), couleur du host_seg elle-même bleue en
## local / orange en ssh.
_user_segment() {
    local host_color=110 ssh_seg=""
    if [ "$_CHEZMOI_IS_SSH" = "1" ]; then
        host_color=208
        ssh_seg="\[\033[38;5;208m\][ssh]\[\033[0m\] "
    fi
    echo " ${ssh_seg}\[\033[38;5;${host_color}m\][\u@\h]\[\033[0m\]"
}

_dir_segment() {
    echo " \[\033[38;5;73m\]$(_prompt_path_segment)\[\033[0m\]"
}

## --- Timer de durée de commande ---
_cmd_timer_start=""
_cmd_timer_trap() {
    [ -z "$_cmd_timer_start" ] && _cmd_timer_start=$SECONDS
}
trap '_cmd_timer_trap' DEBUG

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
    echo " \[\033[38;5;244m\]took ${out}\[\033[0m\]"
}

## Dispatcheur des segments "plats" (thèmes default/minimal) : $2 = style git ("full" ou "compact").
## Nom de segment inconnu -> silence (même fallback que le thème inconnu).
_plain_segment_render() {
    local name="$1" style="$2" ec="$3"
    case "$name" in
        time)     _time_segment ;;
        user)     _user_segment ;;
        dir)      _dir_segment ;;
        git)      if [ "$style" = "compact" ]; then _git_segment_minimal; else _git_segment; fi ;;
        pkg)      _pkg_version_segment ;;
        node)     _node_segment ;;
        duration) _duration_segment ;;
        exitcode) _exitcode_segment "$ec" ;;
        docker)   _docker_segment ;;
        battery)  _battery_segment ;;
    esac
}

## chezmoi:theme-begin floriaaan
_git_segment() {
    _git_refresh_cache
    [ -z "$_git_cache_branch" ] && return
    local dirty="" ab=""
    [ -n "$_git_cache_dirty" ] && dirty=" \[\033[38;5;167m\]●\[\033[0m\]"
    [ -n "$_git_cache_ahead" ] && [ "$_git_cache_ahead" -gt 0 ] 2>/dev/null && ab="${ab} \[\033[38;5;108m\]↑${_git_cache_ahead}\[\033[0m\]"
    [ -n "$_git_cache_behind" ] && [ "$_git_cache_behind" -gt 0 ] 2>/dev/null && ab="${ab} \[\033[38;5;167m\]↓${_git_cache_behind}\[\033[0m\]"
    echo " on \[\033[38;5;179m\]⎇ $_git_cache_branch\[\033[0m\]$dirty$ab"
}

_build_ps1_floriaaan() {
    local ec=$?
    local segs="${CHEZMOI_PROMPT_SEGMENTS:-time user dir git pkg duration}"
    local body="" seg
    for seg in $segs; do
        body="${body}$(_plain_segment_render "$seg" full "$ec")"
    done
    body="${body# }"
    PS1="\n${body}\n\[\033[38;5;108m\]❯\[\033[0m\] "
}
## chezmoi:theme-end floriaaan

## chezmoi:theme-begin minimal
## Version compacte du segment git : juste "(branche●)", pas d'ahead/behind.
_git_segment_minimal() {
    _git_refresh_cache
    [ -z "$_git_cache_branch" ] && return
    local dirty=""
    [ -n "$_git_cache_dirty" ] && dirty="●"
    echo " \[\033[38;5;244m\](${_git_cache_branch}${dirty})\[\033[0m\]"
}

## Une ligne : segments par défaut "dir git" (compact), rien d'autre. "[ssh]" reste géré à part
## (pas un segment) : c'est le seul indice ssh du thème minimal.
_build_ps1_minimal() {
    local ec=$?
    local ssh_seg=""
    [ "$_CHEZMOI_IS_SSH" = "1" ] && ssh_seg="\[\033[38;5;208m\][ssh]\[\033[0m\] "
    local segs="${CHEZMOI_PROMPT_SEGMENTS:-dir git}"
    local body="" seg
    for seg in $segs; do
        body="${body}$(_plain_segment_render "$seg" compact "$ec")"
    done
    body="${body# }"
    PS1="${ssh_seg}${body} \[\033[38;5;108m\]❯\[\033[0m\] "
}
## chezmoi:theme-end minimal

## chezmoi:theme-begin agnoster
## Équivalent du thème oh-my-zsh "agnoster" sans police powerline/nerd font : blocs de couleur
## pleine (contexte/chemin/git/statut), chacun terminé par un ▶ dans sa propre couleur plutôt que
## par la flèche  qui nécessite une police patchée ("effet drapeau" au lieu d'un fondu continu).
_agnoster_segment() {
    local bg="$1" fg="$2" text="$3"
    echo "\[\033[48;5;${bg}m\]\[\033[38;5;${fg}m\] ${text} \[\033[0m\]\[\033[38;5;${bg}m\]▶\[\033[0m\]"
}

## Contexte user@host : masqué en local (bruit inutile, comme le vrai agnoster), affiché en
## orange en session ssh, en rouge si root (prioritaire sur ssh).
_agnoster_context_segment() {
    local is_root=0
    [ "${EUID:-1000}" -eq 0 ] 2>/dev/null && is_root=1
    if [ "$is_root" -eq 1 ]; then
        _agnoster_segment 196 255 "\u@\h"
        return
    fi
    [ "$_CHEZMOI_IS_SSH" = "1" ] || return
    _agnoster_segment 208 0 "\u@\h"
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

_agnoster_time_segment() {
    _agnoster_segment 244 255 "\D{%H:%M:%S}"
}

_agnoster_pkg_segment() {
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
    _agnoster_segment 108 0 "v$version"
}

_agnoster_node_segment() {
    command -v node >/dev/null 2>&1 || return
    { [ -f package.json ] || [ -f .nvmrc ]; } || return
    local v
    v=$(node -v 2>/dev/null) || return
    [ -z "$v" ] && return
    _agnoster_segment 70 255 "⬡ ${v}"
}

_agnoster_duration_segment() {
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
    _agnoster_segment 244 255 "took ${out}"
}

_agnoster_docker_segment() {
    _docker_refresh_cache
    if [ -z "$_docker_cache_ctx" ] || [ "$_docker_cache_ctx" = "default" ]; then
        return
    fi
    _agnoster_segment 110 0 "🐳 ${_docker_cache_ctx}"
}

_agnoster_battery_segment() {
    local raw pct bstatus bg icon
    raw="$(_battery_read_linux)" || raw="$(_battery_read_macos)" || return
    [ -z "$raw" ] && return
    pct="${raw%%$'\t'*}"
    bstatus="${raw#*$'\t'}"
    [[ "$pct" =~ ^[0-9]+$ ]] || return
    if [ "$pct" -le 20 ]; then
        bg=196
    elif [ "$pct" -le 50 ]; then
        bg=179
    else
        bg=108
    fi
    icon="🔋"
    [ "$bstatus" = "Charging" ] && icon="⚡"
    _agnoster_segment "$bg" 255 "${icon}${pct}%"
}

## Dispatcheur des segments "blocs" (thème agnoster). Nom de segment inconnu -> silence.
_agnoster_segment_render() {
    local name="$1" ec="$2"
    case "$name" in
        time)     _agnoster_time_segment ;;
        user)     _agnoster_context_segment ;;
        dir)      _agnoster_dir_segment ;;
        git)      _agnoster_git_segment ;;
        pkg)      _agnoster_pkg_segment ;;
        node)     _agnoster_node_segment ;;
        duration) _agnoster_duration_segment ;;
        exitcode) _agnoster_status_segment "$ec" ;;
        docker)   _agnoster_docker_segment ;;
        battery)  _agnoster_battery_segment ;;
    esac
}

_build_ps1_agnoster() {
    local ec=$?
    local segs="${CHEZMOI_PROMPT_SEGMENTS:-user dir git exitcode}"
    local body="" seg
    for seg in $segs; do
        body="${body}$(_agnoster_segment_render "$seg" "$ec")"
    done
    PS1="${body} "
}
## chezmoi:theme-end agnoster

## chezmoi:theme-begin default
## Reproduit tel quel le PS1 par défaut de bash (celui du squelette Debian /etc/skel/.bashrc, le
## plus répandu) : mêmes échappements (\u \h \w \$), mêmes couleurs ANSI brutes (01;32 vert vif,
## 01;34 bleu vif -- pas la palette 256 adoucie du reste du fichier), même prise en charge de
## $debian_chroot. Pas de dispatch par segment ici : le vrai bash n'en a pas, donc prompt.segments
## ne s'applique pas à ce thème (contrairement aux trois autres).
_build_ps1_default() {
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
}
## chezmoi:theme-end default

_build_ps1() {
    case "$CHEZMOI_PROMPT_THEME" in
        minimal)   _build_ps1_minimal ;;
        agnoster)  _build_ps1_agnoster ;;
        floriaaan) _build_ps1_floriaaan ;;
        *)         _build_ps1_default ;;
    esac
}

## Idempotent : évite doublons/`;;` si chezmoi.sh est re-sourcé (ex: `chezmoi update`).
case ";${PROMPT_COMMAND};" in
    *";_build_ps1;"*) ;;
    *) PROMPT_COMMAND="_build_ps1${PROMPT_COMMAND:+;}${PROMPT_COMMAND}" ;;
esac
