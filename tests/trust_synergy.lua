package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local synergy = require('resources/trust_synergy')
local cards = require('resources/card_assets')

local function expect(condition, message)
    if not condition then
        error(message or 'expectation failed', 2)
    end
end

local ids = {}
local valid_confidence = {
    documented=true, reported=true, estimated=true, mixed=true, unverified=true,
}
local valid_kind = {
    party_bonus=true, behavior=true, skillchain=true, relationship=true, unverified=true,
}
local valid_value_status = {
    approximate=true, uncertain=true, partially_reported=true,
    not_reported=true, condition_unspecified=true,
}
local valid_detail_status = {missing_details=true}
local unresolved_pairs = 0
local scaled_effects = {}
local scaled_effect_count = 0
local forbidden_display_phrases = {
    'estimated', 'approximately', 'not given', 'not reported', 'magnitude',
    'not specified', 'unspecified', 'reported', 'uncertain', 'unverified',
    'proc rate', 'per tick', '/tick', 'scope unspecified', 'range uncertain',
}
local ovjang_effects, mnejing_effects = {}, {}
for _, group in ipairs(synergy.by_trust.Ovjang or {}) do
    for _, effect in ipairs(group.effects or {}) do
        if effect.trust == 'Ovjang' then ovjang_effects[effect.text] = true end
        if effect.trust == 'Mnejing' then mnejing_effects[effect.text] = true end
    end
end
expect(ovjang_effects['Enmity: -10%'] and ovjang_effects['Magic Damage: +10%']
    and mnejing_effects['Defense: +10%'] and mnejing_effects['Enmity: +10%'],
    'Nashmeira partner bonuses must be separate ability rows')
for _, group in ipairs(synergy.groups) do
    expect(type(group.id) == 'string' and group.id ~= '', 'synergy group needs an id')
    expect(not ids[group.id], 'duplicate synergy group id: ' .. group.id)
    ids[group.id] = true
    expect(type(group.members) == 'table' and #group.members >= 2,
        'synergy group needs at least two members: ' .. group.id)
    if group.activation then
        local member_set = {}
        for _, name in ipairs(group.members) do member_set[name] = true end
        expect(type(group.activation.required) == 'table'
                and #group.activation.required > 0
                and type(group.activation.any) == 'table'
                and #group.activation.any > 0,
            'conditional activation needs required and any members: ' .. group.id)
        for _, names in ipairs({group.activation.required, group.activation.any}) do
            for _, name in ipairs(names) do
                expect(member_set[name],
                    'activation name must belong to the group: ' .. group.id)
            end
        end
    end
    expect(type(group.trigger) == 'string' and group.trigger ~= '',
        'synergy group needs a trigger description: ' .. group.id)
    expect(valid_confidence[group.confidence], 'invalid confidence on ' .. group.id)
    expect(valid_kind[group.kind], 'invalid kind on ' .. group.id)
    expect(not group.detail_status or valid_detail_status[group.detail_status],
        'invalid detail status on ' .. group.id)
    expect(type(group.source) == 'table' and type(group.source.url) == 'string',
        'synergy group needs a source: ' .. group.id)
    expect(type(group.source_text) == 'table' and #group.source_text > 0,
        'synergy group needs verbatim source excerpts: ' .. group.id)
    if group.notes then
        expect(group.detail_status == 'missing_details',
            'displayed groups must keep source commentary out of notes: ' .. group.id)
    end
    if group.research_notes then
        expect(type(group.research_notes) == 'table'
                and #group.research_notes > 0,
            'research_notes must be a non-empty table: ' .. group.id)
        for _, note in ipairs(group.research_notes) do
            expect(type(note) == 'string' and note ~= '',
                'research note must be non-empty text: ' .. group.id)
        end
    end
    for _, excerpt in ipairs(group.source_text) do
        expect(type(excerpt.source) == 'string' and type(excerpt.url) == 'string'
            and type(excerpt.text) == 'string' and excerpt.text ~= '',
            'source excerpt needs attribution, URL, and verbatim text: ' .. group.id)
    end

    local display_text = (group.trigger or '') .. ' ' .. (group.summary or '')
    expect(not display_text:find('BG-Wiki', 1, true)
        and not display_text:find('FFXIclopedia', 1, true),
        'group description should not name its source site: ' .. group.id)
    for _, effect in ipairs(group.effects or {}) do
        display_text = display_text .. ' ' .. (effect.text or '')
        expect(not tostring(effect.text or ''):match(
                '^[^:]+:%s*[%+%-]?[%d,]+%%?%.$'),
            'standalone numeric effects omit a sentence period: ' .. group.id)
    end
    local lowered_display = display_text:lower()
    for _, phrase in ipairs(forbidden_display_phrases) do
        expect(not lowered_display:find(phrase, 1, true),
            ('display copy should use normalized wording (%s) in %s'):format(phrase, group.id))
    end

    if group.detail_status == 'missing_details' then
        unresolved_pairs = unresolved_pairs + 1
        expect(group.kind == 'unverified' and group.confidence == 'unverified',
            'missing-detail pair must remain unverified: ' .. group.id)
        expect(#group.members == 2 and #(group.effects or {}) == 0,
            'missing-detail candidate must be a pair without claimed effects: ' .. group.id)
        expect(#(group.references or {}) >= 2,
            'missing-detail pair should retain cross-check references: ' .. group.id)
    end

    for _, effect in ipairs(group.effects or {}) do
        expect(type(effect.text) == 'string' and effect.text ~= '',
            'empty effect text in ' .. group.id)
        expect(not effect.text:find('BG-Wiki', 1, true)
            and not effect.text:find('FFXIclopedia', 1, true),
            'effect description should not name its source site: ' .. group.id)
        expect(not effect.confidence or valid_confidence[effect.confidence],
            'invalid effect confidence in ' .. group.id)
        expect(not effect.value_status or valid_value_status[effect.value_status],
            'invalid value status in ' .. group.id)
        if effect.values_by_group_size then
            scaled_effect_count = scaled_effect_count + 1
            expect(type(effect.effect) == 'string' and effect.effect ~= '',
                'scaled effect needs a property label in ' .. group.id)
            expect(effect.confidence == 'estimated' and effect.value_status == 'approximate',
                'approximate group size values should retain their internal status in ' .. group.id)
            for size, value in pairs(effect.values_by_group_size) do
                expect(type(size) == 'number' and size >= 2,
                    'scaled value needs a numeric group size in ' .. group.id)
                expect(type(value) == 'table' and type(value.value) == 'number'
                    and type(value.unit) == 'string',
                    'scaled value needs a number and unit in ' .. group.id)
                expect(effect.text:find('+' .. value.value .. value.unit, 1, true),
                    'effect copy disagrees with structured values in ' .. group.id)
            end
            scaled_effects[effect.trust] = effect.values_by_group_size
        end
    end

    for _, trust_name in ipairs(group.members) do
        expect(cards[trust_name],
            ('unknown Trust card key %q in synergy group %s'):format(trust_name, group.id))
        local indexed = synergy.by_trust[trust_name]
        expect(indexed, 'missing by_trust index for ' .. trust_name)
        local found = false
        for _, indexed_group in ipairs(indexed) do
            if indexed_group == group then
                found = true
                break
            end
        end
        expect(found, ('missing index entry for %s in %s'):format(trust_name, group.id))
    end
