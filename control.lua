-- control.lua
--
-- ВАЖНО: движок Factorio реализует автонаведение (сканирование и обстрел
-- врагов без участия игрока) только для сущностей типа "artillery-turret"
-- и "artillery-wagon". Наша машина имеет тип "car", поэтому родного
-- автонаведения у неё нет -- ниже приведена САМОДЕЛЬНАЯ имитация через
-- скрипт. Это отправная точка: протестируйте в игре и подстройте цифры
-- (радиус, урон, визуальные эффекты) под себя.

local AUTOFIRE_RADIUS = 28      -- должен совпадать с attack_parameters.range пушки
local SCAN_INTERVAL = 60        -- как часто проверять цели, тиков (60 = раз в секунду)

-- storage.autofire[unit_number] = true/false
local function init_storage()
  storage.autofire = storage.autofire or {}
end

script.on_init(init_storage)
script.on_configuration_changed(init_storage)

-- Переключение авто-огня по горячей клавише (ALT+F по умолчанию)
script.on_event("sau-toggle-autofire", function(event)
  local player = game.get_player(event.player_index)
  if not player or not player.vehicle then return end

  local vehicle = player.vehicle
  if vehicle.name ~= "sau-artillery" then return end

  init_storage()
  local id = vehicle.unit_number
  storage.autofire[id] = not storage.autofire[id]

  player.print(storage.autofire[id]
    and "[SAU] Авто-огонь включён"
    or "[SAU] Авто-огонь выключен")
end)

-- Периодическое сканирование и "выстрел"
script.on_nth_tick(SCAN_INTERVAL, function()
  init_storage()
  for unit_number, enabled in pairs(storage.autofire) do
    if enabled then
      local vehicle = nil
      -- ищем машину среди всех поверхностей (быстрее было бы кэшировать саму entity,
      -- но так проще и надёжнее переживает save/load)
      for _, surface in pairs(game.surfaces) do
        local found = surface.find_entities_filtered{name = "sau-artillery"}
        for _, e in pairs(found) do
          if e.valid and e.unit_number == unit_number then
            vehicle = e
            break
          end
        end
        if vehicle then break end
      end

      if not vehicle or not vehicle.valid then
        storage.autofire[unit_number] = nil
      else
        local ammo_inv = vehicle.get_inventory(defines.inventory.car_ammo)
        local has_ammo = ammo_inv and not ammo_inv.is_empty()

        if has_ammo then
          local enemies = vehicle.surface.find_enemy_units(vehicle.position, AUTOFIRE_RADIUS, vehicle.force)
          if #enemies > 0 then
            local target = enemies[1]

            -- Расходуем один снаряд вручную (т.к. стреляем в обход штатной
            -- логики "car" через create_entity, авто-расход патронов не происходит)
            local slot = ammo_inv[1]
            if slot and slot.valid_for_read then
              slot.count = slot.count - 1
              if slot.count <= 0 then slot.clear() end
            end

            -- Создаём артиллерийский снаряд, летящий в цель.
            -- "artillery-projectile" -- существующий в base-моде тип сущности.
            vehicle.surface.create_entity{
              name = "artillery-projectile",
              position = vehicle.position,
              speed = 1,
              force = vehicle.force,
              source = vehicle,
              target = target,
              max_range = AUTOFIRE_RADIUS
            }
          end
        end
      end
    end
  end
end)
