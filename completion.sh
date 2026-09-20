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
        ## Valeurs possibles pour "chezmoi config set <clé> <TAB>" (réutilise les registres de
        ## config.sh/chezmoi.sh s'ils sont chargés, sinon listes de secours). "-ge 4" et pas
        ## "-eq 4" : prompt.segments, ssh.modules et modules.disabled prennent plusieurs valeurs.
        if [ "$COMP_CWORD" -ge 4 ] && [ "${COMP_WORDS[2]}" = "set" ]; then
            local choices=""
            case "${COMP_WORDS[3]}" in
                prompt.theme)
                    if declare -f _chezmoi_config_choices >/dev/null 2>&1; then
                        choices="$(_chezmoi_config_choices prompt.theme)"
                    else
                        choices="default minimal agnoster floriaaan"
                    fi
                    ;;
                prompt.segments)
                    choices="${_CHEZMOI_PROMPT_SEGMENT_NAMES:-time user dir git pkg node duration exitcode docker battery}"
                    ;;
                ssh.modules|modules.disabled)
                    choices="${_CHEZMOI_MODULES_LIST:-config history z git-aliases gtag ports extract ssh docker net completion colors}"
                    ;;
            esac
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

## --- Dépendance bash-completion des scripts générés (go-task, docker...) ---
## Les scripts que ces binaires génèrent pour bash s'appuient sur `_init_completion`, fourni par le
## paquet bash-completion. Absent (cas par défaut sur macOS), la complétion enregistrée échoue à
## chaque <TAB> avec "bash: _init_completion : commande introuvable" au lieu de compléter. On
## source bash-completion à la demande (chemins connus) ; introuvable -> on renonce au hookup et le
## stub se retire (cf. _completion_lazy_dispatch) : la complétion par défaut vaut mieux qu'une
## complétion qui hurle. Les scripts qui n'utilisent pas `_init_completion` passent sans rien payer.
_COMPLETION_BASH_COMPLETION_PATHS=(
    /usr/share/bash-completion/bash_completion
    /etc/bash_completion
    /etc/profile.d/bash_completion.sh
    /usr/local/etc/profile.d/bash_completion.sh
    /opt/homebrew/etc/profile.d/bash_completion.sh
    "$HOME/.bash_completion"
)
_completion_bash_completion_satisfied() {
    emulate -L bash 2>/dev/null
    case "$1" in
        *_init_completion*) ;;
        *) return 0 ;;
    esac
    declare -f _init_completion >/dev/null 2>&1 && return 0
    local p
    for p in "${_COMPLETION_BASH_COMPLETION_PATHS[@]}"; do
        [ -f "$p" ] || continue
        source "$p" 2>/dev/null
        declare -f _init_completion >/dev/null 2>&1 && return 0
    done
    return 1
}

## --- Complétion go-task (si présent sur la machine, aucune install forcée) ---
## `task --completion <shell>` génère le script de complétion officiel du binaire détecté,
## rien n'est écrit sur disque. Silencieux si absent ou si la sous-commande n'existe pas
## (anciennes versions de go-task).
_completion_hookup_task() {
    emulate -L bash 2>/dev/null
    command -v task >/dev/null 2>&1 || return 0
    if [ -n "$ZSH_VERSION" ]; then
        eval "$(task --completion zsh 2>/dev/null)" 2>/dev/null
        return
    fi
    local script
    script=$(task --completion bash 2>/dev/null)
    [ -n "$script" ] || return 0
    _completion_bash_completion_satisfied "$script" || return 0
    eval "$script" 2>/dev/null
}

## --- Complétion docker (si présent sur la machine, aucune install forcée) ---
## `docker completion <shell>` (Docker CLI >= 20.10) génère le script de complétion officiel,
## même principe que go-task ci-dessus.
_completion_hookup_docker() {
    emulate -L bash 2>/dev/null
    command -v docker >/dev/null 2>&1 || return 0
    if [ -n "$ZSH_VERSION" ]; then
        eval "$(docker completion zsh 2>/dev/null)" 2>/dev/null
        return
    fi
    local script
    script=$(docker completion bash 2>/dev/null)
    [ -n "$script" ] || return 0
    _completion_bash_completion_satisfied "$script" || return 0
    eval "$script" 2>/dev/null
}

## --- Hookup complétion git sur les alias de git-aliases.sh ---
## Chaque alias récupère la complétion de la sous-commande git qu'il enveloppe
## (ex: `gco sta<TAB>` -> `gco staging`, comme `git checkout sta<TAB>`).
## La table alias -> sous-commande est dérivée de git-aliases.sh (source unique de vérité : un
## alias ajouté là-bas est hooké sans toucher ce fichier, et aucun alias fantôme ne subsiste ici).
_COMPLETION_DIR="${CHEZMOI_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}"
_completion_git_alias_pairs() {
    [ -f "$_COMPLETION_DIR/git-aliases.sh" ] || return 0
    sed -nE "s/^alias ([a-zA-Z]+)='git ([a-z-]+).*/\1 \2/p" "$_COMPLETION_DIR/git-aliases.sh"
}

