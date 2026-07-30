# dotfiles

macOS config: zsh, git, AeroSpace tiling with a sketchybar status bar, and
Claude Code's global settings.

## Setting up a new machine

The clone has to live at `~/dotfiles`. `.zshrc` puts `~/dotfiles/bin` on PATH and
`claude/settings.json` invokes the fleet scripts by their `dotfiles/claude/...`
path, so a clone anywhere else links cleanly and then fails at runtime.
`bin/install` refuses to run from the wrong place rather than let that happen.

```sh
git clone git@github.com:arwagner/dotfiles.git ~/dotfiles
~/dotfiles/bin/install --dry-run    # see what would change
~/dotfiles/bin/install

brew bundle --file ~/dotfiles/Brewfile
tfenv install && tfenv use <version>
exec zsh
```

Then add `~/dotfiles/raycast` under Raycast > Extensions > Script Commands, and
start AeroSpace, which starts sketchybar in turn.

`bin/install` is rerunnable. It reports `ok` for anything already linked, so
running it after a `git pull` picks up newly tracked files and leaves the rest
alone.

## What gets linked

The map lives in `bin/install` and is an explicit list, because the shape isn't
uniform:

| repo | `$HOME` | |
| --- | --- | --- |
| `.zshrc` | `~/.zshrc` | interactive shell: prompt, PATH, tool init |
| `.zshenv` | `~/.zshenv` | values every shell needs, interactive or not |
| `.gitconfig` | `~/.gitconfig` | |
| `.aerospace.toml` | `~/.aerospace.toml` | window manager; also starts sketchybar |
| `.config` | `~/.config` | whole directory — sketchybar, gh, ccstatusline |
| `claude/settings.json` | `~/.claude/settings.json` | hooks that drive the fleet scripts |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | global instructions |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` | |
| `vscode/keybindings.json` | `~/Library/Application Support/Code/User/keybindings.json` | |

`~/.claude` is linked file by file instead of as a directory because it is mostly
runtime state — prompt history, conversation transcripts, caches, plugin state —
none of which belongs in a public repo. That is also why the sources sit in an
undotted `claude/` rather than a `.claude/` that could be linked wholesale.

VS Code's user directory is file by file for the same reason, and more so: beside
those two files it holds ~2GB of `workspaceStorage`, `History` and
`globalStorage`. VS Code extensions are not linked at all — the Brewfile's
`vscode "..."` lines install them, so `brew bundle` restores the set. Settings
Sync should stay off; it rewrites `settings.json` itself and would fight the
symlink.

Anything already in the way is moved to `*.pre-dotfiles.<timestamp>` rather than
overwritten, and named in the summary. An identical copy is replaced without a
backup, since there'd be nothing in it to keep.

## What isn't linked

Used from the repo in place, so linking them would be redundant:

- `bin/` — on PATH via `.zshrc`
- `claude/fleet-*.sh` — called by absolute path from `settings.json`
- `raycast/` — Raycast is pointed at the directory in its own preferences
- `Brewfile` — `brew bundle --file`

## Machine-local state kept out

Things that write themselves into config directories and would otherwise land in
the repo, since `~/.config` *is* this repo:

- `.config/raycast/` — ~60MB of downloaded extension bundles, gitignored
- `__pycache__/` — byte-compiled sketchybar plugin helpers, gitignored
- tfenv — keeps its ~85MB-per-release terraform binaries in the same directory as
  its config, and Homebrew's shims default that to `~/.config/tfenv`. `.zshenv`
  sets `TFENV_CONFIG_DIR=~/.local/share/tfenv` to move the whole thing out. The
  version pin moves with the binaries, so a new machine re-pins with `tfenv use`.
