-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2026 手电加鞭
-- MindBlastBox01_Dash.lua -- 01D-1：三列合并仪表盘（A1心灵震爆 / B1目标痛 / C1目标血量%）
-- 任务书：收件箱\送审包_WoW插件01D-1_三列合并任务书_v2_20261002.md
-- 铁律：外壳/行底板=自有帧常亮（P0-1定案：底板是行框的，不在引擎按钮子树里）；
--       保密值"可format禁比较/算术/floor"，格式化结果可能是secret不得再判断（P0-2定案）；
--       全局名一律 Dash01* 前缀、旧命令键不重注册（P0-3）；
--       P0-4′（v0.99 老板改定）：可拖动，但所有宿主几何写入必须带战斗门（外审P1-4：
--       StopMoving 无条件执行、仅落盘门控）；
--       引擎配置表逐字段照抄生产原文含表写法形状（map/list 教训，静默拒收零报错）；
--       禁忌值三侧防护（第四次踩坑沉淀，勿删）：求值侧 pcall(方法,实参)、消费侧 type()/判密
--       先行于比较、传递侧原样整体喂引擎——任一侧裸比较/裸消费都会炸（v0.8/v0.95/v0.99c 三案）
--       引擎候选表必须 map 形式 {[id]=true}（EUI 全库 6/6 消费点 + 自带代码级断言）
-- 仅牧师启用（老板实测其他职业也显示；类别门在 tryInit 首行）
local DASH_VER = "1.45-S1"
local SPELL_A = 8092            -- A1 心灵震爆
local SPELL_B = 589             -- B1 暗言术：痛
local FILTER_B = "HARMFUL|PLAYER"

local win
local aRow, aIcon, aName, aCell, aCD, aDone
local bRow, bContainer, bAuraBtn, bBorder, bCellBase
local cRow, cFS
local c2Row, c2LabelFS, c2CurrentFS, c2MaxFS
-- v1.21：B槽共用引擎通道，配置/宿主/状态独立；B1旧诊断别名只指向第1槽。
local B_SLOTS = {
    { slotKey="swp589", order=1, spellID=589, unit="target", filter=FILTER_B,
      width=134, height=40, cellHeight=36, expectedName="暗言术：痛",
      kind="target_aura", variantPolicy="BASE_ID_ONLY", formatID="ENGINE_DURATION_STRICT_OR_UNKNOWN",
      status={slotOk=false,unitOk=false,btnCaptured=false,fmtGrade="none"} },
    { slotKey="vt34914", order=2, spellID=34914, unit="target", filter=FILTER_B,
      width=134, height=34, cellHeight=30, expectedName="吸血鬼之触",
      kind="target_aura", variantPolicy="BASE_ID_ONLY", formatID="ENGINE_DURATION_STRICT_OR_UNKNOWN",
      status={slotOk=false,unitOk=false,btnCaptured=false,fmtGrade="none"} },
    { slotKey="swm335467", order=3, spellID=335467, unit="target", filter=FILTER_B,
      width=134, height=34, cellHeight=30, expectedName="暗言术：癫",
      kind="target_aura", variantPolicy="BASE_ID_ONLY", formatID="ENGINE_DURATION_STRICT_OR_UNKNOWN",
      status={slotOk=false,unitOk=false,btnCaptured=false,fmtGrade="none"} },
}
-- v1.25：只由公开槽位几何算高度；保持前两行/A2/C2的空间，新增B行各加行高和间距。
local DASH_HEIGHT = 116
for i = 3, #B_SLOTS do DASH_HEIGHT = DASH_HEIGHT + B_SLOTS[i].height + 4 end
-- 注册健康只检查自有状态，不读按钮显隐，不将注册成功当aura存在。
local function allBSlotsRegistered()
    for _, slot in ipairs(B_SLOTS) do
        if not slot.status.slotOk then return false end
    end
    return #B_SLOTS > 0
end
-- D1玩家BUFF ID来自本机历史AURA日志；当前版本匹配仍待老板真机复验。
local D_SLOTS = {
    {slotKey="D_ENTROPIC_RIFT", column="D", order=1, kind="player_aura",
     spellID=450193, unit="player", filter="HELPFUL", sourcePolicy="ANY_CASTER_ON_PLAYER",
     variantPolicy="PLAYER_BUFF_ID_ONLY", displayMode="duration", formatID="ENGINE_INTEGER_UP_STRICT_OR_UNKNOWN",
     width=134, height=40, expectedName="熵能裂隙", specID=258,
     status={slotOk=false,unitOk=false,btnCaptured=false,fmtGrade="none"}},
    -- v1.38：仅玩家真实BUFF；施放技能的冷却/替换与光环是独立对象。
    {slotKey="D_VOIDFORM", column="D", order=2, kind="player_aura",
     spellID=194249, unit="player", filter="HELPFUL", sourcePolicy="ANY_CASTER_ON_PLAYER",
     variantPolicy="PLAYER_BUFF_ID_ONLY", displayMode="duration", formatID="ENGINE_INTEGER_UP_STRICT_OR_UNKNOWN",
     width=134, height=34, cellHeight=30, expectedName="虚空形态", specID=258,
     status={slotOk=false,unitOk=false,btnCaptured=false,fmtGrade="none"}},
    {slotKey="D_POWER_INFUSION", column="D", order=3, kind="player_aura",
     spellID=10060, unit="player", filter="HELPFUL", sourcePolicy="ANY_CASTER_ON_PLAYER",
     variantPolicy="PLAYER_BUFF_ID_ONLY", displayMode="duration", formatID="ENGINE_INTEGER_UP_STRICT_OR_UNKNOWN",
     width=134, height=34, cellHeight=30, expectedName="能量灌注", specID=258,
     status={slotOk=false,unitOk=false,btnCaptured=false,fmtGrade="none"}},
}
local dContainer, dSeparator
-- A3起的普通自身CD按公开槽位配置追加；A1/A2不迁移，不用DoT或BUFF推冷却。
local A_CD_SLOTS = {
    {slotKey="torrent263165", column="A", order=3, kind="spell_cooldown", spellID=263165,
     specID=258, variantPolicy="BASE_ONLY_REJECT_OVERRIDE", cooldownScope="SPELL_ONLY_IGNORE_GCD",
     formatID="NATIVE_INTEGER_UP_OR_OK", expectedName="虚空洪流",
     status={profile="UNKNOWN",mode="UNKNOWN",reason="NOT_INITIALIZED"}},
    {slotKey="death32379", column="A", order=4, kind="spell_cooldown", spellID=32379,
     specID=258, variantPolicy="BASE_ONLY_REJECT_OVERRIDE", cooldownScope="SPELL_ONLY_IGNORE_GCD",
     formatID="NATIVE_INTEGER_UP_OR_OK", expectedName="暗言术：灭",
     status={profile="UNKNOWN",mode="UNKNOWN",reason="NOT_INITIALIZED"}},
    {slotKey="infusion10060", column="A", order=5, kind="spell_cooldown", spellID=10060,
     specID=258, variantPolicy="BASE_ONLY_REJECT_OVERRIDE", cooldownScope="SPELL_ONLY_IGNORE_GCD",
     formatID="NATIVE_INTEGER_UP_OR_OK", expectedName="能量灌注",
     status={profile="UNKNOWN",mode="UNKNOWN",reason="NOT_INITIALIZED"}},
    {slotKey="form228260", column="A", order=6, kind="spell_cooldown", spellID=228260,
     specID=258, variantPolicy="FIXED_BASE_ALLOW_DECLARED_OVERRIDE", allowedOverrides={[1242173]=true},
     cooldownScope="FIXED_BASE_SPELL_IGNORE_GCD", formatID="NATIVE_INTEGER_UP_OR_OK", expectedName="虚空形态",
     status={profile="UNKNOWN",mode="UNKNOWN",reason="NOT_INITIALIZED"}},
    {slotKey="volley1242173", column="A", order=7, kind="conditional_spell_uses", spellID=1242173,
     baseSpellID=228260, specID=258, variantPolicy="ACTUAL_CURRENT_DECLARED_REPLACEMENT",
     cooldownScope="NOT_A_COOLDOWN", formatID="NATIVE_SPELL_CAST_COUNT_SEPARATE_STATE_V6", expectedName="虚空齐射",
     status={profile="UNKNOWN",mode="UNKNOWN",reason="NOT_INITIALIZED"}},
}
-- v1.31：仅公开布局参数；所有普通CD按行号对齐，绝不读取战斗数值。
local function dashRowTop(order)
    if order == 1 then return 20 end
    return 64 + (order - 2) * 38
end
for _, slot in ipairs(A_CD_SLOTS) do
    DASH_HEIGHT = math.max(DASH_HEIGHT, dashRowTop(slot.order) + 34 + 18)
end

local acdRefreshPending, acdProfilePending, acdElapsed = true, true, 0
local activeCombatResource
local refreshDashSettings
local state = {
    shell = false,
    blizzLoaded = false,
    containerOk = false,
    slotOk = false,
    unitOk = false,
    btnCaptured = false,
    fmtGrade = "none",
    clsBlocked = false,
    layoutVersion = "L16",
    c2Format = "CURRENT_AND_MAX_SEPARATE",
    c2Profile = "UNKNOWN",
    c3Configured = false,
    cFormat = "INTEGER_PERCENT_NO_SUFFIX",
    cLabelFormat = "SHORT_EN_V1",
    lastErr = nil,
}

-- v1.03：只有类型正确且明确通过判密的值才进入 Lua 比较。
-- 判密函数缺失、抛错或返回非法类型时，不把该值当明文。
local function publicA(v, expectedType)
    if type(v) ~= expectedType then return nil end
    if type(issecretvalue) ~= "function" then return nil end
    local okS, secret = pcall(issecretvalue, v)
    if not okS or type(secret) ~= "boolean" then return nil end
    if secret then return nil end
    return v
end

local function note(err)
    state.lastErr = tostring(err)
end

-- 状态快照落 SV（.dash 子表，变量层隔离）——远程可诊断，不再靠口述
local function saveDashState()
    if type(MindBlastBox01DB) ~= "table" then return end
    local d = MindBlastBox01DB.dash
    if type(d) ~= "table" then return end
    local s = {}
    for k, v in pairs(state) do s[k] = v end
    -- 只复制公开配置/健康元数据，绝不序列化slot refs或引擎内容。
    s.bSlots = {}
    for _, slot in ipairs(B_SLOTS) do
        local st = slot.status
        s.bSlots[slot.slotKey] = { spellID=slot.spellID, order=slot.order,
            slotOk=st.slotOk, unitOk=st.unitOk, btnCaptured=st.btnCaptured,
            fmtGrade=st.fmtGrade, nameBound=st.nameBound, durationBound=st.durationBound,
            initComplete=st.initComplete, initCount=st.initCount, lastErr=st.lastErr,
            candidateReset=st.candidateReset, rescan=st.rescan }
    end
    s.dSlots = {}
    for _, slot in ipairs(D_SLOTS) do
        local st = slot.status
        s.dSlots[slot.slotKey] = {spellID=slot.spellID, unit=slot.unit, filter=slot.filter,
            sourcePolicy=slot.sourcePolicy, displayMode=slot.displayMode, formatID=slot.formatID,
            slotOk=st.slotOk, unitOk=st.unitOk, btnCaptured=st.btnCaptured, addAttempted=st.addAttempted,
            fmtGrade=st.fmtGrade, nameBound=st.nameBound, iconBound=st.iconBound, durationBound=st.durationBound,
            initComplete=st.initComplete, initCount=st.initCount, lastErr=st.lastErr,
            candidateReset=st.candidateReset, rescan=st.rescan}
    end
    s.aCooldownSlots = {}
    for _, slot in ipairs(A_CD_SLOTS) do
        local st = slot.status
        s.aCooldownSlots[slot.slotKey] = {spellID=slot.spellID, kind=slot.kind, order=slot.order,
            scope=slot.cooldownScope, variantPolicy=slot.variantPolicy, formatID=slot.formatID,
            profile=st.profile, mode=st.mode, reason=st.reason, layoutReady=st.layoutReady,
            style=st.style, completionHook=st.completionHook, countSource=st.countSource, countHealth=st.countHealth}
    end
    s.savedAt = date("%Y-%m-%d %H:%M:%S")
    d.state = s
end

-- v1.04：保存只读本插件外壳几何，不重锚、不读 aura 按钮。
-- v1.08：锚定 UIParent CENTER；SetPoint 偏移使用本窗口单位。
-- 两个中心先换到同一缩放空间求差，再除以窗口缩放；保存期间不改几何。
local VALID_POINT = {
    TOPLEFT=true, TOP=true, TOPRIGHT=true, LEFT=true, CENTER=true,
    RIGHT=true, BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true,
}
local function finitePosition(v)
    local n = publicA(v, "number")
    if n == nil then return nil end
    if n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end

