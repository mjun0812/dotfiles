local profile = require("config.notebook-profile")

return {
  {
    "ajbucci/ipynb.nvim",
    cond = function()
      return profile.enabled("ipynb")
    end,
    lazy = false,
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "neovim/nvim-lspconfig",
      "nvim-tree/nvim-web-devicons",
      "folke/snacks.nvim",
    },
    opts = {
      keymaps = {
        execute_cell = "<localleader>rc",
        execute_and_next = "<localleader>rn",
        execute_and_insert = "<localleader>rN",
        execute_all_below = "<localleader>rb",
        open_output = "<localleader>ko",
        clear_output = "<localleader>kc",
        clear_all_outputs = "<localleader>kC",
        kernel_start = "<localleader>ks",
        kernel_interrupt = "<localleader>ki",
        kernel_restart = "<localleader>kr",
        kernel_shutdown = "<localleader>kS",
        variable_inspect = "<localleader>kh",
        cell_variables = "<localleader>kv",
      },
      kernel = {
        auto_connect = false,
        show_status = true,
        -- The bridge needs jupyter_client. The actual kernel is selected
        -- from the notebook kernelspec and can live in another venv.
        python_path = vim.fn.expand("$HOME/.venv/bin/python"),
      },
      images = {
        enabled = profile.images_enabled(),
      },
      inspector = {
        auto_hover = {
          enabled = false,
        },
      },
      format = {
        enabled = true,
        trailing_blank_lines = 0,
      },
      shadow = {
        location = "temp",
        dir = ".ipynb.nvim",
      },
    },
    config = function(_, opts)
      require("ipynb").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("ipynb-notebook-keymaps", { clear = true }),
        pattern = "ipynb",
        callback = function(args)
          vim.keymap.set("n", "<localleader>rA", "<cmd>NotebookExecuteAll<cr>", {
            buffer = args.buf,
            silent = true,
            desc = "Notebook: run all cells",
          })
        end,
      })
    end,
  },
}
