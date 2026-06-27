local SaveSchema = require("Save.SaveSchema")

local RuntimeSave = {}
RuntimeSave.__index = RuntimeSave

function RuntimeSave.new(baseSave)
    local self = setmetatable({}, RuntimeSave)
    self.data = SaveSchema.DeepClone(baseSave)
    return self
end

function RuntimeSave:GetData()
    return self.data
end

function RuntimeSave:CreateSnapshot()
    return SaveSchema.DeepClone(self.data)
end

function RuntimeSave:GetCoin()
    return self.data.coin or 0
end

function RuntimeSave:GetDiamond()
    return self.data.diamond or 0
end

function RuntimeSave:GetCrystal()
    return self.data.crystal or 0
end

function RuntimeSave:GetPartnerLevel()
    return self.data.partner and self.data.partner.level or 1
end

function RuntimeSave:AddCoin(amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then
        return self.data.coin or 0
    end
    self.data.coin = math.max(0, (self.data.coin or 0) + amount)
    print(string.format("[RuntimeSave] AddCoin amount=%d reason=%s total=%d", amount, tostring(reason), self.data.coin))
    return self.data.coin
end

function RuntimeSave:SetOfflineCollectedAt(timestamp)
    self.data.idle.lastCollectTime = math.floor(tonumber(timestamp) or os.time())
end

return RuntimeSave
