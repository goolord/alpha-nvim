local term = {}

local alpha = require("alpha")

local function get_dynamic_value(arg)
    if arg == nil then
        return nil
    end
    if type(arg) == "function" then
        return arg()
    end
    return arg
end

term.terminal_fillers = {}
function term.terminal_fillers.shell_command(cmd)
    return function(win)
        local handler = vim.schedule_wrap(function(_, data)
            vim.fn.chansend(win.channel_id, data)
        end)
        local jobid = vim.fn.jobstart(cmd, {
            pty = true,
            width = win.width,
            height = win.height,
            on_stdout = handler,
        })
        return {
            on_close = function()
                vim.fn.jobstop(jobid)
            end,
        }
    end
end

function term.terminal_fillers.raw_string(string)
    return function(win)
        vim.api.nvim_chan_send(win.channel_id, get_dynamic_value(string))
        return { on_close = function() end }
    end
end

function alpha.layout_element.term(
    el,
    _, --[[opts]]
    state
)
    local width = get_dynamic_value(el.opts.width) or 80
    local height = get_dynamic_value(el.opts.height) or 10
    local offset = get_dynamic_value(el.opts.horizontal_offset) or 0
    local hi_override = get_dynamic_value(el.opts.hl)

    local on_channel_opened = el.on_channel_opened

    local end_ln = state.line + height

    local winid = state.window
    local itemid = state.current_item_id

    local textlines = {}
    for i = 1, height do
        textlines[i] = ""
    end

    local col = offset
    if el.opts.position == "center" then
        col = (state.win_width - width) / 2 + offset
    elseif el.opts.position == "right" then
        col = state.win_width - width + offset
    end

    local win_options = {
        relative = "win",
        width = width,
        height = height,
        row = state.line,
        col = col,
        style = "minimal",
        win = winid,
    }

    if state.aux_windows[itemid] == nil then
        -- works like a mutex lock
        -- somehow this functions gets called concurrently
        state.aux_windows[itemid] = "creation in progress..."

        local window = {}
        window.buf = vim.api.nvim_create_buf(false, true)
        window.win = vim.api.nvim_open_win(window.buf, false, win_options)
        window.chan_id = vim.api.nvim_open_term(window.buf, {})
        if hi_override ~= nil then
            vim.api.nvim_win_set_option(
                window.win,
                "winhighlight",
                "Normal:" .. hi_override .. ",TermCursor:None,TermCursorNC:NoneCursorLine:None,CursorColumn:None"
            )
        end

        local response = on_channel_opened({
            channel_id = window.chan_id,
            width = width,
            height = height,
        })

        window.on_close = response.on_close

        -- I have no clue why I need to do this, but otherwise it gives errors :/
        vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)

        state.aux_windows[itemid] = window
    elseif type(state.aux_windows[itemid]) == "table" then
        local window = state.aux_windows[itemid]
        vim.api.nvim_win_set_config(window.win, win_options)
    end

    state.line = end_ln
    return textlines, {}
end

alpha.keymaps_element.term = function() end

return term
