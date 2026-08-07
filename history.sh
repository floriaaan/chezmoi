## --- Historique partagé + dédupliqué + timestamps ---
## Module de pure config : aucune fonction exposée. Sourcé en premier par chezmoi.sh
## car certaines options d'historique doivent être posées avant tout le reste.

if [ -n "$ZSH_VERSION" ]; then
    setopt EXTENDED_GLOB

    HISTSIZE=50000
    SAVEHIST=50000
    HISTFILE="${HISTFILE:-$HOME/.zsh_history}"

    setopt SHARE_HISTORY        # historique partagé en temps réel entre sessions
    setopt HIST_IGNORE_ALL_DUPS # supprime les anciens doublons quand une commande est ré-exécutée
    setopt HIST_IGNORE_SPACE    # ignore les commandes préfixées d'un espace
    setopt HIST_REDUCE_BLANKS   # nettoie les espaces superflus avant enregistrement
    setopt EXTENDED_HISTORY     # timestamps dans le fichier d'historique
    setopt INC_APPEND_HISTORY   # écriture immédiate après chaque commande
    setopt HIST_VERIFY          # relit une expansion d'historique avant exécution

    HISTORY_IGNORE="(ls|cd|pwd|exit|clear|history)"

    if [[ -o interactive ]]; then
        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        # les deux variantes de séquence (\e[A vs \eOA) selon mode application du terminal
        bindkey "^[[A" up-line-or-beginning-search
        bindkey "^[OA" up-line-or-beginning-search
        bindkey "^[[B" down-line-or-beginning-search
        bindkey "^[OB" down-line-or-beginning-search
    fi
else
    HISTSIZE=50000
    HISTFILESIZE=50000
    HISTTIMEFORMAT="%F %T "
    HISTCONTROL="ignoreboth:erasedups"   # ignoreboth = ignorespace + ignoredups
    HISTIGNORE="ls:cd:pwd:exit:clear:history"
    shopt -s histappend
    shopt -s cmdhist

    ## Synchro inter-terminaux : append immédiat, purge du buffer en mémoire, relecture du fichier.
    ## S'ajoute à PROMPT_COMMAND sans l'écraser (z.sh/prompt.sh y ajoutent aussi leurs propres hooks).
    _chezmoi_history_sync() {
        history -a
        history -c
        history -r
    }
    case ";${PROMPT_COMMAND};" in
        *";_chezmoi_history_sync;"*) ;;
        *) PROMPT_COMMAND="${PROMPT_COMMAND}${PROMPT_COMMAND:+;}_chezmoi_history_sync" ;;
    esac

    if [[ $- == *i* ]]; then
        bind '"\e[A": history-search-backward'
        bind '"\eOA": history-search-backward'
        bind '"\e[B": history-search-forward'
        bind '"\eOB": history-search-forward'
    fi
fi
