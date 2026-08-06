## --- Prompt façon powerlevel10k (couleurs douces, sans nerd font) [zsh] ---
setopt PROMPT_SUBST

_git_segment() {
    local branch dirty=""
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    [ -z "$branch" ] && return
    if ! git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
        dirty=" %{$'\e[38;5;167m'%}●%{$'\e[0m'%}"
    fi
    echo " on %{$'\e[38;5;179m'%}⎇ $branch%{$'\e[0m'%}$dirty"
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
    echo " %{$'\e[38;5;108m'%}v$version%{$'\e[0m'%}"
}

precmd() {
    local time_seg="%{$'\e[38;5;244m'%}[%D{%Y-%m-%dT%H:%M:%S}]%{$'\e[0m'%}"
    local host_seg="%{$'\e[38;5;110m'%}[%n@%m]%{$'\e[0m'%}"
    local dir_seg="%{$'\e[38;5;73m'%}%~%{$'\e[0m'%}"
    PROMPT="
${time_seg} ${host_seg} ${dir_seg}$(_git_segment)$(_pkg_version_segment)
%{$'\e[38;5;108m'%}❯%{$'\e[0m'%} "
}