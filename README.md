# chezmoi

Personal bash config, modular. Barrel file `chezmoi.sh` sources modules, checks for updates, self-updates via git.

Built with zero-install constraint in mind: no ability to install packages (no sudo / no admin rights) on target machines. Pure bash + core POSIX utils (`awk`, `sed`, `grep`, `curl`, `git`) only — no external deps, no package managers, no compiled binaries. Everything works by just cloning and sourcing.

## Modules

- **z.sh** — mini `z` jump command. Tracks visited dirs (`~/.zdirs`), ranks by frequency, `z <pattern>` cd to best match. Tab-completion included.
- **prompt.sh** — powerlevel10k-style PS1, no nerd fonts. Shows time, user@host, cwd, git branch + dirty marker, package version (`package.json`/`composer.json`).
- **git-aliases.sh** — short git aliases (`ga`, `gc`, `gp`, `gco`, `gcb`, `glog`, `gs`, `grh`, `gcp`, etc).
- **gtag.sh** — `gtag` command: create/push semver git tags. Supports `major|minor|patch`, `--rc`, `--dev`, `--prefix=`, `--force`. No args shows tag tree (prod/rc/dev).
- **chezmoi.sh** — barrel: sources all modules, daily update check against GitHub, `chezmoi update|version|help` commands.

## Install

Clone anywhere, source barrel file in your `~/.bashrc`:

```bash
source /path/to/chezmoi.sh
```

## Usage

```bash
chezmoi version   # show installed version
chezmoi update    # git pull origin main, reload
chezmoi help       # usage

z <pattern>        # jump to frequent dir matching pattern
gtag patch --rc     # tag+push new release candidate
```

## Requirements

bash, git, curl (for update check).

## Version

See `VERSION` file. Current: 1.0.0
