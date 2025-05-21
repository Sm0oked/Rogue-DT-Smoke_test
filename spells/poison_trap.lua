local my_utility = require("my_utility/my_utility")

local menu_elements_pois_trap =
{
    tree_tab              = tree_node:new(1),
    main_boolean          = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean_trap_base_pos")),
   
    trap_mode         = combo_box:new(0, get_hash(my_utility.plugin_label .. "trap_base_base_pos")),
    keybind               = keybind:new(0x01, false, get_hash(my_utility.plugin_label .. "trap_base_keybind_pos")),
    keybind_ignore_hits   = checkbox:new(true, get_hash(my_utility.plugin_label .. "keybind_ignore_min_hitstrap_base_pos")),

    min_hits              = slider_int:new(1, 20, 1, get_hash(my_utility.plugin_label .. "min_hits_to_casttrap_base_pos")),
    
    allow_percentage_hits = checkbox:new(true, get_hash(my_utility.plugin_label .. "allow_percentage_hits_trap_base_pos")),
    min_percentage_hits   = slider_float:new(0.1, 1.0, 0.50, get_hash(my_utility.plugin_label .. "min_percentage_hits_trap_base_pos")),
    soft_score            = slider_float:new(2.0, 15.0, 4.0, get_hash(my_utility.plugin_label .. "min_percentage_hits_trap_base_soft_core_pos")),

    spell_range   = slider_float:new(1.0, 15.0, 3.10, get_hash(my_utility.plugin_label .. "poison_trap_spell_range_2")),
    spell_radius   = slider_float:new(0.50, 5.0, 3.50, get_hash(my_utility.plugin_label .. "poison_trap_spell_radius_2")),
    
    boss_override = checkbox:new(true, get_hash(my_utility.plugin_label .. "boss_override_poison_trap")),
}


local function menu()
    
    if menu_elements_pois_trap.tree_tab:push("Poison Trap") then
        menu_elements_pois_trap.main_boolean:render("Enable Spell", "");

        local options =  {"Auto", "Keybind"};
        menu_elements_pois_trap.trap_mode:render("Mode", options, "");

        menu_elements_pois_trap.keybind:render("Keybind", "");
        menu_elements_pois_trap.keybind_ignore_hits:render("Keybind Ignores Min Hits", "");

        menu_elements_pois_trap.min_hits:render("Min Hits", "");
        
        menu_elements_pois_trap.boss_override:render("Boss Override", "Cast on bosses regardless of hit count");

        menu_elements_pois_trap.allow_percentage_hits:render("Allow Percentage Hits", "");
        if menu_elements_pois_trap.allow_percentage_hits:get() then
            menu_elements_pois_trap.min_percentage_hits:render("Min Percentage Hits", "", 1);
            menu_elements_pois_trap.soft_score:render("Soft Score", "", 1);
        end       

        menu_elements_pois_trap.spell_range:render("Spell Range", "", 1)
        menu_elements_pois_trap.spell_radius:render("Spell Radius", "", 1)

        menu_elements_pois_trap.tree_tab:pop();
    end
end

local my_target_selector = require("my_utility/my_target_selector");

local poison_trap_id = 416528;

local next_time_allowed_cast = 0.0;
local function get_spell_charges(local_player, poison_trap_id)
    if not local_player then 
        return false 
    end

    local charges = local_player:get_spell_charges(poison_trap_id)
    if not charges then
        return false;
    end
    
    if charges <= 0 then
        return false;
    end
    
    return true;
end

