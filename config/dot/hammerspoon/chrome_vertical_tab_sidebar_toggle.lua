-- Chrome-Vertical-Tab-Sidebar-Toggle
-- Hammerspoon script to toggle Chrome's native vertical tab sidebar
-- via keyboard shortcut and mouse left-edge hover.
-- Uses macOS Accessibility API to find and press the sidebar button.

-- ----------------------------------------------------------
-- Modules
-- ----------------------------------------------------------
local eventtap       = hs.eventtap
local appWatcher     = hs.application.watcher
local caffeinate     = hs.caffeinate
local timer          = hs.timer
local mouse          = hs.mouse
local app            = hs.application
local log            = hs.logger.new("chrome-sidebar", "info")

-- ----------------------------------------------------------
-- Configuration
-- ----------------------------------------------------------

-- Toggle which trigger sources are active. Both default to true.
-- Set either to false to fully disable that subsystem at load time;
-- the corresponding hs.eventtap / hs.timer is never created, so the
-- feature has zero runtime cost when off. If both are false, the
-- script effectively becomes a no-op (only the app/sleep watchers
-- remain registered, and they short-circuit immediately).
local FEATURES = {
    keyboardToggle  = true,  -- Cmd+B (or configured TOGGLE_*) toggles the sidebar
    mouseEdgeToggle = true,  -- Hover Chrome's left edge to expand, leave to collapse
}

-- Application names treated as "Chrome". The frontmost app must appear
-- here (with value true) to be considered a target for the sidebar
-- toggle. Add custom Chromium-based browsers if needed.
local TARGET_APPS = {
    ["Google Chrome"]        = true,
    ["Google Chrome Beta"]   = true,
    ["Google Chrome Canary"] = true,
    ["Google Chrome Dev"]    = true,
    ["Chromium"]             = true,
}

-- ----------------------------------------------------------
-- Toggle hotkey
--   TOGGLE_MODS: which modifier keys MUST be held to trigger the toggle.
--                Set each field to true / false explicitly. A keystroke
--                only fires when its modifier mask matches this table
--                exactly (e.g. with cmd=true, Cmd+Shift+B does NOT fire).
--   TOGGLE_KEY : the main key. Use a single character ("b", "s") or a
--                named key from hs.keycodes.map ("tab", "f1", "space").
-- ----------------------------------------------------------
local TOGGLE_MODS    = {
    cmd   = true,
    ctrl  = false,
    alt   = false,
    shift = false,
}
local TOGGLE_KEY     = "b"
local TOGGLE_KEYCODE = hs.keycodes.map[TOGGLE_KEY]

