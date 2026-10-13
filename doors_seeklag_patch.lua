-- Nova Hub / DOORS Seek-chase performance patch
-- Fetches the upstream source, applies four guarded edits in memory, then runs it.
-- If the source changes and any expected section is missing/duplicated, it aborts.

local SOURCE_URL = "https://raw.githubusercontent.com/kyksikoid/Doors-Script/main/doors.lua"

if type(game.HttpGet) ~= "function" then
    warn("[Nova patch] game:HttpGet is unavailable in this environment.")
    return
end

local ok, source = pcall(function()
    return game:HttpGet(SOURCE_URL)
end)

if not ok or type(source) ~= "string" or #source < 10000 then
    warn("[Nova patch] Could not retrieve the full upstream source. Aborting.")
    return
end

local function replaceExactlyOnce(oldText, newText, label)
    local first, last = string.find(source, oldText, 1, true)
    if not first then
        error("[Nova patch] Expected source section not found: " .. label)
    end
    if string.find(source, oldText, last + 1, true) then
        error("[Nova patch] Source section matched multiple times: " .. label)
    end
    source = string.sub(source, 1, first - 1)
        .. newText
        .. string.sub(source, last + 1)
end

local success, patchError = pcall(function()
    -- 1. Add an accumulator for throttling the Auto Minecart controller.
    replaceExactlyOnce(
        "local DoorReach = 0",
        "local DoorReach = 0\nlocal AutoMinecartTimer = 0",
        "Auto Minecart timer declaration"
    )

    -- 2. Accumulate frame time in the main RenderStepped loop.
    replaceExactlyOnce(
        "DoorReach += dt",
        "DoorReach += dt\nAutoMinecartTimer += dt",
        "Auto Minecart timer update"
    )

    -- 3. Run minecart steering at up to about 30 Hz instead of every rendered frame.
    replaceExactlyOnce(
        "if Toggles.AutoMinecart.Value and Camera:FindFirstChild(\"MinecartRig\") then",
        "if Toggles.AutoMinecart.Value and Camera:FindFirstChild(\"MinecartRig\") and AutoMinecartTimer >= 0.033 then\nAutoMinecartTimer = 0",
        "Auto Minecart controller throttle"
    )

    -- 4. DescendantAdded fires for an instance once it is parented under Workspace.
    -- The original unconditional first wait adds 30 ms of scheduling overhead per event.
    replaceExactlyOnce(
        "table.insert(Connections,workspace.DescendantAdded:Connect(function(v)\nlocal timeout = 0\nrepeat task.wait(0.03) timeout += 0.03 until v.Parent or timeout > 0.5\nif v.Parent then",
        "table.insert(Connections,workspace.DescendantAdded:Connect(function(v)\nif not v.Parent then\nlocal timeout = 0\nrepeat task.wait(0.03) timeout += 0.03 until v.Parent or timeout > 0.5\nend\nif v.Parent then",
        "DescendantAdded redundant wait"
    )
end)

if not success then
    warn(tostring(patchError))
    warn("[Nova patch] No patched script was executed.")
    return
end

local compileOK, compiledOrError = pcall(function()
    return loadstring(source)
end)

if not compileOK or type(compiledOrError) ~= "function" then
    warn("[Nova patch] Patched source failed to compile: " .. tostring(compiledOrError))
    return
end

print("[Nova patch] Applied 4 performance edits.")
print("[Nova patch] Auto Minecart control is throttled to ~30 Hz.")
print("[Nova patch] Removed the unnecessary DescendantAdded wait for already-parented instances.")
print("[Nova patch] Starting patched Nova Hub...")

local runOK, runError = pcall(compiledOrError)
if not runOK then
    warn("[Nova patch] Script raised an error: " .. tostring(runError))
end
