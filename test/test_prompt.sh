## --- Tests: prompt.sh / prompt.zsh (troncature de chemin + repère SSH) ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
if [ -n "$ZSH_VERSION" ]; then
    source "$_test_repo_dir/prompt.zsh"
else
    source "$_test_repo_dir/prompt.sh"
fi

test_prompt_path_unchanged_when_short() {
    local out
    out=$(_prompt_truncate_path "~/dev/arr")
    assert_eq "~/dev/arr" "$out" "chemin court: inchangé"
}

test_prompt_path_truncates_on_segment_boundary() {
    (
        _PROMPT_PATH_MAXLEN=25
        local out
        out=$(_prompt_truncate_path "~/dev/linkt/cockpit/src/components/shared")
        assert_eq "…/src/components/shared" "$out" "chemin long: tronqué sur segments entiers, plus grand suffixe tenant dans la limite"
    )
}

test_prompt_path_keeps_minimum_two_segments() {
    (
        _PROMPT_PATH_MAXLEN=1
        local out
        out=$(_prompt_truncate_path "~/a/b/c/d/e/f/g/h/i/j/k")
        assert_eq "…/j/k" "$out" "toujours au moins les 2 derniers segments, même si ça dépasse la limite"
    )
}

test_prompt_path_never_exceeds_maxlen_when_possible() {
    (
        _PROMPT_PATH_MAXLEN=40
        local out
        out=$(_prompt_truncate_path "~/dev/linkt/cockpit/src/components/shared")
        assert_success "résultat tient dans la limite quand c'est possible" -- test "${#out}" -le 40
    )
}

test_prompt_ssh_marker_off_locally() {
    (
        unset SSH_CONNECTION SSH_TTY
        if [ -n "$ZSH_VERSION" ]; then source "$_test_repo_dir/prompt.zsh"; else source "$_test_repo_dir/prompt.sh"; fi
        assert_eq "0" "$_CHEZMOI_IS_SSH" "pas de repère SSH en local"
    )
}

test_prompt_ssh_marker_on_remote() {
    (
        export SSH_CONNECTION="1.2.3.4 22 5.6.7.8 22"
        if [ -n "$ZSH_VERSION" ]; then source "$_test_repo_dir/prompt.zsh"; else source "$_test_repo_dir/prompt.sh"; fi
        assert_eq "1" "$_CHEZMOI_IS_SSH" "repère SSH actif quand SSH_CONNECTION est défini"
    )
}

_prompt_render() {
    if [ -n "$ZSH_VERSION" ]; then
        _chezmoi_precmd
        printf '%s' "$PROMPT"
    else
        _build_ps1
        printf '%s' "$PS1"
    fi
}

test_prompt_theme_default_has_time_segment() {
    (
        CHEZMOI_PROMPT_THEME=default
        local out
        out=$(_prompt_render)
        assert_match 'D\{' "$out" "thème default: le prompt contient un segment heure"
    )
}

test_prompt_theme_minimal_has_no_time_segment() {
    (
        CHEZMOI_PROMPT_THEME=minimal
        local out
        out=$(_prompt_render)
        assert_not_match 'D\{' "$out" "thème minimal: pas de segment heure (1 ligne, compact)"
    )
}

test_prompt_theme_unknown_falls_back_to_default() {
    (
        CHEZMOI_PROMPT_THEME=bogus
        local out
        out=$(_prompt_render)
        assert_match 'D\{' "$out" "thème inconnu -> fallback silencieux sur default"
    )
}

test_prompt_theme_agnoster_has_no_time_segment_but_has_separator() {
    (
        CHEZMOI_PROMPT_THEME=agnoster
        local out
        out=$(_prompt_render)
        assert_not_match 'D\{' "$out" "thème agnoster: pas de segment heure"
        assert_match '▶' "$out" "thème agnoster: contient le séparateur de segment ▶"
    )
}