-- v1.42：字体是可降级的公开显示配置，不取得整个仪表盘的启动否决权。
local dashNumberFont, dashNumberProbe, dashNumberPath
local dashNumberTemplate = "GameFontHighlightLarge"
local dashCountStateTemplate = "GameFontNormalSmall"
local dashCountStateFont, dashCountStateProbe
-- 窄状态独立排版；不把NA改成数字/横杠，也不让状态字串压低全部数字。
local DASH_COUNT_STATE_SAMPLES = {
    {role="COUNT_NA", text="NA", cellWidth=24, padding=4},
    {role="COUNT_UNKNOWN", text="?", cellWidth=24, padding=4},
    {role="COUNT_INACTIVE", text="—", cellWidth=24, padding=4},
    {role="COUNT_READY", text="OK", cellWidth=24, padding=4},
}
local function measureDashFontSamples(probe, samples, size)
    local metrics, failure = {}, nil
    for _, sample in ipairs(samples) do
        -- 固定公开字串，独立公共父框；失败也继续测后序样本。
        local ok, raw = pcall(probe.GetUnboundedStringWidthForText, probe, sample.text)
        local width = ok and finitePosition(raw) or nil
        local limit = sample.cellWidth - sample.padding
        local fits = width ~= nil and width > 0 and width <= limit
        local result = {role=sample.role, text=sample.text, size=size,
            width=width, cellWidth=sample.cellWidth, padding=sample.padding, limit=limit, fits=fits}
        metrics[#metrics+1] = result
        if not fits and not failure then
            failure = string.format("size=%d role=%s text=%s width=%s limit=%.3f",
                size, sample.role, sample.text, width and string.format("%.3f", width) or "UNAVAILABLE", limit)
        end
    end
    return failure == nil, metrics, failure
end
local function prepareDashCountStateFont()
    state.countStateFontMode, state.countStateFontAttempts = "DEFAULT_UNVERIFIED", {}
    local ok, err = pcall(function()
        local path = publicA(GameFontHighlightLarge:GetFont(), "string")
        if not path or path == "" then error("COUNT_STATE_FONT_PATH_UNAVAILABLE") end
        dashCountStateFont = CreateFont("Dash01CountStateFont")
        dashCountStateProbe = UIParent:CreateFontString(nil, "OVERLAY", "Dash01CountStateFont")
        dashCountStateProbe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        dashCountStateProbe:SetSize(200, 40)
        dashCountStateProbe:SetWordWrap(false); dashCountStateProbe:Hide()
        -- 状态专用14/13/12；数字仍16..20，原格宽与4单位留边不变。
        for _, size in ipairs({14, 13, 12}) do
            dashCountStateFont:SetFont(path, size, "")
            local actualPath, height = dashCountStateFont:GetFont()
            actualPath, height = publicA(actualPath, "string"), finitePosition(height)
            if not actualPath or actualPath:lower() ~= path:lower() or
                not height or math.abs(height-size) > 0.0001 then error("COUNT_STATE_FONT_READBACK_MISMATCH") end
            dashCountStateFont:SetTextColor(1, 1, 1); dashCountStateFont:SetShadowOffset(0, 0)
            local fits, metrics, failure = measureDashFontSamples(dashCountStateProbe, DASH_COUNT_STATE_SAMPLES, size)
            state.countStateFontMetrics = metrics
            state.countStateFontAttempts[#state.countStateFontAttempts+1] = {size=size, metrics=metrics, failure=failure}
            if fits then
                dashCountStateTemplate = "Dash01CountStateFont"
                state.countStateFontMode, state.countStateFontSize, state.countStateFontPath = "FITTED", height, actualPath
                return
            end
        end
        error("COUNT_STATE_FONT_DOES_NOT_FIT")
    end)
    if not ok then
        state.countStateFontError = tostring(err)
        local got, path, height = pcall(GameFontNormalSmall.GetFont, GameFontNormalSmall)
        state.countStateFontPath = got and publicA(path, "string") or nil
        state.countStateFontSize = got and finitePosition(height) or nil
        print("|cffffcc66[Dash01]|r 窄格状态字体未通过，已使用默认小字；数字单独检查。")
    end
    if dashCountStateProbe then pcall(dashCountStateProbe.Hide, dashCountStateProbe) end
end
local function recordDashCountFontBinding(key, numberFS, stateFS)
    local function read(fs)
        local ok, path, height = pcall(fs.GetFont, fs)
        return {path=ok and publicA(path, "string") or nil, height=ok and finitePosition(height) or nil}
    end
    -- 构造期间脱战，仅核对自有FontString的公开字体，不读取其文字或数值。
    state.countFontBindings = state.countFontBindings or {}
    state.countFontBindings[key] = {number=read(numberFS), status=read(stateFS)}
end
local function paintDashCountState(numberFS, stateFS, text)
    -- 两层均只SetText：不读数值，不在战斗中更改字体/几何/显隐。
    local cleared = pcall(numberFS.SetText, numberFS, "")
    local painted = pcall(stateFS.SetText, stateFS, text)
    return cleared and painted
end
-- 角色与实际格宽对应；只测公开示例，不是实时值范围或完整排版证明。
local DASH_NUMBER_SAMPLES = {
    {role="RESOURCE", text="888", cellWidth=40, padding=4},
    {role="RECHARGE", text="888", cellWidth=36, padding=4},
    {role="READY", text="OK", cellWidth=36, padding=4},
    {role="NO_TARGET", text="NT", cellWidth=40, padding=4},
    {role="COUNT_ZERO", text="0", cellWidth=24, padding=4},
    {role="COUNT_ONE", text="1", cellWidth=24, padding=4},
    {role="COUNT_TWO", text="2", cellWidth=24, padding=4},
    {role="COUNT", text="8", cellWidth=24, padding=4},
    {role="COUNT_PAIR", text="88", cellWidth=24, padding=4},
    {role="WIDE_UNKNOWN", text="?", cellWidth=36, padding=4},
    {role="WIDE_DASH", text="-", cellWidth=36, padding=4},
    {role="WIDE_INACTIVE", text="—", cellWidth=36, padding=4},
}
local function validDashNumberSize(value)
    local size = finitePosition(value)
    if size == nil or size < 16 or size > 20 or size % 1 ~= 0 then return nil end
    return size
end

local function setDashNumberFontSize(size)
    dashNumberFont:SetFont(dashNumberPath, size, "")
    local path, height = dashNumberFont:GetFont()
    path, height = publicA(path, "string"), finitePosition(height)
    -- 仅公开UI字号回读容差；18->17.999998为实测案例。战斗数值不在此处理。
    if path == nil or path == "" or path:lower() ~= dashNumberPath:lower() or
        height == nil or math.abs(height - size) > 0.0001 then
        error("NUMBER_FONT_READBACK_MISMATCH")
    end
end

local function readDefaultDashNumberSize()
    local ok, _, height = pcall(GameFontHighlightLarge.GetFont, GameFontHighlightLarge)
    return ok and finitePosition(height) or nil
end

local function configureDashNumberSize(value)
    if InCombatLockdown() then return false, "战斗中无法调整，脱战后再操作。" end
    local size = validDashNumberSize(value)
    if size == nil then return false, "数字字号请输入16至20之间的整数。" end
    if state.numberFontMode ~= "READABLE" or not dashNumberFont or not dashNumberProbe then
        return false, "本次使用默认字体；自定义字号未生效，请重载后再试。"
    end
    local previous = state.numberFontSize or 18
    local ok, fits = pcall(function()
        setDashNumberFontSize(size)
        local actualPath, actualHeight = dashNumberFont:GetFont()
        state.numberFontPath, state.numberFontReadbackSize = publicA(actualPath, "string"), finitePosition(actualHeight)
        dashNumberFont:SetTextColor(1, 1, 1)
        dashNumberFont:SetShadowOffset(0, 0)
        local fits, metrics, failure = measureDashFontSamples(dashNumberProbe, DASH_NUMBER_SAMPLES, size)
        state.numberFontFitMetrics, state.numberFontFitFailure = metrics, failure
        state.numberFontFitChecks = {numbers=fits, countState=state.countStateFontMode == "FITTED"}
        state.fontLayoutAccepted = fits and state.countStateFontMode == "FITTED"
        if not fits then return false end
        dashNumberProbe:SetText("")
        return true
    end)
    if not ok or not fits then
        state.fontLayoutAccepted = false
        state.numberFontLastApplyError = ok and "NUMBER_FONT_DOES_NOT_FIT" or tostring(fits)
        local restored = pcall(function()
            setDashNumberFontSize(previous)
            dashNumberProbe:SetText("")
        end)
        if not restored then
            -- 已创建文字继续继承同一Font；CopyFontObject不依赖失效的SetFont判据。
            local copied = pcall(dashNumberFont.CopyFontObject, dashNumberFont, GameFontHighlightLarge)
            state.numberFontMode = copied and "DEFAULT_FALLBACK" or "RESTORE_FAILED"
            state.numberFontSize = copied and readDefaultDashNumberSize() or nil
            state.numberFontError = state.numberFontLastApplyError
            note("数字字体恢复失败：" .. state.numberFontError)
            return false, copied and "自定义字号未生效，已退回默认字体；整体大小不变。" or
                "数字字体恢复失败，请重载；没有报告字号应用成功。"
        end
        return false, "这个字号未生效，保留原字号；可选择小一点的字号。"
    end
    state.numberFontSize = size
    state.numberFontLastApplyError = nil
    state.numberFontFitFailure = nil
    return true, "数字字号已应用为" .. tostring(size) .. "，整体占屏大小不变。"
end

local function initializeDashNumberFont()
    dashNumberPath = GameFontHighlightLarge:GetFont()
    dashNumberFont = CreateFont("Dash01ReadableNumberFont")
    setDashNumberFontSize(18)
    -- 独立公共父框；在外壳之前测量，不依赖半成品窗口的尺寸或锚点。
    dashNumberProbe = UIParent:CreateFontString(nil, "OVERLAY", "Dash01ReadableNumberFont")
    dashNumberProbe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    dashNumberProbe:SetSize(200, 40)
    dashNumberProbe:SetWordWrap(false)
    dashNumberProbe:Hide()
    state.numberFontMode = "READABLE"
    state.numberFontFitAttempts = {}
    local d = type(MindBlastBox01DB) == "table" and MindBlastBox01DB.dash
    local saved = type(d) == "table" and d.numberFontSize
    local size = validDashNumberSize(saved) or 20
    state.numberFontRestore = saved == nil and "DEFAULT" or
        (validDashNumberSize(saved) and "RESTORED" or "INVALID_DEFAULT")
    local function attempt(candidate)
        local ok = configureDashNumberSize(candidate)
        if not ok then
            state.numberFontFitAttempts[#state.numberFontFitAttempts+1] =
                state.numberFontFitFailure or state.numberFontLastApplyError or "FONT_APPLY_FAILED"
        end
        return ok
    end
    local ok = attempt(size)
    if not ok then
        ok = attempt(18)
        state.numberFontRestore = "FIT_FALLBACK_18"
    end
    if not ok then
        ok = attempt(16)
        state.numberFontRestore = "FIT_FALLBACK_16"
    end
    if not ok then error(state.numberFontLastApplyError or "NUMBER_FONT_UNAVAILABLE") end
    dashNumberTemplate = "Dash01ReadableNumberFont"
end

local function prepareDashNumberFont()
    if state.numberFontInitialized then return end
    state.numberFontInitialized = true
    prepareDashCountStateFont()
    local ok, err = pcall(initializeDashNumberFont)
    if not ok then
        dashNumberTemplate = "GameFontHighlightLarge"
        state.fontLayoutAccepted = false
        local got, path = pcall(GameFontHighlightLarge.GetFont, GameFontHighlightLarge)
        state.numberFontPath = got and publicA(path, "string") or nil
        state.numberFontMode, state.numberFontRestore = "DEFAULT_FALLBACK", "DEFAULT_FONT_FALLBACK"
        state.numberFontSize = readDefaultDashNumberSize()
        state.numberFontError = tostring(err)
        if dashNumberProbe then pcall(dashNumberProbe.Hide, dashNumberProbe) end
        note("自定义数字字体未生效：" .. state.numberFontError)
        print("|cffffcc66[Dash01]|r 自定义数字字体未生效，已用默认字体；仪表盘继续加载。")
    elseif state.numberFontRestore == "FIT_FALLBACK_18" or state.numberFontRestore == "FIT_FALLBACK_16" then
        print("|cffffcc66[Dash01]|r 数字格空间不足，实际字号为" .. tostring(state.numberFontSize) .. "；整体大小不变。")
    end
end

-- v1.18 批4A：只持久化公开窗口缩放，非法值不覆盖原存档。
local function loadDashScale()
    local d = type(MindBlastBox01DB) == "table" and MindBlastBox01DB.dash
    if type(d) ~= "table" or type(d.scale) == "nil" then
        state.scaleRestore = "DEFAULT"
        state.windowScale = 1
        return 1
    end
    local scale = finitePosition(d.scale)
    if scale == nil or scale < 0.5 or scale > 1.5 then
        state.scaleRestore = "INVALID_DEFAULT"
        state.windowScale = 1
        note("缩放存档无效：暂用100%，保留原存档")
        return 1
    end
    state.scaleRestore, state.windowScale = "RESTORED", scale
    return scale
end

local function validatedPosition(p)
    if type(p) ~= "table" then return nil end
    local pt, rp, x, y
    if type(p.point) == "nil" then
        pt, rp = "CENTER", "CENTER"
        x, y = finitePosition(p[1]), finitePosition(p[2])
    else
        pt = publicA(p.point, "string")
        rp = publicA(p.relPoint, "string")
        x, y = finitePosition(p.x), finitePosition(p.y)
    end
    if pt == nil or rp == nil or x == nil or y == nil then return nil end
    if not VALID_POINT[pt] or not VALID_POINT[rp] then return nil end
    if type(p.relativeTo) ~= "nil" then
        local rel = publicA(p.relativeTo, "string")
        if rel == nil or rel ~= "UIParent" then return nil end
    end
    return {point=pt, relPoint=rp, x=x, y=y, relativeTo="UIParent"}
end

local function describePosition(p)
    local valid = validatedPosition(p)
    if not valid then return "未知/非法" end
    return string.format("%s/%s@%.1f,%.1f", valid.point, valid.relPoint, valid.x, valid.y)
end

local function saveDashPos()
    -- 函数内的门覆盖拖动与 PLAYER_LOGOUT；战斗中连外壳几何也不采集。
    if InCombatLockdown() then state.posStatus = "SKIPPED_COMBAT"; return end
    if type(MindBlastBox01DB) ~= "table" then return end
    local d = MindBlastBox01DB.dash
    if type(d) ~= "table" or not win or not state.shell then return end
    local ok, normalized = pcall(function()
        local cx, cy = win:GetCenter()
        local ux, uy = UIParent:GetCenter()
        cx, cy = finitePosition(cx), finitePosition(cy)
        ux, uy = finitePosition(ux), finitePosition(uy)
        local ws = finitePosition(win:GetEffectiveScale())
        local us = finitePosition(UIParent:GetEffectiveScale())
        if cx == nil or cy == nil or ux == nil or uy == nil or ws == nil or us == nil then return nil end
        if ws <= 0 or us <= 0 then return nil end
        local x = cx - ux * us / ws
        local y = cy - uy * us / ws
        return validatedPosition({point="CENTER", relPoint="CENTER", x=x, y=y, relativeTo="UIParent"})
    end)
    if not ok or type(normalized) ~= "table" then
        state.posStatus = "SAVE_UNCONFIRMED"
        note("窗位保存失败：保留原存档，未改动窗口")
        return
    end
    d.pos = normalized
    state.posStatus = "SAVED"
    print("|cff66ccff[Dash01]|r 窗位已保存: " .. describePosition(normalized))
end

-- ---------- A1：技能CD（01B 管线搬移，全局名换 Dash01*） ----------
local function applyInfoA()
    if not aIcon then return end
    state.aInfo = "UNKNOWN"
    local ok = pcall(function()
        local si = C_Spell.GetSpellInfo(SPELL_A)
        if type(si) ~= "table" then error("spell metadata missing") end
        local name = publicA(si.name, "string")
        local icon = publicA(si.iconID, "number")
        if name == nil or icon == nil then error("spell metadata unconfirmed") end
        aName:SetText(name)
        aIcon:SetTexture(icon)
        state.aInfo = "PUBLIC_METADATA"
    end)
    if not ok then
        pcall(function() aName:SetText("心灵震爆?") end)
        pcall(function() aIcon:SetTexture(nil) end)
        note("A1 名称/图标未确认")
    end
end

-- v1.13：A1 数字与 OK 共用当前 ignoreGCD duration，不再锁存旧 ACTIVE。
-- IsActive 是 duration object 的原生时间判定，不是 Charges.isActive。
-- 返回值可能保密：只原样送 SetAlphaFromBoolean，不比较、不写 SV、不读字形。
local requestARefresh
local aEngineArmed, aMuteDone = false, false
local aCurrentDuration
state.aScope = "SPELL_ONLY"
state.aCompletionPolicy = "VERIFY_CURRENT_DURATION"
state.aGCDClass = "IGNORED_BY_DURATION_API"
state.aReadyPolicy = "NO_DURATION_OR_DURATION_NOT_ACTIVE"

local function onAEngineDone()
    -- 无来源通知只请求当前查询；不能直接给旧/新冷却盖 OK。
    if aMuteDone or not aEngineArmed then return end
    state.aEngineDoneCount = (state.aEngineDoneCount or 0) + 1
    if requestARefresh then requestARefresh() end
end

local function clearACooldown()
    aCurrentDuration, aEngineArmed = nil, false
    aMuteDone = true
    local ok = pcall(function() aCD:Clear(); aCD:SetAlpha(1) end)
    aMuteDone = false
    if not ok then note("A1 冷却显示清理失败") end
end

local function paintADuration(d)
    -- 同一布尔直接交两个原生 alpha setter，数字与 OK 互斥。
    -- 零跨度、已结束、尚未开始计时：原生 IsActive=false，显示 OK。
    -- 计时正在进行：原生 IsActive=true，显示官方数字。
    -- Lua 不用这个值作 if/or/not/比较，也不回读 alpha 推测可用性。
    local active = d:IsActive()
    aCD:SetAlphaFromBoolean(active, 1, 0)
    aDone:SetAlphaFromBoolean(active, 0, 1)
end

local function showAStatus(text)
    clearACooldown()
    aCD:SetHideCountdownNumbers(true)
    aDone:SetAlpha(1)
    aDone:SetText(text)
    aDone:SetShown(true)
end

local aAcc = 0
local function feedA(el)
    aAcc = aAcc + el
    if aAcc < 0.2 then return end
    aAcc = 0
    if not aCD or not aDone then return end
    local mode, reason = "UNKNOWN", "API_UNCONFIRMED"
    local okM = pcall(function()
        local info = C_Spell.GetSpellCooldown(SPELL_A)
        if type(info) ~= "table" then return end
        local enabled = publicA(info.isEnabled, "boolean")
        if enabled == nil then return end
        if enabled == false then
            mode, reason = "HOLD", "DISABLED"
            return
        end
        local d = C_Spell.GetSpellCooldownDuration(SPELL_A, true)
        if type(d) == "nil" then
            -- 已有本技能有效且 enabled 的信息，成功查询却无计时对象：
            -- 按老板本轮明确的“没有自身倒计时就 OK”候选规则显示。
            -- info 缺失、禁用、方法抛错均不会走到这里。
            mode, reason = "READY", "NO_SPELL_DURATION"
            return
        end
        aMuteDone = true
        local okF = pcall(function()
            aCD:SetHideCountdownNumbers(false)
            aCD:SetCooldownFromDurationObject(d)
            aDone:SetText("OK")
            aDone:SetShown(true)
            paintADuration(d)
        end)
        aMuteDone = false
        if not okF then error("duration display failed") end
        aCurrentDuration, aEngineArmed = d, true
        -- ENGINE 只表示原生控件负责显示；不伪称 Lua 已解出 secret 状态。
        mode, reason = "ENGINE", "CURRENT_DURATION"
    end)
    if not okM then
        mode, reason = "UNKNOWN", "DURATION_API_OR_RENDER_ERROR"
        note("A1 当前冷却查询/显示失败")
    end
    if mode ~= state.aMode or reason ~= state.aReason then
        state.aLog = state.aLog or {}
        table.insert(state.aLog, string.format("%s %s→%s reason=%s",
            date("%H:%M:%S"), tostring(state.aMode), mode, reason))
        if #state.aLog > 10 then table.remove(state.aLog, 1) end
    end
    state.aMode, state.aReason, state.aStartClass = mode, reason, "ENGINE_ONLY"
    if mode == "READY" then showAStatus("OK")
    elseif mode == "HOLD" then showAStatus("—")
    elseif mode == "UNKNOWN" then showAStatus("?") end
end

-- 逐帧只更新上次成功取得的计时对象的 alpha，不逐帧查询 API/重喂数字。
-- 即使完成通知丢失，原生计时到期后也能在下一帧补 OK。
local function tickAReadyDisplay()
    if not aCurrentDuration then return end
    local ok = pcall(paintADuration, aCurrentDuration)
    if not ok then
        state.aMode, state.aReason = "UNKNOWN", "DURATION_ALPHA_ERROR"
        showAStatus("?")
        note("A1 原生计时显隐失败")
    end
end

local aRefreshPending = false
requestARefresh = function()
    state.aRefreshRequests = (state.aRefreshRequests or 0) + 1
    if aRefreshPending then return end
    aRefreshPending = true
    feedA(1)
end

-- ---------- B1：目标DoT（01C v0.97 管线搬移 + 底板出按钮子树改行框自绘） ----------
-- 健康角标只读公开初始化/格式元数据，不判定aura存在，不读取按钮显隐。
-- v1.22：A2独立充能provider，当前层数只原样喂字体，回充只喂引擎duration。
local A2 = {slotKey="tentacle1227280", spellID=1227280, kind="spell_charges",
    specID=258, variantPolicy="BASE_ONLY_REJECT_OVERRIDE", formatID="CHARGES_AND_RECHARGE_V3"}
local a2Row, a2Icon, a2Name, a2CountFS, a2CountStateFS, a2CD, a2StatusFS, a2HealthFS
local a2Source, a2Feeding = nil, false
local a2RefreshPending, a2Elapsed = true, 0
state.a2Profile, state.a2CountMode, state.a2RechargeMode = "UNKNOWN", "UNKNOWN", "UNKNOWN"
state.a2Format, state.a2SpellID = A2.formatID, A2.spellID

local function paintA2Health()
    if not a2HealthFS then return end
    local unknown = state.a2Profile == "UNKNOWN" or state.a2CountMode == "UNKNOWN" or
        state.a2RechargeMode == "UNKNOWN" or state.a2Info ~= "PUBLIC_METADATA"
    a2HealthFS:SetText(unknown and "!" or "")
end

local function clearA2Recharge(text)
    if not (a2CD and a2StatusFS) then return false end
    a2Feeding = true
    -- 不让一个Clear异常跳过其他撤销手段；仅操作自有Cooldown。
    local okAlpha = pcall(a2CD.SetAlpha, a2CD, 0)
    local okHide = pcall(a2CD.SetHideCountdownNumbers, a2CD, true)
    local okClear = pcall(a2CD.Clear, a2CD)
    local okText = pcall(function() a2StatusFS:SetText(text or "?"); a2StatusFS:SetAlpha(1); a2StatusFS:Show() end)
    a2Feeding = false
    return okAlpha and okHide and okClear and okText
end

local function clearA2(reason)
    if a2CountFS then paintDashCountState(a2CountFS, a2CountStateFS, "?") end
    clearA2Recharge("?")
    state.a2CountMode, state.a2RechargeMode = "UNKNOWN", "UNKNOWN"
    state.a2CountReason, state.a2RechargeReason = reason, reason
    paintA2Health()
end

local function confirmA2Identity()
    local reason = "METADATA_ERROR"
    local ok = pcall(function()
        reason = "OVERRIDE_UNCONFIRMED"
        local effective = publicA(C_Spell.GetOverrideSpell(A2.spellID), "number")
        if effective == nil then error("override unconfirmed") end
        reason = "UNSUPPORTED_OVERRIDE"
        if effective ~= A2.spellID then error("override not supported") end
        reason = "SPELL_INFO_UNCONFIRMED"
        local info = C_Spell.GetSpellInfo(effective)
        if type(info) ~= "table" then error("metadata missing") end
        local name, icon = publicA(info.name, "string"), publicA(info.iconID, "number")
        if name == nil or icon == nil then error("metadata unconfirmed") end
        a2Name:SetText(name)
        a2Icon:SetTexture(icon)
    end)
    state.a2Info = ok and "PUBLIC_METADATA" or "UNKNOWN"
    if not ok then
        pcall(a2Name.SetText, a2Name, "触须?")
        pcall(a2Icon.SetTexture, a2Icon, nil)
    end
    return ok, reason
end

local function updateA2()
    if not state.a2LayoutReady then return end
    if (state.a2EventFailed or 0) > 0 then clearA2("EVENT_REG_FAILED"); return end
    if not a2Source then
        if state.a2Profile ~= "NOT_LEARNED" then clearA2("NO_CONFIRMED_SOURCE") end
        return
    end
    local okIdentity, identityReason = confirmA2Identity()
    if not okIdentity then clearA2(identityReason); return end
    -- 此门只确认技能来源，不判断次数、回充或能否施放。
    local okKnown, known = pcall(function() return publicA(C_SpellBook.IsSpellKnown(a2Source), "boolean") end)
    if not okKnown or known ~= true then clearA2("SPELL_KNOWN_UNCONFIRMED_OR_FALSE"); return end
    local okCountClear = paintDashCountState(a2CountFS, a2CountStateFS, "?")
    local okRechargeClear = clearA2Recharge("?")
    state.a2CountMode, state.a2RechargeMode = "UNKNOWN", "UNKNOWN"
    state.a2CountReason, state.a2RechargeReason = "CHARGES_QUERY_OR_TYPE_ERROR", "CHARGE_DURATION_ERROR"
    -- 两格独立读取；层数查询失败也不把有效duration判无效。
    local okInfo, info = pcall(function() return C_Spell.GetSpellCharges(a2Source) end)
    if okInfo and type(info) == "table" then
        local okValue, count = pcall(function() return info.currentCharges end)
        if okCountClear and okValue and type(count) == "number" then
            local okFormat = pcall(function()
                a2CountFS:SetFormattedText("%d", count)
                a2CountStateFS:SetText("")
            end)
            if okFormat then
                state.a2CountMode, state.a2CountReason = "VALUE", "CURRENT_CHARGES_FORMATTED"
            else
                paintDashCountState(a2CountFS, a2CountStateFS, "?")
                state.a2CountReason = "COUNT_FORMAT_ERROR"
            end
        else
            state.a2CountReason = okCountClear and "COUNT_QUERY_OR_TYPE_ERROR" or "COUNT_CLEAR_ERROR"
        end
    end
    if not okRechargeClear then
        state.a2RechargeReason = "RECHARGE_CLEAR_ERROR"
    elseif state.a2RechargeStyle ~= "INTEGER_SECONDS_READY" then
        state.a2RechargeReason = "RECHARGE_STYLE_UNAVAILABLE"
    else
        local okDuration, duration = pcall(function() return C_Spell.GetSpellChargeDuration(a2Source) end)
        if okDuration and (type(duration) == "table" or type(duration) == "userdata") then
            a2Feeding = true
            local reason = "CHARGE_DURATION_FEED_ERROR"
            local okFeed = pcall(function()
                -- 与已认可A1相同：原生IsActive的bool只原样送两次alpha setter。
                -- 不读Charges.isActive，不对active做if/not/比较，不从时长判断次数。
                reason = "DURATION_NATIVE_ACTIVE_ERROR"
                local active = duration:IsActive()
                if type(active) ~= "boolean" then error("native active type unsupported") end
                reason = "CHARGE_DURATION_FEED_ERROR"
                a2CD:SetHideCountdownNumbers(false)
                a2CD:SetCooldownFromDurationObject(duration)
                a2CD:Show()
                a2StatusFS:SetText("OK")
                a2StatusFS:Show()
                reason = "DURATION_NATIVE_ALPHA_ERROR"
                a2CD:SetAlphaFromBoolean(active, 1, 0)
                a2StatusFS:SetAlphaFromBoolean(active, 0, 1)
            end)
            a2Feeding = false
            if okFeed then
                -- 不缓存/诊断原生active；活动或已结束均只登记同一个引擎通道模式。
                state.a2RechargeMode, state.a2RechargeReason = "ENGINE_DURATION", "NATIVE_DURATION_AND_ALPHA"
            else
                clearA2Recharge("?")
                state.a2RechargeReason = reason
            end
        end
    end
    paintA2Health()
end


local function refreshA2Profile()
    a2Source = nil
    state.a2Profile = "UNKNOWN"
    clearA2("PROFILE_REFRESH")
    if not state.a2LayoutReady then return end
    if InCombatLockdown() then
        state.a2ProfilePending = true
        return
    end
    state.a2ProfilePending = false
    local okSpec, spec = pcall(function()
        local index = publicA(C_SpecializationInfo.GetSpecialization(), "number")
        if index == nil then return nil end
        return publicA(C_SpecializationInfo.GetSpecializationInfo(index), "number")
    end)
    a2Row:Show()
    if not okSpec or spec == nil or spec == 0 then
        state.a2ProfileReason = "SPEC_UNCONFIRMED"; return
    end
    if spec ~= A2.specID then
        a2Row:Hide()
        state.a2Profile, state.a2ProfileReason = "NOT_CONFIGURED", "SPEC_NOT_CONFIGURED"
        return
    end
    -- 先排除未支持替换，避免替换后的基础技能known=false被误记未学习。
    local okIdentity, identityReason = confirmA2Identity()
    if not okIdentity then state.a2ProfileReason = identityReason; clearA2(identityReason); return end
    local okKnown, known = pcall(function() return publicA(C_SpellBook.IsSpellKnown(A2.spellID), "boolean") end)
    if not okKnown or known == nil then state.a2ProfileReason = "SPELL_KNOWN_UNCONFIRMED"; return end
    if known == false then
        state.a2Profile, state.a2ProfileReason = "NOT_LEARNED", "PUBLIC_SPELL_NOT_KNOWN"
        a2Name:SetText("触须")
        a2Icon:SetTexture(nil)
        if not paintDashCountState(a2CountFS, a2CountStateFS, "NA") then error("COUNT_STATE_RENDER_ERROR") end
        clearA2Recharge("-")
        state.a2Info, state.a2CountMode, state.a2RechargeMode = "NOT_LEARNED", "NOT_LEARNED", "NOT_LEARNED"
        state.a2CountReason, state.a2RechargeReason = "PUBLIC_SPELL_NOT_KNOWN", "PUBLIC_SPELL_NOT_KNOWN"
        if a2HealthFS then a2HealthFS:SetText("") end
        return
    end
    state.a2Profile, state.a2ProfileReason = "SHADOW_TENTACLE", "SPEC_AND_SPELL_CONFIRMED"
    a2Source = A2.spellID
    updateA2()
end

local function createA2Row(bd)
    if InCombatLockdown() or state.a2LayoutAttempted then return end
    state.a2LayoutAttempted = true
    local row
    local ok = pcall(function()
        row = CreateFrame("Frame", "Dash01RowA2", win, "BackdropTemplate")
        row:SetSize(134, 34)
        row:SetPoint("TOPLEFT", aRow, "BOTTOMLEFT", 0, -4)
        row:SetBackdrop(bd); row:SetBackdropColor(0.02, 0.02, 0.02, 1)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24); icon:SetPoint("LEFT", 4, 0)
        local name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        name:SetPoint("LEFT", row, "LEFT", 32, 0); name:SetWidth(36)
        local font, _, flags = name:GetFont()
        name:SetFont(font, 8, flags); name:SetWordWrap(false); name:SetJustifyH("LEFT"); name:SetText("触须?")
        local function cell(x, width, label)
            local f = CreateFrame("Frame", nil, row, "BackdropTemplate")
            f:SetSize(width, 30); f:SetPoint("LEFT", row, "LEFT", x, 0)
            f:SetBackdrop(bd); f:SetBackdropColor(0.02, 0.02, 0.02, 1)
            local caption = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            local path, _, fl = caption:GetFont()
            caption:SetFont(path, 6, fl); caption:SetPoint("BOTTOM", 0, 2); caption:SetText(label)
            return f
        end
        local countCell, rechargeCell = cell(70, 24, "CHG"), cell(96, 36, "RCH")
        local countFS = countCell:CreateFontString(nil, "OVERLAY", dashNumberTemplate)
        countFS:SetPoint("CENTER", 0, 4); countFS:SetText("")
        local countStateFS = countCell:CreateFontString(nil, "OVERLAY", dashCountStateTemplate)
        countStateFS:SetPoint("CENTER", 0, 4); countStateFS:SetText("?")
        local cd = CreateFrame("Cooldown", "Dash01CooldownA2", rechargeCell, "CooldownFrameTemplate")
        cd:SetAllPoints(rechargeCell); cd:SetDrawSwipe(false); cd:SetDrawBling(false); cd:SetDrawEdge(false)
        cd:SetHideCountdownNumbers(true); cd:SetAlpha(0); cd.noCooldownCount = true
        local okStyle = pcall(function()
            cd:SetCountdownFont(dashNumberTemplate)
            local fs = cd:GetCountdownFontString()
            fs:ClearAllPoints(); fs:SetPoint("CENTER", rechargeCell, "CENTER", 0, 4)
            local fmt = C_StringUtil.CreateNumericRuleFormatter()
            fmt:SetBreakpoints({{threshold=0, format="%d", step=1, rounding=Enum.NumericRuleFormatRounding.Up}})
            cd:SetCountdownFormatter(fmt)
            cd:SetMinimumCountdownDuration(0)
        end)
        state.a2RechargeStyle = okStyle and "INTEGER_SECONDS_READY" or "UNAVAILABLE"
        local okHook = pcall(function() cd:HookScript("OnCooldownDone", function()
            -- 完成通知只请求重新查询，绝不擅自给层数+1。
            if not a2Feeding then a2RefreshPending = true end
        end) end)
        state.a2CompletionHook = okHook and "REGISTERED" or "POLL_FALLBACK"
        local statusFS = rechargeCell:CreateFontString(nil, "OVERLAY", dashNumberTemplate)
        statusFS:SetPoint("CENTER", 0, 4); statusFS:SetText("?")
        local healthFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        healthFS:SetFont(font, 7, flags); healthFS:SetPoint("BOTTOMLEFT", 32, 2)
        healthFS:SetTextColor(1, 0.3, 0.3); healthFS:SetText("!")
        a2Row, a2Icon, a2Name = row, icon, name
        a2CountFS, a2CountStateFS, a2CD, a2StatusFS, a2HealthFS = countFS, countStateFS, cd, statusFS, healthFS
        recordDashCountFontBinding("A2", countFS, countStateFS)
        state.a2LayoutReady = true
    end)
    if not ok then
        state.a2LayoutReady, state.a2LayoutReason = false, "CONSTRUCTION_ERROR_RELOAD_REQUIRED"
        if row then pcall(row.Hide, row) end
        note("A2框体未构建：reload后重试，A1/B/C保持")
    end
end


-- v1.29：新普通CD槽独立实例；不迁移/改写已认可A1或A2充能provider。
local function paintACDHealth(slot)
    if not slot.healthFS then return end
    -- 次数故障由次数格问号表达；只有问号清空/绘制也失败时才保留结构故障保护。
    slot.healthFS:SetText((slot.status.mode == "UNKNOWN" or
        (slot.status.countHealth == "ERROR" and not slot.status.countErrorShown)) and "!" or "")
end

local function clearACDSlot(slot, text, mode, reason)
    slot.duration = nil
    slot.feeding = true
    local okA = pcall(slot.cd.SetAlpha, slot.cd, 0)
    local okH = pcall(slot.cd.SetHideCountdownNumbers, slot.cd, true)
    local okC = pcall(slot.cd.Clear, slot.cd)
    local okT = pcall(function() slot.statusFS:SetText(text); slot.statusFS:SetAlpha(1) end)
    local okU = true
    if slot.unavailableFS then okU = pcall(slot.unavailableFS.SetAlpha, slot.unavailableFS, 0) end
    local okN = true
    if slot.countFS then
        okN = paintDashCountState(slot.countFS, slot.countStateFS, text)
        slot.status.countSource = "NOT_QUERIED"
        slot.status.countHealth = mode == "INACTIVE" and "INACTIVE" or "UNKNOWN"
    end
    slot.feeding = false
    slot.status.mode = (okA and okH and okC and okT and okU and okN) and mode or "UNKNOWN"
    slot.status.reason = (okA and okH and okC and okT and okU and okN) and reason or "CLEAR_ERROR"
    paintACDHealth(slot)
end

-- v1.32：A6只跟踪形态基础CD，明确允许已核对的齐射替换；A3/A4/A5不放宽。
local function resolveFixedBaseIdentity(slot)
    local reason = "BASE_IDENTITY_UNCONFIRMED"
    local ok = pcall(function()
        local effective = publicA(C_Spell.GetOverrideSpell(slot.spellID), "number")
        if effective == nil then error("override unconfirmed") end
        if effective ~= slot.spellID and not slot.allowedOverrides[effective] then
            reason = "UNSUPPORTED_OVERRIDE"; error("override unsupported")
        end
        local known = publicA(C_SpellBook.IsSpellKnown(slot.spellID), "boolean")
        if known == nil then error("known unconfirmed") end
        if not known and effective == slot.spellID then reason = "NOT_LEARNED"; return end
        local info = C_Spell.GetSpellInfo(slot.spellID)
        if type(info) ~= "table" then error("base metadata missing") end
        local name, icon = publicA(info.name, "string"), publicA(info.iconID, "number")
        if not name or not icon then error("base metadata not public") end
        slot.nameFS:SetText(name); slot.icon:SetTexture(icon)
        reason = "FIXED_BASE_CD_DECLARED_REPLACEMENT"
    end)
    if not ok then
        pcall(slot.nameFS.SetText, slot.nameFS, slot.expectedName .. "?")
        pcall(slot.icon.SetTexture, slot.icon, nil)
        return nil, reason
    end
    if reason == "NOT_LEARNED" then
        pcall(slot.nameFS.SetText, slot.nameFS, slot.expectedName)
        pcall(slot.icon.SetTexture, slot.icon, nil)
        return nil, reason
    end
    return slot.spellID, reason
end

-- v1.37：仅次数改用官方冷却面板的技能cast count入口；状态/动作匹配/布局保持，适用性待真机。
local function updateA7ActionCount(slot)
    local reason = "ACTION_SEARCH_ERROR"
    local ok = pcall(function()
        local actions = C_ActionBar.FindSpellActionButtons(slot.baseSpellID)
        if type(actions) == "nil" then reason = "NO_BASE_ACTION_BUTTON"; error("no action") end
        actions = publicA(actions, "table")
        if not actions then reason = "ACTION_LIST_UNCONFIRMED"; error("action list not public") end
        reason = "NO_CONFIRMED_BASE_ACTION"
        for _, rawAction in ipairs(actions) do
            local action = publicA(rawAction, "number")
            if action then
                local spell = publicA(C_ActionBar.GetSpell(action), "number")
                if spell == slot.baseSpellID or spell == slot.spellID then
                    reason = "SPELL_CAST_COUNT_QUERY_ERROR"
                    local countValue = C_Spell.GetSpellCastCount(slot.spellID)
                    if type(countValue) ~= "number" then error("spell cast count type unsupported") end
                    reason = "SPELL_CAST_COUNT_RENDER_ERROR"
                    slot.countFS:SetFormattedText("%d", countValue)
                    slot.countStateFS:SetText("")
                    -- 数值只type后直喂整数格式；不比较/计算/回填/缓存/日志/SV。
                    reason = "SPELL_CAST_COUNT_NUMBER_FORMATTED"
                    return
                end
            end
        end
        error("no confirmed action identity")
    end)
    slot.status.countSource = reason
    slot.status.countHealth = ok and "ENGINE_BOUND_NOT_VALUE_VERIFIED" or "ERROR"
    slot.status.countErrorShown = false
    if not ok then
        slot.status.countErrorShown = paintDashCountState(slot.countFS, slot.countStateFS, "?")
    end
end

local function updateConditionalUses(slot)
    local reason = "USES_METADATA_UNCONFIRMED"
    local ok = pcall(function()
        local info = C_Spell.GetSpellInfo(slot.spellID)
        if type(info) ~= "table" then error("uses metadata missing") end
        local name, icon = publicA(info.name, "string"), publicA(info.iconID, "number")
        if not name or not icon then error("uses metadata not public") end
        slot.nameFS:SetText(name); slot.icon:SetTexture(icon)
        slot.status.countSource = "NOT_QUERIED"
        reason = "CURRENT_OVERRIDE_UNCONFIRMED"
        local effective = publicA(C_Spell.GetOverrideSpell(slot.baseSpellID), "number")
        if effective == nil then error("current override not public") end
        if effective == slot.baseSpellID then
            clearACDSlot(slot, "—", "INACTIVE", "CURRENT_BASE_BUTTON_NOT_VOLLEY")
            return
        end
        if effective ~= slot.spellID then
            reason = "UNSUPPORTED_CURRENT_OVERRIDE"; error("current override unsupported")
        end
        reason = "USES_SURFACE_RESET_ERROR"
        clearACDSlot(slot, "?", "UNKNOWN", "USES_PREPARE")
        if slot.status.reason ~= "USES_PREPARE" or not slot.countFS then error("uses surface reset failed") end
        -- 次数读取失败不改已确认的状态；两格各自表达，避免空文本覆盖OK。
        reason = "CURRENT_REPLACEMENT_RENDER_ERROR"
        slot.statusFS:SetText("OK"); slot.statusFS:SetAlpha(1)
        slot.status.mode = "ENGINE_TRIGGER_OK"
        slot.status.reason = "CURRENT_DECLARED_REPLACEMENT"
        updateA7ActionCount(slot)
        paintACDHealth(slot)
    end)
    if not ok then
        pcall(slot.nameFS.SetText, slot.nameFS, slot.expectedName .. "?")
        clearACDSlot(slot, "?", "UNKNOWN", reason)
    end
end

local function resolveACDIdentity(slot)
    if slot.variantPolicy == "FIXED_BASE_ALLOW_DECLARED_OVERRIDE" then return resolveFixedBaseIdentity(slot) end
    local reason, effective = "SPELL_KNOWN_UNCONFIRMED", nil
    local ok = pcall(function()
        local known = publicA(C_SpellBook.IsSpellKnown(slot.spellID), "boolean")
        if known == nil then error("known unconfirmed") end
        if not known then reason = "NOT_LEARNED"; return end
        reason = "OVERRIDE_UNCONFIRMED"
        effective = publicA(C_Spell.GetOverrideSpell(slot.spellID), "number")
        if effective == nil then error("override unconfirmed") end
        reason = "UNSUPPORTED_OVERRIDE"
        if effective ~= slot.spellID then error("override unsupported") end
        reason = "SPELL_METADATA_UNCONFIRMED"
        local info = C_Spell.GetSpellInfo(effective)
        if type(info) ~= "table" then error("metadata missing") end
        local name, icon = publicA(info.name, "string"), publicA(info.iconID, "number")
        if not name or not icon then error("metadata not public") end
        slot.nameFS:SetText(name); slot.icon:SetTexture(icon)
        reason = "PUBLIC_BASE_SPELL"
    end)
    if not ok then
        pcall(slot.nameFS.SetText, slot.nameFS, slot.expectedName .. "?")
        pcall(slot.icon.SetTexture, slot.icon, nil)
        return nil, reason
    end
    if reason == "NOT_LEARNED" then
        pcall(slot.nameFS.SetText, slot.nameFS, slot.expectedName)
        pcall(slot.icon.SetTexture, slot.icon, nil)
        return nil, reason
    end
    return effective, reason
end

local function paintACDNative(slot)
    -- 原生active可能保密；只检查类型并原样送两个alpha setter，绝不进Lua分支。
    local active = slot.duration:IsActive()
    if type(active) ~= "boolean" then error("native active type unsupported") end
    slot.cd:SetAlphaFromBoolean(active, 1, 0)
    slot.statusFS:SetAlphaFromBoolean(active, 0, 1)
end

local function updateACDSlot(slot)
    if not slot.status.layoutReady then return end
    if state.acdEventFailed ~= 0 then clearACDSlot(slot, "?", "UNKNOWN", "EVENT_REG_FAILED"); return end
    if slot.status.profile == "NOT_CONFIGURED" then return end
    if slot.status.profile == "UNKNOWN" then clearACDSlot(slot, "?", "UNKNOWN", "SPEC_UNCONFIRMED"); return end
    if slot.kind == "conditional_spell_uses" then updateConditionalUses(slot); return end
    -- 此处只确认当前公开技能身份/学习状态，不从次数或时长判断能否施放。
    local spellID, identityReason = resolveACDIdentity(slot)
    if not spellID then
        local unlearned = identityReason == "NOT_LEARNED"
        clearACDSlot(slot, unlearned and "NA" or "?", unlearned and "NOT_LEARNED" or "UNKNOWN", identityReason)
        return
    end
    if slot.status.style ~= "INTEGER_UP_READY" then clearACDSlot(slot, "?", "UNKNOWN", "STYLE_UNAVAILABLE"); return end
    local reason = "COOLDOWN_QUERY_ERROR"
    local ok = pcall(function()
        local info = C_Spell.GetSpellCooldown(spellID)
        if type(info) ~= "table" then error("cooldown metadata missing") end
        reason = "ENABLED_UNCONFIRMED"
        local enabled = publicA(info.isEnabled, "boolean")
        if enabled == nil then error("enabled unconfirmed") end
        if not enabled then clearACDSlot(slot, "—", "HOLD", "DISABLED"); return end
        reason = "DURATION_QUERY_ERROR"
        local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
        if type(duration) == "nil" then
            -- 与A1口径一致：已确认技能/enabled，成功查询却没有自身duration时显示OK。
            clearACDSlot(slot, "OK", "READY", "NO_SPELL_DURATION")
            return
        end
        if type(duration) ~= "table" and type(duration) ~= "userdata" then error("duration type unsupported") end
        reason = "DURATION_FEED_ERROR"
        slot.duration = nil
        slot.feeding = true
        local okFeed = pcall(function()
            slot.cd:SetHideCountdownNumbers(false)
            slot.cd:SetCooldownFromDurationObject(duration)
            slot.duration = duration
            slot.statusFS:SetText("OK")
            paintACDNative(slot)
        end)
        slot.feeding = false
        if not okFeed then error("native duration render failed") end
        slot.status.mode, slot.status.reason = "ENGINE", "CURRENT_NATIVE_DURATION"
    end)
    if not ok then clearACDSlot(slot, "?", "UNKNOWN", reason) end
    paintACDHealth(slot)
end

local function refreshACDProfiles()
    if not win or not state.shell then return end
    local spec
    local ok = pcall(function()
        local index = publicA(GetSpecialization(), "number")
        if index then spec = publicA(GetSpecializationInfo(index), "number") end
    end)
    for _, slot in ipairs(A_CD_SLOTS) do
        if slot.status.layoutReady then
            clearACDSlot(slot, "?", "UNKNOWN", "PROFILE_REFRESH")
            slot.status.profile = (ok and spec and spec ~= 0) and
                (spec == slot.specID and "CONFIGURED" or "NOT_CONFIGURED") or "UNKNOWN"
            if not InCombatLockdown() then
                if slot.status.profile == "NOT_CONFIGURED" then slot.row:Hide() else slot.row:Show() end
            end
            if slot.status.profile == "NOT_CONFIGURED" then
                clearACDSlot(slot, "NA", "NOT_CONFIGURED", "SPEC_NOT_CONFIGURED")
            else
                updateACDSlot(slot)
            end
        end
    end
end

local function createACDRows(bd)
    if InCombatLockdown() then return end
    for _, slot in ipairs(A_CD_SLOTS) do
        local st = slot.status
        if not st.layoutAttempted then
            st.layoutAttempted = true
            local ok, err = pcall(function()
                local row = CreateFrame("Frame", nil, win, "BackdropTemplate")
                slot.row = row
                row:SetSize(134, 34); row:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -dashRowTop(slot.order))
                row:SetBackdrop(bd); row:SetBackdropColor(0.02, 0.02, 0.02, 1)
                local icon = row:CreateTexture(nil, "ARTWORK")
                slot.icon = icon
                icon:SetSize(30, 30); icon:SetPoint("LEFT", 4, 0)
                local nameFS = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                slot.nameFS = nameFS
                nameFS:SetPoint("LEFT", icon, "RIGHT", 4, 0); nameFS:SetPoint("RIGHT", row, "RIGHT", -48, 0)
                local font, _, flags = nameFS:GetFont()
                nameFS:SetFont(font, 9, flags); nameFS:SetWordWrap(false); nameFS:SetJustifyH("LEFT")
                nameFS:SetText(slot.expectedName .. "?")
                local cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
                cell:SetSize(42, 30); cell:SetPoint("RIGHT", -2, 0)
                cell:SetBackdrop(bd); cell:SetBackdropColor(0.02, 0.02, 0.02, 1)
                local numberFont = dashNumberTemplate
                if slot.kind == "conditional_spell_uses" then
                    -- 与A2同宽同高，计数USE不冒充自动回充CHG；RDY保留已验状态。
                    icon:SetSize(24, 24)
                    nameFS:ClearAllPoints(); nameFS:SetPoint("LEFT", row, "LEFT", 32, 0)
                    nameFS:SetWidth(36); nameFS:SetFont(font, 8, flags)
                    cell:SetSize(36, 30)
                    local countCell = CreateFrame("Frame", nil, row, "BackdropTemplate")
                    countCell:SetSize(24, 30); countCell:SetPoint("LEFT", row, "LEFT", 70, 0)
                    countCell:SetBackdrop(bd); countCell:SetBackdropColor(0.02, 0.02, 0.02, 1)
                    slot.countFS = countCell:CreateFontString(nil, "OVERLAY", numberFont)
                    slot.countFS:SetPoint("CENTER", 0, 4); slot.countFS:SetText("")
                    slot.countStateFS = countCell:CreateFontString(nil, "OVERLAY", dashCountStateTemplate)
                    slot.countStateFS:SetPoint("CENTER", 0, 4); slot.countStateFS:SetText("?")
                    recordDashCountFontBinding(slot.slotKey, slot.countFS, slot.countStateFS)
                    for _, item in ipairs({{countCell, "USE"}, {cell, "RDY"}}) do
                        local caption = item[1]:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                        local p, _, f = caption:GetFont()
                        caption:SetFont(p, 6, f); caption:SetPoint("BOTTOM", 0, 2); caption:SetText(item[2])
                    end
                end
                local cd = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
                slot.cd = cd
                cd:SetAllPoints(cell); cd:SetDrawSwipe(false); cd:SetDrawBling(false); cd:SetDrawEdge(false)
                cd:SetHideCountdownNumbers(true); cd:SetAlpha(0); cd.noCooldownCount = true
                local okStyle = pcall(function()
                    cd:SetCountdownFont(numberFont)
                    local fs = cd:GetCountdownFontString()
                    fs:ClearAllPoints(); fs:SetPoint("CENTER", cell, "CENTER")
                    local fmt = C_StringUtil.CreateNumericRuleFormatter()
                    fmt:SetBreakpoints({{threshold=0,format="%d",step=1,rounding=Enum.NumericRuleFormatRounding.Up}})
                    cd:SetCountdownFormatter(fmt); cd:SetMinimumCountdownDuration(0)
                end)
                st.style = slot.kind == "conditional_spell_uses" and "NATIVE_SPELL_CAST_COUNT_SEPARATE_STATE_V6" or
                    (okStyle and "INTEGER_UP_READY" or "UNAVAILABLE")
                local okHook = pcall(cd.HookScript, cd, "OnCooldownDone", function()
                    if not slot.feeding then acdRefreshPending = true end
                end)
                st.completionHook = okHook and "REGISTERED" or "POLL_FALLBACK"
                slot.statusFS = cell:CreateFontString(nil, "ARTWORK", numberFont)
                slot.statusFS:SetAllPoints(cell); slot.statusFS:SetText("?")
                if slot.countFS then
                    slot.statusFS:ClearAllPoints(); slot.statusFS:SetPoint("CENTER", 0, 4)
                end
                slot.healthFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                slot.healthFS:SetFont(font, 7, flags); slot.healthFS:SetPoint("BOTTOMLEFT", 38, 2)
                slot.healthFS:SetTextColor(1, 0.3, 0.3); slot.healthFS:SetText("!")
                st.layoutReady = true
            end)
            if not ok then
                st.layoutReady, st.mode, st.reason = false, "UNKNOWN", "LAYOUT_ERROR_RELOAD_REQUIRED"
                note("A3布局失败: " .. tostring(err))
                if slot.row then pcall(slot.row.Hide, slot.row) end
            end
        end
    end
end


local function paintBHealth(slot)
    if not slot.healthFS then return end
    local st = slot.status
    if not st.slotOk or not st.unitOk or not st.initComplete or
       not st.nameBound or not st.durationFaultDisplayReady or st.candidateReset == "ERROR" or st.rescan == "ERROR" then
        slot.healthFS:SetText("!")
        slot.healthFS:SetTextColor(1, 0.3, 0.3)
    else
        slot.healthFS:SetText("")
    end
end

local function buildRuleFormatter(slotState)
    slotState = slotState or state
    local ok, f = pcall(function()
        local fmt = C_StringUtil.CreateNumericRuleFormatter()
        local Down = Enum.NumericRuleFormatRounding.Down
        fmt:SetBreakpoints({
            { threshold = 0,    format = "%d",  step = 1, rounding = Down },
            { threshold = 60,   format = "%dm", step = 1, rounding = Down, components = { { div = 60 } } },
            { threshold = 3600, format = "%dh", step = 1, rounding = Down, components = { { div = 3600 } } },
        })
        return fmt
    end)
    if ok and f then
        slotState.fmtGrade = "rule"
        return f
    end
    return nil
end

-- v1.45：只在合法初始化回调创建自有数字格挡板，继承实际光环按钮生命周期。
-- 不读按钮显隐、不读秒数；即使绑定部分成功后抛错，后续原生更新也不能露出旧数。
local function prepareDurationFaultDisplay(slot, button)
    local st = slot.status
    st.durationFaultDisplayReady = false
    slot.durationFaultDisplays = slot.durationFaultDisplays or {}
    local surface = slot.durationFaultDisplays[button]
    if not surface then
        local mask = CreateFrame("Frame", nil, button, "BackdropTemplate")
        -- 先登记再配置：同按钮重试继续覆盖同一个半成品，不叠加遗留问号。
        surface = { mask=mask }
        slot.durationFaultDisplays[button] = surface
    end
    local mask = surface.mask
    slot.durationFaultMask = mask
    mask:SetAlpha(1)
    mask:SetFrameLevel(button:GetFrameLevel() + 1)
    mask:SetFrameStrata("HIGH")
    mask:SetPoint("TOPLEFT", slot.cell, "TOPLEFT", 2, -2)
    mask:SetPoint("BOTTOMRIGHT", slot.cell, "BOTTOMRIGHT", -2, 2)
    mask:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"})
    mask:SetBackdropColor(0.02, 0.02, 0.02, 1)
    mask:EnableMouse(false)
    if not surface.text then surface.text = mask:CreateFontString(nil, "OVERLAY", dashNumberTemplate) end
    surface.text:SetPoint("CENTER", slot.cell, "CENTER")
    surface.text:SetText("?")
end

local function finishDurationFaultDisplay(slot)
    -- 只有规定格式成功绑定才撤下数字格挡板；异常格保持问号。
    slot.durationFaultMask:SetAlpha(slot.status.durationBound and 0 or 1)
    slot.status.durationFaultDisplayReady = true
end

local function registerDurationText(button, fs, slotState)
    slotState = slotState or state
    slotState.fmtGrade = "none"
    slotState.durationErrorReason = "FORMATTER_CREATE_OR_CONFIG_ERROR"
    local fmt = buildRuleFormatter(slotState)
    if fmt then
        slotState.durationErrorReason = "DURATION_TEXT_BIND_ERROR"
        if pcall(button.SetDurationText, button, fs, { textFormatter = fmt }) then
            slotState.durationErrorReason = nil
            return true
        end
    end
    slotState.fmtGrade = "none"
    return false
end

local function makeBInitializer(slot)
    local row, cell, st = slot.row, slot.cell, slot.status
    return function(button)
        slot.button = button
        if slot.order == 1 then bAuraBtn = button; state.btnCaptured = true end
        st.btnCaptured, st.initComplete = true, false
        st.durationBound, st.durationFaultDisplayReady = false, false
        st.initCount = (st.initCount or 0) + 1
        local ok, err = pcall(function()

        -- P2-1（外审）：框线层级以按钮实际层级为基准（此前猜容器+5，可能没真盖住）
        if slot.border then
            local okL, lvl = pcall(button.GetFrameLevel, button)
            if okL and lvl then
                slot.border:SetFrameLevel(lvl + 1)
                slot.healthHost:SetFrameLevel(lvl + 2)
            end
        end

        -- P0-1定案：盒底不在按钮子树里（bRow 自绘），按钮只画内容
        button:SetSize(slot.width, slot.height)
        button:SetAllPoints(row)
        pcall(button.SetMouseClickEnabled, button, false)
        pcall(button.SetMouseMotionEnabled, button, false)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(30, 30)
        icon:SetPoint("LEFT", 4, 0)
        button:SetIcon(icon)

        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        pcall(function() cd:SetDrawSwipe(false) end)
        pcall(function() cd:SetDrawBling(false) end)
        pcall(function() cd:SetDrawEdge(false) end)
        pcall(function() cd:SetHideCountdownNumbers(true) end)
        button:SetDurationCooldown(cd)

        -- v1.00-S1：数字格轮廓改常亮、建在自有行（bCellBase，见 ensureShell）——任务书§五
        -- "无 aura 时数字格轮廓仍在"；绑定文本留在按钮后代（本跨层锚点=WC button:SetAllPoints
        -- (proxy) 同款先例）。空槽=格底在、无文字；不冒充存在也不冒充 absence。

        -- B-1（Codex 审核）：名称绑引擎实际匹配对象（SetSpellName），禁固定"暗言术：痛"
        -- 标签贴到别的 aura 上（fail-open 降级时会撒谎）；空槽时名称随按钮隐藏，不冒充存在
        local nameFS = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        nameFS:SetPoint("RIGHT", button, "RIGHT", -48, 0)
        nameFS:SetJustifyH("LEFT")
        local nameFont, _, nameFlags = nameFS:GetFont()
        if nameFont then nameFS:SetFont(nameFont, 9, nameFlags) end
        pcall(function() nameFS:SetWordWrap(false) end)
        st.nameBound = pcall(button.SetSpellName, button, nameFS)
        if not st.nameBound then
            -- 绑定失败兜底：显示配置的槽位预期名（并标注为预期，非实际 aura）
            nameFS:SetText(slot.expectedName .. "?")
            note(slot.slotKey .. " SetSpellName 绑定失败，名称退化为预期标签")
        end

        local stackFS = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        stackFS:SetPoint("TOP", icon, "TOP", 0, 6)
        pcall(button.SetApplicationCount, button, stackFS, {})

        -- 格3：倒计时（引擎格式化，整秒）。文本留在按钮后代（SetSpellName/时长绑定合法域），
        -- 视觉位置对准 bRow 上的常亮格底 bCellBase（跨层锚点=WC button:SetAllPoints(proxy) 同款）
        local durFS = button:CreateFontString(nil, "OVERLAY", dashNumberTemplate)
        durFS:SetPoint("CENTER", cell, "CENTER")
        pcall(function() durFS:SetJustifyH("CENTER") end)
        prepareDurationFaultDisplay(slot, button)
        st.durationBound = registerDurationText(button, durFS, st)
        finishDurationFaultDisplay(slot)
        if not st.durationBound then
            note(slot.slotKey .. " 秒数不可用，显示问号: " .. st.durationErrorReason)
        end
        end)
        st.initComplete = ok
        if not ok then st.lastErr = "INITIALIZER_ERROR_RELOAD_REQUIRED"; note(slot.slotKey .. " 初始化失败: " .. tostring(err)) end
        if slot.order == 1 then state.fmtGrade = st.fmtGrade end
        paintBHealth(slot)
    end
end

-- v1.26：D只画player增益；独立容器/状态，ABC的target/CD/资源provider不变。
local function paintDHealth(slot)
    local st = slot.status
    local bad = state.dProfile ~= "SHADOW_CONFIGURED" or state.dEventFailed ~= 0 or
        not state.dLayoutReady or not st.slotOk or not st.unitOk or not st.initComplete or
        not st.nameBound or not st.iconBound or not st.durationFaultDisplayReady or
        st.candidateReset ~= "OK" or st.rescan ~= "OK" or state.dEnabled ~= "YES"
    -- 自有挡板仅改alpha：错误/未知不让旧引擎数字冒充有效；不读或修改按钮显隐。
    if slot.mask then slot.mask:SetAlpha(bad and 1 or 0) end
    if not slot.healthFS then return end
    if bad then
        slot.healthFS:SetText("!"); slot.healthFS:SetTextColor(1, 0.3, 0.3)
    else
        slot.healthFS:SetText("")
    end
end

local function registerDText(button, fs, st)
    st.fmtGrade = "none"
    st.durationErrorReason = "FORMATTER_CREATE_OR_CONFIG_ERROR"
    local ok, fmt = pcall(function()
        local f = C_StringUtil.CreateNumericRuleFormatter()
        f:SetBreakpoints({{threshold=0, format="%d", step=1, rounding=Enum.NumericRuleFormatRounding.Up}})
        return f
    end)
    if ok and fmt then
        st.durationErrorReason = "DURATION_TEXT_BIND_ERROR"
        if pcall(button.SetDurationText, button, fs, {textFormatter=fmt}) then
            st.fmtGrade = "rule_up"; st.durationErrorReason = nil; return true
        end
    end
    return false
end

local function makeDInitializer(slot)
    local row, cell, st = slot.row, slot.cell, slot.status
    return function(button)
        slot.button = button
        st.btnCaptured, st.initComplete = true, false
        st.durationBound, st.durationFaultDisplayReady = false, false
        st.initCount = (st.initCount or 0) + 1
        -- 几何仅在引擎初始化回调合法域；不在日常刷新/诊断中读写引擎按钮。
        local ok, err = pcall(function()
            local lvl = button:GetFrameLevel()
            slot.border:SetFrameLevel(lvl + 1)
            slot.mask:SetFrameLevel(lvl + 2)
            slot.healthHost:SetFrameLevel(lvl + 3)
            button:SetSize(slot.width, slot.height); button:SetAllPoints(row)
            pcall(button.SetMouseClickEnabled, button, false)
            pcall(button.SetMouseMotionEnabled, button, false)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetSize(30, 30); icon:SetPoint("LEFT", 4, 0)
            st.iconBound = pcall(button.SetIcon, button, icon)
            local nameFS = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameFS:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            nameFS:SetPoint("RIGHT", button, "RIGHT", -48, 0)
            nameFS:SetJustifyH("LEFT")
            local font, _, flags = nameFS:GetFont()
            if font then nameFS:SetFont(font, 9, flags) end
            nameFS:SetWordWrap(false)
            st.nameBound = pcall(button.SetSpellName, button, nameFS)
            local durFS = button:CreateFontString(nil, "OVERLAY", dashNumberTemplate)
            durFS:SetPoint("CENTER", cell, "CENTER"); durFS:SetJustifyH("CENTER")
            prepareDurationFaultDisplay(slot, button)
            st.durationBound = registerDText(button, durFS, st)
            finishDurationFaultDisplay(slot)
        end)
        st.initComplete = ok
        if not ok then st.lastErr = "INITIALIZER_ERROR_RELOAD_REQUIRED"; note(slot.slotKey .. " 初始化失败: " .. tostring(err)) end
        paintDHealth(slot)
    end
end

local function createDLayout(bd)
    if InCombatLockdown() or state.dLayoutAttempted then return end
    state.dLayoutAttempted = true
    -- v1.38：按公开order固定排布；与A/B同排对齐，provider及引擎绑定不变。
    for _, slot in ipairs(D_SLOTS) do
        local row = CreateFrame("Frame", nil, win, "BackdropTemplate")
        slot.row = row
        row:SetSize(slot.width, slot.height); row:SetPoint("TOPLEFT", win, "TOPLEFT", 436, -dashRowTop(slot.order))
        row:SetBackdrop(bd); row:SetBackdropColor(0.02, 0.02, 0.02, 1)
        local cell = CreateFrame("Frame", nil, row, "BackdropTemplate")
        slot.cell = cell
        cell:SetSize(42, slot.cellHeight or 36); cell:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        cell:SetBackdrop(bd); cell:SetBackdropColor(0.02, 0.02, 0.02, 1)
        local border = CreateFrame("Frame", nil, row, "BackdropTemplate")
        slot.border = border
        border:SetAllPoints(row); border:SetBackdrop(bd); border:SetBackdropColor(0, 0, 0, 0)
        border:EnableMouse(false)
        local mask = CreateFrame("Frame", nil, row, "BackdropTemplate")
        slot.mask = mask
        mask:SetAllPoints(row); mask:SetBackdrop(bd); mask:SetBackdropColor(0.02, 0.02, 0.02, 1)
        mask:SetFrameStrata("HIGH"); mask:EnableMouse(false)
        local expected = mask:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        expected:SetPoint("LEFT", row, "LEFT", 38, 0); expected:SetWidth(48)
        local font, _, flags = expected:GetFont()
        expected:SetFont(font, 9, flags); expected:SetWordWrap(false); expected:SetText(slot.expectedName .. "?")
        local unknown = mask:CreateFontString(nil, "OVERLAY", dashNumberTemplate)
        unknown:SetPoint("CENTER", cell, "CENTER"); unknown:SetText("?")
        local healthHost = CreateFrame("Frame", nil, row)
        slot.healthHost = healthHost
        healthHost:SetAllPoints(row); healthHost:SetFrameStrata("HIGH"); healthHost:EnableMouse(false)
        local health = healthHost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        slot.healthFS = health
        health:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 38, 2)
        health:SetFont(font, 7, flags); health:SetTextColor(1, 0.3, 0.3); health:SetText("!")
    end
    dSeparator = win:CreateTexture(nil, "OVERLAY")
    dSeparator:SetColorTexture(1, 1, 1, 1); dSeparator:SetWidth(2)
    dSeparator:SetPoint("TOPLEFT", win, "TOPLEFT", 431, -20)
    dSeparator:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 431, 18)
    state.dLayoutReady = true
