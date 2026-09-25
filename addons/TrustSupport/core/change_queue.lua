-- Ordered party-change queue: confirmed dismissals first, then Trust summons.

local summon_queue = require('core/summon_queue')

local change_queue = {}
local Queue = {}
Queue.__index = Queue

local DISMISSAL_RECAST_GRACE = 5
local DEFAULT_DISMISSAL_HANDOFF_DELAY = 0.75

local function positive(value, fallback)
    value = tonumber(value)
    return value and value > 0 and value or fallback
end

function change_queue.new(state, options)
    assert(state, 'change_queue.new requires Trust state')
    options = options or {}
    assert(type(options.input) == 'function', 'change_queue.new requires input(command)')
    assert(type(options.schedule) == 'function', 'change_queue.new requires schedule(callback, delay)')

    return setmetatable({
        state = state,
        input = options.input,
        schedule = options.schedule,
        emit = options.emit or function() end,
        trace = options.trace or function() end,
        clock = options.clock or os.clock,
        summon = summon_queue.new(state, options),
        confirm_interval = positive(options.confirm_interval, 0.25),
        confirm_timeout = positive(options.confirm_timeout, 5),
        dismissal_handoff_delay = positive(options.dismissal_handoff_delay,
            DEFAULT_DISMISSAL_HANDOFF_DELAY),
        active = false,
        run_id = 0,
        status = 'idle',
        reason = nil,
        last_phase = nil,
        dismissals = {},
        summon_total = 0,
        position = 0,
        current = nil,
        confirm_elapsed = 0,
        confirm_deadline = nil,
        dismissal_handoff_deadline = nil,
        last_watchdog = nil,
        last_heartbeat = nil,
        dismissed = 0,
        recent_dismissals = {},
        delegating = false,
    }, Queue)
end

function Queue:_schedule(run_id, delay, callback)
    self.schedule(function()
        if self.active and self.run_id == run_id then
            local ok, callback_error = pcall(callback)
            if not ok then
                self:fail_internal('dismissal_callback', callback_error)
            end
        end
    end, delay)
end

