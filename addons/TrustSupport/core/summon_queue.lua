-- Sequential Trust summoning state machine.
--
-- This module owns orchestration only. Party, learned-spell, cooldown, and
-- capacity decisions remain in core/trust_state.lua, and all Windower-facing
-- operations are injected for deterministic tests.

local summon_queue = {}

local TRUST_FAILURE_MESSAGES = {
    [700] = 'trust_unavailable',
    [717] = 'zone_restricted',
}

-- These generic action messages are emitted when the client rejects a spell
-- before a normal cast action exists (most commonly because the player moved
-- during the short post-summon action lock). They are recoverable while this
-- queue is specifically waiting for its own Trust cast to begin.
local TRANSIENT_CAST_MESSAGES = {
    [17] = true,
    [18] = true,
}

local SKIPPABLE = {
    cooldown = true,
    in_party = true,
    not_learned = true,
}

local Queue = {}
Queue.__index = Queue

local function positive(value, fallback)
    value = tonumber(value)
    if not value or value <= 0 then
        return fallback
    end
    return value
end

local function action_contains_spell(action, spell_id)
    for _, target in ipairs(action.targets or {}) do
        for _, result in ipairs(target.actions or {}) do
            if tonumber(result.param) == spell_id then
                return true
            end
        end
    end
    return false
end

function summon_queue.new(state, options)
    assert(state, 'summon_queue.new requires Trust state')
    options = options or {}
    assert(type(options.input) == 'function', 'summon_queue.new requires input(command)')
    assert(type(options.schedule) == 'function', 'summon_queue.new requires schedule(callback, delay)')

    return setmetatable({
        state = state,
        input = options.input,
        schedule = options.schedule,
        emit = options.emit or function() end,
        trace = options.trace or function() end,
        clock = options.clock or os.clock,
        get_player_id = options.get_player_id or function() return nil end,
        get_player_position = options.get_player_position,
        get_language = options.get_language or function() return 'English' end,
        to_shift_jis = options.to_shift_jis or function(value) return value end,
        action_timeout = positive(options.action_timeout, 10),
        next_cast_delay = positive(options.next_cast_delay, 0.5),
        confirm_interval = positive(options.confirm_interval, 0.25),
        confirm_timeout = positive(options.confirm_timeout, 5),
        retry_delay = positive(options.retry_delay, 3),
        movement_retry_delay = positive(options.movement_retry_delay, 5),
        action_lock_retry_delay = positive(options.action_lock_retry_delay, 3),
        handoff_timeout = positive(options.handoff_timeout, 3),
        max_attempts = math.max(1, math.floor(tonumber(options.max_attempts) or 2)),
        max_action_lock_retries = math.max(0,
            math.floor(tonumber(options.max_action_lock_retries) or 2)),
        active = false,
        status = 'idle',
        reason = nil,
        run_id = 0,
        ids = {},
        position = 0,
        current = nil,
        attempt = 0,
        command_id = 0,
        confirm_elapsed = 0,
        recovering_missed_action = false,
        cast_origin = nil,
        retry_deadline = nil,
        retry_requires_stationary = false,
        retry_position = nil,
        action_deadline = nil,
        confirm_deadline = nil,
        handoff_deadline = nil,
        last_watchdog = nil,
        last_heartbeat = nil,
        block_cause = nil,
        action_lock_retries = 0,
        summoned = 0,
        skipped = {},
        last_trust_id = nil,
        last_trust_name = nil,
    }, Queue)
end

