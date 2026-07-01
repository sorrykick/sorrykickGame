local ConfigManager = {}

local tables_ = nil

local CONFIG_FILES = {
    npc = "Config/npc.json",
    skill = "Config/skill.json",
    attributes = "Config/Attributes.json",
    icon = "Config/icon.json",
    npcStarLimit = "Config/NpcStarLimit.json",
}

local function decodeJsonFile(path)
    local file = cache:GetFile(path)
    if not file then
        print("[ConfigManager] Missing config: " .. path)
        return {}
    end

    local content = file:ReadString()
    local ok, data = pcall(cjson.decode, content)
    if not ok or type(data) ~= "table" then
        print("[ConfigManager] Decode failed: " .. path)
        return {}
    end
    return data
end

local function isCommentKey(key)
    return type(key) == "string" and string.sub(key, 1, 1) == "#"
end

local function findFirstValidId(tableData)
    local bestId = nil
    local bestKey = nil
    for key, value in pairs(tableData) do
        if not isCommentKey(key) and type(value) == "table" then
            local numericId = tonumber(key)
            if numericId and (not bestId or numericId < bestId) then
                bestId = numericId
                bestKey = key
            end
        end
    end
    return bestKey
end

function ConfigManager.LoadAll()
    if tables_ then
        return tables_
    end

    tables_ = {
        npc = decodeJsonFile(CONFIG_FILES.npc),
        skill = decodeJsonFile(CONFIG_FILES.skill),
        attributes = decodeJsonFile(CONFIG_FILES.attributes),
        icon = decodeJsonFile(CONFIG_FILES.icon),
        npcStarLimit = decodeJsonFile(CONFIG_FILES.npcStarLimit),
    }

    print("[ConfigManager] Configs loaded")
    return tables_
end

function ConfigManager.GetTables()
    return ConfigManager.LoadAll()
end

function ConfigManager.GetNpcConfig(npcId)
    local tables = ConfigManager.LoadAll()
    return tables.npc[tostring(npcId)]
end

function ConfigManager.GetInitialNpcId()
    local tables = ConfigManager.LoadAll()
    if tables.npc["0001"] then
        return "0001"
    end
    if tables.npc["1"] then
        return "1"
    end
    return findFirstValidId(tables.npc)
end

function ConfigManager.GetNpcInitialSkills(npcConfig)
    if not npcConfig or type(npcConfig.Skill) ~= "table" then
        return {}
    end

    local starId = tonumber(npcConfig.BaseStarID) or 1
    local starConfig = ConfigManager.LoadAll().npcStarLimit[tostring(starId)] or {}
    local openSkillNum = math.max(0, math.floor(tonumber(starConfig.OpenSkillNum) or 0))
    local result = {}
    for i = 1, math.min(openSkillNum, #npcConfig.Skill) do
        result[#result + 1] = tonumber(npcConfig.Skill[i]) or npcConfig.Skill[i]
    end
    return result
end

return ConfigManager
