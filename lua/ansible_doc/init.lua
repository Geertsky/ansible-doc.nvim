local M = {}

-- -----------------------
-- Defaults / configuration
-- -----------------------
M.opts = {
  -- default window settings
  window = {
    kind = "float",
    width = 80,
    height = 24,
    border = "rounded",
    style = "minimal",
  },
  -- List of ansible-doc plugin types to probe.
  types = {
    "become", "cache", "callback", "cliconf", "connection", "httpapi", "inventory",
    "lookup", "netconf", "shell", "vars", "module", "strategy", "test", "filter", "role", "keyword",
  },

  -- Limit concurrent `ansible-doc` processes.
  max_jobs = 6,

  -- Open docs in a split. Use "vsplit" if you prefer.
  open_cmd = "botright split",

  -- Add these env vars to the child process.
  env = {
    PAGER = "cat",
    NO_COLOR = "1",
    TERM = "dumb",
  },
}

-- -----------------------
-- Small helpers
-- -----------------------
local function push(t, s)
  t[#t + 1] = (s == nil and "" or tostring(s)):gsub("\r?\n", " ")
end

local function split_lines(s)
  if type(s) ~= "string" or s == "" then return {} end
  local out = {}
  for _, l in ipairs(vim.split(s, "\n", { plain = true })) do
    out[#out + 1] = l:gsub("\r$", "")
  end
  return out
end

local function normalize_desc(d)
  if type(d) == "string" then return d end
  if type(d) == "table" then
    local acc = {}
    for _, x in ipairs(d) do acc[#acc + 1] = tostring(x) end
    return table.concat(acc, "\n")
  end
  return ""
end

local function inspect_one_line(v)
  local ok, s = pcall(vim.inspect, v, { newline = " ", indent = "" })
  if not ok then s = tostring(v) end
  return s:gsub("\r?\n", " ")
end

local function fmt_choices(c)
  if type(c) ~= "table" then return nil end
  local acc = {}
  for _, v in ipairs(c) do acc[#acc + 1] = tostring(v) end
  return #acc > 0 and table.concat(acc, ", ") or nil
end

local function sorted_keys(tbl)
  local keys = {}
  for k in pairs(tbl or {}) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

-- -----------------------
-- Markdown renderer
-- -----------------------
local function render_markdown(fqcn, plug_type, obj)
  local doc = obj.doc or obj
  local lines = {}

  push(lines, "# " .. (doc.module or doc.name or fqcn or "") .. " (" .. plug_type .. ")")
  if fqcn and fqcn ~= (doc.module or doc.name) then
    push(lines, "**FQCN:** " .. fqcn)
  end

  local short = doc.short_description or normalize_desc(doc.description)
  if short ~= "" then
    push(lines, "")
    for _, l in ipairs(split_lines(short)) do push(lines, l) end
  end

  if doc.version_added then
    push(lines, "")
    push(lines, "**version_added:** " .. tostring(doc.version_added))
  end

  if type(doc.options) == "table" and next(doc.options) then
    push(lines, "")
    push(lines, "## Options")
    for _, opt in ipairs(sorted_keys(doc.options)) do
      local spec = doc.options[opt]
      push(lines, "")
      push(lines, "### " .. opt)

      local meta = {}
      if spec.type then meta[#meta + 1] = "`" .. tostring(spec.type) .. "`" end
      if spec.required ~= nil then meta[#meta + 1] = "required: " .. tostring(spec.required) end
      if spec.default ~= nil then meta[#meta + 1] = "default: " .. inspect_one_line(spec.default) end
      local ch = fmt_choices(spec.choices); if ch then meta[#meta + 1] = "choices: " .. ch end
      if #meta > 0 then push(lines, "*(" .. table.concat(meta, " · ") .. ")*") end

      local desc = normalize_desc(spec.description)
      if desc ~= "" then
        for _, l in ipairs(split_lines(desc)) do push(lines, l) end
      end
    end
  end

  if type(obj["return"]) == "table" and next(obj["return"]) then
    push(lines, "")
    push(lines, "## Return values")
    for _, name in ipairs(sorted_keys(obj["return"])) do
      local spec = obj["return"][name]
      push(lines, "")
      push(lines, "### " .. name)
      if spec.type then push(lines, "type: `" .. tostring(spec.type) .. "`") end
      if spec.returned then
        for _, l in ipairs(split_lines("returned: " .. normalize_desc(spec.returned))) do push(lines, l) end
      end
      if spec.sample ~= nil then
        for _, l in ipairs(split_lines("sample: " .. inspect_one_line(spec.sample))) do push(lines, l) end
      end
      if spec.description then
        for _, l in ipairs(split_lines(normalize_desc(spec.description))) do push(lines, l) end
      end
    end
  end

  if type(doc.notes) == "table" and #doc.notes > 0 then
    push(lines, "")
    push(lines, "## Notes")
    for _, n in ipairs(doc.notes) do
      for _, l in ipairs(split_lines("- " .. normalize_desc(n))) do push(lines, l) end
    end
  end

  if type(doc.seealso) == "table" and #doc.seealso > 0 then
    push(lines, "")
    push(lines, "## See also")
    for _, n in ipairs(doc.seealso) do
      if type(n) == "table" and n.module then
        push(lines, "- " .. n.module)
      elseif type(n) == "string" then
        push(lines, "- " .. n)
      end
    end
  end

  if type(obj.examples) == "string" and obj.examples:match("%S") then
    push(lines, "")
    push(lines, "## Examples")
    push(lines, "")
    push(lines, "```yaml")
    for _, l in ipairs(split_lines(obj.examples)) do push(lines, l) end
    push(lines, "```")
  end

  return lines
end

local function pick_entry(json_tbl, keyword)
  if json_tbl[keyword] then return keyword, json_tbl[keyword] end
  for fqcn, val in pairs(json_tbl) do
    local short = fqcn:match("([^.]+)$") or fqcn
    if short == keyword then return fqcn, val end
  end
  for fqcn, val in pairs(json_tbl) do
    local doc = val.doc or val
    if (doc.module or doc.name) == keyword then return fqcn, val end
  end
  return nil, nil
end

local function find_existing_buf(bufname)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == bufname then
      return b
    end
  end
  return nil
end

local function open_float(opts, buf)
  local columns = vim.o.columns
  local lines = vim.o.lines

  local width = math.min(
    opts.window.width or 80,
    math.max(20, columns - 4)
  )

  local height = math.min(
    opts.window.height or 24,
    math.max(5, lines - 4)
  )

  local row = math.floor((lines - height) / 2 - 1)
  local col = math.floor((columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(0, row),
    col = math.max(0, col),
    width = width,
    height = height,
    style = "minimal",
    border = opts.window.border or "rounded",
  })

  vim.wo[win].wrap = true
  vim.wo[win].conceallevel = 2

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, {
    buffer = buf,
    silent = true,
    desc = "Close Ansible documentation",
  })

  return win
end

local function open_entry(opts, entry)
  local bufname = ("ansible-doc://%s/%s"):format(entry.type, entry.fqcn)
  local buf = find_existing_buf(bufname)
  if not buf then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, bufname)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].swapfile = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].modifiable = true
    vim.bo[buf].readonly = true

    local lines = render_markdown(entry.fqcn, entry.type, entry.obj)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end
  if opts.window and opts.window.kind == "float" then
    open_float(opts, buf)
  else
    vim.cmd(opts.open_cmd)
    vim.api.nvim_win_set_buf(0, buf)
  end
end

-- -----------------------
-- Async lookup (bounded concurrency)
-- -----------------------
local function system_ansible_doc(opts, plug_type, kw, cb)
  local args = { "ansible-doc", "-t", plug_type, "-j", kw }
  vim.system(args, { text = true, env = opts.env }, function(res)
    if res.code ~= 0 or not res.stdout or res.stdout == "" then
      return cb(nil)
    end
    local ok, parsed = pcall(vim.json.decode, res.stdout)
    if not ok or type(parsed) ~= "table" then
      return cb(nil)
    end
    local fqcn, obj = pick_entry(parsed, kw)
    if not fqcn then return cb(nil) end
    cb({ type = plug_type, fqcn = fqcn, obj = obj })
  end)
end

function M.lookup_ansible_doc()
  local opts = M.opts

  local kw = vim.fn.expand("<cWORD>"):gsub(":$", "")
  if kw == "" then
    vim.notify("[ansible-doc] No keyword under cursor", vim.log.levels.WARN)
    return
  end

  local results = {}
  local seen = {} -- type|fqcn -> true

  local types = opts.types
  local total = #types
  local finished = 0

  local i = 1
  local running = 0
  local done = false

  local function finalize()
    if done then return end
    done = true

    vim.schedule(function()
      if #results == 0 then
        vim.notify(("[ansible-doc] No docs for %q"):format(kw), vim.log.levels.WARN)
        return
      end

      if #results == 1 then
        open_entry(opts, results[1])
        return
      end

      vim.ui.select(results, {
        prompt = "Select Ansible documentation:",
        format_item = function(item)
          return string.format("%-8s %s", item.type, item.fqcn)
        end,
      }, function(choice)
        if choice then open_entry(opts, choice) end
      end)
    end)
  end

  local function maybe_finish_one()
    finished = finished + 1
    running = math.max(0, running - 1)
    if finished >= total then
      finalize()
      return
    end
    -- continue pumping queue
    vim.schedule(Pump)
  end

  function Pump()
    if done then return end
    while running < opts.max_jobs and i <= total do
      local t = types[i]
      i = i + 1
      running = running + 1

      system_ansible_doc(opts, t, kw, function(entry)
        if entry then
          local key = entry.type .. "|" .. entry.fqcn
          if not seen[key] then
            seen[key] = true
            results[#results + 1] = entry
          end
        end
        maybe_finish_one()
      end)
    end
  end

  Pump()
end

function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, user_opts or {})
end

return M
