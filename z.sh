## --- Mini "z" (jump) ---
export _Z_DATA="$HOME/.zdirs"
touch "$_Z_DATA"

_z_add() {
    local dir="$PWD"
    [ "$dir" = "$HOME" ] && return
    local now tmp found=0
    now=$(date +%s)
    tmp=$(mktemp)
    while IFS='|' read -r path rank time; do
        [ -z "$path" ] && continue
        if [ "$path" = "$dir" ]; then
            rank=$((rank + 1))
            time=$now
            found=1
        fi
        echo "$path|$rank|$time" >> "$tmp"
    done < "$_Z_DATA"
    [ "$found" -eq 0 ] && echo "$dir|1|$now" >> "$tmp"
    sort -t'|' -k2 -rn "$tmp" | head -n 500 > "$_Z_DATA"
    rm -f "$tmp"
}

z() {
    if [ -z "$1" ]; then cd "$HOME" || return; return; fi
    if [ -d "$1" ]; then cd "$1" || return; return; fi
    local best
    best=$(awk -F'|' -v pat="$1" '
        $1 ~ pat { score = $2 + 0; if (score > max) { max = score; best = $1 } }
        END { print best }
    ' "$_Z_DATA")
    if [ -n "$best" ] && [ -d "$best" ]; then
        cd "$best" || return
    else
        echo "z: aucun dossier trouvé pour '$1'" >&2
        return 1
    fi
}

## --- Autocomplétion pour z ---
_z_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local matches
    matches=$(awk -F'|' '{print $1}' "$_Z_DATA" 2>/dev/null | while read -r path; do
        [ -d "$path" ] && basename "$path"
    done | sort -u)
    COMPREPLY=($(compgen -W "$matches" -- "$cur"))
}
complete -F _z_complete z

PROMPT_COMMAND="_z_add;${PROMPT_COMMAND}"