## zsh : compsys fournit déjà une complétion git complète et paresseuse -- "compdef _git
## gco=git-checkout" la réutilise telle quelle. Aucune dépendance à git-completion.bash (absent
## par défaut sur macOS, où l'ancien hookup laissait un stub bash qui bloquait toute complétion
## sur les alias) ni à bashcompinit. Coût nul au démarrage : _git reste autoload.
_completion_hookup_git_aliases_zsh() {
    local a sub
    while read -r a sub; do
        [ -n "$a" ] || continue
        compdef _git "$a=git-$sub" 2>/dev/null
    done <<EOF
$(_completion_git_alias_pairs)
EOF
}

## bash : __git_complete vient de git-completion.bash. Sur beaucoup de machines (bash-completion
## v2), __git_complete/_git_xxx ne sont définis qu'au premier "git <TAB>" tapé dans la session
## (chargement dynamique paresseux) -- donc absents si ce module est sourcé au démarrage du shell,
## avant tout TAB. On source directement le script source si trouvé, pour ne pas en dépendre.
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

## Vrai ? -> ça vaut le coup d'enregistrer les stubs paresseux. Faux -> on ne touche à rien, les
## alias gardent la complétion par défaut du shell (fichiers) au lieu d'un stub qui ne propose rien.
_completion_git_completion_bash_available() {
    declare -f __git_complete >/dev/null 2>&1 && return 0
    local p
    for p in "${_COMPLETION_GIT_COMPLETION_PATHS[@]}"; do
        [ -f "$p" ] && return 0
    done
    return 1
}

_completion_hookup_git_aliases() {
    emulate -L bash 2>/dev/null
    _completion_source_git_completion_bash
    declare -f __git_complete >/dev/null 2>&1 || return 0
    local a sub
    while read -r a sub; do
        [ -n "$a" ] || continue
        __git_complete "$a" "_git_${sub//-/_}"
    done <<EOF
$(_completion_git_alias_pairs)
EOF
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
    ## Stub toujours en place = le hookup réel n'a rien enregistré (binaire/script introuvable) :
    ## on retire le stub, sinon il resterait à bloquer toute complétion sur cette commande (pas
    ## même la complétion de fichiers par défaut) pour le reste de la session.
    case "$real_fn" in
        ""|_completion_lazy_task|_completion_lazy_docker|_completion_lazy_git_alias)
            complete -r "$cmd" 2>/dev/null
            ## 124 = code convenu par bash pour "réessaie la complétion, la spec a changé" : le
            ## <TAB> en cours rend déjà la complétion par défaut (fichiers) au lieu de ne rien
            ## faire. Inconnu de bashcompinit sous zsh, où on se contente de ne rien proposer.
            [ -z "$ZSH_VERSION" ] && return 124
            return 0
            ;;
    esac
    declare -f "$real_fn" >/dev/null 2>&1 || return 0
    "$real_fn" "${COMP_WORDS[0]}" "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD-1]}"
}
_completion_lazy_task()       { _completion_lazy_dispatch task   _completion_hookup_task; }
_completion_lazy_docker()     { _completion_lazy_dispatch docker _completion_hookup_docker; }
_completion_lazy_git_alias()  { _completion_lazy_dispatch "${COMP_WORDS[0]}" _completion_hookup_git_aliases; }

## Une complétion compsys native existe-t-elle déjà pour cette commande ? (zsh uniquement)
_completion_has_native_zsh_completion() {
    [ -n "$ZSH_VERSION" ] || return 1
    [ -n "${_comps[$1]}" ] 2>/dev/null
}

_completion_install_hookups() {
    emulate -L bash 2>/dev/null
    if [ -n "$CHEZMOI_NO_LAZY_COMPLETION" ]; then
        _completion_hookup_task
        _completion_hookup_docker
        _completion_hookup_git_aliases
        return
    fi
    ## zsh : ne jamais écraser une complétion compsys native déjà en place (_docker de Homebrew,
    ## _git...) par un stub bash -- la native est meilleure et déjà paresseuse.
    command -v task >/dev/null 2>&1 && ! _completion_has_native_zsh_completion task \
        && complete -F _completion_lazy_task task
    command -v docker >/dev/null 2>&1 && ! _completion_has_native_zsh_completion docker \
        && complete -F _completion_lazy_docker docker
    if [ -n "$ZSH_VERSION" ]; then
        _completion_hookup_git_aliases_zsh
        return
    fi
    _completion_git_completion_bash_available || return 0
    local a sub
    while read -r a sub; do
        [ -n "$a" ] || continue
        complete -F _completion_lazy_git_alias "$a" 2>/dev/null
    done <<EOF
$(_completion_git_alias_pairs)
EOF
}
_completion_install_hookups
