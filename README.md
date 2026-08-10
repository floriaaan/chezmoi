# chezmoi

Personal shell config, modular. Barrel file `chezmoi.sh` sources modules, checks for updates, self-updates via git. Works under bash and zsh.

Built with zero-install constraint in mind: no ability to install packages (no sudo / no admin rights) on target machines. Pure bash/zsh + core POSIX utils (`awk`, `sed`, `grep`, `curl`, `git`) only — no external deps, no package managers, no compiled binaries. Everything works by just cloning and sourcing.

## Modules

Ordre de chargement (barrel `chezmoi.sh`) : `config → history → z → git-aliases → gtag → ports → extract → ssh → completion → colors → prompt(.sh|.zsh)`.

- **config.sh** — `chezmoi config` : préférences persistantes (`~/.config/chezmoi/config`, ou `$XDG_CONFIG_HOME/chezmoi/config`). Sourcé en premier pour que `ssh.sh`/`prompt.sh`/`prompt.zsh` lisent la valeur dès le démarrage. Clés connues : `prompt.theme` (`default`/`minimal`/`agnoster`, cf. `prompt.sh`), `prompt.segments` (liste ordonnée/espacée des segments affichés, ex: `"time dir git node"`, appliquée quel que soit le thème actif — vide = liste par défaut du thème), `ssh.modules` (modules embarqués par le wrapper ssh, défaut `"prompt git-aliases gtag"`). `chezmoi config set` persiste et applique tout de suite (pas besoin de relancer le shell) ; `chezmoi config set <clé>` sans valeur liste les choix possibles pour une clé à choix fermé (le choix actif est marqué) au lieu d'échouer — pour `prompt.theme`, chaque choix est accompagné d'un aperçu coloré de son rendu ; pour `prompt.segments`, le catalogue de segments valides est listé.
- **history.sh** — historique partagé, dédupliqué (`erasedups`/`HIST_IGNORE_ALL_DUPS`), avec timestamps, écrit immédiatement (synchro temps réel entre terminaux). Ignore les commandes préfixées d'un espace et les commandes triviales (`ls`, `cd`, `pwd`, `exit`, `clear`, `history`). Recherche par préfixe sur ↑/↓ (bindings `\e[A`/`\eOA` etc, les deux variantes de séquence selon le mode du terminal).
- **z.sh** — mini `z` jump command. Tracks visited dirs (`~/.zdirs`), ranks by frequency, `z <pattern>` cd to best match. Tab-completion included (bash + zsh via `bashcompinit`).
- **prompt.sh** — powerlevel10k-style PS1 for bash, no nerd fonts, three themes selectable via `chezmoi config set prompt.theme <default|minimal|agnoster>`: `default` shows segments `time user dir git pkg duration` on two lines ; `minimal` is a single line, `dir git` (compact git) only ; `agnoster` is an oh-my-zsh "agnoster"-equivalent (full-color segment blocks, each closed by a `▶`, no powerline/nerd font needed), segments `user dir git exitcode`. Every theme's segment list is overridable, in any order, via `chezmoi config set prompt.segments "<liste>"` — catalogue : `time`, `user` (user@host, `[ssh]`-prefixed remotely), `dir` (troncature intelligente sur segments entiers, `_PROMPT_PATH_MAXLEN=60`), `git` (branche + dirty + ahead/behind, rendu compact en thème minimal), `pkg` (version `package.json`/`composer.json`), `node` (`node -v`, si projet node détecté), `duration` (>=3s), `exitcode` (code de sortie si échec). Nom de segment inconnu → ignoré silencieusement. Le repère `[ssh]` du thème minimal reste géré à part (pas un segment).
- **prompt.zsh** — same prompt + themes + segments, zsh flavor (`precmd` + `PROMPT_SUBST`).
- **git-aliases.sh** — short git aliases (`ga`, `gc`, `gp`, `gco`, `gcb`, `glog`, `gs`, `grh`, `gcp`, `gm`, `grb`, etc).
- **gtag.sh** — `gtag` command: create/push semver git tags. Supports `major|minor|patch`, `--rc`, `--dev`, `--prefix=`, `--force`. No args shows tag tree (prod/rc/dev). Branch guard: `--rc` expects branch `staging`, everything else (prod, `--dev`) expects `main`/`master` ; confirmations default to yes (`[Y/n]`, Enter = oui).
- **ports.sh** — `ports [PORT|PATTERN]` liste les sockets en écoute (TCP+UDP), via `ss` (fallback `netstat`). `kport <PORT> [--force]` tue le process associé, avec confirmation (refuse PID 1 et les process d'un autre utilisateur, sauf root).
- **extract.sh** — `extract <archive> [dest]` décompresse selon l'extension (`.tar.gz`, `.tgz`, `.tar.bz2`, `.tar.xz`, `.tar.zst`, `.tar`, `.gz`, `.bz2`, `.xz`, `.zip`, `.7z`, `.rar`), avec protection anti-tarbomb (propose un dossier dédié si l'archive a plusieurs entrées racine). `compress <dest.ext> <fichiers...>` fait l'inverse.
- **ssh.sh** — wrapper `ssh` qui embarque `prompt`/`git-aliases`/`gtag` sur l'hôte distant sans rien y écrire (config base64 embarquée en littéral dans la commande distante exécutée par ssh — pas de variable d'env, donc aucune dépendance à `AcceptEnv`/`SetEnv` côté serveur, ni à un client OpenSSH récent). Le module `prompt` n'embarque que le rendu du thème actif (`prompt.theme`, imposé en littéral pour l'hôte distant), pas les autres thèmes — allège la charge utile. Fallback automatique et silencieux vers une session `ssh` normale si l'injection échoue pour n'importe quelle raison (charge trop grosse, `base64` absent côté distant, commande forcée par le serveur, etc). Résultat mis en cache par hôte (`~/.cache/chezmoi_ssh_hosts`, `_SSH_CHEZMOI_CACHE_TTL=86400`) pour ne pas retenter/avertir à chaque connexion vers un hôte déjà connu incompatible. `command ssh`/`ssh-raw` pour contourner. `ssh-chezmoi-test <host>` diagnostique la config sans ouvrir de session (et rafraîchit le cache).
- **completion.sh** — tab-completion for `gtag`/`chezmoi` subcommands; hooks git's own completion (if present on the machine) onto every alias defined in `git-aliases.sh` (`gco sta<TAB>` → `gco staging`, same for `ga`/`gp`/`gd`/`gs`/`glog`/...); sources go-task's own completion (`task --completion bash`/`zsh`) if `task` is present on the machine — no install forced either way.
- **colors.sh** — `LS_COLORS`/`GREP_COLORS` + colored `ls`/`grep`/`diff` aliases (GNU/BSD auto-detected). Also auto-sources `zsh-syntax-highlighting`/`zsh-autosuggestions` under zsh if already installed on the machine (no install forced; opt out with `CHEZMOI_NO_ZSH_PLUGINS=1`).
- **chezmoi.sh** — barrel: detects bash/zsh, sources common modules + right prompt file, daily update check against GitHub, `chezmoi update|reload|version|doctor|config|help` commands. `CHEZMOI_REMOTE=1` (posé par `ssh.sh` côté distant) désactive le check de version et l'écriture de cache.

