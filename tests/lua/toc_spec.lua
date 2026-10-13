local function tocFiles()
  local files = {}
  for line in io.lines("Sentier/Sentier.toc") do
    local clean = (line:gsub("\r", ""))
    if clean ~= "" and not clean:match("^#") then
      files[#files + 1] = "Sentier/" .. (clean:gsub("\\", "/"))
    end
  end
  return files
end

describe("Sentier.toc", function()
  it("liste des fichiers qui existent et compilent", function()
    for _, path in ipairs(tocFiles()) do
      local chunk, err = loadfile(path)
      assert.is_not_nil(chunk, path .. " : " .. tostring(err))
    end
  end)

  it("n'oublie aucun fichier Lua de l'addon", function()
    local listed = {}
    for _, path in ipairs(tocFiles()) do listed[path] = true end
    local pipe = io.popen("find Sentier -name '*.lua'")
    for path in pipe:lines() do
      assert.is_true(listed[path] == true, path .. " absent du .toc")
    end
    pipe:close()
  end)

  it("déclare l'interface 12.1, les sauvegardes et le bouton de la minicarte", function()
    local f = io.open("Sentier/Sentier.toc", "r")
    local text = f:read("*a")
    f:close()
    for _, needle in ipairs({
      "## Interface: 120100",
      "## SavedVariables: SentierDB",
      "## SavedVariablesPerCharacter: SentierCharDB",
      "## AddonCompartmentFunc: Sentier_OnAddonCompartmentClick",
    }) do
      assert.truthy(text:find(needle, 1, true), needle)
    end
  end)
end)
