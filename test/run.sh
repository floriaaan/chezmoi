#!/usr/bin/env bash
## --- Discovery + exécution des tests, bash + zsh ---

_test_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export CHEZMOI_NO_BANNER=1
export CHEZMOI_NO_UPDATE_CHECK=1
export CHEZMOI_NO_ZSH_PLUGINS=1

source "$_test_dir/harness.sh"

## --- Même compat "complete" que le barrel (nécessaire pour test_completion.sh sous zsh) ---
if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz compinit && compinit -u
    autoload -Uz bashcompinit && bashcompinit
fi

for _tf in "$_test_dir"/test_*.sh; do
    [ -f "$_tf" ] && source "$_tf"
done
unset _tf

if [ -n "$ZSH_VERSION" ]; then
    # shellcheck disable=SC2296,SC2206  # syntaxe zsh (${(k)functions[...]}), branche zsh-only
    _test_fns=(${(k)functions[(I)test_*]})
else
    _test_fns=($(compgen -A function test_))
fi

for _fn in "${_test_fns[@]}"; do
    run_test "$_fn"
done
unset _fn

_test_report_summary
exit $?
