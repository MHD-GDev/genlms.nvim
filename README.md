# genlms.nvim

Generate text using local LLMs with customizable prompts

<div align="center">

![Local LLMs in Neovim: genlms.nvim](/genlms.png)

</div>

## Requires

- [LMStudio](https://lmstudio.ai) with any local model (GGUF models are recommended)
- [Curl](https://curl.se/)

## Install

Install with your favorite plugin manager, e.g. [lazy.nvim](https://github.com/folke/lazy.nvim)

Example with Lazy

```lua
-- Minimal configuration
{ "MHD-GDev/genlms.nvim" },

```

```lua
-- Custom Parameters (with defaults)
{
 model = "local-model",
    host = "localhost",
    port = "1123",
    file = false,
    debug = false,
    body = {stream = true},
    show_prompt = false,
    show_model = false,
    quit_map = "q",
    accept_map = "<c-cr>",
    retry_map = "<c-r>",
    hidden = false,
    command = function(options)
            -- Check if model is already loaded first
            local check = vim.fn.system("curl -s http://" .. options.host .. ":" .. options.port .. "/v1/models")
            if check and #check > 0 then
                local success, decoded = pcall(vim.fn.json_decode, check)
                if success and decoded and decoded.data and #decoded.data > 0 then
                    options.model = decoded.data[1].id
                    return "curl --silent --no-buffer -X POST http://" .. options.host ..
                           ":" .. options.port .. "/v1/chat/completions -H 'Content-Type: application/json' -d $body"
                end
            end
        -- Start LM Studio server first, then check connection
        vim.fn.system("lms server start --cors=true")
        
        local recheck = vim.fn.system(
            "curl -s -o /dev/null -w '%{http_code}' http://" .. options.host .. ":" .. options.port .. "/v1/models"
        )
        
        if recheck == "200" then
            return "curl --silent --no-buffer -X POST http://" .. options.host ..
                   ":" .. options.port .. "/v1/chat/completions -H 'Content-Type: application/json' -d $body"
        else
            print("Could not connect to LM Studio server. Please check if it's installed correctly.")
            return nil
        end
    end,
    json_response = true,
    display_mode = "float",
    no_auto_close = false,
    init = function() end,
    list_models = function(options)
        -- Start server proactively
        vim.fn.system("lms server start --cors=true")
        
        local response = vim.fn.systemlist(
            "curl -q --silent --no-buffer http://" .. options.host ..
            ":" .. options.port .. "/v1/models"
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
    select_model = function()
        -- Start LM Studio server first
        vim.fn.system("lms server start --cors=true")
        
        -- Wait briefly for server to start
        vim.fn.system("sleep 1")
        
        -- Now check for loaded model
        local response = vim.fn.system("curl -s -m 2 http://" .. M.host .. ":" .. M.port .. "/v1/models")
        local success, decoded = pcall(vim.fn.json_decode, response)
        if success and decoded and decoded.data and #decoded.data > 0 then
            local current_model = decoded.data[1].id
            -- Unload current model
            vim.fn.system("lms unload " .. current_model)
            print("Unloaded model: " .. current_model)
        end

        -- Get list of available models and let user select
        local models = M.list_models(M)
        vim.ui.select(models, {prompt = "Model:"}, function(item)
            if item ~= nil then
                vim.fn.system("lms load " .. item)
                print("Model set to " .. item)
                M.model = item
                cache_model(item)
            end
        end)
    end,
}
```

## Usage

Use command `Gen` to generate text based on predefined and customizable prompts.

Example key maps:

```lua
vim.keymap.set({ 'n', 'v' }, '<leader>]', ':Gen<CR>')
```

You can also directly invoke it with one of the [predefined prompts](./lua/genlms/prompts.lua) or your custom prompts:

```lua
vim.keymap.set('v', '<leader>]', ':Gen Enhance_Grammar_Spelling<CR>')
```

After a conversation begins, the entire context is sent to the LLM. That allows you to ask follow-up questions with

```lua
:Gen Chat
```

and once the window is closed, you start with a fresh conversation.

For prompts which don't automatically replace the previously selected text (`replace = false`), you can replace the selected text with the generated output with `<c-cr>`.

You can select a model from a list of all installed models with

```lua
require('genlms').select_model()
```

##### Models:

- You can downlaod models from [Hugingface](https://huggingface.co/models) <img height="20" src="https://unpkg.com/@lobehub/icons-static-svg@latest/icons/huggingface-color.svg"/>

## Custom Prompts

[All prompts](./lua/genlms/prompts.lua) are defined in `require('genlms').prompts`, you can enhance or modify them.

Example:

````lua
require('genlms').prompts['Elaborate_Text'] = {
  prompt = "Elaborate the following text:\n$text",
  replace = true
}
require('genlms').prompts['Fix_Code'] = {
  prompt = "Fix the following code. Only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
  replace = true,
  extract = "```$filetype\n(.-)```"
}
````

You can use the following properties per prompt:

- `prompt`: (string | function) Prompt either as a string or a function which should return a string. The result can use the following placeholders:
  - `$text`: Visually selected text or the content of the current buffer
  - `$filetype`: File type of the buffer (e.g. `javascript`)
  - `$input`: Additional user input
  - `$register`: Value of the unnamed register (yanked text)
- `replace`: `true` if the selected text shall be replaced with the generated output
- `extract`: Regular expression used to extract the generated result
- `model`: The model to use, default: `local-model`

## Tip

User selections can be delegated to [Telescope](https://github.com/nvim-telescope/telescope.nvim) with [telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim).

## Dev notes:

- This project was inspired by [gen.nvim](https://github.com/David-Kunz/gen.nvim), which laid the foundation for this version.
- For more information, see the [original project](https://github.com/David-Kunz/gen.nvim).
- We would like to express our gratitude to the original authors and contributors who made this project possible.
