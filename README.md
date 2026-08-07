# chezmoi

Personal shell config, modular. Barrel file `chezmoi.sh` sources modules, checks for updates, self-updates via git. Works under bash and zsh.

Built with zero-install constraint in mind: no ability to install packages (no sudo / no admin rights) on target machines. Pure bash/zsh + core POSIX utils (`awk`, `sed`, `grep`, `curl`, `git`) only — no external deps, no package managers, no compiled binaries. Everything works by just cloning and sourcing.

## Modules

Ordre de chargement (barrel `chezmoi.sh`) : `history → z → git-aliases → gtag → ports → extract → ssh → completion → colors → prompt(.sh|.zsh)`.

- **history.sh** — historique partagé, dédupliqué (`erasedups`/`HIST_IGNORE_ALL_DUPS`), avec timestamps, écrit immédiatement (synchro temps réel entre terminaux). Ignore les commandes préfixées d'un espace et les commandes triviales (`ls`, `cd`, `pwd`, `exit`, `clear`, `history`). Recherche par préfixe sur ↑/↓ (bindings `\e[A`/`\eOA` etc, les deux variantes de séquence selon le mode du terminal).
- **z.sh** — mini `z` jump command. Tracks visited dirs (`~/.zdirs`), ranks by frequency, `z <pattern>` cd to best match. Tab-completion included (bash + zsh via `bashcompinit`).
- **prompt.sh** — powerlevel10k-style PS1 for bash, no nerd fonts. Shows time, user@host, cwd (troncature intelligente sur segments entiers, `_PROMPT_PATH_MAXLEN=60`), git branch + dirty marker, package version (`package.json`/`composer.json`). Repère `[ssh]` orange en session distante.
- **prompt.zsh** — same prompt, zsh flavor (`precmd` + `PROMPT_SUBST`).
- **git-aliases.sh** — short git aliases (`ga`, `gc`, `gp`, `gco`, `gcb`, `glog`, `gs`, `grh`, `gcp`, `gm`, `grb`, etc).
- **gtag.sh** — `gtag` command: create/push semver git tags. Supports `major|minor|patch`, `--rc`, `--dev`, `--prefix=`, `--force`. No args shows tag tree (prod/rc/dev).
- **ports.sh** — `ports [PORT|PATTERN]` liste les sockets en écoute (TCP+UDP), via `ss` (fallback `netstat`). `kport <PORT> [--force]` tue le process associé, avec confirmation (refuse PID 1 et les process d'un autre utilisateur, sauf root).
- **extract.sh** — `extract <archive> [dest]` décompresse selon l'extension (`.tar.gz`, `.tgz`, `.tar.bz2`, `.tar.xz`, `.tar.zst`, `.tar`, `.gz`, `.bz2`, `.xz`, `.zip`, `.7z`, `.rar`), avec protection anti-tarbomb (propose un dossier dédié si l'archive a plusieurs entrées racine). `compress <dest.ext> <fichiers...>` fait l'inverse.
- **ssh.sh** — wrapper `ssh` qui embarque `prompt`/`git-aliases`/`gtag` sur l'hôte distant sans rien y écrire (config base64 embarquée en littéral dans la commande distante exécutée par ssh — pas de variable d'env, donc aucune dépendance à `AcceptEnv`/`SetEnv` côté serveur, ni à un client OpenSSH récent). Fallback automatique et silencieux vers une session `ssh` normale si l'injection échoue pour n'importe quelle raison (charge trop grosse, `base64` absent côté distant, commande forcée par le serveur, etc). Résultat mis en cache par hôte (`~/.cache/chezmoi_ssh_hosts`, `_SSH_CHEZMOI_CACHE_TTL=86400`) pour ne pas retenter/avertir à chaque connexion vers un hôte déjà connu incompatible. `command ssh`/`ssh-raw` pour contourner. `ssh-chezmoi-test <host>` diagnostique la config sans ouvrir de session (et rafraîchit le cache).
- **completion.sh** — tab-completion for `gtag`/`chezmoi` subcommands + hooks git's own completion (if present on the machine) onto `gco`/`gcb`/`gb`/`gm`/`grb`.
- **colors.sh** — `LS_COLORS`/`GREP_COLORS` + colored `ls`/`grep`/`diff` aliases (GNU/BSD auto-detected). Also auto-sources `zsh-syntax-highlighting`/`zsh-autosuggestions` under zsh if already installed on the machine (no install forced; opt out with `CHEZMOI_NO_ZSH_PLUGINS=1`).
- **chezmoi.sh** — barrel: detects bash/zsh, sources common modules + right prompt file, daily update check against GitHub, `chezmoi update|version|doctor|help` commands. `CHEZMOI_REMOTE=1` (posé par `ssh.sh` côté distant) désactive le check de version et l'écriture de cache.

## Install

Clone anywhere, source barrel file in your `~/.bashrc` or `~/.zshrc`:

```bash
source /path/to/chezmoi.sh
```

## Usage

```bash
chezmoi version   # show installed version
chezmoi update    # git pull origin main, reload
chezmoi doctor    # check dependencies/modules
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

See `VERSION` file. Current: 1.4.0
