local _, ns = ...
local L = ns.L

local ListTab = {}
ns.ListTab = ListTab

local ROW_HEIGHT = 18
local ICONS = {
  done = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t ",
  todo = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14|t ",
  locked = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t ",
  unknown = L.ICON_UNKNOWN,
}

function ListTab:Create(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints()

  -- Même réglage que « Masquer les tâches terminées » dans les réglages, en sens inverse.
  local showDone = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
  showDone:SetPoint("TOPLEFT", -2, 2)
  showDone:SetSize(22, 22)
  showDone.label = showDone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  showDone.label:SetPoint("LEFT", showDone, "RIGHT", 2, 0)
  showDone.label:SetText(L.SHOW_DONE)
  showDone:SetScript("OnClick", function(self)
    ns.DB.account.hideDone = not self:GetChecked()
    ns.Core:Refresh()
  end)
  p.showDone = showDone

  local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -24)
  scroll:SetPoint("BOTTOMRIGHT", -24, 0)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)
  p.scroll, p.content, p.rows = scroll, content, {}

  local function onClick(row, button)
    local data = row.data
    if not data then return end
    if button == "RightButton" and data.kind == "task" then
      local guide = ns.Core.result.guide
      local task = data.entry.task
      ns.DB:SetMarked(guide, task, not ns.DB:IsMarked(guide, task))
      ns.Core:Refresh()
    elseif data.target then
      ns.Navigation:SetTarget(data.target.map, data.target.x, data.target.y, data.target.title)
    end
  end

  local function onEnter(row)
    local data = row.data
    if not data or data.kind ~= "task" then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(data.text)
    if data.reason then GameTooltip:AddLine(data.reason, 1, 0.3, 0.3) end
    if data.entry.task.note then GameTooltip:AddLine(data.entry.task.note, 1, 1, 1, true) end
    GameTooltip:AddLine(L.MANUAL_HINT, 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end

  local function getRow(i)
    if p.rows[i] then return p.rows[i] end
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 2, 0)
    row.text:SetPoint("RIGHT", -60, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.rep = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.rep:SetPoint("RIGHT", -2, 0)
    row.rep:SetTextColor(0.62, 0.77, 1)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnClick", onClick)
    row:SetScript("OnEnter", onEnter)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.rows[i] = row
    return row
  end

  function p:Render(result)
    self.showDone:SetChecked(not ns.DB.account.hideDone)
    local rows = ns.Models.List(result, ns.DB.account.hideDone)
    local width = self.scroll:GetWidth()
    for i, data in ipairs(rows) do
      local row = getRow(i)
      row.data = data
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
      row:SetWidth(width)
      if data.kind == "header" then
        row.text:SetText(data.text)
        row.text:SetTextColor(0.94, 0.78, 0.37)
        row.rep:SetText("")
      else
        local text = (ICONS[data.status] or "") .. data.text
        if data.status == "locked" and data.reason then text = text .. L.SEP_REASON .. data.reason end
        row.text:SetText(text)
        if data.status == "done" or data.status == "locked" then
          row.text:SetTextColor(0.5, 0.5, 0.5)
        else
          row.text:SetTextColor(0.91, 0.89, 0.82)
        end
        row.rep:SetText(data.rep or "")
      end
      row:Show()
    end
    for i = #rows + 1, #self.rows do
      self.rows[i]:Hide()
      self.rows[i].data = nil
    end
    self.content:SetSize(width, math.max(1, #rows * ROW_HEIGHT))
  end

  return p
end
