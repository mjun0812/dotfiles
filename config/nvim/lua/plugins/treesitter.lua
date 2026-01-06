return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")
      ts.setup({
        install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "treesitter"),
      })

      local ignore_ft = {
        help = true,
        fern = true,
        TelescopePrompt = true,
        TelescopeResults = true,
        lazy = true,
        toggleterm = true,
      }
      local ignore_bt = {
        terminal = true,
        prompt = true,
        nofile = true,
        acwrite = true,
        quickfix = true,
      }
      local ignore_lang = {
        -- comment = true,
        
      }

      local function should_ignore(buf, ft, lang)
        local bt = vim.bo[buf].buftype
        if ignore_bt[bt] then
          return true
        end

        if ignore_ft[ft] then
          return true
        end

        if ignore_lang[lang] then
          return true
        end

        return false
      end

      -- state
      local installed = {}   ---@type table<string, boolean>
      local installing = {}  ---@type table<string, boolean>
      local pending = {}     ---@type table<string, table<number, true>>  -- lang -> { bufnr = true, ... }
      local polling = {}     ---@type table<string, boolean>

      -- utils -------------------------------------------------------------

      local function buf_valid(buf)
        return buf and vim.api.nvim_buf_is_valid(buf)
      end

      local function has_parser(lang)
        -- runtimepath 上に parser/{lang}.* が見つかればOK
        return #vim.api.nvim_get_runtime_file(("parser/%s.*"):format(lang), false) > 0
      end

      local function seed_installed_from_rtp()
        for _, path in ipairs(vim.api.nvim_get_runtime_file("parser/*.*", true)) do
          local fname = vim.fn.fnamemodify(path, ":t") -- e.g. lua.so / python.wasm
          local lang = fname:match("^(.+)%.")
          if lang and lang ~= "" then
            installed[lang] = true
          end
        end
      end

      local function attach_treesitter(buf, lang)
        if not buf_valid(buf) then return end

        -- attach（失敗しても落とさない）
        pcall(vim.treesitter.start, buf, lang)

        -- indent（あなたの元の方針を維持）
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end

      local function ensure_install_started(lang)
        if installed[lang] or installing[lang] or has_parser(lang) then
          installed[lang] = installed[lang] or has_parser(lang)
          return
        end

        local ok = pcall(ts.install, { lang }, { summary = false })
        if ok then
          installing[lang] = true
          vim.notify(("Installing TS parser: %s"):format(lang), vim.log.levels.INFO)
        else
          vim.notify(("Failed to start TS install: %s"):format(lang), vim.log.levels.WARN)
        end
      end

      local function flush_pending(lang)
        local bufs = pending[lang]
        if not bufs then return end

        for buf, _ in pairs(bufs) do
          attach_treesitter(buf, lang)
        end
        pending[lang] = nil
      end

      local function start_polling(lang)
        if polling[lang] then return end
        polling[lang] = true

        local tries = 0
        local function tick()
          -- 完了判定
          if has_parser(lang) then
            installed[lang] = true
            installing[lang] = nil
            polling[lang] = nil

            vim.notify(("TS parser ready: %s"):format(lang), vim.log.levels.INFO)
            flush_pending(lang)
            return
          end

          tries = tries + 1
          if tries >= 60 then -- 60 * 200ms = 12秒で打ち切り（お好みで調整）
            polling[lang] = nil
            return
          end

          vim.defer_fn(tick, 200)
        end

        vim.defer_fn(tick, 200)
      end

      local function request_parser_for_buffer(buf, ft)
        if not ft or ft == "" then return end

        local lang = vim.treesitter.language.get_lang(ft) or ft
        if should_ignore(buf, ft, lanf) then
          return
        end

        -- すでに利用可能なら即 attach
        if installed[lang] or has_parser(lang) then
          installed[lang] = true
          attach_treesitter(buf, lang)
          return
        end

        -- まだなら「待ち行列」に追加して、インストール開始＆監視
        pending[lang] = pending[lang] or {}
        pending[lang][buf] = true

        ensure_install_started(lang)
        start_polling(lang)
      end

      -- init --------------------------------------------------------------

      seed_installed_from_rtp()

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("my-treesitter", { clear = true }),
        callback = function(args)
          request_parser_for_buffer(args.buf, args.match)
        end,
      })
    end
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
  }
}
