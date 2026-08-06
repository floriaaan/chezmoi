## --- Prompt façon powerlevel10k (couleurs douces, sans nerd font) [zsh] ---
setopt PROMPT_SUBST

_git_segment() {
    local branch dirty=""
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    [ -z "$branch" ] && return
    if ! git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
        dirty=" %F{167}●%f"
    fi
    echo " on %F{179}⎇ $branch%f$dirty"
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

precmd() {
    local time_seg="%F{244}[%D{%Y-%m-%dT%H:%M:%S}]%f"
    local host_seg="%F{110}[%n@%m]%f"
    local dir_seg="%F{73}%~%f"
    PROMPT="
${time_seg} ${host_seg} ${dir_seg}$(_git_segment)$(_pkg_version_segment)
%F{108}❯%f "
}