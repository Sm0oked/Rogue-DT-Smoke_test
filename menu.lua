local my_utility = require("my_utility/my_utility")
local menu_elements =
{
    main_boolean                   = checkbox:new(true, get_hash(my_utility.plugin_label .. "main_boolean")),
    mode                           = combo_box:new(0, get_hash(my_utility.plugin_label .. "mode_melee_range")),
    dash_cooldown                  = slider_int:new(0, 6, 6, get_hash(my_utility.plugin_label .. "dash_cooldown")),
    main_tree                      = tree_node:new(0),
    
    -- Settings section
    settings_tree                  = tree_node:new(1),
    enemy_count_threshold          = slider_int:new(1, 10, 1, get_hash(my_utility.plugin_label .. "enemy_count_threshold")),
    targeting_refresh_interval     = slider_float:new(0.1, 1, 0.2, get_hash(my_utility.plugin_label .. "targeting_refresh_interval")),
    max_targeting_range            = slider_int:new(1, 26, 20, get_hash(my_utility.plugin_label .. "max_targeting_range")),
    cursor_targeting_radius        = slider_float:new(0.1, 6, 3, get_hash(my_utility.plugin_label .. "cursor_targeting_radius")),
    cursor_targeting_angle         = slider_int:new(20, 50, 30, get_hash(my_utility.plugin_label .. "cursor_targeting_angle")),
    best_target_evaluation_radius  = slider_float:new(0.1, 6, 3, get_hash(my_utility.plugin_label .. "best_target_evaluation_radius")),

    -- Enemy weights
    custom_enemy_weights           = checkbox:new(false, get_hash(my_utility.plugin_label .. "custom_enemy_weights")),
    custom_enemy_weights_tree      = tree_node:new(2),
    enemy_weight_normal            = slider_int:new(1, 10, 2, get_hash(my_utility.plugin_label .. "enemy_weight_normal")),
    enemy_weight_elite             = slider_int:new(1, 50, 10, get_hash(my_utility.plugin_label .. "enemy_weight_elite")),
    enemy_weight_champion          = slider_int:new(1, 50, 15, get_hash(my_utility.plugin_label .. "enemy_weight_champion")),
    enemy_weight_boss              = slider_int:new(1, 100, 50, get_hash(my_utility.plugin_label .. "enemy_weight_boss")),
    enemy_weight_damage_resistance = slider_int:new(1, 50, 25, get_hash(my_utility.plugin_label .. "enemy_weight_damage_resistance")),

    -- Debug section
    enable_debug                   = checkbox:new(false, get_hash(my_utility.plugin_label .. "enable_debug")),
    debug_tree                     = tree_node:new(2),
    draw_targets                   = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_targets")),
    draw_max_range                 = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_max_range")),
    draw_melee_range               = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_melee_range")),
    draw_enemy_circles             = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_enemy_circles")),
    draw_cursor_target             = checkbox:new(false, get_hash(my_utility.plugin_label .. "draw_cursor_target")),
    
    -- Spells section
    spells_tree                    = tree_node:new(1),
    disabled_spells_tree           = tree_node:new(1),
}

local draw_targets_description =
    "\n     Targets in sight:\n" ..
    "     Ranged Target - RED circle with line     \n" ..
    "     Melee Target - GREEN circle with line     \n" ..
    "     Closest Target - CYAN circle with line     \n\n" ..
    "     Targets out of sight (only if they are not the same as targets in sight):\n" ..
    "     Ranged Target - faded RED circle     \n" ..
    "     Melee Target - faded GREEN circle     \n" ..
    "     Closest Target - faded CYAN circle     \n\n" ..
    "     Best Target Evaluation Radius:\n" ..
    "     faded WHITE circle       \n\n"

local cursor_target_description =
    "\n     Best Cursor Target - ORANGE pentagon     \n" ..
    "     Closest Cursor Target - GREEN pentagon     \n\n"

return menu_elements