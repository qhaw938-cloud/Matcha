-- Matcha.lua | fixed version
-- ARK: ESP للضب النادر + أسعار المتاجر (أسماء عربية)
-- التشغيل: اضغط L للتشغيل/الإيقاف، أو زر ON/OFF

local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.parl0vHubCleanup) == "function" then
    pcall(env.parl0vHubCleanup)
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

---------------- فحص القدرات (آمن) ----------------
local function try(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil, nil
end

local function probe(className)
    local inst = try(function() return Instance.new(className) end)
    if inst == nil then return false end
    try(function() inst:Destroy() end)
    return true
end

local canInstance = probe("Frame")
local canColor3   = (try(function() return Color3.fromRGB(255,255,255) end) ~= nil)
local canUDim2    = (try(function() return UDim2.new(0,0,0,0) end) ~= nil)
local canVector3  = (try(function() return Vector3.new(0,0,0) end) ~= nil)
local canHighlight = probe("Highlight")
local canGui = canInstance and canColor3 and canUDim2 and canVector3

---------------- قائمة الأسماء ----------------
local rareNames = {
    ["أبو الضبان"]=true, ["ضب التبر"]=true, ["الضب الألماسي"]=true,
    ["أسطورة البر"]=true, ["الضب العملاق الأسطوري"]=true, ["ضب الياقوت"]=true,
    ["ضب الزمرد"]=true, ["ضب الكهرمان"]=true, ["ضب الفيروز"]=true,
    ["ضب المعادن"]=true, ["الضب النجمي"]=true, ["الضب الأزرق النادر"]=true,
    ["الضب البنفسجي المشع"]=true, ["ضب الميثيك الأرجواني"]=true, ["الضب الناري"]=true,
    ["ضب الفانوس"]=true, ["الضب المشع"]=true, ["الضب الكريستالي"]=true,
    ["ضب الكهوف النادر"]=true, ["ضب الحجر النادر"]=true, ["الضب النادر"]=true,
    ["الضب الأزرق"]=true, ["الضب الوردي"]=true, ["الضب السريع"]=true,
    ["الضب المخفي"]=true, ["الضب الصخري"]=true,
}

local scanAreas = {"الديرة","البر","الكهوف والأماكن المهجورة","العالم الثاني"}

local state = {
    enabled = false,
    alive = true,
    seen = {},
    conns = {},
    priceMin = 100000,
    alerts = true,
    esp = true,
    gui = nil,
    labels = {},
    espItems = {},
    noticeGui = nil,
    nameHit = setmetatable({}, {__mode = "k"}),
    textHit = setmetatable({}, {__mode = "k"}),
}

local function log(msg)
    print("[Matcha] " .. tostring(msg))
end

---------------- نصوص الأسماء ----------------
local function collectTexts(obj)
    local out = {}
    local n = try(function() return obj.Name end)
    if type(n) == "string" then out[#out+1] = n end

    for _, key in ipairs({"TribeName","TamedName","ImprintedName","Blueprint","DisplayName","RareName"}) do
        local v = try(function() return obj:GetAttribute(key) end)
        if type(v) == "string" then out[#out+1] = v end
    end

    local children = try(function() return obj:GetChildren() end) or {}
    for i = 1, math.min(#children, 6) do
        local ch = children[i]
        local txt = try(function()
            if ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("TextBox") then
                return ch.Text
            end
            return nil
        end)
        if type(txt) == "string" then out[#out+1] = txt end
    end

    return out
end

local function matchIn(text)
    for rare in pairs(rareNames) do
        if string.find(text, rare, 1, true) then
            return true, rare
        end
    end
    return false, nil
end

local function matchName(obj)
    for _, t in ipairs(collectTexts(obj)) do
        local ok, rare = matchIn(t)
        if ok then return true, rare end
    end
    return false, nil
end

-- بحث عميق في النص الظاهر على الشاشة (سباقات/لوحات أسماء)
local function matchDeepText(obj)
    local descs = try(function() return obj:GetDescendants() end) or {}
    local limit = math.min(#descs, 40)
    for i = 1, limit do
        local ch = descs[i]
        local txt = try(function()
            if ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("TextBox") then
                return ch.Text
            end
            return nil
        end)
        if type(txt) == "string" then
            local ok, rare = matchIn(txt)
            if ok then return true, rare end
        end
    end
    return false, nil
end

---------------- الأسعار ----------------
local function numeric(value)
    if type(value) == "number" then return value end
    if type(value) ~= "string" then return nil end

    local cleaned = value:gsub("[,%s٬]", "")
    local number = tonumber(cleaned:match("%d+%.?%d*"))
    if not number then return nil end

    if value:match("[Kk]") or value:find("ألف", 1, true) then number = number * 1000 end
    if value:match("[Mm]") or value:find("مليون", 1, true) then number = number * 1000000 end

    return number
end

local priceKeys = {"Price","SellPrice","SellValue","Worth","Value","السعر","القيمة"}

local function getPrice(obj)
    for _, key in ipairs(priceKeys) do
        local attr = try(function() return obj:GetAttribute(key) end)
        local num = numeric(attr)
        if num then return num end

        local child = try(function() return obj:FindFirstChild(key) end)
        if child then
            num = numeric(try(function() return child.Value end))
            if num then return num end
            num = numeric(try(function() return child.Text end))
            if num then return num end
        end
    end

    -- البحث في نص الأبناء عن رقم + رمز عملة
    local children = try(function() return obj:GetChildren() end) or {}
    for i = 1, math.min(#children, 8) do
        local ch = children[i]
        local txt = try(function()
            if ch:IsA("TextLabel") or ch:IsA("TextButton") then return ch.Text end
            return nil
        end)
        if type(txt) == "string" and (txt:find("$") or txt:find("د") or txt:find("ريال") or txt:find("USD")) then
            local num = numeric(txt)
            if num then return num end
        end
    end

    return nil
end

---------------- ESP ----------------
local function getMarkerPart(obj)
    if try(function() return obj:IsA("Model") end) then
        return obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end
    if try(function() return obj:IsA("BasePart") end) then
        return obj
    end
    return nil
end

local function clearEsp(obj)
    local esp = state.espItems[obj]
    if not esp then return end
    try(function() if esp.highlight then esp.highlight:Destroy() end end)
    try(function() if esp.billboard then esp.billboard:Destroy() end end)
    state.espItems[obj] = nil
end

local function applyEsp(obj, labelText)
    if not canGui or not state.esp then return end
    if state.espItems[obj] then return end

    local part = getMarkerPart(obj)
    if not part then return end

    local highlight = nil
    if canHighlight then
        highlight = try(function()
            local h = Instance.new("Highlight")
            h.Name = "MatchaRareHighlight"
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillColor = Color3.fromRGB(255, 215, 0)
            h.OutlineColor = Color3.fromRGB(255, 255, 255)
            h.FillTransparency = 0.35
            h.OutlineTransparency = 0
            h.Parent = obj
            return h
        end)
    end

    local billboard = try(function()
        local b = Instance.new("BillboardGui")
        b.Name = "MatchaRareBillboard"
        b.Size = UDim2.new(0, 200, 0, 42)
        b.StudsOffset = Vector3.new(0, 3, 0)
        b.AlwaysOnTop = true
        b.Parent = part

        local t = Instance.new("TextLabel")
        t.Size = UDim2.fromScale(1, 1)
        t.BackgroundTransparency = 1
        t.TextScaled = true
        t.Font = Enum.Font.GothamBold
        t.TextColor3 = Color3.fromRGB(255, 230, 80)
        t.TextStrokeTransparency = 0
        t.Text = labelText
        t.Parent = b
        return b
    end)

    state.espItems[obj] = {highlight = highlight, billboard = billboard}
end

local function setStatus(message)
    log(message)
    local lbl = state.labels and state.labels.status
    if lbl then try(function() lbl.Text = message end) end
end

---------------- مسح العالم ----------------
local function isTargetArea(name)
    for _, a in ipairs(scanAreas) do
        if name == a then return true end
    end
    return false
end

local function buildPool()
    local pool, seen = {}, {}

    local function add(o)
        if not seen[o] then seen[o] = true; pool[#pool+1] = o end
    end

    -- 1) مجلد الديرة (Dabban) إن وجد
    local dabban = try(function() return workspace:FindFirstChild("Dabban") end)
    if dabban then
        for _, o in ipairs(try(function() return dabban:GetDescendants() end) or {}) do add(o) end
        return pool
    end

    -- 2) المناطق العربية
    for _, o in ipairs(try(function() return workspace:GetDescendants() end) or {}) do
        if try(function() return isTargetArea(o.Name) end) then
            add(o)
            for _, c in ipairs(try(function() return o:GetDescendants() end) or {}) do add(c) end
        end
    end
    if #pool > 0 then return pool end

    -- 3) كل العالم كحل أخير
    return try(function() return workspace:GetDescendants() end) or {}
end

local function scan()
    if not state.enabled then return end

    local objects = buildPool()
    local found = {}

    for _, obj in ipairs(objects) do
        local isModel = try(function() return obj:IsA("Model") end) or false

        -- 1) مطابقة سريعة بالاسم/السمات
        local hit = state.nameHit[obj]
        if hit == nil then
            local ok, rare = matchName(obj)
            hit = {ok = ok, rare = rare}
            state.nameHit[obj] = hit
        end

        -- 2) بحث عميق في النص الظاهر (للمخلوقات التي يظهر اسمها عربي)
        if not hit.ok and isModel then
            local deep = state.textHit[obj]
            if deep == nil then
                local ok, rare = matchDeepText(obj)
                deep = {ok = ok, rare = rare}
                state.textHit[obj] = deep
            end
            if deep.ok then hit = deep end
        end

        local price = getPrice(obj)
        local expensive = (price ~= nil and price >= state.priceMin)

        if hit.ok or expensive then
            found[obj] = true

            local labelText = try(function() return obj.Name end) or "?"
            if hit.rare then labelText = hit.rare .. " | " .. labelText end
            if price then labelText = labelText .. " | " .. tostring(price) end

            applyEsp(obj, labelText)

            if not state.seen[obj] and state.alerts then
                setStatus("Found: " .. labelText)
            end
        end
    end

    for oldObj in pairs(state.seen) do
        if not found[oldObj] then clearEsp(oldObj) end
    end

    state.seen = found
end

---------------- الواجهة ----------------
local function showTopMessage(text, bgColor)
    if not canGui then log(text) return end

    local playerGui = try(function()
        return Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
            or Players.LocalPlayer:WaitForChild("PlayerGui", 5)
    end)
    if not playerGui then log(text) return end

    if state.noticeGui then try(function() state.noticeGui:Destroy() end) end

    local gui = try(function()
        local g = Instance.new("ScreenGui")
        g.Name = "MatchaTopNotice"
        g.ResetOnSpawn = false
        g.Parent = playerGui
        return g
    end)
    if not gui then log(text) return end
    state.noticeGui = gui

    local frame = try(function()
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 240, 0, 42)
        f.Position = UDim2.new(0.5, -120, 0, 18)
        f.BackgroundColor3 = bgColor or Color3.fromRGB(35,120,55)
        f.BorderSizePixel = 0
        f.Parent = gui
        return f
    end)
    if not frame then return end

    try(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = frame
    end)
    try(function()
        local s = Instance.new("UIStroke")
        s.Color = Color3.fromRGB(255,255,255)
        s.Transparency = 0.35
        s.Thickness = 1
        s.Parent = frame
    end)
    try(function()
        local l = Instance.new("TextLabel")
        l.Size = UDim2.fromScale(1, 1)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = Color3.fromRGB(255,255,255)
        l.TextScaled = true
        l.Font = Enum.Font.GothamBold
        l.Parent = frame
    end)

    task.spawn(function()
        task.wait(2.5)
        try(function() if gui and gui.Parent then gui:Destroy() end end)
        if state.noticeGui == gui then state.noticeGui = nil end
    end)
end

local function createGui()
    if not canGui then log("GUI unavailable") return end

    local player = Players.LocalPlayer
    if not player then return end

    local parent = try(function() return player:WaitForChild("PlayerGui", 10) end)
    if not parent then
        log("PlayerGui not found - retry later")
        return
    end

    if state.gui then try(function() state.gui:Destroy() end) end

    local gui = try(function()
        local g = Instance.new("ScreenGui")
        g.Name = "MatchaMenu"
        g.ResetOnSpawn = false
        g.Parent = parent
        return g
    end)
    if not gui then return end
    state.gui = gui

    local panel = try(function()
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 230, 0, 118)
        f.Position = UDim2.new(0, 12, 0, 12)
        f.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        f.BackgroundTransparency = 0.15
        f.BorderSizePixel = 0
        f.Parent = gui
        return f
    end)
    if not panel then return end

    try(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 10)
        c.Parent = panel
    end)

    local function label(text, size, pos, color)
        return try(function()
            local l = Instance.new("TextLabel")
            l.Size = size
            l.Position = pos
            l.BackgroundTransparency = 1
            l.Text = text
            l.TextColor3 = color or Color3.fromRGB(235,235,235)
            l.TextSize = 13
            l.Font = Enum.Font.GothamBold
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.Parent = panel
            return l
        end)
    end

    label("Matcha - ESP", UDim2.new(1,-20,0,20), UDim2.new(0,10,0,6))
    local status = label("OFF | press L", UDim2.new(1,-20,0,18), UDim2.new(0,10,0,28), Color3.fromRGB(255,210,90))
    local priceLabel = label("Min price: " .. tostring(state.priceMin), UDim2.new(1,-20,0,18), UDim2.new(0,10,0,48), Color3.fromRGB(160,220,255))
    state.labels.status = status
    state.labels.price = priceLabel

    local function button(text, x, w, cb)
        try(function()
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, w, 0, 26)
            b.Position = UDim2.new(0, x, 0, 74)
            b.BackgroundColor3 = Color3.fromRGB(45,45,55)
            b.Text = text
            b.TextColor3 = Color3.fromRGB(255,255,255)
            b.TextSize = 13
            b.Font = Enum.Font.GothamBold
            b.BorderSizePixel = 0
            b.Parent = panel
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 8)
            c.Parent = b
            b.MouseButton1Click:Connect(cb)
            return b
        end)
    end

    button("ON/OFF", 10, 90, function() toggle() end)
    button("-", 106, 40, function()
        state.priceMin = math.max(0, state.priceMin - 50000)
        if state.labels.price then state.labels.price.Text = "Min price: " .. tostring(state.priceMin) end
    end)
    button("+", 152, 40, function()
        state.priceMin = state.priceMin + 50000
        if state.labels.price then state.labels.price.Text = "Min price: " .. tostring(state.priceMin) end
    end)

    log("GUI ready | L toggles ON/OFF")
