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
  -- Ensure nvim-dap is installed first
  {
    "mfussenegger/nvim-dap",
    dependencies = { 
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
  },
  -- Configure mason-nvim-dap for JS/TS debugging
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = {
      "mfussenegger/nvim-dap",
      "williamboman/mason.nvim",
    },
    opts = {
      ensure_installed = { "js-debug-adapter" },
      handlers = {},
    },
  },
  -- JavaScript/TypeScript DAP configuration
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")
      
      -- Configure the js-debug-adapter
      if not dap.adapters["pwa-node"] then
        dap.adapters["pwa-node"] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "js-debug-adapter",
            args = { "${port}" },
          },
        }
      end
      
      for _, ft in ipairs({ "typescript", "typescriptreact", "javascript", "javascriptreact" }) do
        dap.configurations[ft] = dap.configurations[ft] or {}
        table.insert(dap.configurations[ft], {
          type = "pwa-node",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
        })
        table.insert(dap.configurations[ft], {
          type = "pwa-node",
          request = "launch",
          name = "Jest current file",
          runtimeExecutable = "node",
          runtimeArgs = { "./node_modules/jest/bin/jest.js", "${file}", "--runInBand" },
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
        })
      end
    end,
  },
  { "nvim-neotest/neotest" },
  { "nvim-neotest/neotest-python" },
  { "haydenmeade/neotest-jest" },
}