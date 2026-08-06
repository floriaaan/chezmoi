## --- Tests: completion.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/completion.sh"

test_gtag_completion_top_level() {
    COMP_WORDS=(gtag "")
    COMP_CWORD=1
    COMPREPLY=()
    _gtag_complete
    assert_match "major" "${COMPREPLY[*]}" "gtag <TAB> propose major"
    assert_match "list" "${COMPREPLY[*]}" "gtag <TAB> propose list"
}

test_gtag_completion_list_subcommand() {
    COMP_WORDS=(gtag list "")
    COMP_CWORD=2
    COMPREPLY=()
    _gtag_complete
    assert_match "prod" "${COMPREPLY[*]}" "gtag list <TAB> propose prod"
    assert_match "dev" "${COMPREPLY[*]}" "gtag list <TAB> propose dev"
}

test_chezmoi_completion() {
    COMP_WORDS=(chezmoi "")
    COMP_CWORD=1
    COMPREPLY=()
    _chezmoi_complete
    assert_match "update" "${COMPREPLY[*]}" "chezmoi <TAB> propose update"
    assert_match "version" "${COMPREPLY[*]}" "chezmoi <TAB> propose version"
}