end

local function toggle()
    state.enabled = not state.enabled

    if state.enabled then
        setStatus("ON | scanning rare / priced objects")
        showTopMessage("اشتغل", canColor3 and Color3.fromRGB(35,120,55) or nil)
        scan()
    else
        for obj in pairs(state.espItems) do clearEsp(obj) end
        state.seen = {}
        setStatus("OFF | press L")
        showTopMessage("وقف", canColor3 and Color3.fromRGB(140,45,45) or nil)
    end
end

local function cleanup()
    state.alive = false
    state.enabled = false

    for _, conn in ipairs(state.conns) do try(function() conn:Disconnect() end) end
    for obj in pairs(state.espItems) do clearEsp(obj) end
    if state.gui then try(function() state.gui:Destroy() end) end
    if state.noticeGui then try(function() state.noticeGui:Destroy() end) end

    log("Unloaded")
end

env.parl0vHubCleanup = cleanup
env.parl0vToggle = toggle

local inputConn = try(function()
    return UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.L then toggle() end
    end)
end)
if inputConn then table.insert(state.conns, inputConn) end

task.spawn(function()
    local tries = 0
    while state.alive and tries < 30 do
        if state.gui then break end
        createGui()
        if state.gui then break end
        tries = tries + 1
        task.wait(2)
    end
end)

task.spawn(function()
    while state.alive do
        task.wait(2)
        if state.enabled then scan() end
    end
end)
