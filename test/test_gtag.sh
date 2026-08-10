## --- Tests: gtag.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/gtag.sh"

test_gtag_requires_git_repo() {
    (
        cd "$(mktemp -d)" || exit 1
        assert_failure "gtag hors dépôt git échoue" -- gtag patch --dry-run
    )
}

test_gtag_dry_run_first_patch() {
    (
        local tmp
        tmp=$(mktemp -d)
        cd "$tmp" || exit 1
        git init -q
        git config user.email "test@test.local"
        git config user.name "test"
        git commit -q --allow-empty -m "init"
        local out
        out=$(gtag patch --dry-run)
        assert_match "0\.0\.1" "$out" "premier tag patch = 0.0.1 en dry-run"
    )
}

test_gtag_unknown_option_fails() {
    (
        cd "$(mktemp -d)" || exit 1
        git init -q
        assert_failure "option inconnue échoue" -- gtag --bogus
    )
}

test_gtag_list_no_tags() {
    (
        cd "$(mktemp -d)" || exit 1
        git init -q
        local out
        out=$(gtag list)
        assert_match "aucun tag" "$out" "gtag list sans tags affiche message vide"
    )
}

test_gtag_confirm_empty_answer_defaults_yes() {
    local rc
    printf '\n' | _gtag_confirm "test" >/dev/null
    rc=$?
    assert_eq "0" "$rc" "_gtag_confirm: réponse vide = oui (défaut Y)"
}

test_gtag_confirm_explicit_no_rejects() {
    local rc
    printf 'n\n' | _gtag_confirm "test" >/dev/null
    rc=$?
    assert_eq "1" "$rc" "_gtag_confirm: réponse 'n' explicite refuse"
}

test_gtag_rc_checks_staging_not_main() {
    (
        local tmp
        tmp=$(mktemp -d)
        cd "$tmp" || exit 1
        git init -q
        git config user.email "test@test.local"
        git config user.name "test"
        git commit -q --allow-empty -m "init"
        local out
        out=$(printf 'n\n' | gtag patch --rc 2>&1)
        assert_match "pas staging" "$out" "gtag --rc hors branche 'staging' avertit"
    )
}

test_gtag_no_rc_checks_main_not_staging() {
    (
        local tmp
        tmp=$(mktemp -d)
        cd "$tmp" || exit 1
        git init -q
        git config user.email "test@test.local"
        git config user.name "test"
        git commit -q --allow-empty -m "init"
        git checkout -q -b staging
        local out
        out=$(printf 'n\n' | gtag patch 2>&1)
        assert_match "pas main/master" "$out" "gtag sans --rc sur 'staging' avertit (pas main/master)"
    )
}

test_gtag_rc_on_staging_no_warning() {
    (
        local tmp
        tmp=$(mktemp -d)
        cd "$tmp" || exit 1
        git init -q
        git config user.email "test@test.local"
        git config user.name "test"
        git commit -q --allow-empty -m "init"
        git checkout -q -b staging
        local out
        out=$(printf 'n\n' | gtag patch --rc 2>&1)
        assert_not_match "pas staging" "$out" "gtag --rc sur 'staging' ne prévient pas"
    )
}
