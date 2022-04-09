local alpha = {}

-- business logic
local ui = require('gamma-ui')

-- stylua: ignore start
local function should_skip_alpha()
    -- don't start when opening a file
    if vim.fn.argc() > 0 then return true end

    -- skip stdin
    if vim.fn.line2byte("$") ~= -1 then return true end

    -- Handle nvim -M
    if not vim.o.modifiable then return true end

    for _, arg in pairs(vim.v.argv) do
        -- whitelisted arguments
        -- always open
        if  arg == "--startuptime"
            then return false
        end

        -- blacklisted arguments
        -- always skip
        if  arg == "-b"
            -- commands, typically used for scripting
            or arg == "-c" or vim.startswith(arg, "+")
            or arg == "-S"
            then return true
        end
    end

    -- base case: don't skip
    return false
end
-- stylua: ignore end

local current_config

function alpha.start(on_vimenter, conf)
    local window = vim.api.nvim_get_current_win()

    local buffer
    if on_vimenter then
        if should_skip_alpha() then
            return
        end
        buffer = vim.api.nvim_get_current_buf()
    else
        if vim.bo.ft ~= "alpha" then
            buffer = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_win_set_buf(window, buffer)
        else
            buffer = vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_delete(buffer, {})
            return
        end
    end

    if not vim.o.hidden and vim.opt_local.modified:get() then
        vim.api.nvim_err_writeln("Save your changes first.")
        return
    end

    conf = conf or current_config

    local state = {
        line = 0,
        buffer = buffer,
        window = window,
        win_width = 0,
        --
        cursor_ix = 1,
        cursor_jumps = {},
        cursor_jumps_press = {},
        cursor_jumps_press_queue = {},
    }

    ui.register_ui('alpha', state)

    ui.alpha.enable(conf)
    ui.alpha.draw(conf)

    vim.cmd([[doautocmd User AlphaReady]])
    vim.api.nvim_do_autocmd('User', {pattern = 'AlphaReady'})
end

function alpha.setup(config)
    vim.validate {
      config = { config, "table" },
      layout = {config.layout, "table"},
    }

    current_config = config

    vim.api.nvim_add_user_command('Alpha', function () alpha.start(false) end, {bang = true})
    vim.api.nvim_add_user_command('AlphaReady', function () alpha.redraw() end, {bang = true})

    vim.api.nvim_create_augroup('alpha_start', { clear = true })

    vim.api.nvim_create_autocmd("VimEnter", {
        group = 'alpha_start',
        pattern = "*",
        callback = function() alpha.start(true) end,
        nested = true
    })
end

return alpha
