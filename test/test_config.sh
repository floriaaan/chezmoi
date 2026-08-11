## --- Tests: config.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
## XDG_CONFIG_HOME détourné le temps de sourcer config.sh : sans ça, _chezmoi_config_load_all (fin
## de fichier) lirait le vrai ~/.config/chezmoi/config de la machine et répercuterait son contenu
## (prompt.theme, prompt.segments...) dans des variables globales -- posées ici hors de tout
## sous-shell, elles survivraient pour le reste du process de test et fausseraient tous les tests
## de prompt.sh/.zsh sourcés après ce fichier (pollution suivant l'ordre de découverte de
## compgen -A function, qui n'est pas garanti être l'ordre alphabétique des fichiers test_*.sh).
_test_config_orig_xdg_config_home="$XDG_CONFIG_HOME"
export XDG_CONFIG_HOME=$(mktemp -d)
source "$_test_repo_dir/config.sh"
export XDG_CONFIG_HOME="$_test_config_orig_xdg_config_home"

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

test_config_choices_prompt_theme_lists_all_themes() {
    local out
    out=$(_chezmoi_config_choices prompt.theme)
    assert_match "default" "$out" "_chezmoi_config_choices prompt.theme liste 'default'"
    assert_match "minimal" "$out" "_chezmoi_config_choices prompt.theme liste 'minimal'"
    assert_match "agnoster" "$out" "_chezmoi_config_choices prompt.theme liste 'agnoster'"
    assert_match "floriaaan" "$out" "_chezmoi_config_choices prompt.theme liste 'floriaaan'"
}

test_config_choices_free_form_key_is_empty() {
    local out
    out=$(_chezmoi_config_choices ssh.modules)
    assert_eq "" "$out" "ssh.modules est une clé à valeur libre: pas de choix énumérés"
}

test_config_set_no_value_lists_choices_for_closed_key() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        local out
        out=$(_chezmoi_config_set prompt.theme)
        assert_success "chezmoi config set prompt.theme sans valeur réussit (liste, n'échoue pas)" \
            -- _chezmoi_config_set prompt.theme
        assert_match "default" "$out" "la liste des choix contient 'default'"
        assert_match "minimal" "$out" "la liste des choix contient 'minimal'"
        assert_match "agnoster" "$out" "la liste des choix contient 'agnoster'"
        assert_match "floriaaan" "$out" "la liste des choix contient 'floriaaan'"
    )
}

test_config_preview_returns_example_per_theme() {
    local out
    out=$(_chezmoi_config_preview prompt.theme default)
    assert_match '\$' "$out" "aperçu 'default': se termine par le \$ du PS1 bash"
    out=$(_chezmoi_config_preview prompt.theme minimal)
    assert_match "❯" "$out" "aperçu 'minimal': contient le caractère de prompt"
    out=$(_chezmoi_config_preview prompt.theme agnoster)
    assert_match "▶" "$out" "aperçu 'agnoster': contient le séparateur de segment"
    out=$(_chezmoi_config_preview prompt.theme floriaaan)
    assert_match "main" "$out" "aperçu 'floriaaan': contient un exemple de branche"
}

test_config_preview_empty_for_free_form_key() {
    local out
    out=$(_chezmoi_config_preview ssh.modules "prompt gtag")
    assert_eq "" "$out" "pas d'aperçu pour une clé à valeur libre"
}

test_config_set_no_value_includes_preview_for_each_theme() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        local out
        out=$(_chezmoi_config_set prompt.theme)
        assert_match "❯" "$out" "la liste inclut un aperçu du rendu (pas que les noms)"
        assert_match "▶" "$out" "la liste inclut l'aperçu du thème agnoster"
    )
}

test_config_set_no_value_marks_active_choice() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        _chezmoi_config_set prompt.theme minimal >/dev/null
        local out
        out=$(_chezmoi_config_set prompt.theme)
        assert_match "minimal.*actif" "$out" "le thème actuellement actif est marqué dans la liste"
    )
}

