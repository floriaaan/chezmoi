## --- Tests: config.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/config.sh"

test_config_default_prompt_theme() {
    (
        CHEZMOI_CONFIG_FILE=$(mktemp -u)
        local out
        out=$(_chezmoi_config_get prompt.theme)
        assert_eq "default" "$out" "prompt.theme sans fichier de config = défaut 'default'"
    )
}

test_config_default_ssh_modules() {
    (
        CHEZMOI_CONFIG_FILE=$(mktemp -u)
        local out
        out=$(_chezmoi_config_get ssh.modules)
        assert_eq "prompt git-aliases gtag" "$out" "ssh.modules sans fichier de config = défaut"
    )
}

test_config_set_persists_value() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        _chezmoi_config_set ssh.modules "prompt gtag" >/dev/null
        local out
        out=$(_chezmoi_config_get ssh.modules)
        assert_eq "prompt gtag" "$out" "chezmoi config set persiste la valeur dans le fichier"
    )
}

test_config_set_applies_immediately() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        _chezmoi_config_set ssh.modules "prompt gtag" >/dev/null
        assert_eq "prompt gtag" "$_SSH_CHEZMOI_MODULES" "chezmoi config set répercute tout de suite sur _SSH_CHEZMOI_MODULES"
    )
}

test_config_set_unknown_key_fails() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        assert_failure "clé inconnue refusée" -- _chezmoi_config_set bogus.key value
    )
}

test_config_set_overwrites_previous_value() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        _chezmoi_config_set prompt.theme "one" >/dev/null
        _chezmoi_config_set prompt.theme "two" >/dev/null
        local out
        out=$(_chezmoi_config_get prompt.theme)
        assert_eq "two" "$out" "un nouveau set remplace l'ancienne valeur (pas de doublon)"
    )
}

test_config_unset_resets_to_default() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        _chezmoi_config_set prompt.theme "custom" >/dev/null
        _chezmoi_config_unset prompt.theme >/dev/null
        local out
        out=$(_chezmoi_config_get prompt.theme)
        assert_eq "default" "$out" "chezmoi config unset revient au défaut"
    )
}

test_config_list_shows_known_keys() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        local out
        out=$(_chezmoi_config_list)
        assert_match "prompt.theme" "$out" "la liste affiche prompt.theme"
        assert_match "ssh.modules" "$out" "la liste affiche ssh.modules"
    )
}

test_config_cmd_get_unknown_key_fails() {
    assert_failure "chezmoi config get <clé inconnue> échoue" -- _chezmoi_config_cmd get bogus.key
}

test_config_cmd_get_known_key() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        local out
        out=$(_chezmoi_config_cmd get prompt.theme)
        assert_eq "default" "$out" "chezmoi config get prompt.theme affiche la valeur"
    )
}

test_config_cmd_unset_missing_key_fails() {
    assert_failure "chezmoi config unset sans clé échoue" -- _chezmoi_config_cmd unset
}

test_config_cmd_unknown_subcommand_fails() {
    assert_failure "chezmoi config <sous-commande inconnue> échoue" -- _chezmoi_config_cmd bogus
}
