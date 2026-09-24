return {
  "nvim-mini/mini.nvim",
  version = "*",
  config = function()
    require("mini.map").setup({
      -- Highlight integrations (none by default)
      integrations = nil,

      -- Symbols used to display data
      symbols = {
        encode = nil,
        scroll_line = "█",
        scroll_view = "┃",
      },

      -- Window options
      window = {
        focusable = false,
        side = "right",
        show_integration_count = true,
        width = 10,
        winblend = 25,
        zindex = 10,
      },
    })

    -- Auto-open minimap on VimEnter
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        require("mini.map").open()
      end,
    })
  end,
}
