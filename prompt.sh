## --- Prompt façon powerlevel10k (couleurs douces, sans nerd font) ---

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

_git_segment() {
    _git_refresh_cache
    [ -z "$_git_cache_branch" ] && return
    local dirty="" ab=""
    [ -n "$_git_cache_dirty" ] && dirty=" \[\033[38;5;167m\]●\[\033[0m\]"
    [ -n "$_git_cache_ahead" ] && [ "$_git_cache_ahead" -gt 0 ] 2>/dev/null && ab="${ab} \[\033[38;5;108m\]↑${_git_cache_ahead}\[\033[0m\]"
    [ -n "$_git_cache_behind" ] && [ "$_git_cache_behind" -gt 0 ] 2>/dev/null && ab="${ab} \[\033[38;5;167m\]↓${_git_cache_behind}\[\033[0m\]"
    echo " on \[\033[38;5;179m\]⎇ $_git_cache_branch\[\033[0m\]$dirty$ab"
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

_build_ps1() {
    local time_seg="\[\033[38;5;244m\][\D{%Y-%m-%dT%H:%M:%S}]\[\033[0m\]"
    local host_seg="\[\033[38;5;110m\][\u@\h]\[\033[0m\]"
    local dir_seg="\[\033[38;5;73m\]\w\[\033[0m\]"
    PS1="\n${time_seg} ${host_seg} ${dir_seg}$(_git_segment)$(_pkg_version_segment)$(_duration_segment)\n\[\033[38;5;108m\]❯\[\033[0m\] "
}

PROMPT_COMMAND="_build_ps1;${PROMPT_COMMAND}"