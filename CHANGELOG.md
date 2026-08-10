# Changelog

## 1.7.1
- fix: `test/test_prompt.sh`/`test/test_config.sh` — assertions mises à jour après la permutation `default`/`floriaaan` (1.7.0) : le segment heure et la personnalisation via `prompt.segments` sont désormais testés sur `floriaaan`, `default` est testé contre les couleurs ANSI brutes du vrai bash (`01;32`/`01;34`) et son immunité à `prompt.segments`, les aperçus `chezmoi config set prompt.theme` sont réassociés au bon thème
- fix: `test/test_chezmoi.sh`/`test/test_config.sh` — sourçaient le barrel/`config.sh` réel sans isoler `XDG_CONFIG_HOME`, donc `_chezmoi_config_load_all` lisait le vrai `~/.config/chezmoi/config` de la machine au chargement des tests et répercutait son contenu (`prompt.theme`/`prompt.segments`) dans des variables globales hors sous-shell, polluant tous les tests de `prompt.sh`/`prompt.zsh` sourcés ensuite dans le même process (2 tests en faux échec selon le contenu du fichier local). `XDG_CONFIG_HOME` est désormais détourné vers un répertoire temporaire le temps du `source`

## 1.7.0
- feat: `prompt.sh`/`prompt.zsh` — nouveau thème `default` : reproduit à l'identique le PS1 par défaut de bash (squelette Debian `/etc/skel/.bashrc`), couleurs ANSI brutes (`01;32` vert vif, `01;34` bleu vif) au lieu de la palette 256 adoucie des autres thèmes, une seule ligne, aucun segment (`prompt.segments` sans effet sur ce thème, fidélité à l'original)
- refactor: l'ancien thème `default` (2 lignes façon powerlevel10k, segments `time user dir git pkg duration`) est renommé `floriaaan` ; `minimal` et `agnoster` inchangés
- feat: `config.sh` — `chezmoi config set prompt.theme` liste et prévisualise désormais les quatre thèmes (`default`/`minimal`/`agnoster`/`floriaaan`)

## 1.6.0
- feat: `prompt.sh`/`prompt.zsh` — nouvelle clé `prompt.segments` (`chezmoi config set prompt.segments "<liste>"`) : liste ordonnée/espacée des segments affichés par le prompt, applicable aux trois thèmes (`default`/`minimal`/`agnoster`), en plus ou à la place de leur liste par défaut (`time user dir git pkg duration` / `dir git` / `user dir git exitcode`) ; nom de segment inconnu ignoré silencieusement (même fallback que pour un thème inconnu)
- feat: `prompt.sh`/`prompt.zsh` — deux nouveaux segments : `node` (version node active via `node -v`, affiché seulement si `node` est dispo et le répertoire courant contient `package.json`/`.nvmrc`) et `exitcode` (code de sortie de la commande précédente si non nul, généralisé depuis le thème `agnoster` vers les trois thèmes)
- feat: `config.sh` — `chezmoi config set prompt.segments` sans valeur liste le catalogue des segments valides (`time user dir git pkg node duration exitcode`) et la valeur actuelle, au lieu d'échouer avec l'usage générique (clé à valeur libre, mais bénéficie du même confort que `prompt.theme`)
- feat: `ssh.sh` — `prompt.segments` est désormais propagé à l'hôte distant (imposé en littéral dans la charge utile, comme `prompt.theme`), whitelisté par nom de segment reconnu (`_ssh_prompt_segments_sanitize`) plutôt qu'échappé, pour rester sûr même si la valeur configurée contient un guillemet ou un métacaractère shell
- refactor: `prompt.sh`/`prompt.zsh` — les segments (`time`/`user`/`dir`/`pkg`/`duration`/...) qui n'étaient auparavant rendus que par le thème `default` (et son homologue `agnoster` en bloc de couleur) sont désormais des fonctions communes aux trois thèmes, pour pouvoir être sélectionnés par n'importe quel thème via `prompt.segments`

## 1.5.0
- feat: `config.sh` — `chezmoi config` (get/set/unset/list) : préférences persistantes (`~/.config/chezmoi/config`, ou `$XDG_CONFIG_HOME/chezmoi/config`) pour le thème du prompt (`prompt.theme`) et les modules embarqués par le wrapper ssh (`ssh.modules`, appliqué immédiatement à `_SSH_CHEZMOI_MODULES`, sans relancer le shell) ; sourcé en premier dans le barrel pour que `ssh.sh`/`prompt.sh`/`prompt.zsh` lisent la valeur dès le démarrage
- feat: `chezmoi config set <clé>` sans valeur liste les choix possibles pour une clé à choix fermé (`prompt.theme` : `default`/`minimal`/`agnoster`, avec le choix actif marqué et un aperçu coloré du rendu de chaque thème) au lieu d'échouer avec un simple message d'usage ; inchangé pour une clé à valeur libre (`ssh.modules`)
- feat: `prompt.sh`/`prompt.zsh` — second thème `minimal` (une ligne : chemin + git compact, sans heure/host/version de paquet/durée), sélectionnable via `chezmoi config set prompt.theme minimal`, appliqué immédiatement (pas besoin de relancer le shell)
- feat: `prompt.sh`/`prompt.zsh` — troisième thème `agnoster`, équivalent du thème oh-my-zsh du même nom sans police powerline/nerd font (blocs de couleur pleine — contexte `user@host` si ssh/root, chemin, git, code de sortie si la commande précédente a échoué — chacun terminé par un `▶` dans sa propre couleur au lieu de la flèche  qui nécessite une police patchée)
- feat: `ssh.sh` — `_ssh_build_payload` n'embarque plus, pour le module `prompt`, que le code du thème réellement sélectionné (délimité par des marqueurs `## chezmoi:theme-begin/end <nom>` dans `prompt.sh`/`prompt.zsh`) ; le thème est imposé en littéral dans la charge utile (l'hôte distant n'a pas accès à `chezmoi config`), ce qui allège la charge utile au lieu d'embarquer systématiquement le rendu de tous les thèmes
- fix: `gtag` — la confirmation par défaut (`_gtag_confirm`) passe de `[y/N]` (refus par défaut) à `[Y/n]` (Entrée seule = oui, seul un `n` explicite annule)
- fix: `gtag` — le garde-fou de branche vérifiait toujours `main`/`master`, y compris avec `--rc` (recette). Désormais `--rc` vérifie la branche `staging` ; le contrôle `main`/`master` ne s'applique que sans `--rc`
- fix: `ssh.sh` — `_ssh_build_payload` validait la présence d'une apostrophe dans `prompt.theme` mais pas son appartenance à un thème connu ; un thème arbitraire (ex: faute de frappe dans `chezmoi config set`) faisait sauter TOUS les blocs `## chezmoi:theme-*` du filtrage (aucun ne matchait), laissant le dispatcheur distant appeler une fonction de rendu absente. Le thème est maintenant validé contre le registre de `config.sh` avant filtrage, avec repli sur `default`

## 1.4.1
- fix: `prompt.sh`/`z.sh` — `PROMPT_COMMAND` prepend was unconditional (no dedupe guard, unlike `history.sh`) ; un re-source de `chezmoi.sh` (ex: `chezmoi update`) dupliquait `_build_ps1`/`_z_add` et laissait un `;` orphelin, cassant `PROMPT_COMMAND` (`syntax error near unexpected token ';;'`). Fix : même garde idempotente que `history.sh` sur les deux fichiers.

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
