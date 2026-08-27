local profile = require("config.notebook-profile")

local cell_marker_pattern = "^%s*#%s*%%%%"

local function current_percent_cell()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
    local marker_row = nil

    for row = cursor_row, 1, -1 do
        if lines[row] and lines[row]:match(cell_marker_pattern) then
            marker_row = row
            break
        end
    end

    if marker_row then
        local marker = lines[marker_row]

        if marker:match("%[markdown%]") or marker:match("%[raw%]") then
            return nil, nil, nil, "The current Jupytext cell is not executable"
        end
    end

    local first_line = marker_row and marker_row + 1 or 1
    local last_line = #lines
    local next_marker = nil

    for row = (marker_row or 0) + 1, #lines do
        if lines[row] and lines[row]:match(cell_marker_pattern) then
            next_marker = row
            last_line = row - 1
            break
        end
    end

    while first_line <= last_line
        and lines[first_line]
        and lines[first_line]:match("^%s*$")
    do
        first_line = first_line + 1
    end

    while last_line >= first_line
        and lines[last_line]
        and lines[last_line]:match("^%s*$")
    do
        last_line = last_line - 1
    end

    if first_line > last_line then
        return nil, nil, next_marker, "The current Jupytext cell is empty"
    end

    return first_line, last_line, next_marker, nil
end

local function run_percent_cell(move_next)
    if vim.fn.exists("*MoltenEvaluateRange") == 0 then
        vim.notify("Molten is not available", vim.log.levels.ERROR)
        return
    end

    local first_line, last_line, next_marker, err = current_percent_cell()

    if err then
        vim.notify(err, vim.log.levels.WARN)
        return
    end

    vim.fn.MoltenEvaluateRange(first_line, last_line)

    if move_next and next_marker then
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local target = math.min(next_marker + 1, #lines)

        while target < #lines and lines[target] and lines[target]:match("^%s*$") do
            target = target + 1
        end

        vim.api.nvim_win_set_cursor(0, { target, 0 })
    end
end

return {
    {
        "goerz/jupytext.nvim",
        cond = function()
            return profile.enabled("molten")
        end,
        lazy = false,
        opts = {
            jupytext = vim.fn.expand("$HOME/.venv/bin/jupytext"),
            format = "py:percent",
            update = true,
            autosync = true,
        },
        config = function(_, opts)
            require("jupytext").setup(opts)

            -- jupytext.nvim currently does not re-emit FileType after converting
            -- an ipynb buffer. The local Treesitter/LSP setup depends on it.
            vim.api.nvim_create_autocmd("BufReadPost", {
                group = vim.api.nvim_create_augroup(
                    "jupytext-filetype-refresh",
                    { clear = true }
                ),
                pattern = "*.ipynb",
                callback = function(args)
                    if vim.bo[args.buf].filetype == "" then
                        return
                    end

                    vim.api.nvim_exec_autocmds("FileType", {
                        buffer = args.buf,
                        modeline = false,
                    })
                end,
            })
        end,
    },
    {
        "benlubas/molten-nvim",
        cond = function()
            return profile.enabled("molten")
        end,
        lazy = false,
        build = ":UpdateRemotePlugins",
        dependencies = {
            "3rd/image.nvim",
        },
        init = function()
            vim.g.molten_auto_open_output = false
            vim.g.molten_virt_text_output = true
            vim.g.molten_wrap_output = true
            vim.g.molten_output_win_max_height = 20
            vim.g.molten_image_location = "both"
            vim.g.molten_image_provider = profile.images_enabled() and "image.nvim" or "none"
        end,
        keys = {
            {
                "<localleader>mi",
                "<cmd>MoltenInit<cr>",
                desc = "Molten: initialize kernel",
            },
            {
                "<localleader>rc",
                function()
                    run_percent_cell(false)
                end,
                desc = "Molten: run current Jupytext cell",
            },
            {
                "<localleader>rn",
                function()
                    run_percent_cell(true)
                end,
                desc = "Molten: run cell and move to next",
            },
            {
                "<localleader>rl",
                "<cmd>MoltenEvaluateLine<cr>",
                desc = "Molten: run line",
            },
            {
                "<localleader>rr",
                "<cmd>MoltenReevaluateCell<cr>",
                desc = "Molten: re-run active cell",
            },
            {
                "<localleader>ro",
                "<cmd>noautocmd MoltenEnterOutput<cr>",
                desc = "Molten: open output",
            },
            {
                "<localleader>ri",
                "<cmd>MoltenInterrupt<cr>",
                desc = "Molten: interrupt kernel",
            },
            {
                "<localleader>oi",
                "<cmd>MoltenImportOutput<cr>",
                desc = "Molten: import notebook outputs",
            },
            {
                "<localleader>oe",
                "<cmd>MoltenExportOutput!<cr>",
                desc = "Molten: export outputs to notebook",
            },
            {
                "<localleader>kr",
                "<cmd>MoltenRestart<cr>",
                desc = "Molten: restart kernel",
            },
            {
                "<localleader>r",
                ":<C-u>MoltenEvaluateVisual<CR>gv",
                mode = "v",
                desc = "Molten: run selection",
            },
        },
    },
}
