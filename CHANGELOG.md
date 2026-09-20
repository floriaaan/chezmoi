# Changelog

## 1.10.0
- feat: `chezmoi.sh` — auto-scan de mise à jour : le premier shell de la journée (throttle 24h) récupère en arrière-plan le `VERSION` de origin/main (timeout 2s, jamais bloquant) et le range dans `~/.cache/chezmoi_remote_version` (seulement si c'est un vrai numéro de version) ; quand elle est strictement plus récente que la locale, le premier prompt de chaque nouveau shell affiche `⬆ vX.Y.Z dispo (chezmoi update)` à la suite de la notice de version, jusqu'à ce que `chezmoi update` rattrape la version. Remplace l'ancien message imprimé de façon asynchrone par la tâche de fond (qui tombait n'importe où, en plein prompt ou commande). Comparaison numérique champ par champ (`1.10.0` > `1.9.2`, ce que l'ancien `!=` ne faisait pas : une version locale plus récente que la distante déclenchait aussi l'alerte). Le résultat d'un fetch est visible dès le shell suivant. `CHEZMOI_NO_UPDATE_CHECK=1` désactive fetch et notice ; jamais en session distante

## 1.9.2
- fix: `prompt.sh`/`prompt.zsh`/`completion.sh` — sous WSL sans intégration Docker Desktop, `/usr/bin/docker` est un stub qui affiche « The command 'docker' could not be found in this WSL distro... » : `command -v docker` le trouve, donc ce message finissait dans le segment `docker` du prompt (sortie de `docker context show` prise pour un nom de contexte) et le hookup de complétion l'évaluait comme un script. Les codes retour de `docker context show`/`docker completion`/`task --completion` sont désormais vérifiés, et un « contexte » contenant un espace (jamais un vrai nom) est ignoré : stub WSL = comme docker absent

