local M = {}

M.mru_cache = {}

--- cwd -> git toplevel path, or false if not a repo (negative cache).
M.git_toplevel_cache = {}

local uv = vim.uv or vim.loop

--- @param work_dir string
--- @param git_args string[]
--- @return string[]|nil lines, or nil on git failure
local function git_cmd_lines(work_dir, git_args)
    local cmd = vim.list_extend({ "git", "-C", work_dir }, git_args)
    local out = vim.fn.systemlist(cmd)
    if vim.v.shell_error ~= 0 then
        return nil
    end
    return out
end

--- Same ordering as `{ ... } | sort | uniq`: sorted unique non-empty lines.
--- @param lines string[]
--- @return string[]
local function sorted_unique_lines(lines)
    if #lines == 0 then
        return lines
    end
    local sorted = vim.list_extend({}, lines)
    table.sort(sorted)
    local out = {}
    local prev
    for _, p in ipairs(sorted) do
        if p ~= "" and p ~= prev then
            prev = p
            out[#out + 1] = p
        end
    end
    return out
end

--- Resolve the git worktree root for cwd, using a small cache (cleared with MRU cache on DirChanged).
--- @param work_dir string?
--- @return string|nil
function M.git_worktree_root(work_dir)
    work_dir = work_dir or vim.fn.getcwd()
    local cached = M.git_toplevel_cache[work_dir]
    if cached == false then
        return nil
    end
    if cached ~= nil then
        return cached
    end
    local top_out = git_cmd_lines(work_dir, { "rev-parse", "--show-toplevel" })
    if not top_out or not top_out[1] then
        M.git_toplevel_cache[work_dir] = false
        return nil
    end
    M.git_toplevel_cache[work_dir] = top_out[1]
    return top_out[1]
end

local READABLE_CACHE_MAX = 500
local _readable_cache = {}
local _readable_cache_size = 0

--- Reset the readable cache and its size counter atomically.
--- Always use this instead of assigning to the table directly.
function M.clear_readable_cache()
    _readable_cache = {}
    _readable_cache_size = 0
end

--- @param path string
--- @return boolean
function M.filereadable(path)
    if _readable_cache[path] ~= nil then
        return _readable_cache[path]
    end
    if _readable_cache_size >= READABLE_CACHE_MAX then
        M.clear_readable_cache()
    end
    local readable = uv.fs_stat(path) ~= nil
    _readable_cache[path] = readable
    _readable_cache_size = _readable_cache_size + 1
    return readable
end

--- @param cwd string? working directory, defaults to cwd
--- @param items_number number max number of items to return
--- @param ignore_cb function? optional ignore callback(path, ext) -> bool
--- @return string[]
function M.get_git_files(cwd, items_number, ignore_cb)
    local work_dir = cwd or vim.fn.getcwd()
    local key = "git_" .. work_dir
    if M.mru_cache[key] and #M.mru_cache[key] >= items_number then
        return M.mru_cache[key]
    end

    local git_root = M.git_worktree_root(work_dir)
    if not git_root then
        return {}
    end

    local diff_out = git_cmd_lines(work_dir, { "diff", "--name-only" }) or {}
    local cached_out = git_cmd_lines(work_dir, { "diff", "--cached", "--name-only" }) or {}

    local found = {}
    local prev_unique_count = -1
    local n_commits = math.max(50, items_number * 25)
    local n_max = 2048

    while #found < items_number and n_commits <= n_max do
        local log_out = git_cmd_lines(work_dir, {
            "log",
            "--pretty=format:",
            "--name-only",
            "-n",
            tostring(n_commits),
        }) or {}

        local combined = {}
        vim.list_extend(combined, diff_out)
        vim.list_extend(combined, cached_out)
        vim.list_extend(combined, log_out)

        local sorted_paths = sorted_unique_lines(combined)
        if #sorted_paths == prev_unique_count then
            break
        end
        prev_unique_count = #sorted_paths

        found = {}
        for _, rel_path in ipairs(sorted_paths) do
            local abs_path = git_root .. "/" .. rel_path
            local ignore = ignore_cb and ignore_cb(abs_path, M.get_extension(abs_path))
            if not ignore and M.filereadable(abs_path) then
                table.insert(found, abs_path)
                if #found >= items_number then
                    break
                end
            end
        end

        if #found >= items_number then
            break
        end
        n_commits = n_commits * 2
    end

    M.mru_cache[key] = found
    return found
end

--- @param cwd string?
--- @param items_number number
--- @param ignore_cb function?
--- @return string[]
function M.get_mru(cwd, items_number, ignore_cb)
    local key = cwd or "global"
    if M.mru_cache[key] and #M.mru_cache[key] >= items_number then
        return M.mru_cache[key]
    end

    local all_oldfiles = vim.v.oldfiles
    local found = {}
    local max_check = math.min(#all_oldfiles, 200)
    for i = 1, max_check do
        local v = all_oldfiles[i]
        local cwd_cond = not cwd or vim.startswith(v, cwd)
        local ignore = (ignore_cb and ignore_cb(v, M.get_extension(v))) or false
        if cwd_cond and not ignore then
            if M.filereadable(v) then
                table.insert(found, v)
                if #found >= items_number then
                    break
                end
            end
        end
    end

    M.mru_cache[key] = found
    return found
end

--- @param fn string file name or path
--- @return string
function M.get_extension(fn)
    local basename = vim.fs.basename(fn)
    local match = basename:match("^.+(%..+)$")
    local ext = ""
    if match ~= nil then
        ext = match:sub(2)
    end
    return ext
end

local _devicons, _devicons_tried
local function devicons_get_icon(fn, ext)
    if not _devicons_tried then
        local ok
        ok, _devicons = pcall(require, "nvim-web-devicons")
        if ok then _devicons_tried = true else _devicons = nil end
    end
    if not _devicons then return nil, nil end
    return _devicons.get_icon(fn, ext, { default = true })
end

local _mini_icons, _mini_tried
local function mini_get_icon(fn, ext)
    if not _mini_tried then
        local ok
        ok, _mini_icons = pcall(require, "mini.icons")
        if ok then _mini_tried = true else _mini_icons = nil end
    end
    if not _mini_icons then return nil, nil end
    if ext ~= "" then
        local icon, hl, _ = _mini_icons.get("extension", ext)
        return icon, hl
    else
        local icon, hl, _ = _mini_icons.get("file", fn)
        return icon, hl
    end
end

--- @param provider string devicons or mini
--- @param fn string file name or path
--- @return string, string
function M.get_file_icon(provider, fn)
    local ext = M.get_extension(fn)
    if provider == "devicons" then
        local ico, hl = devicons_get_icon(fn, ext)
        -- if devicons is not installed, fallback to mini icons
        if ico == nil then ico, hl = mini_get_icon(fn, ext) end
        return ico or "", hl or ""
    end
    if provider == "mini" then
        local ico, hl = mini_get_icon(fn, ext)
        -- if mini icons is not installed, fallback to devicons
        if ico == nil then ico, hl = devicons_get_icon(fn, ext) end
        return ico or "", hl or ""
    end
    return "", ""
end

--- Validate the provider, fetch the icon, and mutate file_icons.enabled on failure.
--- @param file_icons table theme-local file_icons config table (provider, enabled fields)
--- @param fn string file name or path
--- @return string, string icon and highlight group
function M.get_icon(file_icons, fn)
    if file_icons.provider ~= "devicons" and file_icons.provider ~= "mini" then
        vim.notify(
            "Alpha: Invalid file icons provider: " .. file_icons.provider .. ", disable file icons",
            vim.log.levels.WARN
        )
        file_icons.enabled = false
        return "", ""
    end
    local ico, hl = M.get_file_icon(file_icons.provider, fn)
    if ico == "" then
        file_icons.enabled = false
        vim.notify("Alpha: Mini icons or devicons get icon failed, disable file icons", vim.log.levels.WARN)
    end
    return ico, hl
end

--- @param hl (string | number)[][][] highlight
--- @param text string[] text lines corresponding to the highlights
--- @param utf16? boolean default: false
--- @return (string | number)[][][]
function M.charhl_to_bytehl(hl, text, utf16)
    utf16 = utf16 or false

    local new_hl = {}
    for row, line_hl in ipairs(hl) do
        new_hl[row] = {}

        for i, item in ipairs(line_hl) do
            local group = item[1]
            local start_col = vim.fn.byteidx(text[row], item[2], utf16)
            local end_col = vim.fn.byteidx(text[row], item[3], utf16)

            new_hl[row][i] = { group, start_col, end_col }
        end
    end

    return new_hl
end

return M
