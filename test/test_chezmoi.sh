## --- Tests: chezmoi.sh (barrel) ---
## CHEZMOI_NO_BANNER / CHEZMOI_NO_UPDATE_CHECK / CHEZMOI_NO_ZSH_PLUGINS déjà exportés par run.sh

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
## XDG_CONFIG_HOME détourné le temps de sourcer le barrel : config.sh calcule
## CHEZMOI_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi" sans condition (pas de garde
## "${VAR:-...}" réutilisant une valeur déjà posée), donc sans ce détournement il lirait le vrai
## ~/.config/chezmoi/config de la machine et répercuterait son contenu (prompt.theme,
## prompt.segments...) dans des variables globales -- posées ici hors de tout sous-shell, elles
## survivraient pour le reste du process de test et fausseraient tous les tests de prompt.sh/.zsh
## sourcés après ce fichier (pollution suivant l'ordre de découverte de compgen -A function, qui
## n'est pas garanti être l'ordre alphabétique des fichiers test_*.sh).
_test_chezmoi_orig_xdg_config_home="$XDG_CONFIG_HOME"
export XDG_CONFIG_HOME=$(mktemp -d)
source "$_test_repo_dir/chezmoi.sh"
export XDG_CONFIG_HOME="$_test_chezmoi_orig_xdg_config_home"

test_chezmoi_version() {
    local out
    out=$(chezmoi version)
    assert_match "$CHEZMOI_VERSION" "$out" "chezmoi version affiche CHEZMOI_VERSION"
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
