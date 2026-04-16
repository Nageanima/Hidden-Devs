-- By Nameanima for HD
local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")

local WEEKLY_PREFIX = "WEEKLY"
local MONTHLY_PREFIX = "MONTHLY"

local SECONDS_IN_WEEK = 7 * 24 * 3600
local SECONDS_IN_MONTHS = 30 * 24 * 3600

local RETRY_WAIT_TIME = 1

local LeaderboardsResetTimeMemoryStore = 
	MemoryStoreService:GetSortedMap("LeaderboardsResetTimeMemoryStore")

-- Useful function to retry network reqeusts
local function pcallUntilSucceed(func, ...)
	-- table.pack allows us to save all args returned by function
	local result = table.pack(pcall(func, ...))
	local isSuccess = result[1]
	
	-- Function is called until it finishes its execution without errors
	while not isSuccess do
		task.wait(RETRY_WAIT_TIME)
		result = table.pack(pcall(func, ...))
		isSuccess = result[1]
	end
	
	-- Returning all function arguments + boolean value that indicate
	-- if function called successfuly, just like common pcall
	return table.unpack(result)
end

-- Making a "class" for each leadeboard
-- Useful for separating them
local LeaderboardSortedMap = {} 
do
	LeaderboardSortedMap.__index = LeaderboardSortedMap
	
	-- Default constructor
	function LeaderboardSortedMap.new(name: string, defaultValue: number, refreshTimeInSec: number)
		local newLeaderboard = {}
		newLeaderboard._memoryStore = MemoryStoreService:GetSortedMap(name)
		-- Shows how many seconds needs to reset leaderboard
		newLeaderboard._refreshTime = refreshTimeInSec
		-- Shows when that leaderboard was reseted last time
		newLeaderboard._lastRefreshTime = 0
		-- Default value is needed in order not to clog the memory store
		newLeaderboard._defaultValue = defaultValue
		newLeaderboard._name = name

		return setmetatable(newLeaderboard, LeaderboardSortedMap)
	end
	
	-- Retrieves top |n| (depends on playersCount argument) players from MemoryStore
	function LeaderboardSortedMap:getTop(playersCount: number): {{userId: number, value: number}}
		local memoryStoreSortedMap = self._memoryStore :: MemoryStoreSortedMap
		
		-- Getting top from store, sort direction is descending, because we need highest values
		local _, top = pcallUntilSucceed(
			memoryStoreSortedMap.GetRangeAsync,
			memoryStoreSortedMap,
			Enum.SortDirection.Descending,
			playersCount
		)
		
		local result = {}
		for place, item: {key: number, value: number} in ipairs(top) do
			result[place] = {
				userId = item.key,
				value = item.value,
			}
		end

		return result
	end
	
	-- Useful for getting a specific player's record
	function LeaderboardSortedMap:getPlayerValue(userId: number): number?
		local memoryStoreSortedMap = self._memoryStore :: MemoryStoreSortedMap
		
		-- Getting value from store
		local _, item, _ = pcallUntilSucceed(
			memoryStoreSortedMap.GetAsync,
			memoryStoreSortedMap,
			tostring(userId)
		)
		-- There could be not item, so we return defaultValue instead
		return item or self._defaultValue
	end
	
	-- Returns how many seconds can value be in the MemoryStore, depending on last refresh time
	function LeaderboardSortedMap:_getExpiration()
		local refreshTime = self._refreshTime :: number
		local lastRefreshTime = self._lastRefreshTime :: number
		local currentTime = os.time()

		return refreshTime - (currentTime - lastRefreshTime)
	end
	
	-- Updates a player's entry in the MemoryStore
	function LeaderboardSortedMap:addToPlayerLeaderStat(userId: number, valueToAdd: number)
		local memoryStoreSortedMap = self._memoryStore :: MemoryStoreSortedMap
		
		-- Updating player key, or adding a new one if not existed
		pcallUntilSucceed(
			memoryStoreSortedMap.UpdateAsync,
			memoryStoreSortedMap,
			tostring(userId),
			function(value, sortKey)
				local currentTime = os.time()

				if not value then
					value = self._defaultValue
				end
				local newValue = value + valueToAdd
				return newValue, newValue
			end,
			-- Getting how many seconds that key should lasts
			self:_getExpiration()
		)
	end

	function LeaderboardSortedMap:clearAll()
		local memoryStoreSortedMap = self._memoryStore :: MemoryStoreSortedMap

		local itemsCount = 0

		while true do
			local _, items = pcallUntilSucceed(
				memoryStoreSortedMap.GetRangeAsync,
				memoryStoreSortedMap,
				Enum.SortDirection.Ascending,
				200
			)
			itemsCount += #items

			for _, item in items do
				pcallUntilSucceed(memoryStoreSortedMap.RemoveAsync, memoryStoreSortedMap, item.key)
			end
			-- If items count less than 200 it means that we reached all values in the store
			if #items < 200 then
				break
			end
		end
		return itemsCount
	end
