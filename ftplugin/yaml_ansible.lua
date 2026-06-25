local ansible_doc = require("ansible_doc")
local mapping = ansible_doc.opts.mapping

if mapping == false or mapping == nil or mapping == "" then
  return
end

vim.keymap.set("n", mapping, function()
  ansible_doc.lookup_ansible_doc()
end, {
  buffer = true,
  silent = true,
  desc = "Show Ansible documentation",
})