test_config_set_no_value_fails_for_free_form_key() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        assert_failure "ssh.modules sans valeur échoue (clé à valeur libre, pas de choix à lister)" \
            -- _chezmoi_config_set ssh.modules
    )
}

test_config_cmd_set_no_value_lists_choices() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        assert_success "chezmoi config set prompt.theme (sans valeur) via _chezmoi_config_cmd" \
            -- _chezmoi_config_cmd set prompt.theme
    )
}

test_config_default_prompt_segments_is_empty() {
    (
        CHEZMOI_CONFIG_FILE=$(mktemp -u)
        local out
        out=$(_chezmoi_config_get prompt.segments)
        assert_eq "" "$out" "prompt.segments sans fichier de config = défaut vide (liste du thème)"
    )
}

test_config_set_prompt_segments_persists_and_applies() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        _chezmoi_config_set prompt.segments "time dir git node" >/dev/null
        local out
        out=$(_chezmoi_config_get prompt.segments)
        assert_eq "time dir git node" "$out" "chezmoi config set persiste prompt.segments"
        assert_eq "time dir git node" "$CHEZMOI_PROMPT_SEGMENTS" "chezmoi config set répercute tout de suite sur CHEZMOI_PROMPT_SEGMENTS"
    )
}

test_config_set_prompt_segments_no_value_lists_catalog_instead_of_failing() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        local out
        out=$(_chezmoi_config_set prompt.segments)
        assert_success "chezmoi config set prompt.segments sans valeur réussit (liste le catalogue, n'échoue pas)" \
            -- _chezmoi_config_set prompt.segments
        assert_match "time" "$out" "le catalogue listé contient le segment 'time'"
        assert_match "node" "$out" "le catalogue listé contient le segment 'node'"
        assert_match "exitcode" "$out" "le catalogue listé contient le segment 'exitcode'"
    )
}

test_config_default_modules_disabled_is_empty() {
    (
        CHEZMOI_CONFIG_FILE=$(mktemp -u)
        local out
        out=$(_chezmoi_config_get modules.disabled)
        assert_eq "" "$out" "modules.disabled sans fichier de config = défaut vide (tous les modules actifs)"
    )
}

test_config_edit_reloads_after_editing() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        local fake_editor
        fake_editor=$(mktemp)
        cat > "$fake_editor" <<'EOF'
#!/usr/bin/env bash
printf 'prompt.theme=minimal\n' > "$1"
EOF
        chmod +x "$fake_editor"
        EDITOR="$fake_editor" _chezmoi_config_edit >/dev/null
        local out
        out=$(_chezmoi_config_get prompt.theme)
        assert_eq "minimal" "$out" "chezmoi config edit: la valeur écrite à la main est prise en compte après édition"
    )
}

test_config_edit_creates_config_dir_and_file_if_missing() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)/nested
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        local fake_editor
        fake_editor=$(mktemp)
        cat > "$fake_editor" <<'EOF'
#!/usr/bin/env bash
: > "$1"
EOF
        chmod +x "$fake_editor"
        EDITOR="$fake_editor" _chezmoi_config_edit >/dev/null
        assert_success "chezmoi config edit crée le dossier/fichier de config s'il n'existe pas" \
            -- test -f "$CHEZMOI_CONFIG_FILE"
    )
}

test_config_edit_fails_without_any_editor() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        EDITOR="/does/not/exist/editor"
        command() { [ "$2" = "vi" ] && return 1; [ "$2" = "/does/not/exist/editor" ] && return 1; builtin command "$@"; }
        assert_failure "chezmoi config edit échoue si aucun éditeur n'est disponible" -- _chezmoi_config_edit
    )
}

test_config_list_shows_prompt_segments_key() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        local out
        out=$(_chezmoi_config_list)
        assert_match "prompt.segments" "$out" "la liste affiche prompt.segments"
    )
}
