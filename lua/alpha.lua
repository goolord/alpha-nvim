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
    };
}
local default_opts = {
    layout = {
        default_header;
        { type = "padding"; val = 10 };
        {
            type = "text";
            val = "foo";
            opts = {
                position = "center"
            };
        };
    }
}

local options = default_opts

function longest_line(tbl)
    local longest = 0
    for _,v in pairs(tbl) do
        if #v > longest then longest = #v end
    end
    return longest
end

function center(tbl, state)
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

function layout(layout_tbl, state)
    local layout_element = {
        ["text"] = function (opts)
            if type(opts.val) == "table" then
                local end_ln = state.line + #opts.val
                local val = opts.val
                if opts.opts.position == "center" then val = center(val, state) end
                vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
                if opts.opts.hl then
                    for i = state.line, end_ln do
                        vim.api.nvim_buf_add_highlight(state.buffer, -1, opts.opts.hl, i , 0 , -1)
                    end
                end
                state.line = end_ln
            end
            if type(opts.val) == "string" then
                local val = { opts.val }
                vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
                state.line = state.line + 1
            end
        end,
        ["padding"] = function (opts)
            local end_ln = state.line + opts.val
            local val = { }
            for i = 1, opts.val + 1 do
                val[i] = ""
            end
            vim.api.nvim_buf_set_lines(state.buffer, state.line, state.line, true, val)
            state.line = end_ln
        end,
        ["button"] = function (opts)
        end,
    }

    local line_state = 0
    for _,opts in pairs(layout_tbl) do
        layout_element[opts.type](opts, state)
    end
end

function start(opts)
    opts = opts or options
    vim.opt_local.modifiable = true

    local buffer = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_set_current_buf(buffer)
    local window = vim.api.nvim_get_current_win()
    local state = {
        line = 0;
        buffer = buffer;
        window = window;
    }

    enable_alpha()
    layout(opts.layout, state)

    vim.opt_local.modifiable = false
end

function enable_alpha()
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

    vim.opt_local.ft = 'alpha'
end

function setup(opts)
    vim.cmd("command Alpha lua require'alpha'.start()")
    if type(opts) == "table" then
        options = opts
    end
end

return {
    setup = setup;
    start = start;
    default_opts = default_opts;
}
