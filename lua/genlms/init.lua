local prompts = require("genlms.prompts")
local M = {}

local globals = {}

local function reset(keep_selection)
    if not keep_selection then
        globals.curr_buffer = nil
        globals.start_pos = nil
        globals.end_pos = nil
    end
    if globals.job_id then
        vim.fn.jobstop(globals.job_id)
        globals.job_id = nil
    end
    globals.result_buffer = nil
    globals.float_win = nil
    globals.result_string = ""
    globals.context = nil
    globals.context_buffer = nil
end

-- lualine
local function create_lualine_component()
    local status = "off"

    -- Function to update status that can be called from GenLoadModel
    local function update_status()
        local check = vim.fn.system("curl -s http://localhost:1123/v1/models")
        if check and #check > 0 then
            local success, decoded = pcall(vim.fn.json_decode, check)
            if success and decoded and decoded.data and #decoded.data > 0 then
                local model_name = decoded.data[1].id
                model_name = model_name:match("[^/]*$")
                status = "on:" .. model_name
            else
                status = "off"
            end
        else
            status = "off"
        end
    end

    -- Initial status check
    update_status()

    -- Make update_status available globally
    M.update_lualine_status = update_status

    return function()
        return status
    end
end


M.get_lualine_component = create_lualine_component

local status_ok, lualine = pcall(require, "lualine")
if status_ok then
    local current_config = lualine.get_config()
    current_config.sections.lualine_x = vim.list_extend(
        { create_lualine_component() },
        current_config.sections.lualine_x or {}
    )
    lualine.setup(current_config)
end


