function missing(t, f, fallback)
    if type(f) == t then return f end
    return fallback
end
queueteleport =  missing("function", queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport))
waxwritefile = writefile
writefile = missing("function", waxwritefile) and function(file, data, safe)
    if safe == true then return pcall(waxwritefile, file, data) end
    waxwritefile(file, data)
end
isfolder = missing("function", isfolder)
makefolder = missing("function", makefolder)

local MacLib = loadstring(game:HttpGet("https://github.com/biggaboy212/Maclib/releases/latest/download/maclib.txt"))()
local Window = MacLib:Window({
	Title = "Haru Demo",
	Subtitle = "This is a subtitle.",
	Size = UDim2.fromOffset(868, 650),
	DragStyle = 1,
	DisabledWindowControls = {},
	ShowUserInfo = true,
	Keybind = Enum.KeyCode.LeftAlt,
	AcrylicBlur = true,
})
local globalSettings = {
	UIBlurToggle = Window:GlobalSetting({
		Name = "UI Blur",
		Default = Window:GetAcrylicBlurState(),
		Callback = function(bool)
			Window:SetAcrylicBlurState(bool)
			Window:Notify({
				Title = Window.Settings.Title,
				Description = (bool and "Enabled" or "Disabled") .. " UI Blur",
				Lifetime = 5
			})
		end,
	}),
	NotificationToggler = Window:GlobalSetting({
		Name = "Notifications",
		Default = Window:GetNotificationsState(),
		Callback = function(bool)
			Window:SetNotificationsState(bool)
			Window:Notify({
				Title = Window.Settings.Title,
				Description = (bool and "Enabled" or "Disabled") .. " Notifications",
				Lifetime = 5
			})
		end,
	}),
	ShowUserInfo = Window:GlobalSetting({
		Name = "Show User Info",
		Default = Window:GetUserInfoState(),
		Callback = function(bool)
			Window:SetUserInfoState(bool)
			Window:Notify({
				Title = Window.Settings.Title,
				Description = (bool and "Showing" or "Redacted") .. " User Info",
				Lifetime = 5
			})
		end,
	})
}
local tabGroups = {TabGroup1 = Window:TabGroup()}
local tabs = {
	Main = tabGroups.TabGroup1:Tab({ Name = "Mainfarm", Image = "rbxassetid://18821914323" }),
	Champions = tabGroups.TabGroup1:Tab({ Name = "Champions", Image = "rbxassetid://88238578565569" }),
	Teleport = tabGroups.TabGroup1:Tab({ Name = "Teleport", Image = "rbxassetid://121700697298748" }),
	
	Settings = tabGroups.TabGroup1:Tab({ Name = "Settings", Image = "rbxassetid://71732494649961" })
}


_G.SelectedMobs = {}
_G.TargetingLogic = "distance"
_G.SequentialNextIndex = 1
_G.FarmMode = "Normal [🟢]"
_G.TargetPlayerID = ""
_G.CopyAppearance = false
_G.AutoFarm = false
_G.AutoQuestEnabled = false 

local sections = {
    MainSection1 = tabs.Main:Section({ Side = "Left" }),
    MainSection2 = tabs.Main:Section({ Side = "Right" }),
	MainSection3 = tabs.Main:Section({ Side = "Right" }),

	-------------

	MainSection4 = tabs.Champions:Section({ Side = "Left" }),

	MainSection5 = tabs.Settings:Section({ Side = "Right" }),
	SettingsSectionLeft = tabs.Settings:Section({ Side = "Left" })

}




local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer


local function simplifyName(str)
    if not str or type(str) ~= "string" then return "" end
    
    return str:lower():gsub("%s+", ""):gsub("[^a-z0-9]", "")
end


local monsterCache = {}
local monstersFolder = Workspace.Debris.Monsters
for _, monster in ipairs(monstersFolder:GetChildren()) do
    monsterCache[monster] = true
