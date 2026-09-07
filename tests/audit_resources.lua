local spells_path = assert(arg[1], 'usage: lua tests/audit_resources.lua <Windower/res/spells.lua>')
local load_spells, load_error = loadfile(spells_path)
assert(load_spells, load_error)
local spells = load_spells()

local cards = dofile('./addons/TrustSupport/resources/card_assets.lua')
local metadata = dofile('./addons/TrustSupport/resources/trust_metadata.lua')
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

local metadata_count = 0
local official_cards = {}
local unclassified = {}
for trust_name, entry in pairs(metadata.by_name) do
    metadata_count = metadata_count + 1
    assert(by_name[trust_name], ('official metadata key is not a Trust spell name: %s'):format(trust_name))
    assert(metadata.roles[entry.role], ('invalid role for %s: %s'):format(trust_name, tostring(entry.role)))
    assert(metadata.affiliations[entry.affiliation],
        ('invalid affiliation for %s: %s'):format(trust_name, tostring(entry.affiliation)))
    assert(type(entry.signature) == 'string' and entry.signature ~= '',
        ('missing signature skill for %s'):format(trust_name))
    assert(type(entry.official_card) == 'number'
        and entry.official_card >= metadata.source.first_card
        and entry.official_card <= metadata.source.last_card,
        ('invalid official card number for %s'):format(trust_name))
    assert(not official_cards[entry.official_card],
        ('official card %03d is assigned more than once'):format(entry.official_card))
    official_cards[entry.official_card] = trust_name
end

for card = metadata.source.first_card, metadata.source.last_card do
    assert(official_cards[card], ('official card %03d is not represented'):format(card))
end
assert(metadata_count == metadata.source.last_card - metadata.source.first_card + 1,
    ('official metadata coverage mismatch: %d'):format(metadata_count))

for trust_name in pairs(by_name) do
    if not metadata.by_name[trust_name] then
        table.insert(unclassified, trust_name)
    end
end
table.sort(unclassified)

io.write(('Resource audit passed: %d Trusts, %d cards, %d official metadata records, '
    .. '%d duplicate model groups, %d shared identity groups.\n')
    :format(trust_count, card_count, metadata_count, duplicate_models, shared_identities))
io.write(('Unclassified by the official card gallery (%d): %s\n')
    :format(#unclassified, table.concat(unclassified, ', ')))
