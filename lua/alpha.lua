local alpha = {}

-- business logic
local abs = math.abs
local concat = table.concat
local deepcopy = vim.deepcopy
local if_nil = vim.F.if_nil
local list_extend = vim.list_extend
local str_rep = string.rep
local strdisplaywidth = vim.fn.strdisplaywidth

local cursor_ix = 1
local cursor_jumps = {}
local cursor_jumps_press = {}
local cursor_jumps_press_queue = {}

-- map of buffer -> state
local alpha_state = {}
local function head(t)
    local next,_,_ = pairs(t)
    return t[next(t)]
end

local function noop() end

local function active_window(state)
    local curr_win = vim.api.nvim_get_current_win()
    local win
    if vim.api.nvim_win_get_buf(curr_win) == state.buffer then
        win = curr_win
    else
        win = state.windows[1]
    end
    return win
end

function alpha.press()
    -- only press under the cursor if there's no queue
    if vim.tbl_count(cursor_jumps_press_queue) == 0 then
        cursor_jumps_press[cursor_ix]()
    end
    for queued_cursor_ix, _ in pairs(cursor_jumps_press_queue) do
        cursor_jumps_press[queued_cursor_ix]()
    end
end

local function draw_press(row, col, state)
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)
    -- todo: represent this in the alpha layout, somehow
    vim.api.nvim_buf_set_text(state.buffer, row - 1, col, row - 1, col + 1, { "*" })
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
end

local function draw_presses(state)
    for _, loc in pairs(cursor_jumps_press_queue) do
        local row = loc[1]
        local col = loc[2]
        draw_press(row, col, state)
    end
end

function alpha.queue_press(state)
    if cursor_jumps_press_queue[cursor_ix] then
        cursor_jumps_press_queue[cursor_ix] = nil
    else

        local cursor = vim.api.nvim_win_get_cursor(active_window(state))
        local row = cursor[1]
        local col = cursor[2]

        cursor_jumps_press_queue[cursor_ix] = {row,col}

        draw_press(row,col,state)
        local height = state.line
        vim.api.nvim_win_set_cursor(0, { math.min(row + 1, height), col })
    end
end

local function longest_line(tbl)
    local longest = 0
    for _, v in pairs(tbl) do
        local width = strdisplaywidth(v)
        if width > longest then
            longest = width
        end
    end
    return longest
end

local function spaces(n)
    return str_rep(" ", n)
end

---@param keymaps nil | string | string[]
---@return string[]
local function normalize_keymaps(keymaps)
    if keymaps == nil then
        return {}
    end

    if type(keymaps) ~= "table" then
        keymaps = { keymaps }
    end

    return keymaps
end

function alpha.align_center(tbl, state)
    -- longest line used to calculate the center.
    -- which doesn't quite give a 'justfieid' look, but w.e
    local longest = longest_line(tbl)
    -- div 2
    local left = bit.arshift(state.win_width - longest, 1)
    local padding = spaces(left)
    local centered = {}
    for k, v in pairs(tbl) do
        centered[k] = padding .. v
    end
    return centered, left
end

function alpha.pad_margin(tbl, state, margin, shrink)
    local longest = longest_line(tbl)
    local left
    if shrink then
        local pot_width = margin + margin + longest
        if pot_width > state.win_width then
            left = (state.win_width - pot_width) + margin
        else
            left = margin
        end
    else
        left = margin
    end
    local padding = spaces(left)
    local padded = {}
    for k, v in pairs(tbl) do
        padded[k] = padding .. v
    end
    return padded, left
end

-- function trim(tbl, state)
--     local win_width = vim.api.nvim_win_get_width(state.windows[1])
--     local trimmed = {}
--     for k,v in ipairs(tbl) do
--         trimmed[k] = string.sub(v, 1, win_width)
--     end
--     return trimmed
-- end

