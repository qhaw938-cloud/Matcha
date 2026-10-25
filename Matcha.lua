-- Matcha.lua | rare scanner + top notification + menu
local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.parl0vHubCleanup) == "function" then
    pcall(env.parl0vHubCleanup)
end

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local rareNames = {
    ["أبو الضبان"] = true,
    ["ضب التبر"] = true,
    ["الضب الألماسي"] = true,
    ["أسطورة البر"] = true,
    ["الضب العملاق الأسطوري"] = true,
    ["ضب الياقوت"] = true,
    ["ضب الزمرد"] = true,
    ["ضب الكهرمان"] = true,
    ["ضب الفيروز"] = true,
    ["ضب المعادن"] = true,
    ["الضب النجمي"] = true,
    ["الضب الأزرق النادر"] = true,
    ["الضب البنفسجي المشع"] = true,
    ["ضب الميثيك الأرجواني"] = true,
    ["الضب الناري"] = true,
    ["ضب الفانوس"] = true,
    ["الضب المشع"] = true,
    ["الضب الكريستالي"] = true,
    ["ضب الكهوف النادر"] = true,
    ["ضب الحجر النادر"] = true,
    ["الضب النادر"] = true,
    ["الضب الأزرق"] = true,
    ["الضب الوردي"] = true,
    ["الضب السريع"] = true,
    ["الضب المخفي"] = true,
    ["الضب الصخري"] = true,
}

local state = {
    enabled = false,
    alive = true,
    seen = {},
    conns = {},
    priceMin = 100000,
    scanNames = true,
    scanPrices = true,
    alerts = true,
    esp = true,
    gui = nil,
    labels = {},
    espItems = {},
    noticeGui = nil,
}

local function log(msg)
    print("[Matcha] " .. tostring(msg))
end

local function safe(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
end

local function getPlayerGui()
    local player = Players.LocalPlayer
    if not player then
        return nil
    end
    return player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 5)
end

local function showTopMessage(text, bgColor)
    local playerGui = safe(getPlayerGui)
    if not playerGui then
        log(text)
        return
    end

    if state.noticeGui then
        safe(function()
            state.noticeGui:Destroy()
        end)
        state.noticeGui = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MatchaTopNotice"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui
    state.noticeGui = gui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 42)
    frame.Position = UDim2.new(0.5, -120, 0, 18)
    frame.BackgroundColor3 = bgColor or Color3.fromRGB(35, 120, 55)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.35
    stroke.Thickness = 1
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = frame

    task.spawn(function()
        task.wait(2.5)
        if gui and gui.Parent then
            gui:Destroy()
        end
        if state.noticeGui == gui then
            state.noticeGui = nil
        end
    end)
end

local function matchName(text)
    if type(text) ~= "string" then
        return false
    end

    for rareName in pairs(rareNames) do
        if string.find(text, rareName, 1, true) then
            return true
        end
    end

    return false
end

local function numeric(value)
    if type(value) == "number" then
        return value
    end

    if type(value) ~= "string" then
        return nil
    end

    local cleaned = value:gsub("[,%s٬]", "")
    local number = tonumber(cleaned:match("%d+%.?%d*"))
    if not number then
        return nil
    end

    if value:match("[Kk]") or value:find("ألف", 1, true) then
        number = number * 1000
    end

    if value:match("[Mm]") or value:find("مليون", 1, true) then
        number = number * 1000000
    end

    return number
end

local function getPrice(obj)
    local priceKeys = { "Price", "SellPrice", "SellValue", "Worth", "Value", "السعر", "القيمة" }

    for _, key in ipairs(priceKeys) do
        local attr = safe(function()
            return obj:GetAttribute(key)
        end)

        local num = numeric(attr)
        if num then
            return num
        end

        local child = safe(function()
            return obj:FindFirstChild(key)
        end)

        if child then
            local childValue = safe(function()
                return child.Value
            end)

            num = numeric(childValue)
            if num then
                return num
            end

            local childText = safe(function()
                return child.Text
            end)

            num = numeric(childText)
            if num then
                return num
            end
        end
    end

    return nil
end

local function getMarkerPart(obj)
    if obj:IsA("Model") then
        return obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end

    if obj:IsA("BasePart") then
        return obj
    end

    return nil
end

local function clearEsp(obj)
    local esp = state.espItems[obj]
    if not esp then
        return
    end

    safe(function()
        if esp.highlight then
            esp.highlight:Destroy()
        end
    end)

    safe(function()
        if esp.billboard then
            esp.billboard:Destroy()
        end
    end)

    state.espItems[obj] = nil
end

