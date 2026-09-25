package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local trust_state = require('core/trust_state')
local command_adapter = require('core/commands')
local trust_metadata = require('resources/trust_metadata')
local affiliation_assets = require('resources/affiliation_assets')

local tests_run = 0

local function expect(condition, message)
    if not condition then
        error(message or 'expectation failed', 2)
    end
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(('%s (expected %s, got %s)'):format(
            message or 'values differ',
            tostring(expected),
            tostring(actual)
        ), 2)
    end
end

local function test(name, body)
    local ok, err = pcall(body)
    if not ok then
        io.stderr:write(('FAIL %s: %s\n'):format(name, tostring(err)))
        os.exit(1)
    end
    tests_run = tests_run + 1
    io.write(('PASS %s\n'):format(name))
end

local spells = {
    [896] = {id=896, en='Shantotto', ja='Shantotto JP', model=3000, party_name='Shantotto', recast_id=896, type='Trust'},
    [907] = {id=907, en='Lion', ja='Lion JP', model=3011, party_name='Lion', recast_id=907, type='Trust'},
    [909] = {id=909, en='Mihli Aliapoh', ja='Mihli JP', model=3013, party_name='MihliAliapoh', recast_id=909, type='Trust'},
    [951] = {id=951, en='Rahal', ja='Rahal JP', model=3056, party_name='Rahal', recast_id=951, type='Trust'},
    [955] = {id=955, en='Apururu (UC)', ja='Apururu JP', model=3061, party_name='Apururu', recast_id=955, type='Trust'},
    [1009] = {id=1009, en='Lion II', ja='Lion II JP', model=3081, party_name='Lion', recast_id=1009, type='Trust'},
    [1019] = {id=1019, en='Shantotto II', ja='Shantotto II JP', model=3110, party_name='Shantotto', recast_id=1019, type='Trust'},
    [1] = {id=1, en='Cure', recast_id=1, type='WhiteMagic'},
}

local function fixture()
    local runtime = {
        info = {logged_in = true},
        learned = {
            [896] = true,
            [907] = true,
            [909] = true,
            [951] = true,
            [955] = true,
            [1009] = true,
            [1019] = true,
        },
        recasts = {
            [896] = 0,
            [907] = 0,
            [909] = 0,
            [951] = 0,
            [955] = 0,
            [1009] = 0,
            [1019] = 0,
        },
        party = {
            p0 = {name='Player', mob={spawn_type=0}},
            party1_count = 1,
        },
        key_items = {2886},
    }

    local state = trust_state.new({
        spells = spells,
        card_assets = {['Mihli Aliapoh'] = 'assets/cards/mihli.png'},
        trust_metadata = {
            ['Mihli Aliapoh'] = {
                role = 'healer',
                stratagem = 'Healer',
                affiliation = 'aht_urhgan',
                affiliation_label = 'The Empire of Aht Urhgan',
                signature = 'Scouring Bubbles',
                official_card = 114,
            },
        },
        get_info = function() return runtime.info end,
        get_spells = function() return runtime.learned end,
        get_spell_recasts = function() return runtime.recasts end,
        get_party = function() return runtime.party end,
        get_key_items = function() return runtime.key_items end,
    })
    state:refresh()
    return state, runtime
end

test('catalog filters non-Trust spells', function()
    local state = fixture()
    equal(state:catalog_size(), 7)
    equal(state:card_count(), 1)
end)

test('Trust limit follows permit and Rhapsody key items', function()
    local state, runtime = fixture()
    equal(state:snapshot().max_trusts, 5)

    runtime.key_items = {2884}
    equal(state:refresh().max_trusts, 4)

    runtime.key_items = {2499}
    equal(state:refresh().max_trusts, 3)

    runtime.key_items = {}
    equal(state:refresh().max_trusts, 0)
end)

test('selection preserves order and prevents duplicates', function()
    local state = fixture()
    local ok = state:select('Mihli Aliapoh')
    expect(ok, 'Mihli should be selectable')
    ok = state:select('Rahal')
    expect(ok, 'Rahal should be selectable')

    local pending = state:pending_entries()
    equal(pending[1].en, 'Mihli Aliapoh')
    equal(pending[2].en, 'Rahal')

    local duplicate, reason = state:select('MihliAliapoh')
    expect(not duplicate)
    equal(reason, 'selected')

    ok = state:remove('Mihli')
    expect(ok)
    equal(state:pending_entries()[1].en, 'Rahal')
end)

