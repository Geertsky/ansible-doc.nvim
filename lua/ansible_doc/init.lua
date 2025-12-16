local M = {}

-- ---------- small helpers (newline-safe) ----------
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

-- ---------- renderer ----------
local function render_markdown(fqcn, plug_type, obj)
  local doc = obj.doc or obj
  local lines = {}

  push(lines, "# " .. (doc.module or doc.name or fqcn or "") .. " (" .. plug_type .. ")")
  if fqcn and fqcn ~= (doc.module or doc.name) then push(lines, "**FQCN:** " .. fqcn) end

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
    push(lines, ""); push(lines, "## Options")
    for opt, spec in pairs(doc.options) do
      push(lines, ""); push(lines, "### " .. opt)
      local meta = {}
      if spec.type     then meta[#meta + 1] = "`" .. tostring(spec.type) .. "`" end
      if spec.required ~= nil then meta[#meta + 1] = "required: " .. tostring(spec.required) end
      if spec.default  ~= nil then meta[#meta + 1] = "default: " .. inspect_one_line(spec.default) end
      local ch = fmt_choices(spec.choices); if ch then meta[#meta + 1] = "choices: " .. ch end
      if #meta > 0 then push(lines, "*(" .. table.concat(meta, " · ") .. ")*") end
      local desc = normalize_desc(spec.description)
      if desc ~= "" then for _, l in ipairs(split_lines(desc)) do push(lines, l) end end
    end
  end

  if type(obj["return"]) == "table" and next(obj["return"]) then
    push(lines, ""); push(lines, "## Return values")
    for name, spec in pairs(obj["return"]) do
      push(lines, ""); push(lines, "### " .. name)
      if spec.type then push(lines, "type: `" .. tostring(spec.type) .. "`") end
      if spec.returned then for _, l in ipairs(split_lines("returned: " .. normalize_desc(spec.returned))) do push(lines, l) end end
      if spec.sample ~= nil then for _, l in ipairs(split_lines("sample: " .. inspect_one_line(spec.sample))) do push(lines, l) end end
      if spec.description then for _, l in ipairs(split_lines(normalize_desc(spec.description))) do push(lines, l) end end
    end
  end

  if type(doc.notes) == "table" and #doc.notes > 0 then
    push(lines, ""); push(lines, "## Notes")
    for _, n in ipairs(doc.notes) do for _, l in ipairs(split_lines("- " .. normalize_desc(n))) do push(lines, l) end end
  end

  if type(doc.seealso) == "table" and #doc.seealso > 0 then
    push(lines, ""); push(lines, "## See also")
    for _, n in ipairs(doc.seealso) do
      if type(n) == "table" and n.module then push(lines, "- " .. n.module)
      elseif type(n) == "string" then push(lines, "- " .. n) end
    end
  end

  if type(obj.examples) == "string" and obj.examples:match("%S") then
    push(lines, ""); push(lines, "## Examples"); push(lines, ""); push(lines, "```yaml")
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

-- ---------- main ----------
local function open_entry(entry)
  local lines = render_markdown(entry.fqcn, entry.type, entry.obj)

  vim.schedule(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(
      buf,
      ("ansible-doc://%s/%s"):format(entry.type, entry.fqcn)
    )
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.cmd("botright split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].modifiable = false
  end)
end


function M.lookup_ansible_doc()
  local finalized = false
  local kw = vim.fn.expand("<cWORD>"):gsub(":$", "")
  if kw == "" then
    vim.notify("[ansible-doc] No keyword under cursor", vim.log.levels.WARN)
    return
  end

  local types = {
    "become","cache","callback","cliconf","connection","httpapi","inventory",
    "lookup","netconf","shell","vars","module","strategy","test","filter","role","keyword"
  }

  local results = {}
  local pending = #types

  local function maybe_finish()
  pending = pending - 1
  if pending > 0 or finalized then
    return
  end
  finalized = true

  -- defer *all* UI work
  vim.schedule(function()
    if #results == 0 then
      vim.notify(("[ansible-doc] No docs for %q"):format(kw), vim.log.levels.WARN)
      return
    end

    if #results == 1 then
      open_entry(results[1])
      return
    end

    vim.ui.select(results, {
      prompt = "Select Ansible documentation:",
      format_item = function(item)
        return string.format("%-8s %s", item.type, item.fqcn)
      end,
    }, function(choice)
      if choice then
        open_entry(choice)
      end
    end)
  end)
end


  for _, t in ipairs(types) do
    local args = { "ansible-doc", "-t", t, "-j", kw }
    vim.system(args, {
      text = true,
      env = { PAGER = "cat", NO_COLOR = "1", TERM = "dumb" },
    }, function(res)
      if res.code ~= 0 or not res.stdout or res.stdout == "" then
        return maybe_finish()
      end

      local ok, parsed = pcall(vim.json.decode, res.stdout)
      if not ok or type(parsed) ~= "table" then
        return maybe_finish()
      end

      local fqcn, obj = pick_entry(parsed, kw)
      if fqcn then
        results[#results + 1] = {
          type = t,
          fqcn = fqcn,
          obj  = obj,
        }
      end

      maybe_finish()
    end)
  end
end

function M.setup(opts)
  opts = opts or {}
  vim.keymap.set("n", opts.mapping or "K", M.lookup_ansible_doc, { desc = "Ansible-doc lookup (JSON)" })
end

return M
