local lib = _G.FlightMasterData_Internal
if not lib then return end

lib.ClientVersions = {
    { version = "retail", name = "Retail", gameType = "mainline", projectConstant = "WOW_PROJECT_MAINLINE", apiFamily = "modern", minimumInterfaceMajor = 10 },
    { version = "classic", name = "Classic Era", gameType = "classic", projectConstant = "WOW_PROJECT_CLASSIC", apiFamily = "modern", interfaceMajor = 1, tocLabel = "Classic" },
    { version = "forever", name = "WoW Forever", gameType = "camelot", projectConstant = "WOW_PROJECT_MAINLINE", apiFamily = "modern", interfaceMajor = 1, minimumInterfaceMinor = 60, tocLabel = "Camelot" },
    { version = "anniversary", name = "Anniversary / Burning Crusade Classic", gameType = "tbc", projectConstant = "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", apiFamily = "modern", interfaceMajor = 2, tocLabel = "TBC" },
    { version = "wrath", name = "Wrath of the Lich King Classic", gameType = "wrath", projectConstant = "WOW_PROJECT_WRATH_CLASSIC", apiFamily = "legacy", interfaceMajor = 3, tocLabel = "Wrath" },
    { version = "cataclysm", name = "Cataclysm Classic", gameType = "cata", projectConstant = "WOW_PROJECT_CATACLYSM_CLASSIC", apiFamily = "legacy", interfaceMajor = 4, tocLabel = "Cata" },
    { version = "mists", name = "Mists of Pandaria Classic", gameType = "mists", projectConstant = "WOW_PROJECT_MISTS_CLASSIC", apiFamily = "modern", interfaceMajor = 5, tocLabel = "Mists" },
}
-- Compatibility alias for consumers of the first catalog format.
lib.ClientGameTypes = lib.ClientVersions

lib.ClientProfiles = {
    { profile = "wow_forever", dataSet = "forever", version = "forever", gameType = "camelot", channel = "beta", build = "1.60.1.70245", interface = 16001, product = "wow_classic_beta", default = true },
}
