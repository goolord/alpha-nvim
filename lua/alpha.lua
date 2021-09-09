-- business logic

local utils = require'alpha.utils'
local if_nil = vim.F.if_nil
local deepcopy = utils.deepcopy

local cursor_ix = 1
local cursor_jumps = {}
local cursor_jumps_press = {}

_G.alpha_redraw = function() end
_G.alpha_close = function() end

function _G.alpha_press()
    cursor_jumps_press[cursor_ix]()
end

local function longest_line(tbl)
    local longest = 0
    local strdisplaywidth = vim.fn.strdisplaywidth
    for _, v in pairs(tbl) do
        local width = strdisplaywidth(v)
        if width > longest then
            longest = width
        end
    end
    return longest
end

longest_line = utils.memoize(longest_line)

local function spaces(n)
    return string.rep(" ", n)
end

spaces = utils.memoize(spaces)

local function center(tbl, state)
    -- longest line used to calculate the center.
    -- which doesn't quite give a 'justfieid' look, but w.e
    local longest = longest_line(tbl)
    local left = math.ceil((state.win_width - longest) / 2)
    local padding = spaces(left)
    local centered = {}
    for k, v in pairs(tbl) do
        centered[k] = padding .. v
    end
    return centered, left
end

local function pad_margin(tbl, state, margin, shrink)
    local longest = longest_line(tbl)
    local pot_width = margin + margin + longest
    local left
    if shrink and (pot_width > state.win_width) then
        left = (state.win_width - pot_width) + margin
    else
        left = margin
    end
    local padding = spaces(left)
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


local layout_element = {}

layout_element.text = function(el, opts, state)
    if type(el.val) == "table" then
        local end_ln = state.line + #el.val
        local val = el.val
        if opts.opts and opts.opts.margin and el.opts and (el.opts.position ~= "center") then
            val = pad_margin(val, state, opts.opts.margin, if_nil(el.opts.shrink_margin, true))
        end
        if el.opts then
            if el.opts.position == "center" then
                val, _ = center(val, state)
            end
        -- if el.opts.wrap == "overflow" then
        --     val = trim(val, state)
        -- end
        end
        vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, false, val)
        if el.opts and el.opts.hl then
            for i = state.line, end_ln do
                vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, i, 0, -1)
            end
        end
        state.line = end_ln
    end

    if type(el.val) == "string" then
        local val = {}
        val = {}
        for s in el.val:gmatch("[^\r\n]+") do
            val[#val+1] = s
        end
        if opts.opts and opts.opts.margin and el.opts and (el.opts.position ~= "center") then
            val = pad_margin(val, state, opts.opts.margin, if_nil(el.opts.shrink_margin, true))
        end
        if el.opts then
            if el.opts.position == "center" then
                val, _ = center(val, state)
            end
        end
        vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, false, val)
        local end_ln = state.line + #val
        if el.opts and el.opts.hl then
            for i = state.line, end_ln do
                vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, i, 0, -1)
            end
        end
        state.line = end_ln
    end

    if type(el.val) == "function" then
        local new_el = deepcopy(el)
        new_el.val = el.val()
        layout_element.text(new_el, opts, state)
    end
end

layout_element.padding = function(el, opts, state)
    local end_ln = state.line + el.val
    local val = {}
    for i = 1, el.val + 1 do
        val[i] = ""
    end
    vim.api.nvim_buf_set_lines(state.buffer, state.line, end_ln, false, val)
    state.line = end_ln
end

