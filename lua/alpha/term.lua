local alpha = require("alpha")

local M = {}

function M.open_window(el)
    local width = el.width
    local height = el.height
    local row = math.floor(height / 5)
    local col = math.floor((vim.o.columns - width) / 2)

    local opts = vim.tbl_extend("keep", (el.opts and el.opts.window_config) or {}, {
        relative = "editor",
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

function alpha.layout_element.terminal(el, conf, state)
    if el.opts and (el.opts.redraw == nil or el.opts.redraw) then
        el.opts.redraw = false
        M.run_command(el.command, el)
    end
    return alpha.layout_element.padding({ type = "padding", val = el.height }, conf, state)
end

function alpha.keymaps_element.terminal(_, _, _)
end

return M