## Install

Clone anywhere, source barrel file in your `~/.bashrc` or `~/.zshrc`:

```bash
source /path/to/chezmoi.sh
```

## Usage

```bash
chezmoi version   # show installed version
chezmoi update    # git pull origin main, reload
chezmoi reload    # re-source files from disk, no git pull (picks up a local edit)
chezmoi doctor    # check dependencies/modules
chezmoi config                          # list preferences (prompt theme, ssh modules) and current values
chezmoi config set ssh.modules "prompt gtag"   # persisted + applied immediately
chezmoi config set prompt.theme minimal        # switch to the 1-line prompt, persisted + applied on the very next prompt
chezmoi config set prompt.theme                # no value: lists the available themes (active one marked)
chezmoi config set prompt.segments "time dir git node"   # customize which segments show, in any order, on any theme
chezmoi config set prompt.segments             # no value: lists the segment catalogue
chezmoi config unset prompt.segments           # back to the active theme's default segment list
chezmoi help       # usage

z <pattern>        # jump to frequent dir matching pattern
gtag patch --rc     # tag+push new release candidate

ports 3000          # who's listening on port 3000
kport 3000           # kill it (asks for confirmation)

extract foo.tar.gz          # detects format, anti-tarbomb prompt if needed
compress out.tar.gz src/    # inverse

ssh myhost           # prompt/git-aliases/gtag available remotely, nothing written to disk there
ssh-chezmoi-test myhost   # diagnose without opening a session
```

## Requirements

bash or zsh, git, curl (for update check).

## Tests / CI

Zero-dependency test harness in `test/` (no bats, no install needed):

```bash
bash test/run.sh
zsh test/run.sh
```

CI (`.github/workflows/ci.yml`) runs `shellcheck` and the test suite under both shells on every push/PR.

## Version

See `VERSION` file.