-- AXTitle / AXDescription strings that identify Chrome's vertical-tab
-- sidebar toggle button. Chrome localizes these by UI language.
--
-- Sourced directly from Chromium's generated_resources_*.xtb translation
-- files for message IDs IDS_EXPAND_VERTICAL_TABS and
-- IDS_COLLAPSE_VERTICAL_TABS. If your Chrome shows the button but it's
-- not being detected, add the exact strings here.
--
-- Matching is case-insensitive and requires an EXACT string match
-- (not substring) to avoid false positives on unrelated labels.
-- All entries are stored in lowercase at lookup-build time below.
local SIDEBAR_LABELS = {
    -- Sidebar is currently COLLAPSED. Button label = next action = "expand".
    -- Source: IDS_EXPAND_VERTICAL_TABS (translation id 7194343495483122559).
    collapsed = {
        "Expand tabs", -- en, en-GB
        "Vou oortjies uit", -- af
        "ትሮችን ዘርጋ", -- am
        "توسيع علامات التبويب", -- ar
        "টেব বিস্তাৰ কৰক", -- as
        "Tabları genişləndirin", -- az
        "Разгарнуць укладкі", -- be
        "Разгъване на разделите", -- bg
        "ট্যাব বড় করুন", -- bn
        "Proširivanje kartica", -- bs
        "Desplega les pestanyes", -- ca
        "Rozbalit karty", -- cs
        "Ehangu tabiau", -- cy
        "Udvid faner", -- da
        "Tabs maximieren", -- de
        "Ανάπτυξη καρτελών", -- el
        "Mostrar pestañas", -- es
        "Expandir pestañas", -- es-419
        "Vahelehtede laiendamine", -- et
        "Zabaldu fitxak", -- eu
        "ازهم بازکردن زبانه‌ها", -- fa
        "Laajenna välilehdet", -- fi
        "I-expand ang mga tab", -- fil
        "Développer les onglets", -- fr, fr-CA
        "Despregar as pestanas", -- gl
        "ટૅબ મોટા કરો", -- gu
        "टैब को बड़ा करें", -- hi
        "Proširi kartice", -- hr, sr-Latn
        "Lapok kibontása", -- hu
        "Ծավալել ներդիրները", -- hy
        "Luaskan tab", -- id
        "Stækka flipa", -- is
        "Espandi schede", -- it
        "הרחבת הכרטיסיות", -- iw / he
        "タブを開く", -- ja
        "ჩანართების გაფართოება", -- ka
        "Қойындыларды жаю", -- kk
        "ពង្រីកផ្ទាំង", -- km
        "ಟ್ಯಾಬ್\u{200c}ಗಳನ್ನು ವಿಸ್ತರಿಸಿ", -- kn
        "탭 펼치기", -- ko
        "Өтмөктөрдү жайып көрсөтүү", -- ky
        "ຂະຫຍາຍແຖບ", -- lo
        "Išskleisti skirtukus", -- lt
        "Izvērst cilnes", -- lv
        "Прошири ги картичките", -- mk
        "ടാബുകൾ വികസിപ്പിക്കുക", -- ml
        "Табуудыг дэлгэх", -- mn
        "टॅबचा विस्तार करा", -- mr
        "Kembangkan tab", -- ms
        "တဘ်များ ပိုပြရန်", -- my
        "ट्याबहरू एक्स्पान्ड गर्नुहोस्", -- ne
        "Tabbladen uitvouwen", -- nl
        "Vis faner", -- no
        "ଟାବଗୁଡ଼ିକୁ ବିସ୍ତାର କରନ୍ତୁ", -- or
        "ਟੈਬਾਂ ਦਾ ਵਿਸਤਾਰ ਕਰੋ", -- pa
        "Rozwiń karty", -- pl
        "Mostrar guias", -- pt-BR
        "Expandir separadores", -- pt-PT
        "Extinde filele", -- ro
        "Развернуть вкладки", -- ru
        "පටිති දිග හරින්න", -- si
        "Rozbaliť karty", -- sk
        "Razširi zavihke", -- sl
        "Zgjero skedat", -- sq
        "Прошири картице", -- sr
        "Utöka flikar", -- sv
        "Panua vichupo", -- sw
        "பக்கங்களை விரிவாக்கும்", -- ta
        "ట్యాబ్\u{200c}లను విస్తరించండి", -- te
        "ขยายแท็บ", -- th
        "Sekmeleri genişlet", -- tr
        "Розгорнути вкладки", -- uk
        "ٹیبز کو پھیلائیں", -- ur
        "Varaqlarni yoyish", -- uz
        "Mở rộng thẻ", -- vi
        "展开标签页", -- zh-CN
        "展開分頁", -- zh-HK, zh-TW
        "Khulisa amathebhu", -- zu
    },
    -- Sidebar is currently EXPANDED. Button label = next action = "collapse".
    -- Source: IDS_COLLAPSE_VERTICAL_TABS (translation id 2729310339366257582).
    expanded = {
        "Collapse tabs", -- en, en-GB
        "Vou oortjies in", -- af
        "ትሮችን ሰብስብ", -- am
        "تصغير علامات التبويب", -- ar
        "টেব সংকোচন কৰক", -- as
        "Tabları yığcamlaşdırın", -- az
        "Згарнуць укладкі", -- be
        "Свиване на разделите", -- bg
        "ট্যাব আড়াল করুন", -- bn
        "Sužavanje kartica", -- bs
        "Replega les pestanyes", -- ca
        "Sbalit karty", -- cs
        "Crebachu tabiau", -- cy
        "Skjul faner", -- da, no
        "Tabs minimieren", -- de
        "Σύμπτυξη καρτελών", -- el
        "Ocultar pestañas", -- es
        "Contraer pestañas", -- es-419
        "Vahelehtede ahendamine", -- et
        "Tolestu fitxak", -- eu
        "جمع کردن زبانه‌ها", -- fa
        "Tiivistä välilehdet", -- fi
        "I-collapse ang mga tab", -- fil
        "Réduire les onglets", -- fr, fr-CA
        "Contraer as pestanas", -- gl
        "ટૅબ નાના કરો", -- gu
        "टैब को छोटा करें", -- hi
        "Sažmi kartice", -- hr
        "Lapok összecsukása", -- hu
        "Ծալել ներդիրները", -- hy
        "Ciutkan tab", -- id
        "Draga saman flipa", -- is
        "Comprimi schede", -- it
        "כיווץ הכרטיסיות", -- iw / he
        "タブを閉じる", -- ja
        "ჩანართების ჩაკეცვა", -- ka
        "Қойындыларды жию", -- kk
        "បង្រួមផ្ទាំង", -- km
        "ಟ್ಯಾಬ್\u{200c}ಗಳನ್ನು ಕುಗ್ಗಿಸಿ", -- kn
        "탭 접기", -- ko
        "Өтмөктөрдү жыйыштыруу", -- ky
        "ຫຍໍ້ແຖບລົງ", -- lo
        "Sutraukti skirtukus", -- lt
        "Sakļaut cilnes", -- lv
        "Собери ги картичките", -- mk
        "ടാബുകൾ ചുരുക്കുക", -- ml
        "Табуудыг хураах", -- mn
        "टॅब कोलॅप्स करा", -- mr
        "Kuncupkan tab", -- ms
        "တဘ်များ လျှော့ပြရန်", -- my
        "ट्याबहरू कोल्याप्स गर्नुहोस्", -- ne
        "Tabbladen samenvouwen", -- nl
        "ଟାବଗୁଡ଼ିକୁ ସଙ୍କୁଚିତ କରନ୍ତୁ", -- or
        "ਟੈਬਾਂ ਨੂੰ ਸਮੇਟੋ", -- pa
        "Zwiń karty", -- pl
        "Ocultar guias", -- pt-BR
        "Reduzir separadores", -- pt-PT
        "Restrânge filele", -- ro
        "Свернуть вкладки", -- ru
        "පටිති හකුළන්න", -- si
        "Zbaliť karty", -- sk
        "Strni zavihke", -- sl
        "Palos skedat", -- sq
        "Скупи картице", -- sr
        "Skupi kartice", -- sr-Latn
        "Komprimera flikar", -- sv
        "Kunja vichupo", -- sw
        "பக்கங்களைச் சுருக்கும்", -- ta
        "ట్యాబ్\u{200c}లను కుదించండి", -- te
        "ยุบแท็บ", -- th
        "Sekmeleri daralt", -- tr
        "Згорнути вкладки", -- uk
        "ٹیبز کو سکیڑیں", -- ur
        "Varaqlarni yigʻish", -- uz
        "Thu gọn thẻ", -- vi
        "收起标签页", -- zh-CN
        "收合分頁", -- zh-HK, zh-TW
        "Nciphisa amathebhu", -- zu
    },
}

