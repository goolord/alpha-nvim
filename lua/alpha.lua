local alpha = {}

-- business logic
local concat = table.concat
local if_nil = vim.F.if_nil
local list_extend = vim.list_extend
local max = math.max
local min = math.min
local str_rep = string.rep
-- not nvim_strwidth: this has to take the numbers themes put in text values,
-- and it accounts for 'tabstop' when a line contains tabs
local strdisplaywidth = vim.fn.strdisplaywidth

-- map of buffer -> state
local alpha_state = {}
local hl_ns = vim.api.nvim_create_namespace("alpha")

local function head(t)
    return t[next(t)]
end

local function noop() end

--- The state of the alpha instance in `buffer`, or of any live instance.
--- @param buffer number? defaults to the current buffer
local function resolve_state(buffer)
    return alpha_state[buffer or vim.api.nvim_get_current_buf()] or head(alpha_state)
end

--- A window the alpha buffer is displayed in, or nil if it is not displayed.
local function active_window(state)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) == state.buffer then
        return win
    end
    for _, candidate in ipairs(state.windows) do
        -- state.windows is tracked on WinClosed, so entries can be stale: a
        -- closed tab page never fires it, and a window can hold another buffer
        if vim.api.nvim_win_is_valid(candidate) and (vim.api.nvim_win_get_buf(candidate) == state.buffer) then
            return candidate
        end
    end
    return nil
end

--- @param state table? defaults to the state of the current buffer
function alpha.press(state)
    state = state or resolve_state()
    if state == nil then
        return
    end

    -- only press under the cursor if there's no queue
    if next(state.queue) == nil then
        local press = state.presses[state.cursor_ix]
        if press then
            press()
        end
        return
    end

    -- a press can redraw, which rewrites the queue, so take the buttons and the
    -- callbacks first and empty the queue before firing any of them
    local presses = {}
    for ix, _ in pairs(state.queue) do
        presses[#presses + 1] = state.presses[ix]
        state.queue[ix] = nil
    end
    for _, press in ipairs(presses) do
        press()
    end
end

local function draw_press(row, col, state)
    if row > vim.api.nvim_buf_line_count(state.buffer) then
        return
    end
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.buffer })
    -- todo: represent this in the alpha layout, somehow
    pcall(vim.api.nvim_buf_set_text, state.buffer, row - 1, col, row - 1, col + 1, { "*" })
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.buffer })
end

--- Queued presses are keyed by button index, so the marker is placed from the
--- jump points of the current draw. Entries whose button is gone are dropped.
local function draw_presses(state)
    for ix, _ in pairs(state.queue) do
        local jump = state.jumps[ix]
        if jump then
            draw_press(jump[1], jump[2], state)
        else
            state.queue[ix] = nil
        end
    end
end

--- @param state table? defaults to the state of the current buffer
function alpha.queue_press(state)
    state = state or resolve_state()
    if state == nil then
        return
    end

    local ix = state.cursor_ix
    if state.queue[ix] then
        state.queue[ix] = nil
        -- redraw to erase the marker
        alpha.redraw(nil, state)
        return
    end

    local jump = state.jumps[ix]
    if jump == nil then
        return
    end
    state.queue[ix] = true
    draw_press(jump[1], jump[2], state)

    -- move off the button that was just queued, so a run of presses can be
    -- queued by repeating the key
    local window = active_window(state)
    if window then
        local height = vim.api.nvim_buf_line_count(state.buffer)
        pcall(vim.api.nvim_win_set_cursor, window, { min(jump[1] + 1, height), jump[2] })
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
    return str_rep(" ", max(0, n))
end

local default_opts = {
    autostart = true,
    keymap = {
        press = "<CR>",
        queue_press = "<M-CR>",
    },
}

