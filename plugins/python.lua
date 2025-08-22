return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, {
        python = { "black" },
      })
      opts.format_on_save = { timeout_ms = 500, lsp_fallback = true }
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "pyright", "ruff_lsp" })
    end,
  },
  { "neovim/nvim-lspconfig", opts = { servers = { pyright = {}, ruff_lsp = {} } } },
  {
    "mfussenegger/nvim-dap",
    dependencies = { "rcarriga/nvim-dap-ui", "jay-babu/mason-nvim-dap.nvim" },
    config = function()
      local dap = require("dap")
      dap.configurations.python = dap.configurations.python or {}
      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "FastAPI (uvicorn)",
        module = "uvicorn",
        args = { "app.main:app", "--reload", "--port", "8000" },
        justMyCode = true,
      })
    end,
  },
}
