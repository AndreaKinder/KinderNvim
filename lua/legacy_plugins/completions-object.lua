return {
  "hrsh7th/nvim-cmp",
  opts = function(_, opts)
    local cmp = require("cmp")
    opts.sources = cmp.config.sources({
      { name = "nvim_lsp" }, -- Esta es la fuente que lee tus objetos
      { name = "path" },
      { name = "buffer" },
    })

    -- Opcional: Esto asegura que el punto siempre dispare el autocompletado
    opts.completion = {
      completeopt = "menu,menuone,noinsert",
    }
  end,
}
