local function get_notes_base()
  local env_path = os.getenv("OBSIDIAN_VAULT_PATH") or os.getenv("NOTES_PATH")
  if env_path and env_path ~= "" then
    return vim.fn.expand(env_path)
  end
  local default_path = "/home/andrea/notes/"
  if vim.fn.isdirectory(default_path) == 0 then
    default_path = vim.fn.expand("~/notes")
  end
  return default_path
end

local function get_workspaces()
  local notes_base = get_notes_base()
  local notes_subdir = os.getenv("OBSIDIAN_NOTES_SUBDIR") or "zettelkasten"

  local workspaces = {
    {
      name = os.getenv("OBSIDIAN_DEFAULT_WORKSPACE") or "notes",
      path = notes_base,
      overrides = {
        notes_subdir = notes_subdir,
      },
    },
  }

  -- 1. Proyectos dentro de la bóveda de notas (notes/projects/*)
  local projects_folder = os.getenv("OBSIDIAN_PROJECTS_FOLDER") or "projects"
  local projects_base = vim.fs.joinpath(notes_base, projects_folder)
  if vim.fn.isdirectory(projects_base) == 1 then
    local project_dirs = vim.fn.glob(projects_base .. "/*", true, true)
    for _, proj_path in ipairs(project_dirs) do
      if vim.fn.isdirectory(proj_path) == 1 then
        local proj_name = vim.fn.fnamemodify(proj_path, ":t")
        table.insert(workspaces, {
          name = "proj-" .. proj_name,
          path = proj_path,
        })
      end
    end
  end

  return workspaces
end

local project_utils = {}

--- Obtiene la lista de proyectos (carpetas en projects/ y workspaces adicionales)
---@return table<{ name: string, path: string, type: "folder"|"workspace", workspace?: any }>
function project_utils.get_projects()
  local ok, obsidian = pcall(require, "obsidian")
  if not ok then
    return {}
  end

  local client = obsidian.get_client()
  if not client then
    return {}
  end

  local projects = {}
  local seen = {}

  -- 1. Carpetas de proyectos dentro de la bóveda
  local vault_dir = tostring(client.dir or get_notes_base())
  local projects_folder = os.getenv("OBSIDIAN_PROJECTS_FOLDER") or "projects"
  local projects_dir = vim.fs.joinpath(vault_dir, projects_folder)

  if vim.fn.isdirectory(projects_dir) == 1 then
    local handle = vim.uv.fs_scandir(projects_dir)
    if handle then
      while true do
        local name, type = vim.uv.fs_scandir_next(handle)
        if not name then
          break
        end
        if type == "directory" and not name:match("^%.") then
          local p_path = vim.fs.joinpath(projects_dir, name)
          seen[p_path] = true
          table.insert(projects, {
            name = name,
            path = p_path,
            type = "folder",
          })
        end
      end
    end
  end

  -- 2. Workspaces adicionales registrados en Obsidian
  if client.opts and client.opts.workspaces then
    local default_ws = os.getenv("OBSIDIAN_DEFAULT_WORKSPACE") or "notes"
    for _, ws in ipairs(client.opts.workspaces) do
      if ws.name ~= default_ws and ws.name ~= ".obsidian.wiki" then
        local ws_path = tostring(ws.path)
        if not seen[ws_path] then
          seen[ws_path] = true
          table.insert(projects, {
            name = ws.name,
            path = ws_path,
            type = "workspace",
            workspace = ws,
          })
        end
      end
    end
  end

  table.sort(projects, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return projects
end

--- Selector interactivo de proyecto
---@param prompt string
---@param allow_new boolean
---@param callback fun(project: { name: string, path: string, type: string, workspace?: any }|nil)
function project_utils.select_project(prompt, allow_new, callback)
  local projects = project_utils.get_projects()
  local items = {}

  if allow_new then
    table.insert(items, { name = "[+ Crear nuevo proyecto]", path = nil, is_new = true })
  end
  for _, p in ipairs(projects) do
    table.insert(items, p)
  end

  if #items == 0 then
    vim.notify("No se encontraron proyectos disponibles.", vim.log.levels.WARN, { title = "Obsidian Proyectos" })
    return
  end

  vim.ui.select(items, {
    prompt = prompt,
    format_item = function(item)
      if item.is_new then
        return item.name
      elseif item.type == "workspace" then
        return "🚀 " .. item.name .. " (" .. item.path .. ")"
      else
        return "📁 " .. item.name
      end
    end,
  }, function(choice)
    if not choice then
      return
    end

    if choice.is_new then
      vim.ui.input({ prompt = "Nombre del nuevo proyecto (kebab-case): " }, function(new_name)
        if not new_name or vim.trim(new_name) == "" then
          return
        end
        local clean_name = new_name:gsub("%s+", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
        local client = require("obsidian").get_client()
        local projects_folder = os.getenv("OBSIDIAN_PROJECTS_FOLDER") or "projects"
        local new_path = vim.fs.joinpath(vault_dir, projects_folder, clean_name)
        if vim.fn.isdirectory(new_path) == 0 then
          vim.fn.mkdir(new_path, "p")
        end
        callback({ name = clean_name, path = new_path, type = "folder" })
      end)
    else
      callback(choice)
    end
  end)
end

--- Asegura que el workspace activo de Obsidian corresponda al proyecto seleccionado
function project_utils.ensure_workspace(project)
  local client = require("obsidian").get_client()
  if not client then
    return
  end

  if project.workspace then
    if client.current_workspace.name ~= project.workspace.name then
      client:switch_workspace(project.workspace.name, { lock = true })
    end
  else
    local Workspace = require("obsidian.workspace")
    local ws = Workspace.get_workspace_for_dir(project.path, client.opts.workspaces)
    if ws and ws.name ~= client.current_workspace.name then
      client:switch_workspace(ws.name, { lock = true })
    end
  end
end

--- Acción 1: Crear nota dentro de un proyecto
function project_utils.create_note()
  project_utils.select_project("Crear nota en proyecto:", true, function(project)
    if not project then
      return
    end

    vim.ui.input({ prompt = "Título / Nombre de la nota (" .. project.name .. "): " }, function(title)
      if not title or vim.trim(title) == "" then
        return
      end

      project_utils.ensure_workspace(project)

      local client = require("obsidian").get_client()
      local note = client:create_note({
        title = title,
        dir = project.path,
      })
      client:open_note(note, { sync = true })
      vim.notify(
        "Nota creada en " .. project.name .. "/" .. note.path.name,
        vim.log.levels.INFO,
        { title = "Obsidian" }
      )
    end)
  end)
end

--- Acción 2: Buscar notas exclusivas de un proyecto (Quick Switch)
function project_utils.find_notes()
  project_utils.select_project("Buscar notas del proyecto:", false, function(project)
    if not project then
      return
    end
    project_utils.ensure_workspace(project)

    local ok_snacks, snacks = pcall(require, "snacks")
    if ok_snacks and snacks.picker then
      snacks.picker.files({
        cwd = project.path,
        title = "Notas: " .. project.name,
      })
      return
    end

    local ok_tele, builtin = pcall(require, "telescope.builtin")
    if ok_tele then
      builtin.find_files({
        cwd = project.path,
        prompt_title = "Notas: " .. project.name,
      })
      return
    end

    local ok_fzf, fzf = pcall(require, "fzf-lua")
    if ok_fzf then
      fzf.files({
        cwd = project.path,
        prompt = "Notas " .. project.name .. "> ",
      })
      return
    end

    local client = require("obsidian").get_client()
    local picker = client:picker()
    if picker then
      picker:find_files({
        dir = project.path,
        prompt_title = "Notas: " .. project.name,
      })
    end
  end)
end

--- Acción 3: Búsqueda de texto (Grep) exclusiva en un proyecto
function project_utils.grep_notes()
  project_utils.select_project("Buscar texto en proyecto:", false, function(project)
    if not project then
      return
    end
    project_utils.ensure_workspace(project)

    local ok_snacks, snacks = pcall(require, "snacks")
    if ok_snacks and snacks.picker then
      snacks.picker.grep({
        cwd = project.path,
        title = "Grep en " .. project.name,
      })
      return
    end

    local ok_tele, builtin = pcall(require, "telescope.builtin")
    if ok_tele then
      builtin.live_grep({
        cwd = project.path,
        prompt_title = "Grep en " .. project.name,
      })
      return
    end

    local ok_fzf, fzf = pcall(require, "fzf-lua")
    if ok_fzf then
      fzf.live_grep({
        cwd = project.path,
        prompt = "Grep " .. project.name .. "> ",
      })
      return
    end

    local client = require("obsidian").get_client()
    local picker = client:picker()
    if picker then
      picker:grep({
        dir = project.path,
        prompt_title = "Grep en " .. project.name,
      })
    end
  end)
end

return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>o", group = "obsidian", icon = "󱞁 " },
        { "<leader>op", group = "proyectos", icon = " " },
      },
    },
  },
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    cmd = {
      "ObsidianBacklinks",
      "ObsidianCheck",
      "ObsidianDebug",
      "ObsidianExtractNote",
      "ObsidianFollowLink",
      "ObsidianLink",
      "ObsidianLinkNew",
      "ObsidianLinks",
      "ObsidianNew",
      "ObsidianNewFromTemplate",
      "ObsidianOpen",
      "ObsidianPasteImg",
      "ObsidianQuickSwitch",
      "ObsidianRename",
      "ObsidianSearch",
      "ObsidianTags",
      "ObsidianTemplate",
      "ObsidianToday",
      "ObsidianTomorrow",
      "ObsidianToggleCheckbox",
      "ObsidianWorkspace",
      "ObsidianYesterday",
      "ObsidianDailies",
      "ObsidianTOC",
    },
    event = {
      "BufReadPre *.md",
      "BufNewFile *.md",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<leader>ow", "<cmd>ObsidianWorkspace<cr>", desc = "Cambiar de bóveda (Workspace)" },
      { "<leader>of", "<cmd>ObsidianQuickSwitch<cr>", desc = "Buscar nota (por alias/título)" },
      { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Buscar texto en notas (Grep)" },
      { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "Crear nueva nota (Zettelkasten)" },
      { "<leader>od", "<cmd>ObsidianToday<cr>", desc = "Nota diaria (Hoy)" },
      { "<leader>oy", "<cmd>ObsidianYesterday<cr>", desc = "Nota diaria (Ayer)" },
      { "<leader>om", "<cmd>ObsidianTomorrow<cr>", desc = "Nota diaria (Mañana)" },
      { "<leader>oc", "<cmd>Calendar<cr>", desc = "Calendario de notas diarias" },
      { "<leader>ot", "<cmd>ObsidianTags<cr>", desc = "Buscar por etiquetas (#tags)" },
      { "<leader>ob", "<cmd>ObsidianBacklinks<cr>", desc = "Ver enlaces entrantes (Backlinks)" },
      { "<leader>ox", "<cmd>ObsidianToggleCheckbox<cr>", desc = "Alternar casilla [-] / [x]" },
      { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Abrir en Obsidian Desktop" },
      { "<leader>oT", "<cmd>ObsidianTemplate<cr>", desc = "Insertar plantilla" },
      { "<leader>oi", "<cmd>ObsidianPasteImg<cr>", desc = "Pegar imagen desde portapapeles" },
      { "<leader>ol", "<cmd>ObsidianLink<cr>", desc = "Vincular texto a nota", mode = "v" },
      { "<leader>onl", "<cmd>ObsidianLinkNew<cr>", desc = "Crear y vincular nueva nota", mode = "v" },
      -- Submenú de Proyectos (<leader>op)
      {
        "<leader>opn",
        function()
          require("lazy").load({ plugins = { "obsidian.nvim" } })
          project_utils.create_note()
        end,
        desc = "Crear nota en proyecto",
      },
      {
        "<leader>opf",
        function()
          require("lazy").load({ plugins = { "obsidian.nvim" } })
          project_utils.find_notes()
        end,
        desc = "Buscar notas en proyecto (Quick switch)",
      },
      {
        "<leader>ops",
        function()
          require("lazy").load({ plugins = { "obsidian.nvim" } })
          project_utils.grep_notes()
        end,
        desc = "Buscar texto en proyecto (Grep)",
      },
    },
    opts = function()
      return {
        legacy_commands = false,
        workspaces = get_workspaces(),
        notes_subdir = os.getenv("OBSIDIAN_NOTES_SUBDIR") or "zettelkasten",
        new_notes_location = "notes_subdir",

        -- Notas diarias (Journal / Bitácora)
        daily_notes = {
          folder = os.getenv("OBSIDIAN_DAILY_FOLDER") or "journal",
          date_format = "%Y-%m-%d",
          alias_format = "%Y-%m-%d",
          template = os.getenv("OBSIDIAN_DAILY_TEMPLATE") or "plantilla-diaria.md",
          default_tags = { "daily-notes" },
        },

        -- Plantillas oficiales de la bóveda
        templates = {
          folder = os.getenv("OBSIDIAN_TEMPLATES_FOLDER") or "templates",
          date_format = "%Y-%m-%d",
          time_format = "%H:%M",
          substitutions = {},
        },

        -- Gestión de imágenes y recursos adjuntos
        attachments = {
          folder = os.getenv("OBSIDIAN_ATTACHMENTS_FOLDER") or "assets",
          ---@param client obsidian.Client
          ---@param path obsidian.Path the absolute path to the image file
          ---@return string
          img_text_func = function(client, path)
            path = client:vault_relative_path(path) or path
            return string.format("![%s](%s)", path.name, path)
          end,
        },

        -- Generador de IDs conforme a AGENTS.md (<TIMESTAMP>-<ACRONIMO/TITULO>)
        note_id_func = function(title)
          local suffix = ""
          if title ~= nil and title ~= "" then
            -- Transformar título a kebab-case limpio
            suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
          else
            -- 4 letras mayúsculas aleatorias (ej. 1787692393-AENB)
            for _ = 1, 4 do
              suffix = suffix .. string.char(math.random(65, 90))
            end
          end
          return tostring(os.time()) .. "-" .. suffix
        end,

        ui = {
          enable = false, -- Desactivado para que render-markdown.nvim maneje todo el renderizado
        },

        -- Frontmatter estructurado según AGENTS.md
        frontmatter = {
          enabled = true,
          func = function(note)
            -- Añadir el título de la nota como alias si está presente
            if note.title then
              note:add_alias(note.title)
            end

            local out = {
              id = note.id,
              description = (note.metadata and note.metadata.description) or "",
              aliases = note.aliases or {},
              tags = note.tags or {},
            }

            -- Preservar metadatos adicionales si existen (ej. events, lastSync, etc.)
            if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
              for k, v in pairs(note.metadata) do
                if k ~= "title" and out[k] == nil then
                  out[k] = v
                end
              end
            end

            return out
          end,
          sort = { "id", "description", "events", "aliases", "tags" },
        },
      }
    end,
  },
}
