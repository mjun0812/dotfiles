-- snacks.nvim の explorer を、以前使っていた fern.vim と同じ操作体系で使うための設定。
-- snacks.lua の opts に lazy.nvim がマージするので、ここでは explorer 関連だけを書く。
return {
  "folke/snacks.nvim",
  keys = {
    -- <C-e> で drawer を toggle (fern の :Fern . -reveal=% -drawer -toggle 相当。
    -- follow_file により開いたときに現在のファイルへ移動する)
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
      -- fern の D (trash) と同じくシステムのゴミ箱へ送る
      trash = true,
    },
    picker = {
      sources = {
        explorer = {
          -- fern#default_hidden = true 相当。dotfile と gitignore 対象を表示する
          hidden = true,
          ignored = true,
          -- 検索の入力欄は普段隠し、/ を押したときだけ出す。幅は fern の drawer_width と同じ 30 列
          layout = { hidden = { "input" }, layout = { width = 30 } },
          actions = {
            -- fern の open-or-enter: ファイルなら開く、ディレクトリなら root にする
            open_or_enter = function(picker, item)
              if item and item.dir then
                picker:action("explorer_focus")
              else
                picker:action("confirm")
              end
            end,
            -- fern の reveal: 編集中のファイルの位置までツリーを開く
            reveal = function(picker)
              local file = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(picker.main))
              if file ~= "" then
                require("snacks.explorer.actions").update(picker, { target = file })
              end
            end,
            -- fern の mark: カーソル行の選択を toggle (移動しない)
            mark = function(picker)
              picker.list:select()
            end,
            -- fern の <C-k> (k してから mark)
            mark_up = function(picker)
              picker.list:move(-1)
              picker.list:select()
            end,
            -- 検索をやめる: ツリーを復元してから input を隠し、list に戻る
            -- (explorer_update は input のバッファに触るので、隠す前に実行する)
            search_leave = function(picker)
              picker:action("explorer_update")
              picker:toggle("input", { enable = false, focus = "list" })
            end,
            -- input を隠す。フォーカスは現在の window のまま (reveal 後は list、open 後は main)
            hide_input = function(picker)
              picker:toggle("input", { enable = false })
            end,
          },
          -- fern#hide_cursor 相当: list にいる間はカーソルを透明にして cursorline だけ見せる
          -- (win.list.on_win は snacks の list 実装が上書きするので picker の on_show を使う)
          on_show = function(picker)
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

            -- fern の hover popup 相当: 幅に収まらない行にカーソルが乗ったら、
            -- 行のテキストと extmark (右寄せの git status は除く) を複製した 1 行の float を重ねて全文を見せる
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
                -- <Esc> は explorer を閉じるのではなく検索をやめる
                ["<Esc>"] = "search_leave",
                -- 検索中の <CR> は該当ファイルをツリー内で表示 (reveal) してから input を隠す
                ["<CR>"] = { { "confirm", "hide_input" }, mode = { "n", "i" } },
              },
            },
            list = {
              keys = {
                -- 移動・展開 (l / h / <BS> は snacks のデフォルトと同じ)
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
                -- N / K はどちらも同じ prompt。末尾に "/" を付けるとディレクトリになる
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
