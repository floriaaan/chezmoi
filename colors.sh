## --- Couleurs façon oh-my-zsh (zero-install, bash + zsh) ---

## LS_COLORS / GREP_COLORS : toujours écrasés pour un look cohérent
export LS_COLORS="di=38;5;110:ln=38;5;179:ex=38;5;108:*.md=38;5;244"
export GREP_COLORS="mt=38;5;179:fn=38;5;110:ln=38;5;244"

## --- ls / grep / diff colorés, avec détection GNU vs BSD ---
if ls --color=auto . >/dev/null 2>&1; then
    alias ls='ls --color=auto'
else
    alias ls='ls -G'
fi
alias ll='ls -lh'
alias la='ls -lAh'

if grep --color=auto . <<<"" >/dev/null 2>&1; then
    alias grep='grep --color=auto'
fi

if diff --color=auto <(:) <(:) >/dev/null 2>&1; then
    alias diff='diff --color=auto'
fi

## --- Auto-source zsh-syntax-highlighting / zsh-autosuggestions si déjà présents sur la machine ---
## Aucune install forcée : simple détection de chemins courants. Désactivable via CHEZMOI_NO_ZSH_PLUGINS=1.
## Doit être sourcé en dernier (après complétions/widgets) — voir appel en fin de chezmoi.sh.
_chezmoi_load_zsh_syntax_plugins() {
    emulate -L zsh 2>/dev/null
    [ -n "$CHEZMOI_NO_ZSH_PLUGINS" ] && return

    local -a highlight_paths=(
        "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
        "${ZSH:-$HOME/.oh-my-zsh}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"
    )
    local -a autosuggest_paths=(
        "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
        "${ZSH:-$HOME/.oh-my-zsh}/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
    )

    local p
    for p in "${autosuggest_paths[@]}"; do
        [ -f "$p" ] && source "$p" && break
    done
    for p in "${highlight_paths[@]}"; do
        [ -f "$p" ] && source "$p" && break
    done
}