test('selection prevents alternate versions of a pending identity', function()
    local state = fixture()
    expect(state:select('Lion'))

    local duplicate, reason = state:select('Lion II')
    expect(not duplicate)
    equal(reason, 'identity_selected')
    equal(#state:pending_entries(), 1)
    equal(state:pending_entries()[1].en, 'Lion')
    expect(state:is_identity_pending(state:find('Lion II')))
    equal(#state:roster('ready'), 5)
end)

test('cooldown is converted and blocks selection', function()
    local state, runtime = fixture()
    runtime.recasts[909] = 150
    state:refresh()

    local entry = state:find('Mihli Aliapoh')
    equal(entry.cooldown_seconds, 2.5)
    local ok, reason = state:select('Mihli Aliapoh')
    expect(not ok)
    equal(reason, 'cooldown')
end)

test('model IDs resolve alternate Trusts and shared identities', function()
    local state, runtime = fixture()
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='Lion', mob={spawn_type=14, models={[1]=3081}}},
        party1_count = 2,
    }
    local snapshot = state:refresh()
    equal(snapshot.active_trusts, 1)
    equal(state.party_trusts[1].trust.en, 'Lion II')
    expect(state:find('Lion').in_party)
    expect(state:find('Lion II').active_exact)

    local ok, reason = state:select('Lion')
    expect(not ok)
    equal(reason, 'in_party')
end)

test('human party members consume Trust capacity', function()
    local state, runtime = fixture()
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='Friend', mob={spawn_type=0}},
        p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
        party1_count = 3,
    }
    local snapshot = state:refresh()
    equal(snapshot.active_trusts, 1)
    equal(snapshot.other_members, 1)
    equal(snapshot.trust_capacity, 4)
    equal(snapshot.remaining_slots, 3)
    equal(#state.party_trusts, 1,
        'human members must not be represented as Trust party records')
end)

test('unknown future Trusts remain manageable without becoming human members', function()
    local state, runtime = fixture()
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='FutureTrust', mob={spawn_type=14, models={[1]=9999}}},
        party1_count = 2,
    }
    local snapshot = state:refresh()
    equal(snapshot.active_trusts, 1)
    equal(snapshot.other_members, 0)
    equal(snapshot.unresolved_trusts, 1)
    equal(#state.party_trusts, 1)
    equal(state.party_trusts[1].name, 'FutureTrust')
    expect(state.party_trusts[1].unresolved)
    expect(state.party_trusts[1].trust == nil)
    expect(state:stage_dismissal('FutureTrust'),
        'spawn-type Trusts must remain dismissible by their party name')
    equal(state:snapshot().pending_dismissals, 1)
end)

test('refresh reconciles pending Trusts that enter the party', function()
    local state, runtime = fixture()
    expect(state:select('Mihli Aliapoh'))
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        party1_count = 2,
    }

    local snapshot = state:refresh()
    equal(snapshot.pending, 0)
    equal(#snapshot.reconciled, 1)
    equal(snapshot.reconciled[1].reason, 'in_party')
end)

test('capacity rejects selections beyond available party slots', function()
    local state, runtime = fixture()
    runtime.key_items = {2497}
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='FriendOne', mob={spawn_type=0}},
        p2 = {name='FriendTwo', mob={spawn_type=0}},
        party1_count = 3,
    }
    state:refresh()
    expect(state:select('Mihli Aliapoh'))

    local ok, reason = state:select('Rahal')
    expect(not ok)
    equal(reason, 'party_full')
end)

test('staged dismissals open replacement slots and reconcile after departure', function()
    local state, runtime = fixture()
    runtime.key_items = {2499}
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
        p3 = {name='Shantotto', mob={spawn_type=14, models={[1]=3000}}},
        party1_count = 4,
    }
    state:refresh()
    equal(state:snapshot().remaining_slots, 0)

    local ok = state:stage_dismissal('Rahal')
    expect(ok)
    equal(state:snapshot().pending_dismissals, 1)
    equal(state:snapshot().remaining_slots, 1)
    expect(state:select('Lion'))
    equal(state:snapshot().remaining_slots, 0)

    runtime.party.p2 = nil
    runtime.party.party1_count = 3
    state:refresh()
    equal(state:snapshot().pending_dismissals, 0)
    equal(#state:pending_entries(), 1)
end)

