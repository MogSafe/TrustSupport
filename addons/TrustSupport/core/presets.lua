-- Pure data model for saved Trust parties.
--
-- Persistence deliberately uses string-keyed slots. Windower's config data is
-- XML-backed, so explicit slot_1 ... slot_5 keys are safer than relying on a
-- nested table retaining numeric-array semantics after a round trip.

local presets = {}

presets.SLOT_COUNT = 5
presets.MAX_MEMBERS = 5

function presets.is_slot_index(value)
    return type(value) == 'number'
        and value == math.floor(value)
        and value >= 1
        and value <= presets.SLOT_COUNT
end

function presets.slot_key(index)
    assert(presets.is_slot_index(index), 'preset slot must be an integer from 1 to 5')
    return ('slot_%d'):format(index)
end

-- Return a fresh persisted settings shape. Every slot is represented by its
-- own ordered array so callers can safely populate one without aliasing any
-- other slot.
function presets.new_settings()
    local slots = {}
    for index = 1, presets.SLOT_COUNT do
        slots[presets.slot_key(index)] = {}
    end

    return {
        selected = 1,
        slots = slots,
    }
end

-- Construct the only record type stored inside a preset slot. The name is a
-- fallback for diagnostics if a future catalog cannot resolve the stable ID;
-- it is not used as the Trust's identity.
function presets.member(id, name)
    assert(type(id) == 'number' and id == math.floor(id) and id > 0,
        'preset member id must be a positive integer')
    assert(type(name) == 'string' and name ~= '',
        'preset member name must be a non-empty string')

    return {
        id = id,
        name = name,
    }
end

local function normalized_member(value)
    if type(value) ~= 'table' then
        return nil
    end

    local id = tonumber(value.id)
    if not id or id ~= math.floor(id) or id <= 0 then
        return nil
    end
    if type(value.name) ~= 'string' or not value.name:match('%S') then
        return nil
    end

    return presets.member(id, value.name)
end

