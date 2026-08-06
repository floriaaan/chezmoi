# Changelog

## 1.3.0
- feat: `completion.sh` — tab-completion for `gtag`/`chezmoi`, git completion hookup on `gco`/`gcb`/`gb`/`gm`/`grb`
- feat: `colors.sh` — `LS_COLORS`/`GREP_COLORS`, colored `ls`/`grep`/`diff` (GNU/BSD detected), auto-source zsh-syntax-highlighting/zsh-autosuggestions if present (`CHEZMOI_NO_ZSH_PLUGINS=1` to opt out)
- feat: CI (GitHub Actions) — shellcheck lint + test suite on bash and zsh
- feat: zero-dependency test harness in `test/`
- fix: `VERSION` file and `CHEZMOI_VERSION` re-synced (were drifted: 1.2.3 vs 1.2.4)
- chore: `.gitignore` added

## 1.2.4
- feat: add `gm` (git merge) and `grb` (git rebase) aliases

## 1.2.3
- fix: emulate `-L` bash in gtag helper functions for zsh compat

## 1.2.2
- feat: git ahead/behind + cmd duration in prompt
- feat: gtag list/dry-run/branch-guard
- feat: z frecency + purge stale dirs

## 1.1.0 (deaf6cc → 88f9746)
- fix: use `%F`/`%f` zsh color syntax, unalias `z` to avoid conflicts
- feat: add zsh support

## 1.0.0 (initial)
- feat: initial commit, modular bash config (z, prompt, git-aliases, gtag, chezmoi barrel)
