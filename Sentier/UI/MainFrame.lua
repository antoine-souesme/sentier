local _, ns = ...
local L = ns.L

-- ns.UI (et son BACKDROP) est créé par StepTab.lua, premier fichier d'interface du .toc.
local UI = ns.UI or { viewIndex = 1 }
ns.UI = UI

local function savePosition(f)
  local point, _, relPoint, x, y = f:GetPoint(1)
  ns.DB.account.frame = { point = point, relPoint = relPoint, x = x, y = y, w = f:GetWidth(), h = f:GetHeight() }
end

function UI:Create()
  if self.frame then return self.frame end
  local saved = ns.DB.account.frame

  local f = CreateFrame("Frame", "SentierFrame", UIParent, "BackdropTemplate")
  f:SetSize(saved and saved.w or 320, saved and saved.h or 260)
  if saved and saved.point then
    f:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
  else
    f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
  end
  f:SetBackdrop(UI.BACKDROP)
  f:SetBackdropColor(0.08, 0.09, 0.11, 0.92)
  f:SetBackdropBorderColor(0.42, 0.35, 0.18)
  f:SetMovable(true)
  f:SetResizable(true)
  f:SetClampedToScreen(true)
  f:SetResizeBounds(260, 180, 600, 700)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not ns.DB.account.locked then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePosition(self) end)

  local title = CreateFrame("Button", nil, f)
  title:SetPoint("TOPLEFT", 10, -8)
  title:SetPoint("TOPRIGHT", -34, -8)
  title:SetHeight(18)
  title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title.text:SetAllPoints()
  title.text:SetJustifyH("LEFT")
  title:SetScript("OnClick", function(btn) UI:OpenGuideMenu(btn) end)
  self.title = title

  local gear = CreateFrame("Button", nil, f)
  gear:SetSize(20, 20)
  gear:SetPoint("TOPRIGHT", -8, -6)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:SetScript("OnClick", function() ns.Settings:Toggle(f) end)

  self.tabs = {}
  for i, key in ipairs({ "step", "list" }) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(70, 20)
    b:SetText(key == "step" and L.TAB_STEP or L.TAB_LIST)
    b:SetPoint("TOPLEFT", 10 + (i - 1) * 74, -30)
    b:SetScript("OnClick", function() UI:SetTab(key) end)
    self.tabs[key] = b
  end

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", 8, -54)
  body:SetPoint("BOTTOMRIGHT", -8, 8)
  self.panels = { step = ns.StepTab:Create(body), list = ns.ListTab:Create(body) }

  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function() if not ns.DB.account.locked then f:StartSizing("BOTTOMRIGHT") end end)
  grip:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    savePosition(f)
    UI:Render(ns.Core.result)
  end)

  self.frame = f
  self:SetTab(ns.DB.char.tab or "step")
  return f
end

function UI:SetTab(key)
  ns.DB.char.tab = key
  for k, panel in pairs(self.panels) do
    panel:SetShown(k == key)
    self.tabs[k]:SetEnabled(k ~= key)
  end
  self:Render(ns.Core.result)
end

function UI:Render(result)
  if not self.frame or not result then return end
  self.title.text:SetText(result.guide.title)
  if ns.DB.char.tab == "list" then
    self.panels.list:Render(result)
  else
    self.panels.step:Render(result, self.viewIndex)
  end
end

function UI:OpenGuideMenu(owner)
  MenuUtil.CreateContextMenu(owner, function(_, root)
    local lastCategory
    for _, guide in ipairs(ns.Registry:List()) do
      if guide.category ~= lastCategory then
        root:CreateTitle(guide.category)
        lastCategory = guide.category
      end
      root:CreateRadio(guide.title,
        function() return ns.DB.char.guide == guide.id end,
        function() ns.Core:SetGuide(guide.id) end)
    end
  end)
end

function UI:Toggle()
  local f = self:Create()
  f:SetShown(not f:IsShown())
  ns.DB.char.hidden = not f:IsShown()
end

function Sentier_OnAddonCompartmentClick()
  UI:Toggle()
end
