-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out,                            "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
    spec = {
        { import = "plugins.blink-cmp" },
        { import = "plugins.copilot" },
        { import = "plugins.fern" },
        { import = "plugins.gitsigns" },
        { import = "plugins.lualine" },
        { import = "plugins.mason" },
        { import = "plugins.sidekick" },
        { import = "plugins.snacks" },
        { import = "plugins.telescope" },
        { import = "plugins.theme" },
        { import = "plugins.treesitter" },
        { import = "plugins.trouble" },
        { import = "plugins.which-key" },
    },
    -- Configure any other settings here. See the documentation for more details.
    -- colorscheme that will be used when installing plugins.
    install = { colorscheme = { "tokyonight-night" } },
    -- automatically check for plugin updates
    checker = { enabled = true, notify = false },
})
