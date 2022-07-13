local M = {}

function M.open_window(bufnr)
    local width = 69
    local height = 8
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

    if not bufnr then
        bufnr = vim.api.nvim_create_buf(false, true)
    end

    local winid = vim.api.nvim_open_win(bufnr, true, opts)
    vim.api.nvim_win_set_option(winid, "winhl", "Normal:DashboardTerminal")
    vim.api.nvim_command("hi DashboardTerminal guibg=NONE gui=NONE")
    return { bufnr, winid }
end

M.run_command = vim.loop.new_async(vim.schedule_wrap(function()
    -- local file_path = ""
    -- if type(db.preview_file_path) == "string" then
    --     file_path = db.preview_file_path
    -- elseif type(db.preview_file_path) == "function" then
    --     file_path = db.preview_file_path()
    -- else
    --     vim.notify("wrong type of preview_file_path")
    --     return
    -- end

    local wininfo = M.open_window()
    local cmd = "cat | lolcat -F 0.3 ~/.config/nvim/static/neovim.cat"
    vim.api.nvim_command("terminal " .. cmd)
    vim.api.nvim_command("wincmd j")
    vim.api.nvim_buf_set_option(wininfo[1], "buflisted", false)
    vim.api.nvim_win_set_var(0, "dashboard_preview_wininfo", wininfo)
    vim.api.nvim_command('let b:term_title ="dashboard_preview" ')
end))

function M.close_window()
    local ok, wininfo = pcall(vim.api.nvim_win_get_var, 1, "dashboard_preview_wininfo")
    if ok then
        if vim.api.nvim_buf_is_loaded(wininfo[1]) then
            vim.api.nvim_buf_delete(wininfo[1], { force = true })
        end
        if vim.api.nvim_win_is_valid(wininfo[2]) then
            vim.api.nvim_win_close(wininfo[2], true)
        end
    end
end

return M
