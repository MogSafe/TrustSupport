-- Chat-command adapter for the headless Trust state.

local commands = {}
local preset_engine = require('core/presets')

local PAGE_SIZE = 18
local VALID_FILTERS = {
    all = true,
    cooldown = true,
    party = true,
    ready = true,
    selected = true,
}

local REASONS = {
    action_timeout = 'No matching Trust cast result was received.',
    already_dismissing = 'That Trust is already marked for dismissal.',
    ambiguous = 'That name matches more than one Trust.',
    busy = 'A summon queue is already running.',
    cast_input_failed = 'The Trust cast command could not be issued.',
    cooldown = 'That Trust is on cooldown.',
    empty = 'Provide a Trust name.',
    in_party = 'That Trust, or another version of that Trust, is already in the party.',
    identity_selected = 'Another version of that Trust is already pending.',
    invalid_context = 'Preset state is unavailable.',
    invalid_plan = 'The preset produced an invalid party plan.',
    invalid_settings = 'Preset settings are unavailable.',
    invalid_slot = 'Preset slots range from 1 to 5.',
    empty_party = 'There are no intended Trusts to save.',
    empty_slot = 'That preset slot is empty.',
    no_trust_permit = 'No Trust permit was detected.',
    no_pending = 'There are no pending party changes.',
    not_dismissing = 'That Trust is not marked for dismissal.',
    not_found = 'No matching Trust was found.',
    not_in_party = 'That Trust is not currently in the party.',
    not_running = 'No summon queue is running.',
    not_learned = 'That Trust is not available to this character.',
    not_logged_in = 'Trust state is unavailable while logged out.',
    not_selected = 'That Trust is not pending.',
    party_full = 'There are no remaining Trust party slots.',
    selected = 'That Trust is already pending.',
    state_unavailable = 'Windower has not provided a complete Trust state yet.',
    unresolved_member = 'An unresolved active Trust cannot be saved to a preset yet.',
    missing_identity = 'An active Trust is missing the identity data required for presets.',
}

local function lower(value)
    return tostring(value or ''):lower()
end

