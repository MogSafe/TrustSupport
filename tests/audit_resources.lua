local spells_path = assert(arg[1], 'usage: lua tests/audit_resources.lua <Windower/res/spells.lua>')
local load_spells, load_error = loadfile(spells_path)
assert(load_spells, load_error)
local spells = load_spells()

local cards = dofile('./addons/TrustSupport/resources/card_assets.lua')
local trust_count = 0
local by_name = {}
local by_model = {}
local by_identity = {}

local function canonical(value)
    return tostring(value or ''):lower():gsub('[%s%p%c]+', '')
end

for _, spell in pairs(spells) do
    if spell.type == 'Trust' then
        trust_count = trust_count + 1
        assert(type(spell.id) == 'number', 'Trust is missing numeric id')
        assert(type(spell.en) == 'string', ('Trust %d is missing English name'):format(spell.id))
        assert(type(spell.model) == 'number', ('%s is missing model id'):format(spell.en))
        assert(type(spell.party_name) == 'string', ('%s is missing party name'):format(spell.en))
        assert(type(spell.recast_id) == 'number', ('%s is missing recast id'):format(spell.en))
        assert(not by_name[spell.en], ('duplicate English Trust name: %s'):format(spell.en))

        by_name[spell.en] = spell
        by_model[spell.model] = by_model[spell.model] or {}
        table.insert(by_model[spell.model], spell)

        local identity = canonical(spell.party_name)
        by_identity[identity] = by_identity[identity] or {}
        table.insert(by_identity[identity], spell)
    end
end

assert(trust_count >= 100, ('unexpectedly small Trust catalog: %d'):format(trust_count))

local card_count = 0
for trust_name, relative_path in pairs(cards) do
    card_count = card_count + 1
    assert(by_name[trust_name], ('card key is not a Trust spell name: %s'):format(trust_name))
    local file = io.open('./addons/TrustSupport/' .. relative_path, 'rb')
    assert(file, ('missing card file for %s: %s'):format(trust_name, relative_path))
    file:close()
end

local duplicate_models = 0
for _, entries in pairs(by_model) do
    if #entries > 1 then
        duplicate_models = duplicate_models + 1
    end
end

local shared_identities = 0
for _, entries in pairs(by_identity) do
    if #entries > 1 then
        shared_identities = shared_identities + 1
    end
end

io.write(('Resource audit passed: %d Trusts, %d cards, %d duplicate model groups, %d shared identity groups.\n')
    :format(trust_count, card_count, duplicate_models, shared_identities))
