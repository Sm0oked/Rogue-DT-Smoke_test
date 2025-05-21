local local_player = get_local_player()
if local_player == nil then
    return
end

local character_id = local_player:get_character_class_id();
local is_rouge = character_id == 3;
if not is_rouge then
 return
end;

-- orbwalker settings
orbwalker.set_block_movement(true);
orbwalker.set_clear_toggle(true);

local my_target_selector = require("my_utility/my_target_selector");
local my_utility = require("my_utility/my_utility");
local spell_data = require("my_utility/spell_data");
local spell_priority = require("spell_priority");
local menu = require("menu");

-- Cache for heavy function results
local next_target_update_time = 0.0 -- Time of next target evaluation
local next_cast_time = 0.0          -- Time of next possible cast
local targeting_refresh_interval = menu.targeting_refresh_interval:get()

-- Declare equipped_lookup at this scope so it's accessible to both on_render_menu and on_update
local equipped_lookup = {}

local spells =
{
    concealment             = require("spells/concealment"),
    caltrop                 = require("spells/caltrop"),
    puncture                = require("spells/puncture"),
    heartseeker             = require("spells/heartseeker"),
    forcefull_arrow         = require("spells/forcefull_arrow"),
    blade_shift             = require("spells/blade_shift"),
    invigorating_strike     = require("spells/invigorating_strike"),
    twisting_blade          = require("spells/twisting_blade"),
    barrage                 = require("spells/barrage"),
    rapid_fire              = require("spells/rapid_fire"),
    flurry                  = require("spells/flurry"),
    penetrating_shot        = require("spells/penetrating_shot"),
    dash                    = require("spells/dash"),
    shadow_step             = require("spells/shadow_step"),
    smoke_grenade           = require("spells/smoke_grenade"),
    poison_trap             = require("spells/poison_trap"),
    dark_shroud             = require("spells/dark_shroud"),
    shadow_imbuement        = require("spells/shadow_imbuement"),
    poison_imbuement        = require("spells/poison_imbuement"),
    cold_imbuement          = require("spells/cold_imbuement"),
    shadow_clone            = require("spells/shadow_clone"),
    death_trap              = require("spells/death_trap"),
    rain_of_arrows          = require("spells/rain_of_arrows"),
    dance_of_knives         = require("spells/dance_of_knives"),
}