-- Build a fast { lowercased_label -> "collapsed"|"expanded" } lookup so
-- the AX traversal can classify each button in O(1).
local SIDEBAR_LABEL_LOOKUP = {}
for state, labels in pairs(SIDEBAR_LABELS) do
    for _, label in ipairs(labels) do
        SIDEBAR_LABEL_LOOKUP[string.lower(label)] = state
    end
end

-- Limits applied when walking Chrome's macOS Accessibility (AX) tree.
local AX = {
    -- Maximum recursion depth allowed in findSidebarButton. Chrome's
    -- toolbar button is typically only ~8-10 levels deep, so 15 leaves
    -- some headroom while still capping pathological cases.
    maxDepth = 15,
}

-- Tuning for the mouse left-edge hover trigger.
local EDGE = {
    -- Distance (in pixels) from the screen's left edge within which the
    -- mouse is considered "on the edge". Once the mouse enters this band,
    -- hover tracking begins.
    enterPx     = 5,

    -- Extra slack (pixels) beyond the live sidebar right edge before
    -- collapsing. Without this, fast horizontal mouse motion that just
    -- grazes the sidebar boundary would trigger an immediate collapse.
    exitMarginPx = 30,

    -- How long (seconds) to wait after pressing the sidebar toggle
    -- before reading the expanded AXTabGroup frame. Chrome's AX cache
    -- briefly still reports the collapsed width right after AXPress, so
    -- reading immediately gives a bogus ~57 px right edge.
    measureDelaySeconds = 0.2,

    -- How long the mouse must stay on the edge (seconds) before the
    -- sidebar is actually expanded. Acts as a debounce against
    -- accidental edge crossings. Lower = snappier but more prone to
    -- triggering during fast left-to-right mouse motion.
    waitSeconds = 0.08,

    -- Interval (seconds) at which the mouse position is polled. Smaller
    -- = more responsive but more CPU; larger = less CPU but laggy edge
    -- detection.
    pollSeconds = 0.05,
}

