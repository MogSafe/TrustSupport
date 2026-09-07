-- Pure Trust roster and party-selection state.
--
-- Windower functions are injected so this module can be exercised outside the
-- game. It deliberately performs no casts, packet work, drawing, or config I/O.

local trust_state = {}

local TRUST_PERMITS = {
    [2497] = true, -- Windurst Trust permit
    [2499] = true, -- Bastok Trust permit
    [2501] = true, -- San d'Oria Trust permit
}

local RHAPSODY_IN_WHITE = 2884
local RHAPSODY_IN_AZURE = 2886

local function trim(value)
    return tostring(value or ''):match('^%s*(.-)%s*$')
end

local function lower(value)
    return trim(value):lower()
end

local function canonical(value)
    return lower(value):gsub('[%s%p%c]+', '')
end

local function count_entries(value)
    local count = 0
    for _ in pairs(value or {}) do
        count = count + 1
    end
    return count
end

local function append(map, key, value)
    if key == '' then
        return
    end

    map[key] = map[key] or {}
    for _, existing in ipairs(map[key]) do
        if existing == value then
            return
        end
    end
    table.insert(map[key], value)
end

local function shallow_copy(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

local State = {}
State.__index = State

function trust_state.new(options)
    assert(type(options) == 'table', 'trust_state.new requires an options table')
    assert(type(options.spells) == 'table', 'trust_state.new requires spell resources')

    local self = setmetatable({
        options = options,
        catalog = {},
        by_id = {},
        by_model = {},
        by_identity = {},
        by_lookup = {},
        pending = {},
        party_trusts = {},
        active_identities = {},
        active_ids = {},
        source_status = {},
        last_reconciled = {},
        logged_in = false,
        max_trusts = 0,
        party_count = 0,
        other_members = 0,
        base_open_slots = 0,
    }, State)

    self:_build_catalog(options.spells, options.card_assets or {})
    return self
end

function State:_build_catalog(spells, card_assets)
    for _, spell in pairs(spells) do
        if type(spell) == 'table' and spell.type == 'Trust' then
            local entry = {
                id = assert(tonumber(spell.id), 'Trust resource is missing an id'),
                en = tostring(spell.en or spell.name or ('Trust ' .. tostring(spell.id))),
                ja = spell.ja,
                party_name = tostring(spell.party_name or spell.en or ''),
                model = tonumber(spell.model),
                recast_id = tonumber(spell.recast_id) or tonumber(spell.id),
            }

            entry.identity_key = canonical(entry.party_name ~= '' and entry.party_name or entry.en)
            entry.card = card_assets[entry.en]
            entry.learned = false
            entry.recast_raw = nil
            entry.cooldown_seconds = nil
            entry.in_party = false
            entry.active_exact = false

            table.insert(self.catalog, entry)
            self.by_id[entry.id] = entry

            if entry.model then
                append(self.by_model, tostring(entry.model), entry)
            end
            append(self.by_identity, entry.identity_key, entry)

            append(self.by_lookup, lower(entry.en), entry)
            append(self.by_lookup, canonical(entry.en), entry)
            if entry.ja then
                append(self.by_lookup, lower(entry.ja), entry)
                append(self.by_lookup, canonical(entry.ja), entry)
            end
        end
    end

    table.sort(self.catalog, function(left, right)
        local left_name = lower(left.en)
        local right_name = lower(right.en)
        if left_name == right_name then
            return left.id < right.id
        end
        return left_name < right_name
    end)
end

function State:_read(name, fallback)
    local reader = self.options[name]
    if type(reader) ~= 'function' then
        return fallback, false
    end

    local ok, value = pcall(reader)
    if not ok or value == nil then
        return fallback, false
    end
    return value, true
end

function State:_resolve_party_member(member)
    if not member or not member.mob or member.mob.spawn_type ~= 14 then
        return nil
    end

    local models = member.mob.models or {}
    local model = tonumber(models[1])
    if model then
        local model_matches = self.by_model[tostring(model)] or {}
        if #model_matches == 1 then
            return model_matches[1], model, true
        end
    end

    local identity_key = canonical(member.name)
    local identity_matches = self.by_identity[identity_key] or {}
    if #identity_matches == 1 then
        return identity_matches[1], model, false
    end

    -- Alternate Trusts intentionally share party names. Prefer the sole
    -- learned variant only when the model could not identify it exactly.
    local learned_match = nil
    for _, entry in ipairs(identity_matches) do
        if entry.learned then
            if learned_match then
                learned_match = nil
                break
            end
            learned_match = entry
        end
    end
    return learned_match, model, false
end

function State:_key_item_set(key_items)
    local result = {}
    for key, value in pairs(key_items or {}) do
        local id = nil
        if type(value) == 'number' then
            id = value
        elseif value == true then
            id = tonumber(key)
        end
        if id then
            result[id] = true
        end
    end
    return result
end

function State:_trust_limit(key_items)
    if key_items[RHAPSODY_IN_AZURE] then
        return 5
    end
    if key_items[RHAPSODY_IN_WHITE] then
        return 4
    end
    for id in pairs(TRUST_PERMITS) do
        if key_items[id] then
            return 3
        end
    end
    return 0
end

function State:_reconcile_pending()
    self.last_reconciled = {}

    -- Missing runtime sources are commonly transient during login or zoning.
    -- Preserve the user's pending order until a complete snapshot is possible.
    if not self.logged_in
        or not self.source_status.spells
        or not self.source_status.recasts
        or not self.source_status.party
        or not self.source_status.key_items then
        return
    end

    local kept = {}
    for _, id in ipairs(self.pending) do
        local entry = self.by_id[id]
        local reason = nil
        if not entry or not entry.learned then
            reason = 'not_learned'
        elseif entry.in_party then
            reason = 'in_party'
        elseif entry.recast_raw == nil then
            reason = 'state_unavailable'
        elseif entry.recast_raw > 0 then
            reason = 'cooldown'
        elseif #kept >= self.base_open_slots then
            reason = 'party_full'
        end

        if reason then
            table.insert(self.last_reconciled, {
                id = id,
                name = entry and entry.en or tostring(id),
                reason = reason,
            })
        else
            table.insert(kept, id)
        end
    end
    self.pending = kept
end

function State:refresh()
    local info, info_ok = self:_read('get_info', {})
    local learned, spells_ok = self:_read('get_spells', {})
    local recasts, recasts_ok = self:_read('get_spell_recasts', {})
    local party, party_ok = self:_read('get_party', {})
    local key_items_raw, key_items_ok = self:_read('get_key_items', {})

    self.logged_in = info_ok and info.logged_in == true
    self.source_status = {
        info = info_ok,
        spells = spells_ok,
        recasts = recasts_ok,
        party = party_ok,
        key_items = key_items_ok,
    }

    for _, entry in ipairs(self.catalog) do
        entry.learned = learned[entry.id] and true or false
        entry.recast_raw = recasts[entry.recast_id]
        if entry.recast_raw ~= nil then
            entry.recast_raw = math.max(0, tonumber(entry.recast_raw) or 0)
            entry.cooldown_seconds = entry.recast_raw / 60
        else
            entry.cooldown_seconds = nil
        end
        entry.in_party = false
        entry.active_exact = false
    end

    self.party_trusts = {}
    self.active_identities = {}
    self.active_ids = {}

    for slot = 1, 5 do
        local member = party['p' .. tostring(slot)]
        if member and member.mob and member.mob.spawn_type == 14 then
            local entry, model, exact = self:_resolve_party_member(member)
            local identity_key = entry and entry.identity_key or canonical(member.name)
            local record = {
                slot = slot,
                name = member.name or (entry and entry.party_name) or 'Unknown Trust',
                model = model,
                id = entry and entry.id or nil,
                trust = entry,
                exact = exact,
                identity_key = identity_key,
            }
            table.insert(self.party_trusts, record)
            self.active_identities[identity_key] = true
            if entry then
                self.active_ids[entry.id] = true
                entry.active_exact = true
            end
        end
    end

    for _, entry in ipairs(self.catalog) do
        entry.in_party = self.active_identities[entry.identity_key] and true or false
    end

    local counted_party = 0
    for slot = 0, 5 do
        if party['p' .. tostring(slot)] then
            counted_party = counted_party + 1
        end
    end
    self.party_count = tonumber(party.party1_count) or counted_party
    self.party_count = math.max(self.party_count, #self.party_trusts + (self.logged_in and 1 or 0))

    self.other_members = math.max(0, self.party_count - #self.party_trusts - (self.logged_in and 1 or 0))
    self.max_trusts = self:_trust_limit(self:_key_item_set(key_items_raw))
    self.base_open_slots = math.max(0, self.max_trusts - #self.party_trusts - self.other_members)

    self:_reconcile_pending()
    return self:snapshot()
end

function State:_is_pending(id)
    for index, pending_id in ipairs(self.pending) do
        if pending_id == id then
            return true, index
        end
    end
    return false, nil
end

function State:eligibility(entry)
    if not entry then
        return false, 'not_found'
    end
    if not self.logged_in then
        return false, 'not_logged_in'
    end
    if not self.source_status.spells
        or not self.source_status.recasts
        or not self.source_status.party
        or not self.source_status.key_items then
        return false, 'state_unavailable'
    end
    if not entry.learned then
        return false, 'not_learned'
    end
    if entry.in_party then
        return false, 'in_party'
    end
    if self:_is_pending(entry.id) then
        return false, 'selected'
    end
    if entry.recast_raw == nil then
        return false, 'state_unavailable'
    end
    if entry.recast_raw > 0 then
        return false, 'cooldown'
    end
    if self.max_trusts == 0 then
        return false, 'no_trust_permit'
    end
    if self:remaining_slots() <= 0 then
        return false, 'party_full'
    end
    return true, 'ready'
end

function State:find(query)
    local raw_key = lower(query)
    local canonical_key = canonical(query)
    if raw_key == '' then
        return nil, 'empty', {}
    end

    local exact = self.by_lookup[raw_key] or self.by_lookup[canonical_key] or {}
    if #exact == 1 then
        return exact[1], nil, exact
    elseif #exact > 1 then
        return nil, 'ambiguous', exact
    end

    local matches = {}
    for _, entry in ipairs(self.catalog) do
        local name = lower(entry.en)
        local compact_name = canonical(entry.en)
        if name:sub(1, #raw_key) == raw_key
            or compact_name:sub(1, #canonical_key) == canonical_key then
            table.insert(matches, entry)
        end
    end

    if #matches == 1 then
        return matches[1], nil, matches
    elseif #matches > 1 then
        return nil, 'ambiguous', matches
    end
    return nil, 'not_found', matches
end

function State:select(query)
    self:refresh()
    local entry, find_reason, matches = self:find(query)
    if not entry then
        return false, find_reason, nil, matches
    end

    local eligible, reason = self:eligibility(entry)
    if not eligible then
        return false, reason, entry, matches
    end

    table.insert(self.pending, entry.id)
    return true, 'selected', entry, matches
end

function State:remove(query)
    self:refresh()
    local entry, find_reason, matches = self:find(query)
    if not entry then
        return false, find_reason, nil, matches
    end

    local selected, index = self:_is_pending(entry.id)
    if not selected then
        return false, 'not_selected', entry, matches
    end

    table.remove(self.pending, index)
    return true, 'removed', entry, matches
end

function State:clear()
    local removed = #self.pending
    self.pending = {}
    self.last_reconciled = {}
    return removed
end

function State:remaining_slots()
    return math.max(0, self.base_open_slots - #self.pending)
end

function State:pending_entries()
    local result = {}
    for index, id in ipairs(self.pending) do
        local entry = self.by_id[id]
        if entry then
            result[index] = entry
        end
    end
    return result
end

function State:roster(filter)
    filter = lower(filter)
    if filter == '' then
        filter = 'ready'
    end

    local result = {}
    for _, entry in ipairs(self.catalog) do
        local selected = self:_is_pending(entry.id)
        local include = false
        if filter == 'all' then
            include = entry.learned
        elseif filter == 'cooldown' then
            include = entry.learned and entry.recast_raw ~= nil and entry.recast_raw > 0
        elseif filter == 'party' then
            include = entry.active_exact
        elseif filter == 'selected' then
            include = selected
        elseif filter == 'ready' then
            include = entry.learned and not entry.in_party and not selected
                and entry.recast_raw ~= nil and entry.recast_raw == 0
        end

        if include then
            table.insert(result, entry)
        end
    end
    return result
end

function State:stats()
    local stats = {
        total = #self.catalog,
        learned = 0,
        ready = 0,
        cooldown = 0,
        cards = 0,
        unknown_recasts = 0,
    }

    for _, entry in ipairs(self.catalog) do
        if entry.card then
            stats.cards = stats.cards + 1
        end
        if entry.learned then
            stats.learned = stats.learned + 1
            if entry.recast_raw == nil then
                stats.unknown_recasts = stats.unknown_recasts + 1
            elseif entry.recast_raw > 0 then
                stats.cooldown = stats.cooldown + 1
            elseif not entry.in_party and not self:_is_pending(entry.id) then
                stats.ready = stats.ready + 1
            end
        end
    end
    return stats
end

function State:snapshot()
    return {
        logged_in = self.logged_in,
        sources = shallow_copy(self.source_status),
        max_trusts = self.max_trusts,
        party_count = self.party_count,
        active_trusts = #self.party_trusts,
        other_members = self.other_members,
        pending = #self.pending,
        open_slots_before_pending = self.base_open_slots,
        remaining_slots = self:remaining_slots(),
        reconciled = self.last_reconciled,
        stats = self:stats(),
    }
end

function State:catalog_size()
    return #self.catalog
end

function State:card_count()
    local cards = 0
    for _, entry in ipairs(self.catalog) do
        if entry.card then
            cards = cards + 1
        end
    end
    return cards
end

function State:unresolved_party_count()
    local unresolved = 0
    for _, member in ipairs(self.party_trusts) do
        if not member.trust then
            unresolved = unresolved + 1
        end
    end
    return unresolved
end

function State:source_count()
    return count_entries(self.source_status)
end

return trust_state
