local _, ns = ...
local L = ns.L

local Settings = {}
ns.Settings = Settings

local NAV_MODES = { "auto", "tomtom", "blizzard" }

local function checkbox(parent, label, y, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", 10, y)
  cb:SetSize(22, 22)
  cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb.label:SetText(label)
  cb:SetScript("OnShow", function(self) self:SetChecked(get()) end)
  cb:SetScript("OnClick", function(self)
    ns.UI:Click()
    set(self:GetChecked() and true or false)
    ns.Core:Refresh()
  end)
  return cb
end

function Settings:Create(anchor)
  local f = CreateFrame("Frame", "SentierSettings", anchor, "BackdropTemplate")
  f:SetSize(240, 324)
  f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
  f:SetBackdrop(ns.UI.BACKDROP)
  f:SetBackdropColor(0.08, 0.09, 0.11, 0.95)
  f:SetBackdropBorderColor(0.42, 0.35, 0.18)
  f:EnableMouse(true)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 10, -10)
  title:SetText(L.SETTINGS_TITLE)
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  sub:SetPoint("TOPLEFT", 10, -32)
  sub:SetText(L.SETTINGS_SOURCES)

  local y = -48
  for _, source in ipairs(ns.SOURCES) do
    checkbox(f, L["SOURCE_" .. source], y,
      function() return ns.DB.account.sources[source] ~= false end,
      function(v) ns.DB.account.sources[source] = v end)
    y = y - 22
  end
  y = y - 6
  checkbox(f, L.SETTINGS_HIDE_DONE, y, function() return ns.DB.account.hideDone end, function(v) ns.DB.account.hideDone = v end)
  y = y - 22
  checkbox(f, L.SETTINGS_LOCK, y, function() return ns.DB.account.locked end, function(v) ns.DB.account.locked = v end)
  y = y - 22
  checkbox(f, L.SETTINGS_MINIMAP, y, function() return not ns.DB.account.minimap.hidden end, function(v)
    ns.DB.account.minimap.hidden = not v
    ns.MinimapButton:Refresh()
  end)
  y = y - 30

  local nav = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  nav:SetSize(220, 22)
  nav:SetPoint("TOPLEFT", 10, y)
  local function navLabel() nav:SetText(L.SETTINGS_NAV .. L.SEP_LABEL .. (L["NAV_" .. tostring(ns.DB.account.nav)] or L.NAV_auto)) end
  nav:SetScript("OnShow", navLabel)
  nav:SetScript("OnClick", function()
    ns.UI:Click()
    local index = 1
    for i, mode in ipairs(NAV_MODES) do
      if mode == ns.DB.account.nav then index = i end
    end
    ns.DB.account.nav = NAV_MODES[index % #NAV_MODES + 1]
    navLabel()
    -- Le nouveau mode s'applique tout de suite : on retire le repère puis on le replace.
    ns.Navigation:Clear()
    ns.Core:Refresh()
  end)
  y = y - 28

  local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clear:SetSize(220, 22)
  clear:SetPoint("TOPLEFT", 10, y)
  clear:SetText(L.SETTINGS_CLEAR_SKIPS)
  clear:SetScript("OnClick", function()
    local guide = ns.Core.result and ns.Core.result.guide
    if guide then
      ns.DB:ClearSkips(guide)
      ns.UI:Notify(L.FEEDBACK_SKIPS_CLEARED)
      ns.Core:Refresh()
    end
  end)

  f:Hide()
  self.frame = f
  return f
end

function Settings:Toggle(anchor)
  local f = self.frame or self:Create(anchor)
  f:SetShown(not f:IsShown())
end
