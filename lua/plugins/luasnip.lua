return {
  "L3MON4D3/LuaSnip",
  dependencies = {
    "rafamadriz/friendly-snippets",
  },
  opts = {
    history = true,
    delete_check_events = "TextChanged",
  },
  config = function(_, opts)
    local luasnip = require("luasnip")
    luasnip.config.set_config(opts)

    -- 1. Cargar snippets globales estándar (friendly-snippets)
    require("luasnip.loaders.from_vscode").lazy_load()

    -- 2. Cargar snippets globales de tu configuración (~/.config/nvim/snippets/)
    require("luasnip.loaders.from_lua").lazy_load({
      paths = { vim.fn.stdpath("config") .. "/snippets" },
    })

    -- 3. Cargar snippets exclusivos del proyecto actual
    -- Rutas relativas al directorio raíz del proyecto donde abras Neovim
    require("luasnip.loaders.from_lua").lazy_load({
      paths = { "./.luasnip", "./.snippets" },
    })

    -- (Opcional) Cargar snippets en formato VSCode desde la carpeta .vscode del proyecto
    require("luasnip.loaders.from_vscode").lazy_load({
      paths = { "./.vscode" },
    })
  end,
}
