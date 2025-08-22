return {
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "tsserver", "eslint" })
    end,
  },
  { "neovim/nvim-lspconfig", opts = { servers = { tsserver = {}, eslint = {} } } },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, {
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
      })
    end,
  },
  {
    "mxsdev/nvim-dap-vscode-js",
    dependencies = { "mfussenegger/nvim-dap", "rcarriga/nvim-dap-ui", "jay-babu/mason-nvim-dap.nvim" },
    config = function()
      require("dap-vscode-js").setup({ adapters = { "pwa-node", "pwa-chrome" } })
      local dap = require("dap")
      for _, ft in ipairs({ "typescript", "typescriptreact", "javascript", "javascriptreact" }) do
        dap.configurations[ft] = dap.configurations[ft] or {}
        table.insert(dap.configurations[ft], {
          type = "pwa-node",
          request = "launch",
          name = "Jest current file",
          runtimeExecutable = "node",
          runtimeArgs = { "./node_modules/jest/bin/jest.js", "${file}", "--runInBand" },
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
        })
        table.insert(dap.configurations[ft], {
          type = "pwa-chrome",
          request = "launch",
          name = "Chrome inspect app",
          url = "http://localhost:3000",
          webRoot = "${workspaceFolder}",
        })
      end
    end,
  },
  { "nvim-neotest/neotest" },
  { "nvim-neotest/neotest-python" },
  { "haydenmeade/neotest-jest" },
}