function alpha.highlight(state, end_ln, hl, left, el)
    local hl_type = type(hl)
    local hl_tbl = {}
    if hl_type == "string" then
        for i = state.line, end_ln do
            table.insert(hl_tbl, { state.buffer, -1, hl, i, 0, -1 })
        end
    end
    if hl_type == "table" then
        local function single_line(the_hl, line)
            for _, hl_section in pairs(the_hl) do
                local col_end
                if hl_section[3] < 0 then
                    if type(el.val) == "string" then
                        col_end = left + #el.val + hl_section[3] + 1
                    else
                        col_end = -1
                    end
                else
                    col_end = left + hl_section[3]
                end
                table.insert(hl_tbl, {
                    state.buffer,
                    -1,
                    hl_section[1],
                    state.line + line,
                    left + hl_section[2],
                    col_end,
                })
            end
        end
        if hl[1] and hl[1][1] and type(hl[1][1]) == "table" then
            for ix, hl_line in ipairs(hl) do
                single_line(hl_line, ix-1)
            end
        else
            single_line(hl, 0)
        end
    end
    return hl_tbl
end

local layout_element = {}

function alpha.resolve(to, el, opts, state)
    local new_el = deepcopy(el)
    new_el.val = el.val()
    return to(new_el, opts, state)
end