on_render_menu(function()
    if not menu.main_tree:push("Rouge: Base") then
        return;
    end;

    menu.main_boolean:render("Enable Plugin", "");

    if not menu.main_boolean:get() then
        -- plugin not enabled, stop rendering menu elements
        menu.main_tree:pop();
        return;
    end;

    local options = {"Melee", "Ranged"};
    menu.mode:render("Mode", options, "");

    menu.dash_cooldown:render("Dash Cooldown", "");

    if menu.settings_tree:push("Settings") then
        menu.enemy_count_threshold:render("Minimum Enemy Count",
            "       Minimum number of enemies in Enemy Evaluation Radius to consider them for targeting")
        menu.targeting_refresh_interval:render("Targeting Refresh Interval",
            "       Time between target checks in seconds       ", 1)
        menu.max_targeting_range:render("Max Targeting Range",
            "       Maximum range for targeting       ")
        menu.cursor_targeting_radius:render("Cursor Targeting Radius",
            "       Area size for selecting target around the cursor       ", 1)
        menu.cursor_targeting_angle:render("Cursor Targeting Angle",
            "       Maximum angle between cursor and target to cast targetted spells       ")
        menu.best_target_evaluation_radius:render("Enemy Evaluation Radius",
            "       Area size around an enemy to evaluate if it's the best target       \n" ..
            "       If you use huge aoe spells, you should increase this value       \n" ..
            "       Size is displayed with debug/display targets with faded white circles       ", 1)

        menu.custom_enemy_weights:render("Custom Enemy Weights",
            "Enable custom enemy weights for determining best targets within Enemy Evaluation Radius")
        if menu.custom_enemy_weights:get() then
            if menu.custom_enemy_weights_tree:push("Custom Enemy Weights") then
                menu.enemy_weight_normal:render("Normal Enemy Weight",
                    "Weighing score for normal enemies - default is 2")
                menu.enemy_weight_elite:render("Elite Enemy Weight",
                    "Weighing score for elite enemies - default is 10")
                menu.enemy_weight_champion:render("Champion Enemy Weight",
                    "Weighing score for champion enemies - default is 15")
                menu.enemy_weight_boss:render("Boss Enemy Weight",
                    "Weighing score for boss enemies - default is 50")
                menu.enemy_weight_damage_resistance:render("Damage Resistance Aura Enemy Weight",
                    "Weighing score for enemies with damage resistance aura - default is 25")
                menu.custom_enemy_weights_tree:pop()
            end
        end

        menu.enable_debug:render("Enable Debug", "")
        if menu.enable_debug:get() then
            if menu.debug_tree:push("Debug") then
                menu.draw_targets:render("Display Targets", "Main targets display")
                menu.draw_max_range:render("Display Max Range", "Draw max range circle")
                menu.draw_melee_range:render("Display Melee Range", "Draw melee range circle")
                menu.draw_enemy_circles:render("Display Enemy Circles", "Draw enemy circles")
                menu.draw_cursor_target:render("Display Cursor Target", "Display cursor targeting")
                menu.debug_tree:pop()
            end
        end

        menu.settings_tree:pop()
    end

    local equipped_spells = get_equipped_spell_ids()
    
    -- Create a lookup table for equipped spells
    equipped_lookup = {} -- Clear the table before repopulating
    for _, spell_id in ipairs(equipped_spells) do
        -- Check each spell in spell_data to find matching spell_id
        for spell_name, data in pairs(spell_data) do
            if data.spell_id == spell_id then
                equipped_lookup[spell_name] = true
                break
            end
        end
    end

    if menu.spells_tree:push("Equipped Spells") then
        -- Display spells in priority order, but only if they're equipped
        for _, spell_name in ipairs(spell_priority) do
            local spell = spells[spell_name]
            if equipped_lookup[spell_name] and spell and spell.menu then
                spell.menu()
            end
        end
        menu.spells_tree:pop()
    end

    if menu.disabled_spells_tree:push("Inactive Spells") then
        for _, spell_name in ipairs(spell_priority) do
            local spell = spells[spell_name]
            if spell and spell.menu and not equipped_lookup[spell_name] then
                spell.menu()
            end
        end
        menu.disabled_spells_tree:pop()
    end

    menu.main_tree:pop();
end)

-- Targets
local best_ranged_target = nil
local best_ranged_target_visible = nil
local best_melee_target = nil
local best_melee_target_visible = nil
local closest_target = nil
local closest_target_visible = nil
local best_cursor_target = nil
local closest_cursor_target = nil
local closest_cursor_target_angle = 0
-- Targetting scores
local ranged_max_score = 0
local ranged_max_score_visible = 0
local melee_max_score = 0
local melee_max_score_visible = 0
local cursor_max_score = 0

-- Targetting settings
local max_targeting_range = menu.max_targeting_range:get()
local collision_table = { true, 1 } -- collision width
local floor_table = { true, 5.0 }   -- floor height
local angle_table = { false, 90.0 } -- max angle

-- Default enemy weights for different enemy types
local normal_monster_value = 2
local elite_value = 10
local champion_value = 15
local boss_value = 50
local damage_resistance_value = 25

local target_selector_data_all = nil
global_poison_trap_last_cast_time = 0.0
global_poison_trap_last_cast_position = nil
local last_dash_cast_time = 0.0
local last_heartseeker_cast_time = 0.0

