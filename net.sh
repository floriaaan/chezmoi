## --- net: petites commandes réseau (IP publique/locale, météo) via curl ---
## Timeout court partout (--max-time) : ne doit jamais bloquer un shell interactif si le
## réseau/service distant est indisponible.

_NET_OK='\033[38;5;108m'
_NET_ERR='\033[38;5;196m'
_NET_INFO='\033[38;5;110m'
_NET_RESET='\033[0m'

## Plusieurs fournisseurs en repli (le premier qui répond gagne) : un seul point de défaillance
## externe serait fragile pour une commande censée juste répondre vite.
_NET_MYIP_PROVIDERS="https://icanhazip.com https://ifconfig.me https://api.ipify.org"

myip() {
    emulate -L bash 2>/dev/null
    command -v curl >/dev/null 2>&1 || { printf "%b\n" "${_NET_ERR}myip: curl indisponible${_NET_RESET}" >&2; return 1; }
    local url ip
    for url in $_NET_MYIP_PROVIDERS; do
        ip=$(curl -fsSL --max-time 3 "$url" 2>/dev/null | tr -d '[:space:]')
        [ -n "$ip" ] && { printf "%s\n" "$ip"; return 0; }
    done
    printf "%b\n" "${_NET_ERR}myip: aucun fournisseur n'a répondu${_NET_RESET}" >&2
    return 1
}

## IP locale (celle utilisée pour sortir vers l'extérieur, pas 127.0.0.1) : "ip route" (Linux) en
## premier, repli sur "ifconfig"/"ipconfig" pour rester utilisable sur macOS/BSD/WSL/Windows-natif.
localip() {
    emulate -L bash 2>/dev/null
    local ip
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}')
    fi
    if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null | grep -oE 'inet (addr:)?[0-9.]+' | grep -v '127.0.0.1' | awk '{print $NF}' | sed 's/addr://' | head -n1)
    fi
    if [ -z "$ip" ] && command -v ipconfig >/dev/null 2>&1; then
        ip=$(ipconfig 2>/dev/null | grep -A1 'IPv4' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    fi
    if [ -z "$ip" ]; then
        printf "%b\n" "${_NET_ERR}localip: aucune IP locale trouvée (ip/ifconfig/ipconfig absents ou sans résultat)${_NET_RESET}" >&2
        return 1
    fi
    printf "%s\n" "$ip"
}

## wttr.in : "?format=3" = une ligne compacte ("Paris: ☀️ +22°C"). Sans argument, wttr.in
## géolocalise par IP source côté serveur.
weather() {
    emulate -L bash 2>/dev/null
    command -v curl >/dev/null 2>&1 || { printf "%b\n" "${_NET_ERR}weather: curl indisponible${_NET_RESET}" >&2; return 1; }
    local location="$1" out
    out=$(curl -fsSL --max-time 5 "https://wttr.in/${location}?format=3" 2>/dev/null)
    if [ -z "$out" ]; then
        printf "%b\n" "${_NET_ERR}weather: service indisponible (wttr.in)${_NET_RESET}" >&2
        return 1
    fi
    printf "%s\n" "$out"
}
