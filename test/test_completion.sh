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

## "complete -p <cmd>" sous zsh/bashcompinit renvoie TOUTES les registrations (cf. completion.sh) :
## on filtre nous-mêmes sur la ligne dont le dernier mot est bien <cmd>.
_test_complete_fn() {
    complete -p "$1" 2>/dev/null | awk -v c="$1" '$NF==c { for (i=1;i<NF;i++) if ($i=="-F") print $(i+1) }' | tail -n1
}

## Stubs paresseux bash uniquement : sous zsh, les alias git passent par compdef (cf. plus bas).
if [ -z "$ZSH_VERSION" ]; then

test_lazy_git_alias_stub_registered_when_git_completion_available() {
    (
        unset CHEZMOI_NO_LAZY_COMPLETION
        CHEZMOI_DIR="$_test_repo_dir"
        source "$_test_repo_dir/completion.sh"
        local fake_dir
        fake_dir=$(mktemp -d)
        echo '__git_complete() { :; }' > "$fake_dir/git-completion.bash"
        _COMPLETION_GIT_COMPLETION_PATHS=("$fake_dir/git-completion.bash")
        _completion_install_hookups
        local out
        out=$(_test_complete_fn gco)
        assert_match "_completion_lazy_git_alias" "$out" "gco: stub paresseux enregistré quand git-completion.bash est trouvable"
    )
}

## Sans git-completion.bash sur la machine (cas par défaut sous macOS), le hookup ne pourra jamais
## aboutir : enregistrer un stub y volerait la complétion par défaut des alias pour rien.
test_lazy_git_alias_no_stub_without_git_completion_bash() {
    (
        unset CHEZMOI_NO_LAZY_COMPLETION
        unset -f __git_complete 2>/dev/null
        CHEZMOI_DIR="$_test_repo_dir"
        source "$_test_repo_dir/completion.sh"
        complete -r gco 2>/dev/null
        _COMPLETION_GIT_COMPLETION_PATHS=()
        _completion_install_hookups
        local out
        out=$(_test_complete_fn gco)
        assert_eq "" "$out" "aucun git-completion.bash trouvable -> pas de stub sur gco (complétion par défaut préservée)"
    )
}

## Si malgré tout le hookup réel ne s'enregistre pas au 1er <TAB>, le stub doit se retirer lui-même.
test_lazy_stub_removes_itself_when_real_hookup_never_registers() {
    (
        unset CHEZMOI_NO_LAZY_COMPLETION
        source "$_test_repo_dir/completion.sh"
        complete -F _completion_lazy_git_alias gco
        unset -f __git_complete 2>/dev/null
        _COMPLETION_GIT_COMPLETION_PATHS=()
        COMP_WORDS=(gco "")
        COMP_CWORD=1
        COMPREPLY=()
        _completion_lazy_git_alias
        local out
        out=$(_test_complete_fn gco)
        assert_eq "" "$out" "hookup impossible -> le stub se désenregistre au lieu de bloquer les <TAB> suivants"
    )
}

fi

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

## --- table alias -> sous-commande git dérivée de git-aliases.sh ---

test_git_alias_pairs_derived_from_git_aliases_file() {
    (
        CHEZMOI_DIR="$_test_repo_dir"
        source "$_test_repo_dir/completion.sh"
        local pairs
        pairs=$(_completion_git_alias_pairs)
        assert_match "gco checkout" "$pairs" "gco est dérivé sur la sous-commande checkout"
        assert_match "gcp cherry-pick" "$pairs" "gcp est dérivé sur la sous-commande cherry-pick"
        assert_match "glog log" "$pairs" "glog est dérivé sur la sous-commande log"
    )
}

test_git_alias_cherry_pick_maps_to_underscored_completion_function() {
    (
        local got=""
        __git_complete() { [ "$1" = "gcp" ] && got="$2"; }
        _completion_hookup_git_aliases
        assert_eq "_git_cherry_pick" "$got" "gcp -> _git_cherry_pick (tiret converti en underscore)"
    )
}

## --- complétion des valeurs de "chezmoi config set <clé>" ---

