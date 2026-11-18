
local lib = _G.FlightMasterData_Internal
if not lib then return end
if not lib.Client or lib.Client.dataSet ~= "forever" then return end

lib.ModifierTrees = {
}
