require("lualib.utils")

local max_effectivity_level = tonumber(settings.startup["battery-roboport-energy-research-limit"].value)
local max_productivity_level = tonumber(settings.startup["battery-roboport-energy-research-limit"].value)
local max_speed_level = tonumber(settings.startup["battery-roboport-energy-research-limit"].value)
local update_timer = tonumber(settings.startup["battery-roboport-update-timer"].value)
local upgrade_timer = tonumber(settings.startup["battery-roboport-upgrade-timer"].value)
local roboports_to_upgrade = {}
local roboports_to_downgrade = {}
local mod_roboport_name = "battery-roboport-mk-"

script.on_init(
    function ()
        Setup_Vars()
    end
)


function Setup_Vars()
    if global.EffectivityResearchLevel == nil then
        global.EffectivityResearchLevel = 0
    end
    if global.ProductivityResearchLevel == nil then
        global.ProductivityResearchLevel = 0
    end
    if global.SpeedResearchLevel == nil then
        global.SpeedResearchLevel = 0
    end
end

function Get_level_from_name(to_check)
    local eff = string.sub(to_check, -5, -5)
    local prod = string.sub(to_check, -3, -3)
    local speed = string.sub(to_check, -1, -1)
    return {tonumber(eff), tonumber(prod), tonumber(speed)}
end

function Is_valid_roboport(roboport)
    local r_name = roboport.name

    if r_name == "roboport" then
        -- The entity is from vanilla Factorio
        return true
    elseif utils.starts_with(r_name, mod_roboport_name) then
        local level = Get_level_from_name(r_name)
        -- Check for correct levels, to avoid replacing already correct roboports.
        if level[1] < global.EffectivityResearchLevel or level[2] < global.ProductivityResearchLevel or level[3] < global.SpeedResearchLevel then
            return true
        end
    else
        -- Entity is from another mod
        return false
    end
end

function Is_research_valid()
    Setup_Vars() -- Shouldn't need to be used here, but is here as a bandaid fix
    local eff = global.EffectivityResearchLevel > 0 and global.EffectivityResearchLevel <= max_effectivity_level
    local prod = global.ProductivityResearchLevel > 0 and global.ProductivityResearchLevel <= max_productivity_level
    local speed = global.SpeedResearchLevel > 0 and global.SpeedResearchLevel <= max_speed_level
    return eff and prod and speed
end


local function upgrade_roboport()
    local roboport, needs_upgrade = next(roboports_to_upgrade)
    if roboport == nil then
        return
    end
    if roboport.valid and needs_upgrade == true then
        local surface = roboport.surface
        if Is_valid_roboport(roboport) then
            local old_energy = roboport.energy
            local suffix = utils.get_internal_suffix(global.EffectivityResearchLevel, global.ProductivityResearchLevel, global.SpeedResearchLevel)

            local to_create = {
                name = mod_roboport_name .. suffix,
                position = roboport.position,
                force = roboport.force,
                fast_replace = true,
                spill = false,
                create_build_effect_smoke = false,
            }
            local created_rport = surface.create_entity(to_create)
            created_rport.energy = old_energy
            roboports_to_upgrade[roboport] = nil

            roboport.destroy()
            end
    else
        roboports_to_upgrade[roboport] = nil
    end
end

local function downgrade_ghost_roboport()
    local roboport, needs_downgrade = next(roboports_to_downgrade)
    if roboport == nil then
        return
    end
    if roboport.valid and needs_downgrade == true then
        local surface = roboport.surface
        if roboport.name == "entity-ghost" and utils.starts_with(roboport.ghost_name, mod_roboport_name) then
            local to_create = {
                name = "entity-ghost",
                type = "entity-ghost",
                ghost_name = "roboport",
                ghost_type = "roboport",
                ghost_prototype = "roboport",
                position = roboport.position,
                force = roboport.force,
                fast_replace = true,
                spill = false,
                create_build_effect_smoke = false,
            }
            local created_rport = surface.create_entity(to_create)
            roboports_to_downgrade[roboport] = nil

            roboport.destroy()
            end
    else
        roboports_to_downgrade[roboport] = nil
    end
end

local function mark_roboports_for_upgrade()
    for _, surface in pairs(game.surfaces) do
        for i, roboport in pairs(surface.find_entities_filtered{
            type = "roboport"
        }) do
            roboports_to_upgrade[roboport] = true
        end
    end
end


script.on_event(defines.events.on_research_finished,
    function (event)
        if utils.starts_with(event.research.name, "roboport-effectivity") then
            global.EffectivityResearchLevel = global.EffectivityResearchLevel + 1
            mark_roboports_for_upgrade()
        elseif utils.starts_with(event.research.name, "roboport-productivity") then
            global.ProductivityResearchLevel = global.ProductivityResearchLevel + 1
            mark_roboports_for_upgrade()
        elseif utils.starts_with(event.research.name, "roboport-speed") then
            global.SpeedResearchLevel = global.SpeedResearchLevel + 1
            mark_roboports_for_upgrade()
        end
    end
)


script.on_event(defines.events.on_research_reversed,
    function (event)
        if utils.starts_with(event.research.name, "roboport-effectivity") then
            global.EffectivityResearchLevel = global.EffectivityResearchLevel - 1
        elseif utils.starts_with(event.research.name, "roboport-productivity") then
            global.ProductivityResearchLevel = global.ProductivityResearchLevel - 1
        elseif utils.starts_with(event.research.name, "roboport-speed") then
            global.SpeedResearchLevel = global.SpeedResearchLevel - 1
        end
    end
)

local function mark_roboport_for_upgrade(roboport)
    if Is_valid_roboport(roboport) then
        roboports_to_upgrade[roboport] = true
    end
end


local function mark_roboport_for_downgrade(roboport)
    roboports_to_downgrade[roboport] = true
end


local function on_built(event)
    if event.created_entity.name == "entity-ghost" or event.created_entity.type == "entity-ghost" then
        mark_roboport_for_downgrade(event.created_entity)
    else
        mark_roboport_for_upgrade(event.created_entity)
    end
end

script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)


script.on_nth_tick(
    upgrade_timer,
    function ()
        upgrade_roboport()
        downgrade_ghost_roboport()
    end
)
