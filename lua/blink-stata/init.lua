
---@module "blink.cmp"

---@class blink-cmp-stata.Source : blink.cmp.Source
---@field config blink.cmp.SourceProviderConfig
local Source = {}

---@class blink-cmp-stata.Options
local defaults = {
    ---disable on certain filetypes
    ---@type string[]?
    disable_filetypes = {},
}

---@param id string
---@param config blink.cmp.SourceProviderConfig
---@return blink-cmp-stata.Source
function Source.new(id, config)
    local self = setmetatable({}, { __index = Source })

    self.id = id
    self.name = config.name
    self.module = config.module
    self.config = config
    self.config.opts = vim.tbl_deep_extend("force", defaults, self.config.opts or {})

    return self
end

function Source:enabled()
    return vim.bo.filetype == "stata"
        and not vim.tbl_contains(self.config.opts.disable_filetypes, vim.bo.filetype)
end

-- Function to get variable names from the Stata log file
local function get_stata_var_names(dataset_name)
    os.execute("stata -b do /home/eugenio/ado/get_var_names.do " .. dataset_name)

    local log_file = io.open("get_var_names.log", "r")
    if not log_file then
        print("Could not open get_var_names.log")
        return {}
    end

    local var_names = {}
    local start_extracting = false
    local line_buffer = ""

    for line in log_file:lines() do
        if start_extracting then
            if line:match("^> ") then
                line = line:gsub("^> ", "")
                line_buffer = line_buffer .. line
            else
                if line_buffer ~= "" then
                    for var in line_buffer:gmatch("%S+") do
                        table.insert(var_names, var)
                    end
                    break
                end
                line_buffer = line
            end
        elseif line:match("^. di r%(varlist%)") then
            start_extracting = true
        end
    end
    log_file:close()

    os.remove("get_var_names.log")
    return var_names
end

---@param context blink.cmp.Context
---@param resolve fun(response?: blink.cmp.CompletionResponse)
function Source:get_completions(context, resolve)
    local dataset_name = _G.current_dataset_name
    if not dataset_name then
        print("No dataset set. Press <leader>d to set one.")
        resolve()
        return
    end

    local var_names = get_stata_var_names(dataset_name)
    local cur_line, cur_col = unpack(context.cursor)
    local buf_text = vim.api.nvim_buf_get_lines(0, cur_line - 1, cur_line, false)[1] or ""

    -- Find the word start by scanning backward from the cursor position
    local start_col = cur_col
    while start_col > 0 and buf_text:sub(start_col, start_col):match("[%w%.%-%_]") do
        start_col = start_col - 1
    end
    start_col = start_col + 1

    local range = {
        ["start"] = {
            line = cur_line - 1,
            character = start_col,
        },
        ["end"] = {
            line = cur_line - 1,
            character = cur_col,
        },
    }

    local items = {} ---@type blink.cmp.CompletionItem[]
    for _, var_name in ipairs(var_names) do
        table.insert(items, {
            label = var_name,
            textEdit = {
                range = range,
                newText = var_name,
            },
            kind = vim.lsp.protocol.CompletionItemKind.Variable,
        })
    end

    resolve({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end

return Source