local function applyEsp(obj, labelText)
    if not state.esp then
        return
    end

    if state.espItems[obj] then
        return
    end

    local part = getMarkerPart(obj)
    if not part then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "MatchaRareHighlight"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(255, 215, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.35
    highlight.OutlineTransparency = 0
    highlight.Parent = obj

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MatchaRareBillboard"
    billboard.Size = UDim2.new(0, 180, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = part

    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextScaled = true
    text.Font = Enum.Font.GothamBold
    text.TextColor3 = Color3.fromRGB(255, 230, 80)
    text.TextStrokeTransparency = 0
    text.Text = labelText
    text.Parent = billboard

    state.espItems[obj] = {
        highlight = highlight,
        billboard = billboard,
    }
end

local function setStatus(message)
    log(message)

    if state.labels.status then
        safe(function()
            state.labels.status.Text = message
        end)
    end
end

local function getScanPool()
    local dabbanFolder = safe(function()
        return workspace:FindFirstChild("Dabban")
    end)

    if dabbanFolder then
        return dabbanFolder:GetDescendants()
    end

    return workspace:GetDescendants()
end

local function scan()
    if not state.enabled then
        return
    end

    local objects = safe(getScanPool)
    if not objects then
        setStatus("Workspace scan unavailable")
        return
    end

    local found = {}

    for _, obj in ipairs(objects) do
        local objName = safe(function()
            return obj.Name
        end)

        if type(objName) == "string" then
            local named = state.scanNames and matchName(objName)
            local price = state.scanPrices and getPrice(obj) or nil
            local expensive = price and price >= state.priceMin

            if named or expensive then
                found[obj] = true

                local labelText = objName
                if price then
                    labelText = objName .. " | " .. tostring(price)
                end

                applyEsp(obj, labelText)

                if not state.seen[obj] and state.alerts then
                    setStatus("Found: " .. labelText)
                end
            end
        end
    end

    for oldObj in pairs(state.seen) do
        if not found[oldObj] then
            clearEsp(oldObj)
        end
    end

    state.seen = found
end

local function toggle()
    state.enabled = not state.enabled

    if state.enabled then
        setStatus("ON | scanning rare / priced objects")
        showTopMessage("اشتغل", Color3.fromRGB(35, 120, 55))
        scan()
    else
        for obj in pairs(state.espItems) do
            clearEsp(obj)
        end
        state.seen = {}
        setStatus("OFF | press L")
        showTopMessage("وقف", Color3.fromRGB(140, 45, 45))
    end
end

local function cleanup()
    state.alive = false
    state.enabled = false

    for _, conn in ipairs(state.conns) do
        safe(function()
            conn:Disconnect()
        end)
    end

    for obj in pairs(state.espItems) do
        clearEsp(obj)
    end

    if state.gui then
        safe(function()
            state.gui:Destroy()
        end)
    end

    if state.noticeGui then
        safe(function()
            state.noticeGui:Destroy()
        end)
    end

    log("Unloaded")
end

env.parl0vHubCleanup = cleanup
env.parl0vToggle = toggle
env.parl0vStart = function()
    if not state.enabled then
        toggle()
    end
end
env.parl0vStop = function()
    if state.enabled then
        toggle()
    end
end

local inputConn = safe(function()
    return UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.L then
            toggle()
        end
    end)
end)

if inputConn then
    table.insert(state.conns, inputConn)
end

local function createGui()
    local player = Players.LocalPlayer
    if not player then
        return
    end

    local parent = player:WaitForChild("PlayerGui", 5)
    if not parent then
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MatchaMenu"
    gui.ResetOnSpawn = false
    gui.Parent = parent
    state.gui = gui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 310, 0, 360)
    panel.Position = UDim2.new(0, 24, 0.5, -180)
    panel.BackgroundColor3 = Color3.fromRGB(26, 29, 37)
    panel.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = panel

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.PaddingLeft = UDim.new(0, 8)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = panel

    local function label(text, height)
        local x = Instance.new("TextLabel")
        x.Size = UDim2.new(1, -16, 0, height or 30)
        x.BackgroundTransparency = 1
        x.TextColor3 = Color3.new(1, 1, 1)
        x.Font = Enum.Font.Gotham
        x.TextSize = 13
        x.TextWrapped = true
        x.Text = text
        x.Parent = panel
        return x
    end

    local function button(text, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -18, 0, 34)
        b.BackgroundColor3 = Color3.fromRGB(53, 62, 82)
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.Text = text
        b.Parent = panel
        b.MouseButton1Click:Connect(callback)
        return b
    end

    label("Matcha | Rare Scanner", 35)
    state.labels.status = label("OFF | Press L to toggle", 35)

    button("START / STOP [L]", toggle)

    button("Rare Names: ON/OFF", function()
        state.scanNames = not state.scanNames
        setStatus("Rare names: " .. tostring(state.scanNames))
    end)

    button("Price > 100000: ON/OFF", function()
        state.scanPrices = not state.scanPrices
        setStatus("Price filter: " .. tostring(state.scanPrices))
    end)

    button("ESP: ON/OFF", function()
        state.esp = not state.esp
        if not state.esp then
            for obj in pairs(state.espItems) do
                clearEsp(obj)
            end
        else
            scan()
        end
        setStatus("ESP: " .. tostring(state.esp))
    end)

    button("Alerts: ON/OFF", function()
        state.alerts = not state.alerts
        setStatus("Alerts: " .. tostring(state.alerts))
    end)

    label("Scans visible names and explicit prices only.", 35)

    button("CLOSE MENU", function()
        gui.Enabled = false
    end)
end

safe(createGui)

task.spawn(function()
    while state.alive do
        task.wait(3)
        if state.enabled then
            scan()
        end
    end
end)

showTopMessage("اشتغل", Color3.fromRGB(35, 120, 55))
log("Loaded | L toggles ON/OFF | starts OFF")