end

local function group_for(trust_name, group_id)
    for _, group in ipairs(synergy.for_trust(trust_name)) do
        if group.id == group_id then
            return group
        end
    end
end

local aldo_group = group_for('Aldo', 'aldo_lion_zeid')
expect(aldo_group and #aldo_group.members == 3,
    'Aldo should resolve to the shared Aldo/Lion/Zeid group')
expect(#synergy.for_trust('Karaha-Baruha') == 2,
    'Karaha-Baruha should expose both of its synergy groups')
local nashmeira_group = group_for('Nashmeira', 'nashmeira_automata')
expect(nashmeira_group,
    'Nashmeira should resolve the automata group')
expect(not nashmeira_group.notes or #nashmeira_group.notes == 0,
    'alternate Trust compatibility reminders must stay out of display notes')
expect(not aldo_group.notes or #aldo_group.notes == 0,
    'Lion II and Zeid II exclusions must stay out of display notes')
local king_group = group_for('King of Hearts', 'king_of_hearts_shantotto')
expect(king_group and (not king_group.notes or #king_group.notes == 0),
    'unlisted Shantotto variants must stay out of display notes')
expect(group_for('Ulmia', 'prishe_ii_ulmia'),
    'Ulmia should resolve the Prishe II interaction')

local ark_group = group_for('AAEV', 'ark_angel_quintet')
expect(ark_group and #ark_group.effects == 2,
    'Ark Angel reports from both wikis should remain separate')
local kayeel_group = group_for('Kayeel-Payeel', 'kayeel_robel')
expect(kayeel_group and #kayeel_group.effects == 1
        and kayeel_group.effects[1].trust == 'Kayeel-Payeel / Robel-Akbel',
    'spell frequency should remain the actor-attributed Kayeel-Payeel/Robel-Akbel effect')
expect(not kayeel_group.notes or #kayeel_group.notes == 0,
    'the speculative Fast Cast explanation should not be presented as synergy information')
expect(group_for('Romaa Mihgo', 'romaa_nanaa_unverified')
    and group_for('Romaa Mihgo', 'romaa_lehko_unverified'),
    'each unverified Romaa Mihgo pairing should be represented separately')
expect(group_for('Ygnas', 'ygnas_darrcuiln_unverified')
    and group_for('Ygnas', 'ygnas_rosulatia_unverified'),
    'each unverified Ygnas pairing should be represented separately')
expect(scaled_effects.Lion and scaled_effects.Lion[2].value == 6
    and scaled_effects.Lion[3].value == 12,
    'Lion attack speed should retain its approximate values by group size')
expect(scaled_effects.Zeid and scaled_effects.Zeid[2].value == 10
    and scaled_effects.Zeid[3].value == 20,
    'Zeid attack should retain its approximate values by group size')
expect(scaled_effect_count == 2,
    ('unexpected number of group size scaled effects: %d'):format(scaled_effect_count))
expect(unresolved_pairs == 8,
    ('expected eight explicit missing-detail pairs, got %d'):format(unresolved_pairs))
expect(#synergy.groups == 27,
    ('unexpected normalized group count: %d'):format(#synergy.groups))

io.write(('Trust synergy data test passed (%d groups, %d indexed Trusts).\n'):format(
    #synergy.groups, (function()
        local count = 0
        for _ in pairs(synergy.by_trust) do count = count + 1 end
        return count
    end)()))
