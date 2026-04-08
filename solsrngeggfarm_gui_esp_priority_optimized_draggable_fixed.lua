
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local initPathAgent

local function log(msg)
    print(string.format("[EggFarm %s] %s", os.date("%H:%M:%S"), msg))
end

player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    task.wait(1)
    if initPathAgent then
        initPathAgent()
    end
end)

local SETTINGS = {
    SEARCH_INTERVAL = 0.35,
    PROMPT_DISTANCE = 3,
    PATH_RECOMPUTE_MAX = 5,
    WALK_SPEED_BOOST = 0,
    MAX_EGG_HEIGHT = 130,
    ESP_MAX_DISTANCE = 99999,
    ESP_UPDATE_INTERVAL = 0.2,
    SAFETY_RESCAN_INTERVAL = 8,
    BLOCKED_REPATH_COOLDOWN = 0.35,
    ERROR_REPATH_COOLDOWN = 0.35,
}

local STATE = {
    running = false,
    eggsCollected = 0,
    potionEggsCollected = 0,
    pointEggsCollected = 0,
    auraEggsCollected = 0,
    currentEggInstance = nil,
}

local GUI = {
    screenGui = nil,
    statusLabel = nil,
    potionCountLabel = nil,
    pointCountLabel = nil,
    auraCountLabel = nil,
    startButton = nil,
    stopButton = nil,
}

local startFarm, stopFarm

local function getGuiParent()
    local ok, result = pcall(function()
        if gethui then
            return gethui()
        end
        local CoreGui = game:GetService("CoreGui")
        if CoreGui then
            return CoreGui
        end
    end)

    if ok and result then
        return result
    end

    local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
    return playerGui
end

local function updateGui()
    if GUI.statusLabel then
        GUI.statusLabel.Text = STATE.running and "Status: Running" or "Status: Stopped"
        GUI.statusLabel.TextColor3 = STATE.running and Color3.fromRGB(0, 255, 85) or Color3.fromRGB(255, 80, 80)
    end

    if GUI.potionCountLabel then
        GUI.potionCountLabel.Text = "Potion Eggs Collected: " .. tostring(STATE.potionEggsCollected)
    end

    if GUI.pointCountLabel then
        GUI.pointCountLabel.Text = "Point Eggs Collected: " .. tostring(STATE.pointEggsCollected)
    end

    if GUI.auraCountLabel then
        GUI.auraCountLabel.Text = "Aura Eggs Collected: " .. tostring(STATE.auraEggsCollected)
    end

    if GUI.startButton then
        GUI.startButton.Active = not STATE.running
        GUI.startButton.AutoButtonColor = not STATE.running
        GUI.startButton.BackgroundColor3 = STATE.running and Color3.fromRGB(36, 120, 36) or Color3.fromRGB(0, 200, 40)
    end

    if GUI.stopButton then
        GUI.stopButton.Active = STATE.running
        GUI.stopButton.AutoButtonColor = STATE.running
        GUI.stopButton.BackgroundColor3 = STATE.running and Color3.fromRGB(220, 0, 0) or Color3.fromRGB(120, 36, 36)
    end
end

local function makeButton(parent, text, color, position)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 126, 0, 44)
    button.Position = position
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamBold
    button.TextScaled = false
    button.TextSize = 16
    button.Text = text
    button.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button

    return button
end

local function makeInfoLabel(parent, text, color, y, size)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, y)
    label.Size = UDim2.new(1, -24, 0, (size or 18) + 4)
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = false
    label.TextSize = size or 18
    label.TextWrapped = false
    label.Text = text
    label.Parent = parent
    return label
end