test_agnoster_context_hidden_locally_non_root() {
    (
        if [ "${EUID:-1000}" -eq 0 ]; then
            printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} (root, test sauté)"
            return 0
        fi
        _CHEZMOI_IS_SSH=0
        local out
        out=$(_agnoster_context_segment)
        assert_eq "" "$out" "contexte masqué en local (non-ssh, non-root), comme le vrai agnoster"
    )
}

test_agnoster_context_shown_over_ssh() {
    (
        _CHEZMOI_IS_SSH=1
        local out
        out=$(_agnoster_context_segment)
        assert_match '▶' "$out" "contexte affiché en session ssh"
    )
}

test_agnoster_dir_segment_always_shown() {
    local out
    out=$(_agnoster_dir_segment)
    assert_match '▶' "$out" "le segment chemin est toujours affiché"
}

test_agnoster_status_segment_hidden_on_success() {
    local out
    out=$(_agnoster_status_segment 0)
    assert_eq "" "$out" "pas de segment statut quand la commande précédente a réussi"
}

test_agnoster_status_segment_shown_on_failure() {
    local out
    out=$(_agnoster_status_segment 1)
    assert_match '✘ 1' "$out" "segment statut affiché avec le code de sortie en cas d'échec"
}

test_exitcode_segment_hidden_on_success() {
    local out
    out=$(_exitcode_segment 0)
    assert_eq "" "$out" "segment exitcode: rien affiché quand la commande précédente a réussi"
}

test_exitcode_segment_shown_on_failure() {
    local out
    out=$(_exitcode_segment 1)
    assert_match '✘ 1' "$out" "segment exitcode: code de sortie affiché en cas d'échec"
}

test_node_segment_hidden_outside_node_project() {
    (
        local tmp
        tmp=$(mktemp -d)
        cd "$tmp" || exit 1
        local out
        out=$(_node_segment)
        assert_eq "" "$out" "segment node: rien affiché hors répertoire projet node (pas de package.json/.nvmrc)"
    )
}

test_node_segment_shown_with_package_json() {
    (
        command -v node >/dev/null 2>&1 || { printf "%b\n" "${_TEST_OK}ok${_TEST_RESET} (node absent, test sauté)"; return 0; }
        local tmp
        tmp=$(mktemp -d)
        cd "$tmp" || exit 1
        : > package.json
        local out
        out=$(_node_segment)
        assert_match 'v[0-9]' "$out" "segment node: affiche la version quand package.json est présent"
    )
}

test_prompt_segments_config_overrides_theme_default_order() {
    (
        CHEZMOI_PROMPT_THEME=default
        CHEZMOI_PROMPT_SEGMENTS="dir"
        local out
        out=$(_prompt_render)
        assert_not_match 'D\{' "$out" "prompt.segments personnalisé: n'affiche que les segments demandés (pas 'time')"
    )
}

test_prompt_segments_config_unknown_segment_is_silently_ignored() {
    (
        CHEZMOI_PROMPT_THEME=default
        CHEZMOI_PROMPT_SEGMENTS="dir bogus git"
        local out
        out=$(_prompt_render)
        assert_not_match 'bogus' "$out" "segment inconnu dans prompt.segments: ignoré silencieusement"
    )
}

test_prompt_segments_config_applies_to_agnoster_theme_too() {
    (
        CHEZMOI_PROMPT_THEME=agnoster
        CHEZMOI_PROMPT_SEGMENTS="dir"
        local out
        out=$(_prompt_render)
        assert_not_match '✘' "$out" "prompt.segments personnalisé s'applique aussi au thème agnoster (pas de segment exitcode ici)"
    )
}

test_git_segment_minimal_shows_branch_no_ahead_behind() {
    (
        local tmp branch out
        tmp=$(mktemp -d)
        cd "$tmp" || exit 1
        git init -q
        git config user.email "test@test.local"
        git config user.name "test"
        git commit -q --allow-empty -m "init"
        branch=$(git symbolic-ref --short HEAD)
        out=$(_git_segment_minimal)
        assert_match "$branch" "$out" "segment git minimal affiche la branche"
        assert_not_match "↑" "$out" "segment git minimal n'affiche pas ahead/behind"
    )
}