end

local function initDContainer()
    if InCombatLockdown() or not state.dLayoutReady then return end
    if not dContainer then
        local okL, loaded = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
        local okQ, ready = pcall(C_AddOns.IsAddOnLoaded, "Blizzard_AuraContainer")
        if not ((okL and publicA(loaded, "boolean") == true) or (okQ and publicA(ready, "boolean") == true)) then
            state.dEngine = "LOAD_ERROR"; return
        end
        -- 部分创建失败不重复造帧；重新加载后才重试。引擎载入失败仍可按事件重试。
        if state.dContainerAttempted then return end
        state.dContainerAttempted = true
        local okC, err = pcall(function()
            dContainer = CreateFrame("AuraContainer", nil, D_SLOTS[1].row, "CustomAuraContainerTemplate")
            dContainer:SetPoint("TOPLEFT", D_SLOTS[1].row, "TOPLEFT"); dContainer:SetSize(1, 1)
            dContainer:SetEnabled(false)
            dContainer:SetUnit("player")
        end)
        state.dContainerReady = okC
        if not okC then state.dEngine = "CONTAINER_ERROR_RELOAD_REQUIRED"; note("D容器失败: " .. tostring(err)); return end
    end
    if not state.dContainerReady then return end
    for _, slot in ipairs(D_SLOTS) do
        local st = slot.status
        if not st.slotOk and not st.addAttempted then
            st.addAttempted = true
            local okS, err = pcall(function()
                dContainer:AddAuraSlot(slot.slotKey, slot.filter, {
                    candidateFilters={includeSpellIDs={[slot.spellID]=true}, excludeSpellIDs={}},
                    initializeFrame=makeDInitializer(slot),
                })
            end)
            st.slotOk = okS
            if not okS then st.lastErr = "ADD_SLOT_ERROR_RELOAD_REQUIRED"; note(slot.slotKey .. " 注册失败: " .. tostring(err)) end
        end
    end
    state.dEngine = "REGISTERED_NOT_PRESENCE"