local function ordered_slot_indices(slot)
    local found = {}
    for key in pairs(slot) do
        local index = tonumber(key)
        if index and index == math.floor(index) and index > 0 then
            found[index] = true
        end
    end

    local indices = {}
    for index in pairs(found) do
        indices[#indices + 1] = index
    end
    table.sort(indices)
    return indices
end

local function slot_value(slot, index)
    if slot[index] ~= nil then
        return slot[index]
    end
    return slot[tostring(index)]
end

local function normalize_slot(value)
    local normalized = {}
    if type(value) ~= 'table' then
        return normalized
    end

    for _, index in ipairs(ordered_slot_indices(value)) do
        local member = normalized_member(slot_value(value, index))
        if member then
            normalized[#normalized + 1] = member
            if #normalized == presets.MAX_MEMBERS then
                break
            end
        end
    end
    return normalized
end

local function source_slot(slots, index)
    local named = slots[presets.slot_key(index)]
    if named ~= nil then
        return named
    end
    if slots[index] ~= nil then
        return slots[index]
    end
    return slots[tostring(index)]
end

-- Convert persisted input into the canonical model without mutating it.
-- Numeric slot/entry keys and numeric-string values are accepted for
-- compatibility with tables read from XML-backed configuration. Semantic
-- party validation (duplicates, learned state, cooldowns, and capacity) is
-- intentionally deferred until a preset is loaded.
function presets.normalize_settings(value)
    local normalized = presets.new_settings()
    if type(value) ~= 'table' then
        return normalized
    end

    local selected = tonumber(value.selected)
    if presets.is_slot_index(selected) then
        normalized.selected = selected
    end

    if type(value.slots) ~= 'table' then
        return normalized
    end

    for index = 1, presets.SLOT_COUNT do
        normalized.slots[presets.slot_key(index)] = normalize_slot(
            source_slot(value.slots, index))
    end
    return normalized
end

-- Select a slot without reading or altering any party-planning state. String
-- numbers are accepted so command arguments can be passed through directly.
function presets.select(settings, index)
    if type(settings) ~= 'table' then
        return false, 'invalid_settings'
    end

    index = tonumber(index)
    if not presets.is_slot_index(index) then
        return false, 'invalid_slot'
    end

    settings.selected = index
    return true, index
end

local function intended_member(value)
    if type(value) ~= 'table' then
        return nil, nil, 'unresolved_member'
    end

    local trust = type(value.trust) == 'table' and value.trust or value
    local id = tonumber(trust.id or value.id)
    local name = trust.en or trust.name or value.name
    local identity_key = value.identity_key or trust.identity_key

    if not id or id ~= math.floor(id) or id <= 0
        or type(name) ~= 'string' or not name:match('%S') then
        return nil, nil, 'unresolved_member'
    end
    if type(identity_key) ~= 'string' or identity_key == '' then
        return nil, nil, 'missing_identity'
    end

    return presets.member(id, name), identity_key
end

local function append_intended(result, seen_ids, seen_identities, value)
    local member, identity_key, reason = intended_member(value)
    if not member then
        return false, reason
    end
    if seen_ids[member.id] then
        return false, 'duplicate_id', member.name
    end
    if seen_identities[identity_key] then
        return false, 'duplicate_identity', member.name
    end
    if #result >= presets.MAX_MEMBERS then
        return false, 'too_many_members', member.name
    end

    result[#result + 1] = member
    seen_ids[member.id] = true
    seen_identities[identity_key] = true
    return true
end

-- Save only the authoritative in-game Trust party in its current order.
-- Pending summons and staged dismissals are deliberately ignored: a preset is
-- a snapshot of confirmed party state, never a snapshot of an editing plan.
-- The operation is atomic; malformed active data never replaces the previous
-- slot contents.
function presets.save(settings, context, slot)
    if type(settings) ~= 'table' or type(settings.slots) ~= 'table' then
        return false, 'invalid_settings'
    end
    if type(context) ~= 'table' then
        return false, 'invalid_context'
    end
    if context.queue_active then
        return false, 'queue_active'
    end

    local index = slot == nil and tonumber(settings.selected) or tonumber(slot)
    if not presets.is_slot_index(index) then
        return false, 'invalid_slot'
    end

    local active = context.active or {}
    if type(active) ~= 'table' then
        return false, 'invalid_context'
    end

    local confirmed = {}
    local seen_ids = {}
    local seen_identities = {}

    for _, value in ipairs(active) do
        local ok, reason, name = append_intended(
            confirmed, seen_ids, seen_identities, value)
        if not ok then
            return false, reason, name
        end
    end

    if #confirmed == 0 then
        return false, 'empty_party'
    end

    settings.slots[presets.slot_key(index)] = confirmed
    return true, 'saved', index
end

local function active_record_id(value)
    if type(value) ~= 'table' then
        return nil
    end
    local trust = type(value.trust) == 'table' and value.trust or value
    local id = tonumber(trust.id or value.id)
    if id and id == math.floor(id) and id > 0 then
        return id
    end
    return nil
end

-- Report whether an occupied preset is the exact authoritative Trust party.
-- Order is significant because preset members are stored in summon order.
-- Pending additions and dismissals are intentionally ignored: a planned party
-- does not become the current party until the game confirms every change.
function presets.matches_active(settings, context, slot)
    if type(settings) ~= 'table' or type(settings.slots) ~= 'table' then
        return false, 'invalid_settings'
    end
    if type(context) ~= 'table' or type(context.active) ~= 'table' then
        return false, 'invalid_context'
    end

    local index = slot == nil and tonumber(settings.selected) or tonumber(slot)
    if not presets.is_slot_index(index) then
        return false, 'invalid_slot'
    end

    local stored = source_slot(settings.slots, index)
    if type(stored) ~= 'table' or next(stored) == nil then
        return false, 'empty_slot'
    end

    local positions = ordered_slot_indices(stored)
    if #positions == 0 then
        return false, 'empty_slot'
    end
    if #positions ~= #context.active then
        return true, false
    end

    for party_position, stored_position in ipairs(positions) do
        local member = normalized_member(slot_value(stored, stored_position))
        if not member then
            return false, 'malformed_slot'
        end
        if active_record_id(context.active[party_position]) ~= member.id then
            return true, false
        end
    end

    return true, true
end

-- Compare a stored target with the authoritative active party using exact
-- spell IDs. Alternate versions therefore appear as one extra active member
-- and one missing target member, ready for the planning step to replace.
-- Existing pending changes are deliberately outside this read-only operation.
function presets.compare(settings, context, slot)
    if type(settings) ~= 'table' or type(settings.slots) ~= 'table' then
        return false, 'invalid_settings'
    end
    if type(context) ~= 'table' or type(context.active) ~= 'table' then
        return false, 'invalid_context'
    end

    local index = slot == nil and tonumber(settings.selected) or tonumber(slot)
    if not presets.is_slot_index(index) then
        return false, 'invalid_slot'
    end

    local stored = source_slot(settings.slots, index)
    if type(stored) ~= 'table' or next(stored) == nil then
        return false, 'empty_slot'
    end

    local target = {}
    for _, position in ipairs(ordered_slot_indices(stored)) do
        local member = normalized_member(slot_value(stored, position))
        if not member then
            return false, 'malformed_slot'
        end
        target[#target + 1] = member
    end
    if #target == 0 then
        return false, 'empty_slot'
    end

    local active_by_id = {}
    for _, record in ipairs(context.active) do
        local id = active_record_id(record)
        if id and active_by_id[id] == nil then
            active_by_id[id] = record
        end
    end

    local target_ids = {}
    local matched = {}
    local missing = {}
    for _, member in ipairs(target) do
        target_ids[member.id] = true
        local active = active_by_id[member.id]
        if active then
            matched[#matched + 1] = {
                target = member,
                active = active,
            }
        else
            missing[#missing + 1] = member
        end
    end

    local extra = {}
    for _, record in ipairs(context.active) do
        local id = active_record_id(record)
        if not id or not target_ids[id] then
            extra[#extra + 1] = record
        end
    end

    local has_changes = #missing > 0 or #extra > 0
    local order_mismatch = false
    if not has_changes and #target == #context.active then
        for position, member in ipairs(target) do
            if active_record_id(context.active[position]) ~= member.id then
                order_mismatch = true
                break
            end
        end
    end

    return true, {
        slot = index,
        target = target,
        matched = matched,
        missing = missing,
        extra = extra,
        has_changes = has_changes,
        -- Loading presets changes party membership, but it cannot safely
        -- reorder an otherwise identical active party. Expose that distinct
        -- no-op so the UI can explain why an occupied yellow slot produces
        -- no staged summons or dismissals.
        order_mismatch = order_mismatch,
    }
end

local function active_record_name(record)
    if type(record) ~= 'table' then
        return 'Unknown Trust'
    end
    local trust = type(record.trust) == 'table' and record.trust or record
    return tostring(trust.en or trust.name or record.name or 'Unknown Trust')
end

local function active_record_identity(record)
    if type(record) ~= 'table' then
        return nil
    end
    local trust = type(record.trust) == 'table' and record.trust or record
    return record.identity_key or trust.identity_key
end

-- Turn the comparison into an ordered, read-only operation plan. Summon
-- targets remain stored-ID records until segment 7 resolves and validates
-- them against the current catalog.
function presets.build_plan(settings, context, slot)
    local ok, comparison_or_reason = presets.compare(settings, context, slot)
    if not ok then
        return false, comparison_or_reason
    end

    local comparison = comparison_or_reason
    local plan = {
        slot = comparison.slot,
        target = comparison.target,
        matched = comparison.matched,
        dismiss = {},
        summon = {},
        actions = {},
        has_changes = comparison.has_changes,
        order_mismatch = comparison.order_mismatch,
    }

    for _, record in ipairs(comparison.extra) do
        local operation = {
            kind = 'dismiss',
            id = active_record_id(record),
            name = active_record_name(record),
            identity_key = active_record_identity(record),
            active = record,
        }
        plan.dismiss[#plan.dismiss + 1] = operation
        plan.actions[#plan.actions + 1] = operation
    end

    for target_position, member in ipairs(comparison.target) do
        local missing = false
        for _, candidate in ipairs(comparison.missing) do
            if candidate.id == member.id then
                missing = true
                break
            end
        end
        if missing then
            local operation = {
                kind = 'summon',
                id = member.id,
                name = member.name,
                target_position = target_position,
                target = member,
            }
            plan.summon[#plan.summon + 1] = operation
            plan.actions[#plan.actions + 1] = operation
        end
    end

    return true, plan
end

local function resolve_catalog_entry(context, id)
    if type(context.entry_by_id) == 'function' then
        local called, entry, reason = pcall(context.entry_by_id, id)
        if not called then
            return nil, 'catalog_unavailable'
        end
        return entry, reason
    end

    local entry = context.by_id[id]
    if type(entry) == 'table' and entry.id == nil and #entry > 1 then
        return nil, 'ambiguous'
    end
    return entry, entry and nil or 'unresolved'
end

local function validation_error(errors, reason, member, position)
    errors[#errors + 1] = {
        reason = reason,
        id = member and member.id or nil,
        name = member and member.name or nil,
        position = position,
    }
end

local function validation_capacity(context)
    if context.capacity ~= nil then
        local capacity = tonumber(context.capacity)
        if capacity and capacity == math.floor(capacity) and capacity >= 0 then
            return math.min(presets.MAX_MEMBERS, capacity)
        end
        return nil
    end

    local max_trusts = tonumber(context.max_trusts)
    local other_members = tonumber(context.other_members or 0)
    if not max_trusts or max_trusts ~= math.floor(max_trusts) or max_trusts < 0
        or not other_members or other_members ~= math.floor(other_members)
        or other_members < 0 then
        return nil
    end
    return math.max(0, math.min(presets.MAX_MEMBERS, max_trusts - other_members))
end

-- Resolve and validate the complete operation plan without changing settings
-- or Trust state. The caller may stage this returned plan only when `ok` is
-- true. On validation failure every detected blocker is returned together.
function presets.validate_plan(settings, context, slot)
    if type(context) ~= 'table' or type(context.active) ~= 'table'
        or (type(context.by_id) ~= 'table'
            and type(context.entry_by_id) ~= 'function') then
        return false, 'invalid_context'
    end

    local capacity = validation_capacity(context)
    if capacity == nil then
        return false, 'invalid_context'
    end

    local ok, plan_or_reason = presets.build_plan(settings, context, slot)
    if not ok then
        return false, plan_or_reason
    end
    local plan = plan_or_reason

    local errors = {}
    if context.queue_active then
        validation_error(errors, 'queue_active')
    end
    if context.state_ready == false then
        validation_error(errors, 'state_unavailable')
    end
    if #plan.target > capacity then
        validation_error(errors, 'capacity_exceeded')
        errors[#errors].capacity = capacity
        errors[#errors].requested = #plan.target
    end
    if #plan.target > presets.MAX_MEMBERS then
        validation_error(errors, 'too_many_members')
    end

    local active_ids = {}
    for _, record in ipairs(context.active) do
        local id = active_record_id(record)
        if id then
            active_ids[id] = true
        end
    end

    local seen_ids = {}
    local seen_identities = {}
    local resolved_by_position = {}
    local resolved_by_id = {}
    for position, member in ipairs(plan.target) do
        if seen_ids[member.id] then
            validation_error(errors, 'duplicate_id', member, position)
        else
            seen_ids[member.id] = true
        end

        local entry, resolution_reason = resolve_catalog_entry(context, member.id)
        if type(entry) ~= 'table' or tonumber(entry.id) ~= member.id then
            validation_error(errors, resolution_reason or 'unresolved', member, position)
        else
            resolved_by_position[position] = entry
            resolved_by_id[member.id] = entry

            local identity_key = entry.identity_key
            if type(identity_key) ~= 'string' or identity_key == '' then
                validation_error(errors, 'missing_identity', member, position)
            elseif seen_identities[identity_key] then
                validation_error(errors, 'duplicate_identity', member, position)
            else
                seen_identities[identity_key] = true
            end

            if context.state_ready ~= false then
                if entry.learned ~= true then
                    validation_error(errors, 'not_learned', member, position)
                elseif not active_ids[member.id] then
                    if entry.recast_raw == nil then
                        validation_error(errors, 'state_unavailable', member, position)
                    elseif tonumber(entry.recast_raw) == nil then
                        validation_error(errors, 'state_unavailable', member, position)
                    elseif tonumber(entry.recast_raw) > 0 then
                        validation_error(errors, 'cooldown', member, position)
                    end
                end
            end
        end
    end

    if #errors > 0 then
        return false, 'validation_failed', errors
    end

    plan.capacity = capacity
    plan.resolved_target = resolved_by_position
    for _, operation in ipairs(plan.summon) do
        operation.entry = resolved_by_id[operation.id]
    end
    return true, plan
end

local function cooldown_only(errors)
    if type(errors) ~= 'table' or #errors == 0 then
        return false
    end
    for _, value in ipairs(errors) do
        if value.reason ~= 'cooldown' then
            return false
        end
    end
    return true
end

-- Public load entry point. Cooldowns are soft blockers: the strict target
-- comparison still stages every non-preset active Trust for dismissal, while
-- missing preset members on cooldown are omitted from this staging pass. All
-- structural and state-integrity failures remain atomic hard blockers.
function presets.load_plan(settings, context, slot)
    local ok, plan_or_reason, errors = presets.validate_plan(
        settings, context, slot)
    if ok then
        plan_or_reason.partial = false
        plan_or_reason.skipped = {}
        plan_or_reason.actionable = plan_or_reason.has_changes
        return true, plan_or_reason
    end
    if plan_or_reason ~= 'validation_failed' or not cooldown_only(errors) then
        return false, plan_or_reason, errors
    end

    local built, partial_or_reason = presets.build_plan(settings, context, slot)
    if not built then
        return false, partial_or_reason
    end
    local plan = partial_or_reason
    local blocked_ids = {}
    for _, value in ipairs(errors) do
        local id = tonumber(value.id)
        if id then
            blocked_ids[id] = value
        end
    end

    local available_summons = {}
    local actions = {}
    for _, operation in ipairs(plan.dismiss) do
        actions[#actions + 1] = operation
    end
    for _, operation in ipairs(plan.summon) do
        if blocked_ids[tonumber(operation.id)] then
            -- The skipped member remains part of plan.target and therefore of
            -- the saved preset; only this immediate summon operation is left
            -- out. Loading again after recast expiry stages the missing member.
        else
            local entry = resolve_catalog_entry(context, operation.id)
            operation.entry = entry
            available_summons[#available_summons + 1] = operation
            actions[#actions + 1] = operation
        end
    end

    plan.summon = available_summons
    plan.actions = actions
    plan.capacity = validation_capacity(context)
    plan.partial = true
    plan.skipped = errors
    local available_members = #plan.target - #plan.skipped
    -- Never let a partial load whose entire target is unavailable act as a
    -- dismissal-only shortcut that empties the current party.
    plan.actionable = available_members > 0
        and (#plan.dismiss > 0 or #plan.summon > 0)
    plan.has_changes = plan.actionable
    if not plan.actionable then
        return false, 'validation_failed', errors
    end
    return true, plan
end

function presets.clear(settings, slot)
    if type(settings) ~= 'table' or type(settings.slots) ~= 'table' then
        return false, 'invalid_settings'
    end
    local index = slot == nil and tonumber(settings.selected) or tonumber(slot)
    if not presets.is_slot_index(index) then
        return false, 'invalid_slot'
    end

    local key = presets.slot_key(index)
    local previous = type(settings.slots[key]) == 'table' and #settings.slots[key] or 0
    settings.slots[key] = {}
    return true, 'cleared', index, previous
end

function presets.list(settings, context)
    if type(settings) ~= 'table' or type(settings.slots) ~= 'table' then
        return false, 'invalid_settings'
    end

    local result = {}
    for index = 1, presets.SLOT_COUNT do
        local members = normalize_slot(source_slot(settings.slots, index))
        local matches_active = false
        local loadable = nil
        local partial = false
        local blockers = nil
        local actionable = nil
        local order_mismatch = false
        if context ~= nil and #members > 0 then
            local match_ok, matched = presets.matches_active(
                settings, context, index)
            matches_active = match_ok and matched == true

            -- A complete runtime context also lets the UI distinguish a
            -- stored preset that can be loaded completely, loaded partially
            -- around cooldowns, or blocked by a hard validation failure.
            if type(context.by_id) == 'table'
                or type(context.entry_by_id) == 'function' then
                local load_ok, load_result, load_errors = presets.load_plan(
                    settings, context, index)
                loadable = load_ok == true
                    and (not load_result.partial or load_result.actionable)
                actionable = load_ok and load_result.actionable == true
                order_mismatch = load_ok
                    and load_result.order_mismatch == true
                if load_ok and load_result.partial then
                    blockers = load_result.skipped
                elseif not load_ok then
                    blockers = load_result == 'validation_failed'
                        and load_errors or {{reason=load_result}}
                end
                partial = load_ok and load_result.partial == true
            end
        end
        result[index] = {
            slot = index,
            selected = tonumber(settings.selected) == index,
            occupied = #members > 0,
            matches_active = matches_active,
            loadable = loadable,
            partial = partial,
            blockers = blockers,
            actionable = actionable,
            order_mismatch = order_mismatch,
            members = members,
        }
    end
    return true, result
end

return presets
