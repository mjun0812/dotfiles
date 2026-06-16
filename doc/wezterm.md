# WezTerm Configuration

This document describes the WezTerm terminal emulator configuration and keyboard shortcuts.

The main configuration file is `config/dot/wezterm.lua`, which is linked to `~/.wezterm.lua`.

## Settings

| Setting                     | Value                                       |
| --------------------------- | ------------------------------------------- |
| Auto reload configuration   | Yes                                         |
| Audible bell                | Disabled                                    |
| Notification handling       | Always show                                 |
| IME                         | Enabled                                     |
| Quit when all windows close | No                                          |
| Window close confirmation   | Never prompt                                |
| Background opacity          | 0.70                                        |
| macOS background blur       | 30                                          |
| Font                        | RobotoMonoJP, Roboto Mono, Noto Color Emoji |
| Font size                   | 12.0                                        |
| Initial size                | 110 columns x 30 rows                       |
| Tab max width               | 16                                          |
| Hide tab bar for one tab    | No                                          |
| Show tab close button       | No                                          |
| Show new tab button         | No                                          |
| Show tab index              | No                                          |

## Keyboard Shortcuts

On macOS, WezTerm displays the `Cmd` key as `SUPER` in `wezterm show-keys`.

### Custom Bindings

These bindings are defined in `config.keys`.

| Key                    | Description                                     |
| ---------------------- | ----------------------------------------------- |
| `Shift + Enter`        | Send a literal newline                          |
| `Cmd + d`              | Split pane horizontally (left/right layout)     |
| `Cmd + Shift + d`      | Split pane vertically (top/bottom layout)       |
| `Cmd + w`              | Close the current pane without confirmation     |
| `Cmd + Shift + w`      | Close the current tab with confirmation         |
| `Cmd + Option + Left`  | Focus pane to the left                          |
| `Cmd + Option + Right` | Focus pane to the right                         |
| `Cmd + Option + Up`    | Focus pane above                                |
| `Cmd + Option + Down`  | Focus pane below                                |
| `Cmd + Ctrl + Left`    | Resize the current pane to the left by 3 cells  |
| `Cmd + Ctrl + Right`   | Resize the current pane to the right by 3 cells |
| `Cmd + Ctrl + Up`      | Resize the current pane upward by 3 cells       |
| `Cmd + Ctrl + Down`    | Resize the current pane downward by 3 cells     |

### Common Built-in Bindings

These bindings come from WezTerm defaults and are useful in daily use.

| Key                    | Description             |
| ---------------------- | ----------------------- |
| `Cmd + T`              | Open a new tab          |
| `Cmd + N`              | Open a new window       |
| `Cmd + C`              | Copy to clipboard       |
| `Cmd + V`              | Paste from clipboard    |
| `Cmd + F`              | Search                  |
| `Cmd + R`              | Reload configuration    |
| `Cmd + Q`              | Quit WezTerm            |
| `Cmd + 1-8`            | Activate tab 1-8        |
| `Cmd + 9`              | Activate the last tab   |
| `Cmd + [`              | Activate previous tab   |
| `Cmd + ]`              | Activate next tab       |
| `Cmd + =`              | Increase font size      |
| `Cmd + -`              | Decrease font size      |
| `Cmd + 0`              | Reset font size         |
| `Alt + Enter`          | Toggle fullscreen       |
| `Shift + PageUp`       | Scroll up by one page   |
| `Shift + PageDown`     | Scroll down by one page |
| `Ctrl + Shift + Space` | Quick select            |

### Built-in Pane Bindings

These defaults are still available in addition to the custom macOS-oriented bindings.

| Key                          | Description                        |
| ---------------------------- | ---------------------------------- |
| `Ctrl + Shift + Left`        | Focus pane to the left             |
| `Ctrl + Shift + Right`       | Focus pane to the right            |
| `Ctrl + Shift + Up`          | Focus pane above                   |
| `Ctrl + Shift + Down`        | Focus pane below                   |
| `Ctrl + Alt + Shift + Left`  | Resize pane to the left by 1 cell  |
| `Ctrl + Alt + Shift + Right` | Resize pane to the right by 1 cell |
| `Ctrl + Alt + Shift + Up`    | Resize pane upward by 1 cell       |
| `Ctrl + Alt + Shift + Down`  | Resize pane downward by 1 cell     |

## Copy Mode

Enter copy mode with `Ctrl + X`.

| Key                              | Description                        |
| -------------------------------- | ---------------------------------- |
| `h` / `j` / `k` / `l`            | Move cursor left/down/up/right     |
| `Left` / `Down` / `Up` / `Right` | Move cursor left/down/up/right     |
| `w`                              | Move forward by word               |
| `b`                              | Move backward by word              |
| `0`                              | Move to the start of line          |
| `$`                              | Move to the end of line content    |
| `G`                              | Move to the bottom of scrollback   |
| `g`                              | Move to the top of scrollback      |
| `Space` / `v`                    | Start cell selection               |
| `Shift + V`                      | Start line selection               |
| `Ctrl + V`                       | Start block selection              |
| `y`                              | Copy selection and close copy mode |
| `Esc` / `Q` / `Ctrl + C`         | Close copy mode                    |

## Mouse Bindings

| Action              | Description                          |
| ------------------- | ------------------------------------ |
| `Cmd + Click`       | Open the link under the mouse cursor |
| `Ctrl + Click`      | Open the link under the mouse cursor |
| Left click and drag | Select text                          |
| Double click        | Select word                          |
| Triple click        | Select line                          |
| Option + drag       | Block selection                      |

`Cmd` mouse handling bypasses terminal mouse reporting, so links can be opened even inside mouse-aware terminal applications such as tmux.

## Hyperlinks

The configuration extends WezTerm hyperlink handling for local file paths.

- Local paths such as `/path/to/file:42` are detected as links.
- Line and column suffixes are stripped before opening the file.
- Local files are opened with the OS default application.
- Standard URL links keep the default WezTerm behavior.
