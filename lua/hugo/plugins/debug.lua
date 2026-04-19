local debug_config = {
  "mfussenegger/nvim-dap",
  dependencies = {
    {
      "rcarriga/nvim-dap-ui",
      dependencies = { "nvim-neotest/nvim-nio" },
    },
    "theHamsta/nvim-dap-virtual-text",
    "jay-babu/mason-nvim-dap.nvim",
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    require("mason-nvim-dap").setup({
      ensure_installed = { "js-debug-adapter", "delve" },
    })

    dapui.setup()
    require("nvim-dap-virtual-text").setup()

    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- pwa-node adapter (from js-debug-adapter)
    dap.adapters["pwa-node"] = {
      type = "server",
      host = "127.0.0.1",
      port = "${port}",
      executable = {
        command = "node",
        args = {
          vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
          "${port}"
        },
      },
    }

    dap.adapters.node = dap.adapters["pwa-node"]

    dap.configurations.javascript = {
      {
        name = "Launch current file",
        type = "pwa-node",
        request = "launch",
        program = "${file}",
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
        protocol = "inspector",
        console = "integratedTerminal",
      },
      {
        name = "Attach to process",
        type = "pwa-node",
        request = "attach",
        processId = require("dap.utils").pick_process,
      },
    }
    dap.configurations.typescript = dap.configurations.javascript

    -- Go (Delve) adapter
    dap.adapters.delve = {
      type = "server",
      port = "${port}",
      executable = {
        command = "dlv",
        args = { "dap", "-l", "127.0.0.1:${port}" },
      },
    }

    dap.configurations.go = {
      {
        name = "Launch file",
        type = "delve",
        request = "launch",
        program = "${file}",
      },
      {
        name = "Launch package",
        type = "delve",
        request = "launch",
        program = "${fileDirname}",
      },
      {
        name = "Debug test",
        type = "delve",
        request = "launch",
        mode = "test",
        program = "${file}",
      },
      {
        name = "Debug test (package)",
        type = "delve",
        request = "launch",
        mode = "test",
        program = "./${relativeFileDirname}",
      },
    }

    -- Keymaps
    vim.keymap.set("n", "<F5>", dap.continue)
    vim.keymap.set("n", "<F9>", dap.toggle_breakpoint)
    vim.keymap.set("n", "<F10>", dap.step_over)
    vim.keymap.set("n", "<F11>", dap.step_into)
    vim.keymap.set("n", "<F12>", dap.step_out)
  end,
}

return debug_config
