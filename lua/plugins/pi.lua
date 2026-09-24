local command = os.getenv("PI_COMMAND") or "pi"
local provider = os.getenv("PI_PROVIDER") or "llama-app"
local model = os.getenv("PI_MODEL") or "ggml-org/gemma-4-E2B-it-GGUF:Q8_0"

return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "ai (pi code)", icon = "󰚩 " },
      },
    },
  },
  {
    name = "pi.nvim",
    dir = vim.fn.stdpath("config") .. "/lua/pi",
    cmd = {
      "PiToggle",
      "PiFloat",
      "PiSendFile",
      "PiSendSelection",
    },
    keys = {
      {
        "<leader>aa",
        function()
          require("pi").toggle()
        end,
        desc = "Abrir/Cerrar Pi Assistant (Split)",
      },
      {
        "<leader>aA",
        function()
          require("pi").toggle(true)
        end,
        desc = "Abrir Pi con contexto del archivo actual (Split)",
      },
      {
        "<leader>af",
        function()
          require("pi").toggle_float()
        end,
        desc = "Abrir/Cerrar Pi Assistant (Flotante)",
      },
      {
        "<leader>aF",
        function()
          require("pi").toggle_float(true)
        end,
        desc = "Abrir Pi con contexto del archivo actual (Flotante)",
      },
      {
        "<leader>ac",
        function()
          require("pi").send_file()
        end,
        desc = "Enviar archivo actual como contexto",
      },
      {
        "<leader>ad",
        function()
          require("pi").send_dir()
        end,
        desc = "Enviar directorio actual como contexto",
      },
      {
        "<leader>as",
        function()
          require("pi").send_selection()
        end,
        mode = "v",
        desc = "Enviar selección visual como contexto",
      },
    },
    opts = {
      auto_context = true, -- Precarga automáticamente el archivo actual al abrir
      split_direction = "vertical",
      command = command,
      command_args = {
        "--provider",
        provider,
        "--model",
        model,
        "--thinking",
        "off",
        "--no-tools",
        "--system-prompt",
        "Eres un asistente de programación y redacción. Tu rol es exclusivamente de chat y asesoría: explica código, responde dudas, sugiere mejoras conceptuales y responde preguntas con base en el contexto proporcionado. No intentes modificar archivos en el sistema ni ejecutar comandos directamente.",
      },
    },
    config = function(_, opts)
      require("pi").setup(opts)
    end,
  },
}
