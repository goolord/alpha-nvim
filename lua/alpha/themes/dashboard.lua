local header = {
    type = "text",
    val = {
        [[                               __                ]],
        [[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
        [[ / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
        [[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
        [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
        [[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
    },
    opts = {
        position = "center",
        hl = "Type"
        -- wrap = "overflow";
    }
}

local function button(sc, txt, keybind)
    local sc_ = sc:gsub("%s", ""):gsub("SPC", "<leader>")
    if keybind then
        table.insert(_G.alpha_keymaps, {"n", sc_, keybind, {noremap = false, silent = true}})
    end
    return {
        type = "button",
        val = txt,
        on_press = function()
            local key = vim.api.nvim_replace_termcodes(sc_, true, false, true)
            vim.api.nvim_feedkeys(key, "normal", false)
        end,
        opts = {
            position = "center",
            shortcut = sc,
            cursor = 5,
            width = 50,
            align_shortcut = "right",
            hl_shortcut = "Keyword",
        }
    }
end

local opts = {
    layout = {
        {type = "padding", val = 2},
        header,
        {type = "padding", val = 2},
        {
            type = "button_group",
            val = {
                button( "e"      , "  New file"
                      , ":ene <BAR> startinsert <CR>"),
                button("SPC s l", "  Open last session"     ),
                button("SPC f h", "  Recently opened files" ),
                button("SPC f r", "  Frecency/MRU"          ),
                button("SPC f f", "  Find file"             ),
                button("SPC f g", "  Find word"             ),
                button("SPC f m", "  Jump to bookmarks"     ),
            },
            opts = {
                spacing = 1
            }
        }
    },
    margin = 5
}

return {
    button = button,
    header = header,
    opts = opts,
}