test_config_set_prompt_segments_completion_lists_segments() {
    COMP_WORDS=(chezmoi config set prompt.segments "")
    COMP_CWORD=4
    COMPREPLY=()
    _chezmoi_complete
    assert_match "battery" "${COMPREPLY[*]}" "chezmoi config set prompt.segments <TAB> propose battery"
}

test_config_set_modules_disabled_completion_lists_modules() {
    COMP_WORDS=(chezmoi config set modules.disabled "")
    COMP_CWORD=4
    COMPREPLY=()
    _chezmoi_complete
    assert_match "docker" "${COMPREPLY[*]}" "chezmoi config set modules.disabled <TAB> propose docker"
}

test_config_set_theme_completion_still_lists_themes() {
    COMP_WORDS=(chezmoi config set prompt.theme "")
    COMP_CWORD=4
    COMPREPLY=()
    _chezmoi_complete
    assert_match "floriaaan" "${COMPREPLY[*]}" "chezmoi config set prompt.theme <TAB> propose floriaaan"
}

## --- zsh : les alias git réutilisent la complétion native compsys (compdef), pas un stub bash ---

if [ -n "$ZSH_VERSION" ]; then

test_zsh_git_aliases_hooked_through_compdef() {
    (
        local calls=()
        compdef() { calls+=("$2"); }
        _completion_hookup_git_aliases_zsh
        local joined="${calls[*]}"
        assert_match "gco=git-checkout" "$joined" "zsh: gco est mappé sur la complétion native de git checkout"
        assert_match "gcp=git-cherry-pick" "$joined" "zsh: gcp est mappé sur git cherry-pick"
    )
}

fi

## --- dépendance bash-completion (_init_completion) des scripts générés par task/docker ---

test_bash_completion_satisfied_passes_script_without_init_completion() {
    (
        _COMPLETION_BASH_COMPLETION_PATHS=()
        assert_success "script sans _init_completion -> aucune dépendance à satisfaire" \
            -- _completion_bash_completion_satisfied 'complete -F _foo foo'
    )
}

test_bash_completion_satisfied_fails_when_init_completion_unavailable() {
    (
        unset -f _init_completion 2>/dev/null
        _COMPLETION_BASH_COMPLETION_PATHS=()
        assert_failure "_init_completion introuvable -> hookup refusé (pas de complétion cassée enregistrée)" \
            -- _completion_bash_completion_satisfied '_init_completion -n : || return'
    )
}

test_bash_completion_sourced_from_known_path_when_needed() {
    (
        unset -f _init_completion 2>/dev/null
        local fake_dir
        fake_dir=$(mktemp -d)
        echo '_init_completion() { :; }' > "$fake_dir/bash_completion"
        _COMPLETION_BASH_COMPLETION_PATHS=("$fake_dir/bash_completion")
        assert_success "bash-completion trouvé à un chemin connu -> sourcé à la demande" \
            -- _completion_bash_completion_satisfied '_init_completion -n : || return'
    )
}

## Chemin bash uniquement (sous zsh, task génère un script compsys sans _init_completion).
if [ -z "$ZSH_VERSION" ]; then

## Régression : `task <TAB>` affichait "bash: _init_completion : commande introuvable" à chaque TAB.
test_task_hookup_registers_nothing_when_init_completion_unavailable() {
    (
        local fake_bin
        fake_bin=$(mktemp -d)
        cat > "$fake_bin/task" <<'TASKEOF'
#!/usr/bin/env bash
if [ "$1" = "--completion" ]; then
    echo '_broken_task_complete() { _init_completion -n : || return; }'
    echo 'complete -F _broken_task_complete task'
fi
TASKEOF
        chmod +x "$fake_bin/task"
        PATH="$fake_bin:$PATH"
        unset -f _init_completion 2>/dev/null
        complete -r task 2>/dev/null
        _COMPLETION_BASH_COMPLETION_PATHS=()
        _completion_hookup_task
        assert_failure "task: script dépendant de _init_completion non évalué quand bash-completion manque" \
            -- declare -f _broken_task_complete
    )
}

fi
