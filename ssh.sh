## --- ssh: wrapper qui embarque un sous-ensemble de la config chezmoi sur l'hôte distant ---
## Aucune écriture persistante côté distant : la config (base64) est passée en argument
## littéral de la commande distante exécutée par ssh, décodée et évaluée en mémoire par le
## shell distant. Rien n'est jamais écrit sur son disque.
##
## Pourquoi un argument de commande et pas une variable d'env (`-o SetEnv`) : SetEnv/SendEnv
## sont soumis à `AcceptEnv` côté sshd, presque toujours verrouillé pour les variables
## non-standard sur les hôtes durcis/d'entreprise — l'injection échouerait alors
## systématiquement. L'argument de commande, lui, n'est soumis à aucune telle restriction
## (ce n'est que du texte que le shell distant parse). L'alphabet base64 (A-Za-z0-9+/=) ne
## contient aucun caractère spécial de shell ni de guillemet simple, donc l'embarquer entre
## guillemets simples est sûr quel que soit son contenu.

_SSH_CHEZMOI_ENABLED=1
_SSH_CHEZMOI_MODULES="prompt git-aliases gtag"
_SSH_CHEZMOI_MAXSIZE=32768
_SSH_CHEZMOI_SHELL="bash"
_SSH_CHEZMOI_CACHE_FILE="$HOME/.cache/chezmoi_ssh_hosts"
_SSH_CHEZMOI_CACHE_TTL=86400   # 1 jour ; 0 désactive le cache

_SSH_OK='\033[38;5;108m'
_SSH_WARN='\033[38;5;179m'
_SSH_ERR='\033[38;5;196m'
_SSH_INFO='\033[38;5;110m'
_SSH_DIM='\033[38;5;244m'
_SSH_RESET='\033[0m'

alias ssh-raw='command ssh'

## --- Injection active seulement pour une session ssh interactive et sans commande distante ---
## Options ssh qui consomment un argument séparé : -B -b -c -D -E -e -F -I -i -J -L -l -m -O -o -p -Q -R -S -W -w
_ssh_wrapper_should_inject() {
    emulate -L bash 2>/dev/null
    local arg skip_next=0 saw_dest=0 extra=0
    for arg in "$@"; do
        if [ "$skip_next" -eq 1 ]; then skip_next=0; continue; fi
        case "$arg" in
            -N|-T|-f|-n|-G|-V) return 1 ;;
            -[BbcDEeFIiJLlmOopQRSWw]) skip_next=1 ;;
            -*) ;;
            *)
                if [ "$saw_dest" -eq 0 ]; then saw_dest=1; else extra=1; fi
                ;;
        esac
    done
    [ "$extra" -eq 1 ] && return 1
    [ "$saw_dest" -eq 0 ] && return 1
    return 0
}

## Extrait la destination (hôte) des arguments ssh, en sautant les options qui consomment
## un argument séparé (même liste que _ssh_wrapper_should_inject) — sert de clé de cache.
_ssh_extract_dest() {
    emulate -L bash 2>/dev/null
    local arg skip_next=0
    for arg in "$@"; do
        if [ "$skip_next" -eq 1 ]; then skip_next=0; continue; fi
        case "$arg" in
            -[BbcDEeFIiJLlmOopQRSWw]) skip_next=1 ;;
            -*) ;;
            *) printf '%s' "$arg"; return 0 ;;
        esac
    done
}

## --- Cache par hôte du résultat de ssh-chezmoi-test, pour éviter de re-tenter l'injection
## (et son avertissement) à chaque connexion vers un hôte déjà connu incompatible ---
_ssh_cache_get() {
    emulate -L bash 2>/dev/null
    local host="$1" now h status ts
    [ "$_SSH_CHEZMOI_CACHE_TTL" -gt 0 ] || return 0
    [ -f "$_SSH_CHEZMOI_CACHE_FILE" ] || return 0
    now=$(date +%s)
    while IFS=$'\t' read -r h status ts; do
        [ "$h" = "$host" ] || continue
        [ $((now - ts)) -le "$_SSH_CHEZMOI_CACHE_TTL" ] || continue
        printf '%s' "$status"
        return 0
    done < "$_SSH_CHEZMOI_CACHE_FILE"
}

