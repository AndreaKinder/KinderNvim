local logo_ok, logo = pcall(require, "config.logo")

local header = logo_ok
    and (type(logo) == "table" and (type(logo[1]) == "string" and logo[1] or table.concat(logo, "\n")) or logo)
  or nil

return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        header = header,
      },
    },
  },
}