-- Watchdog that revives the mouse poller if it stops emitting heartbeats
-- (e.g. after sleep/wake, system stalls, or accessibility hiccups).
local WATCHDOG = {
    -- How often (seconds) the watchdog checks the heartbeat.
    intervalSeconds  = 2,

    -- If no heartbeat has been observed for this many seconds, the
    -- mouse poller is considered dead and the services are restarted.
    heartbeatTimeout = 5,
}

-- Grace periods (seconds): after certain transitions, all sidebar
-- triggers (keyboard hotkey AND mouse edge) are suppressed for the
-- given duration to avoid spurious activations.
local GRACE = {
    -- Suppression after Chrome gains focus. Covers the brief window in
    -- which app-switching key chords (e.g. Cmd+Tab) might still be in
    -- flight when Chrome becomes frontmost.
    onActivate   = 0.3,

    -- Suppression after Chrome loses focus. Mirrors onActivate for the
    -- reverse direction.
    onDeactivate = 1,

    -- Suppression after Chrome is launched. Gives Chrome time to build
    -- its window/AX tree before we try to interact with it.
    onLaunch     = 1.0,

    -- Suppression after the system wakes from sleep. AX queries are
    -- often unreliable during this window. Should cover at least
    -- DELAY.restartAfterWake + DELAY.restartGap so triggers stay
    -- suppressed until the services actually come back up.
    onWake       = 2.5,

    -- Suppression at script initialization. Avoids firing triggers
    -- during Hammerspoon's own startup.
    onInit       = 2,
}

-- Time delays (seconds) for asynchronous start/stop/restart operations.
-- These space out side effects so they don't race with each other or
-- with Chrome's own lifecycle events.
local DELAY = {
    -- Wait this long after Chrome activates before (re-)starting
    -- services. Short enough to feel responsive while still letting
    -- a quick activate→deactivate bounce cancel via cancelPending.
    startAfterActivate  = 0.2,

    -- Wait this long after Chrome deactivates before stopping
    -- services. Prevents flicker if focus bounces back quickly.
    stopAfterDeactivate = 0.3,

    -- Wait this long after the system wakes before restarting
    -- services, to give Chrome and AX time to recover.
    restartAfterWake    = 2,

    -- Gap (seconds) between stopServices() and startServices() inside
    -- restartServices(). Ensures cleanly torn-down timers/eventtaps
    -- before recreating them.
    restartGap          = 0.5,

    -- Wait this long at script load before performing the initial
    -- startServices() / setGracePeriod() pass.
    init                = 2,
}

-- ----------------------------------------------------------
-- State
--
-- All mutable state lives in this single local table so we don't pollute
-- the Hammerspoon global namespace. Other init.lua scripts loaded in the
-- same Hammerspoon instance can't accidentally read or overwrite these.
-- ----------------------------------------------------------
local runtime = {
    keyTap        = nil,  -- hs.eventtap that intercepts the toggle hotkey
    mousePoller   = nil,
    watchdogTimer = nil,
    edgeTimer     = nil,
    graceTimer    = nil,
    pendingStart  = nil,                        -- deferred startServices() handle (cancellable)
    pendingStop   = nil,                        -- deferred stopServices() handle (cancellable)
    isEdgeActive  = false,
    openedByEdge  = false,                      -- true if mouse-edge expanded the sidebar
    isRestarting  = false,                      -- true while restartServices is in flight
    inGrace       = false,                      -- true while a grace period is active
    lastHeartbeat = timer.secondsSinceEpoch(),  -- last mouse poll timestamp
    lastMissLog   = 0,                          -- last time we logged a "button not found" warning
    sidebarRightX = nil,                        -- screen-coord X of the expanded sidebar's right edge
                                                -- (nil = not measured yet → exit branch is inert)
}

