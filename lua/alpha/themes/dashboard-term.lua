local term = require("alpha.term")

local if_nil = vim.F.if_nil

local icon_string = ( -- https://github.com/glepnir/dashboard-nvim/wiki/Ascii-Header-Text
        "                               \27[38;2;237;37;76m              \27[38;2;70;130;255m\r\n"
        .. "      \27[38;2;237;37;76m███████████           \27[38;2;237;37;76m█████      \27[38;2;70;130;255m██\r\n"
        .. "     \27[38;2;237;37;76m███████████             \27[38;2;237;37;76m█████ \r\n"
        .. "     \27[38;2;237;37;76m█████████ \27[38;2;70;130;255m███████ ███\27[38;2;237;37;76m████████ \27[38;2;70;130;255m███   ███████\r\n"
        .. "    \27[38;2;237;37;76m█████████\27[38;2;70;130;255m███████ ████\27[38;2;237;37;76m████████ \27[38;2;70;130;255m█████ ██████████████\r\n"
        .. "   \27[38;2;237;37;76m█████████\27[38;2;70;130;255m█████    ██████\27[38;2;237;37;76m███████ \27[38;2;70;130;255m█████ █████ ████ █████\r\n"
        .. " \27[38;2;237;37;76m███████████\27[38;2;70;130;255m█████████████████\27[38;2;237;37;76m██████ \27[38;2;70;130;255m█████ █████ ████ █████\r\n"
        .. "\27[38;2;237;37;76m██████  ███ \27[38;2;70;130;255m█████████████████ \27[38;2;237;37;76m████ \27[38;2;70;130;255m█████ █████ ████ ██████ "
    )

-- demo for dynamic rendering
local function animated_text_writer(raw_string, delay)
    return function(win)
        local count = 1
        local function output()
            vim.api.nvim_chan_send(win.channel_id, raw_string:sub(count, count))
            count = count + 1
            if count < #raw_string then
                --count = 1
                vim.defer_fn(output, delay)
            end
        end
        vim.schedule(output)
        return {
            on_close = function()
                count = #raw_string
            end,
        }
    end
end

local command_header = {
    type = "term",

	-- use the output of a shell command:
    on_channel_opened = term.terminal_fillers.shell_command("echo - alpha.nvim - | figlet | lolcat"),

	-- render icon_string char by char:
    --on_channel_opened = animated_text_writer(icon_string, 10),

	-- dump icon_string into the window:
    --on_channel_opened = term.terminal_fillers.raw_string(icon_string),

    opts = {
        position = "center",
        horizontal_offset = 0,
        width = 69,
        hl = "Normal",
        height = 8,
    },
}

--- @param sc string
--- @param txt string
--- @param keybind string optional
--- @param keybind_opts table optional
local function button(sc, txt, keybind, keybind_opts)
    local sc_ = sc:gsub("%s", ""):gsub("SPC", "<leader>")

    local opts = {
        position = "center",
        shortcut = sc,
        cursor = 5,
        width = 50,
        align_shortcut = "right",
        hl_shortcut = "Keyword",
    }
    if keybind then
        keybind_opts = if_nil(keybind_opts, { noremap = true, silent = true, nowait = true })
        opts.keymap = { "n", sc_, keybind, keybind_opts }
    end

    local function on_press()
        local key = vim.api.nvim_replace_termcodes(sc_ .. "<Ignore>", true, false, true)
        vim.api.nvim_feedkeys(key, "normal", false)
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
        button("e", "  New file", "<cmd>ene <CR>"),
        button("SPC f f", "  Find file"),
        button("SPC f h", "  Recently opened files"),
        button("SPC f r", "  Frecency/MRU"),
        button("SPC f g", "  Find word"),
        button("SPC f m", "  Jump to bookmarks"),
        button("SPC s l", "  Open last session"),
    },
    opts = {
        spacing = 1,
    },
}

local footer = (function()
    local v = vim.version()
    local text = string.format("Using nvim-%d.%d.%d", v.major, v.minor, v.patch)
    local footer = {
        type = "text",
        val = text,
        opts = {
            position = "center",
            hl = "Number",
        },
    }
    return footer
end)()

local section = {
    header = command_header,
    buttons = buttons,
    footer = footer,
}

local opts = {
    layout = {
        { type = "padding", val = 12 },
        section.header,
        { type = "padding", val = 2 },
        section.buttons,
        { type = "padding", val = 2 },
        section.footer,
        { type = "padding", val = 25 },
    },
    opts = {
        margin = 5,
    },
}

return {
    button = button,
    section = section,
    opts = opts,
}