--- Fill in the opts alpha itself needs. Idempotent, and applied by both
--- alpha.setup and alpha.start, so a raw theme config can be passed to either.
--- @param config table
--- @return table
local function normalize_config(config)
    -- a fresh opts table, so a theme's own opts (and its keymap table, which a
    -- theme may share between configs) are left alone
    local opts = vim.tbl_extend("keep", config.opts or {}, default_opts)
    opts.keymap = vim.tbl_extend("keep", opts.keymap or {}, default_opts.keymap)
    config.opts = opts
    return config
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

--- Indent every line by `left` columns. Returns the new lines and `left`, which
--- can be negative when the text is wider than the window.
local function pad_left(tbl, left)
    local padding = spaces(left)
    local padded = {}
    for k, v in pairs(tbl) do
        padded[k] = padding .. v
    end
    return padded, left
end

function alpha.align_center(tbl, state)
    -- the longest line decides the center, which doesn't quite give a
    -- 'justified' look, but w.e
    local left = bit.arshift(state.win_width - longest_line(tbl), 1)
    return pad_left(tbl, left)
end

function alpha.pad_margin(tbl, state, margin, shrink)
    local left = margin
    if shrink then
        local pot_width = margin + margin + longest_line(tbl)
        if pot_width > state.win_width then
            left = (state.win_width - pot_width) + margin
        end
    end
    return pad_left(tbl, left)
end