_ssh_cache_set() {
    emulate -L bash 2>/dev/null
    local host="$1" status="$2" now tmp
    [ "$_SSH_CHEZMOI_CACHE_TTL" -gt 0 ] || return 0
    now=$(date +%s)
    mkdir -p "$(dirname "$_SSH_CHEZMOI_CACHE_FILE")" 2>/dev/null
    tmp=$(mktemp)
    [ -f "$_SSH_CHEZMOI_CACHE_FILE" ] && awk -F'\t' -v h="$host" '$1 != h' "$_SSH_CHEZMOI_CACHE_FILE" > "$tmp"
    printf '%s\t%s\t%s\n' "$host" "$status" "$now" >> "$tmp"
    mv "$tmp" "$_SSH_CHEZMOI_CACHE_FILE"
}

## Concatène le contenu des modules listés dans _SSH_CHEZMOI_MODULES (prompt -> variante shell distant)
_ssh_build_payload() {
    emulate -L bash 2>/dev/null
    local mod file payload=""
    for mod in $_SSH_CHEZMOI_MODULES; do
        if [ "$mod" = "prompt" ]; then
            if [ "$_SSH_CHEZMOI_SHELL" = "zsh" ]; then
                file="$CHEZMOI_DIR/prompt.zsh"
            else
                file="$CHEZMOI_DIR/prompt.sh"
            fi
        else
            file="$CHEZMOI_DIR/$mod.sh"
        fi
        [ -f "$file" ] || continue
        payload="${payload}$(cat "$file")"$'\n'
    done
    printf '%s' "$payload"
}

## Construit la commande distante. Le b64 (config + bannière, cf. ssh()) est embarqué comme
## littéral entre guillemets simples, sûr quel que soit son contenu (alphabet base64 sans
## métacaractère shell ni guillemet simple).
##
## Piège évité : un "eval" dans le shell courant PUIS un "exec <shell> -i" perd tout ce que
## l'eval vient de poser (PROMPT_COMMAND, fonctions...) — exec REMPLACE le process, seules les
## variables exportées survivent (ex: CHEZMOI_REMOTE). Constaté en prod : la bannière
## s'affichait mais le prompt restait celui de l'hôte. Fix : ne jamais eval-puis-exec ;
## faire lire la config par le shell interactif final lui-même, comme rcfile.
##   - bash : `--rcfile <(...)` fournit ça sans écrire sur disque. `<(...)` est une syntaxe
##     bash — on l'isole dans un `bash -c '...'` explicite pour ne pas dépendre du shell qui
##     exécute cette commande côté sshd (souvent le login shell de l'utilisateur, potentiellement
##     sh/dash pour un compte de service : testé et sûr avec dash comme interprète externe).
##   - autre shell (zsh...) : pas d'équivalent à `--rcfile` sans fichier ; ZDOTDIR pointé sur un
##     dossier `mktemp -d` contenant un `.zshrc` auto-supprimé dès qu'il est sourcé.
_ssh_remote_command() {
    emulate -L bash 2>/dev/null
    local shell_bin="$1" b64="$2"
    if [ "$shell_bin" = "bash" ]; then
        printf '%s' \
"export CHEZMOI_REMOTE=1; \
if command -v base64 >/dev/null 2>&1 && command -v bash >/dev/null 2>&1; then \
exec bash -c 'exec bash --rcfile <(printf \"%s\" \"\$1\" | base64 -d 2>/dev/null) -i' _ '${b64}'; \
else \
printf '\\033[38;5;179mchezmoi: base64/bash indisponible côté distant, session normale\\033[0m\\n' >&2; \
exec sh -i; \
fi"
    else
        printf '%s' \
"export CHEZMOI_REMOTE=1; \
if command -v base64 >/dev/null 2>&1 && command -v ${shell_bin} >/dev/null 2>&1; then \
_cz_zdotdir=\$(mktemp -d 2>/dev/null); \
if [ -n \"\$_cz_zdotdir\" ]; then \
{ printf '%s' '${b64}' | base64 -d 2>/dev/null; printf '\\nrm -rf \"%s\" 2>/dev/null\\n' \"\$_cz_zdotdir\"; } > \"\$_cz_zdotdir/.zshrc\" 2>/dev/null; \
ZDOTDIR=\"\$_cz_zdotdir\" exec ${shell_bin} -i; \
fi; \
exec ${shell_bin} -i; \
else \
printf '\\033[38;5;179mchezmoi: base64/${shell_bin} indisponible côté distant, session normale\\033[0m\\n' >&2; \
exec sh -i; \
fi"
    fi
}

