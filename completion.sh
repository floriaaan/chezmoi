## --- Autocomplétion pour les commandes maison (gtag, chezmoi) + hookup git ---
## Suppose "complete" dispo (bashcompinit déjà chargé sous zsh par le barrel, cf. chezmoi.sh)

_gtag_complete() {
    emulate -L bash 2>/dev/null
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [ "$prev" = "list" ]; then
        COMPREPLY=($(compgen -W "prod rc dev" -- "$cur"))
        return
    fi

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "major minor patch list --force --prefix= --rc --dev --dry-run" -- "$cur"))
        return
    fi

    COMPREPLY=($(compgen -W "--force --prefix= --rc --dev --dry-run" -- "$cur"))
}
complete -F _gtag_complete gtag

_chezmoi_complete() {
    emulate -L bash 2>/dev/null
    local cur prev
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [ "${COMP_WORDS[1]}" = "config" ]; then
        if [ "$COMP_CWORD" -eq 2 ]; then
            COMPREPLY=($(compgen -W "get set unset list help" -- "$cur"))
            return
        fi
        if [ "$COMP_CWORD" -eq 3 ] && { [ "$prev" = "get" ] || [ "$prev" = "set" ] || [ "$prev" = "unset" ]; }; then
            COMPREPLY=($(compgen -W "prompt.theme ssh.modules" -- "$cur"))
            return
        fi
        return
    fi

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "update version doctor config help" -- "$cur"))
        return
    fi
}
complete -F _chezmoi_complete chezmoi

## --- Hookup complétion git native sur les alias (si déjà présente sur la machine, aucune install forcée) ---
if declare -f __git_complete >/dev/null 2>&1; then
    __git_complete gco _git_checkout
    __git_complete gcb _git_checkout
    __git_complete gb _git_branch
    __git_complete gm _git_merge
    __git_complete grb _git_rebase
fi