function layout_element.text(el, conf, state)
    if type(el.val) == "function" then
        return alpha.resolve(layout_element.text, el, conf, state)
    end
    local val
    if type(el.val) == "string" then
        val = {}
        for s in el.val:gmatch("[^\r\n]+") do
            val[#val + 1] = s
        end
    else
        val = el.val
    end
    local hl = {}
    local padding = { left = 0 }
    local margin = vim.tbl_get(conf, 'opts', 'margin')
    local position = vim.tbl_get(el, 'opts', 'position')
    if margin and (position ~= "center") then
        local left
        val, left = alpha.pad_margin(val, state, margin, if_nil(vim.tbl_get(el, 'opts', 'shrink_margin'), true))
        padding.left = padding.left + left
    end
    if position == "center" then
        local left
        val, left = alpha.align_center(val, state)
        padding.left = padding.left + left
    end
    local el_hl = vim.tbl_get(el, 'opts', 'hl')
    if type(el.val) == "string" then
        if el_hl then
            hl = alpha.highlight(state, state.line, el_hl, padding.left, el)
        end
        state.line = state.line + 1
    else
        local end_ln = state.line + #el.val
        if el_hl then
            hl = alpha.highlight(state, end_ln, el_hl, padding.left, el)
        end
        state.line = end_ln
    end
    return val, hl

end

---@diagnostic disable-next-line: unused-local
function layout_element.padding(el, conf, state)
    local lines = 0
    if type(el.val) == "function" then
        lines = el.val()
    end
    if type(el.val) == "number" then
        lines = el.val
    end
    local val = {}
    for i = 1, lines do
        val[i] = ""
    end
    local end_ln = state.line + lines
    state.line = end_ln
    return val, {}
end

function layout_element.button(el, conf, state)
    local val = {}
    local hl = {}
    local padding = {
        left = 0,
        center = 0,
        right = 0,
    }
    local opts = vim.tbl_get(el, 'opts') or {}
    local shortcut = vim.tbl_get(opts, 'shortcut')
    local width = vim.tbl_get(opts, 'width')
    if shortcut then
        -- this min lets the padding resize when the window gets smaller
        if width then
            local max_width = math.min(width, state.win_width)
            local shortcut_padding = max_width - (strdisplaywidth(el.val) + strdisplaywidth(shortcut))
            if opts.align_shortcut == "right" then
                padding.center = shortcut_padding
            else
                padding.right = shortcut_padding
            end
        end
        if opts.align_shortcut == "right" then
            val = { concat({ el.val, spaces(padding.center), opts.shortcut }) }
        else
            val = { concat({ opts.shortcut, el.val, spaces(padding.right) }) }
        end
    else
        val = { el.val }
    end

    -- margin
    if vim.tbl_get(conf, 'opts', 'margin') and (vim.tbl_get(opts, 'position') ~= "center") then
        local left
        val, left = alpha.pad_margin(val, state, conf.opts.margin, if_nil(vim.tbl_get(opts, 'shrink_margin'), true))
        if vim.tbl_get(opts, 'align_shortcut') == "right" then
            padding.center = padding.center + left
        else
            padding.left = padding.left + left
        end
    end

    -- center
    if vim.tbl_get(el, 'opts', 'position') == "center" then
        local left
        val, left = alpha.align_center(val, state)
        if el.opts.align_shortcut == "right" then
            padding.center = padding.center + left
        end
        padding.left = padding.left + left
    end

    local row = state.line + 1
    local col = ((el.opts and el.opts.cursor) or 0) + padding.left
    cursor_jumps[#cursor_jumps + 1] = { row, col }
    cursor_jumps_press[#cursor_jumps_press + 1] = el.on_press
    if el.opts and el.opts.hl_shortcut then
        if type(el.opts.hl_shortcut) == "string" then
            hl = { { el.opts.hl_shortcut, 0, #el.opts.shortcut + 1 } }
        else
            hl = el.opts.hl_shortcut
        end
        if el.opts.align_shortcut == "right" then
            hl = alpha.highlight(state, state.line, hl, #el.val + math.max(0,padding.center), el)
        else
            hl = alpha.highlight(state, state.line, hl, padding.left, el)
        end
    end

    if el.opts and el.opts.hl then
        local left = padding.left
        if el.opts.align_shortcut == "left" then
            left = left + #el.opts.shortcut
        end
        list_extend(hl, alpha.highlight(state, state.line, el.opts.hl, left, el))
    end
    state.line = state.line + 1
    return val, hl
end

function layout_element.group(el, conf, state)
    if type(el.val) == "function" then
        return alpha.resolve(layout_element.group, el, conf, state)
    end

    if type(el.val) == "table" then
        local text_tbl = {}
        local hl_tbl = {}
        local priority = if_nil(vim.tbl_get(el, 'opts', 'priority'), 1)
        local inherit = vim.tbl_get(el, 'opts', 'inherit')
        for _, v in pairs(el.val) do
            if inherit then
                if v.opts then
                    local vpriority = if_nil(vim.tbl_get(v, 'opts', 'priority'), 0)
                    if priority > vpriority then
                        v.opts = vim.tbl_extend("force", v.opts, inherit)
                    end
                else
                    v.opts = inherit
                end
            end
            local text, hl = layout_element[v.type](v, conf, state)
            if text then
                list_extend(text_tbl, text)
            end
            if hl then
                list_extend(hl_tbl, hl)
            end
            if el.opts and el.opts.spacing then
                local padding_el = { type = "padding", val = el.opts.spacing }
                local text_1, hl_1 = layout_element[padding_el.type](padding_el, conf, state)
                list_extend(text_tbl, text_1)
                list_extend(hl_tbl, hl_1)
            end
        end
        return text_tbl, hl_tbl
    end
end

local function layout(conf, state)
    -- this is my way of hacking pattern matching
    -- you index the table by its "type"
    local hl = {}
    local text = {}
    for _, el in pairs(conf.layout) do
        local text_el, hl_el = layout_element[el.type](el, conf, state)
        list_extend(text, text_el)
        list_extend(hl, hl_el)
    end
    vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, text)
    for _, hl_line in pairs(hl) do
        vim.api.nvim_buf_add_highlight(hl_line[1], hl_line[2], hl_line[3], hl_line[4], math.max(hl_line[5], 0), hl_line[6])
    end
end

local keymaps_element = {}

keymaps_element.text = noop
keymaps_element.padding = noop

---@diagnostic disable-next-line: unused-local
function keymaps_element.button(el, conf, state)
    if el.opts and el.opts.keymap then
        el.opts.keymap[4] = vim.tbl_extend("force", el.opts.keymap[4] or {}, { buffer = state.buffer })
        vim.keymap.set(unpack(el.opts.keymap))
    end
end

function keymaps_element.group(el, conf, state)
    if type(el.val) == "function" then
        alpha.resolve(keymaps_element.group, el, conf, state)
    end

    if type(el.val) == "table" then
        for _, v in pairs(el.val) do
            keymaps_element[v.type](v, conf, state)
        end
    end
end

local function keymaps(conf, state)
    for _, el in pairs(conf.layout) do
        keymaps_element[el.type](el, conf, state)
    end
end

-- dragons
local function closest_cursor_jump(cursor, cursors, prev_cursor)
    local direction = prev_cursor[1] > cursor[1] -- true = UP, false = DOWN
    -- minimum distance key from jump point
    -- excluding jumps in opposite direction
    local min
    local cursor_row = cursor[1]
    for k, v in pairs(cursors) do
        local distance = v[1] - cursor_row -- new cursor distance from old cursor
        if (distance <= 0) and direction then
            distance = abs(distance)
            local res = { distance, k }
            if not min then
                min = res
            end
            if min[1] > res[1] then
                min = res
            end
        end
        if (distance >= 0) and not direction then
            local res = { distance, k }
            if not min then
                min = res
            end
            if min[1] > res[1] then
                min = res
            end
        end
    end
    if not min -- top or bottom
    then
        if direction then
            return 1, cursors[1]
        else
            return #cursors, cursors[#cursors]
        end
    else
        -- returns the key (stored in a jank way so we can sort the table)
        -- and the {row, col} tuple
        return min[2], cursors[min[2]]
    end
end

-- stylua: ignore start
local function enable_alpha(conf, state)
    local eventignore = vim.opt.eventignore
    if conf.opts.noautocmd then
        vim.opt.eventignore = 'all'
    end

    vim.opt_local.bufhidden = 'wipe'
    vim.opt_local.buflisted = false
    vim.opt_local.matchpairs = ''
    vim.opt_local.swapfile = false
    vim.opt_local.buftype = 'nofile'
    vim.opt_local.filetype = 'alpha'
    vim.opt_local.synmaxcol = 0
    vim.opt_local.wrap = false
    vim.opt_local.colorcolumn = ''
    vim.opt_local.foldlevel = 999
    vim.opt_local.foldcolumn = '0'
    vim.opt_local.cursorcolumn = false
    vim.opt_local.cursorline = false
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.list = false
    vim.opt_local.spell = false
    vim.opt_local.signcolumn = 'no'

    if conf.opts.noautocmd then
        vim.opt.eventignore = eventignore
    end

    local group_id = vim.api.nvim_create_augroup('alpha_temp', { clear = true })

    vim.api.nvim_create_autocmd('BufUnload', {
        group = group_id,
        buffer = state.buffer,
        callback = alpha.close,
    })

    vim.api.nvim_create_autocmd('SessionLoadPost', {
        group = group_id,
        callback = alpha.close,
    })

    vim.api.nvim_create_autocmd({'WinClosed'}, {
        group = group_id,
        buffer = state.buffer,
        callback = alpha.handle_window,
    })

    vim.api.nvim_create_autocmd('CursorMoved', {
        group = group_id,
        buffer = state.buffer,
        callback = function()
            alpha.move_cursor(active_window(state))
        end,
    })

    if conf.opts then
        if if_nil(conf.opts.redraw_on_resize, true) then
            if vim.version().api_level >= 11 then
                vim.api.nvim_create_autocmd('WinResized', {
                    group = group_id,
                    callback = function() alpha.redraw(conf, state) end,
                })
            else
                vim.api.nvim_create_autocmd('VimResized', {
                    group = group_id,
                    pattern = '*',
                    callback = function() alpha.redraw(conf, state) end,
                })
                vim.api.nvim_create_autocmd({ 'BufLeave', 'WinEnter', 'WinNew', 'WinClosed' }, {
                    group = group_id,
                    pattern = '*',
                    callback = function() alpha.redraw(conf, state) end,
                })
                vim.api.nvim_create_autocmd('CursorMoved', {
                    group = group_id,
                    pattern = '*',
                    callback = function()
                        local width = vim.api.nvim_win_get_width(active_window(state))
                        if width ~= state.win_width
                        then alpha.redraw(conf, state)
                        end
                    end,
                })
            end
        end

        if conf.opts.setup then
            conf.opts.setup()
        end
    end

end

-- stylua: ignore end

-- stylua: ignore start
local function should_skip_alpha()
    -- don't start when opening a file
    if vim.fn.argc() > 0 then return true end

    -- Do not open alpha if the current buffer has any lines (something opened explicitly).
    local lines = vim.api.nvim_buf_get_lines(0, 0, 2, false)
    if #lines > 1 or (#lines == 1 and lines[1]:len() > 0) then return true end

    -- Skip when there are several listed buffers.
    for _, buf_id in pairs(vim.api.nvim_list_bufs()) do
        local bufinfo = vim.fn.getbufinfo(buf_id)
        if bufinfo.listed == 1 and #bufinfo.windows > 0
            then return true
        end
    end

    -- Handle nvim -M
    if not vim.o.modifiable then return true end

    ---@diagnostic disable-next-line: undefined-field
    for _, arg in pairs(vim.v.argv) do
        -- whitelisted arguments
        -- always open
        if arg == "--startuptime"
        then return false
        end

        -- blacklisted arguments
        -- always skip
        if arg == "-b"
            -- commands, typically used for scripting
            or arg == "-c" or vim.startswith(arg, "+")
            or arg == "-S"
        then return true
        end
    end

    -- base case: don't skip
    return false
end

-- stylua: ignore end

function alpha.draw(conf, state)
    -- TODO: figure out why this can happen
    if #state.windows == 0 then return end

    cursor_jumps = {}
    cursor_jumps_press = {}
    state.win_width = vim.api.nvim_win_get_width(active_window(state) or 0)
    state.line = 0
    -- this is for redraws. i guess the cursor 'moves'
    -- when the screen is cleared and then redrawn
    -- so we save the index before that happens
    local ix = cursor_ix
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)
    vim.api.nvim_buf_clear_namespace(state.buffer, -1, 0, -1)
    vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, {})
    layout(conf, state)
    vim.api.nvim_buf_set_option(state.buffer, "modifiable", false)
    local active_win = active_window(state)
    if vim.api.nvim_get_current_win() == active_win then
        if #cursor_jumps ~= 0 then
            -- TODO: this is pcalled because a bunch of window events
            -- like WinEnter will say 'alpha' is the current open buffer
            -- and then immedietely unload it
            pcall(vim.api.nvim_win_set_cursor, active_win, cursor_jumps[ix])
        end
    end
    draw_presses(state)
end

function alpha.move_cursor(window)
    if #cursor_jumps ~= 0 then
        local cursor = vim.api.nvim_win_get_cursor(window)
        local closest_ix, closest_pt = closest_cursor_jump(cursor, cursor_jumps, cursor_jumps[cursor_ix])
        local closest_pt_vc = vim.fn.virtcol2col(window, closest_pt[1], closest_pt[2])
        cursor_ix = closest_ix
        pcall(vim.api.nvim_win_set_cursor, window, {closest_pt[1], closest_pt_vc})
    end
end

function alpha.redraw(conf, state)
    if (conf == nil) and (state == nil) then
        local buffer = vim.api.nvim_get_current_buf()
        local alpha_prime = vim.tbl_get(alpha_state, buffer) or head(alpha_state)
        if alpha_prime == nil then return end
        conf = alpha.default_config
        state = alpha_prime
    end
    alpha.draw(conf, state)
end

function alpha.close(ev)
    alpha_state[ev.buf] = nil
    cursor_ix = 1
    cursor_jumps = {}
    vim.api.nvim_del_augroup_by_id(ev.group)
    vim.api.nvim_exec_autocmds("User", { pattern = "AlphaClosed" })
end

-- @param on_vimenter: ?bool optional
-- @param fon: ?table optional
function alpha.start(on_vimenter, conf)
    local window = vim.api.nvim_get_current_win()

    local buffer
    if on_vimenter then
        if should_skip_alpha() then
            return
        end
        buffer = vim.api.nvim_get_current_buf()
    else
        if vim.bo.ft ~= "alpha" then
            buffer = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_win_set_buf(window, buffer)
        else
            ---@diagnostic disable-next-line: param-type-mismatch
            if not pcall(vim.cmd, 'e #') then
                buffer = vim.api.nvim_get_current_buf()
                vim.api.nvim_buf_delete(buffer, {})
            end
            return
        end
    end

    if not vim.o.hidden and vim.opt_local.modified:get() then
        vim.api.nvim_err_writeln("Save your changes first.")
        return
    end

    conf = conf or alpha.default_config

    local state = {
        line = 0,
        buffer = buffer,
        windows = { window },
        win_width = 0,
        open = false,
    }

    alpha_state[buffer] = state

    for _, k in ipairs(normalize_keymaps(conf.opts.keymap.press)) do
        vim.keymap.set("n", k, function() alpha.press() end, { noremap = false, silent = true, buffer = state.buffer })
    end
    for _, k in ipairs(normalize_keymaps(conf.opts.keymap.queue_press)) do
        vim.keymap.set("n", k, function() alpha.queue_press(state) end, { noremap = false, silent = true, buffer = state.buffer })
    end

    enable_alpha(conf, state)

    alpha.draw(conf, state)

    vim.api.nvim_exec_autocmds("User", { pattern = "AlphaReady" })
    keymaps(conf, state)
end

function alpha.setup(config)
    if vim.fn.has('nvim-0.11') == 1 then
        vim.validate("config", config, "table")
        vim.validate("config.layout", config.layout, "table")
    else
        vim.validate({
            config = { config, "table" },
            layout = { config.layout, "table" },
        })
    end

    config.opts = vim.tbl_extend(
        "keep",
        if_nil(config.opts, {}),
        {
            autostart = true,
            keymap = vim.tbl_extend("keep", if_nil(vim.tbl_get(config, "opts", "keymap"), {}), {
                press = "<CR>",
                queue_press = "<M-CR>",
            })
        }
    )

    alpha.default_config = config

    vim.api.nvim_create_user_command("Alpha", function(_)
        alpha.start(false, config)
    end, {
        bang = true,
        desc = 'require"alpha".start(false)',
        nargs = 0,
        bar = true,
    })

    vim.api.nvim_create_user_command("AlphaRedraw", function(_)
        alpha.redraw()
    end, {
        bang = true,
        desc = 'require"alpha".redraw()',
        nargs = 0,
        bar = true,
    })
    vim.api.nvim_create_user_command("AlphaRemap", function(_)
        local buffer = vim.api.nvim_get_current_buf()
        local alpha_prime = vim.tbl_get(alpha_state, buffer) or head(alpha_state)
        if alpha_prime == nil then return end
        local conf = alpha.default_config
        local state = alpha_prime
        keymaps(conf, state)
    end, {
        bang = true,
        desc = 'manually set keymaps',
        nargs = 0,
        bar = true,
    })
    local group_id = vim.api.nvim_create_augroup("alpha_start", { clear = true })
    vim.api.nvim_create_autocmd("VimEnter", {
        group = group_id,
        pattern = "*",
        nested = true,
        callback = function()
            if config.opts.autostart then
                alpha.start(true, config)
            end
        end,
    })
end

alpha.layout_element = layout_element
alpha.keymaps_element = keymaps_element

function alpha.handle_window(x)
    local alpha_instance = alpha_state[x.buf]
    local current_win = vim.api.nvim_get_current_win()
    if alpha_instance then
        local wins = vim.tbl_filter(function(win)
            return (vim.api.nvim_win_get_buf(win) == x.buf) and (win ~= current_win)
        end
            , vim.api.nvim_list_wins()
        )
        alpha_instance.windows = wins
    end
end

return alpha
