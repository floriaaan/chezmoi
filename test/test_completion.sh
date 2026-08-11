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
    assert_match "reload" "${COMPREPLY[*]}" "chezmoi <TAB> propose reload"
    assert_match "version" "${COMPREPLY[*]}" "chezmoi <TAB> propose version"
}

## --- go-task : eval "$(task --completion <shell>)" si le binaire est présent, no-op sinon ---

test_task_completion_hookup_installs_completion_when_task_present() {
    (
        local fake_bin
        fake_bin=$(mktemp -d)
        cat > "$fake_bin/task" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--completion" ]; then
    echo '_fake_task_complete() { COMPREPLY=(fake); }'
    echo 'complete -F _fake_task_complete task'
fi
EOF
        chmod +x "$fake_bin/task"
        PATH="$fake_bin:$PATH"
        _completion_hookup_task
        assert_success "task présent -> le script de complétion qu'il fournit est bien évalué" \
            -- declare -f _fake_task_complete
    )
}

test_task_completion_hookup_noop_when_task_absent() {
    (
        local fake_bin
        fake_bin=$(mktemp -d)
        PATH="$fake_bin"
        assert_success "task absent du PATH -> _completion_hookup_task ne plante pas (no-op silencieux)" \
            -- _completion_hookup_task
    )
}

## --- chezmoi themes / chezmoi prompt : complétion ---

test_chezmoi_themes_completion_lists_theme_choices() {
    COMP_WORDS=(chezmoi themes "")
    COMP_CWORD=2
    COMPREPLY=()
    _chezmoi_complete
    assert_match "minimal" "${COMPREPLY[*]}" "chezmoi themes <TAB> propose minimal"
    assert_match "agnoster" "${COMPREPLY[*]}" "chezmoi themes <TAB> propose agnoster"
}

test_chezmoi_prompt_completion_lists_segment_names() {
    COMP_WORDS=(chezmoi prompt "")
    COMP_CWORD=2
    COMPREPLY=()
    _chezmoi_complete
    assert_match "battery" "${COMPREPLY[*]}" "chezmoi prompt <TAB> propose le segment battery"
    assert_match "docker" "${COMPREPLY[*]}" "chezmoi prompt <TAB> propose le segment docker"
}

test_chezmoi_top_level_completion_includes_themes_and_prompt() {
    COMP_WORDS=(chezmoi "")
    COMP_CWORD=1
    COMPREPLY=()
    _chezmoi_complete
    assert_match "themes" "${COMPREPLY[*]}" "chezmoi <TAB> propose themes"
    assert_match "prompt" "${COMPREPLY[*]}" "chezmoi <TAB> propose prompt"
}

## --- docker : eval "$(docker completion <shell>)" si le binaire est présent, no-op sinon ---

test_docker_completion_hookup_installs_completion_when_docker_present() {
    (
        local fake_bin
        fake_bin=$(mktemp -d)
        cat > "$fake_bin/docker" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "completion" ]; then
    echo '_fake_docker_complete() { COMPREPLY=(fake); }'
    echo 'complete -F _fake_docker_complete docker'
fi
EOF
        chmod +x "$fake_bin/docker"
        PATH="$fake_bin:$PATH"
        _completion_hookup_docker
        assert_success "docker présent -> le script de complétion qu'il fournit est bien évalué" \
            -- declare -f _fake_docker_complete
    )
}

test_docker_completion_hookup_noop_when_docker_absent() {
    (
        local fake_bin
        fake_bin=$(mktemp -d)
        PATH="$fake_bin"
        assert_success "docker absent du PATH -> _completion_hookup_docker ne plante pas (no-op silencieux)" \
            -- _completion_hookup_docker
    )
}

## --- chargement paresseux (task/docker/alias-git) : stub au démarrage, chargement réel au 1er <TAB> ---

test_lazy_task_registers_stub_instead_of_eager_load() {
    (
        local fake_bin
        fake_bin=$(mktemp -d)
        cat > "$fake_bin/task" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--completion" ] && echo 'complete -F _fake_task_complete task'
EOF
        chmod +x "$fake_bin/task"
        PATH="$fake_bin:$PATH"
        unset CHEZMOI_NO_LAZY_COMPLETION
        source "$_test_repo_dir/completion.sh"
        local out
        out=$(complete -p task 2>/dev/null)
        assert_match "_completion_lazy_task" "$out" "task présent, lazy activé -> stub enregistré (pas de chargement au démarrage)"
    )
}

test_lazy_task_first_tab_loads_and_redispatches() {
    (
        local fake_bin
        fake_bin=$(mktemp -d)
        cat > "$fake_bin/task" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "--completion" ]; then
    echo '_fake_task_complete() { COMPREPLY=(fake-result); }'
    echo 'complete -F _fake_task_complete task'
fi
EOF
        chmod +x "$fake_bin/task"
        PATH="$fake_bin:$PATH"
        unset CHEZMOI_NO_LAZY_COMPLETION
        source "$_test_repo_dir/completion.sh"
        COMP_WORDS=(task "")
        COMP_CWORD=1
        COMPREPLY=()
        _completion_lazy_task
        assert_match "fake-result" "${COMPREPLY[*]}" "1er <TAB>: la vraie complétion charge et répond dès le premier appel"
        local out
        out=$(complete -p task 2>/dev/null)
        assert_match "_fake_task_complete" "$out" "1er <TAB>: le stub est remplacé par la vraie fonction (2e <TAB> direct)"
    )
}

