## --- Autocomplétion pour les commandes maison (gtag, chezmoi) + hookup git + go-task ---
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
            COMPREPLY=($(compgen -W "get set unset edit list help" -- "$cur"))
            return
        fi
        if [ "$COMP_CWORD" -eq 3 ] && { [ "$prev" = "get" ] || [ "$prev" = "set" ] || [ "$prev" = "unset" ]; }; then
            COMPREPLY=($(compgen -W "prompt.theme prompt.segments ssh.modules modules.disabled" -- "$cur"))
            return
        fi
        ## Valeurs possibles pour "chezmoi config set prompt.theme <TAB>" (réutilise le registre de
        ## config.sh s'il est chargé, sinon liste de secours).
        if [ "$COMP_CWORD" -eq 4 ] && [ "${COMP_WORDS[2]}" = "set" ] && [ "${COMP_WORDS[3]}" = "prompt.theme" ]; then
            local choices
            if declare -f _chezmoi_config_choices >/dev/null 2>&1; then
                choices="$(_chezmoi_config_choices prompt.theme)"
            else
                choices="default minimal agnoster"
            fi
            COMPREPLY=($(compgen -W "$choices" -- "$cur"))
            return
        fi
        return
    fi

    if [ "${COMP_WORDS[1]}" = "modules" ]; then
        if [ "$COMP_CWORD" -eq 2 ]; then
            COMPREPLY=($(compgen -W "list disable enable help" -- "$cur"))
            return
        fi
        if [ "$COMP_CWORD" -eq 3 ] && { [ "$prev" = "disable" ] || [ "$prev" = "enable" ]; }; then
            local mods
            mods="${_CHEZMOI_MODULES_LIST:-config history z git-aliases gtag ports extract ssh docker net completion colors}"
            COMPREPLY=($(compgen -W "$mods" -- "$cur"))
            return
        fi
        return
    fi

    if [ "${COMP_WORDS[1]}" = "themes" ]; then
        if [ "$COMP_CWORD" -eq 2 ]; then
            local choices
            if declare -f _chezmoi_config_choices >/dev/null 2>&1; then
                choices="$(_chezmoi_config_choices prompt.theme)"
            else
                choices="default minimal agnoster floriaaan"
            fi
            COMPREPLY=($(compgen -W "$choices list unset help" -- "$cur"))
            return
        fi
        return
    fi

    if [ "${COMP_WORDS[1]}" = "prompt" ]; then
        if [ "$COMP_CWORD" -ge 2 ]; then
            local segs
            segs="${_CHEZMOI_PROMPT_SEGMENT_NAMES:-time user dir git pkg node duration exitcode docker battery}"
            COMPREPLY=($(compgen -W "$segs list unset help" -- "$cur"))
            return
        fi
        return
    fi

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "update reload version doctor config modules themes prompt bench help" -- "$cur"))
        return
    fi
}
complete -F _chezmoi_complete chezmoi

## --- Complétion go-task (si présent sur la machine, aucune install forcée) ---
## `task --completion <shell>` génère le script de complétion officiel du binaire détecté,
## rien n'est écrit sur disque. Silencieux si absent ou si la sous-commande n'existe pas
## (anciennes versions de go-task).
_completion_hookup_task() {
    emulate -L bash 2>/dev/null
    command -v task >/dev/null 2>&1 || return 0
    if [ -n "$ZSH_VERSION" ]; then
        eval "$(task --completion zsh 2>/dev/null)" 2>/dev/null
    else
        eval "$(task --completion bash 2>/dev/null)" 2>/dev/null
    fi
}

## --- Complétion docker (si présent sur la machine, aucune install forcée) ---
## `docker completion <shell>` (Docker CLI >= 20.10) génère le script de complétion officiel,
## même principe que go-task ci-dessus.
_completion_hookup_docker() {
    emulate -L bash 2>/dev/null
    command -v docker >/dev/null 2>&1 || return 0
    if [ -n "$ZSH_VERSION" ]; then
        eval "$(docker completion zsh 2>/dev/null)" 2>/dev/null
    else
        eval "$(docker completion bash 2>/dev/null)" 2>/dev/null
    fi
}

## --- Hookup complétion git native sur les alias de git-aliases.sh (si déjà présente sur la
## machine, aucune install forcée) : chaque alias récupère la complétion de la sous-commande git
## qu'il enveloppe (ex: `gco sta<TAB>` -> `gco staging`, comme `git checkout sta<TAB>`) ---
## Chemins connus de git-completion.bash : sur beaucoup de machines (bash-completion v2),
## __git_complete/_git_xxx ne sont définis qu'au premier "git <TAB>" tapé dans la session
## (chargement dynamique paresseux) — donc absents ici si ce module est sourcé au démarrage
## du shell, avant tout TAB. On source directement le script source si trouvé, pour ne pas en
## dépendre. Fonctionne aussi sous zsh (bashcompinit est chargé par le barrel avant ce module).
_COMPLETION_GIT_COMPLETION_PATHS=(
    /usr/share/bash-completion/completions/git
    /etc/bash_completion.d/git
    /usr/share/git/completion/git-completion.bash
    /usr/share/git-core/contrib/completion/git-completion.bash
    /usr/local/etc/bash_completion.d/git-completion.bash
    /opt/homebrew/etc/bash_completion.d/git-completion.bash
    "$HOME/.git-completion.bash"
)
_completion_source_git_completion_bash() {
    emulate -L bash 2>/dev/null
    declare -f __git_complete >/dev/null 2>&1 && return 0
    local p
    for p in "${_COMPLETION_GIT_COMPLETION_PATHS[@]}"; do
        [ -f "$p" ] && source "$p" 2>/dev/null && break
    done
}

