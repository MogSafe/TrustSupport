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
        get_player_id = options.get_player_id or function() return nil end,
        get_language = options.get_language or function() return 'English' end,
        to_shift_jis = options.to_shift_jis or function(value) return value end,
        action_timeout = positive(options.action_timeout, 10),
        settle_delay = positive(options.settle_delay, 3),
        confirm_interval = positive(options.confirm_interval, 0.25),
        confirm_timeout = positive(options.confirm_timeout, 5),
        retry_delay = positive(options.retry_delay, 3),
        max_attempts = math.max(1, math.floor(tonumber(options.max_attempts) or 2)),
        active = false,
        status = 'idle',
        reason = nil,
        run_id = 0,
        ids = {},
        position = 0,
        current = nil,
        attempt = 0,
        confirm_elapsed = 0,
        summoned = 0,
        skipped = {},
        last_trust_id = nil,
        last_trust_name = nil,
    }, Queue)
end

function Queue:_schedule(run_id, delay, callback)
    self.schedule(function()
        if self.active and self.run_id == run_id then
            callback()
        end
    end, delay)
end

function Queue:_finish(status, reason, message)
    if self.current then
        self.last_trust_id = self.current.id
        self.last_trust_name = self.current.en
    end
    self.active = false
    self.status = status
    self.reason = reason
    self.current = nil
    self.attempt = 0
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

function Queue:_cast_name(entry)
    local language = tostring(self.get_language() or 'English'):lower()
    local name = language == 'japanese' and entry.ja or entry.en
    name = tostring(name or entry.en):gsub('"', '')
    return self.to_shift_jis(name)
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
    self.status = 'awaiting_action'
    self.reason = nil
    local attempt = self.attempt

    self.emit(('Summoning %s (%d/%d, attempt %d/%d).'):format(
        self.current.en,
        self.position,
        #self.ids,
        attempt,
        self.max_attempts
    ))

    local ok, input_error = pcall(function()
        local command = ('/ma "%s" <me>'):format(self:_cast_name(self.current))
        self.input(command)
    end)
    if not ok then
        self:_stop('cast_input_failed', ('Unable to issue the Trust command: %s'):format(tostring(input_error)))
        return
    end

    self:_schedule(run_id, self.action_timeout, function()
        if self.status == 'awaiting_action' and self.attempt == attempt then
            self:_stop('action_timeout', ('No cast result was received for %s.'):format(self.current.en))
        end
    end)
end

function Queue:_advance(run_id)
    if not self.active or self.run_id ~= run_id then
        return
    end

    self.position = self.position + 1
    if self.position > #self.ids then
        self:_complete()
        return
    end

    self.current = self.state:entry_by_id(self.ids[self.position])
    self.attempt = 0
    self.status = 'validating'
    if not self.current then
        self:_skip(nil, 'not_found')
        self:_advance(run_id)
        return
    end
    self:_cast_current(run_id)
end

function Queue:_confirm_party(run_id)
    if not self.active or self.run_id ~= run_id or not self.current then
        return
    end

    self.state:refresh()
    if self.current.in_party then
        self.last_trust_id = self.current.id
        self.last_trust_name = self.current.en
        self.summoned = self.summoned + 1
        self.emit(('%s joined the party.'):format(self.current.en))
        self.current = nil
        self.attempt = 0
        self:_advance(run_id)
        return
    end

    if self.confirm_elapsed >= self.confirm_timeout then
        self:_stop('party_unconfirmed', 'The Trust cast completed, but the party update could not be confirmed.')
        return
    end

    self.confirm_elapsed = self.confirm_elapsed + self.confirm_interval
    self:_schedule(run_id, self.confirm_interval, function()
        self:_confirm_party(run_id)
    end)
end

function Queue:_cast_succeeded(run_id)
    self.status = 'awaiting_party'
    self.confirm_elapsed = self.settle_delay
    self:_schedule(run_id, self.settle_delay, function()
        self:_confirm_party(run_id)
    end)
end

function Queue:_cast_interrupted(run_id)
    if self.attempt >= self.max_attempts then
        self:_stop('interrupted', ('%s was interrupted %d times.'):format(
            self.current.en,
            self.attempt
        ))
        return
    end

    self.status = 'retry_wait'
    self.emit(('%s was interrupted; retrying in %.1f seconds.'):format(
        self.current.en,
        self.retry_delay
    ))
    self:_schedule(run_id, self.retry_delay, function()
        self:_cast_current(run_id)
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
    self.confirm_elapsed = 0
    self.summoned = 0
    self.skipped = {}
    self.last_trust_id = nil
    self.last_trust_name = nil
    self.active = true
    self.status = 'validating'
    self.reason = nil

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

    local reason = TRUST_FAILURE_MESSAGES[tonumber(message_id)]
    if not reason then
        return false
    end

    local player_id = tonumber(self.get_player_id())
    local actor = tonumber(actor_id)
    local target = tonumber(target_id)
    if player_id and actor ~= player_id and target ~= player_id
        and not ((actor or 0) == 0 and (target or 0) == 0) then
        return false
    end

    local message = reason == 'zone_restricted'
        and 'Trusts cannot be summoned in this area.'
        or 'Trust magic cannot be used at this time.'
    self:_stop(reason, message)
    return true
end

function Queue:snapshot()
    return {
        active = self.active,
        status = self.status,
        reason = self.reason,
        position = self.position,
        total = #self.ids,
        current_id = self.current and self.current.id or nil,
        current_name = self.current and self.current.en or nil,
        last_trust_id = self.last_trust_id,
        last_trust_name = self.last_trust_name,
        attempt = self.attempt,
        max_attempts = self.max_attempts,
        summoned = self.summoned,
        skipped = #self.skipped,
    }
end

return summon_queue
