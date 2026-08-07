# Changelog

## 1.4.0
- feat: `history.sh` — historique partagé/dédupliqué/timestampé, écriture immédiate (synchro temps réel entre terminaux), recherche par préfixe sur ↑/↓ (bash + zsh, deux variantes de séquence de touches)
- feat: `ports.sh` — `ports [PORT|PATTERN]` (via `ss`, fallback `netstat`), `kport <PORT> [--force]` avec confirmation et garde-fous (refuse PID 1 / process d'un autre utilisateur)
- feat: `extract.sh` — `extract`/`compress` multi-formats (tar.gz/bz2/xz/zst, zip, 7z, rar, gz/bz2/xz seuls), protection anti-tarbomb
- feat: `ssh.sh` — wrapper `ssh` qui embarque `prompt`/`git-aliases`/`gtag` sur l'hôte distant sans écriture disque (config base64 embarquée en littéral dans la commande distante — pas de variable d'env, donc pas de dépendance à `AcceptEnv`/`SetEnv`), fallback silencieux vers `ssh` natif si l'injection échoue, résultat mis en cache par hôte (`_SSH_CHEZMOI_CACHE_TTL`) pour ne pas re-tenter à chaque connexion ; `ssh-chezmoi-test` pour diagnostiquer (et rafraîchir le cache)
- feat: prompt — troncature intelligente du chemin (`_PROMPT_PATH_MAXLEN`, coupe sur segments entiers, garde au moins 2 segments) ; repère `[ssh]` orange en session distante
- feat: `chezmoi doctor` — checklist des dépendances (`ss`/`netstat`, `tar`/`unzip`, `7z`/`unrar` en optionnel) et des modules chargés
- feat: `CHEZMOI_REMOTE` — désactive le check de version/écriture de cache et `chezmoi update` en session distante injectée
- fix: `_gtag_confirm`/`_ports_confirm`/`_extract_confirm` — `read -rp` échoue sous zsh (`no coprocess`) ; remplacé par `printf` + `read -r` séparés
- fix: `ssh.sh` — la config était `eval`ée dans le shell courant puis un `exec <shell> -i` la remplaçait, ce qui perd tout ce que l'eval venait de poser (`PROMPT_COMMAND`, fonctions) car `exec` ne conserve que les variables exportées ; bannière affichée, prompt resté celui de l'hôte. Fix : le shell interactif final lit désormais lui-même la config, comme rcfile (`bash --rcfile <(...)`, isolé dans un `bash -c` explicite pour rester sûr même si le shell qui exécute la commande côté sshd est `sh`/`dash` ; `ZDOTDIR` éphémère auto-supprimé pour zsh)
- fix: `test/harness.sh` — les assertions dans un test isolé en sous-shell `( ... )` n'incrémentaient jamais les compteurs pass/fail du parent (le résumé pouvait rapporter "0 failed" avec de vrais échecs à l'intérieur) ; tally sur fichier disque, qui traverse fork()

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
