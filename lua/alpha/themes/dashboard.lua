local if_nil = vim.F.if_nil

local default_terminal = {
    type = "terminal",
    command = nil,
    width = 69,
    height = 8,
    opts = {
        redraw = true,
        window_config = {},
    },
}

local default_header = {
    type = "text",
    val = {
        [[                                  __]],
        [[     ___     ___    ___   __  __ /\_\    ___ ___]],
        [[    / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\]],
        [[   /\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \]],
        [[   \ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
        [[    \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
    },
    opts = {
        position = "center",
        hl = "Type",
        -- wrap = "overflow";
    },
}

local footer = {
    type = "text",
    val = "",
    opts = {
        position = "center",
        hl = "Number",
    },
}

local M = {}

M.leader = "SPC"

--- @param sc string
--- @param txt string
--- @param keybind string? optional
--- @param keybind_opts table? optional
function M.button(sc, txt, keybind, keybind_opts)
    local sc_ = sc:gsub("%s", ""):gsub(M.leader, "<leader>")

    local opts = {
        position = "center",
        shortcut = sc,
        cursor = 3,
        width = 50,
        align_shortcut = "right",
        hl_shortcut = "Keyword",
    }
    if keybind then
        keybind_opts = if_nil(keybind_opts, { noremap = true, silent = true, nowait = true })
        opts.keymap = { "n", sc_, keybind, keybind_opts }
    end

    local function on_press()
        local key = vim.api.nvim_replace_termcodes(keybind or sc_ .. "<Ignore>", true, false, true)
        vim.api.nvim_feedkeys(key, "t", false)
    end

    return {
        type = "button",
        val = txt,
        on_press = on_press,
        opts = opts,
    }
end

local buttons = {
    type = "group",
    val = {
        M.button("e", "  New file", "<cmd>ene <CR>"),
        M.button("SPC f f", "󰈞  Find file"),
        M.button("SPC f h", "󰊄  Recently opened files"),
        M.button("SPC f r", "  Frecency/MRU"),
        M.button("SPC f g", "󰈬  Find word"),
        M.button("SPC f m", "  Jump to bookmarks"),
        M.button("SPC s l", "  Open last session"),
    },
    opts = {
        spacing = 1,
    },
}

M.section = {
    terminal = default_terminal,
    header = default_header,
    buttons = buttons,
    footer = footer,
}

M.config = {
    layout = {
        { type = "padding", val = 2 },
        M.section.header,
        { type = "padding", val = 2 },
        M.section.buttons,
        M.section.footer,
    },
    opts = {
        margin = 5,
    },
}

--deprecated
M.opts = M.config

return M