function Queue:_trace(event, detail)
    pcall(self.trace, 'change_' .. tostring(event), table.concat({
        ('run=%d'):format(tonumber(self.run_id) or 0),
        'active=' .. tostring(self.active),
        'status=' .. tostring(self.status),
        ('queue=%d/%d'):format(tonumber(self.position) or 0, #self.dismissals),
        'trust=' .. tostring(self.current and self.current.display_name or '-'),
        'reason=' .. tostring(self.reason or '-'),
        tostring(detail or ''),
    }, ' '))
end

function Queue:fail_internal(source, internal_error)
    if self.delegating or self.summon:snapshot().active then
        return self.summon:fail_internal(source, internal_error)
    end
    self:_trace('internal_error', ('source=%s error=%s'):format(
        tostring(source or 'unknown'), tostring(internal_error or 'unknown')))
    if self.active then
        self:_finish('stopped', 'internal_error',
            'Party changes stopped because an internal queue step failed. See data/queue.log.')
    else
        self.emit('A Trust queue error was recorded in data/queue.log.')
    end
    return false
end

function Queue:_finish(status, reason, message)
    self.active = false
    self.delegating = false
    self.status = status
    self.reason = reason
    self.current = nil
    self.confirm_deadline = nil
    self.dismissal_handoff_deadline = nil
    if message then
        self.emit(message)
    end
end

function Queue:_mark_recent_dismissal(record)
    local id = record and tonumber(record.id)
    if id then
        self.recent_dismissals[id] = self.clock() + DISMISSAL_RECAST_GRACE
    end
end

function Queue:_recent_dismissed_ids()
    local now = self.clock()
    local ids = {}
    for id, expires_at in pairs(self.recent_dismissals) do
        if expires_at > now then
            ids[#ids + 1] = id
        else
            self.recent_dismissals[id] = nil
        end
    end
    table.sort(ids)
    return ids
end

function Queue:_dismiss_name(record)
    local name = record.name
        or (record.trust and record.trust.party_name)
        or (record.trust and record.trust.en)
        or 'Unknown Trust'
    return tostring(name):gsub('"', '')
end

function Queue:_confirm_dismissal(run_id, expected_position)
    if not self.active or self.run_id ~= run_id or not self.current
        or (expected_position and self.position ~= expected_position) then
        return
    end

    self.state:refresh()
    if not self.state.active_identities[self.current.identity_key] then
        self:_trace('dismissal_confirmed')
        self.dismissed = self.dismissed + 1
        self:_mark_recent_dismissal(self.current)
        self:_advance_dismissal(run_id)
        return
    end

    if (self.confirm_deadline and self.clock() >= self.confirm_deadline)
        or self.confirm_elapsed >= self.confirm_timeout then
        self:_trace('dismissal_deadline')
        self:_finish('stopped', 'dismissal_unconfirmed',
            ([=[%s's dismissal was unsuccessful. Try again.]=]):format(
                self.current.display_name))
        return
    end

    self.confirm_elapsed = self.confirm_elapsed + self.confirm_interval
    local position = self.position
    self:_schedule(run_id, self.confirm_interval, function()
        self:_confirm_dismissal(run_id, position)
    end)
end

function Queue:_issue_dismissal(run_id)
    self.status = 'awaiting_dismissal'
    self.dismissal_handoff_deadline = nil
    self.confirm_elapsed = 0
    self.confirm_deadline = self.clock() + self.confirm_timeout
    self.last_watchdog = nil
    self:_trace('dismissal_command')

    local ok, input_error = pcall(function()
        self.input(('/refa "%s"'):format(self.current.command_name))
    end)
    if not ok then
        self:_finish('stopped', 'dismiss_input_failed',
            ('Unable to issue the dismissal command: %s'):format(tostring(input_error)))
        return
    end

    local position = self.position
    self:_schedule(run_id, self.confirm_interval, function()
        self:_confirm_dismissal(run_id, position)
    end)
end

function Queue:_start_summons()
    self.active = false
    self.current = nil
    self.confirm_deadline = nil
    self.last_phase = 'summoning'
    if #self.state:pending_entries() == 0 then
        self:_finish('complete', 'complete')
        return
    end

    self.status = 'starting_summons'
    self.delegating = true
    local ok, reason = self.summon:start(false)
    if not ok then
        self:_finish('stopped', reason, 'Dismissals completed, but the summon queue could not start.')
    end
end

function Queue:_advance_dismissal(run_id)
    if not self.active or self.run_id ~= run_id then
        return
    end
    self.position = self.position + 1
    if self.position > #self.dismissals then
        self:_start_summons()
        return
    end

    if self.position > 1 then
        local position = self.position
        self.status = 'next_dismissal_wait'
        self.current = nil
        self.confirm_deadline = nil
        self.dismissal_handoff_deadline = self.clock()
            + self.dismissal_handoff_delay
        self:_trace('dismissal_handoff_started', ('delay=%.2f'):format(
            self.dismissal_handoff_delay))
        self:_schedule(run_id, self.dismissal_handoff_delay, function()
            if self.status ~= 'next_dismissal_wait'
                or self.position ~= position then
                return
            end
            self.dismissal_handoff_deadline = nil
            self.current = self.dismissals[position]
            self:_trace('dismissal_handoff_complete')
            self:_issue_dismissal(run_id)
        end)
        return
    end
    self.current = self.dismissals[self.position]
    self:_issue_dismissal(run_id)
end

function Queue:start()
    if self.active or self.summon:snapshot().active then
        return false, 'busy'
    end

    self.state:refresh()
    local dismissal_records = self.state:pending_dismissal_records()
    local pending = self.state:pending_entries()
    if #dismissal_records == 0 and #pending == 0 then
        return false, 'no_pending'
    end
    if #dismissal_records == 0 then
        self.dismissals = {}
        self.dismissed = 0
        self.summon_total = #pending
        self.delegating = true
        return self.summon:start()
    end

    self.run_id = self.run_id + 1
    self.dismissals = {}
    self.summon_total = #pending
    for _, record in ipairs(dismissal_records) do
        self.dismissals[#self.dismissals + 1] = {
            id = record.id or (record.trust and record.trust.id),
            identity_key = record.identity_key,
            command_name = self:_dismiss_name(record),
            display_name = record.trust and record.trust.en or record.name,
        }
    end
    self.position = 0
    self.current = nil
    self.dismissal_handoff_deadline = nil
    self.dismissed = 0
    self.delegating = false
    self.reason = nil
    self.status = 'validating_dismissals'
    self.last_phase = 'dismissing'
    self.active = true
    self:_trace('queue_started', ('summons=%d'):format(#pending))
    local dismissal_count = #self.dismissals
    local summon_count = #pending
    local dismissal_label = ('%d dismissal%s'):format(
        dismissal_count, dismissal_count == 1 and '' or 's')
    local summon_label = ('%d summon%s'):format(
        summon_count, summon_count == 1 and '' or 's')
    self.emit(('Applying party changes: %s%s.'):format(
        dismissal_label, summon_count > 0 and (', ' .. summon_label) or ''))
    self:_advance_dismissal(self.run_id)
    return true, 'started'
end

function Queue:cancel(reason)
    if self.active then
        self.run_id = self.run_id + 1
        self:_finish('cancelled', reason or 'cancelled',
            'Party changes cancelled.')
        return true, 'cancelled'
    end
    return self.summon:cancel(reason)
end

function Queue:on_action(action)
    return self.summon:on_action(action)
end

function Queue:on_action_message(actor_id, target_id, message_id)
    return self.summon:on_action_message(actor_id, target_id, message_id)
end

function Queue:on_incoming_text(original, modified)
    return self.summon:on_incoming_text(original, modified)
end

function Queue:tick()
    if not self.active then
        return self.summon:tick()
    end

    local now = self.clock()
    if self.last_watchdog and now - self.last_watchdog < self.confirm_interval then
        return false
    end
    self.last_watchdog = now

    if self.status == 'next_dismissal_wait' then
        if not self.dismissal_handoff_deadline then
            self:fail_internal('dismissal_handoff_watchdog_invariant',
                'active handoff has no deadline')
            return true
        end
        if now >= self.dismissal_handoff_deadline then
            self.dismissal_handoff_deadline = nil
            self.current = self.dismissals[self.position]
            if not self.current then
                self:fail_internal('dismissal_handoff_watchdog_invariant',
                    'active handoff has no queued dismissal')
                return true
            end
            self:_trace('watchdog_dismissal_handoff_complete')
            self:_issue_dismissal(self.run_id)
            return true
        end
        return false
    end

    if self.status ~= 'awaiting_dismissal'
        or not self.current or not self.confirm_deadline then
        self:fail_internal('dismissal_watchdog_invariant',
            ('active status %s has incomplete confirmation state'):format(
                tostring(self.status)))
        return true
    end

    if not self.last_heartbeat or now - self.last_heartbeat >= 2 then
        self.last_heartbeat = now
        self:_trace('heartbeat', ('now=%.3f confirm=%s'):format(
            now, tostring(self.confirm_deadline)))
    end

    self.state:refresh()
    if not self.state.active_identities[self.current.identity_key] then
        self:_trace('watchdog_dismissal_confirmed')
        self.dismissed = self.dismissed + 1
        self:_mark_recent_dismissal(self.current)
        self:_advance_dismissal(self.run_id)
        return true
    end

    if now >= self.confirm_deadline then
        self:_trace('watchdog_dismissal_deadline')
        self:_finish('stopped', 'dismissal_unconfirmed',
            ([=[%s's dismissal was unsuccessful. Try again.]=]):format(
                self.current.display_name))
        return true
    end
    return false
end

function Queue:snapshot()
    if not self.active and self.delegating then
        local snapshot = self.summon:snapshot()
        snapshot.phase = 'summoning'
        snapshot.dismissed = self.dismissed
        snapshot.dismiss_total = #self.dismissals
        snapshot.summon_total = self.summon_total
        snapshot.recent_dismissed_ids = self:_recent_dismissed_ids()
        return snapshot
    end
    return {
        active = self.active,
        phase = self.active and 'dismissing'
            or (self.status == 'stopped' and self.last_phase or nil),
        status = self.status,
        reason = self.reason,
        position = self.position,
        total = #self.dismissals,
        current_id = self.current and self.current.id or nil,
        current_identity_key = self.current and self.current.identity_key or nil,
        current_name = self.current and self.current.display_name or nil,
        dismissed = self.dismissed,
        dismiss_total = #self.dismissals,
        summon_total = self.summon_total,
        summoned = 0,
        skipped = 0,
        recent_dismissed_ids = self:_recent_dismissed_ids(),
        confirm_remaining = self.active and self.confirm_deadline
            and math.max(0, self.confirm_deadline - self.clock()) or nil,
        handoff_remaining = self.active and self.dismissal_handoff_deadline
            and math.max(0, self.dismissal_handoff_deadline - self.clock()) or nil,
    }
end

return change_queue
