-- ctrl+bはsequenceの先頭になり単独では端末に届かなくなるため、2回押しで送る
rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- tmux (~/.tmux.conf)
rex.bind("ctrl+b>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+b>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+b>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+b>l", "pane.focus", { direction = "right" })
rex.bind("ctrl+b>r", "client.config.reload")

-- Herdr (~/.config/herdr/config.toml)
rex.bind("ctrl+b>up", "session.previous")
rex.bind("ctrl+b>down", "session.next")

-- WezTerm (~/.wezterm.lua)
rex.bind("shift+cmd+w", "client.tab.close")
rex.bind("ctrl+cmd+left", "pane.resize", { direction = "left", amount = 3 })
rex.bind("ctrl+cmd+right", "pane.resize", { direction = "right", amount = 3 })
rex.bind("ctrl+cmd+up", "pane.resize", { direction = "up", amount = 3 })
rex.bind("ctrl+cmd+down", "pane.resize", { direction = "down", amount = 3 })

-- iTerm2 (GlobalKeyMap)
rex.bind("shift+cmd+left", "client.tab.move", { direction = "backward" })
rex.bind("shift+cmd+right", "client.tab.move", { direction = "forward" })
rex.bind("cmd+right", "pane.focus_next")
rex.bind("cmd+left", "pane.focus_previous")
-- iTerm2のText "\n" (LF) はctrl+jと同じバイト
rex.bind("shift+enter", "pane.send_key", { key = "ctrl+j" })
