local BASE = "https://raw.githubusercontent.com/newmorta/Roblox-Helpers/main/"

return function(moduleName)
    return loadstring(game:HttpGet(BASE .. moduleName .. ".lua"))()
end
