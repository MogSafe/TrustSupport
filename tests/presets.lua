package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local presets = require('core/presets')

local function equal(actual, expected)
    assert(actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end

equal(presets.SLOT_COUNT, 5)
equal(presets.MAX_MEMBERS, 5)
equal(presets.slot_key(1), 'slot_1')
equal(presets.slot_key(5), 'slot_5')
assert(presets.is_slot_index(1))
assert(presets.is_slot_index(5))
assert(not presets.is_slot_index(0))
assert(not presets.is_slot_index(6))
assert(not presets.is_slot_index(1.5))
assert(not presets.is_slot_index('1'))

local settings = presets.new_settings()
equal(settings.selected, 1)
for index = 1, presets.SLOT_COUNT do
    local slot = settings.slots[presets.slot_key(index)]
    assert(type(slot) == 'table', ('slot %d was not initialized'):format(index))
    equal(#slot, 0)
end

settings.slots.slot_1[1] = presets.member(910, 'Valaineral')
equal(settings.slots.slot_1[1].id, 910)
equal(settings.slots.slot_1[1].name, 'Valaineral')
equal(#settings.slots.slot_2, 0)

local second_settings = presets.new_settings()
equal(#second_settings.slots.slot_1, 0)

local missing = presets.normalize_settings(nil)
equal(missing.selected, 1)
equal(#missing.slots.slot_1, 0)
equal(#missing.slots.slot_5, 0)

local legacy = {
    selected = '4',
    slots = {
        [1] = {
            ['2'] = {id='909', name='Mihli Aliapoh', ignored='derived data'},
            [1] = {id=910, name='Valaineral', card='do-not-persist.png'},
        },
        ['2'] = {
            [1] = {id=951, name='Rahal'},
        },
    },
}
local normalized = presets.normalize_settings(legacy)
equal(normalized.selected, 4)
equal(#normalized.slots.slot_1, 2)
equal(normalized.slots.slot_1[1].id, 910)
equal(normalized.slots.slot_1[2].id, 909)
equal(normalized.slots.slot_1[1].name, 'Valaineral')
equal(normalized.slots.slot_1[1].card, nil)
equal(normalized.slots.slot_2[1].id, 951)

-- Normalization returns fresh data and never aliases persisted input.
normalized.slots.slot_1[1].name = 'Changed'
equal(legacy.slots[1][1].name, 'Valaineral')

local malformed = presets.normalize_settings({
    selected = 9,
    slots = {
        slot_1 = {
            {id=0, name='Bad ID'},
            {id=910, name=''},
            'not a member',
            {id=909, name='Mihli Aliapoh'},
            {id=951, name='Rahal'},
            {id=920, name='Trust Three'},
            {id=921, name='Trust Four'},
            {id=922, name='Trust Five'},
            {id=923, name='Truncated Trust'},
        },
        slot_2 = 'not a slot',
    },
})
equal(malformed.selected, 1)
equal(#malformed.slots.slot_1, 5)
equal(malformed.slots.slot_1[1].id, 909)
equal(malformed.slots.slot_1[5].id, 922)
equal(#malformed.slots.slot_2, 0)

-- Valid duplicate records survive structural normalization so the later load
-- validator can report them instead of silently changing the requested party.
local duplicates = presets.normalize_settings({
    slots = {
        slot_1 = {
            {id=910, name='Valaineral'},
            {id=910, name='Valaineral'},
        },
    },
})
equal(#duplicates.slots.slot_1, 2)

local selection_settings = presets.new_settings()
selection_settings.slots.slot_1[1] = presets.member(910, 'Valaineral')
local slots_before = selection_settings.slots
local slot_one_before = selection_settings.slots.slot_1
local member_before = selection_settings.slots.slot_1[1]

-- These stand in for the runtime structures the preset module deliberately
-- does not receive while merely selecting a slot.
local party_state = {
    active = {910},
    pending = {909},
    dismissals = {951},
    queue = {active=true},
}

local selected, selected_index = presets.select(selection_settings, '3')
assert(selected)
equal(selected_index, 3)
equal(selection_settings.selected, 3)
equal(selection_settings.slots, slots_before)
equal(selection_settings.slots.slot_1, slot_one_before)
equal(selection_settings.slots.slot_1[1], member_before)
equal(party_state.active[1], 910)
equal(party_state.pending[1], 909)
equal(party_state.dismissals[1], 951)
equal(party_state.queue.active, true)

local invalid_values = {0, 6, 2.5, 'not-a-slot'}
for _, value in ipairs(invalid_values) do
    local ok, reason = presets.select(selection_settings, value)
    assert(not ok)
    equal(reason, 'invalid_slot')
    equal(selection_settings.selected, 3)
end

local invalid_settings_ok, invalid_settings_reason = presets.select(nil, 1)
assert(not invalid_settings_ok)
equal(invalid_settings_reason, 'invalid_settings')

local valaineral = {id=910, en='Valaineral', identity_key='valaineral'}
local mihli = {id=909, en='Mihli Aliapoh', identity_key='mihlialiapo'}
local rahal = {id=951, en='Rahal', identity_key='rahal'}
local lion = {id=914, en='Lion', identity_key='lion'}
local lion_ii = {id=995, en='Lion II', identity_key='lion'}

local save_settings = presets.new_settings()
assert(presets.select(save_settings, 3))
save_settings.slots.slot_2[1] = presets.member(951, 'Existing Slot')
save_settings.slots.slot_3[1] = presets.member(999, 'Overwritten Slot')
local untouched_slot = save_settings.slots.slot_2

local save_ok, save_reason, saved_slot = presets.save(save_settings, {
    active = {
        {id=910, name='Valaineral', identity_key='valaineral', trust=valaineral},
        {id=914, name='Lion', identity_key='lion', trust=lion},
        {id=951, name='Rahal', identity_key='rahal', trust=rahal},
    },
    dismissals = {lion=true},
    pending = {mihli},
})
assert(save_ok)
equal(save_reason, 'saved')
equal(saved_slot, 3)
equal(save_settings.selected, 3)
equal(save_settings.slots.slot_2, untouched_slot)
equal(save_settings.slots.slot_2[1].name, 'Existing Slot')
equal(#save_settings.slots.slot_3, 3)
equal(save_settings.slots.slot_3[1].id, 910)
equal(save_settings.slots.slot_3[2].id, 951)
equal(save_settings.slots.slot_3[3].id, 909)

-- Saved entries contain only stable IDs and fallback names and do not alias
-- the runtime catalog records.
equal(save_settings.slots.slot_3[3].identity_key, nil)
equal(save_settings.slots.slot_3[3].recast_raw, nil)
rahal.en = 'Changed Runtime Name'
equal(save_settings.slots.slot_3[2].name, 'Rahal')
rahal.en = 'Rahal'

-- Saving captures the resulting party: staged dismissals are removed and
-- staged additions follow retained active Trusts.
local intended_party_settings = presets.new_settings()
local intended_party_ok = presets.save(intended_party_settings, {
    active = {{trust=valaineral, identity_key='valaineral'}},
    pending = {mihli},
    dismissals = {valaineral=true},
})
assert(intended_party_ok)
equal(#intended_party_settings.slots.slot_1, 1)
equal(intended_party_settings.slots.slot_1[1].id, 909)

-- An unresolved active member does not block saving when it is already staged
-- for dismissal and therefore is not part of the intended party.
local dismissed_unknown_ok = presets.save(intended_party_settings, {
    active = {{name='Unknown Trust', identity_key='unknown'}},
    pending = {rahal},
    dismissals = {unknown=true},
}, 2)
assert(dismissed_unknown_ok)
equal(#intended_party_settings.slots.slot_2, 1)
equal(intended_party_settings.slots.slot_2[1].id, 951)

-- Dismissing every active Trust without adding a replacement leaves no party
-- to save and must preserve the existing slot atomically.
local empty_intended_before = intended_party_settings.slots.slot_2
local empty_intended_ok, empty_intended_reason = presets.save(
    intended_party_settings, {
        active = {{trust=valaineral, identity_key='valaineral'}},
        dismissals = {valaineral=true},
    }, 2)
assert(not empty_intended_ok)
equal(empty_intended_reason, 'empty_party')
equal(intended_party_settings.slots.slot_2, empty_intended_before)

-- An explicit destination overwrites only that slot and does not select it.
local explicit_ok = presets.save(save_settings, {
    active = {{trust=rahal, identity_key='rahal'}},
}, '5')
assert(explicit_ok)
equal(save_settings.selected, 3)
equal(save_settings.slots.slot_5[1].id, 951)
equal(#save_settings.slots.slot_3, 3)

local function expect_atomic_failure(context, expected_reason)
    local before = save_settings.slots.slot_3
    local ok, reason = presets.save(save_settings, context)
    assert(not ok)
    equal(reason, expected_reason)
    equal(save_settings.slots.slot_3, before)
    equal(#save_settings.slots.slot_3, 3)
end

expect_atomic_failure({
    active = {{id=nil, en='Unknown Trust', identity_key='unknown'}},
}, 'unresolved_member')
expect_atomic_failure({
    active = {{id=900, en='No Identity'}},
}, 'missing_identity')
expect_atomic_failure({
    active = {
        {id=901, en='One', identity_key='one'},
        {id=902, en='Two', identity_key='two'},
        {id=903, en='Three', identity_key='three'},
        {id=904, en='Four', identity_key='four'},
        {id=905, en='Five', identity_key='five'},
        {id=906, en='Six', identity_key='six'},
    },
}, 'too_many_members')
expect_atomic_failure({}, 'empty_party')

local bad_context_ok, bad_context_reason = presets.save(save_settings, nil)
assert(not bad_context_ok)
equal(bad_context_reason, 'invalid_context')

local bad_slot_before = save_settings.slots.slot_3
local bad_slot_ok, bad_slot_reason = presets.save(save_settings, {active={rahal}}, 6)
assert(not bad_slot_ok)
equal(bad_slot_reason, 'invalid_slot')
equal(save_settings.slots.slot_3, bad_slot_before)

local comparison_settings = presets.new_settings()
comparison_settings.selected = 2
comparison_settings.slots.slot_2 = {
    presets.member(910, 'Valaineral'),
    presets.member(909, 'Mihli Aliapoh'),
}
local active_valaineral = {id=910, name='Valaineral', trust=valaineral}
local active_rahal = {id=951, name='Rahal', trust=rahal}
local existing_pending = {lion}
local existing_dismissals = {rahal=true}
local compare_context = {
    active = {active_valaineral, active_rahal},
    pending = existing_pending,
    dismissals = existing_dismissals,
}

local compare_ok, comparison = presets.compare(comparison_settings, compare_context)
assert(compare_ok)
equal(comparison.slot, 2)
equal(#comparison.target, 2)
equal(comparison.target[1].id, 910)
equal(comparison.target[2].id, 909)
equal(#comparison.matched, 1)
equal(comparison.matched[1].target.id, 910)
equal(comparison.matched[1].active, active_valaineral)
equal(#comparison.missing, 1)
equal(comparison.missing[1].id, 909)
equal(#comparison.extra, 1)
equal(comparison.extra[1], active_rahal)
equal(comparison.has_changes, true)

-- Comparison is read-only and ignores the old plan that a future validated
-- preset load will replace atomically.
equal(compare_context.pending, existing_pending)
equal(compare_context.pending[1], lion)
equal(compare_context.dismissals, existing_dismissals)
equal(compare_context.dismissals.rahal, true)
equal(comparison_settings.slots.slot_2[1].name, 'Valaineral')

local same_ok, same = presets.compare(comparison_settings, {
    active = {
        {trust=valaineral},
        {trust=mihli},
    },
})
assert(same_ok)
equal(#same.matched, 2)
equal(#same.missing, 0)
equal(#same.extra, 0)
equal(same.has_changes, false)
equal(same.order_mismatch, false)

local reordered_compare_ok, reordered_compare = presets.compare(
    comparison_settings, {
        active = {
            {trust=mihli},
            {trust=valaineral},
        },
    }, 2)
assert(reordered_compare_ok)
equal(reordered_compare.has_changes, false)
equal(reordered_compare.order_mismatch, true)

-- A loaded indicator requires the exact authoritative party in saved summon
-- order. Pending planning state is irrelevant until the game confirms it.
local match_ok, matches = presets.matches_active(comparison_settings, {
    active = {
        {trust=valaineral},
        {trust=mihli},
    },
    pending = {rahal},
    dismissals = {valaineral=true},
}, 2)
assert(match_ok)
equal(matches, true)

local reversed_ok, reversed = presets.matches_active(comparison_settings, {
    active = {
        {trust=mihli},
        {trust=valaineral},
    },
}, 2)
assert(reversed_ok)
equal(reversed, false)

local shorter_ok, shorter = presets.matches_active(comparison_settings, {
    active = {{trust=valaineral}},
}, 2)
assert(shorter_ok)
equal(shorter, false)

local match_list_ok, match_list = presets.list(comparison_settings, {
    active = {
        {trust=valaineral},
        {trust=mihli},
    },
})
assert(match_list_ok)
equal(match_list[2].matches_active, true)
equal(match_list[4].matches_active, false)

-- Exact spell IDs distinguish alternate versions even when their shared
-- identity is the same.
comparison_settings.slots.slot_4 = {presets.member(995, 'Lion II')}
local variant_ok, variant = presets.compare(comparison_settings, {
    active = {{trust=lion}},
}, 4)
assert(variant_ok)
equal(#variant.matched, 0)
equal(#variant.missing, 1)
equal(variant.missing[1].id, 995)
equal(#variant.extra, 1)
equal(variant.extra[1].trust.id, 914)

-- Missing target order follows the saved summon order; extra order follows
-- the current party order.
comparison_settings.slots.slot_5 = {
    presets.member(909, 'Mihli Aliapoh'),
    presets.member(995, 'Lion II'),
}
local order_ok, ordered = presets.compare(comparison_settings, {
    active = {{trust=rahal}, {trust=valaineral}},
}, 5)
assert(order_ok)
equal(ordered.missing[1].id, 909)
equal(ordered.missing[2].id, 995)
equal(ordered.extra[1].trust.id, 951)
equal(ordered.extra[2].trust.id, 910)

local empty_compare_ok, empty_compare_reason = presets.compare(
    comparison_settings, {active={}}, 1)
assert(not empty_compare_ok)
equal(empty_compare_reason, 'empty_slot')

local invalid_compare_ok, invalid_compare_reason = presets.compare(
    comparison_settings, {}, 2)
assert(not invalid_compare_ok)
equal(invalid_compare_reason, 'invalid_context')

local plan_ok, plan = presets.build_plan(comparison_settings, compare_context, 2)
assert(plan_ok)
equal(plan.slot, 2)
equal(plan.has_changes, true)
equal(#plan.matched, 1)
equal(#plan.dismiss, 1)
equal(plan.dismiss[1].kind, 'dismiss')
equal(plan.dismiss[1].id, 951)
equal(plan.dismiss[1].name, 'Rahal')
equal(plan.dismiss[1].identity_key, 'rahal')
equal(plan.dismiss[1].active, active_rahal)
equal(#plan.summon, 1)
equal(plan.summon[1].kind, 'summon')
equal(plan.summon[1].id, 909)
equal(plan.summon[1].name, 'Mihli Aliapoh')
equal(plan.summon[1].target_position, 2)
equal(#plan.actions, 2)
equal(plan.actions[1], plan.dismiss[1])
equal(plan.actions[2], plan.summon[1])

local no_change_ok, no_change_plan = presets.build_plan(comparison_settings, {
    active = {{trust=valaineral}, {trust=mihli}},
}, 2)
assert(no_change_ok)
equal(no_change_plan.has_changes, false)
equal(#no_change_plan.dismiss, 0)
equal(#no_change_plan.summon, 0)
equal(#no_change_plan.actions, 0)
equal(no_change_plan.order_mismatch, false)

local reordered_plan_ok, reordered_plan = presets.load_plan(
    comparison_settings, {
        active = {{trust=mihli}, {trust=valaineral}},
        by_id = {
            [910]={id=910, en='Valaineral', identity_key='valaineral',
                learned=true, recast_raw=0},
            [909]={id=909, en='Mihli Aliapoh', identity_key='mihlialiapo',
                learned=true, recast_raw=0},
        },
        max_trusts = 4,
        other_members = 0,
        state_ready = true,
    }, 2)
assert(reordered_plan_ok)
equal(reordered_plan.has_changes, false)
equal(reordered_plan.actionable, false)
equal(reordered_plan.order_mismatch, true)

local reordered_list_ok, reordered_list = presets.list(
    comparison_settings, {
        active = {{trust=mihli}, {trust=valaineral}},
        by_id = {
            [910]={id=910, en='Valaineral', identity_key='valaineral',
                learned=true, recast_raw=0},
            [909]={id=909, en='Mihli Aliapoh', identity_key='mihlialiapo',
                learned=true, recast_raw=0},
        },
        max_trusts = 4,
        other_members = 0,
        state_ready = true,
    })
assert(reordered_list_ok)
equal(reordered_list[2].matches_active, false)
equal(reordered_list[2].loadable, true)
equal(reordered_list[2].actionable, false)
equal(reordered_list[2].order_mismatch, true)

local variant_plan_ok, variant_plan = presets.build_plan(comparison_settings, {
    active = {{trust=lion}},
}, 4)
assert(variant_plan_ok)
equal(#variant_plan.dismiss, 1)
equal(variant_plan.dismiss[1].id, 914)
equal(#variant_plan.summon, 1)
equal(variant_plan.summon[1].id, 995)
equal(variant_plan.actions[1].kind, 'dismiss')
equal(variant_plan.actions[2].kind, 'summon')

-- Multiple changes always place every dismissal before the first summon.
local ordered_plan_ok, ordered_plan = presets.build_plan(comparison_settings, {
    active = {{trust=rahal}, {trust=valaineral}},
}, 5)
assert(ordered_plan_ok)
equal(#ordered_plan.dismiss, 2)
equal(#ordered_plan.summon, 2)
equal(#ordered_plan.actions, 4)
equal(ordered_plan.actions[1].kind, 'dismiss')
equal(ordered_plan.actions[2].kind, 'dismiss')
equal(ordered_plan.actions[3].kind, 'summon')
equal(ordered_plan.actions[4].kind, 'summon')
equal(ordered_plan.summon[1].id, 909)
equal(ordered_plan.summon[2].id, 995)

-- Building a plan never replaces or clears the plan already staged in state.
equal(compare_context.pending, existing_pending)
equal(compare_context.pending[1], lion)
equal(compare_context.dismissals, existing_dismissals)
equal(compare_context.dismissals.rahal, true)

local empty_plan_ok, empty_plan_reason = presets.build_plan(
    comparison_settings, {active={}}, 1)
assert(not empty_plan_ok)
equal(empty_plan_reason, 'empty_slot')

local function catalog_entry(id, name, identity_key, learned, recast_raw)
    return {
        id = id,
        en = name,
        identity_key = identity_key,
        learned = learned,
        recast_raw = recast_raw,
    }
end

local validation_catalog = {
    [909] = catalog_entry(909, 'Mihli Aliapoh', 'mihlialiapo', true, 0),
    [910] = catalog_entry(910, 'Valaineral', 'valaineral', true, 180),
    [914] = catalog_entry(914, 'Lion', 'lion', true, 0),
    [951] = catalog_entry(951, 'Rahal', 'rahal', true, 0),
    [995] = catalog_entry(995, 'Lion II', 'lion', true, 0),
}

-- A full active Trust party does not block a preset replacement when the
-- target itself fits capacity: all non-target members are dismissed first,
-- then missing target members are staged in saved order.
local full_replacement_catalog = {
    [909] = catalog_entry(909, 'Mihli Aliapoh', 'mihlialiapo', true, 0),
    [910] = catalog_entry(910, 'Valaineral', 'valaineral', true, 0),
}
local full_replacement_ok, full_replacement = presets.load_plan(
    comparison_settings, {
        active = {
            {trust=rahal},
            {trust=lion},
            {id=970, name='Extra One', identity_key='extraone'},
            {id=971, name='Extra Two', identity_key='extratwo'},
        },
        by_id = full_replacement_catalog,
        capacity = 4,
    }, 2)
assert(full_replacement_ok)
equal(#full_replacement.dismiss, 4)
equal(#full_replacement.summon, 2)
equal(full_replacement.summon[1].id, 910)
equal(full_replacement.summon[2].id, 909)
for index = 1, 4 do
    equal(full_replacement.actions[index].kind, 'dismiss')
end
equal(full_replacement.actions[5].kind, 'summon')
equal(full_replacement.actions[6].kind, 'summon')

local staged_pending_before = compare_context.pending
local staged_dismissals_before = compare_context.dismissals
local validated_ok, validated = presets.validate_plan(comparison_settings, {
    active = {active_valaineral, active_rahal},
    pending = staged_pending_before,
    dismissals = staged_dismissals_before,
    by_id = validation_catalog,
    max_trusts = 4,
    other_members = 1,
}, 2)
assert(validated_ok)
equal(validated.capacity, 3)
equal(#validated.resolved_target, 2)
equal(validated.resolved_target[1], validation_catalog[910])
equal(validated.resolved_target[2], validation_catalog[909])
equal(validated.summon[1].entry, validation_catalog[909])
-- Valaineral is already active, so its nonzero recast does not block keeping
-- it in the target party.
equal(validated.matched[1].target.id, 910)
equal(compare_context.pending, staged_pending_before)
equal(compare_context.dismissals, staged_dismissals_before)

local function has_error(errors, reason, id)
    for _, value in ipairs(errors or {}) do
        if value.reason == reason and (id == nil or value.id == id) then
            return value
        end
    end
    return nil
end

local cooldown_catalog = {}
for id, entry in pairs(validation_catalog) do
    cooldown_catalog[id] = catalog_entry(
        entry.id, entry.en, entry.identity_key, entry.learned, entry.recast_raw)
end
cooldown_catalog[909].recast_raw = 60
local cooldown_ok, cooldown_reason, cooldown_errors = presets.validate_plan(
    comparison_settings, {
        active = {active_valaineral, active_rahal},
        by_id = cooldown_catalog,
        capacity = 4,
    }, 2)
assert(not cooldown_ok)
equal(cooldown_reason, 'validation_failed')
assert(has_error(cooldown_errors, 'cooldown', 909))

local cooldown_list_ok, cooldown_list = presets.list(comparison_settings, {
    active = {active_valaineral, active_rahal},
    by_id = cooldown_catalog,
    capacity = 4,
})
assert(cooldown_list_ok)
equal(cooldown_list[2].occupied, true)
equal(cooldown_list[2].matches_active, false)
equal(cooldown_list[2].loadable, true)
equal(cooldown_list[2].partial, true)
equal(cooldown_list[2].blockers[1].reason, 'cooldown')
equal(cooldown_list[2].blockers[1].name, 'Mihli Aliapoh')

-- A partial load remains strict about the target: Rahal is still dismissed,
-- while the missing cooldown member is skipped until a later load.
local partial_ok, partial_plan = presets.load_plan(comparison_settings, {
    active = {active_valaineral, active_rahal},
    by_id = cooldown_catalog,
    capacity = 4,
}, 2)
assert(partial_ok)
equal(partial_plan.partial, true)
equal(partial_plan.actionable, true)
equal(#partial_plan.dismiss, 1)
equal(partial_plan.dismiss[1].id, 951)
equal(#partial_plan.summon, 0)
equal(#partial_plan.skipped, 1)
equal(partial_plan.skipped[1].id, 909)

-- If every target member is on cooldown, loading must not be enabled merely
-- because it could dismiss unrelated active Trusts and empty the party.
local all_cooldown_settings = presets.new_settings()
all_cooldown_settings.slots.slot_1 = {
    presets.member(909, 'Mihli Aliapoh'),
}
local all_cooldown_list_ok, all_cooldown_list = presets.list(
    all_cooldown_settings, {
        active = {active_rahal},
        by_id = cooldown_catalog,
        capacity = 4,
    })
assert(all_cooldown_list_ok)
equal(all_cooldown_list[1].partial, false)
equal(all_cooldown_list[1].loadable, false)
equal(all_cooldown_list[1].blockers[1].reason, 'cooldown')
local all_cooldown_load_ok, all_cooldown_load_reason = presets.load_plan(
    all_cooldown_settings, {
        active = {active_rahal},
        by_id = cooldown_catalog,
        capacity = 4,
    }, 1)
assert(not all_cooldown_load_ok)
equal(all_cooldown_load_reason, 'validation_failed')

local ready_list_ok, ready_list = presets.list(comparison_settings, {
    active = {active_valaineral, active_rahal},
    by_id = validation_catalog,
    capacity = 4,
})
assert(ready_list_ok)
equal(ready_list[2].loadable, true)
equal(ready_list[2].partial, false)
equal(ready_list[2].blockers, nil)

local unlearned_catalog = {}
for id, entry in pairs(validation_catalog) do
    unlearned_catalog[id] = catalog_entry(
        entry.id, entry.en, entry.identity_key, entry.learned, entry.recast_raw)
end
unlearned_catalog[909].learned = false
local unlearned_ok, unlearned_reason, unlearned_errors = presets.validate_plan(
    comparison_settings, {
        active = {active_valaineral},
        by_id = unlearned_catalog,
        capacity = 4,
    }, 2)
assert(not unlearned_ok)
equal(unlearned_reason, 'validation_failed')
assert(has_error(unlearned_errors, 'not_learned', 909))

local unresolved_settings = presets.new_settings()
unresolved_settings.slots.slot_1 = {presets.member(9999, 'Missing Trust')}
local unresolved_ok, unresolved_reason, unresolved_errors = presets.validate_plan(
    unresolved_settings, {
        active = {},
        by_id = validation_catalog,
        capacity = 4,
    }, 1)
assert(not unresolved_ok)
equal(unresolved_reason, 'validation_failed')
assert(has_error(unresolved_errors, 'unresolved', 9999))

local duplicate_settings = presets.new_settings()
duplicate_settings.slots.slot_1 = {
    presets.member(910, 'Valaineral'),
    presets.member(910, 'Valaineral'),
}
local duplicate_ok, duplicate_reason, duplicate_errors = presets.validate_plan(
    duplicate_settings, {
        active = {},
        by_id = validation_catalog,
        capacity = 5,
    }, 1)
assert(not duplicate_ok)
equal(duplicate_reason, 'validation_failed')
assert(has_error(duplicate_errors, 'duplicate_id', 910))

local shared_settings = presets.new_settings()
shared_settings.slots.slot_1 = {
    presets.member(914, 'Lion'),
    presets.member(995, 'Lion II'),
}
local shared_ok, shared_reason, shared_errors = presets.validate_plan(
    shared_settings, {
        active = {},
        by_id = validation_catalog,
        capacity = 5,
    }, 1)
assert(not shared_ok)
equal(shared_reason, 'validation_failed')
assert(has_error(shared_errors, 'duplicate_identity', 995))

local capacity_settings = presets.new_settings()
capacity_settings.slots.slot_1 = {
    presets.member(910, 'Valaineral'),
    presets.member(909, 'Mihli Aliapoh'),
    presets.member(914, 'Lion'),
    presets.member(951, 'Rahal'),
}
local capacity_ok, capacity_reason, capacity_errors = presets.validate_plan(
    capacity_settings, {
        active = {},
        by_id = validation_catalog,
        max_trusts = 4,
        other_members = 1,
    }, 1)
assert(not capacity_ok)
equal(capacity_reason, 'validation_failed')
local capacity_error = has_error(capacity_errors, 'capacity_exceeded')
assert(capacity_error)
equal(capacity_error.capacity, 3)
equal(capacity_error.requested, 4)

local busy_pending = compare_context.pending
local busy_dismissals = compare_context.dismissals
local busy_ok, busy_reason, busy_errors = presets.validate_plan(
    comparison_settings, {
        active = {active_valaineral},
        pending = busy_pending,
        dismissals = busy_dismissals,
        by_id = validation_catalog,
        capacity = 4,
        queue_active = true,
    }, 2)
assert(not busy_ok)
equal(busy_reason, 'validation_failed')
assert(has_error(busy_errors, 'queue_active'))
equal(compare_context.pending, busy_pending)
equal(compare_context.dismissals, busy_dismissals)

local unavailable_ok, unavailable_reason, unavailable_errors = presets.validate_plan(
    comparison_settings, {
        active = {active_valaineral},
        by_id = validation_catalog,
        capacity = 4,
        state_ready = false,
    }, 2)
assert(not unavailable_ok)
equal(unavailable_reason, 'validation_failed')
assert(has_error(unavailable_errors, 'state_unavailable'))

-- A variant replacement validates the incoming variant as a summon while the
-- active sibling remains scheduled for dismissal first.
local validated_variant_ok, validated_variant = presets.validate_plan(
    comparison_settings, {
        active = {{trust=validation_catalog[914]}},
        by_id = validation_catalog,
        capacity = 4,
    }, 4)
assert(validated_variant_ok)
equal(validated_variant.actions[1].kind, 'dismiss')
equal(validated_variant.actions[1].id, 914)
equal(validated_variant.actions[2].kind, 'summon')
equal(validated_variant.actions[2].id, 995)
equal(validated_variant.actions[2].entry, validation_catalog[995])

-- Saving is also blocked while a party-change queue is active.
local busy_save_before = save_settings.slots.slot_3
local busy_save_ok, busy_save_reason = presets.save(save_settings, {
    active = {valaineral},
    queue_active = true,
})
assert(not busy_save_ok)
equal(busy_save_reason, 'queue_active')
equal(save_settings.slots.slot_3, busy_save_before)

local invalid_validation_ok, invalid_validation_reason = presets.validate_plan(
    comparison_settings, {active={}, capacity=4}, 2)
assert(not invalid_validation_ok)
equal(invalid_validation_reason, 'invalid_context')

-- An unmodified party saves in authoritative party order.
local active_save_settings = presets.new_settings()
local active_save_ok = presets.save(active_save_settings, {
    active = {
        {trust=rahal},
        {trust=valaineral},
        {trust=lion},
    },
})
assert(active_save_ok)
equal(active_save_settings.slots.slot_1[1].id, 951)
equal(active_save_settings.slots.slot_1[2].id, 910)
equal(active_save_settings.slots.slot_1[3].id, 914)

-- Canonical settings survive repeated normalization without reordered or
-- aliased members, approximating the config serialization round trip.
local round_trip = presets.normalize_settings(active_save_settings)
local second_round_trip = presets.normalize_settings(round_trip)
equal(second_round_trip.selected, 1)
equal(#second_round_trip.slots.slot_1, 3)
for index, expected_id in ipairs({951, 910, 914}) do
    equal(second_round_trip.slots.slot_1[index].id, expected_id)
    assert(second_round_trip.slots.slot_1[index] ~= round_trip.slots.slot_1[index])
end

local ambiguous_ok, ambiguous_reason, ambiguous_errors = presets.load_plan(
    unresolved_settings, {
        active = {},
        entry_by_id = function()
            return nil, 'ambiguous'
        end,
        capacity = 4,
    }, 1)
assert(not ambiguous_ok)
equal(ambiguous_reason, 'validation_failed')
assert(has_error(ambiguous_errors, 'ambiguous', 9999))

local unavailable_recast_catalog = {
    [909] = catalog_entry(909, 'Mihli Aliapoh', 'mihlialiapo', true, nil),
    [910] = validation_catalog[910],
}
local unavailable_recast_ok, unavailable_recast_reason, unavailable_recast_errors =
    presets.load_plan(comparison_settings, {
        active = {active_valaineral},
        by_id = unavailable_recast_catalog,
        capacity = 4,
    }, 2)
assert(not unavailable_recast_ok)
equal(unavailable_recast_reason, 'validation_failed')
assert(has_error(unavailable_recast_errors, 'state_unavailable', 909))

-- Independent blockers are collected in one atomic failure.
local combined_catalog = {
    [909] = catalog_entry(909, 'Mihli Aliapoh', 'mihlialiapo', false, 0),
    [910] = catalog_entry(910, 'Valaineral', 'valaineral', true, 60),
}
local combined_ok, combined_reason, combined_errors = presets.load_plan(
    comparison_settings, {
        active = {},
        by_id = combined_catalog,
        capacity = 1,
        queue_active = true,
    }, 2)
assert(not combined_ok)
equal(combined_reason, 'validation_failed')
assert(has_error(combined_errors, 'queue_active'))
assert(has_error(combined_errors, 'capacity_exceeded'))
assert(has_error(combined_errors, 'cooldown', 910))
assert(has_error(combined_errors, 'not_learned', 909))

local callback_ok, callback_plan = presets.load_plan(comparison_settings, {
    active = {active_valaineral},
    entry_by_id = function(id)
        return validation_catalog[id]
    end,
    max_trusts = 5,
    other_members = 0,
}, 2)
assert(callback_ok)
equal(callback_plan.summon[1].entry.id, 909)

local callback_failure_ok, callback_failure_reason, callback_failure_errors =
    presets.load_plan(comparison_settings, {
        active = {},
        entry_by_id = function()
            error('catalog reader failed')
        end,
        capacity = 4,
    }, 2)
assert(not callback_failure_ok)
equal(callback_failure_reason, 'validation_failed')
assert(has_error(callback_failure_errors, 'catalog_unavailable'))

local malformed_compare_settings = presets.new_settings()
malformed_compare_settings.slots.slot_1 = {{id='bad', name='Broken'}}
local malformed_plan_ok, malformed_plan_reason = presets.load_plan(
    malformed_compare_settings, {
        active = {},
        by_id = validation_catalog,
        capacity = 4,
    }, 1)
assert(not malformed_plan_ok)
equal(malformed_plan_reason, 'malformed_slot')

local oversized_settings = presets.new_settings()
oversized_settings.slots.slot_1 = {
    presets.member(901, 'One'),
    presets.member(902, 'Two'),
    presets.member(903, 'Three'),
    presets.member(904, 'Four'),
    presets.member(905, 'Five'),
    presets.member(906, 'Six'),
}
local oversized_catalog = {}
for id = 901, 906 do
    oversized_catalog[id] = catalog_entry(id, tostring(id), tostring(id), true, 0)
end
local oversized_ok, oversized_reason, oversized_errors = presets.load_plan(
    oversized_settings, {
        active = {},
        by_id = oversized_catalog,
        capacity = 5,
    }, 1)
assert(not oversized_ok)
equal(oversized_reason, 'validation_failed')
assert(has_error(oversized_errors, 'capacity_exceeded'))
assert(has_error(oversized_errors, 'too_many_members'))

-- Sustained preset churn approximates repeated XML-backed config round trips.
-- Every operation must remain slot-local, preserve selected state through
-- normalization, and leave the caller's existing staging structures alone.
do
    local churn = presets.new_settings()
    local churn_catalog = {
        [909] = catalog_entry(909, 'Mihli Aliapoh', 'mihlialiapo', true, 0),
        [910] = catalog_entry(910, 'Valaineral', 'valaineral', true, 0),
        [951] = catalog_entry(951, 'Rahal', 'rahal', true, 0),
    }
    local active_sets = {
        {{trust=churn_catalog[909]}},
        {{trust=churn_catalog[910]}, {trust=churn_catalog[951]}},
        {{trust=churn_catalog[951]}, {trust=churn_catalog[909]}},
    }
    local function signature(slot)
        local ids = {}
        for index, member in ipairs(slot or {}) do
            ids[index] = tostring(member.id)
        end
        return table.concat(ids, ',')
    end

    for cycle = 1, 125 do
        local slot = (cycle - 1) % presets.SLOT_COUNT + 1
        local before = {}
        for index = 1, presets.SLOT_COUNT do
            before[index] = signature(churn.slots[presets.slot_key(index)])
        end

        assert(presets.select(churn, tostring(slot)))
        local saved, _, saved_slot = presets.save(
            churn, {active=active_sets[(cycle - 1) % #active_sets + 1]}, slot)
        assert(saved)
        equal(saved_slot, slot)
        for index = 1, presets.SLOT_COUNT do
            if index ~= slot then
                equal(signature(churn.slots[presets.slot_key(index)]), before[index])
            end
        end

        churn = presets.normalize_settings(churn)
        equal(churn.selected, slot)
        local pending_sentinel = {cycle}
        local dismissal_sentinel = {keep=true}
        local loaded, plan = presets.load_plan(churn, {
            active = {},
            pending = pending_sentinel,
            dismissals = dismissal_sentinel,
            by_id = churn_catalog,
            capacity = 5,
            state_ready = true,
        }, slot)
        assert(loaded)
        equal(#plan.summon, #active_sets[(cycle - 1) % #active_sets + 1])
        equal(pending_sentinel[1], cycle)
        equal(dismissal_sentinel.keep, true)

        if cycle % 9 == 0 then
            local clear_before = {}
            for index = 1, presets.SLOT_COUNT do
                clear_before[index] = signature(
                    churn.slots[presets.slot_key(index)])
            end
            assert(presets.clear(churn, slot))
            equal(#churn.slots[presets.slot_key(slot)], 0)
            for index = 1, presets.SLOT_COUNT do
                if index ~= slot then
                    equal(signature(churn.slots[presets.slot_key(index)]),
                        clear_before[index])
                end
            end
            churn = presets.normalize_settings(churn)
            equal(churn.selected, slot)
        end
    end
end

io.write('Preset engine tests passed.\n')
