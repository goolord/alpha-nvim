local default_header = {
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

_G.alpha_redraw = function() end
_G.alpha_cursor_ix = 1
_G.alpha_cursor_jumps = {}
_G.alpha_cursor_jumps_press = {}
_G.alpha_keymaps = {}

function _G.alpha_press()
    _G.alpha_cursor_jumps_press[_G.alpha_cursor_ix]()
end

local function default_button(sc, txt, keybind)
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

local default_opts = {
    layout = {
        {type = "padding", val = 2},
        default_header,
        {type = "padding", val = 2},
        {
            type = "button_group",
            val = {
                default_button("e"      , "  New file"              , ":ene <CR>"),
                default_button("SPC s l", "  Open last session"                  ),
                default_button("SPC f h", "  Recently opened files"              ),
                default_button("SPC f r", "  Frecency/MRU"                       ),
                default_button("SPC f f", "  Find file"                          ),
                default_button("SPC f g", "  Find word"                          ),
                default_button("SPC f m", "  Jump to bookmarks"                  ),
            },
            opts = {
                spacing = 1
            }
        }
    },
    margin = 5
}

local options = default_opts

local function longest_line(tbl)
    local longest = 0
    for _, v in pairs(tbl) do
        if #v > longest then
            longest = #v
        end
    end
    return longest
end

local function center(tbl, state)
    -- longest line used to calculate the center.
    -- which doesn't quite give a 'justfieid' look, but w.e
    local longest = longest_line(tbl)
    local win_width = vim.api.nvim_win_get_width(state.window)
    local left = math.ceil((win_width / 2) - (longest / 2))
    local padding = string.rep(" ", left)
    local centered = {}
    for k, v in pairs(tbl) do
        centered[k] = padding .. v
    end
    return centered, left
end

local function pad_margin(tbl, state, margin)
    local longest = longest_line(tbl)
    local pot_width = margin + margin + longest
    local win_width = vim.api.nvim_win_get_width(state.window)
    local left
    if pot_width > win_width then
        left = (win_width - pot_width) + margin
    else
        left = margin
    end
    local padding = string.rep(" ", left)
    local padded = {}
    for k, v in pairs(tbl) do
        padded[k] = padding .. v .. padding
    end
    return padded
end

-- function trim(tbl, state)
--     local win_width = vim.api.nvim_win_get_width(state.window)
--     local trimmed = {}
--     for k,v in pairs(tbl) do
--         trimmed[k] = string.sub(v, 1, win_width)
--     end
--     return trimmed
-- end

local function layout(opts, state)
    -- this is my way of hacking pattern matching
    -- you index the table by its "type"
    local layout_element = {}

    layout_element.text = function(el)
        if type(el.val) == "table" then
            local end_ln = state.line + #el.val
            local val = el.val
            if opts.margin then
                if el.opts and el.opts.position ~= "center" then
                    val = pad_margin(val, state, opts.margin)
                end
            end
            if el.opts then
                if el.opts.position == "center" then
                    val, _ = center(val, state)
                end
            -- if el.opts.wrap == "overflow" then
            --     val = trim(val, state)
            -- end
            end
            vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
            if el.opts and el.opts.hl then
                for i = state.line, end_ln do
                    vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, i, 0, -1)
                end
            end
            state.line = end_ln
        end
        if type(el.val) == "string" then
            local val = {el.val}
            if opts.margin then
                if el.opts and el.opts.position ~= "center" then
                    val = pad_margin(val, state, opts.margin)
                end
            end
            if el.opts then
                if el.opts.position == "center" then
                    val, _ = center(val, state)
                end
            end
            vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
            if el.opts and el.opts.hl then
                vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, state.line, 0, -1)
            end
            state.line = state.line + 1
        end
    end

    layout_element.padding = function(el)
        local end_ln = state.line + el.val
        local val = {}
        for i = 1, el.val + 1 do
            val[i] = ""
        end
        vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
        state.line = end_ln
    end

    layout_element.button = function(el)
        local val
        local center_pad
        if el.opts and el.opts.shortcut then
            center_pad = (el.opts.width or 0) - (#el.val + #el.opts.shortcut)
            val = {el.val .. string.rep(" ", center_pad) .. el.opts.shortcut}
        else
            val = {el.val}
        end

        if opts.margin then
            if el.opts and el.opts.position ~= "center" then
                val = pad_margin(val, state, opts.margin)
                if center_pad then
                    center_pad = center_pad + opts.margin
                end
            end
        end
        if el.opts then
            if el.opts.position == "center" then
                local left
                val, left = center(val, state)
                if center_pad then
                    center_pad = center_pad + left
                end
            end
        end
        local row = state.line + 1
        local _, count_spaces = string.find(val[1], "%s*")
        local col = ((el.opts and el.opts.cursor) or 0) + count_spaces
        table.insert(_G.alpha_cursor_jumps, {row, col})
        table.insert(_G.alpha_cursor_jumps_press, el.on_press)
        vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
        if el.opts and el.opts.hl then
            vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, state.line, 0, -1)
        end
        if el.opts and el.opts.hl_shortcut and center_pad then
            vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl_shortcut, state.line, #el.val + center_pad, -1)
        end
        state.line = state.line + 1
    end

    layout_element.button_group = function(el)
        for _, v in pairs(el.val) do
            layout_element[v.type](v)
            if el.opts and el.opts.spacing then
                local padding = {type = "padding", val = el.opts.spacing}
                layout_element[padding.type](padding)
            end
        end
    end

    for _, el in pairs(opts.layout) do
        layout_element[el.type](el, state)
    end