local function evaluate_targets(target_list, melee_range)
    local best_ranged_target = nil
    local best_melee_target = nil
    local best_cursor_target = nil
    local closest_cursor_target = nil
    local closest_cursor_target_angle = 0

    local ranged_max_score = 0
    local melee_max_score = 0
    local cursor_max_score = 0

    local melee_range_sqr = melee_range * melee_range
    local player_position = get_player_position()
    local cursor_position = get_cursor_position()
    local cursor_targeting_radius = menu.cursor_targeting_radius:get()
    local cursor_targeting_radius_sqr = cursor_targeting_radius * cursor_targeting_radius
    local best_target_evaluation_radius = menu.best_target_evaluation_radius:get()
    local cursor_targeting_angle = menu.cursor_targeting_angle:get()
    local enemy_count_threshold = menu.enemy_count_threshold:get()
    local closest_cursor_distance_sqr = math.huge
    
    local debug_boss_info = menu.enable_debug:get()
    if debug_boss_info then
        console.print("Target evaluation started. Targets to evaluate: " .. #target_list)
        console.print("Boss value: " .. boss_value .. ", Champion value: " .. champion_value .. ", Elite value: " .. elite_value)
    end

    for _, unit in ipairs(target_list) do
        local unit_health = unit:get_current_health()
        local unit_name = unit:get_skin_name()
        local unit_position = unit:get_position()
        local distance_sqr = unit_position:squared_dist_to_ignore_z(player_position)
        local cursor_distance_sqr = unit_position:squared_dist_to_ignore_z(cursor_position)
        local buffs = unit:get_buffs()
        
        -- Debug boss detection for each target
        if debug_boss_info then
            local is_boss_unit = unit:is_boss()
            local is_elite_unit = unit:is_elite()
            local is_champion_unit = unit:is_champion()
            if is_boss_unit or is_elite_unit or is_champion_unit then
                console.print("Special unit found: " .. unit_name .. 
                             " - Boss: " .. tostring(is_boss_unit) .. 
                             ", Elite: " .. tostring(is_elite_unit) .. 
                             ", Champion: " .. tostring(is_champion_unit))
            end
        end

        -- get enemy count in range of enemy unit
        local all_units_count, normal_units_count, elite_units_count, champion_units_count, boss_units_count = my_utility
            .enemy_count_in_range(best_target_evaluation_radius, unit_position)

        -- if enemy count is less than enemy count threshold and unit is not elite, champion or boss, skip this unit
        if all_units_count < enemy_count_threshold and not (unit:is_elite() or unit:is_champion() or unit:is_boss()) then
            if debug_boss_info then
                console.print("Skipping normal unit due to enemy count threshold: " .. unit_name .. " (count: " .. all_units_count .. ")")
            end
            goto continue
        end

        local total_score = normal_units_count * normal_monster_value
        if boss_units_count > 0 then
            total_score = total_score + boss_value * boss_units_count
            if debug_boss_info then
                console.print("Boss points added: " .. (boss_value * boss_units_count) .. " for unit: " .. unit_name)
            end
        elseif champion_units_count > 0 then
            total_score = total_score + champion_value * champion_units_count
            if debug_boss_info then
                console.print("Champion points added: " .. (champion_value * champion_units_count) .. " for unit: " .. unit_name)
            end
        elseif elite_units_count > 0 then
            total_score = total_score + elite_value * elite_units_count
            if debug_boss_info then
                console.print("Elite points added: " .. (elite_value * elite_units_count) .. " for unit: " .. unit_name)
            end
        end

        -- Check if unit itself is a boss, champion, or elite and add direct score
        if unit:is_boss() then
            total_score = total_score + boss_value
            if debug_boss_info then
                console.print("Direct boss points added: " .. boss_value .. " for unit: " .. unit_name)
            end
        elseif unit:is_champion() then
            total_score = total_score + champion_value
            if debug_boss_info then
                console.print("Direct champion points added: " .. champion_value .. " for unit: " .. unit_name)
            end
        elseif unit:is_elite() then
            total_score = total_score + elite_value
            if debug_boss_info then
                console.print("Direct elite points added: " .. elite_value .. " for unit: " .. unit_name)
            end
        end

        -- Check if unit is vulnerable
        if unit:is_vulnerable() then
            total_score = total_score + 10000
            if debug_boss_info then
                console.print("Vulnerable bonus added: 10000 for unit: " .. unit_name)
            end
        end
        
        if debug_boss_info then
            console.print("Final score for " .. unit_name .. ": " .. total_score)
        end

        -- Check if unit is in melee range
        if distance_sqr < melee_range_sqr and total_score > melee_max_score then
            melee_max_score = total_score
            best_melee_target = unit
        end

        -- in max range
        if total_score > ranged_max_score then
            ranged_max_score = total_score
            best_ranged_target = unit
        end

        -- in cursor angle
        if cursor_distance_sqr <= cursor_targeting_radius_sqr then
            local angle_to_cursor = unit_position:get_angle(cursor_position, player_position)
            if angle_to_cursor <= cursor_targeting_angle then
                -- in cursor radius
                if cursor_distance_sqr <= cursor_targeting_radius_sqr then
                    if total_score > cursor_max_score then
                        cursor_max_score = total_score
                        best_cursor_target = unit
                    end

                    if cursor_distance_sqr < closest_cursor_distance_sqr then
                        closest_cursor_distance_sqr = cursor_distance_sqr
                        closest_cursor_target = unit
                        closest_cursor_target_angle = angle_to_cursor
                    end
                end
            end
        end

        ::continue::
    end

    return best_ranged_target, best_melee_target, best_cursor_target, closest_cursor_target, ranged_max_score,
        melee_max_score, cursor_max_score, closest_cursor_target_angle
end

local function use_ability(spell_name, delay_after_cast)
    local spell = spells[spell_name]
    if not spell then
        return false
    end

    -- Check if spell is equipped
    if not equipped_lookup[spell_name] then
        -- Remove frequent debug messages
        return false
    end

    -- Check if spell is enabled in the menu
    if spell.menu_elements and spell.menu_elements.main_boolean and not spell.menu_elements.main_boolean:get() then
        -- Remove frequent debug messages
        return false
    end

    -- Handle special cases
    if spell_name == "dash" then
        local current_time = get_time_since_inject()
        if current_time - last_dash_cast_time <= menu.dash_cooldown:get() then
            -- Remove frequent debug messages
            return false
        end
    elseif spell_name == "heartseeker" then
        local heartseeker_spell_cast_delay = spells.heartseeker.menu_elements_heartseeker_base.spell_cast_delay:get()
        local current_time = get_time_since_inject()
        if current_time - last_heartseeker_cast_time <= heartseeker_spell_cast_delay then
            -- Remove frequent debug messages
            return false
        end
    end

    -- Special case for ranged mode
    local mode_id = menu.mode:get()
    local is_ranged = mode_id >= 1
    if is_ranged and spell_name == "dash" and menu.dash_cooldown:get() > 0 then
        local current_time = get_time_since_inject()
        if current_time - global_poison_trap_last_cast_time > 1.20 and 
           current_time - global_poison_trap_last_cast_time < 2.20 and 
           global_poison_trap_last_cast_position and
           global_poison_trap_last_cast_position:squared_dist_to_ignore_z(get_player_position()) < (3.30 * 3.30) then
            -- Evade exception for ranged
            if cast_spell.position(337031, get_player_position():get_extended(global_poison_trap_last_cast_position, -4.0), 0.00) then
                global_poison_trap_last_cast_time = 0.0
                global_poison_trap_last_cast_position = nil
                console.print("Rouge Plugin, Casted evade ranged EXCEPTION")
                return true
            end
        end
    end

    local target_unit = nil
    if spell.menu_elements and spell.menu_elements.targeting_mode then
        local targeting_mode = spell.menu_elements.targeting_mode:get()
        target_unit = ({
            [0] = best_ranged_target,
            [1] = best_ranged_target_visible,
            [2] = best_melee_target,
            [3] = best_melee_target_visible,
            [4] = closest_target,
            [5] = closest_target_visible,
            [6] = best_cursor_target,
            [7] = closest_cursor_target
        })[targeting_mode]
    else
        -- Default to best ranged target if no targeting mode is specified
        target_unit = best_ranged_target
    end

    -- Add debug info about target - but only for boss targets or significant events
    -- to avoid flooding the debug log
    local debug_enabled = menu.enable_debug:get()
    if debug_enabled and target_unit and (target_unit:is_boss() or target_unit:is_champion() or target_unit:is_elite()) then
        local is_boss = target_unit:is_boss()
        local is_elite = target_unit:is_elite()
        local is_champion = target_unit:is_champion()
        
        -- Only log important targeting attempts
        if is_boss or is_champion then
            console.print("Debug: Attempting " .. spell_name .. " on " .. 
                      target_unit:get_skin_name() .. " (Boss: " .. tostring(is_boss) .. 
                      ", Elite: " .. tostring(is_elite) .. ", Champion: " .. tostring(is_champion) .. ")")
        end
    end

    -- Handle different spell types
    if target_unit and spell.logics and spell.logics(target_unit) then
        -- For targeted abilities
        if spell_name == "dash" then
            last_dash_cast_time = get_time_since_inject()
        elseif spell_name == "heartseeker" then
            last_heartseeker_cast_time = get_time_since_inject()
        end
        
        next_cast_time = get_time_since_inject() + delay_after_cast
        return true
    elseif spell_name == "shadow_step" or spell_name == "poison_trap" or spell_name == "death_trap" or spell_name == "penetrating_shot" then
        -- For area abilities that need target lists
        -- Only log issues with these spells if we have significant targets
        local has_important_target = false
        if target_selector_data_all and target_selector_data_all.list then
            for _, unit in ipairs(target_selector_data_all.list) do
                if unit:is_boss() or unit:is_champion() then
                    has_important_target = true
                    break
                end
            end
        end
        
        if debug_enabled and has_important_target then
            if not target_selector_data_all then
                console.print("Debug: No target selector data available for " .. spell_name)
            elseif not target_selector_data_all.is_valid then
                console.print("Debug: Target selector data is invalid for " .. spell_name)
            elseif not target_selector_data_all.list then
                console.print("Debug: No target list available for " .. spell_name)
            end
        end
        
        if spell.logics and target_selector_data_all and target_selector_data_all.is_valid and target_selector_data_all.list and 
           spell.logics(target_selector_data_all.list, target_selector_data_all, best_ranged_target, target_selector_data_all.closest_unit) then
            next_cast_time = get_time_since_inject() + delay_after_cast
            return true
        elseif debug_enabled and has_important_target then
            -- Only log failures for important targets
            console.print("Debug: Failed to cast " .. spell_name .. " on important target")
        end
    elseif not target_unit and spell.logics and spell.logics() then
        -- For non-targeted abilities
        next_cast_time = get_time_since_inject() + delay_after_cast
        return true
    -- Remove excessive failure logging
    end

    return false
end

-- Auto play movement
local can_move = 0.0

local glow_target = nil
on_update(function()
    local current_time = get_time_since_inject()
    local local_player = get_local_player()
    if not local_player or menu.main_boolean:get() == false or current_time < next_cast_time then
        return
    end

    if not my_utility.is_action_allowed() then
        return
    end
    
    targeting_refresh_interval = menu.targeting_refresh_interval:get()
    -- Only update targets if targeting_refresh_interval has expired
    if current_time >= next_target_update_time then
        local player_position = get_player_position()
        max_targeting_range = menu.max_targeting_range:get()

        local entity_list_visible, entity_list = my_target_selector.get_target_list(
            player_position,
            max_targeting_range,
            collision_table,
            floor_table,
            angle_table)

        target_selector_data_all = my_target_selector.get_target_selector_data(
            player_position,
            entity_list)

        local target_selector_data_visible = my_target_selector.get_target_selector_data(
            player_position,
            entity_list_visible)

        if not target_selector_data_all or not target_selector_data_all.is_valid then
            return
        end

        -- Reset targets
        best_ranged_target = nil
        best_melee_target = nil
        closest_target = nil
        best_ranged_target_visible = nil
        best_melee_target_visible = nil
        closest_target_visible = nil
        best_cursor_target = nil
        closest_cursor_target = nil
        closest_cursor_target_angle = 0
        local melee_range = 2.5 -- Default melee range for rogue

        -- Update enemy weights, use custom weights if enabled
        if menu.custom_enemy_weights:get() then
            normal_monster_value = menu.enemy_weight_normal:get()
            elite_value = menu.enemy_weight_elite:get()
            champion_value = menu.enemy_weight_champion:get()
            boss_value = menu.enemy_weight_boss:get()
            damage_resistance_value = menu.enemy_weight_damage_resistance:get()
        else
            normal_monster_value = 2
            elite_value = 10
            champion_value = 15
            boss_value = 50
            damage_resistance_value = 25
        end

        -- Check all targets within max range
        if target_selector_data_all and target_selector_data_all.is_valid then
            best_ranged_target, best_melee_target, best_cursor_target, closest_cursor_target, ranged_max_score,
            melee_max_score, cursor_max_score, closest_cursor_target_angle = evaluate_targets(
                target_selector_data_all.list,
                melee_range)
            closest_target = target_selector_data_all.closest_unit
        end

        -- Check visible targets within max range
        if target_selector_data_visible and target_selector_data_visible.is_valid then
            best_ranged_target_visible, best_melee_target_visible, _, _,
            ranged_max_score_visible, melee_max_score_visible, _ = evaluate_targets(
                target_selector_data_visible.list,
                melee_range)
            closest_target_visible = target_selector_data_visible.closest_unit
        end

        -- Update next target update time
        next_target_update_time = current_time + targeting_refresh_interval
    end

    -- Set the glow target for rendering
    glow_target = best_ranged_target

    -- Ability usage - uses spell_priority to determine the order of spells
    for _, spell_name in ipairs(spell_priority) do
        local spell = spells[spell_name]
        if spell then
            if use_ability(spell_name, my_utility.spell_delays.regular_cast) then
                return
            end
        end
    end

    -- Auto play engage far away monsters
    local move_timer = get_time_since_inject()
    if move_timer < can_move then
        return
    end

    local is_auto_play = my_utility.is_auto_play_enabled()
    if is_auto_play then
        local player_position = local_player:get_position()
        local is_dangerous_evade_position = evade.is_dangerous_position(player_position)
        if not is_dangerous_evade_position then
            local closer_target = target_selector.get_target_closer(player_position, 15.0)
            if closer_target then
                local closer_target_position = closer_target:get_position()
                local move_pos = closer_target_position:get_extended(player_position, 4.0)
                if pathfinder.move_to_cpathfinder(move_pos) then
                    can_move = move_timer + 1.50
                end
            end
        end
    end
end)

-- Rendering debug information
on_render(function()
    if menu.main_boolean:get() == false or not menu.enable_debug:get() then
        return
    end

    local local_player = get_local_player()
    if not local_player then
        return
    end

    local player_position = local_player:get_position()
    local player_screen_position = graphics.w2s(player_position)
    if player_screen_position:is_zero() then
        return
    end

    -- Draw max range
    max_targeting_range = menu.max_targeting_range:get()
    if menu.draw_max_range:get() then
        graphics.circle_3d(player_position, max_targeting_range, color_white(85), 2.5, 144)
    end

    -- Draw melee range
    if menu.draw_melee_range:get() then
        local melee_range = 2.5 -- Default melee range for rogue
        graphics.circle_3d(player_position, melee_range, color_white(85), 2.5, 144)
    end

    -- Draw enemy circles
    if menu.draw_enemy_circles:get() then
        local enemies = actors_manager.get_enemy_npcs()

        for i, obj in ipairs(enemies) do
            local position = obj:get_position()
            graphics.circle_3d(position, 1, color_white(100))

            local future_position = prediction.get_future_unit_position(obj, 0.4)
            graphics.circle_3d(future_position, 0.5, color_yellow(100))
        end
    end

    -- Only draw targets if we have valid target selector data
    if not target_selector_data_all or not target_selector_data_all.is_valid then
        return
    end

    local best_target_evaluation_radius = menu.best_target_evaluation_radius:get()
    local font_size = 16
    local y_offset = font_size + 2
    local visible_text = 255
    local visible_alpha = 180
    local alpha = 100
    local target_evaluation_radius_alpha = 50

    -- Draw targets
    if menu.draw_targets:get() then
        -- Draw visible ranged target
        if best_ranged_target_visible and best_ranged_target_visible:is_enemy() then
            local best_ranged_target_visible_position = best_ranged_target_visible:get_position()
            local best_ranged_target_visible_position_2d = graphics.w2s(best_ranged_target_visible_position)
            graphics.line(best_ranged_target_visible_position_2d, player_screen_position, color_red(visible_alpha),
                2.5)
            graphics.circle_3d(best_ranged_target_visible_position, 0.80, color_red(visible_alpha), 2.0)
            graphics.circle_3d(best_ranged_target_visible_position, best_target_evaluation_radius,
                color_white(target_evaluation_radius_alpha), 1)
            local text_position = vec2:new(best_ranged_target_visible_position_2d.x,
                best_ranged_target_visible_position_2d.y - y_offset)
            graphics.text_2d("RANGED_VISIBLE - Score:" .. ranged_max_score_visible, text_position, font_size,
                color_red(visible_text))
        end

        -- Draw ranged target if it's not the same as the visible ranged target
        if best_ranged_target_visible ~= best_ranged_target and best_ranged_target and best_ranged_target:is_enemy() then
            local best_ranged_target_position = best_ranged_target:get_position()
            local best_ranged_target_position_2d = graphics.w2s(best_ranged_target_position)
            graphics.circle_3d(best_ranged_target_position, 0.80, color_red_pale(alpha), 2.0)
            graphics.circle_3d(best_ranged_target_position, best_target_evaluation_radius,
                color_white(target_evaluation_radius_alpha), 1)
            local text_position = vec2:new(best_ranged_target_position_2d.x,
                best_ranged_target_position_2d.y - y_offset)
            graphics.text_2d("RANGED - Score:" .. ranged_max_score, text_position, font_size, color_red_pale(alpha))
        end

        -- Draw closest target with glow for visual feedback
        if glow_target and glow_target:is_enemy() then
            local glow_target_position = glow_target:get_position()
            local glow_target_position_2d = graphics.w2s(glow_target_position)
            if not glow_target_position_2d:is_zero() then
                graphics.line(glow_target_position_2d, player_screen_position, color_red(180), 2.5)
                graphics.circle_3d(glow_target_position, 0.80, color_red(200), 2.0)
            end
        end
    end

    if menu.draw_cursor_target:get() then
        local cursor_position = get_cursor_position()
        local cursor_targeting_radius = menu.cursor_targeting_radius:get()

        -- Draw cursor radius
        graphics.circle_3d(cursor_position, cursor_targeting_radius, color_white(target_evaluation_radius_alpha), 1)

        -- Draw best cursor target
        if best_cursor_target and best_cursor_target:is_enemy() then
            local best_cursor_target_position = best_cursor_target:get_position()
            local best_cursor_target_position_2d = graphics.w2s(best_cursor_target_position)
            graphics.circle_3d(best_cursor_target_position, 0.60, color_orange_red(255), 2.0, 5)
            graphics.text_2d("BEST_CURSOR_TARGET - Score:" .. cursor_max_score, best_cursor_target_position_2d, font_size,
                color_orange_red(255))
        end

        -- Draw closest cursor target
        if closest_cursor_target and closest_cursor_target:is_enemy() then
            local closest_cursor_target_position = closest_cursor_target:get_position()
            local closest_cursor_target_position_2d = graphics.w2s(closest_cursor_target_position)
            graphics.circle_3d(closest_cursor_target_position, 0.40, color_green_pastel(255), 2.0, 5)
            local text_position = vec2:new(closest_cursor_target_position_2d.x,
                closest_cursor_target_position_2d.y + y_offset)
            graphics.text_2d("CLOSEST_CURSOR_TARGET - Angle:" .. string.format("%.1f", closest_cursor_target_angle),
                text_position, font_size,
                color_green_pastel(255))
        end
    end

    -- Debug boss detection
    if menu.enable_debug:get() then
        local debug_pos_y = 100
        local enemies = actors_manager.get_enemy_npcs()
        graphics.text_2d("Boss Detection Debug:", vec2:new(10, debug_pos_y), 16, color_white(255))
        debug_pos_y = debug_pos_y + 20
        
        -- Check for bosses in all enemies
        for i, obj in ipairs(enemies) do
            if obj and obj:is_enemy() then
                local is_boss = obj:is_boss()
                local is_elite = obj:is_elite()
                local is_champion = obj:is_champion()
                local enemy_name = obj:get_skin_name() or "Unknown"
                local enemy_health = obj:get_current_health() or 0
                local enemy_max_health = obj:get_max_health() or 0
                local health_pct = enemy_max_health > 0 and (enemy_health / enemy_max_health * 100) or 0
                
                local status = "Normal"
                local color = color_white(255)
                
                if is_boss then 
                    status = "BOSS"
                    color = color_red(255)
                elseif is_champion then
                    status = "Champion" 
                    color = color_blue(255)
                elseif is_elite then
                    status = "Elite"
                    color = color_green(255)
                end
                
                graphics.text_2d(string.format("%s: %s (HP: %.1f%%)", status, enemy_name, health_pct), 
                                 vec2:new(10, debug_pos_y), 14, color)
                debug_pos_y = debug_pos_y + 16
                
                -- Limit to 15 entries to avoid screen clutter
                if i >= 15 then
                    graphics.text_2d("... and more enemies", vec2:new(10, debug_pos_y), 14, color_white(200))
                    break
                end
            end
        end
    end
end)

console.print("Lua Plugin - Rouge Base - Version 1.5");