local debug_console = false
local function is_valid_logics(entity_list, target_selector_data, best_target)
    
    local menu_boolean = menu_elements_pois_trap.main_boolean:get();
    local is_logic_allowed = my_utility.is_spell_allowed(
                menu_boolean, 
                next_time_allowed_cast, 
                poison_trap_id);

    if not is_logic_allowed then
        return nil;
    end;

    local player_position = get_player_position()
    local keybind_used = menu_elements_pois_trap.keybind:get_state();
    local trap_mode = menu_elements_pois_trap.trap_mode:get();
    if trap_mode == 1 then
        if  keybind_used == 0 then   
            return nil;
        end;
    end;

    local keybind_ignore_hits = menu_elements_pois_trap.keybind_ignore_hits:get();
   
    ---@type boolean
    local keybind_can_skip = keybind_ignore_hits == true and keybind_used > 0;
    
    local boss_override = menu_elements_pois_trap.boss_override:get();
    local targeting_boss = false;
    
    -- Check if we have a boss target, and if so enable boss override mode
    if best_target and best_target:is_boss() and boss_override then
        targeting_boss = true;
        -- Removed debug print for less spam
    end
    
    if targeting_boss then
        -- If targeting a boss and override is enabled, cast at the boss position
        return best_target:get_position();
    end
    
    local is_percentage_hits_allowed = menu_elements_pois_trap.allow_percentage_hits:get();
    local min_percentage = menu_elements_pois_trap.min_percentage_hits:get();
    if not is_percentage_hits_allowed then
        min_percentage = 0.0;
    end

    local spell_range =  menu_elements_pois_trap.spell_range:get()
    local spell_radius =  menu_elements_pois_trap.spell_radius:get()
    local min_hits_menu = menu_elements_pois_trap.min_hits:get();

    local area_data = my_target_selector.get_most_hits_circular(player_position, spell_range, spell_radius)
    if not area_data.main_target then
        -- Removed debug print for less spam
        return nil;
    end

    local is_area_valid = my_target_selector.is_valid_area_spell_aio(area_data, min_hits_menu, entity_list, min_percentage);

    if not is_area_valid and not keybind_can_skip  then
        -- Removed debug print for less spam
        return nil;
    end

    if not area_data.main_target:is_enemy() then
        -- Removed debug print for less spam
        return nil;
    end

    local constains_relevant = false;
    for _, victim in ipairs(area_data.victim_list) do
        if victim:is_elite() or victim:is_champion() or victim:is_boss() then
            constains_relevant = true;
        end
    end

    if not constains_relevant and area_data.score < menu_elements_pois_trap.soft_score:get() and not keybind_can_skip  then
        -- Removed debug prints for less spam
        return nil;
    end

    local cast_position_a = area_data.main_target:get_position();
    local best_cast_data = my_utility.get_best_point(cast_position_a, spell_radius, area_data.victim_list);
 
    -- Initialize variables to store the closest target to the point
    local closer_target_to_zone = nil
    local closest_distance_sqr = math.huge

    -- Loop through the list of victims to find the closest one to the point
    for _, victim in ipairs(best_cast_data.victim_list) do
        local victim_position = victim:get_position()
        local distance_sqr = player_position:squared_dist_to_ignore_z(victim_position)
        
        -- If the distance to the current victim is less than the closest distance so far, update the closest target
        if distance_sqr < closest_distance_sqr then
            closer_target_to_zone = victim
            closest_distance_sqr = distance_sqr
        end
    end
    
    if closest_distance_sqr > (spell_range * spell_range) and not keybind_can_skip  then
        -- Removed debug print for less spam
        return nil;
    end

    return best_cast_data.point 
end

local function logics(entity_list, target_selector_data, best_target)
    
    local cast_position = is_valid_logics(entity_list, target_selector_data, best_target)
    if not cast_position then
        return false
    end

    if cast_spell.position(poison_trap_id, cast_position, 0.40)then
        local current_time = get_time_since_inject();
        next_time_allowed_cast = current_time + 9.0;
        global_poison_trap_last_cast_time = current_time
        global_poison_trap_last_cast_position = cast_position
        console.print("Rouge Plugin, Casted Poison Trap (9s rotation)");
        return true;
    end

    return false;
 
end

return 
{
    menu = menu,
    logics = logics,   
    is_valid_logics = is_valid_logics,
}