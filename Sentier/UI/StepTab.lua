local _, ns = ...
local L = ns.L

-- Premier fichier d'interface chargé (.toc) : il crée ns.UI et le cadre commun.
ns.UI = ns.UI or { viewIndex = 1 }
ns.UI.BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local StepTab = {}
ns.StepTab = StepTab

function StepTab:Create(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints()

  local bar = CreateFrame("StatusBar", nil, p)
  bar:SetPoint("TOPLEFT", 2, -2)
  bar:SetPoint("TOPRIGHT", -2, -2)
  bar:SetHeight(12)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(0.25, 0.64, 0.3)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  bar.bg:SetColorTexture(0.16, 0.16, 0.16)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("CENTER")
  p.bar = bar

  local step = CreateFrame("Button", nil, p)
  step:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -8)
  step:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -8)
  step:SetHeight(90)
  step.bg = step:CreateTexture(nil, "BACKGROUND")
  step.bg:SetAllPoints()
  step.bg:SetColorTexture(0.12, 0.11, 0.08)
  step.edge = step:CreateTexture(nil, "ARTWORK")
  step.edge:SetPoint("TOPLEFT")
  step.edge:SetPoint("BOTTOMLEFT")
  step.edge:SetWidth(3)
  step.edge:SetColorTexture(0.94, 0.78, 0.37)
  step.title = step:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  step.title:SetPoint("TOPLEFT", 10, -6)
  step.title:SetPoint("TOPRIGHT", -6, -6)
  step.title:SetJustifyH("LEFT")
  step.detail = step:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  step.detail:SetPoint("TOPLEFT", step.title, "BOTTOMLEFT", 0, -4)
  step.detail:SetPoint("TOPRIGHT", step.title, "BOTTOMRIGHT", 0, -4)
  step.detail:SetJustifyH("LEFT")
  step.detail:SetJustifyV("TOP")
  step.rep = step:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  step.rep:SetPoint("BOTTOMRIGHT", -6, 6)
  step.rep:SetTextColor(0.62, 0.77, 1)
  step:SetScript("OnClick", function()
    local target = p.model and p.model.target
    if target then ns.Navigation:SetTarget(target.map, target.x, target.y, target.title) end
  end)
  p.step = step

  p.nextText = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  p.nextText:SetPoint("TOPLEFT", step, "BOTTOMLEFT", 0, -6)
  p.nextText:SetPoint("TOPRIGHT", step, "BOTTOMRIGHT", 0, -6)
  p.nextText:SetJustifyH("LEFT")

  local function button(label, width, x, onClick)
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(width, 20)
    b:SetText(label)
    b:SetPoint("BOTTOMLEFT", x, 2)
    b:SetScript("OnClick", onClick)
    return b
  end

  p.prev = button(L.BTN_PREV, 28, 2, function()
    ns.UI.viewIndex = math.max(1, ns.UI.viewIndex - 1)
    ns.UI:Render(ns.Core.result)
  end)
  p.skip = button(L.BTN_SKIP, 70, 34, function()
    if p.model and p.model.entry then
      ns.DB:SetSkipped(ns.Core.result.guide, p.model.entry.task, true)
      ns.Core:Refresh()
    end
  end)
  p.next = button(L.BTN_NEXT, 28, 108, function()
    ns.UI.viewIndex = ns.UI.viewIndex + 1
    ns.UI:Render(ns.Core.result)
  end)

  function p:Render(result, viewIndex)
    local m = ns.Models.Step(result, viewIndex)
    self.model = m
    ns.UI.viewIndex = m.index or 1
    if m.renownText then
      self.bar:Show()
      self.bar:SetMinMaxValues(0, math.max(1, m.renownMax))
      self.bar:SetValue(m.renownValue)
      self.bar.text:SetText(m.renownText)
    else
      self.bar:Hide()
    end
    self.step.title:SetText(m.kind and L.STEP_KIND_FMT:format(m.title, m.kind) or m.title)
    self.step.detail:SetText(m.detail or "")
    self.step.rep:SetText(m.rep or "")
    self.nextText:SetText(m.nextText or "")
    self.prev:SetEnabled((m.index or 1) > 1)
    self.next:SetEnabled(m.count ~= nil and m.index < m.count)
    self.skip:SetEnabled(m.entry ~= nil)
  end

  return p
end