test_lazy_disabled_falls_back_to_eager_load() {
    (
        local fake_bin
        fake_bin=$(mktemp -d)
        cat > "$fake_bin/task" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "--completion" ] && echo 'complete -F _fake_task_complete task'
EOF
        chmod +x "$fake_bin/task"
        PATH="$fake_bin:$PATH"
        export CHEZMOI_NO_LAZY_COMPLETION=1
        source "$_test_repo_dir/completion.sh"
        local out
        out=$(complete -p task 2>/dev/null)
        assert_match "_fake_task_complete" "$out" "CHEZMOI_NO_LAZY_COMPLETION=1 -> chargement eager, pas de stub"
    )
}

test_lazy_git_alias_stub_registered_when_chezmoi_dir_known() {
    (
        unset CHEZMOI_NO_LAZY_COMPLETION
        CHEZMOI_DIR="$_test_repo_dir"
        source "$_test_repo_dir/completion.sh"
        local out
        out=$(complete -p gco 2>/dev/null)
        assert_match "_completion_lazy_git_alias" "$out" "gco: stub paresseux enregistré (CHEZMOI_DIR connu)"
    )
}

test_lazy_git_alias_first_tab_loads_and_redispatches() {
    (
        unset -f __git_complete 2>/dev/null
        local fake_dir
        fake_dir=$(mktemp -d)
        cat > "$fake_dir/git-completion.bash" <<'EOF'
__git_complete() {
    eval "$2() { COMPREPLY=(fake-branch); }"
    complete -F "$2" "$1"
}
EOF
        _COMPLETION_GIT_COMPLETION_PATHS=("$fake_dir/git-completion.bash")
        COMP_WORDS=(gco "")
        COMP_CWORD=1
        COMPREPLY=()
        _completion_lazy_git_alias
        assert_match "fake-branch" "${COMPREPLY[*]}" "1er <TAB> sur gco: charge git-completion.bash et répond dès le premier appel"
    )
}

## --- git : hookup __git_complete sur tous les alias de git-aliases.sh (si dispo sur la machine) ---

test_git_alias_completion_hookup_noop_without_git_complete() {
    (
        unset -f __git_complete 2>/dev/null
        _COMPLETION_GIT_COMPLETION_PATHS=()
        assert_success "__git_complete absent et aucun git-completion.bash trouvable -> pas de plantage" \
            -- _completion_hookup_git_aliases
    )
}

## __git_complete/_git_xxx sont souvent chargés paresseusement par bash-completion (au premier
## "git <TAB>" de la session) : absents si ce module est sourcé au démarrage du shell, avant tout
## TAB. _completion_source_git_completion_bash doit aller chercher git-completion.bash lui-même.
test_git_completion_bash_sourced_from_known_path_when_git_complete_missing() {
    (
        unset -f __git_complete 2>/dev/null
        local fake_dir
        fake_dir=$(mktemp -d)
        cat > "$fake_dir/git-completion.bash" <<'EOF'
__git_complete() { :; }
_git_checkout() { :; }
EOF
        _COMPLETION_GIT_COMPLETION_PATHS=("$fake_dir/git-completion.bash")
        _completion_source_git_completion_bash
        assert_success "git-completion.bash trouvé à un chemin connu -> sourcé, __git_complete défini" \
            -- declare -f __git_complete
    )
}

test_git_completion_bash_lookup_skipped_when_git_complete_already_defined() {
    (
        __git_complete() { :; }
        _COMPLETION_GIT_COMPLETION_PATHS=("/does/not/exist/git-completion.bash")
        assert_success "__git_complete déjà défini -> pas de recherche de fichier inutile" \
            -- _completion_source_git_completion_bash
    )
}

test_git_alias_completion_hookup_covers_every_alias_of_git_aliases_sh() {
    (
        local calls=() aliases_defined aliases_hooked
        __git_complete() { calls+=("$1"); }
        _completion_hookup_git_aliases
        aliases_defined=$(grep -oE "^alias [a-zA-Z]+=" "$_test_repo_dir/git-aliases.sh" \
            | sed -E 's/^alias ([a-zA-Z]+)=/\1/' | sort -u | tr '\n' ' ')
        aliases_hooked=$(printf '%s\n' "${calls[@]}" | sort -u | tr '\n' ' ')
        assert_eq "$aliases_defined" "$aliases_hooked" \
            "chaque alias de git-aliases.sh a une complétion git hookée (et aucun alias fantôme)"
    )
}

test_git_alias_gco_maps_to_git_checkout_completion() {
    (
        local got=""
        __git_complete() { [ "$1" = "gco" ] && got="$2"; }
        _completion_hookup_git_aliases
        assert_eq "_git_checkout" "$got" \
            "gco -> complétion de 'git checkout' (ex: gco sta<TAB> -> gco staging)"
    )
}

test_git_alias_gp_maps_to_git_push_completion() {
    (
        local got=""
        __git_complete() { [ "$1" = "gp" ] && got="$2"; }
        _completion_hookup_git_aliases
        assert_eq "_git_push" "$got" "gp -> complétion de 'git push' (remotes/branches)"
    )
}

test_git_alias_gs_maps_to_git_stash_completion() {
    (
        local got=""
        __git_complete() { [ "$1" = "gs" ] && got="$2"; }
        _completion_hookup_git_aliases
        assert_eq "_git_stash" "$got" "gs -> complétion de 'git stash'"
    )
}