end
monstersFolder.ChildAdded:Connect(function(child)
    monsterCache[child] = true
end)
monstersFolder.ChildRemoved:Connect(function(child)
    monsterCache[child] = nil
end)









sections.MainSection1:Header({Name = "Autofarm"})
local player = game:GetService("Players").LocalPlayer
local runService = game:GetService("RunService")
local function ApplyAppearance(character, targetPlayerID)
    if not character or not tonumber(targetPlayerID) then
        Window:Notify({ Title = "Appearance Error", Description = "Invalid character or Player ID.", Lifetime = 4 })
        return
    end
    local success, appearanceModel = pcall(function()
        return game.Players:GetCharacterAppearanceAsync(tonumber(targetPlayerID))
    end)
    if success and appearanceModel then
        for _, v in pairs(character:GetChildren()) do
            if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("BodyColors") then
                v:Destroy()
            end
        end
        for _, asset in pairs(appearanceModel:GetChildren()) do
            if asset:IsA("Accessory") or asset:IsA("Shirt") or asset:IsA("Pants") or asset:IsA("ShirtGraphic") or asset:IsA("BodyColors") then
                asset.Parent = character
            end
        end
        Window:Notify({ Title = "Appearance", Description = "Applied skin from ID: " .. targetPlayerID, Lifetime = 4 })
    else
        Window:Notify({ Title = "Appearance Error", Description = "Failed to get skin for ID: " .. targetPlayerID, Lifetime = 4 })
    end
