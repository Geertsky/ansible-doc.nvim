# ansible-doc.nvim

A small Neovim plugin to look up documentation for Ansible modules, plugins, or keywords, trying all `ansible-doc -t` types in parallel.

## 🚀 Features

- Extracts the word under your cursor.
- Runs `ansible-doc -t <type> <keyword>` for all types in parallel.
- Runs ansible-doc -t <type> <keyword> for all types in parallel.
- If multiple types match, prompts you to select which hit to open.
- Opens a terminal split with the first successful documentation match.
- Falls back with a warning if no match is found.

## 🔧 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Geertsky/ansible-doc.nvim",
  config = function()
    require("ansible_doc").setup({
      mapping = "K"  -- or any other keymap you like
    })
  end,
}

