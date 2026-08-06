## --- Prompt façon powerlevel10k (couleurs douces, sans nerd font) ---

_git_segment() {
    local branch dirty=""
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    [ -z "$branch" ] && return
    if ! git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
        dirty=" \[\033[38;5;167m\]●\[\033[0m\]"
    fi
    echo " on \[\033[38;5;179m\]⎇ $branch\[\033[0m\]$dirty"
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

_build_ps1() {
    local time_seg="\[\033[38;5;244m\][\D{%Y-%m-%dT%H:%M:%S}]\[\033[0m\]"
    local host_seg="\[\033[38;5;110m\][\u@\h]\[\033[0m\]"
    local dir_seg="\[\033[38;5;73m\]\w\[\033[0m\]"
    PS1="\n${time_seg} ${host_seg} ${dir_seg}$(_git_segment)$(_pkg_version_segment)\n\[\033[38;5;108m\]❯\[\033[0m\] "
}

PROMPT_COMMAND="_build_ps1;${PROMPT_COMMAND}"
