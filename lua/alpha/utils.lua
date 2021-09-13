-- utility functions

local utils = {}

-- usage:
-- loadstring = memoize(loadstring)
function utils.memoize (f)
    local mem = {} -- memoizing table
    setmetatable(mem, {__mode = "kv"}) -- make it weak
    return function (x) -- new version of ’f’, with memoizing
        local r = mem[x]
        if r == nil then -- no previous result?
            r = f(x) -- calls original function
            mem[x] = r -- store result for reuse
        end
        return r
    end
end

function utils.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.deepcopy(orig_key)] = utils.deepcopy(orig_value)
        end
        setmetatable(copy, utils.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function utils.contains(table, val)
   for i=1,#table do
      if table[i] == val then
         return true
      end
   end
   return false
end

return utils
