# Blink-stata

A Neovim autocompletion source for Stata variables to use with [blink.cmp](https://github.com/saghen/blink.cmp).

## Features

- Provides autocompletion for Stata variables in your dataset
- Seamlessly integrates with blink.cmp
- Displays Stata variables as completion items in Neovim

## Requirements

- Neovim
- [blink.cmp](https://github.com/saghen/blink.cmp) installed
- Stata installed and accessible from command line

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "saghen/blink.cmp",
    dependencies = {
      {
        "euglevi/blink-stata", 
      },
    },
    opts = {
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "stata" }, -- Add 'stata' to your default sources
        providers = {
          stata = {
            name = "stata",
            module = "blink-stata",
          },
        },
      },
    },
}
```

## Configuration

You can configure the plugin with these options:

```lua
{
  -- path to the get_var_names.do file
  get_var_names_path = os.getenv("HOME") .. "/ado/get_var_names.do",
}
```

The default is that it tracks down the do-file that is needed to extract the variables' names in the directory where the plugin is located. If you want to use a different path, you can set it in your configuration.

## Usage

Before using the completions, you need to set the current dataset name:

```lua
-- In your Neovim configuration
_G.current_dataset_name = "your_dataset_name.dta"
```

Then, when editing Stata files, variable names from your dataset will appear as completion suggestions.


### Automatic Dataset Detection

To improve the workflow, add the following functions to your `~/.config/nvim/ftplugin/stata.lua` file to automatically detect the current dataset:

```lua
-- Function to find the `cd` directory path in the buffer
local function find_cd_directory()
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
        local dir = line:match('^cd%s+"?([^"]+)"?$')
        if dir then
            if dir:find("%$") then
                -- Prompt the user for manual insertion of the file path
                dir = vim.fn.input("Detected variable in path. Please enter the full path manually: ", "", "file")
                if dir == "" then
                    vim.notify("No path entered. Falling back to current working directory.", vim.log.levels.WARN)
                    return nil
                end
            end
            return dir
        end
    end
    return nil  -- No `cd` command found
end

-- Function to find a .dta file reference in the buffer and combine it with the `cd` directory
local function find_dataset_in_buffer()
    local base_dir = find_cd_directory() or vim.fn.getcwd() .. '/'  -- use `cd` directory if available, otherwise current directory
    local match = vim.fn.expand("<cword>")
    return "'" .. '"' .. base_dir .. match .. '"' .. "'"
end

-- Store dataset name in a variable accessible by the completion function
_G.current_dataset_name = nil

function set_stata_dataset()
    _G.current_dataset_name = find_dataset_in_buffer()
    if _G.current_dataset_name then
        print("Dataset set to: " .. _G.current_dataset_name)
    else
        print("No dataset found in buffer.")
    end
end

-- Bind a key to set the dataset name for this buffer (feel free to change the key binding)
vim.api.nvim_set_keymap("n", "<localleader>d", [[:lua set_stata_dataset()<CR>]], { noremap = true, silent = true })
```

With these functions, you can:

1. Place your cursor on a dataset filename in your Stata file
2. Press `<localleader>d` to set it as the current dataset
3. The plugin will then provide completions for variables from that dataset

