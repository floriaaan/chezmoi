## --- Tests: history.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/history.sh"

test_history_size() {
    assert_eq "50000" "$HISTSIZE" "HISTSIZE = 50000"
}

if [ -n "$ZSH_VERSION" ]; then

test_history_savehist() {
    assert_eq "50000" "$SAVEHIST" "SAVEHIST = 50000"
}

test_history_share_history_option() {
    if [[ -o share_history ]]; then assert_eq 1 1 "SHARE_HISTORY actif"; else assert_eq 1 0 "SHARE_HISTORY actif"; fi
}

test_history_ignore_all_dups_option() {
    if [[ -o hist_ignore_all_dups ]]; then assert_eq 1 1 "HIST_IGNORE_ALL_DUPS actif"; else assert_eq 1 0 "HIST_IGNORE_ALL_DUPS actif"; fi
}

test_history_ignore_space_option() {
    if [[ -o hist_ignore_space ]]; then assert_eq 1 1 "HIST_IGNORE_SPACE actif"; else assert_eq 1 0 "HIST_IGNORE_SPACE actif"; fi
}

test_history_inc_append_option() {
    if [[ -o inc_append_history ]]; then assert_eq 1 1 "INC_APPEND_HISTORY actif"; else assert_eq 1 0 "INC_APPEND_HISTORY actif"; fi
}

test_history_ignore_pattern_content() {
    assert_match "ls" "$HISTORY_IGNORE" "HISTORY_IGNORE ignore ls"
    assert_match "cd" "$HISTORY_IGNORE" "HISTORY_IGNORE ignore cd"
}

else

test_history_filesize() {
    assert_eq "50000" "$HISTFILESIZE" "HISTFILESIZE = 50000"
}

test_history_control_erasedups() {
    assert_match "erasedups" "$HISTCONTROL" "HISTCONTROL contient erasedups"
}

test_history_control_ignorespace() {
    assert_match "ignoreboth" "$HISTCONTROL" "HISTCONTROL contient ignoreboth (ignorespace+ignoredups)"
}

test_history_ignore_trivial_commands() {
    assert_match "ls" "$HISTIGNORE" "HISTIGNORE ignore ls"
    assert_match "cd" "$HISTIGNORE" "HISTIGNORE ignore cd"
}

test_history_sync_hook_registered() {
    assert_match "_chezmoi_history_sync" "$PROMPT_COMMAND" "PROMPT_COMMAND contient le hook de synchro"
}

test_history_sync_appends_without_overwriting() {
    (
        PROMPT_COMMAND="some_other_hook"
        source "$_test_repo_dir/history.sh"
        assert_match "some_other_hook.*_chezmoi_history_sync" "$PROMPT_COMMAND" "history.sh concatène à PROMPT_COMMAND existant, ne l'écrase pas"
    )
}

test_history_sync_not_added_twice() {
    (
        PROMPT_COMMAND="_chezmoi_history_sync"
        source "$_test_repo_dir/history.sh"
        local count
        count=$(grep -o "_chezmoi_history_sync" <<< "$PROMPT_COMMAND" | wc -l)
        assert_eq "1" "$count" "history.sh n'ajoute pas deux fois le même hook"
    )
}

fi
