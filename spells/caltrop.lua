local my_utility = require("my_utility/my_utility")

local menu_elements_caltrop =
{
    tree_tab            = tree_node:new(1),
    main_boolean        = checkbox:new(true, get_hash(my_utility.plugin_label .. "caltrop_base_main_bool")),
    usage_filter        = combo_box:new(0, get_hash(my_utility.plugin_label .. "caltrop_usage_filter")),
    spell_range         = slider_float:new(1.0, 15.0, 2.60, get_hash(my_utility.plugin_label .. "caltrop_spell_range_2")),
    boss_override       = checkbox:new(true, get_hash(my_utility.plugin_label .. "boss_override_caltrop")),
}

local function menu()
    
    if menu_elements_caltrop.tree_tab:push("Caltrop")then
        menu_elements_caltrop.main_boolean:render("Enable Spell", "")
        local boss_options = {"Always for Vulnerability", "Elites and Bosses", "Only Bosses"}
        local boss_selection = menu_elements_caltrop.usage_filter:render("Usage", boss_options, "How to use caltrops")
        menu_elements_caltrop.spell_range:render("Spell Range", "", 1)
        menu_elements_caltrop.boss_override:render("Boss Override", "Cast on bosses even if not within specified delay after poison trap")
 
        menu_elements_caltrop.tree_tab:pop()
    end
end

local spell_id_caltrop = 389667;

local pois_trap = require("spells/poison_trap")

local caltrop_spell_data = spell_data:new(
    3.0,                        -- radius
    1.0,                       -- range
    0.5,                        -- cast_delay
    1.0,                        -- projectile_speed
    true,                      -- has_collision
    spell_id_caltrop,              -- spell_id
    spell_geometry.rectangular, -- geometry_type
    targeting_type.skillshot    --targeting_type
)

-- Set debug_console to false to disable all debug messages
local debug_console = false
local next_time_allowed_cast = 0.0;
local function logics(entity_list, target_selector_data, target)
    
    local menu_boolean = menu_elements_caltrop.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                spell_id_caltrop);

    if not is_logic_allowed then
        return false;
    end;
    
    if not target then
        -- Removed debug console print to prevent log spam
        return false
    end
    
    -- Check for boss override first
    local is_boss = target:is_boss()
    local boss_override = menu_elements_caltrop.boss_override:get()
    if is_boss and boss_override then
        if cast_spell.target(target, caltrop_spell_data, true) then
            local current_time = get_time_since_inject();
            next_time_allowed_cast = current_time + 9.0; 
            console.print("Casted Caltrop on Boss (Override)");
            return true;
        end
        return false;
    end

    local poison_trap_id = 416528;
    -- Check if Poison Trap was recently cast (1-2 seconds ago)
    local current_time = get_time_since_inject();
    if global_poison_trap_last_cast_time > 0 then
        local time_since_poison_trap = current_time - global_poison_trap_last_cast_time;
        
        -- If less than 1 second has passed since Poison Trap was cast, wait
        if time_since_poison_trap < 1.0 then
            return false;
        end
        
        -- If more than 2 seconds have passed since Poison Trap was cast, we missed our window
        if time_since_poison_trap > 2.0 and utility.is_spell_ready(poison_trap_id) then
            return false;
        end
    elseif utility.is_spell_ready(poison_trap_id) then
        -- If Poison Trap is ready and hasn't been cast yet, don't cast Caltrops
        -- Removed debug console print to prevent log spam
        return false
    end
    
    if menu_elements_caltrop.usage_filter:get() == 0 then
        if target:is_vulnerable() then
            return false
        end
    end

    local max_health = target:get_max_health()
    local current_health = target:get_current_health()
    local health_percentage = current_health / max_health
    local is_fresh = health_percentage >= 1.0
    if is_fresh then
        return false
    end

    local spell_range = menu_elements_caltrop.spell_range:get()
    local target_position = target:get_position()
    local player_position = get_player_position()
    local distance_sqr = player_position:squared_dist_to_ignore_z(target_position)
    if distance_sqr > (spell_range * spell_range) then
        -- Removed debug console print to prevent log spam
        return false
    end
    
    -- Modified to always cast after Poison Trap for the build's rotation
    if cast_spell.target(target, caltrop_spell_data, true) then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 9.0; 
        console.print("Casted Caltrop (1-2s after Poison Trap)");
        return true;
    end

    return false;
end


return 
{
    menu = menu,
    logics = logics,   
}