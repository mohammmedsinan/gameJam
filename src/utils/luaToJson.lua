local function toLua(value)
	if value == nil then return "nil" end

	local t = type(value)

	if t == "string" then
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" then
		return tostring(value)
	elseif t == "table" then
		local isArray = true
		local i = 1

		for k, _ in pairs(value) do
			if k ~= i then
				isArray = false
				break
			end
			i = i + 1
		end

		local result = {}

		if isArray then
			for _, v in ipairs(value) do
				table.insert(result, toLua(v))
			end
			return "{ " .. table.concat(result, ", ") .. " }"
		else
			for k, v in pairs(value) do
				table.insert(result, k .. " = " .. toLua(v))
			end
			return "{ " .. table.concat(result, ", ") .. " }"
		end
	end
end

return toLua;
