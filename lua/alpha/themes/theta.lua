local dashboard = require("alpha.themes.dashboard")
local recent_files = require("alpha.themes.mru")
local utils = require("alpha.utils")

local file_icons = {
    enabled = true,
    highlight = true,
    -- available: devicons, mini, to use nvim-web-devicons or mini.icons
    -- if provider not loaded and enabled is true, it will try to use another provider
    provider = "mini",
}

local function icon(fn)
    return utils.get_icon(file_icons, fn)
end

local default_mru_ignore = { "gitcommit" }

local mru_opts = {
    ignore = function(path, ext)
        return (string.find(path, "COMMIT_EDITMSG")) or (vim.tbl_contains(default_mru_ignore, ext))
    end,
    autocd = false,
}

local recent = recent_files.new({
    button = dashboard.button,
    file_icons = file_icons,
    mru_opts = mru_opts,
    -- long paths are shortened with plenary, and the cursor sits after the icon
    shorten_paths = true,
    icon_cursor = true,
})

local mru = recent.mru
local mru_git = recent.mru_git

local header = {
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

local section_mru = {
    type = "group",
    val = {
        {
            type = "text",
            val = "Recent files",
            opts = {
                hl = "SpecialComment",
                shrink_margin = false,
                position = "center",
            },
        },
        { type = "padding", val = 1 },
        {
            type = "group",
            val = function()
                return { mru(0, vim.fn.getcwd()) }
            end,
            opts = { shrink_margin = false },
        },
    },
}

local section_mru_git = {
    type = "group",
    val = function()
        recent_files.update_git_info()
        return {
            {
                type = "text",
                val = function()
                    local branch = recent_files.git_info.branch
                    return branch and ("MRU " .. branch) or "MRU"
                end,
                opts = {
                    hl = "SpecialComment",
                    shrink_margin = false,
                    position = "center",
                },
            },
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
}

local buttons = {
    type = "group",
    val = {
        { type = "text",    val = "Quick links", opts = { hl = "SpecialComment", position = "center" } },
        { type = "padding", val = 1 },
        dashboard.button("e", "  New file", "<cmd>ene<CR>"),
        dashboard.button("SPC f f", "󰈞  Find file"),
        dashboard.button("SPC f g", "󰊄  Live grep"),
        dashboard.button("c", "  Configuration", "<cmd>exe 'cd' stdpath ('config')<CR>"),
        dashboard.button("u", "  Update plugins", "<cmd>Lazy sync<CR>"),
        dashboard.button("q", "󰅚  Quit", "<cmd>qa<CR>"),
    },
    position = "center",
}

local config = {
    layout = {
        { type = "padding", val = 2 },
        header,
        { type = "padding", val = 2 },
        section_mru,
        { type = "padding", val = 2 },
        buttons,
    },
    opts = {
        margin = 5,
        setup = recent_files.on_dir_changed,
    },
}

return {
    header = header,
    buttons = buttons,
    icon = icon,
    file_button = recent.file_button,
    mru = mru,
    mru_git = mru_git,
    section_mru = section_mru,
    section_mru_git = section_mru_git,
    config = config,
    -- theme specific config
    mru_opts = mru_opts,
    leader = dashboard.leader,
    file_icons = file_icons,
    -- deprecated
    nvim_web_devicons = file_icons,
}
