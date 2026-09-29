return {
  {
    "3rd/image.nvim",
    lazy = false,
    build = false,
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      kitty_method = "normal",

      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = true,
          download_remote_images = false,

          -- 通常画像はカーソル位置で自動popup
          only_render_image_at_cursor = true,
          only_render_image_at_cursor_mode = "popup",

          floating_windows = false,
          filetypes = {
            "markdown",
            "vimwiki",
          },
        },

        asciidoc = { enabled = false },
        typst = { enabled = false },
        neorg = { enabled = false },
        syslang = { enabled = false },
        html = { enabled = false },
        css = { enabled = false },
        org = { enabled = false },
      },

      max_width = 80,
      max_height = 24,
      max_width_window_percentage = 60,
      max_height_window_percentage = 25,

      scale_factor = 1.0,
      window_overlap_clear_enabled = false,
      editor_only_render_when_focused = true,
      tmux_show_only_in_active_window = false,

      -- 画像ファイルを直接開いた際の自動描画は無効
      hijack_file_patterns = {},
    },
  },
  {
    "3rd/diagram.nvim",
    lazy = false,
    dependencies = {
      "3rd/image.nvim",
    },

    config = function()
      local diagram = require("diagram")
      local markdown = require("diagram.integrations.markdown")
      local image_nvim = require("image")
      local image_utils = require("image/utils")
      local uv = vim.uv or vim.loop

      local mermaid_options = {
        theme = "dark",
        background = "transparent",
        scale = 1,
      }

      -- diagram.nvim自身によるインライン描画は無効化
      diagram.setup({
        integrations = {
          markdown,
        },

        events = {
          render_buffer = {},
          clear_buffer = {},
        },

        renderer_options = {
          mermaid = mermaid_options,
        },
      })

      -- CursorHoldの待機時間。
      -- 既に短い値が設定されている場合は変更しない。
      if vim.o.updatetime > 400 then
        vim.o.updatetime = 400
      end

      local preview = {
        win = nil,
        buf = nil,
        image = nil,
        timer = nil,
        key = nil,
        generation = 0,
      }

      local function close_preview()
        preview.generation = preview.generation + 1
        preview.key = nil

        if preview.timer then
          local timer = preview.timer
          preview.timer = nil

          if not timer:is_closing() then
            timer:stop()
            timer:close()
          end
        end

        if preview.image then
          local current_image = preview.image
          preview.image = nil
          pcall(function()
            current_image:clear()
          end)
        end

        if preview.win and vim.api.nvim_win_is_valid(preview.win) then
          pcall(vim.api.nvim_win_close, preview.win, true)
        end
        preview.win = nil

        if preview.buf and vim.api.nvim_buf_is_valid(preview.buf) then
          pcall(vim.api.nvim_buf_delete, preview.buf, {
            force = true,
          })
        end
        preview.buf = nil
      end

      local function find_mermaid_at_cursor()
        local bufnr = vim.api.nvim_get_current_buf()

        if vim.bo[bufnr].filetype ~= "markdown" then
          return nil, nil
        end

        local ok, diagrams = pcall(markdown.query_buffer_diagrams, bufnr)
        if not ok then
          return nil, nil
        end

        local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        for _, current in ipairs(diagrams) do
          if current.renderer_id == "mermaid" then
            -- info_stringから開きフェンスを探す
            local start_row = current.range.start_row

            for row = start_row, 0, -1 do
              local line = lines[row + 1]

              if line and line:match("^%s*```") then
                start_row = row
                break
              end
            end

            -- 同じ開きフェンスを拾わないよう、
            -- 次の行から閉じフェンスを探す
            local end_row = #lines - 1

            for row = start_row + 1, #lines - 1 do
              local line = lines[row + 1]

              if line and line:match("^%s*```%s*$") then
                end_row = row
                break
              end
            end

            if cursor_row >= start_row and cursor_row <= end_row then
              local key = table.concat({
                tostring(bufnr),
                tostring(start_row),
                vim.fn.sha256(current.source),
              }, ":")

              return current, key
            end
          end
        end

        return nil, nil
      end

      local function find_mermaid_renderer()
        for _, renderer in ipairs(markdown.renderers) do
          if renderer.id == "mermaid" then
            return renderer
          end
        end

        return nil
      end

      local function open_popup(file_path, key, generation)
        if generation ~= preview.generation then
          return
        end

        local _, current_key = find_mermaid_at_cursor()
        if current_key ~= key then
          return
        end

        if vim.fn.filereadable(file_path) ~= 1 then
          return
        end

        local max_width = math.max(20, math.floor(vim.o.columns * 0.8))

        local available_lines = vim.o.lines - vim.o.cmdheight - 2

        local max_height = math.max(8, math.floor(available_lines * 0.65))

        local screen_row = vim.fn.screenrow()
        local screen_col = vim.fn.screencol()

        -- 画面下端・右端ではカーソルの上・左へ出す
        local popup_row = screen_row + max_height + 2 <= vim.o.lines and 1 or -(max_height + 1)

        local popup_col = screen_col + max_width + 2 <= vim.o.columns and 1 or -(max_width + 1)

        local bufnr = vim.api.nvim_create_buf(false, true)

        vim.bo[bufnr].buftype = "nofile"
        vim.bo[bufnr].bufhidden = "wipe"
        vim.bo[bufnr].swapfile = false

        local winid = vim.api.nvim_open_win(bufnr, false, {
          relative = "cursor",
          row = popup_row,
          col = popup_col,
          width = max_width,
          height = max_height,
          style = "minimal",
          border = "rounded",
          focusable = false,
          noautocmd = true,
          zindex = 70,
        })

        local current_image = image_nvim.from_file(file_path, {
          buffer = bufnr,
          window = winid,
          inline = true,
          with_virtual_padding = true,
          x = 0,
          y = 0,
        })

        if not current_image then
          pcall(vim.api.nvim_win_close, winid, true)
          return
        end

        local term_size = image_utils.term.get_size()
        if not term_size then
          current_image:clear()
          pcall(vim.api.nvim_win_close, winid, true)
          return
        end

        local width, height = image_utils.math.adjust_to_aspect_ratio(
          term_size,
          current_image.image_width,
          current_image.image_height,
          max_width,
          max_height
        )

        width = math.max(1, math.min(width, max_width))
        height = math.max(1, math.min(height, max_height))

        vim.api.nvim_win_set_width(winid, width)
        vim.api.nvim_win_set_height(winid, height)

        local empty_lines = {}
        for _ = 1, height do
          table.insert(empty_lines, "")
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, empty_lines)

        -- popupには上で計算したサイズを使う
        current_image.ignore_global_max_size = true

        preview.win = winid
        preview.buf = bufnr
        preview.image = current_image
        preview.key = key

        current_image:render({
          x = 0,
          y = 0,
          width = width,
          height = height,
        })
      end

      local function show_mermaid_popup()
        local current, key = find_mermaid_at_cursor()

        if not current then
          close_preview()
          return
        end

        if preview.key == key and preview.win and vim.api.nvim_win_is_valid(preview.win) then
          return
        end

        close_preview()

        local renderer = find_mermaid_renderer()
        if not renderer then
          return
        end

        local generation = preview.generation
        local result = renderer.render(current.source, mermaid_options)

        if not result then
          return
        end

        -- キャッシュ済みなら即座に表示
        if not result.job_id then
          open_popup(result.file_path, key, generation)
          return
        end

        -- mmdcの非同期処理を待つ
        local timer = uv.new_timer()
        if not timer then
          return
        end

        preview.timer = timer

        timer:start(
          0,
          100,
          vim.schedule_wrap(function()
            if generation ~= preview.generation then
              return
            end

            local status = vim.fn.jobwait({ result.job_id }, 0)[1]

            if status == -1 then
              return
            end

            if preview.timer == timer then
              preview.timer = nil
            end

            if not timer:is_closing() then
              timer:stop()
              timer:close()
            end

            if status == 0 then
              open_popup(result.file_path, key, generation)
            end
          end)
        )
      end

      -- カーソル行にある ![](path) のpathを返す
      local function find_image_url_at_cursor()
        local bufnr = vim.api.nvim_get_current_buf()
        local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1

        local parser = vim.treesitter.get_parser(bufnr, "markdown")
        parser:parse(true)

        local inlines = parser:children().markdown_inline
        if not inlines then
          return nil
        end

        local query = vim.treesitter.query.parse("markdown_inline", "(image (link_destination) @url)")
        local url = nil

        inlines:for_each_tree(function(tree)
          for _, node in query:iter_captures(tree:root(), bufnr) do
            if not url and node:range() == cursor_row then
              url = vim.treesitter.get_node_text(node, bufnr)
            end
          end
        end)

        return url
      end

      -- カーソル位置のMermaid(PNG)・画像のパスかURLを返す
      local function resolve_image_at_cursor()
        local current = find_mermaid_at_cursor()

        if current then
          local renderer = find_mermaid_renderer()
          local result = renderer and renderer.render(current.source, mermaid_options)

          if not result then
            return nil
          end

          -- 未キャッシュならmmdcの完了を待つ
          if result.job_id and vim.fn.jobwait({ result.job_id }, 10000)[1] ~= 0 then
            vim.notify("Mermaidのレンダリングに失敗しました", vim.log.levels.WARN)
            return nil
          end

          return result.file_path
        end

        local url = find_image_url_at_cursor()

        if not url then
          vim.notify("カーソル行に画像・Mermaidがありません", vim.log.levels.INFO)
          return nil
        end

        if url:match("^https?://") then
          return url
        end

        if not url:match("^[/~]") then
          url = vim.fs.joinpath(vim.fs.dirname(vim.api.nvim_buf_get_name(0)), url)
        end

        return vim.fs.normalize(url)
      end

      -- カーソル位置のMermaid・画像を外部ビューアで開く
      local function open_in_viewer()
        local path = resolve_image_at_cursor()

        if path then
          vim.ui.open(path)
        end
      end

      -- カーソル位置のMermaid・画像を画面いっぱいのfloatで表示する
      local function open_fullscreen()
        local file_path = resolve_image_at_cursor()

        if not file_path then
          return
        end

        if file_path:match("^https?://") then
          vim.notify("リモート画像は <leader>io で開いてください", vim.log.levels.INFO)
          return
        end

        if vim.fn.filereadable(file_path) ~= 1 then
          vim.notify("画像が見つかりません: " .. file_path, vim.log.levels.WARN)
          return
        end

        local term_size = image_utils.term.get_size()
        if not term_size then
          return
        end

        close_preview()

        local bufnr = vim.api.nvim_create_buf(false, true)

        vim.bo[bufnr].buftype = "nofile"
        vim.bo[bufnr].bufhidden = "wipe"
        vim.bo[bufnr].swapfile = false

        -- 仮サイズで開き、画像の縦横比が分かってから調整する
        local winid = vim.api.nvim_open_win(bufnr, true, {
          relative = "editor",
          row = 0,
          col = 0,
          width = 1,
          height = 1,
          style = "minimal",
          border = "rounded",
          zindex = 80,
        })

        local current_image = image_nvim.from_file(file_path, {
          buffer = bufnr,
          window = winid,
          inline = true,
          with_virtual_padding = true,
          x = 0,
          y = 0,
        })

        if not current_image then
          pcall(vim.api.nvim_win_close, winid, true)
          return
        end

        local function close()
          pcall(function()
            current_image:clear()
          end)

          if vim.api.nvim_win_is_valid(winid) then
            pcall(vim.api.nvim_win_close, winid, true)
          end
        end

        -- borderの分を除いた画面いっぱいに縦横比を保って収める
        local max_width = vim.o.columns - 2
        local max_height = vim.o.lines - vim.o.cmdheight - 2

        local width, height = image_utils.math.adjust_to_aspect_ratio(
          term_size,
          current_image.image_width,
          current_image.image_height,
          max_width,
          max_height
        )

        width = math.max(1, math.min(width, max_width))
        height = math.max(1, math.min(height, max_height))

        vim.api.nvim_win_set_config(winid, {
          relative = "editor",
          row = math.floor((max_height - height) / 2),
          col = math.floor((max_width - width) / 2),
          width = width,
          height = height,
        })

        local empty_lines = {}
        for _ = 1, height do
          table.insert(empty_lines, "")
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, empty_lines)

        current_image.ignore_global_max_size = true

        for _, lhs in ipairs({ "q", "<Esc>" }) do
          vim.keymap.set("n", lhs, close, {
            buffer = bufnr,
            nowait = true,
            desc = "Close fullscreen image",
          })
        end

        -- 他のwindowへ移ったら閉じる
        vim.api.nvim_create_autocmd("WinLeave", {
          buffer = bufnr,
          once = true,
          callback = function()
            vim.schedule(close)
          end,
        })

        current_image:render({
          x = 0,
          y = 0,
          width = width,
          height = height,
        })
      end

      local group = vim.api.nvim_create_augroup("mermaid-hover-popup", { clear = true })

      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "markdown",
        callback = function(args)
          vim.keymap.set("n", "<leader>io", open_in_viewer, {
            buffer = args.buf,
            desc = "Open image/Mermaid in external viewer",
          })
          vim.keymap.set("n", "<leader>if", open_fullscreen, {
            buffer = args.buf,
            desc = "Show image/Mermaid in fullscreen float",
          })
        end,
      })

      -- Mermaidブロック内でカーソルを止めると自動表示
      vim.api.nvim_create_autocmd("CursorHold", {
        group = group,
        pattern = "*.md",
        callback = show_mermaid_popup,
      })

      -- カーソル移動・スクロール・編集開始で即座に消す
      vim.api.nvim_create_autocmd({
        "CursorMoved",
        "CursorMovedI",
        "InsertEnter",
        "WinScrolled",
        "BufLeave",
        "WinLeave",
        "TextChanged",
        "TextChangedI",
      }, {
        group = group,
        callback = close_preview,
      })
    end,
  },
}
