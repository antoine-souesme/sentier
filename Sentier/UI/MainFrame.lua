local _, ns = ...
local L = ns.L

-- ns.UI (et son BACKDROP) est créé par StepTab.lua, premier fichier d'interface du .toc.
local UI = ns.UI or { viewIndex = 1 }
ns.UI = UI

-- La fenêtre est toujours accrochée par son coin haut gauche : sinon, l'agrandir par le coin
-- bas droit la fait grandir aussi vers le haut, loin du curseur.
local function anchorTopLeft(f)
  local left, top = f:GetLeft(), f:GetTop()
  if not left or not top then return end
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

local function savePosition(f)
  anchorTopLeft(f)
  local point, _, relPoint, x, y = f:GetPoint(1)
  ns.DB.account.frame = { point = point, relPoint = relPoint, x = x, y = y, w = f:GetWidth(), h = f:GetHeight() }
end

local function startMoving(f)
  if ns.DB.account.locked then return end
  anchorTopLeft(f)
  f:StartMoving()
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
  -- Sentier garde lui-même la position : le jeu ne doit pas la remplacer par la sienne.
  if f.SetDontSavePosition then f:SetDontSavePosition(true) end
  f:SetResizable(true)
  f:SetClampedToScreen(true)
  f:SetResizeBounds(260, 180, 600, 700)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", startMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePosition(self) end)

  -- Barre de titre : toute sa largeur sert de poignée pour déplacer la fenêtre.
  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT", 4, -4)
  bar:SetPoint("TOPRIGHT", -4, -4)
  bar:SetHeight(24)
  bar:EnableMouse(true)
  bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", function() startMoving(f) end)
  bar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
  bar.hover = bar:CreateTexture(nil, "BACKGROUND")
  bar.hover:SetAllPoints()
  bar.hover:SetColorTexture(1, 1, 1, 0.06)
  bar.hover:Hide()
  bar:SetScript("OnEnter", function() bar.hover:Show() end)
  bar:SetScript("OnLeave", function() bar.hover:Hide() end)

  local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", 6, 0)
  title:SetPoint("RIGHT", -52, 0)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  self.title = title

  local gear = CreateFrame("Button", nil, bar)
  gear:SetSize(20, 20)
  gear:SetPoint("RIGHT", -2, 0)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  gear:SetScript("OnClick", function() UI:Click(); ns.Settings:Toggle(f) end)

  local menu = CreateFrame("Button", nil, bar)
  menu:SetSize(22, 22)
  menu:SetPoint("RIGHT", gear, "LEFT", -4, 0)
  menu:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
  menu:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
  menu:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Highlight", "ADD")
  menu:SetScript("OnClick", function(btn) UI:Click(); UI:OpenGuideMenu(btn) end)
  menu:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.MENU_GUIDES)
    GameTooltip:Show()
  end)
  menu:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.tabs = {}
  for i, key in ipairs({ "step", "list" }) do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(70, 20)
    b:SetText(key == "step" and L.TAB_STEP or L.TAB_LIST)
    b:SetPoint("TOPLEFT", 10 + (i - 1) * 74, -32)
    b:SetScript("OnClick", function() UI:Click(); UI:SetTab(key) end)
    self.tabs[key] = b
  end

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", 8, -56)
  body:SetPoint("BOTTOMRIGHT", -8, 24)
  self.panels = { step = ns.StepTab:Create(body), list = ns.ListTab:Create(body) }

  local message = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  message:SetPoint("BOTTOMLEFT", 10, 8)
  message:SetPoint("BOTTOMRIGHT", -20, 8)
  message:SetJustifyH("LEFT")
  message:SetTextColor(0.94, 0.78, 0.37)
  self.message = message

  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(14, 14)
  grip:SetPoint("BOTTOMRIGHT", -3, 3)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetScript("OnMouseDown", function()
    if ns.DB.account.locked then return end
    anchorTopLeft(f)
    f:StartSizing("BOTTOMRIGHT")
  end)
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
  self.title:SetText(result.guide.title)
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

-- Son de clic du jeu. Protégé : les noms de sons changent parfois d'une version à l'autre.
function UI:Click()
  if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
    pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  end
end

-- Confirme une action : son de clic, puis message en bas de la fenêtre pendant 3 secondes.
function UI:Notify(text)
  self:Click()
  if not self.message then return end
  self.message:SetText(text)
  if self.messageTimer then self.messageTimer:Cancel() end
  self.messageTimer = C_Timer.NewTimer(3, function() self.message:SetText("") end)
end

function UI:GoTo(target)
  if target then
    ns.Navigation:SetTarget(target.map, target.x, target.y, target.title)
    self:Notify(L.FEEDBACK_WAYPOINT:format(target.title))
  else
    self:Notify(L.FEEDBACK_NO_POSITION)
  end
end

function Sentier_OnAddonCompartmentClick()
  UI:Toggle()
end
