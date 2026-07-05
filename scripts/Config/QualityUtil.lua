local QualityUtil = {}

local QUALITY_RANKS = {
    D = 1,
    C = 2,
    B = 3,
    A = 4,
    S = 5,
    SS = 6,
    L = 7,
}

local QUALITY_NAMES = {
    [1] = "D",
    [2] = "C",
    [3] = "B",
    [4] = "A",
    [5] = "S",
    [6] = "SS",
    [7] = "L",
}

local QUALITY_COLORS = {
    [1] = { 181, 181, 181, 255 },
    [2] = { 162, 255, 148, 255 },
    [3] = { 114, 242, 245, 255 },
    [4] = { 239, 121, 255, 255 },
    [5] = { 255, 237, 0, 255 },
    [6] = { 255, 0, 0, 255 },
    [7] = { 255, 237, 0, 255 },
}

local QUALITY_ICON_PATHS = {
    [1] = "image/品质/_D.png",
    [2] = "image/品质/_C.png",
    [3] = "image/品质/_B.png",
    [4] = "image/品质/_A.png",
    [5] = "image/品质/_S.png",
    [6] = "image/品质/_SS.png",
    [7] = "image/品质/_L.png",
}

local QUALITY_PAGE_ORDER = { 7, 6, 5, 4, 3, 2, 1 }

function QualityUtil.GetRank(value)
    if type(value) == "table" then
        value = value.qualityRank or value.quality
    end
    if type(value) == "number" then
        return math.max(1, math.min(7, math.floor(value)))
    end
    local text = tostring(value or "D")
    local numeric = tonumber(text)
    if numeric then
        return math.max(1, math.min(7, math.floor(numeric)))
    end
    text = string.upper(text)
    return QUALITY_RANKS[text] or 1
end

function QualityUtil.GetName(value)
    return QUALITY_NAMES[QualityUtil.GetRank(value)] or "D"
end

function QualityUtil.GetColor(value)
    return QUALITY_COLORS[QualityUtil.GetRank(value)] or QUALITY_COLORS[1]
end

function QualityUtil.GetIconPath(value)
    return QUALITY_ICON_PATHS[QualityUtil.GetRank(value)] or QUALITY_ICON_PATHS[1]
end

function QualityUtil.GetPageOrder()
    return QUALITY_PAGE_ORDER
end

return QualityUtil