end

-- dragons
local function closest_cursor_jump(cursor, cursors, prev_cursor)
    -- accumulator
    local closest
    if cursors then
        closest = {1, cursors[1]} -- base case
    else
        closest = {1, {1, 1}} -- shouldn't happen
    end
    local distances = {}
    for k, v in pairs(cursors) do
        local distance = math.abs(v[1] - cursor[1]) -- new cursor position's distance
        table.insert(distances, k, {distance, k}) -- from each jump
    end
    table.sort(
        distances,
        function(l, r)
            return l[1] < r[1]
        end
    )
    if distances[1][1] == distances[2][1] then -- tie breaker
        local index
        if prev_cursor[1] > cursor[1] then -- we use the velocity as a tie breaker
            index = math.min(distances[1][2], distances[2][2]) -- up
        else
            index = math.max(distances[1][2], distances[2][2]) -- down
        end
        closest = {index, cursors[index]}
    else
        -- returns the key (stored in a jank way so we can sort the table)
        -- and the {row, col} tuple
        closest = {distances[1][2], cursors[distances[1][2]]}
    end
    return closest
end

function _G.alpha_set_cursor()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local closest = closest_cursor_jump(cursor, _G.alpha_cursor_jumps, _G.alpha_cursor_jumps[_G.alpha_cursor_ix])
    _G.alpha_cursor_ix = closest[1]
    vim.api.nvim_win_set_cursor(0, closest[2])
end

local function enable_alpha()
    -- vim.opt_local behaves inconsistently for window options, it seems.
    -- I don't have the patience to sort out a better way to do this
    -- or seperate out the buffer local options.
    vim.cmd(
        [[silent! setlocal bufhidden=wipe colorcolumn= foldcolumn=0 matchpairs= nocursorcolumn nocursorline nolist nonumber norelativenumber nospell noswapfile signcolumn=no synmaxcol& buftype=nofile filetype=alpha]]
    )

    vim.cmd("autocmd alpha CursorMoved <buffer> call v:lua.alpha_set_cursor()")
end

local function start(on_vimenter, opts)
    -- Handle vim -y, vim -M.
    if on_vimenter and (vim.opt.insertmode:get() or (not vim.opt.modifiable:get())) then
        return
    end

    if not vim.opt.hidden:get() and vim.opt.modified:get() then
        vim.api.nvim_err_writeln("Save your changes first.")
        return
    end

    opts = opts or options

    local buffer = vim.api.nvim_create_buf(false, true)
    local window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(window, buffer)
    enable_alpha()

    local state = {
        line = 0,
        buffer = buffer,
        window = window
    }
    local draw = function()
        _G.alpha_cursor_jumps = {}
        _G.alpha_cursor_jumps_press = {}
        _G.alpha_keymaps = {}
        vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, {})
        state.line = 0
        layout(opts, state)
        vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
        vim.api.nvim_buf_set_keymap(
            state.buffer,
            "n",
            "<CR>",
            ":call v:lua.alpha_press()<CR>",
            {noremap = false, silent = true}
        )
    end
    _G.alpha_redraw = draw
    for _, map in pairs(_G.alpha_keymaps) do
        vim.api.nvim_buf_set_keymap(state.buffer, map[1], map[2], map[3], map[4])
    end
    draw()
    vim.api.nvim_win_set_cursor(0, _G.alpha_cursor_jumps[1])
end

local function setup(opts)
    vim.cmd("command Alpha lua require'alpha'.start(false)")
    vim.cmd([[augroup alpha]])
    vim.cmd([[au!]])
    vim.cmd([[autocmd VimResized * if &filetype ==# 'alpha' | call v:lua.alpha_redraw() | endif]])
    vim.cmd([[autocmd VimEnter * nested lua require'alpha'.start(true)]])
    vim.cmd([[augroup END]])
    if type(opts) == "table" then
        options = opts
    end
end

return {
    setup = setup,
    start = start,
    default_opts = default_opts
}
