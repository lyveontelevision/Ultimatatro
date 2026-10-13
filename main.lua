local DATA_DIR = (SMODS.current_mod.path .. 'data/'):gsub('\\', '/')

local function log_line(message)
    if not DATA_DIR then return end
    local file = io.open(DATA_DIR .. '/ultatro.log', 'a')
    if file then
        file:write(message .. '\n')
        file:close()
    end
end

local function load_hero_data()
    if not DATA_DIR then
        log_line('error: ULTATRO_DATA_DIR is missing')
        return nil
    end
    local file = io.open(DATA_DIR .. '/heroes.data', 'rb')
    if not file then
        log_line('error: run the Overwatch 2 setup first')
        return nil
    end
    local raw = file:read('*a')
    file:close()
    local decode = SMODS.load_file('json.lua')()
    local ok, result = pcall(decode.decode, raw)
    if not ok or type(result) ~= 'table' then
        log_line('error: could not read local Overwatch 2 hero data')
        return nil
    end
    return result
end

local heroes = load_hero_data()
if not heroes or #heroes == 0 then
    log_line('error: no local heroes available')
    return
end

local hero_joker_keys = {}
local hero_role_by_joker_key = {}
local hero_joker_list = {}
local hero_jokers_by_role = { Damage = {}, Tank = {}, Support = {} }
for _, hero in ipairs(heroes) do
    local joker_key = 'j_ultatro_' .. hero.key
    hero_joker_keys[joker_key] = true
    hero_role_by_joker_key[joker_key] = hero.role
    hero_joker_list[#hero_joker_list + 1] = joker_key
    if hero_jokers_by_role[hero.role] then
        hero_jokers_by_role[hero.role][#hero_jokers_by_role[hero.role] + 1] = joker_key
    end
end

local function count_hero_jokers(role)
    local count = 0
    for _, joker in ipairs((G.jokers and G.jokers.cards) or {}) do
        local center = joker.config and joker.config.center
        if center and hero_joker_keys[center.key] and (not role or hero_role_by_joker_key[center.key] == role) then
            count = count + 1
        end
    end
    return count
end

local function has_hand(context, name)
    local hands = context.poker_hands or {}
    return hands[name] and next(hands[name]) ~= nil
end

local function count_scoring_cards(context, predicate)
    local count = 0
    for _, playing_card in ipairs(context.scoring_hand or {}) do
        if predicate(playing_card) then count = count + 1 end
    end
    return count
end

local function ability_bonus(hero, context, source_card)
    local effect_id = hero.effect_id
    if not context.joker_main and not (effect_id == 'reinhardt_earthshatter' and context.press_play) then return end
    local hand_name = context.scoring_name
    local scoring_count = #(context.scoring_hand or {})
    local full_count = #(context.full_hand or context.scoring_hand or {})
    local last_hand = G.GAME.current_round and G.GAME.current_round.hands_left == 0
    local role_count = count_hero_jokers(hero.role)
    local total_count = count_hero_jokers()
    local scale = 1
    if hero.hero_scaling then scale = scale * (1 + math.max(0, total_count - 1) * 0.25) end
    if hero.role_scaling then scale = scale * (1 + math.max(0, role_count - 1) * 0.25) end
    local amount = (tonumber(hero.amount) or 0) * scale
    local function scaled_number(value)
        return math.floor((tonumber(value) or 0) * scale + 0.5)
    end
    local function result(stat, value, label)
        value = math.floor(value + 0.5)
        local prefix = stat == 'dollars' and '+$' or '+'
        local suffix = stat == 'chips' and ' Chips' or (stat == 'mult' and ' Mult' or '')
        return { [stat] = value, message = label or (prefix .. value .. suffix) }
    end
    local function xmult_result(tenths, times)
        local value = (tonumber(tenths) or 0) / 10
        if times and times > 1 then value = value ^ times end
        return { x_mult = value, message = 'X' .. string.format('%.2f', value) .. ' Mult' }
    end
    local hands = {
        straight = 'Straight', flush = 'Flush', pair = 'Pair', two_pair = 'Two Pair',
        full_house = 'Full House', high_card = 'High Card', three_kind = 'Three of a Kind',
        four_kind = 'Four of a Kind', five_kind = 'Five of a Kind',
    }
    local function kind_or_better()
        return has_hand(context, 'Three of a Kind') or has_hand(context, 'Full House') or
            has_hand(context, 'Four of a Kind') or has_hand(context, 'Five of a Kind')
    end
    local function match_hand(name)
        if name == 'kind' then return kind_or_better() end
        return has_hand(context, hands[name])
    end

    if effect_id == 'dva_self_destruct' then
        if last_hand then
            return {
                chips = scaled_number(hero.self_chips),
                mult = scaled_number(hero.secondary),
                x_mult = (tonumber(hero.tertiary) or 20) / 10 * scale,
                message = 'Self-Destruct!',
            }
        elseif has_hand(context, 'Flush') then
            return result('chips', amount)
        end
    elseif effect_id == 'reinhardt_earthshatter' then
        if context.press_play and last_hand and G.GAME.blind and G.GAME.blind:get_type() == 'Boss' and not G.GAME.blind.disabled then
            G.GAME.blind:disable()
            return { message = 'Earthshatter!', colour = G.C.RED }
        elseif context.joker_main and not (last_hand and G.GAME.blind and G.GAME.blind:get_type() == 'Boss') and has_hand(context, 'Straight') then
            return result('mult', amount)
        end
    elseif effect_id == 'last_hand_bonus' and context.joker_main and last_hand then
        return { chips = math.floor(amount + 0.5), mult = scaled_number(hero.secondary), message = 'Ultimate!' }
    elseif effect_id == 'last_hand_xmult' and context.joker_main and last_hand then
        return xmult_result(amount)
    elseif effect_id == 'last_hand_chips' and context.joker_main and last_hand then
        return result('chips', amount)
    elseif effect_id == 'last_hand_mult' and context.joker_main and last_hand then
        return result('mult', amount)
    elseif effect_id == 'last_hand_level' and context.joker_main and last_hand and hand_name then
        level_up_hand(context.blueprint_card or source_card, hand_name, nil, math.max(1, scaled_number(amount)))
        return { message = 'Level Up!', colour = G.C.BLUE }
    elseif effect_id == 'first_hand_xmult' and context.joker_main and G.GAME.current_round and G.GAME.current_round.hands_played == 0 then
        return xmult_result(amount)
    elseif effect_id == 'high_card_level' and context.joker_main and match_hand('high_card') and hand_name then
        level_up_hand(context.blueprint_card or source_card, hand_name, nil, math.max(1, scaled_number(amount)))
        return { message = 'Level Up!', colour = G.C.BLUE }
    elseif effect_id == 'straight_level' and context.joker_main and match_hand('straight') and hand_name then
        level_up_hand(context.blueprint_card or source_card, hand_name, nil, math.max(1, scaled_number(amount)))
        return { message = 'Level Up!', colour = G.C.BLUE }
    elseif effect_id == 'flush_level' and context.joker_main and match_hand('flush') and hand_name then
        level_up_hand(context.blueprint_card or source_card, hand_name, nil, math.max(1, scaled_number(amount)))
        return { message = 'Level Up!', colour = G.C.BLUE }
    elseif effect_id == 'face_chips' or effect_id == 'face_mult' or effect_id == 'face_dollars' then
        local count = count_scoring_cards(context, function(card) local id = card:get_id(); return id >= 11 and id <= 13 end)
        if count > 0 then
            local stat = effect_id == 'face_chips' and 'chips' or (effect_id == 'face_mult' and 'mult' or 'dollars')
            return result(stat, count * amount)
        end
    elseif effect_id == 'face_xmult' then
        local count = count_scoring_cards(context, function(card) local id = card:get_id(); return id >= 11 and id <= 13 end)
        if count > 0 then return xmult_result(amount, count) end
    elseif effect_id == 'ace_mult' or effect_id == 'ace_chips' or effect_id == 'ace_xmult' then
        local count = count_scoring_cards(context, function(card) return card:get_id() == 14 end)
        if count > 0 then
            if effect_id == 'ace_xmult' then return xmult_result(amount) end
            return result(effect_id == 'ace_mult' and 'mult' or 'chips', count * amount)
        end
    elseif effect_id == 'heart_mult' or effect_id == 'heart_dollars' or effect_id == 'heart_xmult' then
        local count = count_scoring_cards(context, function(card) return card:is_suit('Hearts') end)
        if count > 0 then
            if effect_id == 'heart_xmult' then return xmult_result(amount, count) end
            return result(effect_id == 'heart_mult' and 'mult' or 'dollars', count * amount)
        end
    elseif effect_id == 'scoring_card_mult' or effect_id == 'scoring_card_dollars' then
        if scoring_count > 0 then return result(effect_id == 'scoring_card_mult' and 'mult' or 'dollars', scoring_count * amount) end
    elseif effect_id == 'four_card_chips' or effect_id == 'three_card_chips' then
        local minimum = effect_id == 'four_card_chips' and 4 or 3
        if scoring_count >= minimum then return result('chips', amount) end
    elseif effect_id == 'kind_xmult' or effect_id == 'three_kind_chips' then
        if kind_or_better() then
            if effect_id == 'kind_xmult' then return xmult_result(amount) end
            return result('chips', amount)
        end
    elseif effect_id == 'five_card_chips' or effect_id == 'five_card_mult' or effect_id == 'five_card_xmult' then
        if full_count >= 5 then
            if effect_id == 'five_card_xmult' then return xmult_result(amount) end
            return result(effect_id == 'five_card_chips' and 'chips' or 'mult', amount)
        end
    elseif effect_id == 'four_card_xmult' and scoring_count >= 4 then
        return xmult_result(amount)
    elseif effect_id == 'high_card_xmult' and match_hand('high_card') then
        return xmult_result(amount)
    elseif effect_id == 'pair_xmult' and match_hand('pair') then
        return xmult_result(amount)
    elseif effect_id == 'two_pair_xmult' and match_hand('two_pair') then
        return xmult_result(amount)
    elseif effect_id == 'full_house_xmult' and match_hand('full_house') then
        return xmult_result(amount)
    elseif effect_id == 'straight_xmult' and match_hand('straight') then
        return xmult_result(amount)
    elseif effect_id == 'flush_xmult' and match_hand('flush') then
        return xmult_result(amount)
    elseif effect_id == 'high_card_chips' and match_hand('high_card') then
        return result('chips', amount)
    elseif effect_id == 'straight_chips' and match_hand('straight') then
        return result('chips', amount)
    elseif effect_id == 'flush_chips' and match_hand('flush') then
        return result('chips', amount)
    elseif effect_id == 'straight_mult' and match_hand('straight') then
        return result('mult', amount)
    elseif effect_id == 'pair_mult' and match_hand('pair') then
        return result('mult', amount)
    elseif effect_id == 'low_hand_dollars' and (match_hand('high_card') or match_hand('pair')) then
        return result('dollars', amount)
    end
end

local data_root = DATA_DIR:gsub('/+$', '') .. '/'
for _, hero in ipairs(heroes) do
    local hero_key = hero.key
    local hero_data = hero
    local atlas_key = 'ultatro_' .. hero_key
    SMODS.Atlas {
        key = atlas_key,
        path = hero_key .. '.png',
        px = 64,
        py = 64,
        path_mod = { path = data_root },
    }

    SMODS.Joker {
        key = hero_key,
        name = hero_data.name,
        rarity = tonumber(hero_data.rarity) or 1,
        atlas = atlas_key,
        pos = { x = 0, y = 0 },
        cost = tonumber(hero_data.cost) or 5,
        unlocked = true,
        discovered = true,
        blueprint_compat = true,
        config = {},
        loc_txt = {
            name = hero_data.name,
            text = {
                '{C:attention}' .. hero_data.ability .. '{}',
                hero_data.reward,
                '{C:inactive}' .. hero_data.abilityDescription .. '{}',
                'Clear a {C:attention}Boss Blind{} encounter: {C:money}+$3{}',
            },
        },
        calculate = function(self, card, context)
            if hero_key == 'echo' and not context.no_blueprint then
                local copied = nil
                for index, joker in ipairs((G.jokers and G.jokers.cards) or {}) do
                    if joker == card then copied = G.jokers.cards[index + 1]; break end
                end
                if copied and copied ~= card and not copied.debuff and copied.config and copied.config.center then
                    local center = copied.config.center
                    local was_compatible = center.blueprint_compat
                    center.blueprint_compat = true
                    local ok, result = pcall(SMODS.blueprint_effect, card, copied, context)
                    center.blueprint_compat = was_compatible
                    if ok and result then
                        result.colour = G.C.BLUE
                        return result
                    end
                end
            end

            if context.joker_main or context.press_play then
                local bonus = ability_bonus(hero_data, context, card)
                if bonus then
                    log_line('ability:' .. hero_key .. ':' .. hero_data.ability)
                    return bonus
                end
            end

            if context.end_of_round and context.main_eval and not context.game_over and
                G.GAME.blind and G.GAME.blind.boss then
                log_line('encounter:complete:' .. hero_key)
                return { dollars = 3, message = 'Mission Reward!' }
            end
        end,
    }

    local deck_name = hero_data.name .. ' Mission Deck'
    SMODS.Back {
        key = hero_key,
        name = deck_name,
        atlas = atlas_key,
        pos = { x = 0, y = 0 },
        unlocked = true,
        discovered = true,
        config = { jokers = { 'j_ultatro_' .. hero_key } },
        loc_txt = {
            name = deck_name,
            text = {
                'Start with {C:attention}' .. hero_data.name .. '{} as your hero Joker.',
                '{C:inactive}' .. hero_data.ability .. '{}',
                'Boss Blind wins pay {C:money}+$3{} as mission rewards.',
            },
        },
    }
end

local function starting_squad_apply(role, amount, negative, balanced)
    return function(self, back)
        G.E_MANAGER:add_event(Event({
            trigger = 'immediate',
            func = function()
                for index = 1, amount do
                    local source
                    if balanced then
                        local roles = { 'Damage', 'Tank', 'Support' }
                        source = hero_jokers_by_role[roles[index]]
                    else
                        source = role and hero_jokers_by_role[role] or hero_joker_list
                    end
                    local pool = {}
                    for _, key in ipairs(source or {}) do pool[#pool + 1] = key end
                    if #pool == 0 then break end
                    local selected = pseudorandom_element(pool, pseudoseed(self.key .. '_hero_' .. index))
                    local joker = create_card('Joker', G.jokers, nil, nil, nil, nil, selected, 'ultatro_squad')
                    joker:add_to_deck()
                    G.jokers:emplace(joker)
                    joker:set_eternal(true)
                    if negative then joker:set_edition({ negative = true }, true) end
                    joker:start_materialize()
                end
                return true
            end,
        }))
    end
end

local function register_squad_back(key, name, role, amount, description, negative, balanced)
    SMODS.Back {
        key = key,
        name = name,
        atlas = 'ultatro_tracer',
        pos = { x = 0, y = 0 },
        unlocked = true,
        discovered = true,
        config = {},
        apply = starting_squad_apply(role, amount, negative, balanced),
        loc_txt = {
            name = name,
            text = { description },
        },
    }
end

register_squad_back('all_stars', 'All-Stars Squad Deck', nil, 5,
    'Start with 5 random {C:attention}Eternal{} and {C:dark_edition}Negative{} Hero Jokers.', true)
register_squad_back('damage_division', 'Damage Division Deck', 'Damage', 3,
    'Start with 3 random {C:attention}Eternal{} Damage Hero Jokers.')
register_squad_back('tank_line', 'Tank Line Deck', 'Tank', 3,
    'Start with 3 random {C:attention}Eternal{} Tank Hero Jokers.')
register_squad_back('support_network', 'Support Network Deck', 'Support', 3,
    'Start with 3 random {C:attention}Eternal{} Support Hero Jokers.')
register_squad_back('role_queue', 'Role Queue Deck', nil, 3,
    'Start with one random {C:attention}Eternal{} Hero from each role.', false, true)

local function create_hero_pack_card(self, card, index)
    local selected = pseudorandom_element(hero_joker_list, pseudoseed(self.key .. '_hero_' .. tostring(index)))
    return {
        set = 'Joker',
        key = selected,
        area = G.pack_cards,
        skip_materialize = true,
        key_append = 'ultatro_hero_pack',
    }
end

local function register_hero_pack(key, name, cost, extra, choose, weight)
    SMODS.Booster {
        key = key,
        name = name,
        kind = 'Hero',
        atlas = 'Booster',
        pos = { x = 0, y = 0 },
        cost = cost,
        weight = weight,
        config = { extra = extra, choose = choose },
        create_card = create_hero_pack_card,
        loc_txt = {
            name = name,
            text = { 'Choose {C:attention}#1#{} of up to {C:attention}#2#{} Hero Jokers.' },
            group_name = 'Hero Pack',
        },
    }
end

register_hero_pack('hero_normal_1', 'Hero Pack', 4, 3, 1, 0.7)
register_hero_pack('hero_mega_1', 'Mega Hero Pack', 8, 4, 2, 0.35)
register_hero_pack('hero_jumbo_1', 'Jumbo Hero Pack', 6, 5, 1, 0.45)

SMODS.Blind {
    key = 'hero_lock',
    name = 'Hero Check',
    boss = { min = 1 },
    boss_colour = HEX('E84A5F'),
    atlas = 'ultatro_tracer',
    pos = { x = 0, y = 0 },
    dollars = 5,
    mult = 2,
    discovered = true,
    loc_txt = {
        name = 'Hero Check',
        text = {
            'You can only play hands',
            'while you have a {C:attention}Hero Joker{}',
        },
    },
    debuff_hand = function(self, cards, hand, handname, check)
        for _, joker in ipairs((G.jokers and G.jokers.cards) or {}) do
            local center = joker.config and joker.config.center
            if center and hero_joker_keys[center.key] then return false end
        end
        return true
    end,
    get_loc_debuff_text = function(self)
        return 'Requires a Hero Joker'
    end,
}

SMODS.Blind {
    key = 'deadeye',
    name = 'Deadeye',
    boss = { min = 1 },
    boss_colour = HEX('B56A45'),
    atlas = 'ultatro_tracer',
    pos = { x = 0, y = 0 },
    dollars = 5,
    mult = 2,
    discovered = true,
    loc_txt = {
        name = 'Deadeye',
        text = { 'Hands without a scoring {C:attention}face card{} are debuffed.' },
    },
    debuff_hand = function(self, cards, hand, handname, check)
        for _, card in ipairs(cards or {}) do
            if card.is_face and card:is_face() then return false end
        end
        return true
    end,
    get_loc_debuff_text = function(self)
        return 'Needs a face card'
    end,
}

SMODS.Blind {
    key = 'emp',
    name = 'EMP Pulse',
    boss = { min = 1 },
    boss_colour = HEX('7657C8'),
    atlas = 'ultatro_tracer',
    pos = { x = 0, y = 0 },
    dollars = 5,
    mult = 2,
    discovered = true,
    loc_txt = {
        name = 'EMP Pulse',
        text = { 'Your first hand each round is debuffed.' },
    },
    debuff_hand = function(self, cards, hand, handname, check)
        return G.GAME.current_round and G.GAME.current_round.hands_played == 0 or false
    end,
    get_loc_debuff_text = function(self)
        return 'EMP: first hand disabled'
    end,
}

SMODS.Blind {
    key = 'graviton',
    name = 'Graviton Surge',
    boss = { min = 1 },
    boss_colour = HEX('6B4D91'),
    atlas = 'ultatro_tracer',
    pos = { x = 0, y = 0 },
    dollars = 5,
    mult = 2,
    discovered = true,
    loc_txt = {
        name = 'Graviton Surge',
        text = { 'Hands with fewer than {C:attention}4{} cards are debuffed.' },
    },
    debuff_hand = function(self, cards, hand, handname, check)
        return #(cards or {}) < 4
    end,
    get_loc_debuff_text = function(self)
        return 'Needs 4 cards'
    end,
}

SMODS.Blind {
    key = 'no_limits',
    name = 'No Limits',
    boss = { min = 1 },
    boss_colour = HEX('4D92C8'),
    atlas = 'ultatro_tracer',
    pos = { x = 0, y = 0 },
    dollars = 5,
    mult = 2,
    discovered = true,
    loc_txt = {
        name = 'No Limits',
        text = { 'Hands with fewer than {C:attention}5{} cards are debuffed.' },
    },
    debuff_hand = function(self, cards, hand, handname, check)
        return #(cards or {}) < 5
    end,
    get_loc_debuff_text = function(self)
        return 'Needs 5 cards'
    end,
}

log_line('loaded:' .. tostring(#heroes) .. ':local-overwatch-heroes')
