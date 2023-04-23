function gen_word(word, font)
	word = string.upper(word)
	local chars = require("alpha.fonts." .. font)

	local res = {}
	for i = 1, 8 do
		local row = {}
		for c in word:gmatch(".") do
			table.insert(row, chars[c][i])
		end
		table.insert(res, table.concat(row, " "))
	end
	return res
end

function get_repo_name()
	local is_git_repo = os.execute("git rev-parse --is-inside-work-tree > /dev/null 2>&1")
	local success = (is_git_repo == 0) or (type(is_git_repo) == "boolean" and is_git_repo)

	if not success then
		return ""
	end

	local file = io.popen("basename -s .git \"$(git rev-parse --show-toplevel)\"")
	local repo_name = file:read("*a")
	file:close()
	return repo_name:gsub("\n", "") -- Remove the trailing newline character
end


function git_or(word, font)
	local repo = get_repo_name()
	if repo ~= "" then
		return gen_word(repo, font)
	else
		return gen_word(word, font)
	end
end
