return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")
      ts.setup()

      -- FileType / buftype による除外リスト
      local ignore_ft = {
        help = true,
        fern = true,
        lazy = true,
        toggleterm = true,
        TelescopePrompt = true,
        TelescopeResults = true,
      }
      local ignore_bt = {
        terminal = true,
        prompt = true,
        nofile = true,
        acwrite = true,
        quickfix = true,
      }

      local ensure_installed = {
        "markdown_inline",
        "bash",
        "python",
        "lua",
        "json",
        "yaml",
        "toml",
        "html",
        "css",
        "javascript",
        "typescript",
        "go",
        "rust",
        "c",
        "cpp",
        "java",
        "dockerfile",
        "sql",
        "vim",
        "regex",
      }

      local supported_languages = {}
      for _, language in ipairs(ts.get_available()) do
        supported_languages[language] = true
      end

      local installing = {} ---@type table<string, boolean>

      --- バッファでパーサーを利用できるか確認
      local function has_parser(buf, lang)
        local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
        return ok and parser ~= nil
      end

      --- バッファに treesitter を適用
      local function attach(buf, lang)
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        vim.treesitter.start(buf, lang)
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end

      --- パーサーのインストール完了をポーリングで待ち、完了後に attach する
      local function wait_and_attach(buf, lang)
        local tries = 0
        local function poll()
          if has_parser(buf, lang) then
            installing[lang] = nil
            vim.notify(("TS parser ready: %s"):format(lang), vim.log.levels.INFO)
            attach(buf, lang)
            return
          end
          tries = tries + 1
          if tries < 60 then
            vim.defer_fn(poll, 200)
          end
        end
        vim.defer_fn(poll, 200)
      end

      --- パーサーが未インストールなら自動インストールを開始
      local function auto_install(buf, lang)
        if installing[lang] then
          return
        end
        installing[lang] = true
        vim.notify(("Installing TS parser: %s"):format(lang), vim.log.levels.INFO)

        local ok = pcall(ts.install, { lang }, { summary = false })
        if not ok then
          installing[lang] = nil
          return
        end

        wait_and_attach(buf, lang)
      end

      -- ensure_installed のパーサーを自動インストール
      for _, lang in ipairs(ensure_installed) do
        if supported_languages[lang] and not has_parser(0, lang) then
          pcall(ts.install, { lang }, { summary = false })
        end
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("my-treesitter", { clear = true }),
        callback = function(args)
          local ft = args.match
          if not ft or ft == "" then
            return
          end
          if ignore_ft[ft] or ignore_bt[vim.bo[args.buf].buftype] then
            return
          end

          local lang = vim.treesitter.language.get_lang(ft) or ft
          if not supported_languages[lang] then
            return
          end
          if has_parser(args.buf, lang) then
            attach(args.buf, lang)
          else
            auto_install(args.buf, lang)
          end
        end,
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
  },
}
