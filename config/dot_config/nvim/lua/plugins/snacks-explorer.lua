-- snacks.nvimのexplorerを、以前使っていたfern.vimと同じ操作体系で使うための設定。
-- snacks.luaのoptsにlazy.nvimがマージするので、ここではexplorer関連だけを書く。

-- git dir -> fs_event。Neovimを終えるまで同じworktreeを二重に監視しない
local worktree_watches = {}

return {
  "folke/snacks.nvim",
  init = function()
    -- dotfileのファイル名は灰色 (NonText) にせず通常色にする。gitignore対象は灰色のまま
    vim.api.nvim_set_hl(0, "SnacksPickerPathHidden", { link = "SnacksPickerFile" })

    -- snacksはgit statusを最大15分使い回し、.git/indexの変化を見たときだけ読み直す。
    -- 監視が通知を取りこぼすことがあるので、Neovimに戻ったときにも読み直させる。
    -- herdrは同じtabの中でpaneを移ったときだけFocusGainedを送り、tabの切り替えでは送らない
    vim.api.nvim_create_autocmd("FocusGained", {
      callback = function()
        local pickers = Snacks.picker.get({ source = "explorer", tab = false })
        for _, picker in ipairs(pickers) do
          require("snacks.explorer.git").refresh(Snacks.git.get_root(picker:cwd()) or picker:cwd())
        end
        if #pickers > 0 then
          require("snacks.explorer.watch").refresh()
        end
      end,
    })

    vim.api.nvim_create_autocmd("QuitPre", {
      callback = function()
        if #Snacks.picker.get({ source = "explorer" }) == 0 then
          return
        end

        local windows = vim.api.nvim_list_wins()
        local snacks_windows = {}
        local floating_windows = {}
        for _, win in ipairs(windows) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].filetype:match("^snacks_") then
            table.insert(snacks_windows, win)
          elseif vim.api.nvim_win_get_config(win).relative ~= "" then
            table.insert(floating_windows, win)
          end
        end

        if #windows - #floating_windows - #snacks_windows == 1 then
          for _, win in ipairs(snacks_windows) do
            vim.api.nvim_win_close(win, true)
          end
        end
      end,
    })
  end,
  keys = {
    -- <C-e>でdrawerをtoggle (fernの :Fern . -reveal=% -drawer -toggle相当。
    -- follow_fileにより開いたときに現在のファイルへ移動する)
    {
      "<C-e>",
      function()
        Snacks.explorer()
      end,
      desc = "Explorer (toggle)",
    },
  },
  opts = {
    explorer = {
      enabled = true,
      -- fernのD (trash) と同じくシステムのゴミ箱へ送る
      trash = true,
    },
    picker = {
      sources = {
        explorer = {
          -- fern#default_hidden = true相当。dotfileとgitignore対象を表示する
          hidden = true,
          ignored = true,
          -- 検索の入力欄は普段隠し、/を押したときだけ出す。幅はfernのdrawer_widthと同じ30列
          layout = { hidden = { "input" }, layout = { width = 30 } },
          -- git未追跡のファイル名は通常色にし、右端の?アイコンだけで区別する。
          -- (git_status_hlはファイル名にgit statusの色を乗せるかのフラグ。未追跡のときだけ切ることで、
          -- 変更ありなど他のgit statusの色付けとアイコンの色は維持される)
          format = function(item, picker)
            picker.opts.formatters.file.git_status_hl = item.status ~= "??"
            return Snacks.picker.format.file(item, picker)
          end,
          actions = {
            -- fernのopen-or-enter: ファイルなら開く、ディレクトリならrootにする
            open_or_enter = function(picker, item)
              if item and item.dir then
                picker:action("explorer_focus")
              else
                picker:action("confirm")
              end
            end,
            -- fernのreveal: 編集中のファイルの位置までツリーを開く
            reveal = function(picker)
              local file = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(picker.main))
              if file ~= "" then
                require("snacks.explorer.actions").update(picker, { target = file })
              end
            end,
            -- fernのmark: カーソル行の選択をtoggle (移動しない)
            mark = function(picker)
              picker.list:select()
            end,
            -- fernの<C-k> (kしてからmark)
            mark_up = function(picker)
              picker.list:move(-1)
              picker.list:select()
            end,
            -- 検索をやめる: ツリーを復元してからinputを隠し、listに戻る
            -- (explorer_updateはinputのバッファに触るので、隠す前に実行する)
            search_leave = function(picker)
              picker:action("explorer_update")
              picker:toggle("input", { enable = false, focus = "list" })
            end,
            -- inputを隠す。フォーカスは現在のwindowのまま (reveal後はlist、open後はmain)
            hide_input = function(picker)
              picker:toggle("input", { enable = false })
            end,
          },
          -- fern#hide_cursor相当: listにいる間はカーソルを透明にしてcursorlineだけ見せる
          -- (win.list.on_winはsnacksのlist実装が上書きするのでpickerのon_showを使う)
          on_show = function(picker)
            -- git worktreeでは.gitがgitdirを指すファイルになり、snacksの.git監視ではindexの変化に気づけない。
            -- 本当のgit dir (.git/worktrees/<名前>) のindexを監視して、commitなどでgit statusを読み直させる
            local root = Snacks.git.get_root(picker:cwd())
            if root and vim.fn.filereadable(root .. "/.git") == 1 then
              local git_dir = vim.trim(vim.fn.system({ "git", "-C", root, "rev-parse", "--absolute-git-dir" }))
              if vim.v.shell_error == 0 and not worktree_watches[git_dir] then
                worktree_watches[git_dir] = vim.uv.new_fs_event()
                worktree_watches[git_dir]:start(git_dir, {}, function(_, file)
                  if file and vim.fs.basename(file) == "index" then
                    vim.schedule(function()
                      require("snacks.explorer.git").refresh(root)
                      require("snacks.explorer.watch").refresh()
                    end)
                  end
                end)
              end
            end

            Snacks.util.set_hl(
              { TransparentCursor = { strikethrough = true, blend = 100 } },
              { prefix = "SnacksExplorer" }
            )
            local entry = "n-v:SnacksExplorerTransparentCursor/lCursor"
            local function hide()
              vim.opt.guicursor:append(entry)
            end
            local function restore()
              vim.opt.guicursor:remove(entry)
            end
            local list = picker.list.win
            list:on({ "BufEnter", "WinEnter" }, hide, { buf = true })
            list:on({ "BufLeave", "WinLeave" }, restore, { buf = true })
            if vim.api.nvim_get_current_win() == list.win then
              hide()
            end

            -- fernのhover popup相当: 幅に収まらない行にカーソルが乗ったら、
            -- 行のテキストとextmark (右寄せのgit statusは除く) を複製した1行のfloatを重ねて全文を見せる
            local ns = vim.api.nvim_create_namespace("my.snacks.explorer.hover")
            local hover_win
            local function hover_hide()
              if hover_win and vim.api.nvim_win_is_valid(hover_win) then
                vim.api.nvim_win_close(hover_win, true)
              end
              hover_win = nil
            end
            local function hover_show()
              hover_hide()
              local win, buf = list.win, list.buf
              local row = vim.api.nvim_win_get_cursor(win)[1]
              local line = (vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""):gsub("%s+$", "")
              local width = vim.fn.strdisplaywidth(line)
              if width < vim.api.nvim_win_get_width(win) then
                return
              end
              local pbuf = vim.api.nvim_create_buf(false, true)
              vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, { line })
              local marks = vim.api.nvim_buf_get_extmarks(buf, -1, { row - 1, 0 }, { row - 1, -1 }, { details = true })
              for _, m in ipairs(marks) do
                local d = m[4]
                if d.virt_text_pos ~= "right_align" then
                  pcall(vim.api.nvim_buf_set_extmark, pbuf, ns, 0, m[3], {
                    end_col = d.end_col,
                    hl_group = d.hl_group,
                    virt_text = d.virt_text,
                    virt_text_pos = d.virt_text_pos,
                  })
                end
              end
              hover_win = vim.api.nvim_open_win(pbuf, false, {
                relative = "win",
                win = win,
                bufpos = { row - 1, 0 },
                row = 0,
                col = 0,
                width = width,
                height = 1,
                style = "minimal",
                noautocmd = true,
                zindex = (vim.api.nvim_win_get_config(win).zindex or 50) + 1,
              })
              vim.wo[hover_win].winhighlight = "Normal:SnacksPickerListCursorLine"
            end
            list:on({ "CursorMoved", "WinEnter" }, hover_show, { buf = true })
            list:on({ "BufLeave", "WinLeave" }, hover_hide, { buf = true })
          end,
          win = {
            input = {
              keys = {
                -- <Esc>はexplorerを閉じるのではなく検索をやめる
                ["<Esc>"] = "search_leave",
                -- 検索中の<CR>は該当ファイルをツリー内で表示 (reveal) してからinputを隠す
                ["<CR>"] = { { "confirm", "hide_input" }, mode = { "n", "i" } },
              },
            },
            list = {
              keys = {
                -- 移動・展開 (l / h / <BS>はsnacksのデフォルトと同じ)
                ["<CR>"] = "open_or_enter",
                ["<C-h>"] = "explorer_up",
                ["i"] = "reveal",
                ["!"] = "toggle_hidden",
                -- 開く
                ["e"] = "confirm",
                ["E"] = "edit_vsplit",
                ["V"] = "edit_split",
                ["t"] = "tab",
                ["x"] = "explorer_open",
                -- 選択 (mark)
                ["-"] = { "mark", mode = { "n", "x" } },
                ["<C-j>"] = "select_and_next",
                ["<C-k>"] = "mark_up",
                -- ファイル操作
                -- N / Kはどちらも同じprompt。末尾に"/"を付けるとディレクトリになる
                ["N"] = "explorer_add",
                ["K"] = "explorer_add",
                ["D"] = "explorer_del",
                ["R"] = "explorer_rename",
                ["C"] = { "explorer_yank", mode = { "n", "x" } },
                ["P"] = "explorer_paste",
                -- 再読み込み
                ["r"] = "explorer_update",
                ["<C-l>"] = "explorer_update",
              },
            },
          },
        },
      },
    },
  },
}
