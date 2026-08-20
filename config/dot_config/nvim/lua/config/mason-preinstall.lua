-- install.sh のheadless実行から呼ばれ、config/mason-servers.lua のLSP serverを同期的に事前installする
-- (mason-lspconfigのensure_installedはheadlessでは動かないため、MasonInstallを直接使う)
return function()
  require("lazy").load({ plugins = { "mason.nvim", "mason-lspconfig.nvim" } })

  local registry = require("mason-registry")
  registry.refresh()

  local lspconfig_to_package = require("mason-lspconfig").get_mappings().lspconfig_to_package
  local packages = {}
  for _, server in ipairs(require("config.mason-servers")) do
    local package = lspconfig_to_package[server] or server
    if not registry.is_installed(package) then
      table.insert(packages, package)
    end
  end

  if #packages > 0 then
    vim.cmd("MasonInstall " .. table.concat(packages, " "))
  end
end