_completion_hookup_git_aliases() {
    emulate -L bash 2>/dev/null
    _completion_source_git_completion_bash
    declare -f __git_complete >/dev/null 2>&1 || return 0
    __git_complete ga   _git_add
    __git_complete gaa  _git_add
    __git_complete gc   _git_commit
    __git_complete gca  _git_commit
    __git_complete gp   _git_push
    __git_complete gpf  _git_push
    __git_complete gl   _git_pull
    __git_complete gco  _git_checkout
    __git_complete gcb  _git_checkout
    __git_complete gb   _git_branch
    __git_complete gd   _git_diff
    __git_complete gds  _git_diff
    __git_complete glog _git_log
    __git_complete gs   _git_stash
    __git_complete gsp  _git_stash
    __git_complete grh  _git_reset
    __git_complete gcp  _git_cherry_pick
    __git_complete gm   _git_merge
    __git_complete grb  _git_rebase
}

## --- Chargement paresseux des trois hookups ci-dessus ---
## _completion_hookup_task/_completion_hookup_docker (fork+exec du binaire) et
## _completion_hookup_git_aliases (potentiel "source" de git-completion.bash, plusieurs centaines
## de lignes) coûtent chacun quelques ms à quelques dizaines de ms selon la machine -- payés à
## chaque démarrage de shell alors qu'ils ne servent qu'au premier <TAB> réel sur la commande
## concernée (souvent jamais dans une session courte). Un stub léger est enregistré à la place :
## au premier <TAB>, il charge le vrai hookup (qui s'auto-enregistre via `complete -F <fn> <cmd>`,
## écrasant le stub) puis redispatche vers la vraie fonction pour que ce premier <TAB> affiche déjà
## les bonnes propositions (pas besoin d'appuyer deux fois). Si le hookup réel ne s'enregistre pas
## (ex: git-completion.bash introuvable sur la machine), `complete -p` renvoie encore le stub
## lui-même : détecté et ignoré pour éviter une récursion infinie.
## Désactivable via CHEZMOI_NO_LAZY_COMPLETION=1 (comportement eager d'avant : tout chargé au
## démarrage, utile pour un shell non-interactif/déboguage où il n'y aura jamais de <TAB>).
_completion_lazy_dispatch() {
    emulate -L bash 2>/dev/null
    local cmd="$1" loader="$2"
    "$loader"
    ## "complete -p <cmd>" sous zsh/bashcompinit ignore parfois le filtre par commande et renvoie
    ## TOUTES les registrations (constaté avec bashcompinit) : on filtre nous-mêmes sur la ligne
    ## dont le dernier mot est bien <cmd>, plutôt que de faire confiance au filtrage de "complete -p".
    local real_fn
    real_fn=$(complete -p "$cmd" 2>/dev/null | awk -v c="$cmd" '$NF==c { for (i=1;i<NF;i++) if ($i=="-F") print $(i+1) }' | tail -n1)
    case "$real_fn" in
        ""|_completion_lazy_task|_completion_lazy_docker|_completion_lazy_git_alias) return 0 ;;
    esac
    declare -f "$real_fn" >/dev/null 2>&1 || return 0
    "$real_fn" "${COMP_WORDS[0]}" "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD-1]}"
}
_completion_lazy_task()       { _completion_lazy_dispatch task   _completion_hookup_task; }
_completion_lazy_docker()     { _completion_lazy_dispatch docker _completion_hookup_docker; }
_completion_lazy_git_alias()  { _completion_lazy_dispatch "${COMP_WORDS[0]}" _completion_hookup_git_aliases; }

_completion_install_hookups() {
    emulate -L bash 2>/dev/null
    if [ -n "$CHEZMOI_NO_LAZY_COMPLETION" ]; then
        _completion_hookup_task
        _completion_hookup_docker
        _completion_hookup_git_aliases
        return
    fi
    command -v task >/dev/null 2>&1 && complete -F _completion_lazy_task task
    command -v docker >/dev/null 2>&1 && complete -F _completion_lazy_docker docker
    local aliases a
    aliases=""
    if [ -n "$CHEZMOI_DIR" ] && [ -f "$CHEZMOI_DIR/git-aliases.sh" ]; then
        aliases=$(grep -oE '^alias [a-zA-Z]+=' "$CHEZMOI_DIR/git-aliases.sh" | sed -E 's/^alias ([a-zA-Z]+)=/\1/')
    fi
    for a in $aliases; do
        complete -F _completion_lazy_git_alias "$a" 2>/dev/null
    done
}
_completion_install_hookups
