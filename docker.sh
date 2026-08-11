## --- Alias docker (+ docker compose) : pas d'install forcée, ce sont de simples raccourcis
## de commande -- inertes si le binaire docker n'est pas présent sur la machine (comme
## git-aliases.sh vis-à-vis de git) ---
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker images'
alias dex='docker exec -it'                              # dex <container> bash
alias dlog='docker logs -f'
alias dstop='docker stop'
alias drm='docker rm'
alias drmi='docker rmi'
alias dprune='docker system prune -f'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcb='docker compose build'
alias dcl='docker compose logs -f'
alias dcps='docker compose ps'
