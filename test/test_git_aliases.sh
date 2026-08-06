## --- Tests: git-aliases.sh ---

_test_repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
source "$_test_repo_dir/git-aliases.sh"

test_git_aliases_defined() {
    assert_match "git add" "$(alias ga)" "ga = git add"
    assert_match "git commit" "$(alias gc)" "gc = git commit"
    assert_match "git merge" "$(alias gm)" "gm = git merge"
    assert_match "git rebase" "$(alias grb)" "grb = git rebase"
    assert_match "git checkout -b" "$(alias gcb)" "gcb = git checkout -b"
}
