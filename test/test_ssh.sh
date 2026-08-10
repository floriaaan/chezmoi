## --- Tests: ssh.sh ---
## Ne teste que les fonctions pures de décision : aucune vraie connexion ssh n'est ouverte.

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/ssh.sh"

test_ssh_inject_plain_host_is_interactive() {
    assert_success "ssh host (juste une destination) -> injection candidate" -- _ssh_wrapper_should_inject "myhost"
}

test_ssh_inject_with_options_still_interactive() {
    assert_success "ssh -p 2222 -o StrictHostKeyChecking=no host -> injection candidate" \
        -- _ssh_wrapper_should_inject -p 2222 -o StrictHostKeyChecking=no myhost
}

test_ssh_no_inject_with_remote_command() {
    assert_failure "ssh host ls -la (commande distante) -> pas d'injection" \
        -- _ssh_wrapper_should_inject myhost ls -la
}

test_ssh_no_inject_with_dash_n() {
    assert_failure "ssh -N host (tunnel) -> pas d'injection" -- _ssh_wrapper_should_inject -N myhost
}

test_ssh_no_inject_with_dash_capital_t() {
    assert_failure "ssh -T host -> pas d'injection" -- _ssh_wrapper_should_inject -T myhost
}

test_ssh_no_inject_without_destination() {
    assert_failure "ssh -v (aucune destination) -> pas d'injection" -- _ssh_wrapper_should_inject -v
}

test_ssh_build_payload_contains_modules() {
    (
        _SSH_CHEZMOI_MODULES="git-aliases"
        local out
        out=$(_ssh_build_payload)
        assert_match "alias ga=" "$out" "le payload embarque le contenu de git-aliases.sh"
    )
}

test_ssh_build_payload_size_within_default_limit() {
    local payload size
    payload=$(_ssh_build_payload)
    size=${#payload}
    assert_success "le payload par défaut (prompt+git-aliases+gtag) tient sous _SSH_CHEZMOI_MAXSIZE" \
        -- test "$size" -le "$_SSH_CHEZMOI_MAXSIZE"
}

test_ssh_disabled_flag_skips_wrapper_check() {
    (
        _SSH_CHEZMOI_ENABLED=0
        # avec le flag désactivé, ssh() doit passer directement à command ssh -- on ne peut pas
        # tester l'appel réseau ici, mais on vérifie au moins que la fonction reste définie et safe à appeler à blanc.
        assert_success "_SSH_CHEZMOI_ENABLED=0 n'empêche pas la fonction ssh d'exister" -- declare -f ssh
    )
}

test_ssh_raw_alias_bypasses_wrapper() {
    assert_match "command ssh" "$(alias ssh-raw)" "ssh-raw = command ssh (contourne le wrapper)"
}

test_ssh_extract_dest_plain() {
    local out
    out=$(_ssh_extract_dest "myhost")
    assert_eq "myhost" "$out" "_ssh_extract_dest: destination seule"
}

test_ssh_extract_dest_skips_option_values() {
    local out
    out=$(_ssh_extract_dest -p 2222 -o StrictHostKeyChecking=no myhost)
    assert_eq "myhost" "$out" "_ssh_extract_dest: options avec valeur sautées correctement"
}

test_ssh_remote_command_embeds_b64_literal_not_env_var() {
    local out
    out=$(_ssh_remote_command bash "QUlDSQ==")
    assert_match "'QUlDSQ=='" "$out" "_ssh_remote_command embarque le b64 en littéral"
    assert_not_match "CHEZMOI_SSH_PAYLOAD" "$out" "_ssh_remote_command ne dépend plus d'une variable d'env (AcceptEnv)"
}

test_ssh_remote_command_bash_never_evals_then_execs() {
    # Régression : un "eval" dans le shell courant PUIS un "exec bash -i" perd PROMPT_COMMAND
    # et les fonctions (seules les variables exportées survivent à exec). La commande générée
    # doit faire lire la config par le "bash --rcfile" final lui-même, jamais eval-puis-exec.
    local out
    out=$(_ssh_remote_command bash "QUlDSQ==")
    assert_match "\-\-rcfile" "$out" "bash: la config est lue via --rcfile (survit à l'exec), pas eval-puis-exec"
    assert_not_match "^eval " "$out" "bash: pas d'eval au niveau racine de la commande"
}

test_ssh_remote_command_isolates_process_substitution_in_bash_dash_c() {
    # <(...) est une syntaxe bash : elle doit être confinée dans un 'bash -c ...' explicite pour
    # rester sûre même si le shell qui exécute cette commande côté sshd est sh/dash.
    if ! command -v dash >/dev/null 2>&1; then
        printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} (dash absent, test sauté)"
        return 0
    fi
    local out
    out=$(_ssh_remote_command bash "QUlDSQ==")
    assert_success "la commande générée est parseable par dash (pas de <(...) au niveau racine)" \
        -- dash -n <(printf '%s' "$out")
}