end

local function repoolD(enabled)
    state.dEnabled = "NO"
    if dContainer and state.dContainerReady then
        local okU = pcall(dContainer.SetUnit, dContainer, "player")
        local filtersOK = true
        for _, slot in ipairs(D_SLOTS) do
            local st = slot.status
            st.unitOk = okU
            if st.slotOk then
                -- HELPFUL/player的身份过滤由引擎支持；未知/不配置时空include map撤销旧来源。
                local include = enabled and {[slot.spellID]=true} or {}
                local okS = pcall(dContainer.SetAuraSlotCandidateFilters, dContainer, slot.slotKey,
                    {includeSpellIDs=include, excludeSpellIDs={}})
                st.candidateReset = okS and "OK" or "ERROR"
                if not okS then filtersOK = false end
            end
        end
        local okE = pcall(dContainer.SetEnabled, dContainer, enabled and okU and filtersOK)
        local okR = pcall(dContainer.UpdateAllAuras, dContainer)
        if enabled and okU and filtersOK and okE and okR then
            state.dEnabled, state.dEngine = "YES", "REGISTERED_NOT_PRESENCE"
        end
        if not okE or not okR or not filtersOK or not okU then
            state.dEngine = "REBIND_ERROR"
            -- 停用也失败时，自有未知挡板仍覆盖旧内容；不假称清空成功。
            state.dDisableFallback = pcall(dContainer.SetEnabled, dContainer, false) and "REQUESTED" or "ERROR"
        end
        for _, slot in ipairs(D_SLOTS) do slot.status.rescan = okR and "OK" or "ERROR" end
    end
    for _, slot in ipairs(D_SLOTS) do paintDHealth(slot) end
