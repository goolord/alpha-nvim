-- business logic

local ui = require('gamma-ui')

local options

local function start(on_vimenter, opts)
    opts = opts or options
    local window = vim.api.nvim_get_current_win()
    local buffer

    if on_vimenter
        then
            if vim.o.insertmode           -- Handle vim -y
                or (not vim.o.modifiable) -- Handle vim -M
                or vim.fn.argc() ~= 0     -- >1 file argument
                or vim.tbl_contains(vim.v.argv, '-c')
                -- or vim.api.nvim_buf_get_offset(0,0) ~= -1
            then return end
            buffer = vim.api.nvim_get_current_buf()
        else
            buffer = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_win_set_buf(window, buffer)
    end

    if not vim.o.hidden and vim.opt_local.modified:get() then
        vim.api.nvim_err_writeln("Save your changes first.")
        return
    end

    local state = {
        line = 0,
        buffer = buffer,
        window = window,
        win_width = 0,
        cursor_ix = 1,
        cursor_jumps = {},
        cursor_jumps_press = {},
    }
    ui.register_ui('alpha', state)

    _G.alpha_ui.alpha.enable(opts)
    _G.alpha_ui.alpha.draw(opts)
    ui.keymaps(opts, state)
    -- ui.keymaps(opts, state)
end

local function setup(opts)
    options = opts
    vim.cmd[[ 
        command! Alpha lua require'alpha'.start(false)
        command! AlphaRedraw call v:lua.alpha_ui.alpha.draw()
        augroup alpha_start
        au!
        autocmd VimEnter * nested lua require'alpha'.start(true)
        augroup END
    ]]
end

return {
    setup = setup,
    start = start,
}
