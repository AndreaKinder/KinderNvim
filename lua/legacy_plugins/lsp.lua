return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      volar = {
        -- Opciones específicas para Volar
        init_options = {
          vue = {
            hybridMode = true, -- Recomendado para versiones recientes de Volar
          },
        },
      },
      vtsls = {
        -- Permite que el servidor de TS vea archivos .vue para auto-imports
        filetypes = { "javascript", "typescript", "vue" },
      },
    },
  },
}
