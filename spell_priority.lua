-- To modify spell priority, edit the spell_priority table below.
-- The table is sorted from highest priority to lowest priority.
-- The priority is used to determine which spell to cast when multiple spells are valid to cast.

local spell_priority = {
    -- Top priority per build
    "shadow_step",      -- Cast every 8 seconds for Close Quarter Combat & mobility
    "penetrating_shot", -- Cast every 8 seconds for Close Quarter Combat
    "poison_trap",      -- Cast every 9 seconds
    "caltrop",          -- Cast after Poison Trap (1-2 seconds delay)
    
    -- Spam these
    "concealment",
    "death_trap",
    
    -- defensive abilities
    "dark_shroud",
    "shadow_clone",
    
    -- imbuements
    "shadow_imbuement",
    "poison_imbuement",
    "cold_imbuement",
    
    -- traps and control
    "rain_of_arrows",
    "dance_of_knives",
    
    -- mobility and positioning 
    "dash",            -- Use in Speedfarm variant instead of Penetrating Shot
    "smoke_grenade",

    -- main damage abilities
    "twisting_blade",
    "barrage",
    "rapid_fire",
    "flurry",
    "invigorating_strike",
    "blade_shift",
    "forcefull_arrow",
    "heartseeker",

    -- filler abilities
    "puncture",
}

-- Create a lookup table for quick priority checking
local priority_lookup = {}
for index, spell_name in ipairs(spell_priority) do
    priority_lookup[spell_name] = index
end

return spell_priority 