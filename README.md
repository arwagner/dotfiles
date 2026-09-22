# dotfiles

macOS config: zsh, git, AeroSpace tiling with a sketchybar status bar,
Claude Code's global settings, and a Home Assistant VM.

## Setting up a new machine

The clone has to live at `~/dotfiles`. `.zshrc` puts `~/dotfiles/bin` on PATH and
`claude/settings.json` invokes the fleet scripts by their `dotfiles/claude/...`
path, so a clone anywhere else links cleanly and then fails at runtime.
`bin/install` refuses to run from the wrong place rather than let that happen.

```sh
git clone git@github.com:arwagner/dotfiles.git ~/dotfiles
~/dotfiles/bin/install --dry-run    # see what would change
~/dotfiles/bin/install              # installs Homebrew and the Brewfile too

tfenv install && tfenv use <version>
~/dotfiles/bin/install-homeassistant   # optional; builds the Home Assistant VM
exec zsh
```

`launchd/com.andrew.aerospace.plist` starts AeroSpace at login, which starts
sketchybar in turn — `bin/install` links the plist but does not load it, so on a
first setup run it once by hand:

```sh
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.andrew.aerospace.plist
```

Two apps need permissions macOS only grants by hand. Karabiner-Elements needs
its driver extension approved and then Input Monitoring. Hammerspoon needs
Accessibility, and "Launch at login" turned on in its own preferences. Until
both are granted the keyboard behaves as if neither app is installed. UTM needs
a third, described under [Home Assistant](#home-assistant).

`bin/install` is rerunnable. It reports `ok` for anything already linked, so
running it after a `git pull` picks up newly tracked files and leaves the rest
alone. Every run also applies the Brewfile — installing Homebrew itself first if
the machine has none — so a package added to the Brewfile arrives with the next
run. It also runs the `buddy` installer described under [Skills and
subagents](#skills-and-subagents).

## What gets linked

The map lives in `bin/install` and is an explicit list, because the shape isn't
uniform:

| repo | `$HOME` | |
| --- | --- | --- |
| `.zshrc` | `~/.zshrc` | interactive shell: prompt, PATH, tool init |
| `.zshenv` | `~/.zshenv` | values every shell needs, interactive or not |
| `.gitconfig` | `~/.gitconfig` | **included**, not linked — see below |
| `.aerospace.toml` | `~/.aerospace.toml` | window manager; also starts sketchybar |
| `.config` | `~/.config` | whole directory — sketchybar, gh, ccstatusline, karabiner |
| `claude/settings.json` | `~/.claude/settings.json` | hooks that drive the fleet scripts |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | global instructions |
| `codex/config.toml` | `~/.codex/config.toml` | Codex CLI settings — **copied**, not linked — see below |
| `hammerspoon/init.lua` | `~/.hammerspoon/init.lua` | gives Shift-CapsLock back a real Caps Lock |
| `launchd/com.andrew.homeassistant.plist` | `~/Library/LaunchAgents/…` | starts the Home Assistant VM at login |
| `launchd/com.andrew.aerospace.plist` | `~/Library/LaunchAgents/…` | starts AeroSpace at login and relaunches it if it crashes |
| `vscode/settings.json` | `~/Library/Application Support/Code/User/settings.json` | |
| `vscode/keybindings.json` | `~/Library/Application Support/Code/User/keybindings.json` | |

`~/.codex` is not linked at all. `auth.json` sits next to `config.toml` and
holds live ChatGPT OAuth credentials, so only `config.toml` is tracked — and
that one is copied rather than linked, because Codex writes state into its own
config file. It records a `[hooks.state]` trust hash per hook, so it can tell
when a hook changed since you approved it, and a `[tui.model_availability_nux]`
counter for the "new model available" notice. The hook keys embed the absolute
path of the file that declared them, so they mean nothing on another machine.
Codex offers no way to keep that state elsewhere: hooks can move to
`~/.codex/hooks.json`, but the trust table still lands in `config.toml`. While
the file was a symlink, every Codex session dirtied this repo.

So `install` writes the repo copy out and keeps the sha of what it wrote in
`~/.codex/.config.toml.installed-sha`. That is how it tells an edit made here,
which it copies over quietly, from an edit made to the live file, which it backs
up first. Codex's state is dropped on rewrite, which costs one "trust all" the
next time Codex starts. Edits to `codex/config.toml` need an `install` run to
take effect.

`~/.claude` is linked file by file instead of as a directory because it is mostly
runtime state — prompt history, conversation transcripts, caches, plugin state —
none of which belongs in a public repo. That is also why the sources sit in an
undotted `claude/` rather than a `.claude/` that could be linked wholesale.

`~/.gitconfig` is the one entry that is not a symlink. `install` writes a stub
there that `[include]`s this repo's copy, so git reads the same settings while
the file itself stays disposable. `actions/checkout` copies `~/.gitconfig` into a
temp `HOME` before adding a `safe.directory` line, but its copy step recreates a
symlink as a symlink, so a linked `~/.gitconfig` sent every self-hosted runner
job's write straight back into this repo. The stub gets copied for real, and the
writes stay in the temp `HOME`.

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

The one plugin this repo touches is spec-flow, and it touches the whole plugin
rather than any skill inside it. It is a plugin I work on, so `bin/install`
replaces the copy Claude Code downloaded with a symlink to its checkout at
`~/Dropbox/andrew/skylight/code/spec-flow`, and writes the
`.claude-plugin/plugin.json` that repo generates at package time and gitignores.
An edit there is then live on the next start. `/plugin update spec-flow` would
download over the link; `autoUpdates` is off, so that only happens on request,
and rerunning `bin/install` puts the link back.

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

## Home Assistant

`bin/install-homeassistant` builds a Home Assistant VM in UTM from nothing: it
downloads a pinned Home Assistant OS image, checks it against a recorded
SHA-256, and creates the VM through UTM's AppleScript interface. Rerunning it
reports `ok` and exits, so it is safe after a `git pull` like `bin/install`.

It is a virtual machine and not a Docker container because Home Assistant OS is
what the add-on store, the Supervisor and every guide online assume. Running the
bare container drops all three, and on macOS it also strands Home Assistant
behind Docker's private network, where the mDNS broadcasts that discover Wi-Fi
devices never arrive. The VM bridges onto whichever interface carries the
default route, so it holds its own address on the LAN and discovery works.

UTM rather than VirtualBox, which the Home Assistant docs lead with: VirtualBox
on Apple Silicon is still a developer preview. UTM drives QEMU with the hardware
hypervisor, so the aarch64 guest runs at native speed.

Three things the script pins, and they are the whole reason it exists rather
than a page of instructions: the OS version, the image checksum, and the VM's
shape — memory, cores, UEFI boot, VirtIO disk, bridged NIC. Two machines running
it get the same VM.

What it deliberately does not carry is the ~32 GiB disk. That file cannot live
in git, and it must not live in Dropbox either: a running guest writes to it
continuously, so a sync client uploads it forever and can drop a half-written
copy over a live one. The disk is rebuilt from the download instead. The state
worth keeping travels as Home Assistant's own backup `.tar`, which is small,
written once, and safe to sync — set that up under Settings > System > Backups.

The compressed download is cached in `~/Library/Caches/dotfiles-haos` rather
than the repo, so a rebuild after deleting the VM does not fetch 360 MiB again.

Quitting UTM stops every VM it hosts, so the guest dies with the app and a
reboot leaves nothing running. `launchd/com.andrew.homeassistant.plist` starts
it again at login. It runs `bin/homeassistant-start`, which opens UTM, waits for
the VM registry to load, and starts the VM only if it is not already up — so it
is also the thing to run by hand after an accidental quit. The plist reaches the
script through `$HOME` rather than a hardcoded path, since launchd sets `HOME`
for a user agent but does not expand `~` in `ProgramArguments`.

`bin/install` links that plist; `bin/install-homeassistant` is what loads it.
Linking and loading are separate acts, and a `launchctl bootstrap` for one
specific service does not belong in the generic installer. launchd is happy to
bootstrap the symlink and resolves it back to the repo copy, so this one does
not need the real-file treatment `~/.gitconfig` gets.

Like Karabiner and Hammerspoon, this needs one permission macOS only grants by
hand: the first run asks to let the terminal control UTM. Denying it fails the
script with a note rather than hanging.

## What isn't linked

Used from the repo in place, so linking them would be redundant:

- `bin/` — on PATH via `.zshrc`
- `claude/fleet-*.sh` — called by absolute path from `settings.json`
- `Brewfile` — `bin/install` applies it with `brew bundle --file`

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