local function createGui()
    pcall(function()
        if GUI.screenGui then
            GUI.screenGui:Destroy()
        end
    end)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EggFarmGui"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = getGuiParent()

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Position = UDim2.new(0, 18, 0, 100)
    frame.Size = UDim2.new(0, 260, 0, 200)
    frame.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    frame.BackgroundTransparency = 0.12
    frame.Parent = screenGui

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 70)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.15
    stroke.Parent = frame

    local title = makeInfoLabel(frame, "Egg Farm GUI", Color3.new(1, 1, 1), 8, 20)
    title.Size = UDim2.new(1, -24, 0, 24)

    GUI.statusLabel = makeInfoLabel(frame, "Status: Stopped", Color3.fromRGB(255, 80, 80), 34, 18)
    GUI.potionCountLabel = makeInfoLabel(frame, "Potion Eggs Collected: 0", Color3.new(1, 1, 1), 64, 15)
    GUI.pointCountLabel = makeInfoLabel(frame, "Point Eggs Collected: 0", Color3.new(1, 1, 1), 88, 15)
    GUI.auraCountLabel = makeInfoLabel(frame, "Aura Eggs Collected: 0", Color3.new(1, 1, 1), 112, 15)

    GUI.startButton = makeButton(frame, "START FARM", Color3.fromRGB(0, 200, 40), UDim2.new(0, 14, 1, -52))
    GUI.stopButton = makeButton(frame, "STOP FARM", Color3.fromRGB(220, 0, 0), UDim2.new(1, -118, 1, -52))

    GUI.mainFrame = frame

    GUI.startButton.Size = UDim2.new(0, 104, 0, 36)
    GUI.stopButton.Size = UDim2.new(0, 104, 0, 36)

    local dragging = false
    local dragStart
    local startPos
    local dragInput

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart and startPos then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    GUI.startButton.MouseButton1Click:Connect(function()
        if startFarm then
            startFarm()
        end
    end)

    GUI.stopButton.MouseButton1Click:Connect(function()
        if stopFarm then
            stopFarm()
        end
    end)

    GUI.screenGui = screenGui
    updateGui()
end

local ignoredEggs = setmetatable({}, { __mode = "k" })
local eggEspObjects = setmetatable({}, { __mode = "k" })
local trackedEggs = setmetatable({}, { __mode = "k" })
local consumedEggs = setmetatable({}, { __mode = "k" })

LogService.MessageOut:Connect(function(message)
    if message:match("Invalid egg") and STATE.currentEggInstance then
        ignoredEggs[STATE.currentEggInstance] = true
    end
end)

local PRIORITY_EGGS = {
    andromeda_egg = true,
    angelic_egg = true,
    blooming_egg = true,
    dreamer_egg = true,
    egg_v2 = true,
    forest_egg = true,
    hatch_egg = true,
    royal_egg = true,
    the_egg_of_the_sky = true,
}

local EGG_PATTERNS = {
    "^point_egg_%d+$",
    "^random_potion_egg_%d+$",
}

local EXCLUDED_ZONES = {
    { center = Vector3.new(55.676, 102.85, -594.476), radius = 100 },
    { center = Vector3.new(-50.29, 95.5, -102.54), radius = 80 },
    { center = Vector3.new(16.326, 93.75, -438.988), radius = 20 },
}

local function isEggName(name)
    if PRIORITY_EGGS[name] then
        return true
    end

    for _, pattern in ipairs(EGG_PATTERNS) do
        if string.match(name, pattern) then
            return true
        end
    end
    return false
end

local function getEggPriority(name)
    if PRIORITY_EGGS[name] then
        return 0
    elseif string.match(name, "^random_potion_egg_%d+$") then
        return 1
    elseif string.match(name, "^point_egg_%d+$") then
        return 2
    end
    return 3
end

local function getEggPart(obj)
    if not obj or not obj.Parent then
        return nil
    end

    if obj:IsA("BasePart") then
        return obj
    elseif obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function isEggAllowedPosition(pos)
    if pos.Y > SETTINGS.MAX_EGG_HEIGHT then
        return false
    end

    for _, zone in ipairs(EXCLUDED_ZONES) do
        if (pos - zone.center).Magnitude <= zone.radius then
            return false
        end
    end

    return true
end

local function isValidEggInstance(obj)
    if not obj or not obj.Parent or not isEggName(obj.Name) or ignoredEggs[obj] or consumedEggs[obj] then
        return false
    end

    local part = getEggPart(obj)
    if not part then
        return false
    end

    return isEggAllowedPosition(part.Position)
end

local function distanceTo(pos)
    if not rootPart or not rootPart.Parent then
        return math.huge
    end
    return (rootPart.Position - pos).Magnitude
end

local function getEggEspColor(name)
    if PRIORITY_EGGS[name] then
        return Color3.fromRGB(255, 90, 200)
    elseif string.match(name, "^random_potion_egg_%d+$") then
        return Color3.fromRGB(90, 220, 255)
    elseif string.match(name, "^point_egg_%d+$") then
        return Color3.fromRGB(255, 215, 90)
    end
    return Color3.fromRGB(255, 255, 255)
