local M = {}

M.readable_cache = {}
M.mru_cache = {}

local uv = vim.uv or vim.loop

--- @param path string
--- @return boolean
function M.filereadable(path)
    if M.readable_cache[path] ~= nil then
        return M.readable_cache[path]
    end
    local readable = uv.fs_stat(path) ~= nil
    M.readable_cache[path] = readable
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
    local cmd = table.concat({
        "git -C " .. esc .. " diff --name-only",
        "git -C " .. esc .. " diff --cached --name-only",
        "git -C " .. esc .. " log --pretty=format: --name-only -n 5",
    }, "; ")
    local raw = vim.fn.systemlist("{ " .. cmd .. "; } | sort | uniq")

    local seen = {}
    local found = {}
    for _, rel_path in ipairs(raw) do
        if rel_path ~= "" and not seen[rel_path] then
            seen[rel_path] = true
            local abs_path = git_root .. "/" .. rel_path
            local ignore = ignore_cb and ignore_cb(abs_path, M.get_extension(abs_path))
            if not ignore and M.filereadable(abs_path) then
                table.insert(found, abs_path)
                if #found >= items_number then
                    break
                end
            end
        end
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

local function devicons_get_icon(fn, ext)
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if not ok then return nil, nil end
    return devicons.get_icon(fn, ext, { default = true })
end

local function mini_get_icon(fn, ext)
    local ok, mini_icons = pcall(require, "mini.icons")
    if not ok then return nil, nil end
    if ext ~= "" then
        local icon, hl, _ = mini_icons.get("extension", ext)
        return icon, hl
    else
        local icon, hl, _ = mini_icons.get("file", fn)
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