local function join(args, first)
    local values = {}
    for index = first, #args do
        values[#values + 1] = tostring(args[index])
    end
    return table.concat(values, ' ')
end

local function names(entries, limit)
    local result = {}
    for index, entry in ipairs(entries or {}) do
        if not limit or index <= limit then
            result[#result + 1] = entry.en
                or (entry.trust and entry.trust.en)
                or entry.name
                or tostring(entry.id)
        end
    end
    return table.concat(result, ', ')
end

local function display_seconds(seconds)
    seconds = tonumber(seconds) or 0
    if seconds >= 10 then
        return ('%ds'):format(math.ceil(seconds))
    end
    return ('%.1fs'):format(seconds)
end

local function entry_status(state, entry)
    if entry.active_exact then
        if state:is_pending_dismissal(entry) then
            return 'dismiss'
        end
        return 'party'
    end
    local selected = false
    for _, pending in ipairs(state:pending_entries()) do
        if pending.id == entry.id then
            selected = true
            break
        end
    end
    if selected then
        return 'selected'
    end
    if state:is_identity_pending(entry) then
        return 'identity selected'
    end
    if entry.in_party then
        return 'identity in party'
    end
    if entry.recast_raw == nil then
        return 'recast unavailable'
    end
    if entry.recast_raw > 0 then
        return 'cooldown ' .. display_seconds(entry.cooldown_seconds)
    end
    return 'ready'
end

local Handler = {}
Handler.__index = Handler

function commands.new(state, emit, queue, options)
    assert(state, 'commands.new requires Trust state')
    assert(type(emit) == 'function', 'commands.new requires an output function')
    options = options or {}
    return setmetatable({
        state = state,
        emit = emit,
        queue = queue,
        preset_settings = options.presets,
        save_settings = options.save_settings,
    }, Handler)
end

function Handler:_failure(reason, entry, matches)
    local message = REASONS[reason] or ('Unable to continue: ' .. tostring(reason))
    if reason == 'cooldown' and entry and entry.cooldown_seconds then
        message = ('%s is on cooldown for %s.'):format(
            entry.en,
            display_seconds(entry.cooldown_seconds)
        )
    elseif reason == 'ambiguous' and matches and #matches > 0 then
        message = message .. ' Matches: ' .. names(matches, 8)
        if #matches > 8 then
            message = message .. ', ...'
        end
    end
    self.emit(message)
end

function Handler:help()
    self.emit('Commands:')
    self.emit('//ts - toggle the Trust Support window')
    self.emit('//ts open|close - explicitly show or hide the window')
    self.emit('//ts search <name> - filter the visible Trust roster')
    self.emit('//ts scale <0.55-1.25> - resize the window')
    self.emit('//ts resetui - restore the default window position')
    self.emit('//ts status - party capacity, active Trusts, and pending Trusts')
    self.emit('//ts list [ready|cooldown|party|selected|all] [page]')
    self.emit('//ts select <name> - append a ready Trust to the pending order')
    self.emit('//ts remove <name> - remove a pending Trust')
    self.emit('//ts dismiss <name|all> - mark active Trusts for dismissal')
    self.emit('//ts keep <name> - undo a staged dismissal')
    self.emit('//ts clear - clear all pending party changes')
    self.emit('//ts summon - apply dismissals, then summon pending Trusts')
    self.emit('//ts cancel - stop the active party-change queue')
    self.emit('//ts diag - report underlying state-source health')
    self.emit('//ts icon on|off - show or hide the launcher icon')
    self.emit('//ts dialogue off|occasional|always - control post-summon speech bubbles')
    self.emit('//ts preset select|save|load|clear|list [1-5]')
end

function Handler:_queue_active()
    return self.queue and self.queue:snapshot().active or false
end

function Handler:_persist_presets()
    if type(self.save_settings) ~= 'function' then
        return true
    end
    local ok, err = pcall(self.save_settings)
    if not ok then
        self.emit(('Preset changed for this session but could not be saved: %s'):format(
            tostring(err)))
        return false
    end
    return true
end

function Handler:_preset_context()
    local snapshot = self.state:refresh()
    local sources = snapshot.sources or {}
    return {
        active = self.state.party_trusts,
        pending = self.state:pending_entries(),
        dismissals = self.state.pending_dismissals,
        by_id = self.state.by_id,
        max_trusts = snapshot.max_trusts,
        other_members = snapshot.other_members,
        queue_active = self:_queue_active(),
        state_ready = snapshot.logged_in
            and sources.spells and sources.recasts and sources.party and sources.key_items,
    }
end

local PRESET_VALIDATION_MESSAGES = {
    ambiguous = 'has an ambiguous catalog entry',
    catalog_unavailable = 'could not be resolved because the catalog is unavailable',
    cooldown = 'is on cooldown',
    duplicate_id = 'appears more than once',
    duplicate_identity = 'conflicts with another version of the same Trust',
    missing_identity = 'has no shared-identity metadata',
    not_learned = 'is not available to this character',
    state_unavailable = 'cannot be checked because Trust state is unavailable',
    unresolved = 'could not be found in the current Trust catalog',
}

function Handler:_preset_validation_failure(errors)
    self.emit('Preset could not be loaded:')
    for _, value in ipairs(errors or {}) do
        if value.reason == 'capacity_exceeded' then
            self.emit(('  Party requires %d Trust slots; %d are currently available.'):format(
                tonumber(value.requested) or 0, tonumber(value.capacity) or 0))
        elseif value.reason == 'queue_active' then
            self.emit('  Finish or cancel the current party change first.')
        elseif value.reason == 'too_many_members' then
            self.emit('  A preset cannot contain more than five Trusts.')
        elseif not value.name then
            self.emit('  ' .. (REASONS[value.reason]
                or ('Unable to continue: ' .. tostring(value.reason))))
        else
            self.emit(('  %s %s.'):format(
                value.name,
                PRESET_VALIDATION_MESSAGES[value.reason]
                    or ('failed validation (' .. tostring(value.reason) .. ')')))
        end
    end
end

function Handler:preset(args)
    if not self.preset_settings then
        self.emit('Preset settings are unavailable.')
        return
    end

    local action = lower(args[2])
    local slot = args[3]
    if action == '' then
        self.emit('Usage: //ts preset select|save|load|clear|list [1-5]')
        return
    end

    if action == 'list' then
        local ok, slots_or_reason = preset_engine.list(self.preset_settings)
        if not ok then
            self:_failure(slots_or_reason)
            return
        end
        for _, value in ipairs(slots_or_reason) do
            local label = value.selected and 'selected' or 'available'
            self.emit(('Preset %d [%s]: %s'):format(
                value.slot,
                label,
                value.occupied and names(value.members) or 'empty'))
        end
        return
    end

    if self:_queue_active() then
        self:_failure('busy')
        return
    end

    if action == 'select' then
        local ok, selected_or_reason = preset_engine.select(self.preset_settings, slot)
        if not ok then
            self:_failure(selected_or_reason)
            return
        end
        self:_persist_presets()
        self.emit(('Preset %d selected.'):format(selected_or_reason))
        return
    elseif action == 'save' then
        local ok, reason, saved_slot = preset_engine.save(
            self.preset_settings, self:_preset_context(), slot)
        if not ok then
            self:_failure(reason)
            return
        end
        self:_persist_presets()
        self.emit(('Preset %d saved: %s.'):format(
            saved_slot, names(self.preset_settings.slots[preset_engine.slot_key(saved_slot)])))
        return
    elseif action == 'clear' then
        local ok, reason, cleared_slot, previous = preset_engine.clear(
            self.preset_settings, slot)
        if not ok then
            self:_failure(reason)
            return
        end
        self:_persist_presets()
        self.emit(('Preset %d cleared%s.'):format(
            cleared_slot, previous == 0 and ' (already empty)' or ''))
        return
    elseif action == 'load' then
        local ok, plan_or_reason, errors = preset_engine.load_plan(
            self.preset_settings, self:_preset_context(), slot)
        if not ok then
            if plan_or_reason == 'validation_failed' then
                self:_preset_validation_failure(errors)
            else
                self:_failure(plan_or_reason)
            end
            return
        end

        local plan = plan_or_reason
        local staged, stage_reason, summons, dismissals = self.state:replace_plan(plan)
        if not staged then
            self:_failure(stage_reason)
            return
        end
        if not plan.has_changes and plan.order_mismatch then
            self.emit(('Preset %d contains the active Trusts, but their party order differs; '
                .. 'no summons or dismissals were selected.'):format(plan.slot))
        elseif not plan.has_changes then
            self.emit(('Preset %d already matches the active party; '
                .. 'no changes were selected.'):format(plan.slot))
        elseif plan.partial then
            local available = math.max(0, #plan.target - #plan.skipped)
            self.emit(('Preset %d partially loaded: %d of %d Trusts available; '
                .. '%d summon%s and %d dismissal%s selected.'):format(
                plan.slot, available, #plan.target,
                summons, summons == 1 and '' or 's',
                dismissals, dismissals == 1 and '' or 's'))
            for _, value in ipairs(plan.skipped) do
                self.emit(('  %s %s.'):format(
                    value.name or 'A preset Trust',
                    PRESET_VALIDATION_MESSAGES[value.reason]
                        or 'is currently unavailable'))
            end
        else
            self.emit(('Preset %d loaded: %d summon%s and %d dismissal%s selected.'):format(
                plan.slot,
                summons, summons == 1 and '' or 's',
                dismissals, dismissals == 1 and '' or 's'))
        end
        return
    end

    self.emit('Usage: //ts preset select|save|load|clear|list [1-5]')
end

function Handler:status()
    local snapshot = self.state:refresh()
    local stats = snapshot.stats
    self.emit(('Known %d | learned %d | ready %d | cooldown %d | cards %d'):format(
        stats.total,
        stats.learned,
        stats.ready,
        stats.cooldown,
        stats.cards
    ))
    self.emit(('Party %d | Trust limit %d | active %d | other members %d | summon %d | dismiss %d | open %d'):format(
        snapshot.party_count,
        snapshot.max_trusts,
        snapshot.active_trusts,
        snapshot.other_members,
        snapshot.pending,
        snapshot.pending_dismissals,
        snapshot.remaining_slots
    ))

    local active_names = {}
    for _, member in ipairs(self.state.party_trusts) do
        active_names[#active_names + 1] = member.trust and member.trust.en or member.name
    end
    self.emit('Active: ' .. (#active_names > 0 and table.concat(active_names, ' > ') or 'none'))

    local pending = self.state:pending_entries()
    self.emit('Pending: ' .. (#pending > 0 and names(pending) or 'none'))
    local dismissals = self.state:pending_dismissal_records()
    self.emit('Dismiss: ' .. (#dismissals > 0 and names(dismissals) or 'none'))

    if self.queue then
        local queue = self.queue:snapshot()
        self.emit(('Summon queue: %s%s'):format(
            queue.status,
            queue.current_name and (' (' .. queue.current_name .. ')') or ''
        ))
    end

    for _, removed in ipairs(snapshot.reconciled or {}) do
        self.emit(('Removed %s from pending state (%s).'):format(removed.name, removed.reason))
    end
end

function Handler:summon()
    if not self.queue then
        self.emit('The summon queue is unavailable.')
        return
    end
    local ok, reason = self.queue:start()
    if not ok then
        self:_failure(reason)
    end
end

function Handler:cancel()
    if not self.queue then
        self.emit('The summon queue is unavailable.')
        return
    end
    local ok, reason = self.queue:cancel('user_cancelled')
    if not ok then
        self:_failure(reason)
    end
end

function Handler:list(args)
    self.state:refresh()

    local filter = lower(args[2])
    local page = tonumber(args[3])
    if tonumber(args[2]) then
        page = tonumber(args[2])
        filter = 'ready'
    elseif filter == '' then
        filter = 'ready'
    end

    if not VALID_FILTERS[filter] then
        self.emit('Usage: //ts list [ready|cooldown|party|selected|all] [page]')
        return
    end

    page = math.max(1, math.floor(page or 1))
    local roster = self.state:roster(filter)
    local pages = math.max(1, math.ceil(#roster / PAGE_SIZE))
    page = math.min(page, pages)
    local first = (page - 1) * PAGE_SIZE + 1
    local last = math.min(#roster, first + PAGE_SIZE - 1)

    self.emit(('Trusts: %s (%d total, page %d/%d)'):format(filter, #roster, page, pages))
    if #roster == 0 then
        self.emit('No Trusts match this filter.')
        return
    end

    for index = first, last do
        local entry = roster[index]
        self.emit(('%3d. %s [%s]%s'):format(
            index,
            entry.en,
            entry_status(self.state, entry),
            entry.card and ' [card]' or ''
        ))
    end
end

function Handler:select(args)
    if self.queue and self.queue:snapshot().active then
        self:_failure('busy')
        return
    end
    local query = join(args, 2)
    local ok, reason, entry, matches = self.state:select(query)
    if not ok then
        self:_failure(reason, entry, matches)
        return
    end
    self.emit(('%s added at pending position %d.'):format(entry.en, #self.state.pending))
end

function Handler:remove(args)
    if self.queue and self.queue:snapshot().active then
        self:_failure('busy')
        return
    end
    local query = join(args, 2)
    local ok, reason, entry, matches = self.state:remove(query)
    if not ok then
        self:_failure(reason, entry, matches)
        return
    end
    self.emit(('%s removed from the pending party.'):format(entry.en))
end

function Handler:dismiss(args)
    if self.queue and self.queue:snapshot().active then
        self:_failure('busy')
        return
    end
    local query = join(args, 2)
    if lower(query) == 'all' then
        local added = self.state:stage_all_dismissals()
        self.emit(('Marked %d Trust%s for dismissal.'):format(added, added == 1 and '' or 's'))
        return
    end
    local ok, reason, record = self.state:stage_dismissal(query)
    if not ok then
        self:_failure(reason)
        return
    end
    self.emit(('%s marked for dismissal.'):format(record.trust and record.trust.en or record.name))
end

function Handler:keep(args)
    if self.queue and self.queue:snapshot().active then
        self:_failure('busy')
        return
    end
    local ok, reason, record = self.state:unstage_dismissal(join(args, 2))
    if not ok then
        self:_failure(reason)
        return
    end
    self.emit(('%s will remain in the party.'):format(record and record.trust and record.trust.en
        or record and record.name or 'Trust'))
end

function Handler:clear()
    if self.queue and self.queue:snapshot().active then
        self:_failure('busy')
        return
    end
    local summons, dismissals = self.state:clear()
    self.emit(('Cleared %d summon%s and %d dismissal%s.'):format(
        summons, summons == 1 and '' or 's',
        dismissals, dismissals == 1 and '' or 's'))
end

function Handler:diag()
    local snapshot = self.state:refresh()
    local sources = snapshot.sources
    self.emit(('Logged in: %s | sources: info=%s spells=%s recasts=%s party=%s key_items=%s'):format(
        tostring(snapshot.logged_in),
        tostring(sources.info),
        tostring(sources.spells),
        tostring(sources.recasts),
        tostring(sources.party),
        tostring(sources.key_items)
    ))
    self.emit(('Catalog: %d Trusts | %d card assets | %d unresolved party Trusts | %d unknown recasts'):format(
        self.state:catalog_size(),
        self.state:card_count(),
        self.state:unresolved_party_count(),
        snapshot.stats.unknown_recasts
    ))
    self.emit(('Capacity: limit=%d party=%d active=%d others=%d pending=%d remaining=%d'):format(
        snapshot.max_trusts,
        snapshot.party_count,
        snapshot.active_trusts,
        snapshot.other_members,
        snapshot.pending,
        snapshot.remaining_slots
    ))
end

function Handler:handle(args)
    local command = lower(args[1])
    if command == '' or command == 'toggle' then
        self.emit('The party-selection UI is unavailable in this environment.')
    elseif command == 'help' then
        self:help()
    elseif command == 'status' then
        self:status()
    elseif command == 'list' then
        self:list(args)
    elseif command == 'select' or command == 'add' then
        self:select(args)
    elseif command == 'remove' or command == 'unselect' then
        self:remove(args)
    elseif command == 'dismiss' then
        self:dismiss(args)
    elseif command == 'keep' or command == 'undismiss' then
        self:keep(args)
    elseif command == 'clear' then
        self:clear()
    elseif command == 'summon' then
        self:summon()
    elseif command == 'cancel' then
        self:cancel()
    elseif command == 'diag' then
        self:diag()
    elseif command == 'preset' or command == 'presets' then
        self:preset(args)
    else
        self.emit(('Unknown command "%s".'):format(command))
        self:help()
    end
end

return commands
