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