function alpha.highlight(state, end_ln, hl, left, el)
    local hl_tbl = {}
    if type(hl) == "string" then
        for row = state.line, end_ln do
            hl_tbl[#hl_tbl + 1] = { state.buffer, -1, hl, row, 0, -1 }
        end
        return hl_tbl
    end
    if type(hl) ~= "table" then
        return hl_tbl
    end

    local function single_line(line_hl, line)
        for _, section in pairs(line_hl) do
            -- no end column means to the end of the text
            local col_end = section[3] or -1
            if col_end >= 0 then
                col_end = left + col_end
            elseif type(el.val) == "string" then
                -- negative columns count back from the end of the text
                col_end = left + #el.val + col_end + 1
            else
                col_end = -1
            end
            hl_tbl[#hl_tbl + 1] = { state.buffer, -1, section[1], state.line + line, left + section[2], col_end }
        end
    end

    -- either one line of sections, or one list of sections per line
    if hl[1] and type(hl[1][1]) == "table" then
        for ix, line_hl in pairs(hl) do
            single_line(line_hl, ix - 1)
        end
    else
        single_line(hl, 0)
    end
    return hl_tbl
end

--- Identifies a binding (mode + lhs), so a changed rhs replaces it in place.
local function keymap_bind_id(mode, lhs)
    if type(mode) == "table" then
        mode = concat(mode, "\1")
    end
    return mode .. "\0" .. lhs
end

--- Record a keymap the drawn layout asks for. Collected during the layout
--- traversal and diffed against what is applied, so button keymaps always
--- match the buttons on screen.
local function want_keymap(state, keymap)
    if keymap == nil then
        return
    end
    local id = keymap_bind_id(keymap[1], keymap[2])
    if state.want_keymaps[id] == nil then
        state.want_keymaps[id] = keymap
    end
end

local function del_keymap(state, mode, lhs)
    if not vim.api.nvim_buf_is_valid(state.buffer) then
        return
    end
    -- the mapping is gone if the user deleted it themselves, which is fine: this
    -- runs on every draw, so a warning here would be a warning on every draw
    pcall(vim.keymap.del, mode, lhs, { buffer = state.buffer })
end

local function apply_keymaps(state)
    local applied = state.keymaps
    local want = state.want_keymaps
    for id, keymap in pairs(want) do
        local mode, lhs, rhs = keymap[1], keymap[2], keymap[3]
        local rhs_id = type(rhs) == "string" and rhs or tostring(rhs)
        local prev = applied[id]
        if (prev == nil) or (prev[3] ~= rhs_id) then
            vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", keymap[4] or {}, { buffer = state.buffer }))
            applied[id] = { mode, lhs, rhs_id }
        end
    end
    for id, km in pairs(applied) do
        if want[id] == nil then
            del_keymap(state, km[1], km[2])
            applied[id] = nil
        end
    end
end

local layout_element = {}

function alpha.resolve(to, el, opts, state)
    local val = el.val()
    local new_el = setmetatable({ val = val }, { __index = el })
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
    local el_opts = el.opts or {}
    local margin = conf.opts and conf.opts.margin
    local position = el_opts.position
    local padding_left = 0
    if margin and (position ~= "center") then
        val, padding_left = alpha.pad_margin(val, state, margin, if_nil(el_opts.shrink_margin, true))
    end
    if position == "center" then
        val, padding_left = alpha.align_center(val, state)
    end
    -- one rendered line per entry in `val`, which is not the same as one line
    -- per element: a string val can carry newlines
    local end_ln = state.line + #val
    if el_opts.hl then
        hl = alpha.highlight(state, end_ln - 1, el_opts.hl, padding_left, el)
    end
    state.line = end_ln
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
    local opts = el.opts or {}
    local shortcut = opts.shortcut
    -- with the shortcut on the right, the gap between text and shortcut carries
    -- the padding; otherwise it trails the text
    local align_right = opts.align_shortcut == "right"
    local hl = {}
    local val
    local padding_left = 0
    local padding_center = 0

    if shortcut then
        local gap = 0
        if opts.width then
            -- this min lets the padding resize when the window gets smaller
            local max_width = min(opts.width, state.win_width)
            gap = max_width - (strdisplaywidth(el.val) + strdisplaywidth(shortcut))
        end
        if align_right then
            padding_center = gap
            val = { concat({ el.val, spaces(gap), shortcut }) }
        else
            val = { concat({ shortcut, el.val, spaces(gap) }) }
        end
    else
        val = { el.val }
    end

    local margin = conf.opts and conf.opts.margin
    if margin and (opts.position ~= "center") then
        local left
        val, left = alpha.pad_margin(val, state, margin, if_nil(opts.shrink_margin, true))
        if align_right then
            padding_center = padding_center + left
        else
            padding_left = padding_left + left
        end
    end

    if opts.position == "center" then
        local left
        val, left = alpha.align_center(val, state)
        if align_right then
            padding_center = padding_center + left
        end
        padding_left = padding_left + left
    end

    local ix = #state.jumps + 1
    state.jumps[ix] = { state.line + 1, (opts.cursor or 0) + padding_left }
    state.presses[ix] = el.on_press
    want_keymap(state, opts.keymap)

    if opts.hl_shortcut then
        local shortcut_hl = opts.hl_shortcut
        if type(shortcut_hl) == "string" then
            shortcut_hl = { { shortcut_hl, 0, #shortcut + 1 } }
        end
        local left = align_right and (#el.val + max(0, padding_center)) or padding_left
        hl = alpha.highlight(state, state.line, shortcut_hl, left, el)
    end

    if opts.hl then
        local left = padding_left
        if opts.align_shortcut == "left" then
            left = left + #shortcut
        end
        list_extend(hl, alpha.highlight(state, state.line, opts.hl, left, el))
    end

    state.line = state.line + 1
    return val, hl
end

--- Apply a group's `inherit` opts to a child without touching the child table,
--- which belongs to the theme and is reused on every draw.
local function with_inherited_opts(v, inherit, priority)
    local vpriority = (v.opts and v.opts.priority) or 0
    if v.opts and (priority <= vpriority) then
        return v
    end
    return setmetatable({ opts = vim.tbl_extend("force", v.opts or {}, inherit) }, { __index = v })
end

function layout_element.group(el, conf, state)
    if type(el.val) == "function" then
        return alpha.resolve(layout_element.group, el, conf, state)
    end

    if type(el.val) ~= "table" then
        return
    end

    local text_tbl = {}
    local hl_tbl = {}
    local el_opts = el.opts or {}
    local priority = if_nil(el_opts.priority, 1)
    local inherit = el_opts.inherit
    -- one padding element, drawn again after every child
    local spacing_el = el_opts.spacing and { type = "padding", val = el_opts.spacing }

    local start_line = state.line
    local jumps_start = #state.jumps

    for _, child in pairs(el.val) do
        if inherit then
            child = with_inherited_opts(child, inherit, priority)
        end
        local text, hl = alpha.element(child, conf, state)
        if text then
            list_extend(text_tbl, text)
        end
        if hl then
            list_extend(hl_tbl, hl)
        end
        if spacing_el then
            local spacing_text = layout_element.padding(spacing_el, conf, state)
            list_extend(text_tbl, spacing_text)
        end
    end

    if el_opts.position == "v_center" then
        local shift = max(0, math.floor((state.win_height - #text_tbl) / 2) - start_line)
        if shift > 0 then
            local shifted = {}
            for i = 1, shift do
                shifted[i] = ""
            end
            list_extend(shifted, text_tbl)
            text_tbl = shifted
            for _, hl_entry in pairs(hl_tbl) do
                hl_entry[4] = hl_entry[4] + shift
            end
            for i = jumps_start + 1, #state.jumps do
                state.jumps[i][1] = state.jumps[i][1] + shift
            end
            state.line = state.line + shift
        end
    end

    return text_tbl, hl_tbl
end

local builtin_element = { text = true, padding = true, button = true, group = true }

--- Render one element. This is my way of hacking pattern matching:
--- you index the table by its "type".
--- Custom element types that predate the single traversal may also have a
--- `keymaps_element` entry, which is called here for backwards compatibility.
function alpha.element(el, conf, state)
    local draw = layout_element[el.type]
    if draw == nil then
        vim.notify("alpha: no layout_element for type " .. vim.inspect(el.type), vim.log.levels.ERROR)
        return {}, {}
    end
    local text, hl = draw(el, conf, state)
    if not builtin_element[el.type] then
        local legacy = alpha.keymaps_element[el.type]
        if legacy then
            legacy(el, conf, state)
        end
    end
    return text, hl
end

--- Mark up one `alpha.highlight` entry: {buffer, ns, group, row, col, end_col}.
--- Columns are clamped to `line`, and a negative end column reaches to the end
--- of it, which is what nvim_buf_add_highlight used to do.
local function apply_highlight(buffer, line, hl_line)
    local row, eol = hl_line[4], #line
    local col = min(max(hl_line[5], 0), eol)
    local end_row, end_col = row, hl_line[6]
    if (end_col == nil) or (end_col < 0) then
        end_row, end_col = row + 1, 0
    else
        end_col = min(end_col, eol)
    end
    if (end_row == row) and (end_col <= col) then
        return
    end
    vim.api.nvim_buf_set_extmark(buffer, hl_ns, row, col, {
        end_row = end_row,
        end_col = end_col,
        hl_group = hl_line[3],
    })
end

local function layout(conf, state)
    local hl = {}
    local text = {}
    for _, el in pairs(conf.layout) do
        local text_el, hl_el = alpha.element(el, conf, state)
        list_extend(text, text_el)
        list_extend(hl, hl_el)
    end
    vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, text)
    for _, hl_line in pairs(hl) do
        local line = text[hl_line[4] + 1]
        if line then
            apply_highlight(state.buffer, line, hl_line)
        end
    end
end

-- Deprecated. Button keymaps are collected by the layout traversal now; this
-- table is only kept so custom element types written against the old two-pass
-- api keep working, including custom container elements that walk their own
-- children through it. See alpha.element.
local keymaps_element = {}

keymaps_element.text = noop
keymaps_element.padding = noop

---@diagnostic disable-next-line: unused-local
function keymaps_element.button(el, conf, state)
    if state.want_keymaps then
        want_keymap(state, el.opts and el.opts.keymap)
    end
end

function keymaps_element.group(el, conf, state)
    if type(el.val) == "function" then
        return alpha.resolve(keymaps_element.group, el, conf, state)
    end

    if type(el.val) == "table" then
        for _, v in pairs(el.val) do
            local fn = keymaps_element[v.type]
            if fn then
                fn(v, conf, state)
            end
        end
    end
end

--- The jump point nearest the cursor, searching the way the cursor just moved:
--- moving up only considers jumps at or above it, moving down at or below.
--- Returns the index and its {row, col} tuple.
local function closest_cursor_jump(cursor, cursors, prev_cursor)
    local up = prev_cursor[1] > cursor[1]
    local row = cursor[1]
    local best_ix, best_distance
    for ix, jump in pairs(cursors) do
        local distance = jump[1] - row
        if up then
            distance = -distance
        end
        if (distance >= 0) and ((best_distance == nil) or (distance < best_distance)) then
            best_ix, best_distance = ix, distance
        end
    end
    if best_ix == nil then
        -- the cursor moved past every jump point, so stop at the end it left by
        best_ix = up and 1 or #cursors
    end
    return best_ix, cursors[best_ix]
end

-- stylua: ignore start
local function enable_alpha(conf, state)
    local eventignore = vim.opt.eventignore
    if conf.opts.noautocmd then
        vim.opt.eventignore = 'all'
    end

    -- set on the alpha buffer and window explicitly: alpha is not always started
    -- from the window it draws into
    local buf_opts = {
        bufhidden = "wipe", buflisted = false, matchpairs = "", swapfile = false,
        buftype = "nofile", filetype = "alpha", synmaxcol = 0,
    }
    local win_opts = {
        wrap = false, colorcolumn = "", foldlevel = 999, foldcolumn = "0",
        cursorcolumn = false, cursorline = false, number = false,
        relativenumber = false, list = false, spell = false, signcolumn = "no",
    }
    for opt, val in pairs(buf_opts) do
        vim.api.nvim_set_option_value(opt, val, { buf = state.buffer })
    end
    for opt, val in pairs(win_opts) do
        vim.api.nvim_set_option_value(opt, val, { win = state.windows[1], scope = "local" })
    end

    if conf.opts.noautocmd then
        vim.opt.eventignore = eventignore
    end

    local group_id = vim.api.nvim_create_augroup('alpha_temp_' .. state.buffer, { clear = true })
    state.augroup = group_id
    -- legacy group name: themes register their own autocmds under it
    vim.api.nvim_create_augroup('alpha_temp', { clear = true })

    vim.api.nvim_create_autocmd('BufUnload', {
        group = group_id,
        buffer = state.buffer,
        callback = function() alpha.close({ buf = state.buffer }) end,
    })

    -- ev.buf is whatever buffer is current when the session loads, so the alpha
    -- buffer has to be named explicitly
    vim.api.nvim_create_autocmd('SessionLoadPost', {
        group = group_id,
        callback = function() alpha.close({ buf = state.buffer }) end,
    })

    vim.api.nvim_create_autocmd('WinClosed', {
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

    if if_nil(conf.opts.redraw_on_resize, true) then
        local function redraw() alpha.redraw(conf, state) end
        if vim.version().api_level >= 11 then
            vim.api.nvim_create_autocmd('WinResized', { group = group_id, callback = redraw })
        else
            -- WinResized doesn't exist yet, so watch everything that could have
            -- resized the window
            vim.api.nvim_create_autocmd({ 'VimResized', 'BufLeave', 'WinEnter', 'WinNew', 'WinClosed' }, {
                group = group_id,
                pattern = '*',
                callback = redraw,
            })
            vim.api.nvim_create_autocmd('CursorMoved', {
                group = group_id,
                pattern = '*',
                callback = function()
                    local window = active_window(state)
                    if window and (vim.api.nvim_win_get_width(window) ~= state.win_width) then
                        redraw()
                    end
                end,
            })
        end
    end

    if conf.opts.setup then
        conf.opts.setup(state)
    end
end

local function should_skip_alpha()
    -- don't start when opening a file
    if vim.fn.argc() > 0 then return true end

    -- Do not open alpha if the current buffer has any lines (something opened explicitly).
    local lines = vim.api.nvim_buf_get_lines(0, 0, 2, false)
    if #lines > 1 or (#lines == 1 and lines[1]:len() > 0) then return true end

    -- Skip when there are other listed buffers in windows.
    local curr_buf = vim.api.nvim_get_current_buf()
    for _, win in pairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if buf ~= curr_buf and vim.bo[buf].buflisted then return true end
    end

    -- Handle nvim -M
    if not vim.o.modifiable then return true end

    ---@diagnostic disable-next-line: undefined-field
    for _, arg in pairs(vim.v.argv) do
        -- always open, whatever else is on the command line
        if arg == "--startuptime" then return false end

        -- -b, and the arguments that run commands: typically scripting
        if arg == "-b" or arg == "-c" or arg == "-S" or vim.startswith(arg, "+") then return true end
    end

    -- base case: don't skip
    return false
end

-- stylua: ignore end

function alpha.draw(conf, state)
    -- there is nothing to lay out for a buffer that is not on screen, and no
    -- window to measure it against
    local active_win = active_window(state)
    if active_win == nil then return end

    state.conf = conf
    state.jumps = {}
    state.presses = {}
    state.want_keymaps = {}
    state.win_width = vim.api.nvim_win_get_width(active_win)
    state.win_height = vim.api.nvim_win_get_height(active_win)
    state.line = 0
    -- this is for redraws. i guess the cursor 'moves'
    -- when the screen is cleared and then redrawn
    -- so we save the index before that happens
    local ix = state.cursor_ix
    vim.api.nvim_set_option_value("modifiable", true, { buf = state.buffer })
    vim.api.nvim_buf_clear_namespace(state.buffer, hl_ns, 0, -1)
    layout(conf, state)
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.buffer })
    -- the layout may have fewer buttons than it did on the last draw
    if state.jumps[ix] == nil then
        ix = 1
        state.cursor_ix = 1
    end
    if vim.api.nvim_get_current_win() == active_win then
        local jump = state.jumps[ix]
        if jump then
            -- TODO: this is pcalled because a bunch of window events
            -- like WinEnter will say 'alpha' is the current open buffer
            -- and then immedietely unload it
            pcall(vim.api.nvim_win_set_cursor, active_win, jump)
        end
    end
    draw_presses(state)
    apply_keymaps(state)
end

function alpha.move_cursor(window)
    if (window == nil) or not vim.api.nvim_win_is_valid(window) then
        return
    end
    local state = resolve_state(vim.api.nvim_win_get_buf(window))
    if state == nil then
        return
    end
    local jumps = state.jumps
    if #jumps ~= 0 then
        local cursor = vim.api.nvim_win_get_cursor(window)
        local closest_ix, closest_pt = closest_cursor_jump(cursor, jumps, jumps[state.cursor_ix] or jumps[1])
        local closest_pt_vc = vim.fn.virtcol2col(window, closest_pt[1], closest_pt[2])
        state.cursor_ix = closest_ix
        pcall(vim.api.nvim_win_set_cursor, window, {closest_pt[1], closest_pt_vc})
    end
end

--- @param conf table? defaults to the config that was drawn last
--- @param state table? defaults to the state of the current buffer
function alpha.redraw(conf, state)
    state = state or resolve_state()
    if state == nil then return end
    conf = conf or state.conf or alpha.default_config
    if conf == nil then return end
    alpha.draw(conf, state)
end

function alpha.close(ev)
    ev = ev or {}
    local state = resolve_state(ev.buf)
    if state then
        alpha_state[state.buffer] = nil
    end
    local group = (state and state.augroup) or ev.group
    if group then
        pcall(vim.api.nvim_del_augroup_by_id, group)
    end
    -- autocmds themes registered under the legacy group name, which is shared by
    -- every instance, so it can only go when the last one does
    if next(alpha_state) == nil then
        pcall(vim.api.nvim_del_augroup_by_name, "alpha_temp")
    end
    vim.api.nvim_exec_autocmds("User", { pattern = "AlphaClosed" })
end

-- @param on_vimenter: ?bool optional
-- @param fon: ?table optional
function alpha.start(on_vimenter, conf)
    if on_vimenter and should_skip_alpha() then
        return
    end

    conf = conf or alpha.default_config
    if conf == nil then
        vim.notify("alpha: no config, call require'alpha'.setup(config) first", vim.log.levels.ERROR)
        return
    end
    normalize_config(conf)

    -- both checks happen before anything is swapped into the window, so giving
    -- up leaves the user's buffer where it was
    if not vim.o.hidden and vim.bo.modified then
        vim.notify("alpha: save your changes first", vim.log.levels.ERROR)
        return
    end

    local window = vim.api.nvim_get_current_win()

    local buffer
    if on_vimenter then
        buffer = vim.api.nvim_get_current_buf()
    elseif vim.bo.ft ~= "alpha" then
        buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(window, buffer)
    else
        -- alpha is already up: go back to the previous buffer, or drop this one
        ---@diagnostic disable-next-line: param-type-mismatch
        if not pcall(vim.cmd, 'e #') then
            vim.api.nvim_buf_delete(vim.api.nvim_get_current_buf(), {})
        end
        return
    end

    local state = {
        line = 0,
        buffer = buffer,
        windows = { window },
        win_width = 0,
        conf = conf,
        cursor_ix = 1,
        -- {row, col} per button, in draw order
        jumps = {},
        -- on_press per button, same indices as jumps
        presses = {},
        -- set of button indices with a queued press
        queue = {},
        -- bind id -> {mode, lhs, rhs id} of the keymaps alpha has set
        keymaps = {},
        want_keymaps = {},
    }

    alpha_state[buffer] = state

    local function bind(keys, fn)
        for _, lhs in pairs(normalize_keymaps(keys)) do
            vim.keymap.set("n", lhs, fn, { noremap = false, silent = true, buffer = buffer })
        end
    end
    bind(conf.opts.keymap.press, function() alpha.press(state) end)
    bind(conf.opts.keymap.queue_press, function() alpha.queue_press(state) end)

    enable_alpha(conf, state)

    alpha.draw(conf, state)

    vim.api.nvim_exec_autocmds("User", { pattern = "AlphaReady" })
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

    normalize_config(config)

    alpha.default_config = config

    local function command(name, desc, fn)
        vim.api.nvim_create_user_command(name, fn, { bang = true, desc = desc, nargs = 0, bar = true })
    end

    command("Alpha", 'require"alpha".start(false)', function()
        alpha.start(false, config)
    end)
    command("AlphaRedraw", 'require"alpha".redraw()', function()
        alpha.redraw()
    end)
    -- deprecated: keymaps are collected on every draw
    command("AlphaRemap", "deprecated, use :AlphaRedraw", function()
        alpha.redraw()
    end)
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

--- Keep state.windows in step with the windows the alpha buffer is in.
--- @param ev table WinClosed autocmd event
function alpha.handle_window(ev)
    local state = alpha_state[ev.buf]
    if state == nil then
        return
    end
    -- the window that fired WinClosed is still open while this runs
    local closing = tonumber(ev.match)
    local windows = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if (win ~= closing) and (vim.api.nvim_win_get_buf(win) == ev.buf) then
            windows[#windows + 1] = win
        end
    end
    state.windows = windows
end

return alpha