test('undo preserves pending summons when the resulting party still fits', function()
    local state, runtime = fixture()
    runtime.key_items = {2499}
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
        party1_count = 3,
    }
    state:refresh()
    expect(state:stage_dismissal('Rahal'))
    expect(state:select('Lion'))

    local ok, reason, kept, removed = state:unstage_dismissal('Rahal')
    expect(ok)
    equal(reason, 'dismiss_removed')
    equal(kept.name, 'Rahal')
    expect(removed == nil,
        'Undo must not remove an incoming Trust while capacity remains')
    equal(#state:pending_entries(), 1)
    equal(state:pending_entries()[1].en, 'Lion')
    equal(state:snapshot().pending_dismissals, 0)
    equal(state:snapshot().remaining_slots, 0)
end)

test('undo removes the visually paired summon only when capacity requires it', function()
    local state, runtime = fixture()
    runtime.key_items = {2499}
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
        p3 = {name='Shantotto', mob={spawn_type=14, models={[1]=3000}}},
        party1_count = 4,
    }
    state:refresh()
    expect(state:stage_dismissal('Mihli Aliapoh'))
    expect(state:stage_dismissal('Rahal'))
    expect(state:select('Lion'))
    expect(state:select('Apururu (UC)'))

    local output = {}
    local handler = command_adapter.new(state, function(line)
        output[#output + 1] = line
    end)
    local result = handler:handle({'keep', 'Rahal'})
    expect(result and result.ok)
    equal(result.removed.en, 'Apururu (UC)',
        'the second outgoing Trust must remove the second paired summon')
    expect(output[1]:find('Apururu %(UC%) was removed from pending summons'),
        'the typed Undo command must identify the capacity-driven removal')
    equal(#state:pending_entries(), 1)
    equal(state:pending_entries()[1].en, 'Lion')
    equal(state:snapshot().pending_dismissals, 1)

    local ok, _, _, removed = state:unstage_dismissal('Mihli Aliapoh')
    expect(ok)
    equal(removed.en, 'Lion',
        'repeated Undo must remove the incoming Trust still paired to that row')
    equal(#state:pending_entries(), 0)
    equal(state:snapshot().pending_dismissals, 0)
    equal(state:snapshot().remaining_slots, 0)
end)

test('official metadata is attached without affecting unclassified Trusts', function()
    local state = fixture()
    local mihli = state:find('Mihli Aliapoh')
    equal(mihli.metadata.role, 'healer')
    equal(mihli.metadata.signature, 'Scouring Bubbles')
    expect(state:find('Rahal').metadata == nil)
end)

test('affiliation emblems and flags cover every official Trust consistently', function()
    local counts = {}
    for name, entry in pairs(trust_metadata.by_name) do
        local assets = affiliation_assets[entry.affiliation]
        expect(assets ~= nil,
            ('%s uses unmapped affiliation %s'):format(name,
                tostring(entry.affiliation)))
        expect(assets.emblem ~= nil,
            ('%s affiliation has no emblem'):format(name))
        local emblem = io.open('addons/TrustSupport/' .. assets.emblem, 'rb')
        expect(emblem ~= nil, ('missing emblem asset for %s'):format(name))
        emblem:close()
        if entry.affiliation == 'unknown' then
            expect(assets.flag == nil,
                ('unknown affiliation must not render a flag for %s'):format(name))
        else
            expect(assets.flag ~= nil,
                ('%s affiliation has no flag'):format(name))
            local flag = io.open('addons/TrustSupport/' .. assets.flag, 'rb')
            expect(flag ~= nil, ('missing flag asset for %s'):format(name))
            flag:close()
        end
        counts[entry.affiliation] = (counts[entry.affiliation] or 0) + 1
    end
    equal(counts.aht_urhgan, 13,
        'the official Aht Urhgan group, including Mnejing, must remain complete')
    for key, assets in pairs(affiliation_assets) do
        if assets.flag then
            expect(assets.emblem ~= nil,
                ('%s must not provide a flag without an emblem'):format(key))
        end
    end
end)

test('audited Trust job labels cover the official metadata roster', function()
    for name, entry in pairs(trust_metadata.by_name) do
        expect(type(entry.job_label) == 'string' and entry.job_label ~= '',
            ('missing audited job label for %s'):format(name))
    end
    equal(trust_metadata.by_name.Fablinix.job_label, 'THF/RDM',
        'Fablinix job label must use the audited display form')
    equal(trust_metadata.by_name['King of Hearts'].job_label, 'RDM/WHM',
        'King of Hearts job label must preserve its audited main/subjobs')
    equal(trust_metadata.by_name['Iroha II'].job_label, 'SAM/WHM/BLM',
        'Iroha II must retain its long audited job label')
    equal(trust_metadata.by_name.Mnejing.job_source_label, 'PLD/PLD',
        'Mnejing must retain its audited source job pairing')
    equal(trust_metadata.by_name.Mnejing.job_label, 'PLD',
        'identical main/subjobs must be compacted for display')
    for name, entry in pairs(trust_metadata.by_name) do
        local seen = {}
        for job in entry.job_label:gmatch('[^/]+') do
            expect(not seen[job],
                ('duplicate display job %s remains on %s'):format(job, name))
            seen[job] = true
        end
    end
end)

test('capacity changes preserve previously pending selections', function()
    local state, runtime = fixture()
    expect(state:select('Mihli Aliapoh'))
    expect(state:select('Rahal'))

    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='FriendOne', mob={spawn_type=0}},
        p2 = {name='FriendTwo', mob={spawn_type=0}},
        p3 = {name='FriendThree', mob={spawn_type=0}},
        p4 = {name='FriendFour', mob={spawn_type=0}},
        party1_count = 5,
    }
    local snapshot = state:refresh()
    equal(snapshot.remaining_slots, 0)
    equal(#state:pending_entries(), 2)
end)

test('transient missing state preserves pending selections', function()
    local state, runtime = fixture()
    expect(state:select('Rahal'))
    runtime.info = {logged_in = false}
    state:refresh()
    equal(#state:pending_entries(), 1)
end)

test('transient zone and logout snapshots preserve staged dismissals', function()
    local state, runtime = fixture()
    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
        party1_count = 2,
    }
    state:refresh()
    expect(state:stage_dismissal('Rahal'))

    runtime.info = {logged_in = false}
    runtime.party = {party1_count = 0}
    state:refresh()
    equal(state:snapshot().pending_dismissals, 1,
        'logout snapshot must not fulfill a staged dismissal')

    runtime.info = {logged_in = true}
    state:refresh()
    equal(state:snapshot().pending_dismissals, 1,
        'zoning snapshot without p0 must not fulfill a staged dismissal')

    runtime.party = {
        p0 = {name='Player', mob={spawn_type=0}},
        party1_count = 1,
    }
    state:refresh()
    equal(state:snapshot().pending_dismissals, 0,
        'a restored in-world party snapshot may fulfill the dismissal')
end)

test('name lookup supports compact names and reports ambiguous prefixes', function()
    local state = fixture()
    equal(state:find('MihliAliapoh').en, 'Mihli Aliapoh')
    equal(state:find('Lion').en, 'Lion')

    local entry, reason, matches = state:find('Li')
    expect(entry == nil)
    equal(reason, 'ambiguous')
    equal(#matches, 2)
end)

test('command adapter reports state without mutating runtime actions', function()
    local state = fixture()
    local output = {}
    local handler = command_adapter.new(state, function(line)
        output[#output + 1] = line
    end)

    handler:handle({'select', 'Mihli', 'Aliapoh'})
    equal(#state:pending_entries(), 1)
    expect(output[1]:find('pending position 1', 1, true) ~= nil)

    output = {}
    handler:handle({'status'})
    expect(#output >= 4)
    expect(output[1]:find('Known 7', 1, true) ~= nil)
end)

io.write(('All %d tests passed.\n'):format(tests_run))
