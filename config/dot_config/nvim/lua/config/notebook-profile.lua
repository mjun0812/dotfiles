local M = {}

local profile = vim.env.NVIM_NOTEBOOK or "none"

local valid_profiles = {
    none = true,
    molten = true,
    ipynb = true,
    all = true,
}

if not valid_profiles[profile] then
    vim.schedule(function()
        vim.notify(
            ("Unknown NVIM_NOTEBOOK profile: %s"):format(profile),
            vim.log.levels.WARN
        )
    end)

    profile = "none"
end

function M.enabled(name)
    return profile == name or profile == "all"
end

function M.current()
    return profile
end

function M.images_enabled()
    return vim.env.NVIM_NOTEBOOK_IMAGES ~= "0"
end

return M
