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
    -- Custom Parameters (with defaults)
    {
        "MHD-GDev/genlms.nvim",
        dependencies = {
            "nvim-lualine/lualine.nvim",
        },
        config = function()
            require("gen").setup({
                quit_map = "q",
                retry_map = "<c-r>",
                accept_map = "<c-cr>",
                host = "localhost",
                port = "1123",
                display_mode = "split",
                show_prompt = true,
                show_model = true,
                no_auto_close = false,
                json_response = true,
                result_filetype = "markdown",
                debug = false,
            })

            -- Key mappings
            vim.keymap.set({ "n", "v" }, "<leader>]", ":Gen<CR>")
            vim.keymap.set("n", "<leader>ga", "<CMD>Gen Ask<CR>", { noremap = true })
            vim.keymap.set("n", "<leader>gc", "<CMD>Gen Chat<CR>", { noremap = true })
            vim.keymap.set("n", "<leader>gg", "<CMD>Gen Generate<CR>", { noremap = true })
            vim.keymap.set("v", "<leader>gC", ":'<,'>Gen Change_Code<CR>", { noremap = true })
            vim.keymap.set("v", "<leader>ge", ":'<,'>Gen Enhance_Code<CR>", { noremap = true })
            vim.keymap.set("v", "<leader>gR", ":'<,'>Gen Review_Code<CR>", { noremap = true })
            vim.keymap.set("v", "<leader>gs", ":'<,'>Gen Summarize<CR>", { noremap = true })
            vim.keymap.set("v", "<leader>ga", ":'<,'>Gen Ask<CR>", { noremap = true })
            vim.keymap.set("v", "<leader>gx", ":'<,'>Gen Fix_Code<CR>", { noremap = true })
            vim.keymap.set("n", "<leader>gl", "<CMD>GenLoadModel<CR>", { noremap = true })
            vim.keymap.set("n", "<leader>gu", "<CMD>GenUnloadModel<CR>", { noremap = true })
        end,
    },
```

## Usage

Use command `Gen` to generate text based on predefined and customizable prompts.

Example key maps:

```lua
vim.keymap.set({ 'n', 'v' }, '<leader>]', ':Gen<CR>')
```

You can also directly invoke it with one of the [predefined prompts](./lua/gen/prompts.lua) or your custom prompts:

```lua
vim.keymap.set('v', '<leader>]', ':Gen Enhance_Grammar_Spelling<CR>')
```

After a conversation begins, the entire context is sent to the LLM. That allows you to ask follow-up questions with

```lua
:Gen Chat
```

and once the window is closed, you start with a fresh conversation.

For prompts which don't automatically replace the previously selected text (`replace = false`), you can replace the selected text with the generated output with `<c-cr>`.

### Note:
To use genlms you need to load or unload models with these commands ```:GenUnloadModel``` and ```:GenloadModel``` .

##### Models:

- You can downlaod models from [Hugingface](https://huggingface.co/models) <img height="20" src="https://unpkg.com/@lobehub/icons-static-svg@latest/icons/huggingface-color.svg"/>

## Custom Prompts

[All prompts](./lua/gen/prompts.lua) are defined in `require('gen').prompts`, you can enhance or modify them.

Example:

````lua
require('gen').prompts['Elaborate_Text'] = {
  prompt = "Elaborate the following text:\n$text",
  replace = true
}
require('gen').prompts['Fix_Code'] = {
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
