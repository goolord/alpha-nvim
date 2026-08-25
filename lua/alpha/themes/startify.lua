local recent_files = require("alpha.themes.mru")
local utils = require("alpha.utils")

--- Mutable theme table; closures read fields here so user config (e.g. mru_sections) applies.
local startify = {}

local if_nil = vim.F.if_nil
local fnamemodify = vim.fn.fnamemodify

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
        hl = "Type",
        shrink_margin = false,
        -- wrap = "overflow";
    },
}

local leader = "SPC"

--- @param sc string
--- @param txt string
--- @param keybind string? optional
--- @param keybind_opts table? optional
local function button(sc, txt, keybind, keybind_opts)
    local sc_ = sc:gsub("%s", ""):gsub(leader, "<leader>")

    local opts = {
        position = "left",
        shortcut = "[" .. sc .. "] ",
        cursor = 1,
        -- width = 50,
        align_shortcut = "left",
        hl_shortcut = { { "Operator", 0, 1 }, { "Number", 1, #sc + 1 }, { "Operator", #sc + 1, #sc + 2 } },
        shrink_margin = false,
    }
    if keybind then
        keybind_opts = if_nil(keybind_opts, { noremap = true, silent = true, nowait = true })
        opts.keymap = { "n", sc_, keybind, keybind_opts }
    end

    local function on_press()
        local key = vim.api.nvim_replace_termcodes((keybind or sc_) .. "<Ignore>", true, false, true)
        vim.api.nvim_feedkeys(key, "t", false)
    end

    return {
        type = "button",
        val = txt,
        on_press = on_press,
        opts = opts,
    }
end

local file_icons = {
    enabled = true,
    highlight = true,
    -- available: devicons, mini, to use nvim-web-devicons or mini.icons
    -- if provider not loaded and enabled is true, it will try to use another provider
    provider = "mini",
}

local default_mru_ignore = { "gitcommit" }

local mru_opts = {
    ignore = function(path, ext)
        return (string.find(path, "COMMIT_EDITMSG")) or (vim.tbl_contains(default_mru_ignore, ext))
    end,
    autocd = false
}

local recent = recent_files.new({
    button = button,
    file_icons = file_icons,
    mru_opts = mru_opts,
})

local mru = recent.mru
local mru_git = recent.mru_git

local function icon(fn)
    return utils.get_icon(file_icons, fn)
end

local function make_git_title_el()
    local cwd_short = fnamemodify(vim.fn.getcwd(), ":~")
    local branch = recent_files.git_info.branch
    if not branch then
        return {
            type = "text",
            val = "MRU " .. cwd_short,
            opts = { hl = "SpecialComment", shrink_margin = false },
        }
    end
    local head = "MRU " .. cwd_short .. " "
    return {
        type = "text",
        val = head .. branch,
        opts = {
            hl = {
                { "SpecialComment", 0,     #head },
                { "Label",          #head, #head + #branch },
            },
            shrink_margin = false,
        },
    }
end

local section = {
    header = default_header,
    top_buttons = {
        type = "group",
        val = {
            button("e", "New file", "<cmd>ene <CR>"),
        },
    },
    -- note about MRU: currently this is a function,
    -- since that means we can get a fresh mru
    -- whenever there is a DirChanged. this is *really*
    -- inefficient on redraws, since mru does a lot of I/O.
    -- should probably be cached, or maybe figure out a way
    -- to make it a reference to something mutable
    -- and only mutate that thing on DirChanged
    mru = {
        type = "group",
        val = {
            { type = "padding", val = 1 },
            { type = "text",    val = "MRU", opts = { hl = "SpecialComment" } },
            { type = "padding", val = 1 },
            {
                type = "group",
                val = function()
                    return { mru(10) }
                end,
            },
        },
    },
    mru_cwd = {
        type = "group",
        val = function()
            local cwd = vim.fn.getcwd()
            return {
                { type = "padding", val = 1 },
                { type = "text",    val = "MRU " .. fnamemodify(cwd, ":~"), opts = { hl = "SpecialComment", shrink_margin = false } },
                { type = "padding", val = 1 },
                {
                    type = "group",
                    val = function() return { mru(0, cwd) } end,
                    opts = { shrink_margin = false },
                },
            }
        end,
    },
    mru_git = {
        type = "group",
        val = function()
            recent_files.update_git_info()
            return {
                { type = "padding", val = 1 },
                make_git_title_el(),
                { type = "padding", val = 1 },
                {
                    type = "group",
                    val = function()
                        return { mru_git(0, vim.fn.getcwd()) }
                    end,
                    opts = { shrink_margin = false },
                },
            }
        end,
    },
    bottom_buttons = {
        type = "group",
        val = {
            button("q", "Quit", "<cmd>q <CR>"),
        },
    },
    footer = {
        type = "group",
        val = {},
    },
}

startify.mru_sections = { "mru_cwd", "mru" }

local config = {
    layout = {
        { type = "padding", val = 1 },
        section.header,
        { type = "padding", val = 2 },
        section.top_buttons,
        {
            type = "group",
            val = function()
                local result = {}
                for _, name in ipairs(startify.mru_sections) do
                    result[#result + 1] = section[name]
                end
                return result
            end,
        },
        { type = "padding", val = 1 },
        section.bottom_buttons,
        section.footer,
    },
    opts = {
        margin = 3,
        redraw_on_resize = false,
        setup = recent_files.on_dir_changed,
    },
}

startify.icon = icon
startify.button = button
startify.file_button = recent.file_button
startify.mru = mru
startify.mru_git = mru_git
startify.mru_opts = mru_opts
startify.section = section
startify.config = config
startify.file_icons = file_icons
startify.nvim_web_devicons = file_icons
startify.leader = leader
startify.opts = config

return startify
