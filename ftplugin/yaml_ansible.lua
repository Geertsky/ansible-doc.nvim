
-- ansible-doc
for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  if map.lhs == "K" and map.mode == "n" then
    vim.keymap.del("n", "K", { buf = 0 })
  end
end
vim.keymap.set("n", "K", function () require("ansible_doc").lookup_ansible_doc() end, { desc = "lookup_ansible_doc", buf = 0 })
