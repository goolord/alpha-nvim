local alpha = require("alpha")

local M = {}

function M.open_window(el)
    local parent_win = vim.api.nvim_get_current_win()
    local parent_win_width = vim.api.nvim_win_get_width(parent_win)
    local width = el.width
    local height = el.height
    local row = math.floor(height / 5)
    local col = math.floor((parent_win_width - width) / 2)

    local opts = vim.tbl_extend("keep", (el.opts and el.opts.window_config) or {}, {
        relative = "win",
        win = parent_win,
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
    })

    local bufnr = vim.api.nvim_create_buf(false, true)
    local winid = vim.api.nvim_open_win(bufnr, true, opts)
    vim.api.nvim_win_set_option(winid, "winhl", "Normal:Normal")
    return { bufnr, winid }
end

function M.run_command(cmd, el)
    if cmd == nil then
        return
    end

    if type(cmd) == 'function' then
        cmd = cmd()
    end

    vim.loop.new_async(vim.schedule_wrap(function()
        local wininfo = M.open_window(el)
        vim.api.nvim_command("terminal " .. cmd)
        vim.api.nvim_command("wincmd j")
        vim.api.nvim_buf_set_option(wininfo[1], "buflisted", false)
        vim.api.nvim_win_set_var(0, "alpha_section_terminal", wininfo)
        vim.api.nvim_command('let b:term_title ="alpha_terminal" ')
    end)):send()
end

function M.close_window()
    local ok, wininfo = pcall(vim.api.nvim_win_get_var, 0, "alpha_section_terminal")
    if ok and vim.api.nvim_buf_is_loaded(wininfo[1]) then
        vim.api.nvim_buf_delete(wininfo[1], { force = true })
    end
end

vim.api.nvim_create_autocmd("User", {
    pattern = "AlphaClosed",
    callback = function()
        M.close_window()
    end,
})

function M.find_parent_id()
    local windows = vim.api.nvim_list_wins()
    for _, winid in ipairs(windows) do
        local success, value = pcall(vim.api.nvim_win_get_var, winid, "alpha_section_terminal")
        if success and value then
            return winid
        end
    end
    return nil
end

function M.reposition()
    local parent_id = M.find_parent_id()
    if parent_id == nil then
        return
    end

    local parent_width = vim.api.nvim_win_get_width(parent_id)
    local position = vim.api.nvim_win_get_position(parent_id)
    local parent_col = position[2]
    local parent_row = position[1]

    local term_info = vim.api.nvim_win_get_var(parent_id, "alpha_section_terminal")
    local term_id = term_info[2]
    local config = vim.api.nvim_win_get_config(term_id)
    config.row = math.floor(config.height / 5 + parent_row)
    config.col = math.floor((parent_width - config.width) / 2 + parent_col)

    vim.api.nvim_win_set_config(term_id, config)
end

function alpha.layout_element.terminal(el, conf, state)
    if el.opts and (el.opts.redraw == nil or el.opts.redraw) then
        el.opts.redraw = false
        M.run_command(el.command, el)
    else
        M.reposition()
    end
    return alpha.layout_element.padding({ type = "padding", val = el.height }, conf, state)
end

function alpha.keymaps_element.terminal(_, _, _)
end

return M
