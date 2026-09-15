package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local trust_state = require('core/trust_state')
local commands = require('core/commands')
local presets = require('core/presets')

local function equal(actual, expected)
    assert(actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end

local spells = {
    [907] = {id=907, en='Lion', model=3011, party_name='Lion', recast_id=907, type='Trust'},
    [909] = {id=909, en='Mihli Aliapoh', model=3013, party_name='MihliAliapoh', recast_id=909, type='Trust'},
    [951] = {id=951, en='Rahal', model=3056, party_name='Rahal', recast_id=951, type='Trust'},
    [1009] = {id=1009, en='Lion II', model=3081, party_name='Lion', recast_id=1009, type='Trust'},
}

local runtime = {
    info = {logged_in=true},
    learned = {[907]=true, [909]=true, [951]=true, [1009]=true},
    recasts = {[907]=0, [909]=0, [951]=0, [1009]=0},
    party = {
        p0 = {name='Player', mob={spawn_type=0}},
        p1 = {name='Lion', mob={spawn_type=14, models={[1]=3011}}},
        party1_count = 2,
    },
    key_items = {2886},
}

local state = trust_state.new({
    spells = spells,
    get_info = function() return runtime.info end,
    get_spells = function() return runtime.learned end,
    get_spell_recasts = function() return runtime.recasts end,
    get_party = function() return runtime.party end,
    get_key_items = function() return runtime.key_items end,
})
state:refresh()

local settings = presets.new_settings()
settings.slots.slot_1 = {
    presets.member(1009, 'Lion II'),
    presets.member(909, 'Mihli Aliapoh'),
}

local queue_active = false
local queue = {
    snapshot = function()
        return {active=queue_active, status=queue_active and 'running' or 'idle'}
    end,
}
local output = {}
local saves = 0
local handler = commands.new(state, function(line)
    output[#output + 1] = line
end, queue, {
    presets = settings,
    save_settings = function() saves = saves + 1 end,
})

handler:handle({'preset', 'load', '1'})
equal(#state:pending_dismissal_records(), 1)
equal(state:pending_dismissal_records()[1].trust.id, 907)
equal(#state:pending_entries(), 2)
equal(state:pending_entries()[1].id, 1009)
equal(state:pending_entries()[2].id, 909)
assert(output[#output]:find('1 loaded', 1, true))

handler:handle({'preset', 'save', '2'})
equal(#settings.slots.slot_2, 1)
equal(settings.slots.slot_2[1].id, 907)
equal(saves, 1)

handler:handle({'preset', 'select', '2'})
equal(settings.selected, 2)
equal(saves, 2)

handler:handle({'preset', 'list'})
assert(output[#output - 3]:find('Preset 2 [selected]', 1, true))

-- Loading an empty slot is a no-op and preserves the existing staged plan.
local pending_before = {state.pending[1], state.pending[2]}
local lion_dismissal_before = state.pending_dismissals.lion
handler:handle({'preset', 'load', '5'})
equal(state.pending[1], pending_before[1])
equal(state.pending[2], pending_before[2])
equal(state.pending_dismissals.lion, lion_dismissal_before)
equal(output[#output], 'That preset slot is empty.')

handler:handle({'preset', 'clear', '2'})
equal(#settings.slots.slot_2, 0)
equal(saves, 3)

-- Queue activity blocks every mutating preset command.
queue_active = true
handler:handle({'preset', 'select', '4'})
equal(settings.selected, 2)
equal(output[#output], 'A summon queue is already running.')
handler:handle({'preset', 'save', '4'})
equal(#settings.slots.slot_4, 0)
equal(saves, 3)
queue_active = false

-- State-level staging failures are atomic even if runtime facts change after
-- the preset engine built its plan.
local atomic_pending = {state.pending[1], state.pending[2]}
local atomic_lion_dismissal = state.pending_dismissals.lion
runtime.recasts[951] = 60
local stage_ok, stage_reason = state:replace_plan({
    dismiss = {},
    summon = {
        {id=909},
        {id=951},
    },
})
assert(not stage_ok)
equal(stage_reason, 'cooldown')
equal(state.pending[1], atomic_pending[1])
equal(state.pending[2], atomic_pending[2])
equal(state.pending_dismissals.lion, atomic_lion_dismissal)

-- Cooldown members are skipped without weakening strict replacement: the
-- active non-preset Lion is still staged for dismissal and ready Lion II is
-- staged, while Mihli remains saved for a later load.
state:clear()
runtime.recasts[909] = 60
local partial_output_start = #output
handler:handle({'preset', 'load', '1'})
equal(#state:pending_entries(), 1)
equal(state:pending_entries()[1].id, 1009)
equal(#state:pending_dismissal_records(), 1)
equal(state:pending_dismissal_records()[1].trust.id, 907)
local partial_output = table.concat(output, '|', partial_output_start + 1)
assert(partial_output:find('partially loaded: 1 of 2 Trusts available', 1, true))
assert(partial_output:find('Mihli Aliapoh is on cooldown', 1, true))
runtime.recasts[909] = 0

-- The exact-match marker preserves saved summon order, while preset loading
-- deliberately avoids dismissing and immediately resummoning identical party
-- members merely to reorder them. Report that otherwise silent no-op.
state:clear()
runtime.party = {
    p0 = {name='Player', mob={spawn_type=0}},
    p1 = {name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
    p2 = {name='Lion', mob={spawn_type=14, models={[1]=3011}}},
    party1_count = 3,
}
state:refresh()
settings.slots.slot_3 = {
    presets.member(907, 'Lion'),
    presets.member(909, 'Mihli Aliapoh'),
}
local order_output_start = #output
handler:handle({'preset', 'load', '3'})
equal(#state:pending_entries(), 0)
equal(#state:pending_dismissal_records(), 0)
local order_output = table.concat(output, '|', order_output_start + 1)
assert(order_output:find('party order differs', 1, true))
assert(order_output:find('no summons or dismissals were selected', 1, true))

-- Future Trusts that Windower identifies as Trust actors remain manageable,
-- but cannot be persisted until a stable spell/resource identity exists.
-- Saving must fail clearly and leave the destination slot untouched.
runtime.party = {
    p0 = {name='Player', mob={spawn_type=0}},
    p1 = {name='FutureTrust', mob={spawn_type=14, models={[1]=9999}}},
    party1_count = 2,
}
state:refresh()
local saves_before_unresolved = saves
handler:handle({'preset', 'save', '4'})
equal(output[#output],
    'An unresolved active Trust cannot be saved to a preset yet.')
equal(#settings.slots.slot_4, 0)
equal(saves, saves_before_unresolved)

io.write('Preset runtime integration tests passed.\n')
