local default_header = {
    type = "text";
    val = {
        [[                               __                ]],
        [[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
        [[ / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
        [[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
        [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
        [[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
    };
    opts = {
        position = "center";
        hl = "Type";
        -- wrap = "overflow";
    };
}

local function default_button(sc, txt)
    return {
        type = "button";
        val = txt;
        on_press = function ()
            vim.api.nvim_feedkeys(sc, 'n', false)
        end;
        opts = {
            position = "center";
            shortcut = sc;
            cursor = 5;
        };
    }
end

local default_opts = {
    layout = {
        { type = "padding"; val = 2 };
        default_header;
        { type = "padding"; val = 2 };
        default_button("e"      , "  New file"             );
        { type = "padding"; val = 1 };
        default_button("SPC s l", "  Open last session"    );
        { type = "padding"; val = 1 };
        default_button("SPC f h", "  Recently opened files");
        { type = "padding"; val = 1 };
        default_button("SPC f r", "  Frecency/MRU"         );
        { type = "padding"; val = 1 };
        default_button("SPC f r", "  Find file"            );
        { type = "padding"; val = 1 };
        default_button("SPC f w", "  Find word"            );
        { type = "padding"; val = 1 };
        default_button("SPC f m", "  Jump to bookmarks"    );
    };
    margin = 5;
}

local options = default_opts

local function longest_line(tbl)
    local longest = 0
    for _,v in pairs(tbl) do
        if #v > longest then longest = #v end
    end
    return longest
end

local function center(tbl, state)
    local longest = longest_line(tbl)
    local win_width = vim.api.nvim_win_get_width(state.window)
    local left = (win_width / 2) - (longest / 2)
    local padding = string.rep(" ", left)
    local centered = {}
    for k,v in pairs(tbl) do
        centered[k] = padding..v
    end
    return centered
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
    for k,v in pairs(tbl) do
        padded[k] = padding..v..padding
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
    local layout_element = {
        ["text"] = function (el)
            if type(el.val) == "table" then
                local end_ln = state.line + #el.val
                local val = el.val
                if opts.margin then val = pad_margin(val, state, opts.margin) end
                if el.opts then
                    if el.opts.position == "center" then val = center(val, state) end
                    -- if el.opts.wrap == "overflow" then
                    --     val = trim(val, state)
                    -- end
                end
                vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
                if el.opts and el.opts.hl then
                    for i = state.line, end_ln do
                        vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, i , 0 , -1)
                    end
                end
                state.line = end_ln
            end
            if type(el.val) == "string" then
                local val = { el.val }
                if opts.margin then val = pad_margin(val, state, opts.margin) end
                if el.opts then
                    if el.opts.position == "center" then val = center(val, state) end
                end
                vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
                if el.opts and el.opts.hl then
                    vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, state.line , 0 , -1)
                end
                state.line = state.line + 1
            end
        end,

        ["padding"] = function (el)
            local end_ln = state.line + el.val
            local val = { }
            for i = 1, el.val + 1 do
                val[i] = ""
            end
            vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
            state.line = end_ln
        end,

        ["button"] = function (el)
            local val
            if el.opts and el.opts.shortcut then
                val = { el.val .."    ".. el.opts.shortcut }
            else
                val = { el.val }
            end

            if opts.margin then val = pad_margin(val, state, opts.margin) end
            if el.opts then
                if el.opts.position == "center" then val = center(val, state) end
            end
            local row = state.line + 1
            local  _, count_spaces = string.find(val[1], "%s*")
            local col = ((el.opts and el.opts.cursor) or 0) + count_spaces
            table.insert(_G.alpha_cursor_jumps, { row, col })
            vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
            if el.opts and el.opts.hl then
                vim.api.nvim_buf_add_highlight(state.buffer, -1, el.opts.hl, state.line , 0 , -1)
            end
            state.line = state.line + 1
        end,
    }

    for _,el in pairs(opts.layout) do
        layout_element[el.type](el, state)
    end
end

function _G.alpha_redraw() end

_G.alpha_cursor_ix = 1
_G.alpha_cursor_jumps = {}

local function closest_cursor_jump(cursor, cursors, prev_cursor)
    local closest 
    if cursors
        then closest = { 1, cursors[1] }
        else closest = { 1, { 1, 1 } }
    end
    local distances = {}
    for k,v in pairs(cursors) do
        local distance = math.abs(v[1] - cursor[1])
        table.insert(distances, k, { distance, k })
    end
    table.sort(distances, function (l, r) return l[1] < r[1] end)
    if distances[1][1] == distances[2][1] then
        local index
        if prev_cursor[1] > cursor[1] 
            then index = math.min(distances[1][2],distances[2][2]) -- up
            else index = math.max(distances[1][2],distances[2][2]) -- down
        end
        closest = { index, cursors[index] }
    else
        closest = { distances[1][2], cursors[distances[1][2]] }
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
    vim.opt_local.bufhidden      = 'wipe'
    vim.opt_local.colorcolumn    = ""
    vim.opt_local.foldcolumn     = "0"
    vim.opt_local.matchpairs     = ""
    vim.opt_local.buflisted      = false
    vim.opt_local.cursorcolumn   = false
    vim.opt_local.cursorline     = false
    vim.opt_local.list           = false
    vim.opt_local.number         = false
    vim.opt_local.relativenumber = false
    vim.opt_local.spell          = false
    vim.opt_local.swapfile       = false
    vim.opt_local.signcolumn     = 'no'
    vim.opt_local.synmaxcol      = vim.api.nvim_get_option_info('synmaxcol').default
    vim.opt_local.wrap           = false

    vim.opt_local.ft = 'alpha'

    vim.cmd("autocmd alpha CursorMoved <buffer> call v:lua.alpha_set_cursor()")
end

local function start(opts)
    opts = opts or options

    local buffer = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(buffer)
    local window = vim.api.nvim_get_current_win()
    local state = {
        line = 0;
        buffer = buffer;
        window = window;
    }

    enable_alpha()
    local draw = function ()
        _G.alpha_cursor_jumps = {}
        vim.api.nvim_buf_set_option(state.buffer, 'modifiable', true)
        vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, {})
        state.line = 0
        layout(opts, state)
        vim.api.nvim_buf_set_option(state.buffer, 'modifiable', false)
        vim.api.nvim_buf_set_option(state.buffer, 'modified', false)
    end
    vim.api.nvim_win_set_cursor(state.window, _G.alpha_cursor_jumps[1] or {1, 1})
    _G.alpha_redraw = draw
    draw()
end

local function setup(opts)
    vim.cmd("command Alpha lua require'alpha'.start()")
    vim.cmd([[augroup alpha]])
    vim.cmd([[au!]])
    vim.cmd([[autocmd VimResized * if &filetype ==# 'alpha' | call v:lua.alpha_redraw() | endif]])
    vim.cmd([[augroup END]])
    if type(opts) == "table" then
        options = opts
    end
end

return {
    setup = setup;
    start = start;
    default_opts = default_opts;
}