end

local Leaderboards = {}
Leaderboards.STATS = {
	KILLS = "KILLS",
	WINS = "WINS",
}
Leaderboards.PERSONAL_STATS = {
	KILLS = "KILLS",
	WINS = "WINS",
}
-- Creating weekly leaderboards
Leaderboards[WEEKLY_PREFIX] = {
	[Leaderboards.STATS.KILLS] = LeaderboardSortedMap.new(
		`{Leaderboards.STATS.KILLS}{WEEKLY_PREFIX}`,
		0,
		SECONDS_IN_WEEK
	),
	[Leaderboards.STATS.WINS] = LeaderboardSortedMap.new(
		`{Leaderboards.STATS.WINS}{WEEKLY_PREFIX}`,
		0,
		SECONDS_IN_WEEK
	),
}
-- Creating monthly leaderboards
Leaderboards[MONTHLY_PREFIX] = {
	[Leaderboards.STATS.KILLS] = LeaderboardSortedMap.new(
		`{Leaderboards.STATS.KILLS}{MONTHLY_PREFIX}`,
		0,
		SECONDS_IN_MONTHS
	),
	[Leaderboards.STATS.WINS] = LeaderboardSortedMap.new(
		`{Leaderboards.STATS.WINS}{MONTHLY_PREFIX}`,
		0,
		SECONDS_IN_MONTHS
	),
}
-- Allows us to clear leaderboards manually
function Leaderboards:clearAll()
	local itemsCount = 0

	for leaderboardName, leaderboard in pairs(Leaderboards[WEEKLY_PREFIX]) do
		itemsCount += leaderboard:clearAll()
	end
	for leaderboardName, leaderboard in pairs(Leaderboards[MONTHLY_PREFIX]) do
		itemsCount += leaderboard:clearAll()
	end

	return itemsCount
end

do
	local function updateGlobal(userId: number, prefix: string)
		local player = Players:GetPlayerByUserId(userId)
		-- Its a folden where all players data contains
		local dataFolder = player.Data :: Folder
		
		for leaderboardName, leaderboard in pairs(Leaderboards[prefix]) do
			-- Getting some player data and then updating it
			local numberValue = dataFolder:FindFirstChild(leaderboardName) :: NumberValue
			leaderboard:addToPlayerLeaderStat(userId, numberValue.Value)
		end
	end
	
	function Leaderboards:addPlayerStatsToLeaderboards(userId: number)
		-- Updating weekly leaderboard
		updateGlobal(userId, WEEKLY_PREFIX)
		-- Updating monthly leaderboard
		updateGlobal(userId, MONTHLY_PREFIX)
	end
end

-- Updates leaderboards lastRefreshTime
local function updateLeaderboards(prefix: string, updatePeriod: number)
	local _, lastRefresh = pcallUntilSucceed(
		LeaderboardsResetTimeMemoryStore.GetAsync,
		LeaderboardsResetTimeMemoryStore,
		prefix
	)
	-- If not lastRefreshTime was assigned just assign to it 0
	lastRefresh = lastRefresh or 0
	
	--Updating all leaderboards
	for _, leaderboard in pairs(Leaderboards[prefix]) do
		leaderboard._lastRefreshTime = lastRefresh
	end
	
	-- Checks if last refresh time expired already
	if os.time() - lastRefresh < updatePeriod then
		return
	end
	-- Updating refresh time in memory store for other servers
	LeaderboardsResetTimeMemoryStore:UpdateAsync(prefix, function(value, sortKey)
		if not value then
			value = 0
		end
		local currentTime = os.time()
		-- If condition is complete it means that lastRefreshTime was
		-- already updated and then we just abort the operation
		if currentTime - value < updatePeriod then
			return nil
		end
		return currentTime, sortKey
	end, updatePeriod)
end

task.spawn(function()
	while true do
		updateLeaderboards(WEEKLY_PREFIX, SECONDS_IN_WEEK)
		updateLeaderboards(MONTHLY_PREFIX, SECONDS_IN_MONTHS)
		
		task.wait(2)
	end
end)

return Leaderboards
-- By Nameanima for HD