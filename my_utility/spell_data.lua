local spell_data = {
    -- defensive abilities
    dark_shroud = {
        spell_id = 786381,
        buff_id = 786383
    },
    concealment = {
        spell_id = 794965
    },
    shadow_clone = {
        spell_id = 1690398
    },
    
    -- traps and control
    death_trap = {
        spell_id = 421161
    },
    poison_trap = {
        spell_id = 416528
    },
    rain_of_arrows = {
        spell_id = 439762
    },
    dance_of_knives = {
        spell_id = 1690398
    },
    
    -- imbuements
    shadow_imbuement = {
        spell_id = 359246,
        buff_id = 359246
    },
    poison_imbuement = {
        spell_id = 358508,
        buff_id = 358508
    },
    cold_imbuement = {
        spell_id = 359246,
        buff_id = 359246
    },

    -- mobility and positioning
    shadow_step = {
        spell_id = 355606
    },
    dash = {
        spell_id = 358761
    },
    caltrop = {
        spell_id = 389667
    },
    smoke_grenade = {
        spell_id = 416528
    },

    -- main damage abilities
    twisting_blade = {
        spell_id = 399111
    },
    barrage = {
        spell_id = 439762
    },
    rapid_fire = {
        spell_id = 358339
    },
    flurry = {
        spell_id = 358339
    },
    penetrating_shot = {
        spell_id = 377137
    },
    invigorating_strike = {
        spell_id = 416057
    },
    blade_shift = {
        spell_id = 399111
    },
    forcefull_arrow = {
        spell_id = 416272
    },
    heartseeker = {
        spell_id = 363402
    },

    -- filler abilities
    puncture = {
        spell_id = 364877
    },

    -- utility
    evade = {
        spell_id = 337031
    },
    
    -- enemy buffs/debuffs
    enemies = {
        damage_resistance = {
            spell_id = 413943,
            buff_ids = {
                provider = 0,
                receiver = 1
            }
        }
    }
}

return spell_data 