ssh() {
    emulate -L bash 2>/dev/null

    if [ "$_SSH_CHEZMOI_ENABLED" != "1" ] || [ $# -eq 0 ]; then
        command ssh "$@"
        return
    fi
    if ! [ -t 0 ] || ! [ -t 1 ]; then
        command ssh "$@"
        return
    fi
    if ! _ssh_wrapper_should_inject "$@"; then
        command ssh "$@"
        return
    fi
    if ! command -v base64 >/dev/null 2>&1; then
        command ssh "$@"
        return
    fi

    local dest cached
    dest="$(_ssh_extract_dest "$@")"
    if [ -n "$dest" ]; then
        cached=$(_ssh_cache_get "$dest")
        if [ "$cached" = "fail" ]; then
            printf "%b\n" "${_SSH_DIM}note: ${dest} connu incompatible avec l'injection (cache) — 'ssh-chezmoi-test ${dest}' pour re-vérifier${_SSH_RESET}" >&2
            command ssh "$@"
            return
        fi
    fi

    local payload size b64 remote_cmd
    payload="$(_ssh_build_payload)"
    size=${#payload}

    if [ "$size" -eq 0 ]; then
        command ssh "$@"
        return
    fi
    if [ "$size" -gt "$_SSH_CHEZMOI_MAXSIZE" ]; then
        printf "%b\n" "${_SSH_WARN}ssh: charge chezmoi trop volumineuse (${size} > ${_SSH_CHEZMOI_MAXSIZE} octets), session normale${_SSH_RESET}" >&2
        command ssh "$@"
        return
    fi

    ## La bannière fait partie de ce qui est sourcé côté distant (cf. note dans
    ## _ssh_remote_command) : elle doit voyager dans le même b64 que les modules, pas être
    ## reconstruite après coup dans un process qui va disparaître au prochain exec.
    local banner full_payload
    banner="printf '\\033[38;5;108mchezmoi\\033[0m \\033[38;5;110mv${CHEZMOI_VERSION} chargé (${_SSH_CHEZMOI_SHELL}, remote)\\033[0m\\n'"
    full_payload="${payload}"$'\n'"${banner}"

    b64="$(printf '%s' "$full_payload" | base64 | tr -d '\n')"
    remote_cmd="$(_ssh_remote_command "$_SSH_CHEZMOI_SHELL" "$b64")"

    command ssh -t "$@" "$remote_cmd"
}

## --- ssh-chezmoi-test <host> : diagnostic sans ouvrir de session interactive ---
ssh-chezmoi-test() {
    emulate -L bash 2>/dev/null
    local host="$1"
    if [ -z "$host" ]; then
        printf "%b\n" "${_SSH_ERR}ssh-chezmoi-test: usage: ssh-chezmoi-test <host>${_SSH_RESET}" >&2
        return 1
    fi

    printf "%b\n" "${_SSH_INFO}ssh-chezmoi-test ${host}${_SSH_RESET}"

    local payload size b64 got
    payload="$(_ssh_build_payload)"
    size=${#payload}
    b64="$(printf '%s' "$payload" | base64 | tr -d '\n')"

    if [ "$size" -le "$_SSH_CHEZMOI_MAXSIZE" ]; then
        printf "%b\n" "  ${_SSH_OK}✔${_SSH_RESET} charge utile: ${size} octets (limite ${_SSH_CHEZMOI_MAXSIZE})"
    else
        printf "%b\n" "  ${_SSH_ERR}✘${_SSH_RESET} charge utile: ${size} octets, dépasse la limite ${_SSH_CHEZMOI_MAXSIZE}"
    fi

    got=$(command ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" \
        "printf '%s' '${b64}' | base64 -d" 2>/dev/null)
    if [ "$got" = "$payload" ]; then
        printf "%b\n" "  ${_SSH_OK}✔${_SSH_RESET} transmission de la charge utile en argument de commande OK"
        _ssh_cache_set "$host" ok
    else
        printf "%b\n" "  ${_SSH_ERR}✘${_SSH_RESET} échec de la transmission (commande distante forcée ? base64 absent ? charge trop grosse pour la limite du serveur ?)"
        _ssh_cache_set "$host" fail
    fi

    if command ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "command -v $_SSH_CHEZMOI_SHELL" >/dev/null 2>&1; then
        printf "%b\n" "  ${_SSH_OK}✔${_SSH_RESET} shell '${_SSH_CHEZMOI_SHELL}' présent côté distant"
    else
        printf "%b\n" "  ${_SSH_WARN}○${_SSH_RESET} shell '${_SSH_CHEZMOI_SHELL}' absent côté distant (fallback sh)"
    fi

    local bin
    for bin in git grep awk; do
        if command ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" "command -v $bin" >/dev/null 2>&1; then
            printf "%b\n" "  ${_SSH_OK}✔${_SSH_RESET} binaire '${bin}' présent côté distant"
        else
            printf "%b\n" "  ${_SSH_ERR}✘${_SSH_RESET} binaire '${bin}' absent côté distant"
        fi
    done
}
