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

test_chezmoi_reload_resources_without_git() {
    (
        local out
        out=$(chezmoi reload)
        assert_match "rechargement" "$out" "chezmoi reload affiche un message de rechargement"
    )
}

test_chezmoi_reload_works_when_remote() {
    (
        export CHEZMOI_REMOTE=1
        assert_success "chezmoi reload fonctionne aussi en session distante (pas de dépôt git requis)" \
            -- chezmoi reload
    )
}

test_chezmoi_reload_listed_in_help() {
    local out
    out=$(chezmoi help)
    assert_match "reload" "$out" "chezmoi help mentionne reload"
}

## --- chezmoi modules ---

test_chezmoi_modules_list_shows_all_enabled_by_default() {
    (
        CHEZMOI_MODULES_DISABLED=""
        local out
        out=$(_chezmoi_modules_list)
        assert_match "docker" "$out" "chezmoi modules liste le module docker"
        assert_match "net" "$out" "chezmoi modules liste le module net"
        assert_not_match "désactivé" "$out" "aucun module désactivé par défaut"
    )
}

test_chezmoi_modules_disable_persists_and_shows_in_list() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        CHEZMOI_MODULES_DISABLED=""
        _chezmoi_modules_cmd disable docker >/dev/null
        assert_match "docker" "$CHEZMOI_MODULES_DISABLED" "chezmoi modules disable docker: répercuté sur CHEZMOI_MODULES_DISABLED"
        local out
        out=$(_chezmoi_modules_list)
        assert_match "docker \(désactivé\)" "$out" "chezmoi modules: docker marqué désactivé dans la liste"
    )
}

test_chezmoi_modules_enable_removes_from_disabled() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        CHEZMOI_MODULES_DISABLED=""
        _chezmoi_modules_cmd disable docker >/dev/null
        _chezmoi_modules_cmd enable docker >/dev/null
        assert_not_match "docker" "$CHEZMOI_MODULES_DISABLED" "chezmoi modules enable docker: retiré de CHEZMOI_MODULES_DISABLED"
    )
}

test_chezmoi_modules_disable_refuses_config() {
    (
        CHEZMOI_CONFIG_DIR=$(mktemp -d)
        CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/config"
        assert_failure "chezmoi modules disable config est refusé" -- _chezmoi_modules_cmd disable config
    )
}

test_chezmoi_modules_disable_refuses_unknown_module() {
    assert_failure "chezmoi modules disable <module inconnu> échoue" -- _chezmoi_modules_cmd disable bogus
}

test_chezmoi_modules_disable_without_name_fails() {
    assert_failure "chezmoi modules disable sans nom échoue" -- _chezmoi_modules_cmd disable
}

test_chezmoi_modules_unknown_subcommand_fails() {
    assert_failure "chezmoi modules <sous-commande inconnue> échoue" -- _chezmoi_modules_cmd bogus
}

test_chezmoi_modules_listed_in_help() {
    local out
    out=$(chezmoi help)
    assert_match "modules" "$out" "chezmoi help mentionne modules"
}

test_chezmoi_barrel_skips_disabled_module() {
    (
        ## Le module désactivé doit venir du fichier de config réel : CHEZMOI_MODULES_DISABLED
        ## posé ici serait de toute façon écrasé par _chezmoi_config_load_all (fin de config.sh,
        ## sourcé avant que la boucle du barrel n'atteigne "docker") lors du re-source ci-dessous.
        ## docker.sh est déjà sourcé au niveau global par test_docker.sh (comme tous les
        ## test_*.sh, chargés une fois par run.sh) : "dps" existe donc déjà comme alias hérité
        ## du process parent avant même ce sous-shell. On le retire explicitement ici (effet
        ## local au sous-shell, sans impact sur le reste de la suite) pour repartir d'un état
        ## propre et vérifier que le re-source du barrel ne le redéfinit pas.
        unalias dps 2>/dev/null
        local xdg
        xdg=$(mktemp -d)
        mkdir -p "$xdg/chezmoi"
        printf 'modules.disabled=docker\n' > "$xdg/chezmoi/config"
        export XDG_CONFIG_HOME="$xdg"
        source "$_test_repo_dir/chezmoi.sh"
        assert_failure "module docker désactivé -> son alias dps n'est pas défini" -- alias dps
    )
}

## --- chezmoi bench ---

test_chezmoi_bench_runs_and_reports_total() {
    (
        local out
        out=$(chezmoi bench)
        assert_match "chezmoi bench" "$out" "chezmoi bench affiche son titre"
        assert_match "total:" "$out" "chezmoi bench affiche un total"
        assert_match "config" "$out" "chezmoi bench liste le module config"
    )
}

test_chezmoi_bench_skips_disabled_module() {
    (
        ## "chezmoi bench" (re)source aussi config.sh dans son sous-shell dédié : la valeur de
        ## CHEZMOI_MODULES_DISABLED doit donc venir du fichier de config réel, sans quoi
        ## _chezmoi_config_load_all l'écraserait avec la valeur par défaut (vide) avant que la
        ## boucle de bench n'atteigne "docker" (même piège que pour le barrel, cf. test ci-dessus).
        local xdg
        xdg=$(mktemp -d)
        mkdir -p "$xdg/chezmoi"
        printf 'modules.disabled=docker\n' > "$xdg/chezmoi/config"
        export XDG_CONFIG_HOME="$xdg"
        local out
        out=$(chezmoi bench)
        assert_match "docker.*désactivé" "$out" "chezmoi bench signale docker comme désactivé, sauté"
    )
}

test_chezmoi_bench_listed_in_help() {
    local out
    out=$(chezmoi help)
    assert_match "bench" "$out" "chezmoi help mentionne bench"
}
