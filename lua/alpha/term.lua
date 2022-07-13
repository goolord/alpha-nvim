local M = {}

function M.open_window(opts)
    local width = opts.width
    local height = opts.height
    local row = math.floor(height / 5)
    local col = math.floor((vim.o.columns - width) / 2)

    local opts = {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
    }

    local bufnr = vim.api.nvim_create_buf(false, true)
    local winid = vim.api.nvim_open_win(bufnr, true, opts)
    vim.api.nvim_win_set_option(winid, "winhl", "Normal:Normal")
    return { bufnr, winid }
end

function M.run_command(cmd, opts)
    if cmd == nil then
        return
    end

    vim.loop
        .new_async(vim.schedule_wrap(function()
            local wininfo = M.open_window(opts)
            vim.api.nvim_command("terminal " .. cmd)
            vim.api.nvim_command("wincmd j")
            vim.api.nvim_buf_set_option(wininfo[1], "buflisted", false)
            vim.api.nvim_win_set_var(0, "dashboard_preview_wininfo", wininfo)
            vim.api.nvim_command('let b:term_title ="dashboard_preview" ')
        end))
        :send()
end

function M.close_window()
    local ok, wininfo = pcall(vim.api.nvim_win_get_var, 0, "dashboard_preview_wininfo")
    if ok and vim.api.nvim_buf_is_loaded(wininfo[1]) then
        vim.api.nvim_buf_delete(wininfo[1], { force = true })
    end
end

return M
