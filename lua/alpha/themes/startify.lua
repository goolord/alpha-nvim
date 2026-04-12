local utils = require("alpha.utils")

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

local git_info = { is_git = false, branch = nil }

local function update_git_info()
    local cwd = vim.fn.getcwd()
    local git_root = vim.fn.systemlist(
        "git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel"
    )[1]
    if vim.v.shell_error ~= 0 or not git_root then
        git_info = { is_git = false, branch = nil }
        return
    end
    local branch = vim.fn.systemlist(
        "git -C " .. vim.fn.shellescape(cwd) .. " branch --show-current"
    )[1]
    git_info = {
        is_git = true,
        branch = (branch and branch ~= "") and branch or nil,
    }
end

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
        local key = vim.api.nvim_replace_termcodes(keybind .. "<Ignore>", true, false, true)
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

local function icon(fn)
    if file_icons.provider ~= "devicons" and file_icons.provider ~= "mini" then
        vim.notify("Alpha: Invalid file icons provider: " .. file_icons.provider .. ", disable file icons", vim.log.levels.WARN)
        file_icons.enabled = false
        return "", ""
    end

    local ico, hl = utils.get_file_icon(file_icons.provider, fn)
    if ico == "" then
        file_icons.enabled = false
        vim.notify("Alpha: Mini icons or devicons get icon failed, disable file icons", vim.log.levels.WARN)
    end
    return ico, hl
end

local function file_button(fn, sc, short_fn, autocd)
    short_fn = if_nil(short_fn, fn)
    local ico_txt
    local fb_hl = {}
    if file_icons.enabled then
        local ico, hl = icon(fn)
        local hl_option_type = type(file_icons.highlight)
        if hl_option_type == "boolean" then
            if hl and file_icons.highlight then
                table.insert(fb_hl, { hl, 0, #ico })
            end
        end
        if hl_option_type == "string" then
            table.insert(fb_hl, { file_icons.highlight, 0, #ico })
        end
        ico_txt = ico .. "  "
    else
        ico_txt = ""
    end
    local cd_cmd = (autocd and " | cd %:p:h" or "")
    local file_button_el = button(sc, ico_txt .. short_fn, "<cmd>e " .. vim.fn.fnameescape(fn) .. cd_cmd .. " <CR>")
    local fn_start = short_fn:match(".*[/\\]")
    if fn_start ~= nil then
        table.insert(fb_hl, { "Comment", #ico_txt, #fn_start + #ico_txt })
    end
    file_button_el.opts.hl = fb_hl
    return file_button_el
end

local default_mru_ignore = { "gitcommit" }

local mru_opts = {
    ignore = function(path, ext)
        return (string.find(path, "COMMIT_EDITMSG")) or (vim.tbl_contains(default_mru_ignore, ext))
    end,
    autocd = false
}

local function mru_git(start, cwd, items_number, opts)
    opts = opts or mru_opts
    items_number = if_nil(items_number, 10)

    local found = utils.get_git_files(cwd, items_number, opts.ignore)

    local tbl = {}
    for i, fn in ipairs(found) do
        local short_fn
        if cwd then
            short_fn = fnamemodify(fn, ":.")
        else
            short_fn = fnamemodify(fn, ":~")
        end
        local file_button_el = file_button(fn, tostring(i + start - 1), short_fn, opts.autocd)
        tbl[i] = file_button_el
    end
    return {
        type = "group",
        val = tbl,
        opts = {},
    }
end

local function mru(start, cwd, items_number, opts)
    opts = opts or mru_opts
    items_number = if_nil(items_number, 10)

    local found = utils.get_mru(cwd, items_number, opts.ignore)

    local tbl = {}
    for i, fn in ipairs(found) do
        local short_fn
        if cwd then
            short_fn = fnamemodify(fn, ":.")
        else
            short_fn = fnamemodify(fn, ":~")
        end
        local file_button_el = file_button(fn, tostring(i + start - 1), short_fn, opts.autocd)
        tbl[i] = file_button_el
    end
    return {
        type = "group",
        val = tbl,
        opts = {},
    }
end

local function make_git_title_el(opts)
    local cwd_short = fnamemodify(vim.fn.getcwd(), ":~")
    local branch = git_info.branch
    if branch then
        local head = "MRU " .. cwd_short .. " "
        return {
            type = "text",
            val = head .. branch,
            opts = vim.tbl_extend("force", {
                hl = {
                    { "SpecialComment", 0, #head },
                    { "Label", #head, #head + #branch },
                },
                shrink_margin = false,
            }, opts or {}),
        }
    else
        return {
            type = "text",
            val = "MRU " .. cwd_short,
            opts = vim.tbl_extend("force", { hl = "SpecialComment", shrink_margin = false }, opts or {}),
        }
    end
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
            { type = "text", val = "MRU", opts = { hl = "SpecialComment" } },
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
                { type = "text", val = "MRU " .. fnamemodify(cwd, ":~"), opts = { hl = "SpecialComment", shrink_margin = false } },
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

local mru_sections = { "mru_cwd", "mru" }

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
                for _, name in ipairs(mru_sections) do
                    if section[name] then
                        table.insert(result, section[name])
                    end
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
        setup = function()
            update_git_info()
            vim.api.nvim_create_autocmd('DirChanged', {
                pattern = '*',
                group = "alpha_temp",
                callback = function ()
                    utils.mru_cache = {}
                    update_git_info()
                    require('alpha').redraw()
                    vim.cmd('AlphaRemap')
                end,
            })
        end,
    },
}

return {
    icon = icon,
    button = button,
    file_button = file_button,
    mru = mru,
    mru_git = mru_git,
    mru_opts = mru_opts,
    mru_sections = mru_sections,
    section = section,
    config = config,
    -- theme config
    file_icons = file_icons,
    -- deprecated
    nvim_web_devicons = file_icons,
    leader = leader,
    -- deprecated
    opts = config,
}