end

local function refreshDProfile()
    if not win or not state.shell then return end
    -- profile只按公开暗影专精配置；不以IsSpellKnown(BUFF_ID)判不存在。
    -- 暗影其他英雄天赋仍保留D1空槽；未来天赋精确开关另批核实。
    local specID
    local ok = pcall(function()
        local index = publicA(GetSpecialization(), "number")
        if index then specID = publicA(GetSpecializationInfo(index), "number") end
    end)
    state.dProfile = ok and specID and (specID == 258 and "SHADOW_CONFIGURED" or "NOT_CONFIGURED") or "UNKNOWN"
    if not InCombatLockdown() then
        local visible = state.dProfile ~= "NOT_CONFIGURED"
        win:SetWidth(visible and 578 or 436)
        for _, slot in ipairs(D_SLOTS) do if visible then slot.row:Show() else slot.row:Hide() end end
        if dSeparator then if visible then dSeparator:Show() else dSeparator:Hide() end end
        state.dLayoutPending = false
        state.dColumn = visible and "VISIBLE" or "HIDDEN"
        initDContainer()
        if refreshDashSettings then refreshDashSettings() end
    else
        state.dLayoutPending = true
    end
    repoolD(state.dProfile == "SHADOW_CONFIGURED" and state.dEventFailed == 0)
    saveDashState()
end


-- ---------- C1：目标血量%（新管线，任务书v2 §二） ----------
local function updateHP()
    if not cFS then return end
    local reason = "HP_API_ERROR"
    local ok = pcall(function()
        -- 先消除旧目标的百分比；成功后只让引擎写入新值。
        cFS:SetText("?")
        state.cMode, state.cReason = "UNKNOWN", "UPDATING"
        reason = "EXISTS_UNREADABLE"
        local exists = publicA(UnitExists("target"), "boolean")
        if exists == nil then error("target existence unconfirmed") end
        if exists == false then
            cFS:SetText("NT")
            state.cMode, state.cReason = "NO_TARGET", "NO_TARGET"
            return
        end
        reason = "DEATH_UNREADABLE"
        local dead = publicA(UnitIsDead("target"), "boolean")
        if dead == nil then error("target death unconfirmed") end
        if dead == true then
            cFS:SetText("0")
            state.cMode, state.cReason = "DEAD", "CONFIRMED_DEAD"
            return
        end
        reason = "CURVE_MISSING"
        local curve
        if type(CurveConstants) == "table" then curve = CurveConstants.ScaleTo100 end
        if type(curve) == "nil" then error("health curve missing") end
        reason = "PERCENT_QUERY_ERROR"
        local pct = UnitHealthPercent("target", false, curve)
        -- type 是唯一的消费门；秘密数值原样喂引擎，不做判真、比较、格式化后判断或落 SV。
        reason = "PERCENT_TYPE_UNSUPPORTED"
        if type(pct) ~= "number" then error("health result is not numeric") end
        reason = "PERCENT_FORMAT_ERROR"
        cFS:SetFormattedText("%d", pct)
        state.cMode, state.cReason = "ACTUAL", "ACTUAL_FORMATTED"
    end)
    if not ok then
        state.cMode, state.cReason = "UNKNOWN", reason
        pcall(function() cFS:SetText("?") end)
        note("C1 未确认：" .. reason)
    end
end

-- v1.17 批3：资源槽配置只放公开元数据，不缓存当前值/上限。
-- C3=false 是第二资源的配置位置，本批不创建/渲染 C3 或其他职业资源。
local COMBAT_RESOURCE_PROFILES = {
    [258] = {
        C2 = { unit = "player", powerType = 13, powerToken = "INSANITY",
            label = "INS" },
        C3 = false,
    },
}

local function clearCombatResource()
    if c2CurrentFS then pcall(c2CurrentFS.SetText, c2CurrentFS, "?") end
    if c2MaxFS then pcall(c2MaxFS.SetText, c2MaxFS, "?") end
    state.c2CurrentMode, state.c2MaxMode = "UNKNOWN", "UNKNOWN"
    state.c2CurrentReason, state.c2MaxReason = "NO_CONFIRMED_PROFILE", "NO_CONFIRMED_PROFILE"
end

local function writeCombatResourceValue(fs, query, profile)
    -- 每次先清旧值；不把查询失败、类型错误、格式化失败当成有效0。
    local okClear = pcall(fs.SetText, fs, "?")
    if not okClear then return false, "CLEAR_ERROR" end
    if type(query) ~= "function" then return false, "API_MISSING" end
    local okQuery, value = pcall(query, profile.unit, profile.powerType, false)
    if not okQuery then return false, "QUERY_ERROR" end
    -- 唯一消费门：type。保密数值原样传引擎，不比较/算术/floor/转字符串/落SV。
    if type(value) ~= "number" then return false, "TYPE_UNSUPPORTED" end
    local okFormat = pcall(fs.SetFormattedText, fs, "%d", value)
    if not okFormat then
        pcall(fs.SetText, fs, "?")
        return false, "FORMAT_ERROR"
    end
    return true, "VALUE_FORMATTED"
end

local function updateCombatResource()
    if not (c2CurrentFS and c2MaxFS) then return end
    if (state.c2EventFailed or 0) > 0 then
        clearCombatResource()
        state.c2CurrentReason, state.c2MaxReason = "EVENT_REG_FAILED", "EVENT_REG_FAILED"
        return
    end
    if not activeCombatResource then
        clearCombatResource()
        return
    end
    -- 两格独立查询/格式化；最大值不写死，也不从当前值反推。
    local okCurrent, currentReason = writeCombatResourceValue(c2CurrentFS, UnitPower, activeCombatResource)
    local okMax, maxReason = writeCombatResourceValue(c2MaxFS, UnitPowerMax, activeCombatResource)
    state.c2CurrentMode = okCurrent and "VALUE" or "UNKNOWN"
    state.c2MaxMode = okMax and "VALUE" or "UNKNOWN"
    state.c2CurrentReason, state.c2MaxReason = currentReason, maxReason
end

local function refreshCombatResourceProfile()
    if not (win and c2Row) then return end
    -- 专精切换时先撤销旧来源。战斗中不重设宿主高度/资源行显隐，脱战恢复。
    activeCombatResource = nil
    clearCombatResource()
    state.c2Profile = "UNKNOWN"
    if InCombatLockdown() then
        state.c2ProfilePending = true
        c2LabelFS:SetText("RES?")
        return
    end
    state.c2ProfilePending = false
    local specID
    local okSpec = pcall(function()
        if type(C_SpecializationInfo) ~= "table" then return end
        local index = publicA(C_SpecializationInfo.GetSpecialization(), "number")
        if index == nil then return end
        specID = publicA(C_SpecializationInfo.GetSpecializationInfo(index), "number")
    end)
    if not okSpec or specID == nil or specID == 0 then
        -- 未确认专精保留可见?，不伪装成没有资源或没有配置。
        c2LabelFS:SetText("RES?")
        c2Row:Show()
        win:SetHeight(DASH_HEIGHT)
        state.c2ProfileReason = "SPEC_UNCONFIRMED"
        return
    end
    local profile = COMBAT_RESOURCE_PROFILES[specID]
    if not profile then
        c2LabelFS:SetText("RES")
        c2Row:Hide()
        win:SetHeight(DASH_HEIGHT)
        state.c2Profile, state.c2ProfileReason = "NOT_CONFIGURED", "SPEC_NOT_CONFIGURED"
        return
    end
    activeCombatResource = profile.C2
    c2LabelFS:SetText(activeCombatResource.label)
    c2Row:Show()
    win:SetHeight(DASH_HEIGHT)
    state.c2Profile, state.c2ProfileReason = "SHADOW_INSANITY", "SPEC_CONFIRMED"
    updateCombatResource()
end

-- v1.14 批1：只给自有外壳增加锁定，不读写引擎 aura 按钮。
-- 每次加载默认锁定；解锁仅用于当前调整，拖完自动锁定。
local lockMenu, windowTag
local windowDragging, windowPositionPending = false, false
state.windowLocked = true

local function paintWindowLock(locked)
    state.windowLocked = locked
    if windowTag then windowTag:SetText(locked and "Dash01 L16 [锁定]" or "Dash01 L16 [解锁]") end
end

local function stopWindowDrag()
    -- 沿用既有纪律：StopMoving 无条件执行；战斗中不读取/保存几何。
    if win then win:StopMovingOrSizing() end
    if windowDragging then
        if InCombatLockdown() then
            windowPositionPending = true
        else
            saveDashPos()
        end
    end
    windowDragging = false
    paintWindowLock(true)
    if refreshDashSettings then refreshDashSettings() end
end

local function setWindowLocked(locked)
    if InCombatLockdown() then
        print("|cff66ccff[Dash01]|r 战斗中不能调整锁定或位置")
        if lockMenu then lockMenu:Hide() end
        return
    end
    if locked then stopWindowDrag() end
    paintWindowLock(locked)
    if lockMenu then lockMenu:Hide() end
    print(locked and "|cff66ccff[Dash01]|r 已锁定" or
        "|cff66ccff[Dash01]|r 已解锁：左键拖动标题区域，松开后自动锁定")
end

local function toggleLockMenu(_, button)
    if button ~= "RightButton" then return end
    if InCombatLockdown() then
        if lockMenu then lockMenu:Hide() end
        print("|cff66ccff[Dash01]|r 战斗中不能调整锁定或位置")
        return
    end
    if lockMenu then lockMenu:SetShown(not lockMenu:IsShown()) end
end

-- v1.18 批4A：独立Canvas设置页。所有数值都是公开配置/自有几何，
-- 不读引擎 aura 按钮，也不参与 A/B/C1/C2 秘密数据的查询或渲染。
local settingsPanel, settingsCategory, settingsStatus
local settingsFontEdit
local settingsEdits, settingsButtons = {}, {}
local setupDashSettings

local function settingsMessage(message)
    if settingsStatus then settingsStatus:SetText(message) end
end

local function readDashWindowControls()
    if InCombatLockdown() or not win then return nil end
    local ok, controls = pcall(function()
        local cx, cy = win:GetCenter()
        local ux, uy = UIParent:GetCenter()
        cx, cy = finitePosition(cx), finitePosition(cy)
        ux, uy = finitePosition(ux), finitePosition(uy)
        local ws = finitePosition(win:GetEffectiveScale())
        local us = finitePosition(UIParent:GetEffectiveScale())
        if cx == nil or cy == nil or ux == nil or uy == nil or ws == nil or us == nil then return nil end
        if ws <= 0 or us <= 0 then return nil end
        local scale = finitePosition(ws / us)
        local x = finitePosition(cx * ws / us - ux)
        local y = finitePosition(cy * ws / us - uy)
        if scale == nil or x == nil or y == nil then return nil end
        return {scale=scale, x=x, y=y}
    end)
    if not ok then return nil end
    return controls
end

refreshDashSettings = function()
    if not settingsPanel or not state.settingsRegistered then return end
    local blocked = InCombatLockdown()
    local enabled = not blocked and win ~= nil
    for _, edit in ipairs(settingsEdits) do
        if enabled then edit:Enable() else edit:Disable(); edit:ClearFocus() end
    end
    for _, button in ipairs(settingsButtons) do button:SetEnabled(enabled) end
    if settingsFontEdit then
        if enabled then settingsFontEdit:Enable() else settingsFontEdit:Disable(); settingsFontEdit:ClearFocus() end
    end
    if blocked then
        settingsMessage("战斗中无法调整，脱战后再操作。")
        return
    end
    if not win or not state.shell then
        settingsMessage("当前角色的仪表盘尚未完成加载。")
        return
    end
    local controls = readDashWindowControls()
    if not controls then
        for _, button in ipairs(settingsButtons) do button:Disable() end
        settingsMessage("当前位置暂未确认，请稍后重新打开设置。")
        return
    end
    -- 输入以公开UI坐标显示；保存仍用原有窗口单位的中心偏移格式。
    settingsEdits[1]:SetText(string.format("%.2f", controls.scale * 100))
    settingsEdits[2]:SetText(string.format("%.2f", controls.x))
    settingsEdits[3]:SetText(string.format("%.2f", controls.y))
    settingsFontEdit:SetText(state.numberFontSize and tostring(state.numberFontSize) or "默认")
    if state.numberFontMode ~= "READABLE" then
        settingsMessage("自定义字号未生效；当前使用默认字体。原因可用/dash查看。")
    else
        settingsMessage("实际数字字号" .. tostring(state.numberFontSize) .. "；大小和位置单独应用。")
    end
end

