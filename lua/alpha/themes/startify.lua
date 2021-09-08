local if_nil = vim.F.if_nil

local default_header = {
    type = "text",
    val = {
        [[                                   __                ]],
        [[      ___     ___    ___   __  __ /\_\    ___ ___    ]],
        [[     / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
        [[    /\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
        [[    \ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
        [[     \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
    },
    opts = {
        hl = "Type"
        -- wrap = "overflow";
    }
}

--                    req req  optional optional
local function button(sc, txt, keybind, keybind_opts)
    local sc_ = sc:gsub("%s", ""):gsub("SPC", "<leader>")

    local opts = {
        position = "left",
        shortcut = "["..sc.."] ",
        cursor = 1,
        -- width = 50,
        align_shortcut = "left",
        hl_shortcut = "Number",
        shrink_margin = false,
    }
    if keybind then
        keybind_opts = if_nil(keybind_opts, {noremap = true, silent = true, nowait = true})
        opts.keymap = {"n", sc_, keybind, {noremap = false, silent = true, nowait = true}}
    end

    return {
        type = "button",
        val = txt,
        on_press = function()
            local key = vim.api.nvim_replace_termcodes(sc_ .. '<Ignore>', true, false, true)
            vim.api.nvim_feedkeys(key, "normal", false)
        end,
        opts = opts
    }
end

local function mru(start, cwd)
    vim.cmd("rshada")
    local oldfiles = {}
    for _,v in pairs(vim.v.oldfiles) do
        if #oldfiles == 10 then break end
        local cwd_cond
        if not cwd
            then cwd_cond = true
            else cwd_cond = vim.fn.filereadable(v) == 1
        end
        if (vim.fn.filereadable(v) == 1) and cwd_cond then
            oldfiles[#oldfiles+1] = v
        end
    end

    local tbl = {}
    local function icon(fn)
        if pcall(require, 'nvim-web-devicons')
        then
            local nvim_web_devicons = require('nvim-web-devicons')
            local match = fn:match("^.+(%..+)$")
            local ext = ''
            if match ~= nil then
                ext = match:sub(2)
            end
                return nvim_web_devicons.get_icon(fn, ext, { default = true })
        else
            return '', nil
        end
    end
    for i, fn in pairs(oldfiles) do
        local ico, hl = icon(fn)
        local short_fn
        if cwd
            then short_fn = vim.fn.fnamemodify(fn, ':.')
            else short_fn = vim.fn.fnamemodify(fn, ':~')
        end
        local file_button = button(tostring(i+start-1), ico .. '  ' .. short_fn , ":e " .. fn .. " <CR>")
        if hl then file_button.opts.hl = { { hl, 0, 1 } } end -- starts at val and not shortcut
        tbl[#tbl+1] = file_button
    end
    return {
        type = "group",
        val = tbl,
        opts = {
        }
    }
end


local section = {
    header = default_header,
    top_buttons = {
        type = "group",
        val = {
            button("e", "New file", ":ene <BAR> startinsert <CR>"),
        }
    },
    mru = {
        type = "group",
        val = {
            {type = "text", val = "MRU", opts = { hl = "Comment" }},
            {type = "padding", val = 1},
            mru(0),
        }
    },
    mru_cwd = {
        type = "group",
        val = {
            {type = "text", val = "MRU " .. vim.fn.getcwd() , opts = { hl = "Comment" }},
            {type = "padding", val = 1},
            mru(10, vim.fn.getcwd),
        }
    },
    bottom_buttons = {
        type = "group",
        val = {
            button("q", "Quit", ":q <CR>"),
        }
    },
}

local opts = {
    layout = {
        {type = "padding", val = 2},
        section.header,
        {type = "padding", val = 2},
        section.top_buttons,
        {type = "padding", val = 1},
        section.mru,
        {type = "padding", val = 1},
        section.mru_cwd,
        {type = "padding", val = 1},
        section.bottom_buttons,
    },
    opts = {
        margin = 3,
    },
}

return {
    button = button,
    mru = mru,
    section = section,
    opts = opts,
}
