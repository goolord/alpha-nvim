local M = {}

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

local has_devicons, devicons = pcall(require, "nvim-web-devicons")
local has_mini_icons, mini_icons = pcall(require, "mini.icons")
local function devicons_get_icon(fn, ext)
    return devicons.get_icon(fn, ext, { default = true })
end
local function mini_get_icon(fn, ext)
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
    if not has_devicons and not has_mini_icons then
        return "", ""
    end

    local ext = M.get_extension(fn)
    if provider == "devicons" then
        -- if devicons is not installed, fallback to mini icons
        if not has_devicons then
            return mini_get_icon(fn, ext)
        end
        return devicons_get_icon(fn, ext)
    end
    if provider == "mini" then
        -- if mini icons is not installed, fallback to devicons
        if not has_mini_icons then
            return devicons_get_icon(fn, ext)
        end
        return mini_get_icon(fn, ext)
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
