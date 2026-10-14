local H = dofile("tests/lua/helper.lua")

describe("MinimapButton", function()
  local M

  before_each(function()
    local ns = H.load()
    assert(loadfile("Sentier/UI/MinimapButton.lua"))("Sentier", ns)
    M = ns.MinimapButton
  end)

  local function near(a, b) return math.abs(a - b) < 1e-6 end

  it("donne l'angle du curseur vu depuis le centre de la minicarte", function()
    assert.is_true(near(0, M.AngleFrom(100, 100, 150, 100)))
    assert.is_true(near(90, M.AngleFrom(100, 100, 100, 150)))
    assert.is_true(near(180, M.AngleFrom(100, 100, 50, 100)))
  end)

  it("ne donne jamais d'angle négatif sous le centre", function()
    assert.is_true(near(270, M.AngleFrom(100, 100, 100, 50)))
    assert.is_true(near(315, M.AngleFrom(0, 0, 1, -1)))
  end)

  it("place le bouton sur le cercle à partir de l'angle", function()
    local x, y = M.Offset(0, 80)
    assert.is_true(near(80, x) and near(0, y))
    x, y = M.Offset(90, 80)
    assert.is_true(near(0, x) and near(80, y))
  end)

  it("retrouve l'angle d'une position calculée", function()
    local x, y = M.Offset(225, 80)
    assert.is_true(near(225, M.AngleFrom(0, 0, x, y)))
  end)
end)
