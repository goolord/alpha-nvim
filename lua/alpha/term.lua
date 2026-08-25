local alpha = require("alpha")

local M = {}

--- Terminal windows are per alpha buffer, not per element: a theme's element
--- table is shared, so two alpha instances drawing it each need their own
--- window. `el.wininfo` and `el.parent_id` mirror the most recent instance,
--- which is what themes and older code read.
--- @param el table
--- @param state table
--- @return table
local function instance(el, state)
    el.instances = el.instances or {}
    local inst = el.instances[state.buffer]
    if inst == nil then
        inst = {}
        el.instances[state.buffer] = inst
    end
    return inst
end

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
    vim.api.nvim_set_option_value("winhl", "Normal:Normal", { win = winid })
    return { bufnr, winid }
end

--- Close a terminal window and its buffer, if they are still around.
--- @param wininfo table? {bufnr, winid}
local function close_wininfo(wininfo)
    if wininfo == nil then
        return
    end
    local bufnr, winid = wininfo[1], wininfo[2]
    if vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_win_close(winid, true)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end
end

--- Run `cmd` in the current buffer as a terminal. Not `:terminal`, which would
--- need the command escaped for an Ex command line.
--- @param cmd string
local function termopen(cmd)
    if vim.fn.has("nvim-0.11") == 1 then
        return vim.fn.jobstart(cmd, { term = true })
    end
    ---@diagnostic disable-next-line: deprecated
    return vim.fn.termopen(cmd)
end

function M.run_command(cmd, el, state, line, inst)
    inst = inst or instance(el, state)
    inst.parent_id = state.windows[1]
    el.parent_id = inst.parent_id
    if cmd == nil then
        return
    end

    if type(cmd) == 'function' then
        cmd = cmd()
    end

    vim.schedule(function()
        -- alpha can be closed, or drawn into another window, between the draw
        -- and this callback
        if not vim.api.nvim_buf_is_valid(state.buffer) then
            return
        end
        local parent_win = state.windows[1]
        if (parent_win == nil) or not vim.api.nvim_win_is_valid(parent_win) then
            return
        end

        -- a re-run replaces this instance's terminal instead of orphaning it
        close_wininfo(inst.wininfo)

        local wininfo = M.open_window(el, state, line)
        local bufnr = wininfo[1]
        termopen(cmd)

        inst.wininfo = wininfo
        el.wininfo = wininfo

        vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
        vim.b[bufnr].term_title = "alpha_terminal"

        local function close()
            if el.instances[state.buffer] == inst then
                el.instances[state.buffer] = nil
            end
            close_wininfo(wininfo)
        end

        -- watches this alpha buffer, so closing one instance leaves the terminals
        -- of the others alone. Not alpha's own augroup, which is deleted while
        -- BufUnload is still being handled
        vim.api.nvim_create_autocmd("BufUnload", {
            group = vim.api.nvim_create_augroup("alpha_terminal_" .. bufnr, { clear = true }),
            buffer = state.buffer,
            once = true,
            callback = function()
                -- close() only ever closes what is still valid, so retrying it
                -- off the event is safe if the editor is locked right now
                if not pcall(close) then
                    vim.schedule(close)
                end
            end,
        })

        vim.api.nvim_command("wincmd j")
    end)
end

function M.calc_position(parent_id, el, state, line)
    local position = vim.api.nvim_win_get_position(parent_id)
    return {
        row = math.floor(position[1] + line),
        col = math.floor(((state.win_width - el.width) / 2) + position[2]),
    }
end

function M.reposition(el, state, line, inst)
    inst = inst or el
    local parent_id = inst.parent_id
    if (parent_id == nil) or not vim.api.nvim_win_is_valid(parent_id) then
        return
    end

    local term_id = inst.wininfo and inst.wininfo[2]
    if (term_id == nil) or not vim.api.nvim_win_is_valid(term_id) then
        return
    end

    local new_position = M.calc_position(parent_id, el, state, line)
    local win_config = vim.api.nvim_win_get_config(term_id)
    win_config.row = new_position.row
    win_config.col = new_position.col

    vim.api.nvim_win_set_config(term_id, win_config)
end

function alpha.layout_element.terminal(el, conf, state)
    local line = state.line
    local opts = el.opts or {}
    el.opts = opts
    local inst = instance(el, state)
    local window_alive = inst.wininfo and vim.api.nvim_win_is_valid(inst.wininfo[2])
    -- opts.redraw is a one-shot request to run the command again; a window that
    -- is gone (alpha closed and reopened) has to run it either way
    if (opts.redraw ~= false) or not window_alive then
        opts.redraw = false
        M.run_command(el.command, el, state, line, inst)
    else
        M.reposition(el, state, line, inst)
    end
    return alpha.layout_element.padding({ type = "padding", val = el.height }, conf, state)
end

return M
