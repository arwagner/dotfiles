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

Then start AeroSpace, which starts sketchybar in turn.

Two apps need permissions macOS only grants by hand. Karabiner-Elements needs
its driver extension approved and then Input Monitoring. Hammerspoon needs
Accessibility, and "Launch at login" turned on in its own preferences. Until
both are granted the keyboard behaves as if neither app is installed.

`bin/install` is rerunnable. It reports `ok` for anything already linked, so
running it after a `git pull` picks up newly tracked files and leaves the rest
alone. It also runs the `buddy` installer described under [Skills and
subagents](#skills-and-subagents).

## What gets linked

The map lives in `bin/install` and is an explicit list, because the shape isn't
uniform:

| repo | `$HOME` | |
| --- | --- | --- |
| `.zshrc` | `~/.zshrc` | interactive shell: prompt, PATH, tool init |
| `.zshenv` | `~/.zshenv` | values every shell needs, interactive or not |
| `.gitconfig` | `~/.gitconfig` | |
| `.aerospace.toml` | `~/.aerospace.toml` | window manager; also starts sketchybar |
| `.config` | `~/.config` | whole directory — sketchybar, gh, ccstatusline, karabiner |
| `claude/settings.json` | `~/.claude/settings.json` | hooks that drive the fleet scripts |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | global instructions |
| `hammerspoon/init.lua` | `~/.hammerspoon/init.lua` | gives Shift-CapsLock back a real Caps Lock |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` | |
| `vscode/keybindings.json` | `~/Library/Application Support/Code/User/keybindings.json` | |

`~/.claude` is linked file by file instead of as a directory because it is mostly
runtime state — prompt history, conversation transcripts, caches, plugin state —
none of which belongs in a public repo. That is also why the sources sit in an
undotted `claude/` rather than a `.claude/` that could be linked wholesale.

`~/.hammerspoon` is file by file for the same reason: Hammerspoon writes console
history there.

VS Code's user directory is file by file for the same reason, and more so: beside
those two files it holds ~2GB of `workspaceStorage`, `History` and
`globalStorage`. VS Code extensions are not linked at all — the Brewfile's
`vscode "..."` lines install them, so `brew bundle` restores the set. Settings
Sync should stay off; it rewrites `settings.json` itself and would fight the
symlink.

## Skills and subagents

My own Claude skills are not in this repo. They live in the `buddy` repo at
`~/Dropbox/andrew/code/buddy`, which ships its own `install.sh` to link them into
`~/.claude/skills` and `~/.claude/agents`. `bin/install` calls that installer and
passes `--dry-run` through, so one command still sets up a machine.

The wiring is deliberately in one place only. A personal skill in
`~/.claude/skills` silently wins over a plugin skill of the same name, so a
second copy of this logic here would drift without anything reporting it. That
is also why buddy's installer prunes: a skill deleted from the repo leaves a
dangling symlink that Claude Code reports as broken, so linking alone never
converges.

Everything else under `~/.claude/skills` comes from plugins, listed in
`claude/settings.json` under `enabledPlugins`. Plugins are installed and updated
through Claude Code, not from here. Do not hand-link a plugin's skills — that
recreates the shadowing this section exists to prevent.

Buddy arrives through Dropbox rather than a clone, so a fresh machine that has
not synced yet gets a skipped notice instead of a failure. Rerun `bin/install`
once it lands.

## Keyboard

Everything bound is an `alt` chord in `.aerospace.toml`. A chord earns its place
by frequency, not by being memorable: focus and window motion, workspace
switching, sending a window to a workspace, and moving a whole workspace to
another monitor. `i` `j` `k` `l` mean up, left, down and right throughout, which
is why no workspace is named `H` through `L`.

Everything else — layout, flatten, reload, rename, the Claude fleet scripts —
has no key and is run from the CLI. That used to be a Caps Lock leader tree
built on Hammerspoon and the Hammerflow spoon, spelling out noun-verb-object.
It was removed: the actions it covered turned out not to be worth a keystroke,
and the ones that were already had chords. If something in the CLI list starts
grating, give it a chord rather than rebuilding the tree.

### What Karabiner does

Caps Lock is rewritten to `f18` on every keyboard, a key nothing else claims.
Nothing is bound to bare `f18` any more, so Caps Lock alone does nothing. Shift
passes through untouched, so Shift-CapsLock arrives as Shift-`f18`, and
`hammerspoon/init.lua` binds that to toggle the real Caps Lock — the only route
back, since Karabiner rewrites the key unconditionally. That single binding is
the entire reason Hammerspoon is still installed.

The other two rules fix the hands rather than the bindings. The built-in
keyboard and the USB one disagree about where Command and Option sit, so
`alt` chords land under a different thumb on each. Karabiner swaps the pair on
the USB keyboard alone, matching it to the Mac. It then maps right Command to
Option on both, which puts an Option key where the right thumb already rests.
With one under each thumb you reach `alt` with the hand opposite the letter,
which is what stops `alt-shift-s` from becoming a one-handed claw.

## MCP servers

`claude/mcp-servers.json` holds the global MCP servers, and `bin/install`
registers each one with `claude mcp add-json -s user`. They are not linked.
User-scope servers live in `~/.claude.json`, which Claude Code rewrites
constantly with prompt history, the OAuth account and cached feature flags. That
file can be neither a symlink nor a public repo file. The install step adds and
updates only, so a server that is not in the repo file stays untouched.

Keep tokens out of both files. Claude Code expands `${VAR}` in a server's argv
when it starts that server. So a secret is written as `${TODO_API_KEY}` here and
its value lives in the Dropbox env file `.zshenv` sources. A server whose
variable is unset fails when it connects, not during install, and `claude mcp
list` reports which one.

Anything already in the way is moved to `*.pre-dotfiles.<timestamp>` rather than
overwritten, and named in the summary. An identical copy is replaced without a
backup, since there'd be nothing in it to keep.

## What isn't linked

Used from the repo in place, so linking them would be redundant:

- `bin/` — on PATH via `.zshrc`
- `claude/fleet-*.sh` — called by absolute path from `settings.json`
- `Brewfile` — `brew bundle --file`

`~/.hammerspoon/Spoons` is left over from the leader tree, which loaded the
Hammerflow spoon from there. Nothing loads a spoon now, so the directory can go
whenever you next tidy up.

## Machine-local state kept out

Things that write themselves into config directories and would otherwise land in
the repo, since `~/.config` *is* this repo:

- `.config/raycast/` — ~60MB of downloaded extension bundles, gitignored
- `.config/karabiner/automatic_backups/` — Karabiner snapshots its config here
  every time you touch a setting, gitignored. The config itself is tracked, and
  Karabiner rewrites it in place, so its history lives in git instead
- `__pycache__/` — byte-compiled sketchybar plugin helpers, gitignored
- tfenv — keeps its ~85MB-per-release terraform binaries in the same directory as
  its config, and Homebrew's shims default that to `~/.config/tfenv`. `.zshenv`
  sets `TFENV_CONFIG_DIR=~/.local/share/tfenv` to move the whole thing out. The
  version pin moves with the binaries, so a new machine re-pins with `tfenv use`.