local function applyDashWindowControls(scale, x, y)
    -- 必须先挡战斗，连自有宿主几何也不采集；不排队延后套用输入。
    if InCombatLockdown() then return false, "战斗中无法调整，脱战后再操作。" end
    if not win then return false, "当前角色的仪表盘尚未启用。" end
    scale, x, y = finitePosition(scale), finitePosition(x), finitePosition(y)
    if scale == nil or scale < 0.5 or scale > 1.5 then return false, "整体大小请输入50至150。" end
    if x == nil or y == nil or math.abs(x) > 4000 or math.abs(y) > 4000 then
        return false, "位置请输入-4000至4000之间的数字。"
    end
    local d = type(MindBlastBox01DB) == "table" and MindBlastBox01DB.dash
    if type(d) ~= "table" then return false, "设置存档尚未就绪。" end
    stopWindowDrag()
    local previous = readDashWindowControls()
    if not previous then return false, "当前位置暂未确认，未改动窗口。" end
    local previousPos = d.pos
    local function place(s, px, py)
        win:SetScale(s)
        win:ClearAllPoints()
        -- UIParent坐标换为窗口单位；整体大小改变时中心位置保持一致。
        win:SetPoint("CENTER", UIParent, "CENTER", px / s, py / s)
    end
    local ok = pcall(place, scale, x, y)
    if ok then
        saveDashPos()
        ok = state.posStatus == "SAVED"
    end
    if not ok then
        d.pos = previousPos
        local restored = pcall(place, previous.scale, previous.x, previous.y)
        state.settingsApply = restored and "RESTORED_AFTER_ERROR" or "RESTORE_ERROR"
        note("大小/位置应用未确认：" .. state.settingsApply)
        return false, "应用失败，已尝试恢复原位置和大小。"
    end
    d.scale = scale
    state.windowScale, state.scaleRestore, state.settingsApply = scale, "SAVED", "APPLIED"
    saveDashState()
    if refreshDashSettings then refreshDashSettings() end
    return true, "已应用并保存。窗口靠近屏幕边缘时会自动保持在屏幕内。"
end

local function readSettingsNumber(edit)
    local text = publicA(edit:GetText(), "string")
    if text == nil then return nil end
    return finitePosition(tonumber(text))
end

setupDashSettings = function()
    if state.settingsRegistered then return true end
    if state.settingsRegistrationFailed then return false end
    if InCombatLockdown() then state.settingsStatus = "DEFERRED_COMBAT"; return false end
    if type(Settings) ~= "table" or type(Settings.RegisterCanvasLayoutCategory) ~= "function" or
        type(Settings.RegisterAddOnCategory) ~= "function" then
        state.settingsStatus = "API_PENDING"
        return false
    end
    local ok, err = pcall(function()
        settingsPanel = CreateFrame("Frame", "Dash01SettingsPanel", UIParent)
        settingsPanel.name = "DASH"
        settingsPanel:Hide()
        local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 20, -20)
        title:SetText("DASH · 大小、位置与数字字号")
        local help = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", 20, -52)
        help:SetPoint("TOPRIGHT", -20, -52)
        help:SetJustifyH("LEFT")
        help:SetText("先调整数字字号，整体大小可保持原值。位置从屏幕中心计算；改变大小时保持中心位置。")
        local labels = {"整体大小（50%～150%）", "水平位置（右＋ / 左－）", "垂直位置（上＋ / 下－）"}
        for i, labelText in ipairs(labels) do
            local label = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            label:SetPoint("TOPLEFT", 20, -92 - (i-1)*48)
            label:SetText(labelText)
            local edit = CreateFrame("EditBox", nil, settingsPanel, "InputBoxTemplate")
            edit:SetSize(130, 28)
            edit:SetPoint("TOPLEFT", 250, -86 - (i-1)*48)
            edit:SetAutoFocus(false)
            edit:SetMaxLetters(16)
            edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            settingsEdits[i] = edit
        end
        local function button(label, x, width, callback)
            local b = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
            b:SetSize(width, 28)
            b:SetPoint("TOPLEFT", x, -250)
            b:SetText(label)
            b:SetScript("OnClick", callback)
            settingsButtons[#settingsButtons+1] = b
        end
        button("应用", 20, 90, function()
            if InCombatLockdown() then settingsMessage("战斗中无法调整，脱战后再操作。"); return end
            local percent = readSettingsNumber(settingsEdits[1])
            local x, y = readSettingsNumber(settingsEdits[2]), readSettingsNumber(settingsEdits[3])
            if percent == nil then settingsMessage("整体大小请输入50至150。"); return end
            local _, message = applyDashWindowControls(percent / 100, x, y)
            settingsMessage(message)
        end)
        button("读取当前位置", 122, 130, function() refreshDashSettings() end)
        button("恢复默认大小和位置", 264, 180, function()
            local _, message = applyDashWindowControls(1, 240, 160)
            settingsMessage(message)
        end)
        settingsStatus = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        settingsStatus:SetPoint("TOPLEFT", 20, -298)
        settingsStatus:SetPoint("TOPRIGHT", -20, -298)
        settingsStatus:SetJustifyH("LEFT")
        local fontLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fontLabel:SetPoint("TOPLEFT", 20, -350)
        fontLabel:SetText("数字字号（16～20，单独调整）")
        settingsFontEdit = CreateFrame("EditBox", nil, settingsPanel, "InputBoxTemplate")
        settingsFontEdit:SetSize(130, 28); settingsFontEdit:SetPoint("TOPLEFT", 250, -344)
        settingsFontEdit:SetAutoFocus(false); settingsFontEdit:SetMaxLetters(2)
        settingsFontEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local fontButton = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
        fontButton:SetSize(160, 28); fontButton:SetPoint("TOPLEFT", 20, -388)
        fontButton:SetText("应用数字字号")
        fontButton:SetScript("OnClick", function()
            if InCombatLockdown() then settingsMessage("战斗中无法调整，脱战后再操作。"); return end
            local d = type(MindBlastBox01DB) == "table" and MindBlastBox01DB.dash
            if type(d) ~= "table" then settingsMessage("设置存档尚未就绪。"); return end
            local okFont, message = configureDashNumberSize(readSettingsNumber(settingsFontEdit))
            if okFont then
                d.numberFontSize = state.numberFontSize
                state.numberFontRestore = "SAVED"
            end
            saveDashState(); refreshDashSettings()
            settingsMessage(message)
        end)
        settingsButtons[#settingsButtons+1] = fontButton
        local footer = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        footer:SetPoint("TOPLEFT", 20, -436)
        footer:SetPoint("TOPRIGHT", -20, -436)
        footer:SetJustifyH("LEFT")
        footer:SetText("右键仪表盘解锁，拖动标题后自动锁定并保存。数字字号只改变文字；恢复默认大小和位置不会改数字字号。")
        settingsPanel:SetScript("OnShow", function() refreshDashSettings() end)
        settingsPanel:SetScript("OnHide", function()
            for _, edit in ipairs(settingsEdits) do edit:ClearFocus() end
            if settingsFontEdit then settingsFontEdit:ClearFocus() end
        end)
        settingsPanel.OnRefresh = function() refreshDashSettings() end
        settingsCategory = Settings.RegisterCanvasLayoutCategory(settingsPanel, "DASH")
        Settings.RegisterAddOnCategory(settingsCategory)
    end)
    if not ok then
        state.settingsStatus, state.settingsRegistrationFailed = "REGISTER_ERROR", true
        note("DASH设置页初始化失败：" .. tostring(err))
        return false
    end
    state.settingsRegistered, state.settingsStatus = true, "REGISTERED"
    return true
end

local function openDashSettings()
    if InCombatLockdown() then print("|cff66ccff[DASH]|r 战斗中请先脱战再调整"); return end
    if not setupDashSettings() then print("|cff66ccff[DASH]|r 设置页暂未就绪，/dash 可查状态"); return end
    local ok = pcall(function() Settings.OpenToCategory(settingsCategory:GetID()) end)
    if not ok then print("|cff66ccff[DASH]|r 请从ESC→选项→插件→DASH打开") end
end

-- v1.15 批2：三个不变色/不闪烁的自有定位图形，仅供未来视觉端定位。
-- 黑底白图，三个图案不同；出现图形不代表数据健康或旧视觉端已支持。
-- 此构造函数仅在脱战 ensureShell 创建期调用，不查询任何引擎按钮。
local function createDashLocator(parent, name, pattern)
    local locator = CreateFrame("Frame", name, parent)
    locator:SetSize(16, 16)
    locator:EnableMouse(false)
    local bg = locator:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(locator)
    bg:SetColorTexture(0, 0, 0, 1)
    local function whiteRect(width, height, x, y)
        local texture = locator:CreateTexture(nil, "ARTWORK")
        texture:SetSize(width, height)
        texture:SetPoint("TOPLEFT", x, -y)
        texture:SetColorTexture(1, 1, 1, 1)
    end
    if pattern == "SQUARE" then
        whiteRect(8, 8, 4, 4)
    elseif pattern == "L" then
        whiteRect(3, 10, 3, 3)
        whiteRect(10, 3, 3, 10)
    elseif pattern == "BARS" then
        whiteRect(10, 3, 3, 3)
        whiteRect(10, 3, 3, 9)
    end
    return locator
end

-- ---------- 外壳（常亮，可拖动带战斗门，位置 SV 持久化） ----------
local function buildDashShell()
    prepareDashNumberFont()
    win = CreateFrame("Frame", "Dash01Window", UIParent, "BackdropTemplate")
    win:Hide()
    win:SetSize(436, DASH_HEIGHT)
    local initialScale = loadDashScale()
    win:SetScale(initialScale)
    win:SetPoint("CENTER", UIParent, "CENTER", 240 / initialScale, 160 / initialScale)
    -- v0.99：老板要求可拖动。战斗门照抄 01C proxy 同款（P0-4：引擎宿主战斗中写几何=BLOCKED）
    -- 本插件窗位由自己的 SV 管理；不删除或编辑客户端布局缓存。
    local okOwner = pcall(function() win:SetDontSavePosition(true) end)
    state.posOwner = okOwner and "PLUGIN_SV" or "UNCONFIRMED"
    if not okOwner then note("窗位持久化设置未确认") end
    win:SetMovable(true)
    win:EnableMouse(true)
    -- 自有透明点击层接收框体右键；不改变 A/B/C1 或引擎按钮显隐/几何。
    local mouseSurface = CreateFrame("Frame", "Dash01MouseSurface", win)
    mouseSurface:SetAllPoints(win)
    mouseSurface:SetFrameLevel(win:GetFrameLevel() + 10)
    mouseSurface:EnableMouse(true)
    mouseSurface:SetScript("OnMouseUp", toggleLockMenu)
    win:SetScript("OnMouseUp", toggleLockMenu)

    local titleHit = CreateFrame("Frame", "Dash01TitleHit", mouseSurface)
    titleHit:SetPoint("TOPLEFT")
    titleHit:SetPoint("TOPRIGHT")
    titleHit:SetHeight(14)
    titleHit:EnableMouse(true)
    titleHit:RegisterForDrag("LeftButton")
    titleHit:SetScript("OnMouseUp", toggleLockMenu)
    titleHit:SetScript("OnDragStart", function()
        if InCombatLockdown() or state.windowLocked then return end
        if lockMenu then lockMenu:Hide() end
        win:StartMoving()
        windowDragging = true
    end)
    titleHit:SetScript("OnDragStop", stopWindowDrag)

    -- 两个简单按钮；全部尺寸/锚点在脱战 ensureShell 创建期设好。
    lockMenu = CreateFrame("Frame", "Dash01LockMenu", win, "BackdropTemplate")
    lockMenu:SetSize(136, 68)
    lockMenu:SetPoint("TOPLEFT", win, "TOPRIGHT", 4, 0)
    lockMenu:SetFrameStrata("DIALOG")
    lockMenu:SetFrameLevel(win:GetFrameLevel() + 30)
    lockMenu:SetClampedToScreen(true)
    lockMenu:EnableMouse(true)
    lockMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 13,
    })
    lockMenu:SetBackdropColor(0.05, 0.05, 0.08, 1)
    local lockButton = CreateFrame("Button", nil, lockMenu, "UIPanelButtonTemplate")
    lockButton:SetSize(120, 24)
    lockButton:SetPoint("TOP", 0, -8)
    lockButton:SetText("锁定")
    lockButton:SetScript("OnClick", function() setWindowLocked(true) end)
    local unlockButton = CreateFrame("Button", nil, lockMenu, "UIPanelButtonTemplate")
    unlockButton:SetSize(120, 24)
    unlockButton:SetPoint("TOP", lockButton, "BOTTOM", 0, -4)
    unlockButton:SetText("解锁")
    unlockButton:SetScript("OnClick", function() setWindowLocked(false) end)
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "Dash01LockMenu")
    end
    lockMenu:Hide()
    -- 旧数组和旧 point 格式仍可读取；非法存档不清除当前默认锚点。
    local dbDash
    if type(MindBlastBox01DB) == "table" then dbDash = MindBlastBox01DB.dash end
    if type(dbDash) == "table" and type(dbDash.pos) ~= "nil" then
        local p = validatedPosition(dbDash.pos)
        if not p then
            state.posStatus = "RESTORE_INVALID"
            note("存档窗位格式无效：使用默认位置，保留原存档")
        else
            local okRest = pcall(function()
                win:ClearAllPoints()
                win:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
            end)
            if okRest then
                state.posStatus = "RESTORED"
                print("|cff66ccff[Dash01]|r 已应用存档窗位: " .. describePosition(p))
            else
                state.posStatus = "RESTORE_ERROR"
                local okDefault = pcall(function()
                    win:ClearAllPoints()
                    win:SetPoint("CENTER", UIParent, "CENTER", 240 / initialScale, 160 / initialScale)
                end)
                if not okDefault then state.posStatus = "DEFAULT_ERROR" end
                note("窗位恢复失败：已尝试默认位置，原存档保留")
            end
        end
    else
        state.posStatus = "DEFAULT"
    end
    win:SetClampedToScreen(true)
    win:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 13,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    win:SetBackdropColor(0, 0, 0, 1)

    local tag = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tag:SetPoint("TOPLEFT", 26, -2)
    windowTag = tag
    paintWindowLock(true)

    local bd = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    }

    -- A1 行（01B 搬移：图标/名称/正方形数字格+引擎自绘/OK）
    aRow = CreateFrame("Frame", "Dash01RowA", win, "BackdropTemplate")
    aRow:SetSize(134, 40)
    aRow:SetPoint("TOPLEFT", 8, -20)
    aRow:SetBackdrop(bd)
    aRow:SetBackdropColor(0.02, 0.02, 0.02, 1)
    aIcon = aRow:CreateTexture(nil, "ARTWORK")
    aIcon:SetSize(30, 30)
    aIcon:SetPoint("LEFT", 4, 0)
    aName = aRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    aName:SetPoint("LEFT", aIcon, "RIGHT", 4, 0)
    aName:SetPoint("RIGHT", aRow, "RIGHT", -48, 0)
    aName:SetJustifyH("LEFT")
    local aNameFont, _, aNameFlags = aName:GetFont()
    if aNameFont then aName:SetFont(aNameFont, 9, aNameFlags) end
    pcall(function() aName:SetWordWrap(false) end)
    aName:SetText("加载中")
    aCell = CreateFrame("Frame", "Dash01CellA", aRow, "BackdropTemplate")
    aCell:SetSize(42, 36)
    aCell:SetPoint("RIGHT", -2, 0)
    aCell:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    aCell:SetBackdropColor(0.02, 0.02, 0.02, 1)
    aCD = CreateFrame("Cooldown", "Dash01CooldownA", aCell, "CooldownFrameTemplate")
    aCD:SetAllPoints(aCell)
    local okFont, errFont = pcall(aCD.SetCountdownFont, aCD, dashNumberTemplate)
    state.aCountdownFont = okFont and "SET" or "NATIVE_DEFAULT"
    if not okFont then
        state.aCountdownFontError = tostring(errFont)
        note("A1数字字体未生效，保留原生字体：" .. state.aCountdownFontError)
    end
    local okDone = pcall(function() aCD:HookScript("OnCooldownDone", onAEngineDone) end)
    state.aCompletionHook = okDone and "REGISTERED" or "UNAVAILABLE"
    if not okDone then note("A1 冷却完成回调未绑定") end
    local okMin = pcall(function() aCD:SetMinimumCountdownDuration(0) end)
    state.aCountdownMinimum = okMin and "ZERO" or "UNCONFIRMED"
    aCD:SetHideCountdownNumbers(false)
    aCD:SetDrawSwipe(false)
    pcall(function() aCD:SetDrawBling(false) end)
    pcall(function() aCD:SetDrawEdge(false) end)
    aCD.noCooldownCount = false
    aDone = aCell:CreateFontString(nil, "ARTWORK", dashNumberTemplate)
    aDone:SetAllPoints(aCell)
    aDone:SetText("OK")
    aDone:SetShown(false)

    -- A2在已空闲第二行创建；仅自有帧脱战几何，外框/其他行不改变。
    createA2Row(bd)
    createACDRows(bd)

    -- B1 行（底板=行框自绘，常亮；引擎按钮只画内容）
    bRow = CreateFrame("Frame", "Dash01RowB", win, "BackdropTemplate")
    bRow:SetSize(134, 40)
    bRow:SetPoint("LEFT", aRow, "RIGHT", 8, 0)
    bRow:SetBackdrop(bd)
    bRow:SetBackdropColor(0.02, 0.02, 0.02, 1)

    -- v1.00-S1：B1 数字格底（常亮，任务书§五"无 aura 时数字格轮廓仍在"）。
    -- 绑定文本留在按钮后代（initializer 内锚此格中心，跨层锚点=WarriorCharges 先例）
    bCellBase = CreateFrame("Frame", "Dash01CellB", bRow, "BackdropTemplate")
    bCellBase:SetSize(42, 36)
    bCellBase:SetPoint("RIGHT", -2, 0)
    bCellBase:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    bCellBase:SetBackdropColor(0.02, 0.02, 0.02, 1)

    B_SLOTS[1].row, B_SLOTS[1].cell = bRow, bCellBase
    -- 新槽由公开配置生成自有行/格；不属于引擎按钮子树，不随aura折叠。
    for i, slot in ipairs(B_SLOTS) do
        if i > 1 then
            slot.row = CreateFrame("Frame", "Dash01RowB" .. i, win, "BackdropTemplate")
            slot.row:SetSize(slot.width, slot.height)
            slot.row:SetPoint("TOPLEFT", B_SLOTS[i-1].row, "BOTTOMLEFT", 0, -4)
            slot.row:SetBackdrop(bd)
            slot.row:SetBackdropColor(0.02, 0.02, 0.02, 1)
            slot.cell = CreateFrame("Frame", "Dash01CellB" .. i, slot.row, "BackdropTemplate")
            slot.cell:SetSize(42, slot.cellHeight)
            slot.cell:SetPoint("RIGHT", -2, 0)
            slot.cell:SetBackdrop(bd)
            slot.cell:SetBackdropColor(0.02, 0.02, 0.02, 1)
            slot.border = CreateFrame("Frame", "Dash01RowB" .. i .. "_Border", slot.row, "BackdropTemplate")
            slot.border:SetAllPoints(slot.row)
            slot.border:SetBackdrop(bd)
            slot.border:SetBackdropColor(0, 0, 0, 0)
            slot.border:EnableMouse(false)
            pcall(slot.border.SetMouseMotionEnabled, slot.border, false)
        end
        slot.healthHost = CreateFrame("Frame", nil, slot.row)
        slot.healthHost:SetAllPoints(slot.row)
        slot.healthHost:SetFrameStrata("HIGH")
        slot.healthHost:EnableMouse(false)
        slot.healthFS = slot.healthHost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local hf, _, flags = slot.healthFS:GetFont()
        if hf then slot.healthFS:SetFont(hf, 8, flags) end
        slot.healthFS:SetPoint("BOTTOMLEFT", slot.row, "BOTTOMLEFT", 38, 2)
        slot.healthFS:SetText("!")
        slot.healthFS:SetTextColor(1, 0.3, 0.3)
    end

    -- C1 三格：名称/整数百分比/定位；单位只在名称格，不把 % 混进数字格。
    cRow = CreateFrame("Frame", "Dash01RowC", win)
    cRow:SetSize(136, 40)
    cRow:SetPoint("LEFT", bRow, "RIGHT", 8, 0)
    local cLabelCell = CreateFrame("Frame", "Dash01LabelC1", cRow, "BackdropTemplate")
    cLabelCell:SetSize(48, 40)
    cLabelCell:SetPoint("LEFT")
    cLabelCell:SetBackdrop(bd)
    cLabelCell:SetBackdropColor(0.02, 0.02, 0.02, 1)
    local cLabelFS = cLabelCell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cLabelFS:SetAllPoints(cLabelCell)
    cLabelFS:SetJustifyH("CENTER")
    local cLabelFont, _, cLabelFlags = cLabelFS:GetFont()
    if cLabelFont then cLabelFS:SetFont(cLabelFont, 10, cLabelFlags) end
    pcall(function() cLabelFS:SetWordWrap(false) end)
    cLabelFS:SetText("T.HP%")

    local cValueCell = CreateFrame("Frame", "Dash01ValueC1", cRow, "BackdropTemplate")
    cValueCell:SetSize(40, 40)
    cValueCell:SetPoint("LEFT", cLabelCell, "RIGHT", 4, 0)
    cValueCell:SetBackdrop(bd)
    cValueCell:SetBackdropColor(0.02, 0.02, 0.02, 1)
    cFS = cValueCell:CreateFontString(nil, "ARTWORK", dashNumberTemplate)
    cFS:SetAllPoints(cValueCell)
    cFS:SetText("?")

    local cLocatorCell = CreateFrame("Frame", "Dash01LocatorCellC1", cRow, "BackdropTemplate")
    cLocatorCell:SetSize(40, 40)
    cLocatorCell:SetPoint("LEFT", cValueCell, "RIGHT", 4, 0)
    cLocatorCell:SetBackdrop(bd)
    cLocatorCell:SetBackdropColor(0.02, 0.02, 0.02, 1)
    -- C2 三格：名称/当前点数/实时上限；与C1同宽，额外行高34。
    -- 只在脱战 ensureShell 中创建，不属于引擎 aura 按钮子树。
    c2Row = CreateFrame("Frame", "Dash01RowC2", win)
    c2Row:SetSize(136, 34)
    c2Row:SetPoint("TOPLEFT", cRow, "BOTTOMLEFT", 0, -4)
    local c2LabelCell = CreateFrame("Frame", "Dash01LabelC2", c2Row, "BackdropTemplate")
    c2LabelCell:SetSize(48, 34)
    c2LabelCell:SetPoint("LEFT")
    c2LabelCell:SetBackdrop(bd)
    c2LabelCell:SetBackdropColor(0.02, 0.02, 0.02, 1)
    c2LabelFS = c2LabelCell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    c2LabelFS:SetAllPoints(c2LabelCell)
    c2LabelFS:SetJustifyH("CENTER")
    local c2LabelFont, _, c2LabelFlags = c2LabelFS:GetFont()
    if c2LabelFont then c2LabelFS:SetFont(c2LabelFont, 10, c2LabelFlags) end
    pcall(function() c2LabelFS:SetWordWrap(false) end)
    c2LabelFS:SetText("RES?")

    local c2CurrentCell = CreateFrame("Frame", "Dash01CurrentC2", c2Row, "BackdropTemplate")
    c2CurrentCell:SetSize(40, 34)
    c2CurrentCell:SetPoint("LEFT", c2LabelCell, "RIGHT", 4, 0)
    c2CurrentCell:SetBackdrop(bd)
    c2CurrentCell:SetBackdropColor(0.02, 0.02, 0.02, 1)
    c2CurrentFS = c2CurrentCell:CreateFontString(nil, "ARTWORK", dashNumberTemplate)
    c2CurrentFS:SetAllPoints(c2CurrentCell)
    c2CurrentFS:SetText("?")

    local c2MaxCell = CreateFrame("Frame", "Dash01MaximumC2", c2Row, "BackdropTemplate")
    c2MaxCell:SetSize(40, 34)
    c2MaxCell:SetPoint("LEFT", c2CurrentCell, "RIGHT", 4, 0)
    c2MaxCell:SetBackdrop(bd)
    c2MaxCell:SetBackdropColor(0.02, 0.02, 0.02, 1)
    c2MaxFS = c2MaxCell:CreateFontString(nil, "ARTWORK", dashNumberTemplate)
    c2MaxFS:SetAllPoints(c2MaxCell)
    c2MaxFS:SetText("?")
    c2Row:Hide()

    local locatorC1 = createDashLocator(cLocatorCell, "Dash01LocatorC1", "L")
    locatorC1:SetPoint("CENTER")
    local locatorTL = createDashLocator(win, "Dash01LocatorTL", "SQUARE")
    locatorTL:SetPoint("TOPLEFT", 4, -2)
    local locatorBR = createDashLocator(win, "Dash01LocatorBR", "BARS")
    locatorBR:SetPoint("BOTTOMRIGHT", -4, 2)

    -- L5：两条自有列分隔线；高度随外壳锚点变化，不访问引擎按钮。
    for _, x in ipairs({145, 287}) do
        local separator = win:CreateTexture(nil, "OVERLAY")
        separator:SetColorTexture(1, 1, 1, 1)
        separator:SetWidth(2)
        separator:SetPoint("TOPLEFT", win, "TOPLEFT", x, -20)
        separator:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", x, 18)
    end

    state.shell = true
    pcall(refreshACDProfiles)
    local okD, errD = pcall(createDLayout, bd)
    if not okD then
        state.dLayoutReady, state.dEngine = false, "LAYOUT_ERROR_RELOAD_REQUIRED"
        note("D布局失败：" .. tostring(errD))
        print("|cffff6666[Dash01]|r D布局未构建，reload后重试；ABC保持")
    end
    refreshCombatResourceProfile()
    refreshA2Profile()
    if refreshDashSettings then refreshDashSettings() end
    return true
