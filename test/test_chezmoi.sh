## --- Tests: chezmoi.sh (barrel) ---
## CHEZMOI_NO_BANNER / CHEZMOI_NO_UPDATE_CHECK / CHEZMOI_NO_ZSH_PLUGINS déjà exportés par run.sh

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/chezmoi.sh"

test_chezmoi_version() {
    local out
    out=$(chezmoi version)
    assert_match "1\.3\.0" "$out" "chezmoi version affiche 1.3.0"
}

test_chezmoi_help() {
    local out
    out=$(chezmoi help)
    assert_match "Usage" "$out" "chezmoi help affiche l'usage"
}

test_chezmoi_unknown_command_fails() {
    assert_failure "chezmoi bogus échoue" -- chezmoi bogus
}
