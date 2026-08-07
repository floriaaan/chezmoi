## --- Tests: chezmoi.sh (barrel) ---
## CHEZMOI_NO_BANNER / CHEZMOI_NO_UPDATE_CHECK / CHEZMOI_NO_ZSH_PLUGINS déjà exportés par run.sh

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/chezmoi.sh"

test_chezmoi_version() {
    local out
    out=$(chezmoi version)
    assert_match "1\.4\.0" "$out" "chezmoi version affiche 1.4.0"
}

test_chezmoi_help() {
    local out
    out=$(chezmoi help)
    assert_match "Usage" "$out" "chezmoi help affiche l'usage"
}

test_chezmoi_unknown_command_fails() {
    assert_failure "chezmoi bogus échoue" -- chezmoi bogus
}

test_chezmoi_doctor_runs() {
    local out
    out=$(chezmoi doctor)
    assert_match "doctor" "$out" "chezmoi doctor affiche son titre"
    assert_match "ports" "$out" "chezmoi doctor vérifie le module ports"
    assert_match "extract" "$out" "chezmoi doctor vérifie le module extract"
}

test_chezmoi_doctor_shows_remote_when_active() {
    (
        export CHEZMOI_REMOTE=1
        local out
        out=$(chezmoi doctor)
        assert_match "CHEZMOI_REMOTE" "$out" "chezmoi doctor signale CHEZMOI_REMOTE actif"
    )
}

test_chezmoi_update_refused_when_remote() {
    (
        export CHEZMOI_REMOTE=1
        assert_failure "chezmoi update échoue en session distante" -- chezmoi update
    )
}