function Queue:_trace(event, detail)
    local current = self.current
    local position = self:_player_position()
    local fields = {
        ('run=%d'):format(tonumber(self.run_id) or 0),
        'active=' .. tostring(self.active),
        'status=' .. tostring(self.status),
        ('queue=%d/%d'):format(tonumber(self.position) or 0, #self.ids),
        'trust=' .. tostring(current and current.en or '-'),
        ('attempt=%d/%d'):format(tonumber(self.attempt) or 0, self.max_attempts),
        'reason=' .. tostring(self.reason or '-'),
        'block_cause=' .. tostring(self.block_cause or '-'),
    }
    if position then
        fields[#fields + 1] = ('xyz=%.3f,%.3f,%.3f'):format(
            position.x, position.y, position.z)
    end
    if detail and detail ~= '' then
        fields[#fields + 1] = tostring(detail)
    end
    pcall(self.trace, tostring(event), table.concat(fields, ' '))
end

function Queue:_player_position()
    if type(self.get_player_position) ~= 'function' then
        return nil
    end
    local ok, position = pcall(self.get_player_position)
    if not ok or type(position) ~= 'table' then
        return nil
    end
    local x = tonumber(position.x)
    local y = tonumber(position.y)
    local z = tonumber(position.z)
    if not x or not z then
        return nil
    end
    return {x=x, y=y or 0, z=z}
end

local function same_position(left, right)
    if not left or not right then
        return false
    end
    local dx = left.x - right.x
    local dy = left.y - right.y
    local dz = left.z - right.z
    -- Position values can drift slightly while an idle model settles. A small
    -- tolerance distinguishes that harmless jitter from deliberate movement.
    return dx * dx + dy * dy + dz * dz <= 0.0004
end

function Queue:_transient_block_cause()
    local position = self:_player_position()
    if self.cast_origin and position and not same_position(self.cast_origin, position) then
        return 'movement'
    end
    return 'action_lock'
end

function Queue:_advance_when_stationary(run_id, previous, stationary_elapsed)
    if not self.active or self.run_id ~= run_id
        or self.status ~= 'next_summon_wait' then
        return
    end

    local current = self:_player_position()
    if not current then
        self:_advance(run_id)
        return
    end

    if same_position(previous, current) then
        stationary_elapsed = stationary_elapsed + self.confirm_interval
    else
        stationary_elapsed = 0
    end

    if stationary_elapsed >= self.next_cast_delay
        or (self.handoff_deadline and self.clock() >= self.handoff_deadline) then
        self:_trace('handoff_complete',
            stationary_elapsed >= self.next_cast_delay and 'stationary=true'
                or 'deadline=true')
        self:_advance(run_id)
        return
    end

    self:_schedule(run_id, self.confirm_interval, function()
        self:_advance_when_stationary(run_id, current, stationary_elapsed)
    end)
end

function Queue:_schedule(run_id, delay, callback)
    self.schedule(function()
        if self.active and self.run_id == run_id then
            local ok, callback_error = pcall(callback)
            if not ok then
                self:fail_internal('scheduled_callback', callback_error)
            end
        end
    end, delay)
end

function Queue:fail_internal(source, internal_error)
    local detail = ('source=%s error=%s'):format(
        tostring(source or 'unknown'), tostring(internal_error or 'unknown'))
    self:_trace('internal_error', detail)
    if self.active then
        self:_stop('internal_error',
            'Summoning stopped because an internal queue step failed. See data/queue.log.')
    else
        self.emit('A Trust queue error was recorded in data/queue.log.')
    end
    return false
end

function Queue:_finish(status, reason, message)
    self:_trace('finish', ('next_status=%s next_reason=%s'):format(
        tostring(status), tostring(reason)))
    if self.current then
        self.last_trust_id = self.current.id
        self.last_trust_name = self.current.en
    end
    self.active = false
    self.status = status
    self.reason = reason
    self.current = nil
    self.attempt = 0
    self.recovering_missed_action = false
    self.cast_origin = nil
    self.retry_deadline = nil
    self.retry_requires_stationary = false
    self.retry_position = nil
    self.action_deadline = nil
    self.confirm_deadline = nil
    self.handoff_deadline = nil
    if message then
        self.emit(message)
    end
end

function Queue:_stop(reason, message)
    self:_finish('stopped', reason, message or ('Summoning stopped: ' .. tostring(reason)))
end

function Queue:_complete()
    self.state:refresh()
    self:_finish('complete', 'complete', ('Summoning complete: %d summoned, %d skipped.'):format(
        self.summoned,
        #self.skipped
    ))
end

function Queue:_skip(entry, reason)
    if entry then
        self.last_trust_id = entry.id
        self.last_trust_name = entry.en
    end
    table.insert(self.skipped, {
        id = entry and entry.id or nil,
        name = entry and entry.en or 'Unknown Trust',
        reason = reason,
    })
    self.emit(('%s skipped (%s).'):format(entry and entry.en or 'Unknown Trust', reason))
end

function Queue:_accept_joined_current(run_id, recovered_action)
    if not self.active or self.run_id ~= run_id or not self.current then
        return false
    end
    self:_trace('party_confirmed', 'recovered_action=' .. tostring(recovered_action == true))
    self.last_trust_id = self.current.id
    self.last_trust_name = self.current.en
    self.summoned = self.summoned + 1
    if recovered_action then
        self.emit(('%s joined the party; continuing after a missed cast result.'):format(
            self.current.en))
    else
        self.emit(('%s joined the party.'):format(self.current.en))
    end
    self.current = nil
    self.attempt = 0
    self.recovering_missed_action = false
    self.cast_origin = nil
    self.action_deadline = nil
    self.confirm_deadline = nil
    if self.position < #self.ids then
        -- Leave a short action-lock buffer after authoritative membership is
        -- visible. If position data is available, require the player to remain
        -- still for that buffer so movement cannot strand the next cast.
        self.status = 'next_summon_wait'
        self.handoff_deadline = self.clock() + self.handoff_timeout
        self:_trace('handoff_started', ('deadline=%.3f'):format(self.handoff_deadline))
        local position = self:_player_position()
        if position then
            self:_schedule(run_id, self.confirm_interval, function()
                self:_advance_when_stationary(run_id, position, 0)
            end)
        else
            self:_schedule(run_id, self.next_cast_delay, function()
                self:_advance(run_id)
            end)
        end
    else
        self:_advance(run_id)
    end
    return true
end

function Queue:_cast_name(entry)
    local language = tostring(self.get_language() or 'English'):lower()
    local name = language == 'japanese' and entry.ja or entry.en
    name = tostring(name or entry.en):gsub('"', '')
    return self.to_shift_jis(name)
end

function Queue:_observe_party_while_awaiting_action(run_id, attempt, command_id)
    if not self.active or self.run_id ~= run_id or not self.current
        or self.status ~= 'awaiting_action' or self.attempt ~= attempt
        or self.command_id ~= command_id then
        return
    end

    -- Party membership is independently authoritative. Observe it alongside
    -- the action event so a missed or late Windower action packet cannot hold
    -- an already-summoned Trust until the action timeout.
    self.state:refresh()
    if self.current.in_party then
        self:_accept_joined_current(run_id, false)
        return
    end

    -- A Trust cast cannot begin while the player is moving. Windower does not
    -- consistently emit the corresponding action-message event, so position
    -- change after issuing /ma is an authoritative local failure signal. This
    -- also ends attempt 2/2 immediately instead of leaving the UI busy until
    -- the generic action timeout expires.
    local position = self:_player_position()
    if self.cast_origin and position and not same_position(self.cast_origin, position) then
        self:_cast_temporarily_blocked(run_id, 'movement')
        return
    end

    self:_schedule(run_id, self.confirm_interval, function()
        self:_observe_party_while_awaiting_action(run_id, attempt, command_id)
    end)
end

function Queue:_cast_current(run_id)
    if not self.active or self.run_id ~= run_id or not self.current then
        return
    end

    self.state:refresh()
    local eligible, reason = self.state:summon_eligibility(self.current)
    if not eligible then
        if SKIPPABLE[reason] then
            self:_skip(self.current, reason)
            self:_advance(run_id)
        elseif reason == 'party_full' then
            self:_stop('party_full', 'Summoning stopped because the party has no remaining Trust slots.')
        else
            self:_stop(reason)
        end
        return
    end

    self.attempt = self.attempt + 1
    self.command_id = self.command_id + 1
    self.status = 'awaiting_action'
    self.reason = nil
    self.block_cause = nil
    self.recovering_missed_action = false
    self.cast_origin = self:_player_position()
    self.retry_deadline = nil
    self.action_deadline = self.clock() + self.action_timeout
    self.confirm_deadline = nil
    self.handoff_deadline = nil
    local attempt = self.attempt
    local command_id = self.command_id

    self.emit(('Summoning %s (%d/%d, attempt %d/%d).'):format(
        self.current.en,
        self.position,
        #self.ids,
        attempt,
        self.max_attempts
    ))
    self:_trace('cast_command', ('spell_id=%s deadline=%.3f'):format(
        tostring(self.current.id), self.action_deadline))

    local ok, input_error = pcall(function()
        local command = ('/ma "%s" <me>'):format(self:_cast_name(self.current))
        self.input(command)
    end)
    if not ok then
        self:_trace('cast_input_error', tostring(input_error))
        self:_stop('cast_input_failed', ('Unable to issue the Trust command: %s'):format(tostring(input_error)))
        return
    end

    self:_schedule(run_id, self.action_timeout, function()
        self:_begin_missed_action_recovery(run_id, attempt, command_id)
    end)
    self:_schedule(run_id, self.confirm_interval, function()
        self:_observe_party_while_awaiting_action(run_id, attempt, command_id)
    end)
end

function Queue:_advance(run_id)
    if not self.active or self.run_id ~= run_id then
        return
    end

    self.handoff_deadline = nil
    self.position = self.position + 1
    if self.position > #self.ids then
        self:_complete()
        return
    end

    self.current = self.state:entry_by_id(self.ids[self.position])
    self.attempt = 0
    self.action_lock_retries = 0
    self.status = 'validating'
    if not self.current then
        self:_skip(nil, 'not_found')
        self:_advance(run_id)
        return
    end
    self:_cast_current(run_id)
end

function Queue:_begin_missed_action_recovery(run_id, attempt, command_id)
    if not self.active or self.run_id ~= run_id or not self.current
        or self.status ~= 'awaiting_action' or self.attempt ~= attempt
        or (command_id ~= nil and self.command_id ~= command_id) then
        return false
    end

    self.state:refresh()
    if self.current.in_party then
        return self:_accept_joined_current(run_id, true)
    end

    -- Windower can occasionally miss the matching action event even though
    -- the Trust succeeds. Keep a short, independently watched party window.
    self.status = 'awaiting_party'
    self.reason = 'missed_action'
    self.confirm_elapsed = 0
    self.recovering_missed_action = true
    self.action_deadline = nil
    self.confirm_deadline = self.clock() + self.confirm_timeout
    self:_trace('missed_action_recovery', ('confirm_deadline=%.3f'):format(
        self.confirm_deadline))
    self:_confirm_party(run_id)
    return true
end

function Queue:_confirm_party(run_id)
    if not self.active or self.run_id ~= run_id or not self.current then
        return
    end

    self.state:refresh()
    if self.current.in_party then
        self:_accept_joined_current(run_id, self.recovering_missed_action)
        return
    end

    if self.confirm_elapsed >= self.confirm_timeout then
        if self.recovering_missed_action then
            self:_stop('action_timeout',
                ('The game did not begin summoning %s, and %s did not join your party. Try again.'):format(
                    self.current.en, self.current.en))
        else
            self:_stop('party_unconfirmed',
                'The Trust cast completed, but the party update could not be confirmed.')
        end
        return
    end

    self.confirm_elapsed = self.confirm_elapsed + self.confirm_interval
    self:_schedule(run_id, self.confirm_interval, function()
        self:_confirm_party(run_id)
    end)
end

function Queue:_cast_succeeded(run_id)
    self.status = 'awaiting_party'
    self.recovering_missed_action = false
    self.cast_origin = nil
    self.action_deadline = nil
    self.confirm_deadline = self.clock() + self.confirm_timeout
    self:_trace('cast_succeeded', ('confirm_deadline=%.3f'):format(
        self.confirm_deadline))
    self.confirm_elapsed = 0
    self:_schedule(run_id, self.confirm_interval, function()
        self:_confirm_party(run_id)
    end)
end

function Queue:_cast_interrupted(run_id)
    self.recovering_missed_action = false
    self.cast_origin = nil
    self.action_deadline = nil
    self.confirm_deadline = nil
    self:_trace('cast_interrupted')
    if self.attempt >= self.max_attempts then
        self:_stop('interrupted', ('%s was interrupted %d times.'):format(
            self.current.en,
            self.attempt
        ))
        return
    end

    self.status = 'retry_wait'
    self.retry_deadline = self.clock() + self.retry_delay
    self:_trace('retry_started', ('deadline=%.3f cause=interrupted'):format(
        self.retry_deadline))
    self.emit(('%s was interrupted; retrying in %.1f seconds.'):format(
        self.current.en,
        self.retry_delay
    ))
    local attempt = self.attempt
    self:_schedule(run_id, self.retry_delay, function()
        if self.status == 'retry_wait' and self.attempt == attempt then
            self:_cast_current(run_id)
        end
    end)
end

function Queue:_check_retry_wait(run_id, schedule_next)
    if not self.active or self.run_id ~= run_id
        or self.status ~= 'retry_wait' or not self.current then
        return false
    end

    local now = self.clock()
    if self.retry_requires_stationary then
        local position = self:_player_position()
        if position then
            if self.retry_position and not same_position(self.retry_position, position) then
                -- The retry settling window begins again whenever movement is
                -- observed. This prevents a fixed timer from issuing attempt
                -- two while the player is still moving or has only just
                -- stopped, which was the source of brief false final attempts.
                self.retry_deadline = now + self.movement_retry_delay
                self:_trace('retry_stationary_reset',
                    ('deadline=%.3f'):format(self.retry_deadline))
            end
            self.retry_position = position
        end
    end

    if self.retry_deadline and now >= self.retry_deadline then
        self:_trace('retry_ready', self.retry_requires_stationary
            and 'stationary=true' or 'delay=true')
        self.retry_requires_stationary = false
        self.retry_position = nil
        self:_cast_current(run_id)
        return true
    end

    if schedule_next then
        self:_schedule(run_id, self.confirm_interval, function()
            self:_check_retry_wait(run_id, true)
        end)
    end
    return false
end

function Queue:_cast_temporarily_blocked(run_id, cause)
    cause = cause == 'movement' and 'movement' or 'action_lock'
    self.block_cause = cause
    self.recovering_missed_action = false
    self.cast_origin = nil
    self.action_deadline = nil
    self.confirm_deadline = nil
    self:_trace('cast_blocked', 'cause=' .. cause)
    if cause == 'action_lock' then
        -- A command rejected immediately by the lingering client action lock
        -- never became a meaningful cast attempt. Give that rejection its own
        -- bounded allowance and restore the cast-attempt number.
        self.action_lock_retries = self.action_lock_retries + 1
        self.attempt = math.max(0, self.attempt - 1)
        if self.action_lock_retries > self.max_action_lock_retries then
            self:_stop('cast_temporarily_blocked',
                ('%s remained unavailable after %d action-lock retries. Try again in a moment.'):format(
                    self.current.en, self.max_action_lock_retries))
            return
        end
    elseif self.attempt >= self.max_attempts then
        local message = cause == 'movement'
            and ('%s could not be cast after %d attempts. Try again when stationary.'):format(
                self.current.en, self.attempt)
            or ('%s could not be cast after %d attempts. Try again in a moment.'):format(
                self.current.en, self.attempt)
        self:_stop('cast_temporarily_blocked', message)
        return
    end

    self.status = 'retry_wait'
    self.reason = 'cast_temporarily_blocked'
    local delay = cause == 'movement'
        and self.movement_retry_delay or self.action_lock_retry_delay
    self.retry_requires_stationary = cause == 'movement'
    self.retry_position = self.retry_requires_stationary
        and self:_player_position() or nil
    self.retry_deadline = self.clock() + delay
    self:_trace('retry_started', ('deadline=%.3f cause=blocked'):format(
        self.retry_deadline))
    local message = cause == 'movement'
        and ('%s could not be cast yet. Retrying in %.1f seconds; remain stationary when it begins.'):format(
            self.current.en, delay)
        or ('%s could not be cast yet. Waiting %.1f seconds for the previous summon to settle.'):format(
            self.current.en, delay)
    self.emit(message)
    self:_schedule(run_id, self.confirm_interval, function()
        self:_check_retry_wait(run_id, true)
    end)
end

function Queue:start()
    if self.active then
        return false, 'busy'
    end

    self.state:refresh()
    local pending = self.state:pending_entries()
    if #pending == 0 then
        return false, 'no_pending'
    end

    self.run_id = self.run_id + 1
    self.ids = {}
    for _, entry in ipairs(pending) do
        table.insert(self.ids, entry.id)
    end
    self.position = 0
    self.current = nil
    self.attempt = 0
    self.command_id = 0
    self.confirm_elapsed = 0
    self.recovering_missed_action = false
    self.cast_origin = nil
    self.retry_deadline = nil
    self.retry_requires_stationary = false
    self.retry_position = nil
    self.action_deadline = nil
    self.confirm_deadline = nil
    self.handoff_deadline = nil
    self.last_watchdog = nil
    self.last_heartbeat = nil
    self.block_cause = nil
    self.action_lock_retries = 0
    self.summoned = 0
    self.skipped = {}
    self.last_trust_id = nil
    self.last_trust_name = nil
    self.active = true
    self.status = 'validating'
    self.reason = nil
    local trace_ids = {}
    for index, id in ipairs(self.ids) do
        trace_ids[index] = tostring(id)
    end
    self:_trace('queue_started', 'ids=' .. table.concat(trace_ids, ','))

    local run_id = self.run_id
    self.emit(('Starting summon queue with %d Trust%s.'):format(
        #self.ids,
        #self.ids == 1 and '' or 's'
    ))
    self:_advance(run_id)
    return true, 'started'
end

function Queue:cancel(reason)
    if not self.active then
        return false, 'not_running'
    end

    self.run_id = self.run_id + 1
    self:_finish('cancelled', reason or 'cancelled', 'Summon queue cancelled; pending selections were preserved.')
    return true, 'cancelled'
end

function Queue:on_action(action)
    if not self.active or self.status ~= 'awaiting_action' or not self.current then
        return false
    end

    local player_id = tonumber(self.get_player_id())
    if player_id and tonumber(action.actor_id) ~= player_id then
        return false
    end

    self:_trace('action_event', ('category=%s param=%s actor=%s'):format(
        tostring(action.category), tostring(action.param), tostring(action.actor_id)))

    local spell_id = self.current.id
    if action.category == 4 and tonumber(action.param) == spell_id then
        self:_cast_succeeded(self.run_id)
        return true
    end

    if action.category == 8
        and tonumber(action.param) == 28787
        and action_contains_spell(action, spell_id) then
        self:_cast_interrupted(self.run_id)
        return true
    end
    return false
end

function Queue:on_action_message(actor_id, target_id, message_id)
    if not self.active then
        return false
    end

    local numeric_message_id = tonumber(message_id)
    self:_trace('action_message', ('id=%s actor=%s target=%s'):format(
        tostring(message_id), tostring(actor_id), tostring(target_id)))
    local reason = TRUST_FAILURE_MESSAGES[numeric_message_id]
    local transient = TRANSIENT_CAST_MESSAGES[numeric_message_id]
        and self.status == 'awaiting_action'
        and self.current ~= nil
    if not reason and not transient then
        return false
    end

    local player_id = tonumber(self.get_player_id())
    local actor = tonumber(actor_id)
    local target = tonumber(target_id)
    if player_id and actor ~= player_id and target ~= player_id
        and not ((actor or 0) == 0 and (target or 0) == 0) then
        return false
    end

    if transient then
        self:_cast_temporarily_blocked(self.run_id, self:_transient_block_cause())
        return true
    end

    local message = reason == 'zone_restricted'
        and 'Trusts cannot be summoned in this area.'
        or 'Trust magic cannot be used at this time.'
    self:_stop(reason, message)
    return true
end

function Queue:on_incoming_text(original, modified)
    local function is_transient_rejection(value)
        return type(value) == 'string'
            and value:lower():find('unable to cast spells at this time', 1, true) ~= nil
    end

    if not is_transient_rejection(original) and not is_transient_rejection(modified) then
        return false
    end

    self:_trace('rejection_text', 'matched=true')
    if not self.active or self.status ~= 'awaiting_action' or not self.current then
        return false
    end

    self:_cast_temporarily_blocked(self.run_id, self:_transient_block_cause())
    return true
end

function Queue:tick()
    if not self.active then
        return false
    end

    local now = self.clock()
    if self.last_watchdog and now - self.last_watchdog < self.confirm_interval then
        return false
    end
    self.last_watchdog = now
    local run_id = self.run_id

    local missing_deadline = (self.status == 'next_summon_wait' and not self.handoff_deadline)
        or (self.status == 'retry_wait' and not self.retry_deadline)
        or (self.status == 'awaiting_action' and not self.action_deadline)
        or (self.status == 'awaiting_party' and not self.confirm_deadline)
    if missing_deadline then
        self:fail_internal('watchdog_invariant',
            ('active status %s has no deadline'):format(tostring(self.status)))
        return true
    end

    if not self.last_heartbeat or now - self.last_heartbeat >= 2 then
        self.last_heartbeat = now
        local detail = ('now=%.3f retry=%s action=%s confirm=%s handoff=%s'):format(
            now,
            tostring(self.retry_deadline),
            tostring(self.action_deadline),
            tostring(self.confirm_deadline),
            tostring(self.handoff_deadline))
        self:_trace('heartbeat', detail)
    end

    if self.status == 'next_summon_wait' then
        if self.handoff_deadline and now >= self.handoff_deadline then
            self:_trace('watchdog_handoff_deadline')
            self:_advance(run_id)
            return true
        end
        return false
    end

    if self.status == 'retry_wait' then
        return self:_check_retry_wait(run_id, false)
    end

    if self.status == 'awaiting_action' and self.current then
        self.state:refresh()
        if self.current.in_party then
            self:_accept_joined_current(run_id, false)
            return true
        end
        local position = self:_player_position()
        if self.cast_origin and position and not same_position(self.cast_origin, position) then
            self:_cast_temporarily_blocked(run_id, 'movement')
            return true
        end
        if self.action_deadline and now >= self.action_deadline then
            self:_trace('watchdog_action_deadline')
            return self:_begin_missed_action_recovery(
                run_id, self.attempt, self.command_id)
        end
        return false
    end

    if self.status == 'awaiting_party' and self.current then
        self.state:refresh()
        if self.current.in_party then
            self:_accept_joined_current(run_id, self.recovering_missed_action)
            return true
        end
        if self.confirm_deadline and now >= self.confirm_deadline then
            self:_trace('watchdog_confirm_deadline')
            if self.recovering_missed_action then
                self:_stop('action_timeout',
                    ('The game did not begin summoning %s, and %s did not join your party. Try again.'):format(
                        self.current.en, self.current.en))
            else
                self:_stop('party_unconfirmed',
                    'The Trust cast completed, but the party update could not be confirmed.')
            end
            return true
        end
    end
    return false
end

function Queue:snapshot()
    local now = self.clock()
    local retry_remaining = nil
    if self.active and self.status == 'retry_wait' and self.retry_deadline then
        retry_remaining = math.max(0, self.retry_deadline - now)
    end
    return {
        run_id = self.run_id,
        active = self.active,
        status = self.status,
        reason = self.reason,
        position = self.position,
        total = #self.ids,
        current_id = self.current and self.current.id or nil,
        current_identity_key = self.current and self.current.identity_key or nil,
        current_name = self.current and self.current.en or nil,
        command_id = self.command_id,
        last_trust_id = self.last_trust_id,
        last_trust_name = self.last_trust_name,
        attempt = self.attempt,
        max_attempts = self.max_attempts,
        action_lock_retries = self.action_lock_retries,
        max_action_lock_retries = self.max_action_lock_retries,
        block_cause = self.block_cause,
        retry_remaining = retry_remaining,
        action_remaining = self.active and self.action_deadline
            and math.max(0, self.action_deadline - now) or nil,
        confirm_remaining = self.active and self.confirm_deadline
            and math.max(0, self.confirm_deadline - now) or nil,
        handoff_remaining = self.active and self.handoff_deadline
            and math.max(0, self.handoff_deadline - now) or nil,
        action_timeout = self.action_timeout,
        confirm_timeout = self.confirm_timeout,
        summoned = self.summoned,
        skipped = #self.skipped,
    }
end

return summon_queue
