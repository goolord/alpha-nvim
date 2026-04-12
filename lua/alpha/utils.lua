local M = {}

M.mru_cache = {}

local uv = vim.uv or vim.loop

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

    local git_root_out = vim.fn.systemlist("git -C " .. vim.fn.shellescape(work_dir) .. " rev-parse --show-toplevel")
    if vim.v.shell_error ~= 0 or not git_root_out[1] then
        return {}
    end
    local git_root = git_root_out[1]

    local esc = vim.fn.shellescape(work_dir)
    local diff_prefix = "git -C " .. esc .. " diff --name-only; git -C " .. esc .. " diff --cached --name-only; "

    local found = {}
    local prev_raw_count = -1
    local n_commits = items_number
    while #found < items_number and n_commits <= 1024 do
        local raw = vim.fn.systemlist(
            "{ " ..
            diff_prefix ..
            "git -C " .. esc .. " log --pretty=format: --name-only -n " .. n_commits .. "; } | sort | uniq"
        )
        if #raw == prev_raw_count then break end
        prev_raw_count = #raw

        local seen = {}
        found = {}
        for _, rel_path in ipairs(raw) do
            if rel_path ~= "" and not seen[rel_path] then
                seen[rel_path] = true
                local abs_path = git_root .. "/" .. rel_path
                local ignore = ignore_cb and ignore_cb(abs_path, M.get_extension(abs_path))
                if not ignore and M.filereadable(abs_path) then
                    table.insert(found, abs_path)
                end
            end
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
