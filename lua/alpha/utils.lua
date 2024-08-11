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

return M
