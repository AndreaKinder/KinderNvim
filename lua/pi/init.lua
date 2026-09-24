local M = {}

local default_config = {
  split_direction = "vertical", -- "vertical" o "horizontal"
  command = os.getenv("PI_COMMAND") or "pi",
  command_args = {
    "--provider",
    os.getenv("PI_PROVIDER") or "mlx-local",
    "--model",
    os.getenv("PI_MODEL") or "mlx-community/Qwen2.5-Coder-7B-Instruct-4bit",
    "--thinking",
    "off",
  },
  server_url = os.getenv("MLX_SERVER_URL") or os.getenv("PI_SERVER_URL") or "http://127.0.0.1:8080/v1/models",
  auto_context = false, -- Si es true, siempre precarga el archivo actual al abrir
  float_opts = {
    width = 0.85,
    height = 0.85,
    border = "rounded",
    title = " 🥧 Pi Code (MLX Local) ",
  },
}

local config = {}

local state = {
  bufnr = nil,
  chan_id = nil,
  split_win = nil,
  float_win = nil,
}

local function check_mlx_server()
  if vim.fn.executable("curl") ~= 1 then
    return
  end
  vim.fn.jobstart({ "curl", "-fsS", "-m", "1", config.server_url or default_config.server_url }, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          vim.notify(
            "Aviso: El servidor MLX local no responde en " .. (config.server_url or default_config.server_url) .. ".\nInícialo con: mlx-server",
            vim.log.levels.WARN,
            { title = "Pi Code" }
          )
        end)
      end
    end,
  })
end

local function build_command()
  local cmd = config.command or "pi"
  local cmd_list = { cmd }
  if config.command_args and type(config.command_args) == "table" then
    for _, arg in ipairs(config.command_args) do
      table.insert(cmd_list, arg)
    end
  end
  return cmd_list
end

local function close_window(win_type)
  if win_type == "split" and state.split_win and vim.api.nvim_win_is_valid(state.split_win) then
    vim.api.nvim_win_close(state.split_win, true)
    state.split_win = nil
  elseif win_type == "float" and state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
    vim.api.nvim_win_close(state.float_win, true)
    state.float_win = nil
  end
end

local function ensure_buffer()
  if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
    return state.bufnr
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  pcall(vim.api.nvim_buf_set_name, buf, "pi://terminal")
  state.bufnr = buf
  return buf
end

local function launch_terminal_if_needed(current_file_ctx)
  if state.chan_id and vim.fn.jobwait({ state.chan_id }, 0)[1] == -1 then
    return
  end

  local cmd_list = build_command()
  local main_cmd = cmd_list[1]

  if vim.fn.executable(main_cmd) ~= 1 then
    vim.notify(
      "Pi Code ('" .. main_cmd .. "') no encontrado en PATH. Asegúrate de tener instalado pi.",
      vim.log.levels.ERROR,
      { title = "Pi Code" }
    )
  end

  check_mlx_server()

  state.chan_id = vim.fn.termopen(cmd_list, {
    env = { ["EDITOR"] = "nvim" },
    on_exit = function()
      if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
        pcall(vim.api.nvim_buf_delete, state.bufnr, { force = true })
      end
      state.bufnr = nil
      state.chan_id = nil
      state.split_win = nil
      state.float_win = nil
    end,
  })

  -- Si se solicitó precargar el archivo actual como contexto
  if current_file_ctx and current_file_ctx ~= "" then
    vim.defer_fn(function()
      if state.chan_id then
        vim.api.nvim_chan_send(state.chan_id, current_file_ctx .. "\n")
      end
    end, 600)
  end
end

local function get_current_file_context()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" or filepath:match("^pi://") then
    return nil
  end

  local relpath = vim.fn.fnamemodify(filepath, ":.")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local ft = vim.bo.filetype
  return string.format(
    "Contexto del archivo actual (`%s`):\n```%s\n%s\n```\n¿En qué me puedes asesorar sobre este archivo?",
    relpath,
    ft,
    table.concat(lines, "\n")
  )
end

function M.open_split(preload_file)
  if state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
    close_window("float")
  end

  local file_ctx = (preload_file or config.auto_context) and get_current_file_context() or nil

  if state.split_win and vim.api.nvim_win_is_valid(state.split_win) then
    vim.api.nvim_set_current_win(state.split_win)
    if file_ctx and state.chan_id then
      vim.api.nvim_chan_send(state.chan_id, file_ctx .. "\n")
      vim.notify("Pi Assistant: Archivo actual cargado al contexto", vim.log.levels.INFO)
    end
    vim.cmd("startinsert")
    return
  end

  if config.split_direction == "horizontal" then
    vim.cmd("split")
  else
    vim.cmd("vsplit")
  end

  local new_win = vim.api.nvim_get_current_win()
  local buf = ensure_buffer()
  vim.api.nvim_win_set_buf(new_win, buf)
  state.split_win = new_win

  launch_terminal_if_needed(file_ctx)
  vim.cmd("startinsert")
end

function M.toggle(preload_file)
  local cur_win = vim.api.nvim_get_current_win()
  if state.split_win and vim.api.nvim_win_is_valid(state.split_win) then
    if cur_win == state.split_win then
      close_window("split")
    else
      vim.api.nvim_set_current_win(state.split_win)
      vim.cmd("startinsert")
    end
  else
    M.open_split(preload_file)
  end