local function trim_table(tbl)
    local function is_whitespace(str)
        return str:match("^%s*$") ~= nil
    end

    while #tbl > 0 and (tbl[1] == "" or is_whitespace(tbl[1])) do
        table.remove(tbl, 1)
    end

    while #tbl > 0 and (tbl[#tbl] == "" or is_whitespace(tbl[#tbl])) do
        table.remove(tbl, #tbl)
    end

    return tbl
end

local default_options = {
    host = "localhost",
    port = "1234",
    file = false,
    debug = false,
    body = { stream = true },
    show_prompt = false,
    show_model = false,
    quit_map = "q",
    accept_map = "<c-cr>",
    retry_map = "<c-r>",
    hidden = false,
    command = function(options)
        local check = vim.fn.system("curl -s http://" .. options.host .. ":" .. options.port .. "/v1/models")
        if check and #check > 0 then
            local success, decoded = pcall(vim.fn.json_decode, check)
            if success and decoded and decoded.data and #decoded.data > 0 then
                -- Only set model if explicitly loaded
                if decoded.data[1].id then
                    options.model = decoded.data[1].id
                end
                return "curl --silent --no-buffer -X POST http://"
                    .. options.host
                    .. ":"
                    .. options.port
                    .. "/v1/chat/completions -H 'Content-Type: application/json' -d $body"
            end
        end
        -- Start LM Studio server first, then check connection
        vim.fn.system("lms server start --cors=true")
    return "curl --silent --no-buffer -X POST http://"
        .. options.host
        .. ":"
        .. options.port
        .. "/v1/chat/completions -H 'Content-Type: application/json' -d $body"
end,
    json_response = true,
    display_mode = "float",
    no_auto_close = false,
    init = function() end,
    list_models = function(options)
        -- Start server proactively
        vim.fn.system("lms server start --cors=true")

        local response = vim.fn.systemlist(
            "curl -q --silent --no-buffer http://" .. options.host .. ":" .. options.port .. "/v1/models"
        )

        if response and #response > 0 then
            local list = vim.fn.json_decode(response)
            local models = {}
            for _, model in ipairs(list.data) do
                table.insert(models, model.id)
            end
            table.sort(models)
            return models
        end

        print("Could not fetch models. Please verify LM Studio installation.")
        return {}
    end,
    result_filetype = "markdown",
}
for k, v in pairs(default_options) do
    M[k] = v
end

M.setup = function(opts)
    for k, v in pairs(opts) do
        M[k] = v
    end
end


local function close_window(opts)
    local lines = {}
    if opts.extract then
        local extracted = globals.result_string:match(opts.extract)
        if not extracted then
            if not opts.no_auto_close then
                vim.api.nvim_win_hide(globals.float_win)
                if globals.result_buffer ~= nil then
                    vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
                end
                reset()
            end
            return
        end
        lines = vim.split(extracted, "\n", { trimempty = true })
    else
        lines = vim.split(globals.result_string, "\n", { trimempty = true })
    end
    lines = trim_table(lines)
    vim.api.nvim_buf_set_text(
        globals.curr_buffer,
        globals.start_pos[2] - 1,
        globals.start_pos[3] - 1,
        globals.end_pos[2] - 1,
        globals.end_pos[3] > globals.start_pos[3] and globals.end_pos[3] or globals.end_pos[3] - 1,
        lines
    )
    -- in case another replacement happens
    globals.end_pos[2] = globals.start_pos[2] + #lines - 1
    globals.end_pos[3] = string.len(lines[#lines])
    if not opts.no_auto_close then
        if globals.float_win ~= nil then
            vim.api.nvim_win_hide(globals.float_win)
        end
        if globals.result_buffer ~= nil then
            vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
        end
        reset()
    end
end

local function get_window_options(opts)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local new_win_width = vim.api.nvim_win_get_width(0)
    local win_height = vim.api.nvim_win_get_height(0)

    local middle_row = win_height / 2

    local new_win_height = math.floor(win_height / 2)
    local new_win_row
    if cursor[1] <= middle_row then
        new_win_row = 5
    else
        new_win_row = -5 - new_win_height
    end

    -- Adds dynamic sizing based on content
    local content_lines = vim.split(globals.result_string, "\n")
    local dynamic_height = math.min(#content_lines + 2, math.floor(win_height / 2))

    local result = {
        relative = "cursor",
        width = new_win_width,
        height = dynamic_height,
        row = new_win_row,
        col = 0,
        style = "minimal",
        border = "rounded",
        zindex = 50, -- Ensure window stays on top
    }

    local version = vim.version()
    if version.major > 0 or version.minor >= 10 then
        result.hide = opts.hidden
    end

    return result
end

local function chunk_large_content(content, chunk_size)
    local chunks = {}
    local length = #content
    for i = 1, length, chunk_size do
        table.insert(chunks, string.sub(content, i, math.min(i + chunk_size - 1, length)))
    end
    return chunks
end
local function write_to_buffer(lines)
    if not globals.result_buffer or not vim.api.nvim_buf_is_valid(globals.result_buffer) then
        return
    end
    local all_lines = vim.api.nvim_buf_get_lines(globals.result_buffer, 0, -1, false)

    local last_row = #all_lines
    local last_row_content = all_lines[last_row]
    local last_col = string.len(last_row_content)

    local text = table.concat(lines or {}, "\n")

    vim.api.nvim_set_option_value("modifiable", true, { buf = globals.result_buffer })
    vim.api.nvim_buf_set_text(
        globals.result_buffer,
        last_row - 1,
        last_col,
        last_row - 1,
        last_col,
        vim.split(text, "\n")
    )

    if globals.float_win ~= nil and vim.api.nvim_win_is_valid(globals.float_win) then
        local cursor_pos = vim.api.nvim_win_get_cursor(globals.float_win)

        -- Move the cursor to the end of the new lines
        if cursor_pos[1] == last_row then
            local new_last_row = last_row + #lines - 1
            vim.api.nvim_win_set_cursor(globals.float_win, { new_last_row, 0 })
        end
    end

    vim.api.nvim_set_option_value("modifiable", false, { buf = globals.result_buffer })
end

local function create_window(cmd, opts)
    -- Create buffer and show "Thinking..." immediately
    globals.result_buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(globals.result_buffer, 0, -1, false, {"Thinking...", ""})

    local function setup_window()
        globals.result_buffer = vim.fn.bufnr("%")
        globals.float_win = vim.fn.win_getid()
        vim.api.nvim_set_option_value("filetype", opts.result_filetype, { buf = globals.result_buffer })
        vim.api.nvim_set_option_value("buftype", "nofile", { buf = globals.result_buffer })
        vim.api.nvim_set_option_value("wrap", true, { win = globals.float_win })
        vim.api.nvim_set_option_value("linebreak", true, { win = globals.float_win })
    end

    local display_mode = opts.display_mode or M.display_mode
    if display_mode == "float" then
        if globals.result_buffer then
            vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
        end
        local win_opts = vim.tbl_deep_extend("force", get_window_options(opts), opts.win_config)
        globals.result_buffer = vim.api.nvim_create_buf(false, true)
        globals.float_win = vim.api.nvim_open_win(globals.result_buffer, true, win_opts)
        setup_window()
    elseif display_mode == "horizontal-split" then
        vim.cmd("split genlms.nvim")
        setup_window()
    else
        vim.cmd("vnew genlms.nvim")
        setup_window()
    end
    vim.keymap.set("n", "<esc>", function()
        if globals.job_id then
            vim.fn.jobstop(globals.job_id)
        end
    end, { buffer = globals.result_buffer })
    vim.keymap.set("n", M.quit_map, "<cmd>quit<cr>", { buffer = globals.result_buffer })
    vim.keymap.set("n", M.accept_map, function()
        opts.replace = true
        close_window(opts)
    end, { buffer = globals.result_buffer })
    vim.keymap.set("n", M.retry_map, function()
        local buf = 0 -- Current buffer
        if globals.job_id then
            vim.fn.jobstop(globals.job_id)
            globals.job_id = nil
        end
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
        -- vim.api.nvim_win_close(0, true)
        M.run_command(cmd, opts)
    end, { buffer = globals.result_buffer })
end

M.exec = function(options)

    local opts = vim.tbl_deep_extend("force", M, options)
    if opts.hidden then
        -- the only reasonable thing to do if no output can be seen
        opts.display_mode = "float" -- uses the `hide` option
        opts.replace = true
    end

    if type(opts.init) == "function" then
        opts.init(opts)
    end

    if globals.result_buffer ~= vim.fn.winbufnr(0) then
        globals.curr_buffer = vim.fn.winbufnr(0)
        local mode = opts.mode or vim.fn.mode()
        if mode == "v" or mode == "V" then
            globals.start_pos = vim.fn.getpos("'<")
            globals.end_pos = vim.fn.getpos("'>")
            local max_col = vim.api.nvim_win_get_width(0)
            if globals.end_pos[3] > max_col then
                globals.end_pos[3] = vim.fn.col("'>") - 1
            end -- in case of `V`, it would be maxcol instead
        else
            local cursor = vim.fn.getpos(".")
            globals.start_pos = cursor
            globals.end_pos = globals.start_pos
        end
    end

    local content
    if globals.start_pos == globals.end_pos then
        -- get text from whole buffer
        content = table.concat(vim.api.nvim_buf_get_lines(globals.curr_buffer, 0, -1, false), "\n")
    else
        content = table.concat(
            vim.api.nvim_buf_get_text(
                globals.curr_buffer,
                globals.start_pos[2] - 1,
                globals.start_pos[3] - 1,
                globals.end_pos[2] - 1,
                globals.end_pos[3],
                {}
            ),
            "\n"
        )
    end
    local function substitute_placeholders(input)
        if not input then
            return input
        end
        local text = input
        if string.find(text, "%$input") then
            local answer = vim.fn.input("Prompt: ")
            text = string.gsub(text, "%$input", answer)
        end

        text = string.gsub(text, '%$register_([%w*+:/"])', function(r_name)
            local register = vim.fn.getreg(r_name)
            if not register or register:match("^%s*$") then
                error("Prompt uses $register_" .. rname .. " but register " .. rname .. " is empty")
            end
            return register
        end)

        if string.find(text, "%$register") then
            local register = vim.fn.getreg('"')
            if not register or register:match("^%s*$") then
                error("Prompt uses $register but yank register is empty")
            end

            text = string.gsub(text, "%$register", register)
        end

        content = string.gsub(content, "%%", "%%%%")
        text = string.gsub(text, "%$text", content)
        text = string.gsub(text, "%$filetype", vim.bo.filetype)
        return text
    end

    local prompt = opts.prompt

    if type(prompt) == "function" then
        prompt = prompt({ content = content, filetype = vim.bo.filetype })
        if type(prompt) ~= "string" or string.len(prompt) == 0 then
            return
        end
    end

    prompt = substitute_placeholders(prompt)
    opts.extract = substitute_placeholders(opts.extract)
    prompt = string.gsub(prompt, "%%", "%%%%")

    globals.result_string = ""

    local cmd

    opts.json = function(body, shellescape)
        local json = vim.fn.json_encode(body)
        if shellescape then
            json = vim.fn.shellescape(json)
            if vim.o.shell == "cmd.exe" then
                json = string.gsub(json, '\\""', '\\\\\\"')
            end
        end
        return json
    end

    opts.prompt = prompt

    if type(opts.command) == "function" then
        cmd = opts.command(opts)
    else
        cmd = M.command
    end

    if string.find(cmd, "%$prompt") then
        local prompt_escaped = vim.fn.shellescape(prompt)
        cmd = string.gsub(cmd, "%$prompt", prompt_escaped)
    end
    cmd = string.gsub(cmd, "%$model", opts.model)
    if string.find(cmd, "%$body") then
        local body = vim.tbl_extend("force", { model = opts.model, stream = true }, opts.body)
        local messages = {}
        if globals.context then
            messages = globals.context
        end
        -- Add new prompt to the context
        table.insert(messages, { role = "user", content = prompt })
        body.messages = messages

        if opts.file ~= nil then
            local json = opts.json(body, false)
            globals.temp_filename = os.tmpname()
            local fhandle = io.open(globals.temp_filename, "w")
            fhandle:write(json)
            fhandle:close()
            cmd = string.gsub(cmd, "%$body", "@" .. globals.temp_filename)
        else
            local json = opts.json(body, true)
            cmd = string.gsub(cmd, "%$body", json)
        end
    end

    if globals.context ~= nil then
        write_to_buffer({ "", "", "---", "" })
    end

    M.run_command(cmd, opts)
end

M.run_command = function(cmd, opts)
    -- vim.print('run_command', cmd, opts)
    if globals.result_buffer == nil or globals.float_win == nil or not vim.api.nvim_win_is_valid(globals.float_win) then
        create_window(cmd, opts)
        if opts.show_model then
            write_to_buffer({ "# Chat with " .. opts.model, "" })
        end
    end
    local partial_data = ""
    if opts.debug then
        print(cmd)
    end

    globals.job_id = vim.fn.jobstart(cmd, {
        -- stderr_buffered = opts.debug,
        on_stdout = function(_, data, _)
            -- window was closed, so cancel the job
            if not globals.float_win or not vim.api.nvim_win_is_valid(globals.float_win) then
                if globals.job_id then
                    vim.fn.jobstop(globals.job_id)
                end
                if globals.result_buffer then
                    vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
                end
                reset()
                return
            end
            if opts.debug then
                vim.print("Response data: ", data)
            end
            for _, line in ipairs(data) do
                partial_data = partial_data .. line
                if line:sub(-1) == "}" then
                    partial_data = partial_data .. "\n"
                end
            end

            local lines = vim.split(partial_data, "\n", { trimempty = true })

            partial_data = table.remove(lines) or ""

            for _, line in ipairs(lines) do
                Process_response(line, globals.job_id, opts.json_response)
            end

            if partial_data:sub(-1) == "}" then
                Process_response(partial_data, globals.job_id, opts.json_response)
                partial_data = ""
            end
        end,
        on_stderr = function(_, data, _)
            if opts.debug then
                -- window was closed, so cancel the job
                if not globals.float_win or not vim.api.nvim_win_is_valid(globals.float_win) then
                    if globals.job_id then
                        vim.fn.jobstop(globals.job_id)
                    end
                    return
                end

                if data == nil or #data == 0 then
                    return
                end

                globals.result_string = globals.result_string .. table.concat(data, "\n")
                local lines = vim.split(globals.result_string, "\n")
                write_to_buffer(lines)
            end
        end,
        on_exit = function(_, b)
            if b == 0 and opts.replace and globals.result_buffer then
                close_window(opts)
            end
        end,
    })

    local group = vim.api.nvim_create_augroup("genlms", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = globals.result_buffer,
        group = group,
        callback = function()
            if globals.job_id then
                vim.fn.jobstop(globals.job_id)
            end
            if globals.result_buffer then
                vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
            end
            reset(true) -- keep selection in case of subsequent retries
        end,
    })

    if opts.show_prompt then
        local lines = vim.split(opts.prompt, "\n")
        local short_prompt = {}
        for i = 1, #lines do
            lines[i] = "> " .. lines[i]
            table.insert(short_prompt, lines[i])
            if i >= 3 and opts.show_prompt ~= "full" then
                if #lines > i then
                    table.insert(short_prompt, "...")
                end
                break
            end
        end
        local heading = "#"
        if M.show_model then
            heading = "##"
        end
        write_to_buffer({
            heading .. " Prompt:",
            "",
            table.concat(short_prompt, "\n"),
            "",
            "---",
            "",
        })
    end

    vim.api.nvim_buf_attach(globals.result_buffer, false, {
        on_detach = function()
            globals.result_buffer = nil
        end,
    })
end

M.win_config = {}

M.prompts = prompts
local function select_prompt(cb)
    local promptKeys = {}
    for key, _ in pairs(M.prompts) do
        table.insert(promptKeys, key)
    end
    table.sort(promptKeys)
    vim.ui.select(promptKeys, {
        prompt = "Prompt:",
        format_item = function(item)
            return table.concat(vim.split(item, "_"), " ")
        end,
    }, function(item)
        cb(item)
    end)
end

vim.api.nvim_create_user_command("Genlms", function(arg)

    local mode
    if arg.range == 0 then
        mode = "n"
    else
        mode = "v"
    end
    if arg.args ~= "" then
        local prompt = M.prompts[arg.args]
        if not prompt then
            print("Invalid prompt '" .. arg.args .. "'")
            return
        end
        local p = vim.tbl_deep_extend("force", { mode = mode }, prompt)
        return M.exec(p)
    end

    select_prompt(function(item)
        if not item then
            return
        end
        local p = vim.tbl_deep_extend("force", { mode = mode }, M.prompts[item])
        M.exec(p)
    end)
end, {
    range = true,
    nargs = "?",
    complete = function(ArgLead)
        local promptKeys = {}
        for key, _ in pairs(M.prompts) do
            if key:lower():match("^" .. ArgLead:lower()) then
                table.insert(promptKeys, key)
            end
        end
        table.sort(promptKeys)
        return promptKeys
    end,
})

function Process_response(str, json_response)
    if string.len(str) == 0 then
        return
    end
    local text

    if json_response then
        -- llamacpp response string -- 'data: {"content": "hello", .... }' -- remove 'data: ' prefix, before json_decode
        if string.sub(str, 1, 6) == "data: " then
            str = string.gsub(str, "data: ", "", 1)
        end
        local success, result = pcall(function()
            return vim.fn.json_decode(str)
        end)

        if success then
            if result.message and result.message.content then -- ollama chat endpoint
                local content = result.message.content
                text = content

                globals.context = globals.context or {}
                globals.context_buffer = globals.context_buffer or ""
                globals.context_buffer = globals.context_buffer .. content

                -- When the message sequence is complete, add it to the context
                if result.done then
                    table.insert(globals.context, {
                        role = "assistant",
                        content = globals.context_buffer,
                    })
                    -- Clear the buffer as we're done with this sequence of messages
                    globals.context_buffer = ""
                end
            elseif result.choices then -- LMStudio/OpenAI format
                local choice = result.choices[1]
                local content = choice.delta.content or choice.message.content
                text = content

                if content ~= nil then
                    globals.context = globals.context or {}
                    globals.context_buffer = globals.context_buffer or ""
                    globals.context_buffer = globals.context_buffer .. content
                end

                -- When the message sequence is complete, add it to the context
                if choice.finish_reason == "stop" then
                    table.insert(globals.context, {
                        role = "assistant",
                        content = globals.context_buffer,
                    })
                    globals.context_buffer = ""
                end
            elseif result.content then -- llamacpp version
                text = result.content
                if result.content then
                    globals.context = result.content
                end
            elseif result.response then -- lms generate endpoint
                text = result.response
                if result.context then
                    globals.context = result.context
                end
            end
        else
            write_to_buffer({ "", "====== ERROR ====", str, "-------------", "" })
            vim.fn.jobstop(globals.job_id)
        end
    else
        text = str
    end

    if text == nil then
        return
    end

    globals.result_string = globals.result_string .. text
    local lines = vim.split(text, "\n")
    write_to_buffer(lines)
end

-- This code let the user unload the model themselves
vim.api.nvim_create_user_command("GenUnloadModel", function()
    local response = vim.fn.system("curl -s http://" .. M.host .. ":" .. M.port .. "/v1/models")
    local success, decoded = pcall(vim.fn.json_decode, response)
    if success and decoded and decoded.data and #decoded.data > 0 then
        local model_id = decoded.data[1].id
        vim.fn.system("lms unload " .. model_id)
        -- Ensure server stops after unloading
        vim.fn.system("lms server stop")
        vim.fn.system("lms server stop")
        print("Unloaded model and stopped server: " .. model_id)
        M.update_lualine_status() -- Updates lualine status
    end
end, {})

vim.api.nvim_create_user_command("GenLoadModel", function()
    -- Check if a model is currently loaded
    local response = vim.fn.system("curl -s http://" .. M.host .. ":" .. M.port .. "/v1/models")
    local success, decoded = pcall(vim.fn.json_decode, response)

    -- If there's a loaded model, unload it first
    if success and decoded and decoded.data and #decoded.data > 0 then
        local current_model = decoded.data[1].id
        vim.fn.system("lms unload " .. current_model)
        print("Unloaded previous model: " .. current_model)
    end

    -- Get list of available models and let user select
    local models = M.list_models(M)
    vim.ui.select(models, { prompt = "Select model to load:" }, function(item)
        if item ~= nil then
            vim.fn.system("lms load " .. item)
            print("Model set to " .. item)
            M.model = item
            M.update_lualine_status() -- Updates lualine status
        end
    end)
end, {})


return M