end
local silentFarmState = {
    isActive = false,
    realChar = nil,
    clone = nil,
    originalCFrame = nil,
    originalWalkSpeed = 16,
    originalJumpPower = 50
}
local DisableSilentFarm
local function EnableSilentFarm()
    if silentFarmState.isActive or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
    local originalChar = player.Character
    local humanoid = originalChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    silentFarmState.realChar = originalChar
    silentFarmState.originalCFrame = originalChar:GetPrimaryPartCFrame()
    silentFarmState.originalWalkSpeed = humanoid.WalkSpeed
    silentFarmState.originalJumpPower = humanoid.JumpPower
    if originalChar:FindFirstChild("HumanoidRootPart") then
        originalChar.HumanoidRootPart.Anchored = true
    end
    originalChar.Archivable = true
    local cloneChar = originalChar:Clone()
    originalChar.Archivable = false
    if _G.CopyAppearance and tonumber(_G.TargetPlayerID) then
        ApplyAppearance(cloneChar, _G.TargetPlayerID)
    end
    silentFarmState.clone = cloneChar
    cloneChar.Name = "HaruSilentClone"
    for _, part in pairs(cloneChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
        end
    end
    cloneChar:SetPrimaryPartCFrame(silentFarmState.originalCFrame)
    for _, part in pairs(originalChar:GetDescendants()) do
        if part:isA("BasePart") or part:isA("Decal") then
            part.LocalTransparencyModifier = 1.0
        end
    end
    player.Character = cloneChar
    cloneChar.Parent = workspace
    silentFarmState.isActive = true
    Window:Notify({ Title = "Silent Farm", Description = "Enabled & Controllable", Lifetime = 3 })
end
DisableSilentFarm = function()
    if not silentFarmState.isActive then return end
    local realChar = silentFarmState.realChar
    if player.Character == silentFarmState.clone then
        player.Character = realChar
    end
    if silentFarmState.clone and silentFarmState.clone.Parent then
        silentFarmState.clone:Destroy()
        silentFarmState.clone = nil
    end
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    workspace.CurrentCamera.CameraSubject = realChar
    if realChar and realChar.Parent then
        for _, part in pairs(realChar:GetDescendants()) do
            if part:isA("BasePart") or part:isA("Decal") then
                part.LocalTransparencyModifier = 0
            end
        end
        if silentFarmState.originalCFrame then
             realChar:SetPrimaryPartCFrame(silentFarmState.originalCFrame)
        end
        local humanoid = realChar:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = silentFarmState.originalWalkSpeed
            humanoid.JumpPower = silentFarmState.originalJumpPower
            humanoid.Sit = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if realChar:FindFirstChild("HumanoidRootPart") then
            realChar.HumanoidRootPart.Anchored = false
        end
    end
    silentFarmState.isActive = false
    silentFarmState.realChar = nil
    silentFarmState.originalCFrame = nil
    Window:Notify({ Title = "Silent Farm", Description = "Disabled", Lifetime = 3 })
end
local function getQuestMonsterName()
    local monsterName = nil
    local success, result = pcall(function()
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
        local QuestScreen = PlayerGui:WaitForChild("Quests_Screen")
        local QuestSideMenu = QuestScreen:WaitForChild("Quest_Side_Menu")
        local QuestList = QuestSideMenu.Quests.Main.List
        local questItem = QuestList:FindFirstChild("1")

        if questItem and questItem:FindFirstChild("Title") then
            local titleText = questItem.Title.Text
            if titleText:match("Defeat") then
                local rawName = titleText:match("Defeat(.+)")
                if rawName then
                    monsterName = rawName:match("^%s*(.-)%s*$") -- Trim whitespace
                end
            end
        end
    end)
    if not success then
        -- Silently fail as UI may not be present
    end
    return monsterName
end

function GetFinalTarget()
    local monstersFolder = workspace.Debris.Monsters
    local player = game.Players.LocalPlayer
    local char = silentFarmState.isActive and silentFarmState.realChar or player.Character
    if not char then return nil, nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil, nil end

    -- New logic: Prioritize quest monster if AutoQuest is enabled
    if _G.AutoQuestEnabled then
        local questMonsterName = getQuestMonsterName()
        if questMonsterName then
            local simplifiedTarget = simplifyName(questMonsterName)
            if simplifiedTarget ~= "" then
                local closestQuestMob = nil
                local closestDist = math.huge
                for _, monster in ipairs(monstersFolder:GetChildren()) do
                    if monster:FindFirstChild("Humanoid") and monster.Humanoid.Health > 0 then
                        local simplifiedModel = simplifyName(monster.Name)
                        local simplifiedAttribute = simplifyName(tostring(monster:GetAttribute("Title") or ""))
                        if simplifiedTarget == simplifiedModel or simplifiedTarget == simplifiedAttribute then
                            -- Found a matching quest monster, now find the closest one
                            local dist = (monster.HumanoidRootPart.Position - root.Position).Magnitude
                            if dist < closestDist then
                                closestDist = dist
                                closestQuestMob = monster
                            end
                        end
                    end
                end
                if closestQuestMob then
                    return closestQuestMob, nil -- Return the closest quest monster
                end
            end
        end
    end

    -- Fallback to original logic if AutoQuest is off or no quest monster was found
    if not _G.SelectedMobs or #_G.SelectedMobs == 0 then
        return nil, nil
    end

    if _G.TargetingLogic == "distance" then
        local nearestMob = nil
        local closestDist = math.huge
        for _, monsterInstance in pairs(monstersFolder:GetChildren()) do
            if monsterInstance:IsA("Model") and monsterInstance:FindFirstChild("HumanoidRootPart") and monsterInstance:FindFirstChild("Humanoid") and monsterInstance.Humanoid.Health > 0 then
                local title = monsterInstance:GetAttribute("Title")
                if title and table.find(_G.SelectedMobs, title) then
                    local dist = (monsterInstance.HumanoidRootPart.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        nearestMob = monsterInstance
                    end
                end
            end
        end
        return nearestMob, nil
    elseif _G.TargetingLogic == "index" then
        if _G.SequentialNextIndex > #_G.SelectedMobs then _G.SequentialNextIndex = 1 end
        for i = 1, #_G.SelectedMobs do
            local indexToCheck = (_G.SequentialNextIndex - 1 + i - 1) % #_G.SelectedMobs + 1
            local mobNameToFind = _G.SelectedMobs[indexToCheck]
            if mobNameToFind then
                for _, monsterInstance in pairs(monstersFolder:GetChildren()) do
                    if monsterInstance:IsA("Model") and monsterInstance:GetAttribute("Title") == mobNameToFind and monsterInstance:FindFirstChild("Humanoid") and monsterInstance.Humanoid.Health > 0 then
                        return monsterInstance, indexToCheck
                    end
                end
            end
        end
        return nil, nil
    end
    return nil, nil
end
sections.MainSection1:Dropdown({
	Name = "Farm Mode",
	Multi = false,
	Required = true,
	Options = {"Normal [🟢]", "Silent Farm [👻]"},
	Default = 1,
	Callback = function(Value)
		_G.FarmMode = Value
		Window:Notify({
			Title = "Mode Changed",
			Description = "Farm mode set to " .. Value,
			Lifetime = 3
		})
	end,
})
local uniqueTitles = {}
local optionTable = {}
for _, monster in pairs(workspace.Debris.Monsters:GetChildren()) do
    if monster:IsA("Model") then
        local title = monster:GetAttribute("Title")
        if title and not uniqueTitles[title] then
            uniqueTitles[title] = true
            table.insert(optionTable, title)
        end
    end
end
local MultiDropdown = sections.MainSection1:Dropdown({
	Name = "เลือกมอนสเตอร์ (Select Mob)",
	Search = true,
	Multi = true,
	Required = false,
	Options = optionTable,
	Default = {},
	Callback = function(selectedMobs)
		table.clear(_G.SelectedMobs)
		for mobName, isSelected in pairs(selectedMobs) do
			if isSelected then
				table.insert(_G.SelectedMobs, mobName)
			end
		end
        _G.SequentialNextIndex = 1
		print("Selected mobs updated:", table.concat(_G.SelectedMobs, ", "))
	end,
}, "MultiDropdown")
sections.MainSection1:Dropdown({
    Name = "Logical method",
    Search = false,
    Multi = false,
    Required = true,
    Options = {"distance", "index"},
    Default = 1,
    Callback = function(selectedValue)
        _G.TargetingLogic = selectedValue
        Window:Notify({
            Title = "เปลี่ยนลำดับการโจมตี",
            Description = "ตั้งค่าเป็น: " .. selectedValue,
            Lifetime = 3
        })
    end,
}, "TargetingLogicDropdown")
sections.MainSection1:Button({
    Name = "Update Selection",
    Callback = function()
        local newOptionTable = {}
        local uniqueTitles = {}
        for _, monster in pairs(workspace.Debris.Monsters:GetChildren()) do
            if monster:IsA("Model") then
                local title = monster:GetAttribute("Title")
                if title and not uniqueTitles[title] then
                    uniqueTitles[title] = true
                    table.insert(newOptionTable, title)
                end
            end
        end
        MultiDropdown:ClearOptions()
        MultiDropdown:InsertOptions(newOptionTable)
        Window:Notify({
            Title = "Mob List Updated",
            Description = "The selection list has been refreshed.",
            Lifetime = 3
        })
    end,
})
sections.MainSection1:Button({
    Name = "Reset Selection",
    Callback = function()
        MultiDropdown:UpdateSelection({})
        Window:Notify({
            Title = "Selection Cleared",
            Description = "Mob selection has been reset.",
            Lifetime = 3
        })
    end,
})


sections.MainSection1:Toggle({
	Name = "Auto Farm Mobs",
	Default = false,
	Callback = function(value)
		_G.AutoFarm = value
		Window:Notify({
			Title = Window.Settings.Title,
			Description = (value and "Enabled " or "Disabled ") .. "Auto Farm Mobs"
		})
        if value then
            task.spawn(function()
                local currentTarget = nil
                while _G.AutoFarm do
                    task.wait()
                    if _G.FarmMode == "Silent Farm [👻]" and not silentFarmState.isActive then
                        EnableSilentFarm()
                        if silentFarmState.realChar and silentFarmState.realChar:FindFirstChild("HumanoidRootPart") then
                           silentFarmState.realChar.HumanoidRootPart.Anchored = false
                        end
                    elseif _G.FarmMode ~= "Silent Farm [👻]" and silentFarmState.isActive then
                        DisableSilentFarm()
                    end
					if _G.FarmMode == "Instant" then
						for _, v in pairs(workspace.Debris.Monsters:GetChildren()) do
							if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
								local title = v:GetAttribute("Title")
								if title and table.find(_G.SelectedMobs, title) then
									local args = {{ Id = v:GetAttribute("Id") or v.Name, Action = "_Mouse_Click" }}
									game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
									break
								end
							end
						end
                    else
                        if not (currentTarget and currentTarget.Parent and currentTarget:FindFirstChild("Humanoid") and currentTarget.Humanoid.Health > 0) then
                            if _G.TargetingLogic == "index" and currentTarget then
                                _G.SequentialNextIndex = _G.SequentialNextIndex + 1
                            end
                            local newTarget, foundAtIndex = GetFinalTarget()
                            currentTarget = newTarget
                            if _G.TargetingLogic == "index" and foundAtIndex then
                                _G.SequentialNextIndex = foundAtIndex
                            end
                        end
                        if currentTarget then
                            local charToMove = silentFarmState.isActive and silentFarmState.realChar or player.Character
                            if charToMove and charToMove:FindFirstChild("HumanoidRootPart") then
                                local root = charToMove.HumanoidRootPart
                                local remote = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server")
                                root.CFrame = currentTarget.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
                                local args = {{ Id = currentTarget:GetAttribute("Id") or currentTarget.Name, Action = "_Mouse_Click" }}
                                remote:FireServer(unpack(args))
                            end
                        end
					end
                end
                if silentFarmState.isActive then
                    if silentFarmState.realChar and silentFarmState.realChar:FindFirstChild("HumanoidRootPart") then
                        silentFarmState.realChar.HumanoidRootPart.Anchored = true
                    end
                    DisableSilentFarm()
                end
            end)
        end
	end,
}, "Toggle")


sections.MainSection1:Toggle({
    Name = "Auto Quest",
    Default = false,
    Callback = function(value)
        _G.AutoQuestEnabled = value
        Window:Notify({
            Title = "Auto Quest",
            Description = (value and "Enabled" or "Disabled") .. " Auto Quest"
        })
        if value then
            -- Loop 1: Quest Accepter
            task.spawn(function()
                while _G.AutoQuestEnabled do
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local To_Server = ReplicatedStorage:WaitForChild("Events"):WaitForChild("To_Server")
                    for i = 1, 200 do
                        if not _G.AutoQuestEnabled then break end
                        local args = { { Id = tostring(i), Type = "Accept", Action = "_Quest" } }
                        To_Server:FireServer(unpack(args))
                        pcall(function()
                            game:GetService("Players").LocalPlayer.PlayerGui.Notifications.Normal[""]:Destroy()
                        end)
                        task.wait()
                    end
                    task.wait() 
                end
            end)

            -- Loop 2: Quest Completer
            task.spawn(function()
                while _G.AutoQuestEnabled do
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local To_Server = ReplicatedStorage:WaitForChild("Events"):WaitForChild("To_Server")
                    for i = 1, 200 do
                        if not _G.AutoQuestEnabled then break end
                        local args = { { Id = tostring(i), Type = "Complete", Action = "_Quest" } }
                        To_Server:FireServer(unpack(args))
                        pcall(function()
                            game:GetService("Players").LocalPlayer.PlayerGui.Notifications.Normal[""]:Destroy()
                        end)
                        task.wait()
                    end
                    task.wait() 
                end
            end)

            -- Loop 3: Monster Killer (adapted from Auto Farm)
            task.spawn(function()
                local currentTarget = nil
                while _G.AutoQuestEnabled do
                    task.wait()
                    if _G.FarmMode == "Silent Farm [👻]" and not silentFarmState.isActive then
                        EnableSilentFarm()
                        if silentFarmState.realChar and silentFarmState.realChar:FindFirstChild("HumanoidRootPart") then
                           silentFarmState.realChar.HumanoidRootPart.Anchored = false
                        end
                    elseif _G.FarmMode ~= "Silent Farm [👻]" and silentFarmState.isActive then
                        DisableSilentFarm()
                    end
                    
                    if not (currentTarget and currentTarget.Parent and currentTarget:FindFirstChild("Humanoid") and currentTarget.Humanoid.Health > 0) then
                        if _G.TargetingLogic == "index" and currentTarget then
                            _G.SequentialNextIndex = _G.SequentialNextIndex + 1
                        end
                        local newTarget, foundAtIndex = GetFinalTarget()
                        currentTarget = newTarget
                        if _G.TargetingLogic == "index" and foundAtIndex then
                            _G.SequentialNextIndex = foundAtIndex
                        end
                    end

                    if currentTarget then
                        local charToMove = silentFarmState.isActive and silentFarmState.realChar or player.Character
                        if charToMove and charToMove:FindFirstChild("HumanoidRootPart") then
                            local root = charToMove.HumanoidRootPart
                            local remote = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server")
                            root.CFrame = currentTarget.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
                            local args = {{ Id = currentTarget:GetAttribute("Id") or currentTarget.Name, Action = "_Mouse_Click" }}
                            remote:FireServer(unpack(args))
                        end
                    end
                end
                if silentFarmState.isActive then
                    if silentFarmState.realChar and silentFarmState.realChar:FindFirstChild("HumanoidRootPart") then
                        silentFarmState.realChar.HumanoidRootPart.Anchored = true
                    end
                    DisableSilentFarm()
                end
            end)
        else
            if silentFarmState.isActive then
                DisableSilentFarm()
            end
        end
    end,
})


local rankHeader = sections.MainSection1:Header({
    Text = "Loading..."
}, "RankUpHeader")


task.spawn(function()
    while task.wait(0.2) do
        local player = game:GetService("Players").LocalPlayer
        local energyVal = "Unknown"
        local maxVal = "Unknown"

     
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats and leaderstats:FindFirstChild("Energy") then
            energyVal = tostring(leaderstats.Energy.Value)
        end

        
        local gui = player:FindFirstChild("PlayerGui")
        if gui then
            local upgradeUI = gui:FindFirstChild("Upgrades")
            if upgradeUI then
                local rankUp = upgradeUI:FindFirstChild("Upgrade_Rank_Up")
                if rankUp and rankUp:FindFirstChild("Progress") then
                    local main = rankUp.Progress:FindFirstChild("Main")
                    if main and main:FindFirstChild("TextLabel") then
                        local fullText = main.TextLabel.Text  
                        local _, maxPart = string.match(fullText, "([^/]+)/([^/]+)")
                        if maxPart then
                            maxVal = maxPart
                        end
                    end
                end
            end
        end

  
        rankHeader:UpdateName(energyVal .. " / " .. maxVal)
    end
end)


sections.MainSection1:Toggle({
    Name = "AutoRankUp",
    Default = false,
    Callback = function(value)
        _G.AutoRankUp = value
        while _G.AutoRankUp do
            task.wait(0.1)
            local args = {{
                Upgrading_Name = "Rank",
                Action = "_Upgrades",
                Upgrade_Name = "Rank_Up"
            }}
            game:GetService("ReplicatedStorage")
                :WaitForChild("Events")
                :WaitForChild("To_Server")
                :FireServer(unpack(args))
            local notif = game:GetService("Players").LocalPlayer.PlayerGui.Notifications.Normal[""]
            if notif then notif:Destroy() end
        end
        Window:Notify({
            Title = Window.Settings.Title,
            Description = (value and "Enabled " or "Disabled ") .. "Toggle"
        })
    end,
}, "Toggle")

sections.MainSection2:Header({
	Name = "Auto Upgrade"
})


sections.MainSection2:Toggle({
	Name = "AutoUpLevelPrestige🎆",
	Default = false,
	Callback = function(value)
	 if value then
		 while value do
            task.wait(0.1)
			 local args = {{Action = "Level_Up_Prestige"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
			end
	end
		Window:Notify({
			Title = Window.Settings.Title,
			Description = (value and "Enabled " or "Disabled ") .. "Toggle"
		})
	end,
}, "Toggle")


sections.MainSection3:Header({
	Name = "Open Chest"

})


sections.MainSection3:Toggle({
	Name = "Auto All Open Chest",
	Default = false,
	Callback = function(value)
	 if value then
		 while value do
			 
			 local args = {{Action = "_Chest_Claim",Name = "Daily"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
			local args = {{Action = "_Chest_Claim",Name = "Group"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
			local args = {{Action = "_Chest_Claim",Name = "Premium"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
			local args = {{Action = "_Chest_Claim",Name = "VIP"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
			wait(86400)
			end
	end
		Window:Notify({
			Title = Window.Settings.Title,
			Description = (value and "Enabled " or "Disabled ") .. "Toggle"
		})
	end,
}, "Toggle")



sections.MainSection4:Header({
	Name = "Auto StarChampions"
})





local StarList = {"Star_1","Star_2","Star_3","Star_4","Star_5","Star_6","Star_7","Star_8","Star_9","Star_10","Star_11","Star_12","Star_13","Star_14","Star_15","Star_16","Star_17","Star_18","Star_19","Star_20","Star_21"}
local SelectedStar = StarList[1]
local Dropdown = sections.MainSection4:Dropdown({
	Name = "Dropdown",
	Multi = false,
	Required = true,
	Options = StarList,
	Default = 1,
	Callback = function(value)
		SelectedStar = value
		print("Dropdown changed: " .. value)
	end,
}, "Dropdown")

-- Toggle
_G.AutoStar = false
sections.MainSection4:Toggle({
	Name = "Toggle",
	Default = false,
	Callback = function(state)
		_G.AutoStar = state
		if state then
			task.spawn(function()
				while _G.AutoStar do
					task.wait(1)
					if SelectedStar then
						local args = {{Open_Amount = 5,Action = "_Stars",Name = SelectedStar}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
					end
				end
			end)
		end

		Window:Notify({
			Title = Window.Settings.Title,
			Description = (state and "Enabled " or "Disabled ") .. "Toggle"
		})
	end,
}, "Toggle")




local teleportSection = tabs.Teleport:Section({ Side = "Left" })
teleportSection:Header({Name = "Teleport Locations"})
teleportSection:Button({
    Name = "Earth City1",
    Callback = function()
	local args = {{Location = "Earth_City",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
     local args = {{Action = "Maps_Unlock",Id = 1}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))

			 Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Spawn.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Windmil Island2",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 2}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
			local args = {{Location = "Windmill_Island",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Shop.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Soul Society3",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 3}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
              local args = {{Location = "Soul_Society",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Cursed School4",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 4}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Cursed_School",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Slayer Village5",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 5}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Slayer_Village",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Solo Ialand6",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 6}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Solo_Ialand",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Clover Village7",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 7}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Clover_Village",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Leaf Village8",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 8}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Leaf_Village",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Spirit Residence9",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 9}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Spirit_Residence",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Magic Hunter City10",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 10}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Magic_Hunter_City",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Titan City11",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 11}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Titan_City",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Village of Sins12",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 12}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Village_of_Sins",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Kaiju Base13",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 13}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Kaiju_Base",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Tempest Capital14",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 14}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Tempest_Capital",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Virtual City15",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 15}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Virtual_City",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Cairo16",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 16}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Cairo",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})teleportSection:Button({
    Name = "Ghoul City17",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 17}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Ghoul_City",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})teleportSection:Button({
    Name = "Chainsaw City18",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 18}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Chainsaw_City",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})teleportSection:Button({
    Name = "Tokyo Empire19",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 19}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Tokyo_Empire",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})teleportSection:Button({
    Name = "Green Planet20",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 20}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Green_Planet",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})
teleportSection:Button({
    Name = "Hollow World21",
    Callback = function()
	local args = {{Action = "Maps_Unlock",Id = 21}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
	task.wait(0.1)
        	local args = {{Location = "Hollow_World",Type = "Map",Action = "Teleport"}}game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("To_Server"):FireServer(unpack(args))
            Window:Notify({
            Title = "Teleport",
            Description = "Teleported to Safe Zone.",
            Lifetime = 3
        })
    end,
})



MacLib:SetFolder("Maclib")
tabs.Settings:InsertConfigSection("Left")

sections.MainSection5:Header({Name = "Clone Settings"})
sections.MainSection5:Input({
	Name = "Target Player ID",
	Placeholder = "Enter Player User ID",
	AcceptedCharacters = "Numbers",
	Callback = function(input)
        _G.TargetPlayerID = input
		Window:Notify({
			Title = "Clone Settings",
			Description = "Set Target ID to " .. input,
            Lifetime = 3
		})
	end,
	onChanged = function(input)
		_G.TargetPlayerID = input
	end,
}, "Input")
sections.MainSection5:Toggle({
    Name = "Copy Appearance (for Clone)",
    Default = false,
    Callback = function(value)
        _G.CopyAppearance = value
        Window:Notify({
			Title = "Clone Settings",
			Description = (value and "Enabled" or "Disabled") .. " Copy Appearance",
            Lifetime = 3
		})
    end
})
sections.MainSection5:Button({
    Name = "Apply to Me",
    Callback = function()
        if _G.TargetPlayerID and player.Character then
            ApplyAppearance(player.Character, _G.TargetPlayerID)
        else
            Window:Notify({
                Title = "Appearance Error",
                Description = "Please enter a Target Player ID first.",
                Lifetime = 4
            })
        end
    end
})

sections.SettingsSectionLeft:Header({Name = "Server Hop"})

_G.TargetJobId = ""

sections.SettingsSectionLeft:Button({
    Name = "Copy Current JobId",
    Callback = function()
        if not setclipboard then
            Window:Notify({
                Title = "Error",
                Description = "Executor does not support 'setclipboard'.",
                Lifetime = 5
            })
            print("Current JobId: " .. game.JobId)
            return
        end
        setclipboard(game.JobId)
        Window:Notify({
            Title = "Success",
            Description = "Copied JobId: " .. game.JobId,
            Lifetime = 5
        })
    end,
})

sections.SettingsSectionLeft:Input({
	Name = "Target Job ID",
	Placeholder = "Enter Job ID to join",
	AcceptedCharacters = nil,
	Callback = function(input)
        _G.TargetJobId = input
	end,
	onChanged = function(input)
		_G.TargetJobId = input
	end,
}, "InputJobId")

sections.SettingsSectionLeft:Button({
    Name = "Join by Job ID",
    Callback = function()
        local targetJobId = _G.TargetJobId
        if not targetJobId or targetJobId == "" then
            Window:Notify({
                Title = "Input Error",
                Description = "Please enter a JobId first.",
                Lifetime = 4
            })
            return
        end

        local TeleportService = game:GetService("TeleportService")
        local LocalPlayer = game:GetService("Players").LocalPlayer

        Window:Notify({
            Title = "Teleporting",
            Description = "Attempting to join server: " .. targetJobId,
            Lifetime = 5
        })

        local success, errorMessage = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, LocalPlayer)
        end)

        if not success then
            Window:Notify({
                Title = "Teleport Failed",
                Description = "Error: " .. tostring(errorMessage),
                Lifetime = 6
            })
        end
    end
})

game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(State)
	if queueteleport then
		queueteleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/Xinterhyperbola/Anime-Eternal/refs/heads/main/Haru_merged.lua'))()")
	end
end)




Window.onUnloaded(function()
	print("Unloaded!")
end)
tabs.Main:Select()
MacLib:LoadAutoLoadConfig()