-- Minimum seconds between repeated "button not found" log lines.
-- mousePollCallback fires at EDGE.pollSeconds, so without this throttle
-- the Hammerspoon console would be flooded whenever the sidebar button
-- truly is missing.
local MISS_LOG_INTERVAL = 30

-- AXButton cache. Weak key on the window AXUIElement so the entry vanishes
-- when the window is gone. Validity is re-checked on every read.
local function newWeakKeyTable() return setmetatable({}, { __mode = "k" }) end
local buttonCache = newWeakKeyTable()

-- Stop the timer/eventtap currently held at runtime[key] (if any) and clear
-- the slot. Used by the three "create or recreate" helpers below so each one
-- doesn't repeat the same nil-then-stop dance.
local function disposeRuntime(key)
    if runtime[key] then
        runtime[key]:stop()
        runtime[key] = nil
    end
end

-- ----------------------------------------------------------
-- Forward declarations
-- (only restartServices needs one, because the watchdog callback
--  references it before it is defined.)
-- ----------------------------------------------------------
local restartServices

-- ----------------------------------------------------------
-- App targeting
-- ----------------------------------------------------------
local function isTargetApp(name)
    return name ~= nil and TARGET_APPS[name] == true
end

-- True when the frontmost macOS app is one of our Chrome variants.
local function isFrontChrome()
    local f = app.frontmostApplication()
    return f ~= nil and isTargetApp(f:name())
end

-- ----------------------------------------------------------
-- AX: Find sidebar button in Chrome's accessibility tree.
-- Classification (collapsed vs expanded) happens later in getSidebarState.
-- ----------------------------------------------------------
local function findSidebarButton(axElement, depth)
    depth = depth or 0
    if not axElement or depth > AX.maxDepth then return nil end

    if axElement:attributeValue("AXRole") == "AXButton" then
        local title = string.lower(tostring(axElement:attributeValue("AXTitle") or ""))
        local desc  = string.lower(tostring(axElement:attributeValue("AXDescription") or ""))
        if SIDEBAR_LABEL_LOOKUP[title] or SIDEBAR_LABEL_LOOKUP[desc] then
            return axElement
        end
    end

    local children = axElement:attributeValue("AXChildren")
    if children then
        for _, child in ipairs(children) do
            local result = findSidebarButton(child, depth + 1)
            if result then return result end
        end
    end
    return nil
end

-- Find Chrome's vertical-tab AXTabGroup and return its AXFrame.
-- The tab group's frame is the entire sidebar's screen-coordinate rect,
-- so frame.x + frame.w is the live sidebar right edge — exactly what the
-- mouse-edge exit threshold needs.
local function findTabGroupFrame(axElement, depth)
    depth = depth or 0
    if not axElement or depth > AX.maxDepth then return nil end

    if axElement:attributeValue("AXRole") == "AXTabGroup" then
        return axElement:attributeValue("AXFrame")
    end

    local children = axElement:attributeValue("AXChildren")
    if children then
        for _, child in ipairs(children) do
            local frame = findTabGroupFrame(child, depth + 1)
            if frame then return frame end
        end
    end
    return nil
end

-- Return the AXUIElement for Chrome's focused window, or any window as fallback.
local function getFocusedChromeWindow()
    if not isFrontChrome() then return nil end
    local axApp = hs.axuielement.applicationElement(app.frontmostApplication())
    return axApp:attributeValue("AXFocusedWindow")
        or (axApp:attributeValue("AXWindows") or {})[1]
end

-- Look up the sidebar button for a given window with cache.
-- Re-validates the cached element and re-searches the tree on miss/invalidation.
-- Logs a throttled warning to the Hammerspoon console when the button cannot
-- be found, since that usually means the vertical-tab feature is disabled
-- in chrome://flags or the AX label changed.
local function getSidebarButton(win)
    if not win then return nil end
    local cached = buttonCache[win]
    if cached then
        local ok, valid = pcall(function() return cached:isValid() end)
        if ok and valid then return cached end
        buttonCache[win] = nil
    end
    local button = findSidebarButton(win) -- ignore returned state here; classification happens in getSidebarState
    if button then
        buttonCache[win] = button
        return button
    end

    -- Throttle to avoid console spam from the 20Hz mouse poller.
    local now = timer.secondsSinceEpoch()
    if (now - runtime.lastMissLog) >= MISS_LOG_INTERVAL then
        runtime.lastMissLog = now
        log.w("Sidebar button (Expand tabs / Collapse tabs) not found in Chrome's AX tree. "
            .. "Is the vertical tab strip enabled?")
    end
    return nil
