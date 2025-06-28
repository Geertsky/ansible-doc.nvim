local M = {}

function M.lookup_ansible_doc()
  local keyword = vim.fn.expand("<cWORD>"):gsub(":$", "")
  vim.api.nvim_echo({{"keyword: " .. keyword, "Normal"}}, true, {})

  if not keyword or keyword == "" then
    print("[WARNING]: No keyword found")
    return
  end

  local types = {
    "become","cache","callback","cliconf","connection","httpapi","inventory",
    "lookup","netconf","shell","vars","module","strategy","test","filter","role","keyword"
  }

  local found = false  -- ensure we act only on first successful result

  for _, t in ipairs(types) do
    local cmd = {"ansible-doc", "-t", t, keyword}
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)

    local output = ""

    local handle
    handle = vim.loop.spawn(cmd[1], {
      args = {cmd[2], cmd[3], cmd[4]},
      stdio = {nil, stdout, stderr},
    }, function()
      stdout:close()
      stderr:close()
      handle:close()
      if not found and output and output:match("%S") and not output:match("^%[WARNING%]:") then
        found = true
        vim.schedule(function()
          vim.cmd("sp term://" .. table.concat(cmd, " "))
        end)
      end
    end)

    stdout:read_start(function(err, data)
      if err then return end
      if data then output = output .. data end
    end)

    stderr:read_start(function(err, data)
      if err then return end
      if data then output = output .. data end
    end)
  end

  -- Fallback warning after delay if no match found
  vim.defer_fn(function()
    if not found then
      print("[WARNING]: No documentation found for keyword '" .. keyword .. "' in any type.")
    end
  end, 3000) -- wait up to 3 seconds
end

function M.setup(opts)
  opts = opts or {}
  vim.keymap.set("n", opts.mapping or "K", M.lookup_ansible_doc, { desc = "Ansible-doc lookup (parallel)" })
end

return M
