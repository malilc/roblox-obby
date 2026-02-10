-- Logger: Centralized logging with configurable levels

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = {}

Logger.Level = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
	NONE = 5,
}

-- Default: show everything. Set to INFO or higher for production.
Logger.currentLevel = Logger.Level.DEBUG

local function formatMessage(tag: string, ...: any): string
	local parts = { "[" .. tag .. "]" }
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		table.insert(parts, tostring(v))
	end
	return table.concat(parts, " ")
end

function Logger.debug(tag: string, ...: any)
	if Logger.currentLevel <= Logger.Level.DEBUG then
		print(formatMessage(tag, ...))
	end
end

function Logger.info(tag: string, ...: any)
	if Logger.currentLevel <= Logger.Level.INFO then
		print(formatMessage(tag, ...))
	end
end

function Logger.warn(tag: string, ...: any)
	if Logger.currentLevel <= Logger.Level.WARN then
		warn(formatMessage(tag, ...))
	end
end

function Logger.error(tag: string, ...: any)
	if Logger.currentLevel <= Logger.Level.ERROR then
		warn("[ERROR] " .. formatMessage(tag, ...))
	end
end

return Logger
