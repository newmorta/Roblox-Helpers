local BASE = "https://raw.githubusercontent.com/newmorta/Roblox-Helpers/main/"
local Cache = {}

return function(moduleName)
    if Cache[moduleName] then
        return Cache[moduleName]
    end

    local module = loadstring(game:HttpGet(BASE .. moduleName .. ".lua"))()
    Cache[moduleName] = module

    return module
end
