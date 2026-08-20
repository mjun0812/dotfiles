-- CIで install.sh の事前install結果を検証するスクリプト
-- (nvim --headless -c "luafile script/ci/check_nvim.lua" +qa で実行する)
-- treesitter parserとMason packageが1つでも欠けていればexit code 1で異常終了する
local missing = {}

for _, lang in ipairs(require("config.treesitter-langs")) do
  if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", true) == 0 then
    table.insert(missing, "treesitter:" .. lang)
  end
end

require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim" } })
local registry = require("mason-registry")
registry.refresh()
local lspconfig_to_package = require("mason-lspconfig").get_mappings().lspconfig_to_package
for _, server in ipairs(require("config.mason-servers")) do
  local package = lspconfig_to_package[server] or server
  if not registry.is_installed(package) then
    table.insert(missing, "mason:" .. package)
  end
end

if #missing > 0 then
  io.stderr:write("missing: " .. table.concat(missing, " ") .. "\n")
  vim.cmd("cquit 1")
end
print("OK: all treesitter parsers and mason packages are installed")
