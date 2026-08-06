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