layout_element.button = function(el, opts, state)
    local val
    local padding = {
        left   = 0,
        center = 0,
        right  = 0,
    }
    if el.opts and el.opts.shortcut then
        -- this min lets the padding resize when the window gets smaller
        if el.opts.width then
            local max_width = math.min(el.opts.width, state.win_width)
            if el.opts.align_shortcut == "right"
                then padding.center = max_width - (#el.val + #el.opts.shortcut)
                else padding.right = max_width - (#el.val + #el.opts.shortcut)
            end
        end
        if el.opts.align_shortcut == "right"
            then val = {el.val .. spaces(padding.center) .. el.opts.shortcut}
            else val = {el.opts.shortcut .. " " .. el.val .. spaces(padding.right)}
        end
    else
        val = {el.val}
    end

    -- margin
    if opts.opts and opts.opts.margin and el.opts and (el.opts.position ~= "center") then
        val = pad_margin(val, state, opts.opts.margin, if_nil(el.opts.shrink_margin, true))
        if el.opts.align_shortcut == "right"
            then padding.center = padding.center + opts.opts.margin
            else padding.left = padding.left + opts.opts.margin
        end
    end

    -- center
    if el.opts then
        if el.opts.position == "center" then
            local left
            val, left = center(val, state)
            if el.opts.align_shortcut == "right"
                then padding.center = padding.center + left
                else padding.left = padding.left + left
            end
        end
    end

    local row = state.line + 1
    local _, count_spaces = string.find(val[1], "%s*")
    local col = ((el.opts and el.opts.cursor) or 0) + count_spaces
    cursor_jumps[#cursor_jumps+1] = {row, col}
    cursor_jumps_press[#cursor_jumps_press+1] = el.on_press
    vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, false, val)
    if el.opts and el.opts.hl_shortcut then
        if el.opts.align_shortcut == "right"
            then vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl_shortcut, state.line, #el.val + padding.center, -1)
            else vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl_shortcut, state.line, padding.left, padding.left + #el.opts.shortcut)
        end
    end

    if el.opts and el.opts.hl then
        local left = padding.left
        if el.opts.align_shortcut == "left" then left = left + #el.opts.shortcut + 3 end
        for _, hl in pairs(el.opts.hl) do
            vim.api.nvim_buf_add_highlight(
                state.buffer,
                -1,
                hl[1],
                state.line,
                left + hl[2],
                left + hl[3]
            )
        end
    end
    state.line = state.line + 1
end

layout_element.group = function(el, opts, state)
    if type(el.val) == "function"
    then
        local new_el = deepcopy(el)
        new_el.val = el.val()
        layout_element.group(new_el, opts, state)
    else
        for _, v in pairs(el.val) do
            layout_element[v.type](v, opts, state)
            if el.opts and el.opts.spacing then
                local padding_el = {type = "padding", val = el.opts.spacing}
                layout_element[padding_el.type](padding_el, opts, state)
            end
        end
    end
end

local function layout(opts, state)
    -- this is my way of hacking pattern matching
    -- you index the table by its "type"
    for _, el in pairs(opts.layout) do
        layout_element[el.type](el, opts, state)
    end
end

local keymaps_element = {}

keymaps_element.text = function () end
keymaps_element.padding = function () end

keymaps_element.button = function (el, opts, state)
    if el.opts and el.opts.keymap then
        local map = el.opts.keymap
        vim.api.nvim_buf_set_keymap(state.buffer, map[1], map[2], map[3], map[4])
    end
end

keymaps_element.group = function (el, opts, state)
    if type(el.val) == "function"
    then
        local new_el = deepcopy(el)
        new_el.val = el.val()
        keymaps_element.group(new_el, opts, state)
    else
        for _, v in pairs(el.val) do
            keymaps_element[v.type](v, opts, state)
        end
    end
end

local function keymaps(opts, state)
    for _, el in pairs(opts.layout) do
        keymaps_element[el.type](el, opts, state)
    end
end

-- dragons
local function closest_cursor_jump(cursor, cursors, prev_cursor)
    local direction = prev_cursor[1] > cursor[1] -- true = UP, false = DOWN
    -- minimum distance key from jump point
    -- excluding jumps in opposite direction
    local min
    local cursor_row = cursor[1]
    local abs = math.abs
    for k, v in pairs(cursors) do
        local distance = v[1] - cursor_row -- new cursor distance from old cursor
        if direction and (distance <= 0) then
            distance = abs(distance)
            local res = {distance, k}
            if not min then min = res end
            if min[1] > res[1] then min = res end
        end
        if (not direction) and (distance >= 0) then
            local res = {distance, k}
            if not min then min = res end
            if min[1] > res[1] then min = res end
        end
    end
    if not min -- top or bottom
        then
            if direction
                then return 1, cursors[1]
                else return #cursors, cursors[#cursors]
            end
        else
            -- returns the key (stored in a jank way so we can sort the table)
            -- and the {row, col} tuple
            return min[2], cursors[min[2]]
    end
end

_G.alpha_set_cursor = function ()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local closest_ix, closest_pt = closest_cursor_jump(cursor, cursor_jumps, cursor_jumps[cursor_ix])
    cursor_ix = closest_ix
    vim.api.nvim_win_set_cursor(0, closest_pt)
end

local function enable_alpha(opts)
    -- vim.opt_local behaves inconsistently for window options, it seems.
    -- I don't have the patience to sort out a better way to do this
    -- or seperate out the buffer local options.
    vim.cmd(
        [[silent! setlocal bufhidden=wipe colorcolumn= foldcolumn=0 matchpairs= nocursorcolumn nocursorline nolist nonumber norelativenumber nospell noswapfile signcolumn=no synmaxcol& buftype=nofile filetype=alpha nowrap]]
    )

    vim.cmd("autocmd alpha CursorMoved <buffer> call v:lua.alpha_set_cursor()")

    if opts.setup then opts.setup() end
end

local options

local function start(on_vimenter, opts)
    if on_vimenter then
        if vim.opt.insertmode:get()       -- Handle vim -y
            or (not vim.opt.modifiable:get()) -- Handle vim -M
            or vim.fn.argc() ~= 0 -- should probably figure out
                                  -- how to be smarter than this
        then return end
     end

    if not vim.opt.hidden:get() and vim.opt_local.modified:get() then
        vim.api.nvim_err_writeln("Save your changes first.")
        return
    end

    opts = opts or options

    local buffer = vim.api.nvim_create_buf(false, true)
    local window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(window, buffer)
    enable_alpha(opts)

    local state = {
        line = 0,
        buffer = buffer,
        window = window,
        win_width = 0
    }
    local function draw()
        for k in pairs(cursor_jumps) do cursor_jumps[k] = nil end
        for k in pairs(cursor_jumps_press) do cursor_jumps_press[k] = nil end
        state.win_width = vim.api.nvim_win_get_width(state.window)
        state.line = 0
        -- this is for redraws. i guess the cursor 'moves'
        -- when the screen is cleared and then redrawn
        -- so we save the index before that happens
        local ix = cursor_ix
        vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)
        vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, {})
        layout(opts, state)
        vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
        vim.api.nvim_buf_set_keymap(
            state.buffer,
            "n",
            "<CR>",
            ":call v:lua.alpha_press()<CR>",
            {noremap = false, silent = true}
        )
        vim.api.nvim_win_set_cursor(0, cursor_jumps[ix])
    end
    _G.alpha_redraw = draw
    _G.alpha_close = function ()
        -- deletes the buffer so there's nothing left in the window :Y
        -- vim.api.nvim_buf_delete(state.buffer, {})

        cursor_ix = 1
        cursor_jumps = {}
        cursor_jumps_press = {}

        _G.alpha_redraw = function() end
        _G.alpha_close = function() end
    end
    draw()
    keymaps(opts, state)
end

local function setup(opts)
    vim.cmd("command! Alpha lua require'alpha'.start(false)")
    vim.cmd("command! AlphaRedraw call v:lua.alpha_redraw()")
    vim.cmd([[
        augroup alpha
        au!
        autocmd VimResized * if &filetype ==# 'alpha' | call v:lua.alpha_redraw() | endif
        autocmd VimEnter * nested lua require'alpha'.start(true)
        autocmd BufUnload alpha call v:lua.alpha_close() 
        augroup END
    ]])
    if type(opts) == "table" then
        options = opts
    end
end

return {
    setup = setup,
    start = start,
}
