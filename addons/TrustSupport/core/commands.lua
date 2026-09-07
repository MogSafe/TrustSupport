-- Chat-command adapter for the headless Trust state.

local commands = {}

local PAGE_SIZE = 18
local VALID_FILTERS = {
    all = true,
    cooldown = true,
    party = true,
    ready = true,
    selected = true,
}

local REASONS = {
    ambiguous = 'That name matches more than one Trust.',
    cooldown = 'That Trust is on cooldown.',
    empty = 'Provide a Trust name.',
    in_party = 'That Trust, or another version of that Trust, is already in the party.',
    no_trust_permit = 'No Trust permit was detected.',
    not_found = 'No matching Trust was found.',
    not_learned = 'That Trust is not available to this character.',
    not_logged_in = 'Trust state is unavailable while logged out.',
    not_selected = 'That Trust is not pending.',
    party_full = 'There are no remaining Trust party slots.',
    selected = 'That Trust is already pending.',
    state_unavailable = 'Windower has not provided a complete Trust state yet.',
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
            result[#result + 1] = entry.en or entry.name or tostring(entry.id)
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

function commands.new(state, emit)
    assert(state, 'commands.new requires Trust state')
    assert(type(emit) == 'function', 'commands.new requires an output function')
    return setmetatable({state = state, emit = emit}, Handler)
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
    self.emit('//ts - toggle the Trust Support window (UI pending)')
    self.emit('//ts status - party capacity, active Trusts, and pending Trusts')
    self.emit('//ts list [ready|cooldown|party|selected|all] [page]')
    self.emit('//ts select <name> - append a ready Trust to the pending order')
    self.emit('//ts remove <name> - remove a pending Trust')
    self.emit('//ts clear - clear all pending Trusts')
    self.emit('//ts diag - report underlying state-source health')
    self.emit('//ts icon on|off - show or hide the launcher icon')
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
    self.emit(('Party %d | Trust limit %d | active %d | other members %d | pending %d | open %d'):format(
        snapshot.party_count,
        snapshot.max_trusts,
        snapshot.active_trusts,
        snapshot.other_members,
        snapshot.pending,
        snapshot.remaining_slots
    ))

    local active_names = {}
    for _, member in ipairs(self.state.party_trusts) do
        active_names[#active_names + 1] = member.trust and member.trust.en or member.name
    end
    self.emit('Active: ' .. (#active_names > 0 and table.concat(active_names, ' > ') or 'none'))

    local pending = self.state:pending_entries()
    self.emit('Pending: ' .. (#pending > 0 and names(pending) or 'none'))

    for _, removed in ipairs(snapshot.reconciled or {}) do
        self.emit(('Removed %s from pending state (%s).'):format(removed.name, removed.reason))
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
    local query = join(args, 2)
    local ok, reason, entry, matches = self.state:select(query)
    if not ok then
        self:_failure(reason, entry, matches)
        return
    end
    self.emit(('%s added at pending position %d.'):format(entry.en, #self.state.pending))
end

function Handler:remove(args)
    local query = join(args, 2)
    local ok, reason, entry, matches = self.state:remove(query)
    if not ok then
        self:_failure(reason, entry, matches)
        return
    end
    self.emit(('%s removed from the pending party.'):format(entry.en))
end

function Handler:clear()
    local removed = self.state:clear()
    self.emit(('Cleared %d pending Trust%s.'):format(removed, removed == 1 and '' or 's'))
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
        self.emit('The party-selection UI is not implemented yet. Use //ts status for the state preview.')
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
    elseif command == 'clear' then
        self:clear()
    elseif command == 'diag' then
        self:diag()
    else
        self.emit(('Unknown command "%s".'):format(command))
        self:help()
    end
end

return commands