end

-- 创建过程只尝试一次；普通字体失败已在创建前退回默认字体。
-- 其他构造失败保留原始原因，隐藏同一半成品，必须reload才重试，避免孤儿帧累积。
local function ensureShell()
    if state.shell and state.shellStatus == "READY" then return true end
    if state.shellStatus == "FAILED_RELOAD_REQUIRED" then return false end
    if InCombatLockdown() then return false end
    state.shellStatus = "BUILDING"
    local ok, result = pcall(function()
        if buildDashShell() ~= true then return false end
        win:Show()
        return true
    end)
    if not ok or result ~= true then
        state.shell, state.shellStatus = false, "FAILED_RELOAD_REQUIRED"
        state.shellError = tostring(result)
        if win then pcall(win.Hide, win) end
        note("仪表盘构造未完成：" .. state.shellError)
        saveDashState()
        print("|cffff6666[Dash01]|r 仪表盘未完成加载，请重载；/dash可查看原始原因。")
        return false
    end
    state.shell, state.shellStatus = true, "READY"
    return true
end

-- ---------- B 容器（脱战基线；换目标 repool 双杠杆） ----------
local function tryInit()
    if state.shell and state.shellStatus == "READY" and state.unitOk and allBSlotsRegistered() then
        updateHP()
        applyInfoA()
        return true
    end
    -- 老板实测 BUG：其他职业也显示（还显示 OK/空）——三列只对牧师有意义，类别门在此
    local okCls, cls = pcall(function() return select(2, UnitClass("player")) end)
    if not (okCls and cls == "PRIEST") then
        if not state.clsBlocked then
            state.clsBlocked = true
            saveDashState()
            print("|cff66ccff[Dash01]|r 非牧师角色，不启用（心灵震爆/痛/血量三列仅牧师有意义）")
        end
        return false
    end
    if InCombatLockdown() then return false end
    if not ensureShell() then return false end

    -- 载入引擎容器模板（v0.97 配方同款；此前这步靠旧 DoT 盒代劳，旧盒退役后会断——补上）
    if not state.blizzLoaded then
        -- D-2（Codex）：LoadAddOn 不抛错≠加载成功，必须核对返回的 loaded 与最终加载状态；
        -- 失败保留重试资格（blizzLoaded 不置真）
        local okL, loaded, reason = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
        if not okL then
            note("LoadAddOn 异常: " .. tostring(loaded))
            saveDashState()
            return false
        end
        if loaded ~= true and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
            note("LoadAddOn 未加载成功: " .. tostring(reason))
            saveDashState()
            return false
        end
        state.blizzLoaded = true
    end

    if not state.containerOk then
        local okC, errC = pcall(function()
            bContainer = CreateFrame("AuraContainer", nil, bRow, "CustomAuraContainerTemplate")
            bContainer:SetPoint("TOPLEFT", bRow, "TOPLEFT")
            bContainer:SetSize(1, 1)
        end)
        if not okC then
            note("CreateFrame(AuraContainer) 失败: " .. tostring(errC))
            saveDashState()
            return false
        end
        state.containerOk = true
        saveDashState()

        -- v0.99c：B1 框线覆盖层。老板实测"dot 没有框"——引擎按钮显示时自带不透明底，
        -- 会盖住 bRow 的底板边框（按钮隐时框能看到、按钮显时框被盖=现象吻合）。
        -- 修法：在容器之上（自有帧，非按钮子树，不触创建窗口禁令）再画一层边框。
        -- v0.99d（外审 P2-3）：bg 全透明只留框线，别把数字压暗 35%；P2-2：整段 pcall。
        if not bBorder then
            local okB, errB = pcall(function()
                bBorder = CreateFrame("Frame", "Dash01RowB_Border", bRow, "BackdropTemplate")
                bBorder:SetAllPoints(bRow)
                bBorder:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                bBorder:SetBackdropColor(0, 0, 0, 0)
                bBorder:EnableMouse(false)
                pcall(function() bBorder:SetMouseMotionEnabled(false) end)
            end)
            if not okB then note("bBorder 创建失败: " .. tostring(errB)) end
        end
    end

    B_SLOTS[1].border = bBorder
    -- AddAuraSlot可能在注册前/后抛错，故每槽每次加载只尝试一次；失败不造重复帧，reload重试。
    for _, slot in ipairs(B_SLOTS) do
        local st = slot.status
        if not st.slotOk and not st.addAttempted then
            st.addAttempted = true
            local okS, errS = pcall(function()
                bContainer:AddAuraSlot(slot.slotKey, slot.filter, {
                    candidateFilters = { includeSpellIDs = { [slot.spellID] = true }, excludeSpellIDs = {} },
                    initializeFrame = makeBInitializer(slot),
                })
            end)
            st.slotOk = okS
            if not okS then
                st.lastErr = "ADD_SLOT_ERROR_RELOAD_REQUIRED"
                note(slot.slotKey .. " AddAuraSlot失败: " .. tostring(errS))
            end
            paintBHealth(slot)
        end
    end
    state.slotOk = B_SLOTS[1].status.slotOk

    local okU, errU = pcall(function()
        bContainer:SetUnit("target")
        bContainer:UpdateAllAuras()
    end)
    for _, slot in ipairs(B_SLOTS) do
        slot.status.unitOk = okU
        slot.status.rescan = okU and "OK" or "ERROR"
        paintBHealth(slot)
    end
    if not okU then
        note("SetUnit/UpdateAllAuras 失败: " .. tostring(errU))
        saveDashState()
        return false
    end
    state.unitOk = true
    saveDashState()
    updateHP()
    applyInfoA()
    if allBSlotsRegistered() then
        print("|cff66ccff[Dash01]|r B配置槽已注册（不是aura有效性证明）：/dash 看状态")
    else
        print("|cffff6666[Dash01]|r 部分B槽注册失败，见!角标与/dash；修复后reload重试")
    end
    return true
end

local function repoolB(why)
    if not (state.unitOk and bContainer) then return end
    -- v0.99b：map 形式（[id]=true）——与 AddAuraSlot/EUI 生产一致，list 形式疑似重设被拒
    -- P1-5（外审）收口：战斗中保留不做门——EUI unitWatcher 的 RefreshUnit 同样无战斗门
    -- （UF/姓名板战斗中常态重扫），容器/重扫通道 68914 起战斗合法（AuraKit:1553-1555，
    -- 本机 69933）；实测项=战斗中切目标零 ADDON_ACTION_BLOCKED（作业单已列，红字即回改）
    -- D-2（Codex）：候选重设失败单独留痕，不能只看重扫结果掩盖前半段失败
    for _, slot in ipairs(B_SLOTS) do
        if slot.status.slotOk then
            local okS, errS = pcall(bContainer.SetAuraSlotCandidateFilters, bContainer, slot.slotKey,
                { includeSpellIDs = { [slot.spellID] = true }, excludeSpellIDs = {} })
            slot.status.candidateReset = okS and "OK" or "ERROR"
            if not okS then note(why .. " " .. slot.slotKey .. " 候选重设失败: " .. tostring(errS)) end
        end
    end
    local okR, errR = pcall(bContainer.UpdateAllAuras, bContainer)
    if not okR then note(why .. " 重扫失败: " .. tostring(errR)) end
    for _, slot in ipairs(B_SLOTS) do
        slot.status.rescan = okR and "OK" or "ERROR"
        paintBHealth(slot)
    end
    saveDashState()
end

-- ---------- 事件（并集 9 个；UNIT_* 全部 RegisterUnitEvent 限 target） ----------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterUnitEvent("UNIT_FACTION", "target")
ev:RegisterUnitEvent("UNIT_HEALTH", "target")
ev:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
ev:RegisterUnitEvent("UNIT_HEAL_PREDICTION", "target")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, e, arg1)
    if e == "PLAYER_REGEN_DISABLED" then
        -- 新事件只处理自有拖动层；不检查引擎按钮，不触碰 A/B/C provider。
        if windowDragging then stopWindowDrag() end
        paintWindowLock(true)
        if lockMenu then lockMenu:Hide() end
        return
    end
    if e == "PLAYER_REGEN_ENABLED" and windowPositionPending then
        saveDashPos()
        if state.posStatus == "SAVED" then windowPositionPending = false end
    end
    if e == "ADDON_LOADED" then
        if arg1 == "MindBlastBox01" then
            -- Q3（外审）：SV 变量层隔离——只用 .dash 子表，不碰旧盒键
            if type(MindBlastBox01DB) ~= "table" then
                local previous = MindBlastBox01DB
                MindBlastBox01DB = { dashRecoveredRoot = previous }
                if type(previous) ~= "nil" then note("设置根表无效：原值已另存") end
            end
            if type(MindBlastBox01DB.dash) ~= "table" then
                local previous = MindBlastBox01DB.dash
                MindBlastBox01DB.dash = { recoveredValue = previous }
                if type(previous) ~= "nil" then note("dash 设置无效：原值已另存") end
            end
            print("|cff66ccff[Dash01 " .. DASH_VER .. "]|r 文件已加载：/dash 查状态")
            pcall(function() UIErrorsFrame:AddMessage("Dash01 " .. DASH_VER .. " 已加载", 0.4, 0.8, 1) end)
        end
        return
    end
    if e == "UNIT_HEALTH" or e == "UNIT_MAXHEALTH" or e == "UNIT_HEAL_PREDICTION" then
        if arg1 == "target" then updateHP() end
        return
    end
    if e == "PLAYER_TARGET_CHANGED" then
        updateHP()
        repoolB("PLAYER_TARGET_CHANGED")
        -- v1.09：切目标立即重查 A1，并安排下一次 OnUpdate 复查。
        requestARefresh()
        return
    end
    if e == "UNIT_FACTION" and arg1 == "target" then
        updateHP()
        repoolB("UNIT_FACTION")
        return
    end
    if e == "SPELLS_CHANGED" then
        applyInfoA()
        return
    end
    if e == "PLAYER_LOGOUT" then
        -- v1.01（反馈③兜底）：下线前再存一次窗位/状态，覆盖拖动后未触发 OnDragStop 的漏网路径
        saveDashPos()
        saveDashState()
        return
    end
    tryInit()
end)

-- v1.26：D单一生命周期帧；引擎容器自行处理player UNIT_AURA，插件不轮询BUFF秒数。
local dWatch = CreateFrame("Frame")
state.dProfile, state.dEnabled = "UNKNOWN", "NO"
state.dEventRegistered, state.dEventFailed = 0, 0
local function safeRefreshD()
    local ok, err = pcall(refreshDProfile)
    if not ok then
        state.dProfile, state.dEngine, state.dEnabled = "UNKNOWN", "PROFILE_ERROR", "NO"
        if dContainer then pcall(dContainer.SetEnabled, dContainer, false) end
        for _, slot in ipairs(D_SLOTS) do pcall(paintDHealth, slot) end
        note("D刷新失败: " .. tostring(err)); saveDashState()
    end
end
local function deferDRefresh()
    -- 合并同帧元数据事件，只执行一次，随后撤销OnUpdate；不做高频全量扫描。
    dWatch:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        safeRefreshD()
    end)
end
for _, eventName in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED"}) do
    local ok = pcall(dWatch.RegisterEvent, dWatch, eventName)
    if ok then state.dEventRegistered = state.dEventRegistered + 1
    else state.dEventFailed = state.dEventFailed + 1; note("D事件注册未确认: " .. eventName) end
end
dWatch:SetScript("OnEvent", function(_, eventName, arg1)
    if eventName == "ADDON_LOADED" and publicA(arg1, "string") ~= "MindBlastBox01" then return end
    if eventName == "PLAYER_SPECIALIZATION_CHANGED" and publicA(arg1, "string") ~= "player" then return end
    -- 立即撤销旧来源并遮挡旧数字；一次延迟重查重新配置，战斗不改行/列几何显隐。
    state.dProfile, state.dEnabled = "UNKNOWN", "NO"
    repoolD(false)
    deferDRefresh()
end)

-- v1.17：C2独立player事件帧；不改既有A/B/C1事件分支与刷新时机。
local resourceWatch = CreateFrame("Frame")
state.c2EventRegistered, state.c2EventFailed = 0, 0
for _, eventName in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
    local ok = pcall(resourceWatch.RegisterUnitEvent, resourceWatch, eventName, "player")
    if ok then state.c2EventRegistered = state.c2EventRegistered + 1
    else
        state.c2EventFailed = state.c2EventFailed + 1
        note("C2事件注册未确认：" .. eventName)
    end
end
for _, eventName in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }) do
    local ok = pcall(resourceWatch.RegisterEvent, resourceWatch, eventName)
    if ok then state.c2EventRegistered = state.c2EventRegistered + 1
    else
        state.c2EventFailed = state.c2EventFailed + 1
        note("C2事件注册未确认：" .. eventName)
    end
