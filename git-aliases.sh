## --- Alias git ---
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -S -m'                                # gc "message"
alias gca='git commit --amend'
alias gp='git push'
alias gpf='git push --force-with-lease'                 # force push safe (n'écrase pas si origin a bougé)
alias gl='git pull'
alias gco='git checkout'
alias gcb='git checkout -b'                              # gcb nom-branche
alias gb='git branch'
alias gd='git diff'
alias gds='git diff --staged'
alias glog='git log --oneline --graph --decorate -20'   # historique compact des 20 derniers commits
alias gs='git stash'
alias gsp='git stash pop'
alias grh='git reset --hard'
alias gcp='git cherry-pick'