end

local function removeEggEsp(egg)
    local esp = eggEspObjects[egg]
    if not esp then
        return
    end

    if esp.highlight then
        esp.highlight:Destroy()
    end

    if esp.billboard then
        esp.billboard:Destroy()
    end

    eggEspObjects[egg] = nil
end

local function unregisterEgg(egg)
    trackedEggs[egg] = nil
    removeEggEsp(egg)
end

local function createEggEsp(egg)
    if eggEspObjects[egg] or not isValidEggInstance(egg) then
        return
    end

    local part = getEggPart(egg)
    if not part then
        return
    end

    local color = getEggEspColor(egg.Name)

    local highlight = Instance.new("Highlight")
    highlight.Name = "EggFarmESP"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.Adornee = egg
    highlight.Parent = egg

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "EggFarmDistance"
    billboard.Adornee = part
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 180, 0, 46)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.MaxDistance = SETTINGS.ESP_MAX_DISTANCE
    billboard.Parent = egg

    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "DistanceLabel"
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.fromScale(1, 1)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextScaled = true
    textLabel.TextStrokeTransparency = 0.35
    textLabel.TextColor3 = color
    textLabel.Text = egg.Name
    textLabel.Parent = billboard

    eggEspObjects[egg] = {
        highlight = highlight,
        billboard = billboard,
        textLabel = textLabel,
    }
end

local function registerEgg(egg)
    if trackedEggs[egg] or not isValidEggInstance(egg) then
        return
    end
    trackedEggs[egg] = true
    createEggEsp(egg)
end

local function fullEggRescan()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if isValidEggInstance(obj) then
            registerEgg(obj)
        end
    end
end

local function findAllEggs()
    local eggs = {}

    for egg in pairs(trackedEggs) do
        if isValidEggInstance(egg) then
            local part = getEggPart(egg)
            if part then
                table.insert(eggs, {
                    instance = egg,
                    part = part,
                    position = part.Position,
                    prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true),
                    name = egg.Name,
                    priority = getEggPriority(egg.Name),
                })
            end
        else
            unregisterEgg(egg)
        end
    end

    table.sort(eggs, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return distanceTo(a.position) < distanceTo(b.position)
    end)

    return eggs
end

local function fireProximityPromptSafe(prompt)
    if not prompt or not prompt.Parent then
        return false
    end

    if fireproximityprompt then
        fireproximityprompt(prompt)
        return true
    end

    local oldHold = prompt.HoldDuration
    local oldDist = prompt.MaxActivationDistance

    prompt.MaxActivationDistance = 9999
    prompt.HoldDuration = 0
    prompt:InputHoldBegin()
    task.wait(0.1)
    prompt:InputHoldEnd()
    prompt.HoldDuration = oldHold
    prompt.MaxActivationDistance = oldDist

    return true
end

local function collectEgg(egg)
    if not egg or not egg.instance or consumedEggs[egg.instance] then
        return false
    end

    local prompt = egg.prompt or egg.instance:FindFirstChildWhichIsA("ProximityPrompt", true)

    if prompt then
        fireProximityPromptSafe(prompt)
        task.wait(0.15)
    else
        if VirtualInputManager then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.06)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
        task.wait(0.15)
    end

    if consumedEggs[egg.instance] then
        return false
    end

    consumedEggs[egg.instance] = true
    unregisterEgg(egg.instance)

    STATE.eggsCollected = STATE.eggsCollected + 1
    if egg.priority == 0 then
        STATE.auraEggsCollected = STATE.auraEggsCollected + 1
    elseif string.match(egg.name, "^random_potion_egg_%d+$") then
        STATE.potionEggsCollected = STATE.potionEggsCollected + 1
    elseif string.match(egg.name, "^point_egg_%d+$") then
        STATE.pointEggsCollected = STATE.pointEggsCollected + 1
    end
    updateGui()
    log("Collected: " .. egg.name .. " | total=" .. STATE.eggsCollected)
    return true
end

local SimplePath
local ok, err = pcall(function()
    SimplePath = loadstring(game:HttpGet("https://raw.githubusercontent.com/grayzcale/simplepath/main/src/SimplePath.lua"))()
end)

if not ok or not SimplePath then
    warn("[EggFarm] Failed to load SimplePath: " .. tostring(err))
    return
