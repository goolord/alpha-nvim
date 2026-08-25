-- Minimal headless test harness.
-- run: nvim --clean --cmd 'set rtp+=.' -l tests/run.lua
-- or:  make test

-- git has to see none of the user's config: no global hooks, commit template,
-- signing key or credential prompts
vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
vim.env.GIT_CONFIG_SYSTEM = "/dev/null"
vim.env.GIT_TERMINAL_PROMPT = "0"

local has_git = vim.fn.executable("git") == 1

local cases = {}
local failures = {}
local skips = {}

local function test(name, fn)
    cases[#cases + 1] = { name = name, fn = fn }
end

local function fail(msg)
    error(msg, 2)
end

--- Abandon the case without failing the run, for a case that needs something
--- this machine does not have.
local function skip_if(cond, reason)
    if cond then
        error({ skip = reason }, 0)
    end
end

--- Run `fn`, then `cleanup` whether or not `fn` threw. Without this, a failing
--- assertion leaves temp dirs, the cwd and shared theme tables behind, and the
--- cases after it fail for the wrong reason.
local function with_cleanup(fn, cleanup)
    local success, err = pcall(fn)
    cleanup()
    if not success then
        error(err, 0)
    end
end

local function eq(got, want, what)
    if not vim.deep_equal(got, want) then
        fail(string.format("%s: expected %s, got %s", what or "value", vim.inspect(want), vim.inspect(got)))
    end
end

local function ok(fn, what)
    local success, err = pcall(fn)
    if not success then
        fail(string.format("%s: unexpected error: %s", what or "call", tostring(err)))
    end
end

local alpha = require("alpha")

--- Leave the alpha buffer so its `bufhidden=wipe` fires BufUnload -> alpha.close,
--- which is what clears the per-buffer state between cases.
local function reset()
    vim.cmd("enew!")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "alpha" then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
end

--- @param layout table
--- @param opts table?
local function open(layout, opts)
    reset()
    local conf = { layout = layout, opts = vim.tbl_extend("keep", opts or {}, { margin = 0 }) }
    alpha.setup(conf)
    alpha.start(false, conf)
    return conf
end

local function lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function marks()
    local out = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do
        out[#out + 1] = { row = m[2], col = m[3], hl = m[4].hl_group }
    end
    return out
end

local function button(txt, on_press, opts)
    return {
        type = "button",
        val = txt,
        on_press = on_press or function() end,
        opts = vim.tbl_extend("keep", opts or {}, { shortcut = "", cursor = 0 }),
    }
end

test("multi-line string text advances one line per rendered line", function()
    open({
        { type = "text", val = "aaa\nbbb\nccc", opts = { hl = "Type" } },
        button("press me"),
    })
    eq(lines(), { "aaa", "bbb", "ccc", "press me" }, "rendered lines")
    eq(vim.api.nvim_win_get_cursor(0)[1], 4, "cursor row on the button")

    local rows = {}
    for _, m in ipairs(marks()) do
        rows[#rows + 1] = m.row
    end
    table.sort(rows)
    eq(rows, { 0, 1, 2 }, "highlighted rows")
end)

test("text values that are not strings still render", function()
    -- centering is what turns them into strings, and measuring them must not throw
    open({ { type = "text", val = { 123, "abc" }, opts = { position = "center", hl = "Type" } } })
    eq(vim.tbl_map(vim.trim, lines()), { "123", "abc" }, "rendered lines")
end)

test("press with no buttons is a no-op", function()
    open({ { type = "text", val = "no buttons here" } })
    ok(alpha.press, "alpha.press")
end)

test("queued press survives a layout shrink", function()
    local count = 3
    local conf = open({
        {
            type = "group",
            val = function()
                local group = {}
                for i = 1, count do
                    group[i] = button("btn" .. i)
                end
                return group
            end,
        },
    })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    alpha.move_cursor(0)
    ok(alpha.queue_press, "alpha.queue_press")
    count = 1
    ok(function()
        alpha.redraw(conf)
    end, "redraw after shrink")
    eq(lines(), { "btn1" }, "shrunk layout")
    ok(alpha.press, "press after shrink")
end)

test("press fires each queued button once", function()
    local pressed = {}
    open({
        {
            type = "group",
            val = {
                button("one", function()
                    pressed[#pressed + 1] = 1
                end),
                button("two", function()
                    pressed[#pressed + 1] = 2
                end),
            },
        },
    })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    alpha.move_cursor(0)
    alpha.queue_press()
    alpha.press()
    eq(pressed, { 1 }, "first press")
    alpha.press()
    eq(pressed, { 1, 1 }, "queue cleared, cursor press only")
end)

test("redraw accepts a conf without a state", function()
    local conf = open({ { type = "text", val = "hello" } })
    ok(function()
        alpha.redraw(conf)
    end, "redraw(conf)")
    ok(alpha.redraw, "redraw()")
end)

test("button keymaps follow the drawn layout", function()
    local rhs = "gg"
    local conf = open({
        {
            type = "group",
            val = function()
                return {
                    button("dynamic", nil, { keymap = { "n", "gx", rhs, { noremap = true } } }),
                }
            end,
        },
    })
    local function mapped()
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
            if m.lhs == "gx" then
                return m.rhs
            end
        end
    end
    eq(mapped(), rhs, "initial keymap")
    rhs = "G"
    alpha.redraw(conf)
    eq(mapped(), rhs, "keymap after redraw")
end)

test("a custom element can register keymaps through keymaps_element", function()
    -- the deprecated path: the element draws its own lines, and its keymaps come
    -- from children alpha never saw as buttons
    local child = button("nested", nil, { keymap = { "n", "gy", "gg", { noremap = true } } })
    alpha.layout_element.box = function(el, conf, state)
        return alpha.layout_element.text({ type = "text", val = "box" }, conf, state)
    end
    alpha.keymaps_element.box = function(el, conf, state)
        for _, v in pairs(el.val) do
            alpha.keymaps_element[v.type](v, conf, state)
        end
    end
    open({ { type = "box", val = { child } } })
    eq(lines(), { "box" }, "rendered lines")

    local found
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
        if m.lhs == "gy" then
            found = m.rhs
        end
    end

    -- close the instance before the element type goes away, so nothing can
    -- redraw a layout alpha no longer knows how to draw
    reset()
    alpha.layout_element.box = nil
    alpha.keymaps_element.box = nil
    eq(found, "gg", "keymap from the custom element")
end)

test("group inherit does not mutate the layout tables", function()
    local child = { type = "text", val = "child" }
    local conf = open({
        { type = "group", val = { child }, opts = { inherit = { position = "center" } } },
    })
    alpha.redraw(conf)
    eq(child.opts, nil, "child opts untouched")
end)

test("start works on a config that never went through setup", function()
    reset()
    ok(function()
        alpha.start(false, { layout = { { type = "text", val = "raw config" } } })
    end, "start with a raw config")
    eq(lines(), { "raw config" }, "rendered lines")
end)

test("startify button without a keybind can be pressed", function()
    local startify = require("alpha.themes.startify")
    ok(startify.button("SPC f f", "Find file").on_press, "startify on_press")
    ok(require("alpha.themes.dashboard").button("SPC f f", "Find file").on_press, "dashboard on_press")
end)

--- A throwaway git repo with one commit per file, oldest first.
--- @param names string[]
--- @return string dir
local function git_repo(names)
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    local function git(...)
        vim.fn.system(vim.list_extend({ "git", "-C", dir }, { ... }))
    end
    git("init", "-q", "-b", "main")
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "test")
    for _, name in ipairs(names) do
        vim.fn.writefile({ name }, dir .. "/" .. name)
        git("add", name)
        git("-c", "commit.gpgsign=false", "commit", "-q", "-m", "add " .. name)
    end

    local utils = require("alpha.utils")
    utils.mru_cache = {}
    utils.git_toplevel_cache = {}
    utils.clear_readable_cache()
    return dir
end

test("git files are ordered by recency", function()
    skip_if(not has_git, "git is not installed")
    -- committed in alphabetical order, so an alphabetical result is not a recency result
    local dir = git_repo({ "apple.txt", "middle.txt", "zebra.txt" })
    with_cleanup(function()
        local found = require("alpha.utils").get_git_files(dir, 3)
        eq(vim.tbl_map(vim.fs.basename, found), { "zebra.txt", "middle.txt", "apple.txt" }, "most recent first")
    end, function()
        vim.fn.delete(dir, "rf")
    end)
end)

test("git files include staged files in a repo with no commits", function()
    skip_if(not has_git, "git is not installed")
    local dir = git_repo({})
    with_cleanup(function()
        vim.fn.writefile({ "x" }, dir .. "/staged.txt")
        vim.fn.system({ "git", "-C", dir, "add", "staged.txt" })
        local found = require("alpha.utils").get_git_files(dir, 5)
        eq(vim.tbl_map(vim.fs.basename, found), { "staged.txt" }, "staged file")
    end, function()
        vim.fn.delete(dir, "rf")
    end)
end)

for _, name in ipairs({ "dashboard", "startify", "theta" }) do
    test("the " .. name .. " theme renders", function()
        local theme = require("alpha.themes." .. name)
        reset()
        ok(function()
            alpha.setup(theme.config)
            alpha.start(false, theme.config)
        end, "start")
        local rendered = lines()
        local has_header = false
        for _, line in ipairs(rendered) do
            if line:find("_", 1, true) then
                has_header = true
                break
            end
        end
        if not has_header then
            fail("expected the header art in: " .. vim.inspect(rendered))
        end
        ok(alpha.redraw, "redraw")
    end)
end

test("a terminal element draws and redraws", function()
    require("alpha.term")
    local el = {
        type = "terminal",
        command = "true",
        width = 20,
        height = 3,
        opts = { redraw = true, window_config = {} },
    }
    local conf = open({ el, button("after the terminal") })
    eq(#lines(), 4, "terminal height plus the button")

    -- run_command is scheduled, so let the loop drain before checking on it
    vim.wait(500, function()
        return el.wininfo ~= nil
    end)
    if el.wininfo == nil then
        fail("the terminal window was never opened")
    end
    eq(vim.bo[el.wininfo[1]].buftype, "terminal", "terminal buffer is the one being tracked")

    ok(function()
        alpha.redraw(conf)
    end, "redraw")
    reset()
end)

test("a git mru section renders file buttons", function()
    skip_if(not has_git, "git is not installed")
    local dir = git_repo({ "apple.txt", "zebra.txt" })
    local startify = require("alpha.themes.startify")
    local sections = startify.mru_sections
    local cwd = vim.fn.getcwd()

    with_cleanup(function()
        vim.cmd.cd(dir)
        startify.mru_sections = { "mru_git" }
        reset()
        alpha.setup(startify.config)
        alpha.start(false, startify.config)
        local rendered = table.concat(lines(), "\n")
        for _, name in ipairs({ "zebra.txt", "apple.txt" }) do
            if not rendered:find(name, 1, true) then
                fail(name .. " missing from:\n" .. rendered)
            end
        end
    end, function()
        startify.mru_sections = sections
        vim.cmd.cd(cwd)
        vim.fn.delete(dir, "rf")
    end)
end)

for _, case in ipairs(cases) do
    local success, err = pcall(case.fn)
    if success then
        print("ok   " .. case.name)
    elseif (type(err) == "table") and err.skip then
        print("skip " .. case.name .. ": " .. err.skip)
        skips[#skips + 1] = case.name
    else
        print("FAIL " .. case.name)
        failures[#failures + 1] = string.format("%s\n     %s", case.name, tostring(err))
    end
end

print("")
print(string.format("%d/%d passed, %d skipped", #cases - #failures - #skips, #cases, #skips))
if #failures > 0 then
    print("")
    for _, f in ipairs(failures) do
        print("FAIL " .. f)
    end
    os.exit(1)
end
