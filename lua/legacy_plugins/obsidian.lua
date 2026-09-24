return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = false,
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  opts = {
    workspaces = {
      { name = "KinderDots", path = "~/.dotfiles/doc" },
    },
    log_level = vim.log.levels.INFO,
    completion = { nvim_cmp = false },
    ui = { enable = true },
    picker = {
      name = "telescope.nvim",
    },
  },
}
