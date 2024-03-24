local alpha = require("alpha")

local M = {}

function M.open_window(el, state, line)
    local parent_win = state.windows[1]
    local position = M.calc_position(parent_win, el, state, line)

    local win_config = vim.tbl_extend("keep", (el.opts and el.opts.window_config) or {}, {
        relative = "editor",
        row = position.row,
        col = position.col,
        width = el.width,
        height = el.height,
        style = "minimal",
        focusable = false,
        noautocmd = true,
        zindex = 1,
    })

    local bufnr = vim.api.nvim_create_buf(false, true)
    local winid = vim.api.nvim_open_win(bufnr, true, win_config)
    vim.api.nvim_win_set_option(winid, "winhl", "Normal:Normal")
    return { bufnr, winid }
end

function M.run_command(cmd, el, state, line)
    el.parent_id = state.windows[1]
    if cmd == nil then
        return
    end

    if type(cmd) == 'function' then
        cmd = cmd()
    end

    vim.loop.new_async(vim.schedule_wrap(function()
        local wininfo = M.open_window(el, state, line)
        el.wininfo = wininfo
        vim.api.nvim_create_autocmd("User", {
            pattern = "AlphaClosed",
            callback = function()
                if vim.api.nvim_buf_is_valid(wininfo[1]) then
                    vim.api.nvim_buf_delete(wininfo[1], { force = true })
                end
            end,
        })
        vim.api.nvim_command("terminal " .. cmd)
        vim.api.nvim_command("wincmd j")
        vim.api.nvim_buf_set_option(wininfo[1], "buflisted", false)
        vim.api.nvim_command('let b:term_title ="alpha_terminal" ')
    end)):send()
end

function M.calc_position(parent_id, el, state, line)
    local parent_win_width = state.win_width
    local position = vim.api.nvim_win_get_position(parent_id)
    local res = {}
    res.row = math.floor(position[1] + line)
    res.col = math.floor(((parent_win_width - el.width) / 2) + position[2])
    return res
end

function M.reposition(el, state, line)
    local parent_id = el.parent_id
    if parent_id == nil then
        return
    end

    local new_position = M.calc_position(parent_id, el, state, line)
    local term_id = el.wininfo[2]
    local win_config = vim.api.nvim_win_get_config(term_id)
    win_config.row = new_position.row
    win_config.col = new_position.col

    vim.api.nvim_win_set_config(term_id, win_config)
end

function alpha.layout_element.terminal(el, conf, state)
    local line = state.line
    if el.opts and (el.opts.redraw == nil or el.opts.redraw) then
        el.opts.redraw = false
        M.run_command(el.command, el, state, line)
    else
        M.reposition(el, state, line)
    end
    return alpha.layout_element.padding({ type = "padding", val = el.height }, conf, state)
end

function alpha.keymaps_element.terminal(_, _, _)
end

return M