end

-- ----------------------------------------------------------
-- Sidebar state inspection
--   Chrome labels the button by its NEXT action; the SIDEBAR_LABELS
--   dictionary above maps each known localized label to the current
--   sidebar state ("collapsed" or "expanded").
-- ----------------------------------------------------------
local function getSidebarState()
    local win = getFocusedChromeWindow()
    if not win then return nil end

    local button = getSidebarButton(win)
    if not button then return nil end

    local title = string.lower(tostring(button:attributeValue("AXTitle") or ""))
    local desc  = string.lower(tostring(button:attributeValue("AXDescription") or ""))
    local state = SIDEBAR_LABEL_LOOKUP[title] or SIDEBAR_LABEL_LOOKUP[desc]
    return state, button
end

-- ----------------------------------------------------------
-- Core: Toggle sidebar via AX API
-- ----------------------------------------------------------
local function toggleSidebar()
    if runtime.inGrace then return end
    local _, button = getSidebarState()
    if button then
        button:performAction("AXPress")
        -- User explicitly toggled; relinquish edge-ownership so the
        -- "mouse left far away → auto-collapse" rule doesn't kick in.
        runtime.openedByEdge = false
        runtime.sidebarRightX = nil  -- width may have changed; re-measure on next edge expand
    end
end

-- Only collapses sidebars that were opened by the edge trigger itself.
local function collapseSidebarIfOwned()
    if runtime.inGrace then return end
    if not runtime.openedByEdge then return end
    local state, button = getSidebarState()
    if state == "expanded" and button then
        button:performAction("AXPress")
    end
    runtime.openedByEdge = false
    runtime.sidebarRightX = nil  -- next expand re-measures
end

-- ----------------------------------------------------------
-- Mouse: Left-edge hover trigger
-- ----------------------------------------------------------
local function resetEdgeState()
    if runtime.edgeTimer then
        runtime.edgeTimer:stop()
        runtime.edgeTimer = nil
    end
    runtime.isEdgeActive = false
end

-- Get Chrome's focused window AXFrame (screen coordinates) or nil.
-- Used by the mouse poller to derive a window-relative X so the left-edge
-- trigger works regardless of where Chrome is positioned on screen.
local function getChromeWindowFrame()
    local win = getFocusedChromeWindow()
    return win and win:attributeValue("AXFrame") or nil
end

