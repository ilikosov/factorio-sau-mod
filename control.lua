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
local AUTOFIRE_COOLDOWN = 300   -- должен совпадать с attack_parameters.cooldown пушки (data.lua)

-- storage.autofire[unit_number] = { entity = LuaEntity, enabled = true/false }
-- storage.autofire_last_shot[unit_number] = tick последнего авто-выстрела
local function init_storage()
  storage.autofire = storage.autofire or {}
  storage.autofire_last_shot = storage.autofire_last_shot or {}
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
  local entry = storage.autofire[id]
  local enabled = not (entry and entry.enabled)
  storage.autofire[id] = {entity = vehicle, enabled = enabled}

  player.print(enabled
    and "[SAU] Авто-огонь включён"
    or "[SAU] Авто-огонь выключен")
end)

-- Периодическое сканирование и "выстрел"
script.on_nth_tick(SCAN_INTERVAL, function()
  init_storage()
  for unit_number, entry in pairs(storage.autofire) do
    if entry.enabled then
      local vehicle = entry.entity

      if not vehicle or not vehicle.valid then
        storage.autofire[unit_number] = nil
        storage.autofire_last_shot[unit_number] = nil
      else
        -- Как у artillery-wagon: авто-огонь работает только пока за рулём
        -- есть игрок и машина полностью остановлена.
        local last_shot = storage.autofire_last_shot[unit_number] or 0
        local ready_to_fire = vehicle.get_driver() ~= nil
          and vehicle.speed == 0
          and (game.tick - last_shot) >= AUTOFIRE_COOLDOWN

        if ready_to_fire then
          local ammo_inv = vehicle.get_inventory(defines.inventory.car_ammo)

          -- Ищем первый слот с патроном, а не полагаемся на то, что
          -- снаряд обязательно лежит в первом слоте инвентаря.
          local slot = nil
          if ammo_inv then
            for i = 1, #ammo_inv do
              local candidate = ammo_inv[i]
              if candidate and candidate.valid_for_read then
                slot = candidate
                break
              end
            end
          end

          if slot then
            local enemies = vehicle.surface.find_enemy_units(vehicle.position, AUTOFIRE_RADIUS, vehicle.force)
            if #enemies > 0 then
              local target = enemies[1]

              -- Расходуем один снаряд вручную (т.к. стреляем в обход штатной
              -- логики "car" через create_entity, авто-расход патронов не происходит)
              slot.count = slot.count - 1
              if slot.count <= 0 then slot.clear() end

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

              storage.autofire_last_shot[unit_number] = game.tick
            end
          end
        end
      end
    end
  end
end)