end

local pathAgent

initPathAgent = function()
    if pathAgent then
        pcall(function()
            pathAgent:Destroy()
        end)
    end

    if not character or not character.Parent then
        return
    end

    pathAgent = SimplePath.new(character, {
        AgentRadius = 3,
        AgentHeight = 5.5,
        AgentCanJump = true,
        AgentCanClimb = true,
        AgentJumpHeight = 7.2,
        WaypointSpacing = 3,
        Costs = { Water = 100, Climb = 1 },
    })
end

initPathAgent()

local mapFixed = false
local function fixMapGeometry()
    if mapFixed then
        return
    end
    mapFixed = true

    local map = workspace:FindFirstChild("Map")
    local leafygrass = map and map:FindFirstChild("leafygrass")
    if not leafygrass then
        return
    end

    log("Geometry patch enabled")

    local extensionDown = 25
    for _, obj in ipairs(leafygrass:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name ~= "PathBlocker" then
            local blocker = Instance.new("Part")
            blocker.Name = "PathBlocker"
            blocker.Size = Vector3.new(obj.Size.X, extensionDown, obj.Size.Z)
            blocker.CFrame = obj.CFrame * CFrame.new(0, -(obj.Size.Y / 2 + extensionDown / 2), 0)
            blocker.Anchored = true
            blocker.CanCollide = true
            blocker.Transparency = 1
            blocker.Parent = obj
        end
    end
end

local function stopPathing()
    if pathAgent then
        pcall(function()
            pathAgent:Stop()
        end)
    end
end

local function moveToEgg(egg)
    if not STATE.running then
        return false
    end
    if not rootPart or not rootPart.Parent or not humanoid or humanoid.Health <= 0 then
        return false
    end
    if not egg.part or not egg.part.Parent then
        return false
    end

    STATE.currentEggInstance = egg.instance
    if egg.priority == 0 then
        log("Walking to PRIORITY egg: " .. egg.name)
    else
        log("Walking to: " .. egg.name)
    end

    if SETTINGS.WALK_SPEED_BOOST > 0 then
        humanoid.WalkSpeed = SETTINGS.WALK_SPEED_BOOST
    end

    local maxErrors = SETTINGS.PATH_RECOMPUTE_MAX * 3
    local errors = 0
    local reached = false
    local lastBlockedRepath = 0
    local lastErrorRepath = 0

    local conReached
    local conBlocked
    local conError
    local conWaypoint

    local function cleanup()
        if conReached then conReached:Disconnect() end
        if conBlocked then conBlocked:Disconnect() end
        if conError then conError:Disconnect() end
        if conWaypoint then conWaypoint:Disconnect() end
        stopPathing()
    end

    conReached = pathAgent.Reached:Connect(function()
        reached = true
    end)

    conBlocked = pathAgent.Blocked:Connect(function()
        local now = os.clock()
        if now - lastBlockedRepath < SETTINGS.BLOCKED_REPATH_COOLDOWN then
            return
        end
        lastBlockedRepath = now
        pcall(function()
            pathAgent:Run(egg.part.Position)
        end)
    end)

    conError = pathAgent.Error:Connect(function()
        local now = os.clock()
        if now - lastErrorRepath < SETTINGS.ERROR_REPATH_COOLDOWN then
            return
        end
        lastErrorRepath = now
        errors = errors + 1
        if humanoid and rootPart then
            humanoid.Jump = true
            humanoid:MoveTo(rootPart.Position + rootPart.CFrame.RightVector * math.random(-4, 4))
        end
        task.wait(0.1)
        pcall(function()
            pathAgent:Run(egg.part.Position)
        end)
    end)

    conWaypoint = pathAgent.WaypointReached:Connect(function()
        if egg.part and egg.part.Parent and distanceTo(egg.part.Position) <= SETTINGS.PROMPT_DISTANCE then
            reached = true
        end
    end)

    pcall(function()
        pathAgent:Run(egg.part.Position)
    end)

    local lastPos = rootPart.Position
    local timeStuck = 0

    while STATE.running and not reached do
        if not egg.part or not egg.part.Parent then
            log("Egg disappeared: " .. egg.name)
            break
        end

        local dist = distanceTo(egg.part.Position)
        if dist <= SETTINGS.PROMPT_DISTANCE then
            reached = true
            break
        end

        if errors > maxErrors then
            log("Too many path errors, skipping: " .. egg.name)
            break
        end

        local currentPos = rootPart.Position
        local deltaMove = (currentPos - lastPos).Magnitude

        if deltaMove < 0.2 then
            timeStuck = timeStuck + 0.1
            if timeStuck > 1.2 then
                humanoid.Jump = true
                humanoid:MoveTo(currentPos + rootPart.CFrame.RightVector * math.random(-5, 5) - rootPart.CFrame.LookVector * 2)
                errors = errors + 1
                task.wait(0.2)
                pcall(function()
                    pathAgent:Run(egg.part.Position)
                end)
                timeStuck = 0
            end
        else
            timeStuck = 0
        end

        lastPos = currentPos
        task.wait(0.1)
    end

    cleanup()

    if not STATE.running then
        return false
    end

    if egg.part and egg.part.Parent and distanceTo(egg.part.Position) <= SETTINGS.PROMPT_DISTANCE then
        collectEgg(egg)
        return true
    end

    log("Failed to reach: " .. egg.name)
    return false
end

local farmThread

local function farmLoop()
    fixMapGeometry()
    log("Farm started")

    while STATE.running do
        local eggs = findAllEggs()

        if #eggs == 0 then
            task.wait(SETTINGS.SEARCH_INTERVAL)
        else
            for _, egg in ipairs(eggs) do
                if not STATE.running then
                    break
                end
                if egg.part and egg.part.Parent then
                    moveToEgg(egg)
                    task.wait(0.08)
                end
            end
            task.wait(SETTINGS.SEARCH_INTERVAL)
        end
    end

    stopPathing()
    STATE.currentEggInstance = nil
    log("Farm stopped")
    updateGui()
    farmThread = nil
end

startFarm = function()
    if STATE.running then
        log("Farm is already running")
        return
    end

    STATE.running = true
    updateGui()
    farmThread = task.spawn(farmLoop)
end

stopFarm = function()
    if not STATE.running then
        log("Farm is already stopped")
        return
    end

    STATE.running = false
    stopPathing()
    updateGui()
end

local function normalizeMessage(msg)
    msg = tostring(msg or ""):lower()
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    msg = msg:gsub("%s+", " ")
    return msg
end

local function handleCommand(msg)
    local text = normalizeMessage(msg)

    if text == "/e farm on" or text == "/emote farm on" or text == "farm on" then
        startFarm()
    elseif text == "/e farm off" or text == "/emote farm off" or text == "farm off" then
        stopFarm()
    end
end

createGui()

player.Chatted:Connect(handleCommand)

workspace.DescendantAdded:Connect(function(obj)
    if isEggName(obj.Name) then
        task.defer(function()
            if isValidEggInstance(obj) then
                registerEgg(obj)
            end
        end)
    end
end)

workspace.DescendantRemoving:Connect(function(obj)
    if trackedEggs[obj] or eggEspObjects[obj] then
        unregisterEgg(obj)
    end
end)

RunService.Heartbeat:Connect(function()
    -- keep root references fresh after odd respawn edge cases
    if character and character.Parent and (not rootPart or not rootPart.Parent) then
        rootPart = character:FindFirstChild("HumanoidRootPart") or rootPart
    end
end)

task.spawn(function()
    while true do
        for egg, esp in pairs(eggEspObjects) do
            if not isValidEggInstance(egg) then
                unregisterEgg(egg)
            else
                local currentPart = getEggPart(egg)
                if not currentPart then
                    unregisterEgg(egg)
                else
                    if esp.billboard and esp.billboard.Adornee ~= currentPart then
                        esp.billboard.Adornee = currentPart
                    end
                    local dist = distanceTo(currentPart.Position)
                    if dist == math.huge then
                        esp.textLabel.Text = string.format("%s\n--", egg.Name)
                    else
                        esp.textLabel.Text = string.format("%s\n%.1f studs", egg.Name, dist)
                    end
                end
            end
        end
        task.wait(SETTINGS.ESP_UPDATE_INTERVAL)
    end
end)

task.spawn(function()
    while true do
        fullEggRescan()
        task.wait(SETTINGS.SAFETY_RESCAN_INTERVAL)
    end
end)

fullEggRescan()
log("Loaded. Use GUI buttons or type /e farm on and /e farm off. Egg ESP is always enabled. Optimized cache mode enabled.")
