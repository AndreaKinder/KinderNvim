return {
  -- Configuración de Autocompletado Blink.cmp (Estilo Gentleman Programming)
  {
    "saghen/blink.cmp",
    dependencies = {
      "milanglacier/minuet-ai.nvim",
    },
    opts = {
      keymap = {
        preset = "super-tab",
        ["<A-y>"] = {
          function()
            require("minuet").make_blink_map()
          end,
        },
      },
      snippets = {
        preset = "luasnip",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "minuet" },
        providers = {
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            async = true,
            timeout_ms = 4000,
            score_offset = 50,
          },
        },
      },
      completion = {
        trigger = {
          prefetch_on_insert = false,
        },
        ghost_text = {
          enabled = true,
        },
        menu = {
          border = "rounded",
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 150,
          window = {
            border = "rounded",
          },
        },
      },
    },
  },

  -- Configuración LSP para Auto-Imports de PHP (intelephense) y JS/TS/Vue (vtsls)
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = {
          settings = {
            intelephense = {
              completion = {
                insertUseDeclaration = true,
                fullyQualifyGlobalConstantsAndFunctions = false,
              },
            },
          },
        },
        vtsls = {
          settings = {
            typescript = {
              suggest = {
                autoImports = true,
              },
            },
            javascript = {
              suggest = {
                autoImports = true,
              },
            },
          },
        },
        emmet_language_server = {
          filetypes = {
            "css",
            "eruby",
            "html",
            "javascript",
            "javascriptreact",
            "less",
            "sass",
            "scss",
            "pug",
            "typescriptreact",
            "vue",
          },
        },
      },
    },
  },
}
