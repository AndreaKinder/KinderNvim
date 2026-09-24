local endpoint = os.getenv("LLAMA_APP_ENDPOINT")
  or os.getenv("MINUET_AI_ENDPOINT")
  or "http://127.0.0.1:9931/v1/chat/completions"

local api_key = os.getenv("LLAMA_APP_API_KEY")
  or os.getenv("MINUET_AI_API_KEY")
  or "none"

local model = os.getenv("LLAMA_APP_MODEL")
  or os.getenv("MINUET_AI_MODEL")
  or "ggml-org/gemma-4-E2B-it-GGUF:Q8_0"

return {
  "milanglacier/minuet-ai.nvim",
  lazy = false,
  opts = {
    provider = "openai_compatible",
    request_timeout = 4,
    throttle = 1000,
    debounce = 400,
    n_completions = 1,
    context_window = 4096,
    provider_options = {
      openai_compatible = {
        api_key = api_key,
        name = "Local LLM (Llama.app)",
        end_point = endpoint,
        model = model,
        optional = {
          max_tokens = 64,
          top_p = 0.9,
        },
      },
    },
  },
}

