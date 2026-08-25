--- Recent-files sections, shared by the bundled themes.
---
--- A theme supplies its own button constructor and icon config, and gets
--- `file_button`, `mru` and `mru_git` back:
---
--- ```lua
--- local recent = require("alpha.themes.mru").new({
---     button = my_button,
---     file_icons = my_file_icons,
---     mru_opts = my_mru_opts,
--- })
--- local section = { type = "group", val = function() return { recent.mru(0, vim.fn.getcwd()) } end }
--- ```
local utils = require("alpha.utils")

local if_nil = vim.F.if_nil
local fnamemodify = vim.fn.fnamemodify
local strdisplaywidth = vim.fn.strdisplaywidth

local M = {}

--- Git state of the current working directory. Read by themes for section
--- titles, refreshed lazily so nothing runs git on the startup path unless a
--- git section is actually drawn.
M.git_info = { is_git = false, branch = nil }

local git_cwd = nil

function M.update_git_info()
    local cwd = vim.fn.getcwd()
    if cwd == git_cwd then
        return M.git_info
    end
    git_cwd = cwd

    if not utils.git_worktree_root(cwd) then
        M.git_info = { is_git = false, branch = nil }
        return M.git_info
    end
    local branch = vim.fn.systemlist({ "git", "-C", cwd, "branch", "--show-current" })[1]
    M.git_info = {
        is_git = true,
        branch = (branch and branch ~= "") and branch or nil,
    }
    return M.git_info
end

--- Drop the caches that are keyed by working directory and redraw.
--- @param state table? the alpha state, as passed to `opts.setup`
function M.on_dir_changed(state)
    vim.api.nvim_create_autocmd("DirChanged", {
        pattern = "*",
        group = (state and state.augroup) or "alpha_temp",
        callback = function()
            utils.mru_cache = {}
            utils.git_toplevel_cache = {}
            utils.clear_readable_cache()
            git_cwd = nil
            require("alpha").redraw()
        end,
    })
end

local target_width = 35

--- Shorten a path to roughly `target_width` columns, if plenary is available.
--- @param path string
--- @return string
local function shorten(path)
    if strdisplaywidth(path) <= target_width then
        return path
    end
    local plenary_path = utils.try_require("plenary.path")
    if not plenary_path then
        return path
    end
    local short = plenary_path.new(path):shorten(1, { -2, -1 })
    if strdisplaywidth(short) > target_width then
        short = plenary_path.new(short):shorten(1, { -1 })
    end
    return short
end

--- @param spec table theme spec: `button`, `file_icons`, `mru_opts`, and the
--- optional `shorten_paths` and `icon_cursor` flags
--- @return table
function M.new(spec)
    local recent = {}

    --- @param fn string absolute path
    --- @param sc string shortcut
    --- @param short_fn string? display path, defaults to `fn`
    --- @param autocd boolean? cd to the file's directory when pressed
    function recent.file_button(fn, sc, short_fn, autocd)
        short_fn = short_fn or fn
        local file_icons = spec.file_icons
        local hl = {}
        local ico_txt = ""

        if file_icons.enabled then
            local ico, ico_hl = utils.get_icon(file_icons, fn)
            local highlight = file_icons.highlight
            if type(highlight) == "string" then
                hl[#hl + 1] = { highlight, 0, #ico }
            elseif highlight and ico_hl then
                hl[#hl + 1] = { ico_hl, 0, #ico }
            end
            ico_txt = ico .. "  "
        end

        local cd_cmd = autocd and " | cd %:p:h" or ""
        local el = spec.button(sc, ico_txt .. short_fn, "<cmd>e " .. vim.fn.fnameescape(fn) .. cd_cmd .. " <CR>")

        local dir = short_fn:match(".*[/\\]")
        if dir ~= nil then
            hl[#hl + 1] = { "Comment", #ico_txt, #ico_txt + #dir }
        end
        if spec.icon_cursor then
            el.opts.cursor = strdisplaywidth(ico_txt)
        end
        el.opts.hl = hl
        return el
    end

    --- @param fetch fun(cwd: string?, items_number: number, ignore: function?): string[]
    local function section(fetch, start, cwd, items_number, opts)
        opts = opts or spec.mru_opts
        items_number = if_nil(items_number, 10)

        local found = fetch(cwd, items_number, opts.ignore)
        local buttons = {}
        for i, fn in ipairs(found) do
            local short_fn = fnamemodify(fn, cwd and ":." or ":~")
            if spec.shorten_paths then
                short_fn = shorten(short_fn)
            end
            buttons[i] = recent.file_button(fn, tostring(i + start - 1), short_fn, opts.autocd)
        end
        return { type = "group", val = buttons, opts = {} }
    end

    --- @param start number shortcut number of the first entry
    --- @param cwd string? only files under this directory
    --- @param items_number number? how many entries, default 10
    --- @param opts table? overrides the theme's mru_opts
    function recent.mru(start, cwd, items_number, opts)
        return section(utils.get_mru, start, cwd, items_number, opts)
    end

    --- Same as `mru`, but sourced from the git worktree of `cwd`.
    function recent.mru_git(start, cwd, items_number, opts)
        return section(utils.get_git_files, start, cwd, items_number, opts)
    end

    return recent
end

return M