local function mousePollCallback()
    runtime.lastHeartbeat = timer.secondsSinceEpoch()

    if not isFrontChrome() or runtime.inGrace then
        resetEdgeState()
        return
    end

    local pos = mouse.absolutePosition()
    local winFrame = getChromeWindowFrame()
    if not winFrame then return end

    -- Distance from Chrome window's LEFT edge (not the screen's). This
    -- lets the trigger work when Chrome is e.g. snapped to the right
    -- half of the display.
    local relativeX = pos.x - winFrame.x

    if relativeX >= 0 and relativeX <= EDGE.enterPx and not runtime.isEdgeActive then
        -- Start tracking optimistically. State (collapsed vs expanded) is
        -- checked inside the wait callback to avoid AX traversal on every
        -- poll tick.
        runtime.isEdgeActive = true

        runtime.edgeTimer = timer.doAfter(EDGE.waitSeconds, function()
            -- Re-check grace period here: a Chrome activation may have
            -- started its 1.5s grace window while this timer was pending.
            if runtime.inGrace then
                runtime.isEdgeActive = false
                return
            end

            local currentPos = mouse.absolutePosition()
            local currentWinFrame = getChromeWindowFrame()
            if not currentWinFrame or not isFrontChrome() then
                runtime.isEdgeActive = false
                return
            end

            local currentRelativeX = currentPos.x - currentWinFrame.x
            if currentRelativeX < 0 or currentRelativeX > EDGE.enterPx then
                runtime.isEdgeActive = false
                return
            end

            -- Single AX call: read state + button, press directly here.
            -- This avoids the duplicate traversal that calling expandSidebar()
            -- would cause.
            local state, button = getSidebarState()
            if state == "collapsed" and button then
                button:performAction("AXPress")
                runtime.openedByEdge = true
                -- Measure the now-expanded sidebar's right edge so the
                -- exit threshold tracks the actual width (which varies
                -- per Chrome layout / user resize). AXTabGroup.x +
                -- AXTabGroup.w is the live right-edge X in screen
                -- coordinates.
                --
                -- Defer the read: Chrome's AXTabGroup width still
                -- reports the collapsed value (~57px) right after
                -- AXPress, because the AX cache hasn't observed the
                -- layout pass yet. A short delay lets Chrome update.
                -- Until the deferred read completes, sidebarRightX
                -- stays nil and the exit branch is inert (mouse motion
                -- can't close the sidebar yet).
                timer.doAfter(EDGE.measureDelaySeconds, function()
                    if not runtime.openedByEdge then return end  -- already collapsed
                    local win = getFocusedChromeWindow()
                    local frame = win and findTabGroupFrame(win)
                    if frame then
                        runtime.sidebarRightX = frame.x + frame.w
                    end
                end)
            else
                -- Already expanded, or button unavailable. Drop tracking
                -- so the exit branch can't later collapse something we
                -- didn't open.
                runtime.isEdgeActive = false
            end
        end)
    elseif runtime.isEdgeActive
        and runtime.sidebarRightX
        and pos.x >= runtime.sidebarRightX + EDGE.exitMarginPx then
        -- Collapse only when the live AXTabGroup measurement is available.
        -- While sidebarRightX is nil (e.g. during the measureDelaySeconds
        -- window right after expanding), do nothing rather than guessing
        -- with a fixed pixel threshold.
        resetEdgeState()
        collapseSidebarIfOwned()
    end
end

local function createMousePoller()
    disposeRuntime("mousePoller")
    runtime.mousePoller = timer.new(EDGE.pollSeconds, mousePollCallback)
    return runtime.mousePoller
end

-- ----------------------------------------------------------
-- Watchdog: independent timer that revives the mouse poller
-- if its heartbeat goes stale (e.g. after sleep/wake glitches).
-- ----------------------------------------------------------
local function createWatchdog()
    disposeRuntime("watchdogTimer")
    runtime.watchdogTimer = timer.new(WATCHDOG.intervalSeconds, function()
        -- Skip the check while a restart is already in progress, otherwise
        -- the still-stale heartbeat would trigger a second restart and
        -- race with the first.
        if runtime.isRestarting or runtime.inGrace or not isFrontChrome() then return end

        local now = timer.secondsSinceEpoch()
        if (now - runtime.lastHeartbeat) > WATCHDOG.heartbeatTimeout then
            restartServices()
        end
    end)
    return runtime.watchdogTimer
end

-- ----------------------------------------------------------
-- Grace period (avoids triggers during app switching)
-- ----------------------------------------------------------
local function setGracePeriod(seconds)
    runtime.inGrace = true
    if runtime.graceTimer then runtime.graceTimer:stop() end
    runtime.graceTimer = timer.doAfter(seconds, function()
        runtime.inGrace = false
    end)
end

-- ----------------------------------------------------------
-- Keyboard: hotkey intercept via eventtap
--
-- We use hs.eventtap instead of hs.hotkey.bind because hs.hotkey installs
-- a GLOBAL hotkey at the OS level: if its enable/disable lifecycle races
-- with appWatcher events (which it can during fast app-switching), the
-- key stays captured even in other apps — e.g. Cmd+B then stops working
-- in VSCode. eventtap inspects every keyDown but only consumes it when
-- frontmost == Chrome and the modifier mask + keycode match exactly, so
-- non-Chrome contexts are guaranteed to receive the original key event.
-- ----------------------------------------------------------
local function createKeyTap()
    disposeRuntime("keyTap")
    runtime.keyTap = eventtap.new({ eventtap.event.types.keyDown }, function(event)
        if not isFrontChrome() or runtime.inGrace then return false end

        if event:getKeyCode() ~= TOGGLE_KEYCODE then return false end

        local flags = event:getFlags()
        if (flags.cmd or false) ~= TOGGLE_MODS.cmd then return false end
        if (flags.ctrl or false) ~= TOGGLE_MODS.ctrl then return false end
        if (flags.alt or false) ~= TOGGLE_MODS.alt then return false end
        if (flags.shift or false) ~= TOGGLE_MODS.shift then return false end

        toggleSidebar()
        return true
    end)
    return runtime.keyTap
end

-- ----------------------------------------------------------
-- Service management
--
-- Each create*/start pair below is gated by a FEATURES flag, so a
-- disabled subsystem has zero runtime cost: its hs.eventtap / hs.timer
-- is never constructed. The watchdog only runs when the mouse poller
-- does, since it exists solely to revive a stalled poller.
-- ----------------------------------------------------------
local function startServices()
    if FEATURES.keyboardToggle
        and not (runtime.keyTap and runtime.keyTap:isEnabled()) then
        createKeyTap()
        if runtime.keyTap then runtime.keyTap:start() end
    end

    if FEATURES.mouseEdgeToggle then
        if not (runtime.mousePoller and runtime.mousePoller:running()) then
            createMousePoller()
            if runtime.mousePoller then runtime.mousePoller:start() end
        end
        if not (runtime.watchdogTimer and runtime.watchdogTimer:running()) then
            createWatchdog()
            if runtime.watchdogTimer then runtime.watchdogTimer:start() end
        end
    end
end

local function stopServices()
    if runtime.keyTap and runtime.keyTap:isEnabled() then runtime.keyTap:stop() end
    if runtime.mousePoller and runtime.mousePoller:running() then runtime.mousePoller:stop() end
    if runtime.watchdogTimer and runtime.watchdogTimer:running() then runtime.watchdogTimer:stop() end
    resetEdgeState()
end

restartServices = function()
    -- Guard against re-entry: the watchdog runs every WATCHDOG.intervalSeconds
    -- and could fire again during the DELAY.restartGap window before the
    -- heartbeat is refreshed, leading to overlapping stop/start cycles.
    if runtime.isRestarting then return end
    runtime.isRestarting = true

    stopServices()
    timer.doAfter(DELAY.restartGap, function()
        startServices()
        runtime.lastHeartbeat = timer.secondsSinceEpoch()
        runtime.isRestarting = false
    end)
end

-- ----------------------------------------------------------
-- App lifecycle: Chrome focus / defocus / sleep
-- ----------------------------------------------------------
startServices()

-- Cancel a pending deferred call, if any. Used so an activate→deactivate
-- (or vice versa) in quick succession doesn't fire both start and stop.
local function cancelPending(key)
    local t = runtime[key]
    if t then
        t:stop()
        runtime[key] = nil
    end
end

appWatcher.new(function(appName, eventType, _)
    if not isTargetApp(appName) then return end

    if eventType == appWatcher.activated then
        cancelPending("pendingStop")
        setGracePeriod(GRACE.onActivate)
        runtime.pendingStart = timer.doAfter(DELAY.startAfterActivate, function()
            runtime.pendingStart = nil
            startServices()
        end)
    elseif eventType == appWatcher.deactivated then
        cancelPending("pendingStart")
        setGracePeriod(GRACE.onDeactivate)
        runtime.pendingStop = timer.doAfter(DELAY.stopAfterDeactivate, function()
            runtime.pendingStop = nil
            stopServices()
        end)
    elseif eventType == appWatcher.launched then
        setGracePeriod(GRACE.onLaunch)
    elseif eventType == appWatcher.terminated then
        cancelPending("pendingStart")
        cancelPending("pendingStop")
        stopServices()
        runtime.openedByEdge = false
        runtime.sidebarRightX = nil
        buttonCache = newWeakKeyTable()
    end
end):start()

caffeinate.watcher.new(function(event)
    if event == caffeinate.watcher.systemDidWake then
        setGracePeriod(GRACE.onWake)
        timer.doAfter(DELAY.restartAfterWake, restartServices)
    elseif event == caffeinate.watcher.systemWillSleep then
        cancelPending("pendingStart")
        cancelPending("pendingStop")
        stopServices()
        runtime.openedByEdge = false
        runtime.sidebarRightX = nil
    end
end):start()

-- ----------------------------------------------------------
-- Init
-- ----------------------------------------------------------
log.i(string.format("Features enabled: keyboardToggle=%s mouseEdgeToggle=%s",
    tostring(FEATURES.keyboardToggle), tostring(FEATURES.mouseEdgeToggle)))

timer.doAfter(DELAY.init, function()
    if isFrontChrome() then startServices() end
    setGracePeriod(GRACE.onInit)
end)
