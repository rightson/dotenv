-- ==========================================
-- Configuration & Setup
-- ==========================================

-- 1. Define the application to ignore (Must match the system name exactly)
local ignoredApp = "Omnissa Horizon Client"

-- 2. Create a table to store all your hotkey objects
local myHotkeys = {}

-- 3. Helper function to bind keys and add them to our storage table
local function bind(mods, key, func)
    local k = hs.hotkey.bind(mods, key, func)
    table.insert(myHotkeys, k)
    return k
end

-- ==========================================
-- Window Movement Logic
-- ==========================================

local function moveWindow(x, y, w, h)
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local f = win:screen():frame()
    win:setFrame({
        x = f.x + (f.w * x),
        y = f.y + (f.h * y),
        w = f.w * w,
        h = f.h * h
    })
end

-- ==========================================
-- 1/3 Window Split (Using 'bind' instead of 'hs.hotkey.bind')
-- ==========================================

bind({"ctrl", "alt"}, "1", function()
    hs.alert.show("Left 1/3")
    moveWindow(0, 0, 1/3, 1)
end)

bind({"ctrl", "alt"}, "2", function()
    hs.alert.show("Middle 1/3")
    moveWindow(1/3, 0, 1/3, 1)
end)

bind({"ctrl", "alt"}, "3", function()
    hs.alert.show("Right 1/3")
    moveWindow(2/3, 0, 1/3, 1)
end)

-- ==========================================
-- 2/3 Window Split
-- ==========================================

bind({"ctrl", "shift", "alt"}, "1", function()
    hs.alert.show("Left 2/3")
    moveWindow(0, 0, 2/3, 1)
end)

bind({"ctrl", "shift", "alt"}, "2", function()
    hs.alert.show("Middle 2/3")
    moveWindow(1/6, 0, 2/3, 1)
end)

bind({"ctrl", "shift", "alt"}, "3", function()
    hs.alert.show("Right 2/3")
    moveWindow(1/3, 0, 2/3, 1)
end)

-- ==========================================
-- Display Movement (Next/Maximize)
-- ==========================================

bind({"ctrl", "alt", "cmd"}, "N", function()
    local win = hs.window.focusedWindow()
    if win then
        hs.alert.show("Next Display")
        local currentFrame = win:frame()
        local currentScreen = win:screen()
        local nextScreen = currentScreen:next()
        local currentScreenFrame = currentScreen:frame()

        local relativeX = (currentFrame.x - currentScreenFrame.x) / currentScreenFrame.w
        local relativeY = (currentFrame.y - currentScreenFrame.y) / currentScreenFrame.h
        local relativeW = currentFrame.w / currentScreenFrame.w
        local relativeH = currentFrame.h / currentScreenFrame.h

        local nextScreenFrame = nextScreen:frame()
        win:setFrame({
            x = nextScreenFrame.x + (nextScreenFrame.w * relativeX),
            y = nextScreenFrame.y + (nextScreenFrame.h * relativeY),
            w = nextScreenFrame.w * relativeW,
            h = nextScreenFrame.h * relativeH
        })
    end
end)

bind({"ctrl", "alt", "cmd"}, "m", function()
    local win = hs.window.focusedWindow()
    if win then
        hs.alert.show("Next Display & Maximize")
        local nextScreen = win:screen():next()
        win:moveToScreen(nextScreen, false, true)
        win:maximize()
    end
end)

-- ==========================================
-- Standard Splits
-- ==========================================

bind({"ctrl", "alt"}, "Left", function()
    hs.alert.show("Left Half")
    moveWindow(0, 0, 0.5, 1)
end)

bind({"ctrl", "alt"}, "Right", function()
    hs.alert.show("Right Half")
    moveWindow(0.5, 0, 0.5, 1)
end)

bind({"ctrl", "alt"}, "C", function()
    hs.alert.show("Center (70%)")
    moveWindow(0.15, 0.15, 0.7, 0.7)
end)


-- ==========================================
-- Application Watcher (The Fix)
-- ==========================================

local function handleAppEvent(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
        if appName == ignoredApp then
            -- Disable all hotkeys when Omnissa is active
            -- hs.alert.show("Hammerspoon Keys Disabled") -- Uncomment to debug
            for _, hotkey in ipairs(myHotkeys) do
                hotkey:disable()
            end
        else
            -- Enable all hotkeys when any other app is active
            for _, hotkey in ipairs(myHotkeys) do
                hotkey:enable()
            end
        end
    end
end

-- Start the watcher
local appWatcher = hs.application.watcher.new(handleAppEvent)
appWatcher:start()

-- ==========================================
-- Dictionary Lookup & Translation
-- ==========================================

-- Ctrl + Option + D: Open dictionary and lookup clipboard content
bind({"ctrl", "alt"}, "D", function()
    local clipboardContent = hs.pasteboard.getContents()
    if clipboardContent and clipboardContent ~= "" then
        hs.alert.show("Lookup: " .. clipboardContent)
        -- Use URL scheme to open Dictionary app and search
        hs.urlevent.openURL("dict://" .. hs.http.encodeForQuery(clipboardContent))
    else
        hs.alert.show("Clipboard is empty")
    end
end)

-- Ctrl + Option + G: Open Google Translate and translate clipboard content
bind({"ctrl", "alt"}, "G", function()
    local clipboardContent = hs.pasteboard.getContents()
    if clipboardContent and clipboardContent ~= "" then
        hs.alert.show("Translate: " .. clipboardContent)
        -- Open Google Translate (auto-detect language)
        local url = "https://translate.google.com/?sl=en&tl=zh-TW&text=" .. hs.http.encodeForQuery(clipboardContent)
        hs.urlevent.openURL(url)
    else
        hs.alert.show("Clipboard is empty")
    end
end)

-- ==========================================
-- Startup Notification
-- ==========================================
hs.alert.show("✓ Window management loaded")