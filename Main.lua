-- Venice Aim/ESP - fichier .lua
repeat wait() until game:IsLoaded()
local plrs = game:GetService("Players")
local plr = plrs.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Teams = game:GetService("Teams")
local Camera = workspace.CurrentCamera
local mouse = plr:GetMouse()
local Drawing = Drawing or (pcall(function() return Drawing.new("Line") end) and Drawing or nil)

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Settings = {
    Silent = false, FOV = 150, FOVVisible = false, Method = "auto",
    TargetPart = "Head", VisibleCheck = false, FilterMode = "Ennemis",
    SelectedTeams = {}, Box = true, FullBox = false, Skeleton = true,
    Tracers = true, Health = true, Meters = true, ESP = true,
}

local Window = Library:CreateWindow({ Title = 'Venice Aim/ESP', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
local Tabs = { Combat = Window:AddTab('Combat'), Visuals = Window:AddTab('Visuals'), ['UI Settings'] = Window:AddTab('UI Settings') }
local Silent = Tabs.Combat:AddLeftGroupbox('Silent Aim')
local EspBox = Tabs.Visuals:AddLeftGroupbox('ESP')
local Filter = Tabs.Visuals:AddRightGroupbox('Filtre')

-- ===== FILTRE =====
local function teamList()
    local t = {}
    for _, team in ipairs(Teams:GetTeams()) do t[#t+1] = team.Name end
    return (#t > 0) and t or { "Aucune" }
end

local function passes(p)
    if p == plr then return false end
    if Settings.FilterMode == "Tous" then return true end
    if Settings.FilterMode == "Ennemis" then return p.Team ~= plr.Team end
    return p.Team and Settings.SelectedTeams[p.Team.Name] == true
end

local teamDropdown
local function refreshTeams()
    if teamDropdown then pcall(function() teamDropdown:SetValues(teamList()) end) end
end

Filter:AddDropdown('Mode', {
    Values = { 'Tous', 'Ennemis', 'Teams' }, Default = 'Ennemis', Multi = false, Text = 'Mode de filtre',
    Callback = function(v) Settings.FilterMode = v end
})

teamDropdown = Filter:AddDropdown('TeamsSel', {
    Values = teamList(), Default = 1, Multi = true, Text = 'Teams',
    Callback = function(v)
        Settings.SelectedTeams = {}
        for name, on in pairs(v) do if on then Settings.SelectedTeams[name] = true end end
    end
})

Teams.ChildAdded:Connect(refreshTeams)
Teams.ChildRemoved:Connect(refreshTeams)
plrs.PlayerAdded:Connect(function(p)
    p:GetPropertyChangedSignal("Team"):Connect(function() end) -- rescan à la frame
end)

-- ===== CIBLE =====
local ValidParts = {"Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso"}
local function visible(p)
    local char, lchar = p.Character, plr.Character
    if not char or not lchar then return false end
    local root = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local parts = Camera:GetPartsObscuringTarget({root.Position, lchar, char}, {lchar, char})
    return #parts == 0
end

local function closest()
    local best, bestD
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in ipairs(plrs:GetPlayers()) do
        if passes(p) then
            local char = p.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local part = char:FindFirstChild(Settings.TargetPart == "Random" and ValidParts[math.random(#ValidParts)] or Settings.TargetPart)
                if part and hum and hum.Health > 0 then
                    if not Settings.VisibleCheck or visible(p) then
                        local sp, on = Camera:WorldToViewportPoint(part.Position)
                        if on then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if d <= Settings.FOV and d < (bestD or math.huge) then best, bestD = part, d end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ===== SILENT AIM (auto) =====
local function dir(o, t) return (t - o).Unit * (t - o).Magnitude end
local workingMethod
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local method = getnamecallmethod()
    local Args = {...}
    local self = Args[1]
    if Settings.Silent and self == workspace and not checkcaller() then
        local t = closest()
        if t then
            if Settings.Method == "auto" then workingMethod = workingMethod or method end
            if method == (Settings.Method == "auto" and workingMethod or Settings.Method) then
                if method == "Raycast" then Args[3] = dir(Args[2], t.Position)
                else local ray = Args[2]; if ray then Args[2] = Ray.new(ray.Origin, dir(ray.Origin, t.Position)) end end
                return OldNamecall(unpack(Args))
            end
        end
    end
    return OldNamecall(...)
end))

Silent:AddToggle('SilentOn', { Text = 'Silent Aim', Default = false, Callback = function(v) Settings.Silent = v end })
    :AddKeyPicker('SilentKey', { Default = 'G', SyncToggleState = true, Mode = 'Toggle', Text = 'Silent Aim', NoUI = false })
Silent:AddSlider('Fov', { Text = 'FOV', Default = 150, Min = 10, Max = 800, Rounding = 0, Compact = false, Callback = function(v) Settings.FOV = v end })
Silent:AddToggle('FovVis', { Text = 'Afficher le FOV', Default = false, Callback = function(v) Settings.FOVVisible = v end })
Silent:AddDropdown('Part', { Values = { 'Random', 'Head', 'HumanoidRootPart', 'Torso', 'UpperTorso', 'LowerTorso' }, Default = 'Head', Multi = false, Text = 'Part visée', Callback = function(v) Settings.TargetPart = v end })
Silent:AddToggle('Vis', { Text = 'Visible Check', Default = false, Callback = function(v) Settings.VisibleCheck = v end })

-- ===== ESP UI =====
EspBox:AddToggle('EspOn', { Text = 'ESP', Default = true, Callback = function(v) Settings.ESP = v end })
EspBox:AddToggle('B', { Text = 'Box', Default = true, Callback = function(v) Settings.Box = v end })
EspBox:AddToggle('FB', { Text = 'Full box', Default = false, Callback = function(v) Settings.FullBox = v end })
EspBox:AddToggle('Sk', { Text = 'Skeleton', Default = true, Callback = function(v) Settings.Skeleton = v end })
EspBox:AddToggle('Tr', { Text = 'Tracers', Default = true, Callback = function(v) Settings.Tracers = v end })
EspBox:AddToggle('Hp', { Text = 'Health', Default = true, Callback = function(v) Settings.Health = v end })
EspBox:AddToggle('Mt', { Text = 'Meters', Default = true, Callback = function(v) Settings.Meters = v end })

-- ===== ESP RENDER =====
local espData = {}
local function newEsp()
    local t = { box = Drawing.new("Square"), full = Drawing.new("Square"), name = Drawing.new("Text"), hp = Drawing.new("Square"), meters = Drawing.new("Text"), sk