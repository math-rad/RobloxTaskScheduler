--[[
Script Name: Task Scheduler
Author: Benjamin Sirianni
Date: 2023

Description: A task scheduler for roblox. See readme for more information on how to use this. 

Usage Terms: You are free to use and modify this script for personal or commercial use, as long as you cite the original author (Benjamin Sirianni) and provide a link to the original source code. You may not claim this script as your own or distribute it without attribution.

]]
local wrap, wait, spawn, defer, yield, resume, create, running, status, insert, remove = require(script.wrap), task.wait, task.spawn, task.defer, coroutine.yield, coroutine.resume, coroutine.create, coroutine.running, coroutine.status, table.insert, table.remove
local TASKref, SCHEDULERref = {}, {} -- differenciate by table reference 
local emptyFunction = function() end

local function proceed(object, ...)
	if type(object) ~= "table" then
		return
	end
	
	local thread = object.thread
	
	if object._ == SCHEDULERref then
		if status(thread) == "dead" or status(thread) == "running" or object.status then
			return
		end
		spawn(thread, object, ...)
	elseif object._ == TASKref then
		if object.thread then
			spawn(thread,  ...)
		end
		
		if object.threads then
			for _, Thread in ipairs(object.threads) do
				spawn(Thread, ...)
			end
		end
		
		if object.callbacks then
			for _, callback in ipairs(object.callbacks) do
				if type(callback) == "table" then
					local callback, Thread = unpack(callback)
					xpcall(callback, warn, ...)
					spawn(Thread, ...)
				else
					xpcall(callback, warn, ...)
				end
			end
		end
	end
end

local TASK = {
	["proceed"] = proceed,
	["wait"] = function(self)
		if self.completed then
			return
		end
		task.defer(wrap(insert, self.threads, running()))
		return yield()
	end,
	["once"] = function(self, f, shouldYield)
		local callbacks, f = self.callbacks, f or emptyFunction
		if self.completed then
			return xpcall(f or emptyFunction, warn)
		end
		if not shouldYield then -- you'll most likely not yield imo
			return table.insert(callbacks, f or emptyFunction)
		else
			task.defer(wrap(insert, callbacks, {f, running()}))
			return yield()
		end
	end,
	["markInitiated"] = function(self)
		self.initiated = true
		self.initiation = time()

	end,
	["_"] = TASKref
}
TASK.__index = TASK

local taskScheduler = {
	["proceed"] = proceed,
	["getTask"] = function(self)
		local Task = remove(self.tasks, 1)
		if not Task then
			self.status = false
			self.currentTask = nil
			yield()
			return self:getTask()
		end
		return Task
	end,
	["processor"] = function(self)
		local handler = self.handler
		while true do
			local Task = self:getTask()
			self.status = true
			self.currentTask = Task
			Task:markInitiated()
			local results = table.pack(handler(Task))
			Task.results = results
			Task.completed = true
			Task:proceed(unpack(results))
			self.status = false
		end
	end,
	["newTask"] = function(self, parameters, shouldYield: boolean)
		local Task = setmetatable({
			["scheduler"] = self,
			["threads"] = {},
			["callbacks"] = {},
			["parameters"] = parameters
		}, TASK)
		
		local enqueue = function()
			task.defer(function()
				insert(self.tasks, Task)
				self:proceed()
			end)
		end
		
		if shouldYield then
			Task.thread = running()
			enqueue()
			return Task, yield()
		else
			return Task, enqueue()
		end
	end,
	["_"] = SCHEDULERref
}
taskScheduler.__index = taskScheduler

function taskScheduler:new(handler)
	return setmetatable({
		["status"] = false,
		["tasks"] = {},
		["handler"] = wrap(xpcall, handler, warn),
		["thread"] = create(self.processor, self)
	}, self)
end


return taskScheduler
