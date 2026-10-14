local _, ns = ...
local L = ns.L

-- Bouton rond au bord de la minicarte : clic gauche ouvre ou ferme le guide, clic droit les réglages.
-- On le fait glisser autour de la minicarte ; son angle est gardé dans SentierDB.minimap.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

-- WoW est en Lua 5.1 (math.atan2) ; les tests tournent en Lua 5.3 ou plus (math.atan à deux arguments).
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

function MinimapButton.AngleFrom(cx, cy, x, y)
  return math.deg(atan2(y - cy, x - cx)) % 360
end

function MinimapButton.Offset(angle, radius)
  local rad = math.rad(angle)
  return math.cos(rad) * radius, math.sin(rad) * radius
end

function MinimapButton:Place()
  if not self.button then return end
  local x, y = MinimapButton.Offset(ns.DB.account.minimap.angle, Minimap:GetWidth() / 2 + 10)
  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:Refresh()
  if self.button then self.button:SetShown(not ns.DB.account.minimap.hidden) end
end

function MinimapButton:Create()
  if self.button or not Minimap then return self.button end
  local b = CreateFrame("Button", "SentierMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  icon:SetPoint("TOPLEFT", 7, -6)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  b:SetScript("OnMouseDown", function() icon:SetVertexColor(0.6, 0.6, 0.6) end)
  b:SetScript("OnMouseUp", function() icon:SetVertexColor(1, 1, 1) end)
  b:SetScript("OnClick", function(_, button)
    ns.UI:Click()
    if button == "RightButton" then
      local f = ns.UI:Create()
      f:Show()
      ns.DB.char.hidden = false
      ns.Settings:Toggle(f)
    else
      ns.UI:Toggle()
    end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(L.ADDON_NAME)
    GameTooltip:AddLine(L.MINIMAP_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_RIGHT, 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_DRAG, 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      ns.DB.account.minimap.angle = MinimapButton.AngleFrom(mx, my, cx / scale, cy / scale)
      MinimapButton:Place()
    end)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    icon:SetVertexColor(1, 1, 1)
  end)

  self.button = b
  self:Place()
  self:Refresh()
  return b
end