end

function M.open_float(preload_file)
  if state.split_win and vim.api.nvim_win_is_valid(state.split_win) then
    close_window("split")
  end

  local file_ctx = (preload_file or config.auto_context) and get_current_file_context() or nil

  if state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
    vim.api.nvim_set_current_win(state.float_win)
    if file_ctx and state.chan_id then
      vim.api.nvim_chan_send(state.chan_id, file_ctx .. "\n")
      vim.notify("Pi Assistant: Archivo actual cargado al contexto", vim.log.levels.INFO)
    end
    vim.cmd("startinsert")
    return
  end

  local f_opts = config.float_opts or default_config.float_opts
  local total_cols = vim.o.columns
  local total_lines = vim.o.lines

  local width = math.floor(total_cols * (f_opts.width or 0.85))
  local height = math.floor(total_lines * (f_opts.height or 0.85))
  local row = math.floor((total_lines - height) / 2)
  local col = math.floor((total_cols - width) / 2)

  local buf = ensure_buffer()

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = f_opts.border or "rounded",
    title = f_opts.title or " 🥧 Pi Code (MLX Local) ",
    title_pos = "center",
  })
  state.float_win = win

  launch_terminal_if_needed(file_ctx)
  vim.cmd("startinsert")
end

function M.toggle_float(preload_file)
  local cur_win = vim.api.nvim_get_current_win()
  if state.float_win and vim.api.nvim_win_is_valid(state.float_win) then
    if cur_win == state.float_win then
      close_window("float")
    else
      vim.api.nvim_set_current_win(state.float_win)
      vim.cmd("startinsert")
    end
  else
    M.open_float(preload_file)
  end
end

function M.send_text(text)
  if not text or text == "" then
    return
  end

  local is_open = (state.split_win and vim.api.nvim_win_is_valid(state.split_win))
    or (state.float_win and vim.api.nvim_win_is_valid(state.float_win))

  if not is_open then
    M.open_split()
  end

  if state.chan_id then
    vim.api.nvim_chan_send(state.chan_id, text .. "\n")
  end
end

function M.send_file()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.notify("Pi Assistant: El buffer actual no tiene archivo asociado.", vim.log.levels.WARN)
    return
  end

  local relpath = vim.fn.fnamemodify(filepath, ":.")
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local ft = vim.bo.filetype
  local content = string.format("Contexto del archivo actual (`%s`):\n```%s\n%s\n```\n¿En qué me puedes asesorar sobre este archivo?", relpath, ft, table.concat(lines, "\n"))

  M.send_text(content)
  vim.notify("Pi Assistant: Archivo actual cargado al contexto (" .. relpath .. ")", vim.log.levels.INFO)
end

function M.send_dir()
  local cwd = vim.fn.getcwd()
  local rel_cwd = vim.fn.fnamemodify(cwd, ":~")
  local files = vim.fn.globpath(cwd, "*", false, true)
  local file_list = {}
  for _, f in ipairs(files) do
    local fname = vim.fn.fnamemodify(f, ":t")
    if not fname:match("^%.") then
      local is_dir = vim.fn.isdirectory(f) == 1
      table.insert(file_list, (is_dir and "📁 " or "📄 ") .. fname)
    end
  end

  local content = string.format("Contexto del directorio de trabajo actual (`%s`):\nContenido:\n%s\n\n¿En qué me puedes ayudar en este proyecto?", rel_cwd, table.concat(file_list, "\n"))
  M.send_text(content)
  vim.notify("Pi Assistant: Estructura de directorio enviada (" .. rel_cwd .. ")", vim.log.levels.INFO)
end

function M.send_selection()
  vim.cmd([[execute "normal! \<ESC>"]])

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  if start_line == 0 or end_line == 0 or start_line > end_line then
    vim.notify("Pi Assistant: No hay selección visual válida.", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype
  local header = ""
  if filepath ~= "" then
    local relpath = vim.fn.fnamemodify(filepath, ":.")
    header = string.format("Fragmento de `%s` (L%d-L%d):\n", relpath, start_line, end_line)
  end

  local content = header .. "```" .. ft .. "\n" .. table.concat(lines, "\n") .. "\n```\n¿Qué opinas de este fragmento?"
  M.send_text(content)
  vim.notify("Pi Assistant: Selección enviada (" .. #lines .. " líneas)", vim.log.levels.INFO)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})

  -- Comandos de usuario principales
  vim.api.nvim_create_user_command("PiToggle", function()
    M.toggle()
  end, { desc = "Abrir/Cerrar Pi Code (Split)" })

  vim.api.nvim_create_user_command("PiFloat", function()
    M.toggle_float()
  end, { desc = "Abrir/Cerrar Pi Code (Flotante)" })

  vim.api.nvim_create_user_command("PiSendFile", function()
    M.send_file()
  end, { desc = "Enviar archivo actual a Pi Code" })

  vim.api.nvim_create_user_command("PiSendDir", function()
    M.send_dir()
  end, { desc = "Enviar contexto de directorio/proyecto actual a Pi Code" })

  vim.api.nvim_create_user_command("PiSendSelection", function()
    M.send_selection()
  end, { range = true, desc = "Enviar selección visual a Pi Code" })
end

return M
