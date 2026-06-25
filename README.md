# ansible-doc.nvim

A small Neovim plugin for looking up Ansible documentation from inside Ansible YAML files.

`ansible-doc.nvim` reads the keyword under the cursor, runs `ansible-doc` for the configured Ansible documentation types in parallel, and opens the matching documentation in Neovim.

If exactly one match is found, it is opened directly. If multiple matches are found, the plugin asks which result to open.

## Features

* Looks up the keyword under the cursor.
* Supports fully qualified Ansible names such as `ansible.builtin.import_tasks`.
* Runs `ansible-doc -t <type> -j <keyword>` for multiple Ansible documentation types.
* Runs lookups in parallel with a configurable concurrency limit.
* Prompts with `vim.ui.select()` when multiple documentation types match.
* Renders documentation as Markdown.
* Installs a buffer-local mapping for Ansible YAML buffers.

## Requirements

* Neovim with `vim.system()`
* Ansible installed
* `ansible-doc` available in `$PATH`

Check inside Neovim:

```vim
:echo executable("ansible-doc")
```

Expected result:

```text
1
```

## Installation

### Native `vim.pack`

```lua
vim.pack.add({
  {
    src = "git@github.com:Geertsky/ansible-doc.nvim.git",
    name = "ansible-doc.nvim",
  },
})

require("ansible_doc").setup()
```

For a local development checkout:

```lua
vim.pack.add({
  {
    src = "file:///home/geert/git/ansible-doc.nvim",
    name = "ansible-doc.nvim",
  },
})

require("ansible_doc").setup()
```

### lazy.nvim

```lua
{
  "Geertsky/ansible-doc.nvim",
  config = function()
    require("ansible_doc").setup()
  end,
}
```

## Help documentation

The plugin ships Vim help documentation in `doc/`.

After installing or updating the plugin, generate helptags:

```vim
:helptags ALL
```

Then open the help with:

```vim
:help ansible-doc.nvim
```

Many plugin managers generate helptags automatically. With native packages, you may need to run `:helptags ALL` yourself after installing or updating the plugin.

## Usage

Open an Ansible YAML buffer and place the cursor on an Ansible keyword or fully qualified collection name.

Example:

```yaml
- name: Import tasks
  ansible.builtin.import_tasks:
    file: tasks/install.yml
```

With the cursor on `ansible.builtin.import_tasks`, press:

```text
K
```

By default, `K` is mapped buffer-locally for Ansible YAML buffers.

You can also call the lookup function directly:

```vim
:lua require("ansible_doc").lookup_ansible_doc()
```

## Default mapping

By default, `ansible-doc.nvim` installs this buffer-local mapping for Ansible YAML buffers:

```text
K
```

The mapping calls:

```lua
require("ansible_doc").lookup_ansible_doc()
```

This mapping is buffer-local. It does not affect non-Ansible buffers.

## Configuration

Minimal setup:

```lua
require("ansible_doc").setup()
```

Default options:

```lua
require("ansible_doc").setup({
  mapping = "K",

  window = {
    kind = "float",
    width = 80,
    height = 24,
    border = "rounded",
    style = "minimal",
  },

  types = {
    "become",
    "cache",
    "callback",
    "cliconf",
    "connection",
    "httpapi",
    "inventory",
    "lookup",
    "netconf",
    "shell",
    "vars",
    "module",
    "strategy",
    "test",
    "filter",
    "role",
    "keyword",
  },

  max_jobs = 6,

  open_cmd = "botright split",

  env = {
    PAGER = "cat",
    NO_COLOR = "1",
    TERM = "dumb",
  },
})
```

## Mapping configuration

Change the Ansible YAML buffer-local mapping:

```lua
require("ansible_doc").setup({
  mapping = "<leader>ad",
})
```

Disable the default mapping:

```lua
require("ansible_doc").setup({
  mapping = false,
})
```

After disabling the default mapping, define your own mapping in your personal configuration if desired:

```lua
vim.keymap.set("n", "<leader>ad", function()
  require("ansible_doc").lookup_ansible_doc()
end, {
  buffer = true,
  silent = true,
  desc = "Show Ansible documentation",
})
```

For a buffer-local Ansible mapping in your own config, place it in the filetype configuration that matches your Ansible YAML setup, for example:

```text
after/ftplugin/yaml_ansible.lua
```

## Window configuration

Documentation opens in a floating window by default.

Change the floating window size:

```lua
require("ansible_doc").setup({
  window = {
    width = 100,
    height = 32,
  },
})
```

Change the border:

```lua
require("ansible_doc").setup({
  window = {
    border = "single",
  },
})
```

Use a split instead of a floating window:

```lua
require("ansible_doc").setup({
  window = {
    kind = "split",
  },
  open_cmd = "rightbelow vsplit",
})
```

## Optional Markdown rendering

`ansible-doc.nvim` renders documentation buffers as Markdown.

For a richer display, you can use [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim). This is optional; `ansible-doc.nvim` works without it.

With native `vim.pack`:

```lua
vim.pack.add({
  {
    src = "https://github.com/MeanderingProgrammer/render-markdown.nvim",
    name = "render-markdown.nvim",
  },
})

require("render-markdown").setup()
```

With lazy.nvim:

```lua
{
  "MeanderingProgrammer/render-markdown.nvim",
  opts = {},
}
```

The documentation buffer created by `ansible-doc.nvim` uses the `markdown` filetype, so Markdown-rendering plugins can enhance the display automatically.

## Lookup configuration

Restrict lookup to specific Ansible documentation types:

```lua
require("ansible_doc").setup({
  types = {
    "module",
    "keyword",
  },
})
```

Lower the number of concurrent `ansible-doc` jobs:

```lua
require("ansible_doc").setup({
  max_jobs = 3,
})
```

Pass a custom environment to `ansible-doc`:

```lua
require("ansible_doc").setup({
  env = {
    PAGER = "cat",
    NO_COLOR = "1",
    TERM = "dumb",
  },
})
```

## Troubleshooting

### `ansible-doc` is not found

Check:

```vim
:echo executable("ansible-doc")
```

If this returns `0`, install Ansible or fix your `$PATH`.

### No documentation is found

Check what Neovim sees as the keyword under the cursor:

```vim
:echo expand("<cWORD>")
```

Then try the equivalent command manually:

```sh
ansible-doc -t module -j ansible.builtin.debug
```

### The mapping is not active

Check the filetype:

```vim
:set filetype?
```

Check the active mapping:

```vim
:verbose nmap K
```

If you changed the mapping, check your configured mapping instead.

List buffer-local normal-mode mappings:

```vim
:lua vim.print(vim.api.nvim_buf_get_keymap(0, "n"))
```

### Plugin changes do not appear during development

Lua modules are cached. Restart Neovim or reload the module:

```vim
:lua package.loaded["ansible_doc"] = nil
:lua require("ansible_doc").setup()
```

Check which plugin file is being loaded:

```vim
:lua vim.print(vim.api.nvim_get_runtime_file("lua/ansible_doc/init.lua", true))
:lua vim.print(debug.getinfo(require("ansible_doc").lookup_ansible_doc).source)
```

## License

See the repository license.
