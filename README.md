# herdr-lazygit

Open [lazygit](https://github.com/jesseduffield/lazygit) in a herdr split pane or its own tab, with smart toggle: press once to open, again to focus, and again (while focused) to close. Quitting lazygit (`q`) closes the pane.

**Split pane** (`ctrl+alt+g`) — lazygit beside your work:

![lazygit in a herdr split pane](docs/split-pane.jpeg)

**Own tab** (`ctrl+alt+shift+g`) — full-window lazygit:

![lazygit in its own herdr tab](docs/tab.png)

Requires herdr ≥ 0.7.0, `lazygit`, and `jq` (without jq the shortcut still opens lazygit, it just loses the toggle).

## Install

```bash
herdr plugin install JacquesvanWyk/herdr-lazygit
herdr plugin list   # confirm herdr-lazygit is registered
```

For local development:

```bash
herdr plugin link /path/to/herdr-lazygit
```

## Keybindings

Add to `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "ctrl+alt+g"
type = "shell"
command = "herdr plugin action invoke open-lazygit --plugin herdr-lazygit"

[[keys.command]]
key = "ctrl+alt+shift+g"
type = "shell"
command = "herdr plugin action invoke open-lazygit-tab --plugin herdr-lazygit"
```

> **Pick keys that fit your setup.** These are suggestions. herdr reserves most
> `prefix+<letter>` chords for its built-ins (`prefix+z` zoom, `prefix+n`/`prefix+p` tab
> nav, and more — see the herdr keybindings reference), so this plugin uses `ctrl+alt+*`
> direct chords to avoid clashing with them or with your other plugins. Rebind to whatever
> is free on your system. If `ctrl+alt+shift+*` doesn't register in your terminal, use a
> plain `ctrl+alt+<letter>` for the tab action instead.

Then reload:

```bash
herdr server reload-config
```

Or invoke without a keybinding:

```bash
herdr plugin action invoke open-lazygit --plugin herdr-lazygit
herdr plugin action invoke open-lazygit-tab --plugin herdr-lazygit
```
