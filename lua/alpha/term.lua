local term = {}

local Job = require("plenary.job")
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
    return function(channel_id)
        local jobdesc = nil
        if type(cmd) == "table" then
            jobdesc = cmd
        else
            jobdesc = {
                command = "sh",
                args = { "-c", cmd },
            }
        end

        jobdesc.on_stdout = vim.schedule_wrap(function(_, data)
            vim.api.nvim_chan_send(channel_id, data .. "\r\n")
        end)
        jobdesc.on_stderr = jobdesc.on_stdout

        Job:new(jobdesc):start()
    end
end

function term.terminal_fillers.raw_string(string)
    return function(channel_id)
        vim.api.nvim_chan_send(channel_id, get_dynamic_value(string))
    end
end

function alpha.layout_element.term(
    el,
    _ --[[opts]],
    state
)
    local width = get_dynamic_value(el.opts.width) or 20
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

    if state.term_windows[itemid] == nil then
        -- works like a mutex lock
        -- somehow this functions gets called concurrently
        state.term_windows[itemid] = "creation in progress..."

        local window = {}
        window.buf = vim.api.nvim_create_buf(false, true)
        window.win = vim.api.nvim_open_win(window.buf, false, win_options)
        window.chan_id = vim.api.nvim_open_term(window.buf, {})
        if hi_override ~= nil then
            vim.api.nvim_win_set_option(window.win, "winhighlight", "Normal:" .. hi_override)
        end

        on_channel_opened(window.chan_id)

        -- I have no clue why I need to do this, but otherwise it gives errors :/
        vim.api.nvim_buf_set_option(state.buffer, "modifiable", true)

        state.term_windows[itemid] = window
    elseif type(state.term_windows[itemid]) == "table" then
        local window = state.term_windows[itemid]
        vim.api.nvim_win_set_config(window.win, win_options)
    end

    state.line = end_ln
    return textlines, {}
end

alpha.keymaps_element.term = alpha.noop

return term
