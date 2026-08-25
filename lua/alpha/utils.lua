local M = {}

M.mru_cache = {}

--- cwd -> git toplevel path, or false if not a repo (negative cache).
M.git_toplevel_cache = {}

local uv = vim.uv or vim.loop

--- cache key -> true when the cached list is everything its source had, so a
--- request for more items can still be served from it. Keyed separately from
--- mru_cache, which is public and cleared wholesale on DirChanged.
local _cache_exhausted = {}

--- @param key string
--- @param items_number number
--- @return string[]|nil
local function cached_items(key, items_number)
    local cached = M.mru_cache[key]
    if cached and (_cache_exhausted[key] or (#cached >= items_number)) then
        return cached
    end
    return nil
end

--- @param key string
--- @param found string[]
--- @param items_number number
--- @return string[]
local function cache_items(key, found, items_number)
    M.mru_cache[key] = found
    _cache_exhausted[key] = #found < items_number
    return found
end

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

--- Unique non-empty lines in first-seen order. `git log --name-only` lists the
--- most recent commit first, so first-seen order is recency order.
--- @param lines string[]
--- @return string[]
local function unique_lines(lines)
    local out = {}
    local seen = {}
    for _, p in ipairs(lines) do
        if p ~= "" and not seen[p] then
            seen[p] = true
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
    if cached ~= nil then
        return cached or nil
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
    local cached = cached_items(key, items_number)
    if cached then
        return cached
    end

    local git_root = M.git_worktree_root(work_dir)
    if not git_root then
        return {}
    end

    -- two subprocesses, no matter how many items are asked for: working tree
    -- changes (staged and unstaged) first, then paths by commit recency
    local combined = git_cmd_lines(work_dir, { "diff", "--name-only", "HEAD" })
    if not combined then
        -- no commits yet, so there is no HEAD to diff against
        combined = git_cmd_lines(work_dir, { "diff", "--cached", "--name-only" }) or {}
    end
    local n_commits = math.max(50, items_number * 25)
    vim.list_extend(
        combined,
        git_cmd_lines(work_dir, { "log", "--pretty=format:", "--name-only", "-n", tostring(n_commits) }) or {}
    )

    local found = {}
    for _, rel_path in ipairs(unique_lines(combined)) do
        local abs_path = git_root .. "/" .. rel_path
        local ignore = ignore_cb and ignore_cb(abs_path, M.get_extension(abs_path))
        if not ignore and M.filereadable(abs_path) then
            found[#found + 1] = abs_path
            if #found >= items_number then
                break
            end
        end
    end

    return cache_items(key, found, items_number)
end

--- @param cwd string?
--- @param items_number number
--- @param ignore_cb function?
--- @return string[]
function M.get_mru(cwd, items_number, ignore_cb)
    local key = cwd or "global"
    local cached = cached_items(key, items_number)
    if cached then
        return cached
    end

    local oldfiles = vim.v.oldfiles
    local found = {}
    for i = 1, math.min(#oldfiles, 200) do
        local path = oldfiles[i]
        local in_cwd = not cwd or vim.startswith(path, cwd)
        local ignore = ignore_cb and ignore_cb(path, M.get_extension(path))
        if in_cwd and not ignore and M.filereadable(path) then
            found[#found + 1] = path
            if #found >= items_number then
                break
            end
        end
    end

    return cache_items(key, found, items_number)
end

--- @param fn string file name or path
--- @return string
function M.get_extension(fn)
    return vim.fs.basename(fn):match("^.+%.(.+)$") or ""
end

--- name -> the module, `true` if it loaded but is not a table, `false` if it
--- was not on the runtimepath.
local _tried = {}

--- Require an optional module, remembering the result. A missing module is
--- retried only once it shows up in package.loaded, so a lazy loaded plugin is
--- still picked up on a later redraw without paying for a runtimepath scan on
--- every call.
--- @param name string
--- @return table|nil
function M.try_require(name)
    local tried = _tried[name]
    if type(tried) == "table" then
        return tried
    end
    if tried == true then
        return nil
    end
    if tried == false and package.loaded[name] == nil then
        return nil
    end
    local ok, mod = pcall(require, name)
    if not ok then
        _tried[name] = false
        return nil
    end
    if type(mod) ~= "table" then
        -- loaded, but there is no api table to call into
        _tried[name] = true
        return nil
    end
    _tried[name] = mod
    return mod
end

local function devicons_get_icon(fn, ext)
    local devicons = M.try_require("nvim-web-devicons")
    if not devicons then return nil, nil end
    return devicons.get_icon(fn, ext, { default = true })
end

local function mini_get_icon(fn, ext)
    local mini_icons = M.try_require("mini.icons")
    if not mini_icons then return nil, nil end
    local category, name = "file", fn
    if ext ~= "" then
        category, name = "extension", ext
    end
    local icon, hl = mini_icons.get(category, name)
    return icon, hl
end

--- @param provider string devicons or mini
--- @param fn string file name or path
--- @return string, string
function M.get_file_icon(provider, fn)
    local preferred, fallback = devicons_get_icon, mini_get_icon
    if provider == "mini" then
        preferred, fallback = mini_get_icon, devicons_get_icon
    elseif provider ~= "devicons" then
        return "", ""
    end
    local ext = M.get_extension(fn)
    local ico, hl = preferred(fn, ext)
    if ico == nil then
        -- the preferred provider is not installed
        ico, hl = fallback(fn, ext)
    end
    return ico or "", hl or ""
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