end
resourceWatch:SetScript("OnEvent", function(_, eventName, arg1)
    if eventName == "UNIT_POWER_FREQUENT" or eventName == "UNIT_MAXPOWER" or eventName == "UNIT_DISPLAYPOWER" then
        if publicA(arg1, "string") == "player" then updateCombatResource() end
        return
    end
    if eventName == "PLAYER_SPECIALIZATION_CHANGED" and publicA(arg1, "string") ~= "player" then return end
    if eventName == "PLAYER_TALENT_UPDATE" or eventName == "TRAIT_CONFIG_UPDATED" then
        -- 天赋更新只需重读两格，保留已确认专精，不在战斗中触碰宿主。
        updateCombatResource()
        return
    end
    refreshCombatResourceProfile()
end)


-- v1.18 设置入口的独立生命周期；Combat刷新只禁用控件，不读取窗口几何。
local settingsWatch = CreateFrame("Frame")
settingsWatch:RegisterEvent("ADDON_LOADED")
settingsWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
settingsWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
settingsWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
settingsWatch:SetScript("OnEvent", function(_, eventName)
    -- 其他插件按需载入时不重填输入，避免覆盖用户尚未应用的草稿。
    if eventName == "ADDON_LOADED" and state.settingsRegistered then return end
    if eventName ~= "PLAYER_REGEN_DISABLED" then setupDashSettings() end
    if refreshDashSettings then refreshDashSettings() end
end)
SLASH_DASHCONFIG1 = "/dashconfig"
SlashCmdList["DASHCONFIG"] = openDashSettings

-- v1.09：事件刷新 + 一次 OnUpdate 复查；保留原 0.2s 轮询兜底。
local aWatch = CreateFrame("Frame")
local aGlobalEvents = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES" }
local aPlayerEvents = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
}
state.aRefreshPolicy = "EVENT_UPDATE_POLL_0P2"
state.aRefreshRegistered, state.aRefreshRegisterFailed = 0, 0
for _, eventName in ipairs(aGlobalEvents) do
    local ok = pcall(aWatch.RegisterEvent, aWatch, eventName)
    if ok then
        state.aRefreshRegistered = state.aRefreshRegistered + 1
    else
        state.aRefreshRegisterFailed = state.aRefreshRegisterFailed + 1
        note("A1 刷新事件注册失败；仍保留轮询")
    end
end
for _, eventName in ipairs(aPlayerEvents) do
    -- 引擎按 player 过滤；回调不消费可能为 secret 的 unit/spellID/castGUID。
    local ok = pcall(aWatch.RegisterUnitEvent, aWatch, eventName, "player")
    if ok then
        state.aRefreshRegistered = state.aRefreshRegistered + 1
    else
        state.aRefreshRegisterFailed = state.aRefreshRegisterFailed + 1
        note("A1 玩家施法事件注册失败；仍保留轮询")
    end
end
aWatch:SetScript("OnEvent", function(_, event)
    -- 不读任何技能/施法GUID/单位 payload；各事件只查询当前计时对象。
    requestARefresh()
end)
aWatch:SetScript("OnUpdate", function(_, el)
    if aRefreshPending then
        aRefreshPending = false
        feedA(1)
    else
        feedA(el)
    end
    tickAReadyDisplay()
end)

-- v1.22：独立A2生命周期；不读施法payload，不改变A1/B/C事件。
local a2Watch = CreateFrame("Frame")
state.a2EventRegistered, state.a2EventFailed = 0, 0
for _, eventName in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
    "SPELLS_CHANGED", "SPELL_UPDATE_CHARGES", "SPELL_UPDATE_COOLDOWN"}) do
    local ok = pcall(a2Watch.RegisterEvent, a2Watch, eventName)
    if ok then state.a2EventRegistered = state.a2EventRegistered + 1
    else state.a2EventFailed = state.a2EventFailed + 1; note("A2事件注册失败：" .. eventName) end
end
a2Watch:SetScript("OnEvent", function(_, eventName, arg1)
    if eventName == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = publicA(arg1, "string")
        -- 只有公开确认其他单位才跳过；未知payload仍撤销旧来源并重新核对。
        if unit ~= nil and unit ~= "player" then return end
    end
    if eventName == "SPELL_UPDATE_CHARGES" or eventName == "SPELL_UPDATE_COOLDOWN" or
        (eventName == "SPELLS_CHANGED" and InCombatLockdown()) then
        updateA2(); a2RefreshPending = true
        return
    end
    refreshA2Profile()
    a2RefreshPending = true
end)
a2Watch:SetScript("OnUpdate", function(_, elapsed)
    if not state.a2LayoutReady then return end
    a2Elapsed = a2Elapsed + elapsed
    if not a2RefreshPending and a2Elapsed < 0.2 then return end
    a2RefreshPending, a2Elapsed = false, 0
    updateA2()
end)


-- v1.29：新普通CD槽共用一个事件/轮询帧，不改A1/A2/B/C/D原事件。
local acdWatch = CreateFrame("Frame")
state.acdEventRegistered, state.acdEventFailed = 0, 0
for _, eventName in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USES", "SPELL_UPDATE_CHARGES"}) do
    local ok = pcall(acdWatch.RegisterEvent, acdWatch, eventName)
    if ok then state.acdEventRegistered = state.acdEventRegistered + 1
    else state.acdEventFailed = state.acdEventFailed + 1; note("A3事件注册未确认: " .. eventName) end
end
for _, eventName in ipairs({"UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_AURA"}) do
    local ok = pcall(acdWatch.RegisterUnitEvent, acdWatch, eventName, "player")
    if ok then state.acdEventRegistered = state.acdEventRegistered + 1
    else state.acdEventFailed = state.acdEventFailed + 1; note("A3玩家事件注册未确认: " .. eventName) end
end
acdWatch:SetScript("OnEvent", function(_, eventName, arg1)
    if eventName == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = publicA(arg1, "string")
        if unit ~= nil and unit ~= "player" then return end
    end
    acdRefreshPending = true
    if eventName == "SPELL_UPDATE_COOLDOWN" or eventName:sub(1,5) == "UNIT_" then return end
    acdProfilePending = true
    for _, slot in ipairs(A_CD_SLOTS) do
        slot.status.profile = "UNKNOWN"
        if slot.status.layoutReady then clearACDSlot(slot, "?", "UNKNOWN", "SOURCE_REFRESH_PENDING") end
    end
end)
acdWatch:SetScript("OnUpdate", function(_, elapsed)
    if not state.shell then return end
    acdElapsed = acdElapsed + elapsed
    if acdRefreshPending or acdElapsed >= 0.2 then
        acdRefreshPending, acdElapsed = false, 0
        local needsProfile = acdProfilePending
        for _, slot in ipairs(A_CD_SLOTS) do
            if slot.status.profile == "UNKNOWN" then needsProfile = true end
        end
        if needsProfile then
            acdProfilePending = false
            local ok = pcall(refreshACDProfiles)
            if not ok then
                for _, slot in ipairs(A_CD_SLOTS) do
                    slot.status.profile = "UNKNOWN"
                    if slot.status.layoutReady then clearACDSlot(slot, "?", "UNKNOWN", "PROFILE_ERROR") end
                end
            end
        else
            for _, slot in ipairs(A_CD_SLOTS) do
                local ok = pcall(updateACDSlot, slot)
                if not ok and slot.status.layoutReady then clearACDSlot(slot, "?", "UNKNOWN", "UPDATE_ERROR") end
            end
        end
    end
    -- 逐帧只消费仍由引擎计时的duration原生active；不逐帧查询数值或重喂倒计时。
    for _, slot in ipairs(A_CD_SLOTS) do
        if slot.duration then
            local ok = pcall(paintACDNative, slot)
            if not ok then clearACDSlot(slot, "?", "UNKNOWN", "NATIVE_ALPHA_ERROR") end
        end
    end
end)

-- 仅公开字体配置与固定示例测宽结果；无实时技能值、按钮几何或秘密值。
SLASH_DASHFONT1 = "/dashfont"
SlashCmdList["DASHFONT"] = function(message)
    print("[DashFont] numbers=" .. tostring(state.numberFontMode) .. " size=" .. tostring(state.numberFontSize) ..
        " font=" .. tostring(state.numberFontPath))
    print("[DashFont] countState=" .. tostring(state.countStateFontMode) .. " size=" .. tostring(state.countStateFontSize) ..
        " font=" .. tostring(state.countStateFontPath))
    print("[DashFont] fixedSamplesAccepted=" .. tostring(state.fontLayoutAccepted) .. " (not OCR validation)")
    local all = message == "all"
    for _, metrics in ipairs({state.numberFontFitMetrics or {}, state.countStateFontMetrics or {}}) do
        for _, item in ipairs(metrics) do
            if all or not item.fits or item.role == "RECHARGE" or item.role == "COUNT_PAIR" or item.role == "COUNT_NA" then
                print(string.format("[DashFont] %s text=%s size=%d width=%s limit=%d cell=%d pad=%d %s",
                    item.role, item.text, item.size, item.width and string.format("%.3f", item.width) or "UNAVAILABLE",
                    item.limit, item.cellWidth, item.padding, item.fits and "FIT" or "FAIL"))
            end
        end
    end
    if state.numberFontError then print("[DashFont] numberError=" .. state.numberFontError) end
    if state.countStateFontError then print("[DashFont] stateError=" .. state.countStateFontError) end
end

SLASH_DASH1 = "/dash"
SlashCmdList["DASH"] = function()
    for _, slot in ipairs(A_CD_SLOTS) do
        local st = slot.status
        print("[Dash01 A3] " .. slot.slotKey .. " profile=" .. tostring(st.profile) ..
            " mode=" .. tostring(st.mode) .. " reason=" .. tostring(st.reason) ..
            " style=" .. tostring(st.style) .. " hook=" .. tostring(st.completionHook) .. " countSource=" .. tostring(st.countSource) .. " countHealth=" .. tostring(st.countHealth) ..
            " events=" .. tostring(state.acdEventRegistered) .. "/" .. tostring(state.acdEventFailed))
    end
    -- D诊断只看自有公开状态；任何时刻都不读取引擎按钮/光环内容。
    for _, slot in ipairs(D_SLOTS) do
        local st = slot.status
        print("[Dash01 D] " .. slot.slotKey .. " profile=" .. tostring(state.dProfile) ..
            " registered=" .. tostring(st.slotOk) .. " init=" .. tostring(st.initComplete) ..
            " name=" .. tostring(st.nameBound) .. " icon=" .. tostring(st.iconBound) ..
            " duration=" .. tostring(st.durationBound) .. " fmt=" .. tostring(st.fmtGrade) ..
            " candidate=" .. tostring(st.candidateReset) .. " rescan=" .. tostring(st.rescan) ..
            " enabled=" .. tostring(state.dEnabled) .. " engine=" .. tostring(state.dEngine))
    end
    -- 判密分类器：SECRET/明文/nil 三态，打印永不抛错
    local function classify(v)
        if type(v) == "nil" then return "nil" end
        if type(issecretvalue) ~= "function" then return "CHECK_UNAVAILABLE" end
        local okS, secret = pcall(issecretvalue, v)
        if not okS or type(secret) ~= "boolean" then return "CHECK_FAILED" end
        if secret then return "SECRET" end
        return tostring(v)
    end
    pcall(function()
        local diag = ""
        if bAuraBtn then
            if InCombatLockdown() then
                -- D-1（Codex §6.3）：战斗中直接跳过引擎按钮诊断（pcall 抓到失败≠没访问）
                diag = " bBtn=战斗中跳过"
            else
                -- 脱战：方法查找和调用一起进 pcall（Codex 建议）
                local okG = pcall(function()
                    local gl, gb, gW, gH = bAuraBtn:GetRect()
                    diag = string.format(" bBtn=%.0fx%.0f@(%.0f,%.0f)", gW, gH, gl, gb)
                end)
                if not okG then diag = " bBtn_GetRect异常" end
                local okSh, sh = pcall(function() return bAuraBtn:IsShown() end)
                if okSh then
                    diag = diag .. " shown=" .. (type(sh) == "boolean" and tostring(sh) or "type=" .. type(sh))
                else
                    diag = diag .. " shown=读取异常"
                end
            end
        else
            diag = " bBtn=尚无(引擎未建按钮)"
        end
        local bs = {}
        for _, slot in ipairs(B_SLOTS) do
            local st = slot.status
            bs[#bs+1] = slot.slotKey .. ":registered=" .. tostring(st.slotOk) ..
                ",captured=" .. tostring(st.btnCaptured) .. ",init=" .. tostring(st.initComplete) ..
                ",name=" .. tostring(st.nameBound) .. ",duration=" .. tostring(st.durationBound) ..
                ",fmt=" .. tostring(st.fmtGrade) .. ",candidate=" .. tostring(st.candidateReset) ..
                ",rescan=" .. tostring(st.rescan) .. ",err=" .. tostring(st.lastErr)
        end
        diag = diag .. " bSlots=" .. table.concat(bs, " | ")
        diag = diag .. " A2=" .. tostring(state.a2Profile) ..
            ",count=" .. tostring(state.a2CountMode) .. ":" .. tostring(state.a2CountReason) ..
            ",recharge=" .. tostring(state.a2RechargeMode) .. ":" .. tostring(state.a2RechargeReason) ..
            ",style=" .. tostring(state.a2RechargeStyle) .. ",events=" .. tostring(state.a2EventRegistered) ..
            "/" .. tostring(state.a2EventFailed)
        -- A1 就绪三读数（外审 §八.2：上两轮各采一半导致根因判反，这次一次采全）
        local aDiag = ""
        local okC, cdInfo = pcall(C_Spell.GetSpellCooldown, SPELL_A)
        if okC and type(cdInfo) == "table" then
            local okA, act = pcall(function() return cdInfo.isActive end)
            local okE, en = pcall(function() return cdInfo.isEnabled end)
            aDiag = aDiag .. " CD_isActive=" .. (okA and classify(act) or "ERR") ..
                " CD_isEnabled=" .. (okE and classify(en) or "ERR")
        end
        local okQ, chInfo = pcall(C_Spell.GetSpellCharges, SPELL_A)
        if okQ and type(chInfo) == "table" then
            local okA, act = pcall(function() return chInfo.isActive end)
            local okM, mx = pcall(function() return chInfo.maxCharges end)
            aDiag = aDiag .. " Chg_isActive=" .. (okA and classify(act) or "ERR") ..
                " Chg_max=" .. (okM and classify(mx) or "ERR")
        else
            aDiag = aDiag .. " Chg=无表"
        end
        local okI, si = pcall(C_Spell.GetSpellInfo, SPELL_A)
        if okI and type(si) == "table" then
            local name = publicA(si.name, "string")
            if name ~= nil then aDiag = aDiag .. " A1_name=" .. name end
        end
        -- 非法 SV/几何不能让整条 /dash 输出消失；战斗不读几何。
        local posDiag = " pos=无窗"
        if win then
            if InCombatLockdown() then
                posDiag = " pos=战斗中跳过"
            else
                local okP, pt, rel, rp, px, py = pcall(function() return win:GetPoint(1) end)
                if okP then
                    local relKnown = rel == UIParent
                    if relKnown then
                        posDiag = " pos=" .. describePosition({point=pt,relPoint=rp,x=px,y=py})
                    else
                        posDiag = " pos=当前非UIParent锚点"
                    end
                else
                    posDiag = " pos=不可读"
                end
            end
        end
        local svPos = " SVpos=无"
        if type(MindBlastBox01DB) == "table" and type(MindBlastBox01DB.dash) == "table" then
            if type(MindBlastBox01DB.dash.pos) ~= "nil" then
                svPos = " SVpos=" .. describePosition(MindBlastBox01DB.dash.pos)
            end
        end
        -- v1.02：A1 模式变化最近几条留痕（远程定位空窗/迟到类问题）
        local aLog = " aLog=无"
        if type(state.aLog) == "table" and #state.aLog > 0 then
            local tail = {}
            for i = math.max(1, #state.aLog - 3), #state.aLog do
                tail[#tail + 1] = state.aLog[i]
            end
            aLog = " aLog=" .. table.concat(tail, " | ")
        end
        print("|cff66ccff[Dash01 " .. DASH_VER .. "]|r shell=" .. tostring(state.shell) ..
            " blizz=" .. tostring(state.blizzLoaded) ..
            " containerOk=" .. tostring(state.containerOk) ..
            " slotOk=" .. tostring(state.slotOk) ..
            " unitOk=" .. tostring(state.unitOk) ..
            " btnCaptured=" .. tostring(state.btnCaptured) ..
            " fmt=" .. tostring(state.fmtGrade) .. " aMode=" .. tostring(state.aMode) ..
            " aInfo=" .. tostring(state.aInfo) .. " aReason=" .. tostring(state.aReason) .. " startClass=" .. tostring(state.aStartClass) ..
            " aScope=" .. tostring(state.aScope) .. " aGCD=" .. tostring(state.aGCDClass) ..
            " aReadyPolicy=" .. tostring(state.aReadyPolicy) .. " aDonePolicy=" .. tostring(state.aCompletionPolicy) .. " aDoneHook=" .. tostring(state.aCompletionHook) .. " aDoneCount=" .. tostring(state.aEngineDoneCount or 0) ..
            " aMin=" .. tostring(state.aCountdownMinimum) ..
            " aRefresh=" .. tostring(state.aRefreshPolicy) ..
            " aEventReg=" .. tostring(state.aRefreshRegistered) .. "/" .. tostring(state.aRefreshRegisterFailed) ..
            " aRequests=" .. tostring(state.aRefreshRequests or 0) ..
            " layout=" .. tostring(state.layoutVersion) .. " cFormat=" .. tostring(state.cFormat) .. " cLabelFmt=" .. tostring(state.cLabelFormat) ..
            " cMode=" .. tostring(state.cMode) .. " cReason=" .. tostring(state.cReason) ..
            " c2Profile=" .. tostring(state.c2Profile) ..
            " c2Current=" .. tostring(state.c2CurrentMode) .. ":" .. tostring(state.c2CurrentReason) ..
            " c2Max=" .. tostring(state.c2MaxMode) .. ":" .. tostring(state.c2MaxReason) ..
            " c2Events=" .. tostring(state.c2EventRegistered) .. "/" .. tostring(state.c2EventFailed) ..
            " c3Configured=" .. tostring(state.c3Configured) ..
            " locked=" .. tostring(state.windowLocked) ..
            " windowScale=" .. tostring(state.windowScale) .. " scaleRestore=" .. tostring(state.scaleRestore) ..
            " shellStatus=" .. tostring(state.shellStatus) .. " shellError=" .. tostring(state.shellError) ..
            " numberFontMode=" .. tostring(state.numberFontMode) .. " numberFontError=" .. tostring(state.numberFontError) ..
            " aCountdownFont=" .. tostring(state.aCountdownFont) .. " aCountdownFontError=" .. tostring(state.aCountdownFontError) ..
            " numberFontSize=" .. tostring(state.numberFontSize) .. " numberFontRestore=" .. tostring(state.numberFontRestore) ..
            " settings=" .. tostring(state.settingsStatus) .. " settingsApply=" .. tostring(state.settingsApply) ..
            " posStatus=" .. tostring(state.posStatus) .. " posOwner=" .. tostring(state.posOwner) ..
            diag .. aDiag .. posDiag .. svPos .. aLog)
        if state.lastErr then
            print("|cffff4444lastErr:|r " .. state.lastErr)
        end
    end)
    saveDashState()
end