## 1.9.1
- fix: `completion.sh` — sous bash, `task <TAB>`/`docker <TAB>` affichaient `bash: _init_completion : commande introuvable` à chaque TAB : les scripts de complétion générés par ces binaires s'appuient sur `_init_completion`, fourni par le paquet bash-completion, absent par défaut sur macOS. `_completion_bash_completion_satisfied` source bash-completion à la demande (chemins connus) quand le script généré en a besoin ; introuvable, le script n'est pas évalué du tout et le stub se retire (`complete -r` + code de retour 124, « réessaie la complétion » côté bash) : complétion par défaut plutôt qu'une complétion qui hurle
- feat: `chezmoi.sh`/`prompt.sh`/`prompt.zsh` — la bannière `chezmoi vX.Y.Z chargé` n'est plus imprimée au chargement : la version est injectée **dans le premier prompt** de la session, en bout de ligne d'infos (`... ⚡80% chezmoi v1.9.1`), puis consommée — les prompts suivants sont inchangés. `chezmoi.sh` pose `_CHEZMOI_PROMPT_NOTICE` (échappements `\[...\]` sous bash, `%F{}` sous zsh), `_chezmoi_prompt_inject_notice` la colle en fin d'avant-dernière ligne du prompt (sur sa propre ligne au-dessus pour les thèmes mono-ligne `default`/`minimal`). Plus aucune ligne volée au scrollback, et plus rien dans les shells non interactifs (scripts, `ssh <commande>`), où la bannière polluait la sortie ; `CHEZMOI_NO_BANNER=1` la supprime toujours
- fix: `completion.sh` — sous zsh, les alias git (`gco`, `gd`, `gs`...) ne proposaient plus rien du tout (`<TAB>` = bip) : le hookup bash dépend de `git-completion.bash`, absent par défaut sur macOS, et le stub paresseux enregistré au démarrage restait alors en place pour toute la session, volant jusqu'à la complétion par défaut de ces alias. Sous zsh, les alias passent désormais par la complétion native compsys (`compdef _git gco=git-checkout`) : aucune dépendance à `git-completion.bash` ni à bashcompinit, et coût nul au démarrage (`_git` reste autoload)
- fix: `completion.sh` — sous bash, le stub paresseux d'un alias git n'est plus enregistré si aucun `git-completion.bash` n'est trouvable aux chemins connus (le hookup ne pourrait jamais aboutir) ; et si un hookup réel échoue malgré tout au premier `<TAB>`, le stub se désenregistre (`complete -r`) au lieu de bloquer tous les `<TAB>` suivants sur cette commande
- fix: `completion.sh` — sous zsh, les stubs `task`/`docker` n'écrasent plus une complétion compsys native déjà en place (`_docker` de Homebrew par exemple), qui est meilleure et déjà paresseuse
- fix: `completion.sh` — la table alias → sous-commande git n'est plus dupliquée en dur (19 lignes qui pouvaient diverger) : elle est dérivée de `git-aliases.sh`, seule source de vérité ; un alias ajouté là-bas est hooké sans toucher `completion.sh`
- feat: `completion.sh` — `chezmoi config set <clé> <TAB>` propose les valeurs de `prompt.segments`, `ssh.modules` et `modules.disabled` (auparavant `prompt.theme` uniquement), et accepte les positions suivantes pour ces clés multi-valeurs
- fix: `completion.sh` — `floriaaan` manquait dans la liste de secours des thèmes de `chezmoi config set prompt.theme <TAB>` (utilisée quand `config.sh` n'est pas chargé)
- fix: `test/test_history.sh` — le test « pas de double hook » comparait la sortie de `wc -l`, paddée d'espaces sous macOS/BSD : `grep -c` à la place

## 1.9.0
- feat: `docker.sh` — nouveau module, alias docker/docker-compose (`dps`, `dpsa`, `dimg`, `dex`, `dlog`, `dstop`, `drm`, `drmi`, `dprune`, `dcu`, `dcd`, `dcb`, `dcl`, `dcps`), inertes si `docker` absent (même logique que `git-aliases.sh` vis-à-vis de `git`)
- feat: `net.sh` — nouveau module : `myip` (IP publique, plusieurs fournisseurs en repli : icanhazip/ifconfig.me/ipify), `localip` (IP locale de sortie, `ip route`/`ifconfig`/`ipconfig`), `weather [ville]` (une ligne via wttr.in) ; timeout court partout, jamais bloquant
- feat: `prompt.sh`/`prompt.zsh` — deux nouveaux segments : `docker` (contexte docker actif via `docker context show`, mis en cache comme le segment git, masqué si absent/`"default"`) et `battery` (charge batterie, Linux `/sys/class/power_supply`/macOS `pmset -g batt`, masqué si pas de batterie, icône éclair en charge)
- feat: `completion.sh` — complétion docker : `eval "$(docker completion bash|zsh)"` si le binaire `docker` est présent (même principe que go-task)
- feat: `completion.sh` — les hookups task/docker/alias-git (fork+exec du binaire, ou source de `git-completion.bash`) sont désormais **chargés paresseusement** : un stub léger est enregistré au démarrage, le vrai chargement n'a lieu qu'au premier `<TAB>` réel sur la commande concernée (qui redispatche aussitôt vers la vraie complétion, pas besoin d'appuyer deux fois) ; `CHEZMOI_NO_LAZY_COMPLETION=1` revient au chargement eager d'avant
- feat: `config.sh` — `chezmoi config edit` : ouvre le fichier de config brut dans `$EDITOR` (repli `vi`), recharge toutes les clés au retour
- feat: `chezmoi.sh` — `chezmoi modules [list|disable <module>|enable <module>]` : active/désactive un module du barrel sans éditer `chezmoi.sh` (façon apt/brew), persisté via la nouvelle clé de config `modules.disabled` ; `config` n'est jamais désactivable (il porte cette clé lui-même)
- feat: `chezmoi.sh` — `chezmoi bench` : mesure le temps de chargement (source) de chaque module du barrel, dans l'ordre réel de chargement, dans un sous-shell dédié (ne pollue jamais la session courante)
- feat: `chezmoi.sh` — barrel étendu avec `docker`/`net` (entre `ssh` et `completion`)
- feat: `chezmoi.sh` — `chezmoi themes [<thème>|unset]` et `chezmoi prompt [<segment>...|unset]` : raccourcis en lecture/écriture pour `prompt.theme`/`prompt.segments`, délégués entièrement à `config.sh` (mêmes garde-fous, même persistance) — `chezmoi themes minimal` et `chezmoi config set prompt.theme minimal` sont deux chemins équivalents vers le même état, dans les deux sens ; `chezmoi modules disable/enable` était déjà l'équivalent de `chezmoi config set modules.disabled "<liste>"`, documenté et croisé dans `chezmoi modules help`

## 1.8.0
- feat: `completion.sh` — complétion go-task : `eval "$(task --completion bash|zsh)"` si le binaire `task` est présent sur la machine (aucune install forcée), pour bénéficier de la complétion officielle de Taskfile
- feat: `completion.sh` — hookup `__git_complete` étendu à tous les alias de `git-aliases.sh` (`ga`, `gaa`, `gc`, `gca`, `gp`, `gpf`, `gl`, `gco`, `gcb`, `gb`, `gd`, `gds`, `glog`, `gs`, `gsp`, `grh`, `gcp`, `gm`, `grb`), auparavant limité à `gco`/`gcb`/`gb`/`gm`/`grb` : chaque alias récupère la complétion de la sous-commande git qu'il enveloppe (ex: `gco sta<TAB>` → `gco staging`, comme `git checkout sta<TAB>`)
- fix: `completion.sh` — `__git_complete`/`_git_xxx` sont souvent chargés paresseusement par bash-completion (au premier `git <TAB>` de la session) : absents si ce module est sourcé au démarrage du shell, avant tout TAB, ce qui empêchait silencieusement le hookup d'alias git de se faire pour toute la session (`gco sta<TAB>` restait une simple complétion de fichiers). `_completion_source_git_completion_bash` cherche et source directement `git-completion.bash` (chemins connus bash-completion v2/homebrew/`~/.git-completion.bash`) si `__git_complete` n'est pas encore défini
- feat: `chezmoi.sh` — nouvelle commande `chezmoi reload` : re-source les fichiers depuis le disque (comme `chezmoi update` après un pull) mais sans git pull, pour relire une modification locale ou récupérer un module qui vient de charger `__git_complete` en retard. Fonctionne aussi en session distante (`CHEZMOI_REMOTE=1`), contrairement à `update`
- refactor: `completion.sh` — les deux hookups (go-task, alias git) sont extraits en fonctions (`_completion_hookup_task`, `_completion_hookup_git_aliases`) pour rester testables individuellement, comportement au chargement inchangé
- fix: `chezmoi.sh` — `CHEZMOI_VERSION` était un littéral dupliqué du fichier `VERSION` (désynchronisé depuis 1.7.0/1.7.1, `chezmoi version` affichait un numéro périmé) ; lu désormais depuis `VERSION` au chargement, `VERSION` devient l'unique source de vérité

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
