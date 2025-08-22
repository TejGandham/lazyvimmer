return {
  {
    "kdheepak/lazygit.nvim",
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
      { "<leader>gG", "<cmd>LazyGitCurrentFile<cr>", desc = "LazyGit (current file)" },
      { "<leader>gf", "<cmd>LazyGitFilter<cr>", desc = "LazyGit Filter" },
      { "<leader>gF", "<cmd>LazyGitFilterCurrentFile<cr>", desc = "LazyGit Filter (current file)" },
    },
  },
}