test_ssh_remote_command_zsh_uses_zdotdir_not_setenv_payload() {
    local out
    out=$(_ssh_remote_command zsh "QUlDSQ==")
    assert_match "ZDOTDIR" "$out" "zsh: transport via ZDOTDIR (pas de --rcfile pour zsh)"
    assert_not_match "CHEZMOI_SSH_PAYLOAD" "$out" "zsh: pas de dépendance à une variable d'env"
}

test_ssh_cache_roundtrip_ok() {
    (
        _SSH_CHEZMOI_CACHE_FILE=$(mktemp)
        _ssh_cache_set "goodhost" ok
        local out
        out=$(_ssh_cache_get "goodhost")
        assert_eq "ok" "$out" "cache: lit ce qui vient d'être écrit"
    )
}

test_ssh_cache_overwrites_previous_status() {
    (
        _SSH_CHEZMOI_CACHE_FILE=$(mktemp)
        _ssh_cache_set "flappy" ok
        _ssh_cache_set "flappy" fail
        local out
        out=$(_ssh_cache_get "flappy")
        assert_eq "fail" "$out" "cache: un nouveau _ssh_cache_set remplace l'ancien statut (pas de doublon)"
    )
}

test_ssh_cache_miss_for_unknown_host() {
    (
        _SSH_CHEZMOI_CACHE_FILE=$(mktemp)
        _ssh_cache_set "somehost" fail
        local out
        out=$(_ssh_cache_get "otherhost")
        assert_eq "" "$out" "cache: pas d'entrée pour un hôte jamais vu"
    )
}

test_ssh_cache_expires_after_ttl() {
    (
        _SSH_CHEZMOI_CACHE_FILE=$(mktemp)
        _SSH_CHEZMOI_CACHE_TTL=100
        printf 'stalehost\tfail\t0\n' > "$_SSH_CHEZMOI_CACHE_FILE"
        local out
        out=$(_ssh_cache_get "stalehost")
        assert_eq "" "$out" "cache: une entrée plus vieille que le TTL est traitée comme absente"
    )
}

test_ssh_prompt_filter_keeps_only_selected_theme() {
    (
        local out
        out=$(_ssh_prompt_filter_theme "$_test_repo_dir/prompt.sh" minimal)
        assert_match '_build_ps1_minimal\(\) \{' "$out" "filtre thème minimal: garde _build_ps1_minimal"
        assert_not_match '_build_ps1_default\(\) \{' "$out" "filtre thème minimal: retire la définition de _build_ps1_default"
    )
}

test_ssh_build_payload_prompt_respects_theme() {
    (
        _SSH_CHEZMOI_MODULES="prompt"
        CHEZMOI_PROMPT_THEME="minimal"
        local out
        out=$(_ssh_build_payload)
        assert_match "_build_ps1_minimal\(\) \{" "$out" "payload ssh prompt=minimal: contient le rendu minimal"
        assert_not_match "_build_ps1_default\(\) \{" "$out" "payload ssh prompt=minimal: n'embarque pas le rendu default (charge utile allégée)"
    )
}

test_ssh_build_payload_prompt_forces_theme_literal() {
    (
        _SSH_CHEZMOI_MODULES="prompt"
        CHEZMOI_PROMPT_THEME="minimal"
        local out
        out=$(_ssh_build_payload)
        assert_match "CHEZMOI_PROMPT_THEME='minimal'" "$out" "payload ssh: le thème actif est imposé en littéral (l'hôte distant n'a pas la config locale)"
    )
}

test_ssh_build_payload_prompt_theme_reduces_size() {
    (
        _SSH_CHEZMOI_MODULES="prompt"
        local payload_minimal payload_default
        CHEZMOI_PROMPT_THEME="minimal"
        payload_minimal=$(_ssh_build_payload)
        CHEZMOI_PROMPT_THEME="default"
        payload_default=$(_ssh_build_payload)
        assert_success "filtrer sur le thème actif réduit la charge utile ssh" \
            -- test "${#payload_minimal}" -lt "${#payload_default}"
    )
}

test_ssh_build_payload_prompt_theme_sanitizes_quote() {
    (
        _SSH_CHEZMOI_MODULES="prompt"
        CHEZMOI_PROMPT_THEME="a'b"
        local out
        out=$(_ssh_build_payload)
        assert_match "CHEZMOI_PROMPT_THEME='default'" "$out" "une valeur de thème avec un guillemet simple retombe sur 'default' (pas d'injection dans le littéral)"
    )
}

test_ssh_cache_disabled_with_zero_ttl() {
    (
        _SSH_CHEZMOI_CACHE_FILE=$(mktemp)
        _SSH_CHEZMOI_CACHE_TTL=0
        _ssh_cache_set "anyhost" ok
        local out
        out=$(_ssh_cache_get "anyhost")
        assert_eq "" "$out" "_SSH_CHEZMOI_CACHE_TTL=0 désactive le cache (ni lecture ni écriture utiles)"
    )
}
