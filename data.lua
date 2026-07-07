local util = require("util")

-- =========================================================
-- 1. ПУШКА (гарантированно совместима с обычными арт-снарядами)
--    Берём attack_parameters от ванильной пушки арт-вагона,
--    поэтому боеприпас "artillery-shell" подходит без изменений.
-- =========================================================
local sau_cannon = util.table.deepcopy(data.raw["gun"]["artillery-wagon-cannon"])
sau_cannon.name = "sau-cannon"
sau_cannon.icon = "__base__/graphics/icons/artillery-wagon-cannon.png"
sau_cannon.icon_size = 64
sau_cannon.flags = {"hidden"} -- пушка не должна лежать в инвентаре как отдельный предмет
-- Чуть уменьшим дальность и урон относительно ж/д вагона -- машина легче и менее устойчива
sau_cannon.attack_parameters.range = 28
sau_cannon.attack_parameters.cooldown = 300 -- в тиках, дольше перезарядка чем у ж/д версии
sau_cannon.subgroup = "gun"
sau_cannon.order = "z-sau-cannon"

-- =========================================================
-- 2. ТРАНСПОРТНОЕ СРЕДСТВО (на основе танка)
-- =========================================================
local sau_vehicle = util.table.deepcopy(data.raw["car"]["tank"])
sau_vehicle.name = "sau-artillery"
sau_vehicle.icon = "__base__/graphics/icons/tank.png"
sau_vehicle.icon_size = 64
sau_vehicle.minable = {mining_time = 2, result = "sau-artillery"}
sau_vehicle.max_health = 700           -- чуть хрупче танка -- это машина поддержки, не штурмовая
sau_vehicle.weight = 6000              -- тяжелее танка
sau_vehicle.braking_force = 60
sau_vehicle.friction_force = 0.5
sau_vehicle.energy_per_hit_point = 0.6
sau_vehicle.consumption = "1200kW"
sau_vehicle.effectivity = 0.7
sau_vehicle.rotation_speed = 0.0035    -- медленнее разворот, тяжёлая машина
sau_vehicle.guns = {"sau-cannon"}
sau_vehicle.equipment_grid = nil       -- убираем броне-сетку танка, у нас другой баланс
-- звук выстрела не нужно переносить отдельно: он уже часть attack_parameters,
-- скопированных в sau_cannon вместе с пушкой арт-вагона (см. выше)
sau_vehicle.order = "z-sau-artillery"

data:extend({sau_cannon})
data:extend({sau_vehicle})

-- =========================================================
-- 3. ПРЕДМЕТ (для крафта / инвентаря)
-- =========================================================
data:extend({
  {
    type = "item-with-entity-data",
    name = "sau-artillery",
    icon = "__base__/graphics/icons/tank.png",
    icon_size = 64,
    subgroup = "transport",
    order = "z-sau-artillery",
    place_result = "sau-artillery",
    stack_size = 1
  }
})

-- =========================================================
-- 4. РЕЦЕПТ
-- =========================================================
data:extend({
  {
    type = "recipe",
    name = "sau-artillery",
    enabled = false,
    ingredients = {
      {"tank", 1},
      {"artillery-wagon", 1},
      {"steel-plate", 50},
      {"processing-unit", 20}
    },
    energy_required = 30,
    results = {{"sau-artillery", 1}}
  }
})

-- =========================================================
-- 4b. ГОРЯЧАЯ КЛАВИША ДЛЯ АВТО-ОГНЯ (экспериментальная фича, см. control.lua)
-- =========================================================
data:extend({
  {
    type = "custom-input",
    name = "sau-toggle-autofire",
    key_sequence = "ALT + F",
    consuming = "none"
  }
})

-- =========================================================
-- 5. ТЕХНОЛОГИЯ
-- =========================================================
data:extend({
  {
    type = "technology",
    name = "sau-artillery",
    icon = "__base__/graphics/technology/artillery.png",
    icon_size = 128,
    prerequisites = {"tank", "artillery"},
    unit = {
      count = 300,
      ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1}
      },
      time = 30
    },
    effects = {
      {type = "unlock-recipe", recipe = "sau-artillery"}
    },
    order = "z-sau-artillery"
  }
})
