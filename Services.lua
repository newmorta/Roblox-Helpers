-- Services.lua

local Services = {}

local Cache = {}

setmetatable(Services, {
	__index = function(_, serviceName)
		local service = Cache[serviceName]

		if not service then
			service = game:GetService(serviceName)
			Cache[serviceName] = service
		end

		return service
	end,
})

return Services
