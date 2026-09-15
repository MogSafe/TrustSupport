package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local trust_state = require('core/trust_state')
local summon_queue = require('core/summon_queue')
local commands = require('core/commands')

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

local Scheduler = {}
Scheduler.__index = Scheduler

function Scheduler.new()
    return setmetatable({now=0, tasks={}}, Scheduler)
end

function Scheduler:schedule(callback, delay)
    table.insert(self.tasks, {at=self.now + delay, callback=callback})
end

function Scheduler:run_next()
    if #self.tasks == 0 then
        return false
    end
    local next_index = 1
    for index = 2, #self.tasks do
        if self.tasks[index].at < self.tasks[next_index].at then
            next_index = index
        end
    end
    local task = table.remove(self.tasks, next_index)
    self.now = task.at
    task.callback()
    return true
end

local spells = {
    [909] = {id=909, en='Mihli Aliapoh', ja='Mihli JP', model=3013, party_name='MihliAliapoh', recast_id=909, type='Trust'},
    [951] = {id=951, en='Rahal', ja='Rahal JP', model=3056, party_name='Rahal', recast_id=951, type='Trust'},
}

local function fixture()
    local runtime = {
        info = {logged_in=true, language='English'},
        learned = {[909]=true, [951]=true},
        recasts = {[909]=0, [951]=0},
        party = {p0={name='Player', mob={spawn_type=0}}, party1_count=1},
        key_items = {2886},
        player_id = 100,
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

    local scheduler = Scheduler.new()
    local inputs = {}
    local output = {}
    local queue = summon_queue.new(state, {
        input = function(command) inputs[#inputs + 1] = command end,
        schedule = function(callback, delay) scheduler:schedule(callback, delay) end,
        emit = function(line) output[#output + 1] = line end,
        clock = function() return scheduler.now end,
        get_player_id = function() return runtime.player_id end,
        get_language = function() return runtime.info.language end,
        to_shift_jis = function(value) return value end,
        action_timeout = 2,
        next_cast_delay = 0.1,
        confirm_interval = 0.1,
        confirm_timeout = 0.5,
        retry_delay = 0.1,
        movement_retry_delay = 0.1,
        action_lock_retry_delay = 0.1,
        max_action_lock_retries = 2,
        max_attempts = 2,
    })
    return state, runtime, queue, scheduler, inputs, output
end

local function success_action(id, actor_id)
    return {category=4, param=id, actor_id=actor_id}
end

local function interruption_action(id, actor_id)
    return {
        category=8,
        param=28787,
        actor_id=actor_id,
        targets={{actions={{param=id}}}},
    }
end

test('summons pending Trusts sequentially and confirms party membership', function()
    local state, runtime, queue, scheduler, inputs = fixture()
    expect(state:select('Mihli Aliapoh'))
    expect(state:select('Rahal'))
    expect(queue:start())
    equal(inputs[1], '/ma "Mihli Aliapoh" <me>')
    equal(queue:snapshot().current_name, 'Mihli Aliapoh')

    expect(not queue:on_action(success_action(909, 999)), 'another actor must be ignored')
    expect(queue:on_action(success_action(909, runtime.player_id)))
    runtime.party = {
        p0={name='Player', mob={spawn_type=0}},
        p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        party1_count=2,
    }
    while queue:snapshot().status == 'awaiting_party' do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().status, 'next_summon_wait')
    expect(scheduler:run_next())
    equal(inputs[2], '/ma "Rahal" <me>')

    expect(queue:on_action(success_action(951, runtime.player_id)))
    runtime.party.p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}}
    runtime.party.party1_count = 3
    while queue:snapshot().active do
        expect(scheduler:run_next())
    end

    local snapshot = queue:snapshot()
    equal(snapshot.status, 'complete')
    equal(snapshot.summoned, 2)
    equal(#state:pending_entries(), 0)
end)

test('retries one interruption and then stops without clearing pending', function()
    local state, runtime, queue, scheduler, inputs = fixture()
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(queue:on_action(interruption_action(951, runtime.player_id)))
    equal(queue:snapshot().status, 'retry_wait')
    while #inputs < 2 do
        expect(scheduler:run_next())
    end
    equal(#inputs, 2)

    expect(queue:on_action(interruption_action(951, runtime.player_id)))
    equal(queue:snapshot().status, 'stopped')
    equal(queue:snapshot().reason, 'interrupted')
    equal(#state:pending_entries(), 1)
end)

test('retries a Trust cast rejected during movement and continues the queue', function()
    local state, runtime, queue, scheduler, inputs, output = fixture()
    expect(state:select('Mihli Aliapoh'))
    expect(state:select('Rahal'))
    expect(queue:start())

    expect(queue:on_action(success_action(909, runtime.player_id)))
    runtime.party = {
        p0={name='Player', mob={spawn_type=0}},
        p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        party1_count=2,
    }
    while #inputs < 2 do
        expect(scheduler:run_next())
    end
    equal(inputs[2], '/ma "Rahal" <me>')
    expect(not queue:on_action_message(999, 999, 17),
        'another actor\'s generic spell rejection must be ignored')
    expect(queue:on_action_message(runtime.player_id, runtime.player_id, 17))
    equal(queue:snapshot().status, 'retry_wait')
    equal(queue:snapshot().reason, 'cast_temporarily_blocked')
    equal(queue:snapshot().block_cause, 'action_lock')
    expect(math.abs(queue:snapshot().retry_remaining - 0.1) < 0.000001,
        'retry countdown must expose the configured remaining delay')
    expect(table.concat(output, '|'):find('previous summon to settle', 1, true) ~= nil)

    while #inputs < 3 do
        expect(scheduler:run_next())
    end
    equal(inputs[3], '/ma "Rahal" <me>')
    expect(queue:on_action(success_action(951, runtime.player_id)))
    runtime.party.p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}}
    runtime.party.party1_count = 3
    while queue:snapshot().active do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().status, 'complete')
    equal(queue:snapshot().summoned, 2)
end)

test('uses visible rejection text when no structured action message arrives', function()
    local state, _, queue, scheduler, inputs = fixture()
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(not queue:on_incoming_text('Some unrelated message.', 'Some unrelated message.'))
    expect(queue:on_incoming_text(
        'Unable to cast spells at this time.',
        'Unable to cast spells at this time.'))
    equal(queue:snapshot().status, 'retry_wait')
    while #inputs < 2 do
        expect(scheduler:run_next())
    end
    equal(inputs[2], '/ma "Rahal" <me>')
end)

test('waits for the player to stop moving before casting the next Trust', function()
    local state, runtime, queue, scheduler, inputs = fixture()
    local position = {x=0, y=0, z=0}
    queue.get_player_position = function()
        return position
    end
    expect(state:select('Mihli Aliapoh'))
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(queue:on_action(success_action(909, runtime.player_id)))
    runtime.party = {
        p0={name='Player', mob={spawn_type=0}},
        p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        party1_count=2,
    }

    while queue:snapshot().status == 'awaiting_party' do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().status, 'next_summon_wait')
    for step = 1, 8 do
        position = {x=step, y=0, z=0}
        expect(scheduler:run_next())
        equal(#inputs, 1, 'movement must defer the next Trust command')
    end
    while #inputs < 2 do
        expect(scheduler:run_next())
    end
    equal(inputs[2], '/ma "Rahal" <me>')
end)

test('stops attempt two immediately when movement invalidates the cast', function()
    local state, runtime, queue, scheduler, inputs = fixture()
    local position = {x=0, y=0, z=0}
    queue.get_player_position = function()
        return position
    end
    expect(state:select('Rahal'))
    expect(queue:start())

    position = {x=1, y=0, z=0}
    expect(scheduler:run_next())
    equal(queue:snapshot().status, 'retry_wait')
    equal(queue:snapshot().block_cause, 'movement')
    expect(scheduler.now < 2, 'movement must be detected before the action timeout')

    while #inputs < 2 do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().attempt, 2)
    position = {x=2, y=0, z=0}
    while queue:snapshot().active do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().status, 'stopped')
    equal(queue:snapshot().reason, 'cast_temporarily_blocked')
    expect(scheduler.now < 2, 'attempt two must stop before the action timeout')
    equal(#state:pending_entries(), 1)
end)

test('wall-clock watchdog recovers when scheduled retry and timeout callbacks are lost', function()
    local state, _, queue, scheduler, inputs = fixture()
    queue.schedule = function() end
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(queue:on_incoming_text('Unable to cast spells at this time.'))
    equal(queue:snapshot().status, 'retry_wait')

    scheduler.now = scheduler.now + 0.11
    expect(queue:tick())
    equal(#inputs, 2)
    equal(queue:snapshot().status, 'awaiting_action')

    scheduler.now = scheduler.now + 2.01
    expect(queue:tick())
    equal(queue:snapshot().status, 'awaiting_party')
    scheduler.now = scheduler.now + 0.51
    expect(queue:tick())
    equal(queue:snapshot().status, 'stopped')
    equal(queue:snapshot().reason, 'action_timeout')
end)

test('stationary handoff has a bounded maximum wait', function()
    local state, runtime, queue, scheduler, inputs = fixture()
    local position = {x=0, y=0, z=0}
    queue.get_player_position = function() return position end
    queue.handoff_timeout = 0.3
    expect(state:select('Mihli Aliapoh'))
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(queue:on_action(success_action(909, runtime.player_id)))
    runtime.party = {
        p0={name='Player', mob={spawn_type=0}},
        p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        party1_count=2,
    }
    while queue:snapshot().status == 'awaiting_party' do
        expect(scheduler:run_next())
    end
    for step = 1, 4 do
        position = {x=step, y=0, z=0}
        scheduler.now = scheduler.now + 0.1
        queue:tick()
    end
    equal(#inputs, 2, 'handoff watchdog must not wait indefinitely for exact coordinates')
end)

test('bounds repeated action-lock rejection and preserves the remaining Trust', function()
    local state, runtime, queue, scheduler, inputs = fixture()
    expect(state:select('Rahal'))
    expect(queue:start())
    for expected_retry = 1, 2 do
        expect(queue:on_action_message(runtime.player_id, runtime.player_id, 18))
        equal(queue:snapshot().status, 'retry_wait')
        equal(queue:snapshot().action_lock_retries, expected_retry)
        local expected_inputs = expected_retry + 1
        while #inputs < expected_inputs do
            expect(scheduler:run_next())
        end
    end
    expect(queue:on_action_message(runtime.player_id, runtime.player_id, 18))
    equal(queue:snapshot().status, 'stopped')
    equal(queue:snapshot().reason, 'cast_temporarily_blocked')
    equal(#state:pending_entries(), 1)
end)

test('movement retry waits for settling and action lock does not consume attempt two', function()
    local state, runtime, queue, scheduler, inputs = fixture()
    local position = {x=0, y=0, z=0}
    queue.get_player_position = function() return position end
    queue.movement_retry_delay = 0.5
    queue.action_lock_retry_delay = 0.2
    expect(state:select('Rahal'))
    expect(queue:start())

    position = {x=1, y=0, z=0}
    expect(scheduler:run_next())
    equal(queue:snapshot().status, 'retry_wait')
    equal(queue:snapshot().attempt, 1)

    -- Continuing movement repeatedly resets the full settling window.
    for step = 2, 5 do
        position = {x=step, y=0, z=0}
        expect(scheduler:run_next())
        equal(#inputs, 1, 'movement must not allow attempt two to begin')
        expect(queue:snapshot().retry_remaining >= 0.49,
            'movement must restart the stationary settling countdown')
    end

    while #inputs < 2 do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().attempt, 2)
    local rejected_command_id = queue:snapshot().command_id
    local rejected_deadline = scheduler.now + queue:snapshot().action_remaining

    -- Reproduce the live log: the retry command is immediately rejected by
    -- the lingering action lock. It receives a bounded lock retry and attempt
    -- two remains available instead of the queue stopping.
    expect(queue:on_action_message(runtime.player_id, runtime.player_id, 18))
    equal(queue:snapshot().status, 'retry_wait')
    equal(queue:snapshot().attempt, 1)
    equal(queue:snapshot().action_lock_retries, 1)
    while #inputs < 3 do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().attempt, 2)
    expect(queue:snapshot().command_id > rejected_command_id)
    expect(queue:snapshot().active)

    -- The rejected command's old timeout must not attach itself to the reused
    -- attempt number and prematurely time out the replacement command.
    while scheduler.now < rejected_deadline do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().status, 'awaiting_action')
    expect(queue:snapshot().active)
    expect(queue:cancel('test_complete'))
end)

test('stops on an action timeout and preserves pending', function()
    local state, _, queue, scheduler, _, output = fixture()
    expect(state:select('Rahal'))
    expect(queue:start())
    while queue:snapshot().active do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().reason, 'action_timeout')
    equal(#state:pending_entries(), 1)
    expect(output[#output]:find(
        'The game did not begin summoning Rahal, and Rahal did not join your party. Try again.',
        1, true) ~= nil,
        'a silent summon timeout must use player-facing language in chat')
end)

test('confirms party membership without waiting for a cast result', function()
    local state, runtime, queue, scheduler, inputs, output = fixture()
    expect(state:select('Mihli Aliapoh'))
    expect(state:select('Rahal'))
    expect(queue:start())

    -- The game confirms Mihli in the party, but Windower never delivers her
    -- matching action event. Parallel party observation must advance well
    -- before the action timeout.
    runtime.party = {
        p0={name='Player', mob={spawn_type=0}},
        p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        party1_count=2,
    }
    expect(scheduler:run_next())
    expect(scheduler.now < 2,
        'party membership must be recognized before the action timeout')
    equal(queue:snapshot().status, 'next_summon_wait')
    expect(scheduler:run_next())
    equal(inputs[2], '/ma "Rahal" <me>')
    equal(queue:snapshot().current_name, 'Rahal')
    equal(queue:snapshot().summoned, 1)
    equal(#state:pending_entries(), 1)
    equal(state:pending_entries()[1].en, 'Rahal')
    expect(table.concat(output, '|'):find(
        'continuing after a missed cast result', 1, true) == nil)

    expect(queue:on_action(success_action(951, runtime.player_id)))
    runtime.party.p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}}
    runtime.party.party1_count = 3
    while queue:snapshot().active do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().status, 'complete')
    equal(queue:snapshot().summoned, 2)
    equal(#state:pending_entries(), 0)
end)

test('polls party state after a missed action before timing out', function()
    local state, runtime, queue, scheduler, inputs, output = fixture()
    expect(state:select('Mihli Aliapoh'))
    expect(state:select('Rahal'))
    expect(queue:start())

    -- The action timeout fires before the party snapshot contains Mihli.
    -- Recovery must stay active during the confirmation window.
    while queue:snapshot().status == 'awaiting_action' do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().status, 'awaiting_party')
    equal(queue:snapshot().reason, 'missed_action')
    runtime.party = {
        p0={name='Player', mob={spawn_type=0}},
        p1={name='MihliAliapoh', mob={spawn_type=14, models={}}},
        party1_count=2,
    }
    while #inputs < 2 do
        expect(scheduler:run_next())
    end
    equal(inputs[2], '/ma "Rahal" <me>')
    equal(queue:snapshot().current_name, 'Rahal')
    equal(queue:snapshot().summoned, 1)
    expect(table.concat(output, '|'):find(
        'continuing after a missed cast result', 1, true) ~= nil)
end)

test('handles Trust-specific hard failure messages for the player', function()
    local state, runtime, queue = fixture()
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(not queue:on_action_message(999, 999, 700))
    expect(queue:on_action_message(runtime.player_id, runtime.player_id, 700))
    equal(queue:snapshot().reason, 'trust_unavailable')
end)

test('stops when party capacity changes and preserves the remaining Trust', function()
    local state, runtime, queue, scheduler, inputs, output = fixture()
    expect(state:select('Mihli Aliapoh'))
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(queue:on_action(success_action(909, runtime.player_id)))
    runtime.party = {
        p0={name='Player', mob={spawn_type=0}},
        p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        p2={name='FriendOne', mob={spawn_type=0}},
        p3={name='FriendTwo', mob={spawn_type=0}},
        p4={name='FriendThree', mob={spawn_type=0}},
        p5={name='FriendFour', mob={spawn_type=0}},
        party1_count=6,
    }
    while queue:snapshot().active
        and queue:snapshot().reason ~= 'party_full' do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().reason, 'party_full')
    expect(not queue:snapshot().active)
    equal(queue:snapshot().current_name, nil)
    equal(#inputs, 1,
        'capacity loss must stop before issuing the next Trust command')
    equal(#state:pending_entries(), 1)
    equal(state:pending_entries()[1].en, 'Rahal')
    expect(table.concat(output, '|'):find(
        'party has no remaining Trust slots', 1, true) ~= nil)

    -- Restoring capacity permits an immediate retry. Old callbacks from the
    -- stopped run may remain scheduled, but their run ID cannot affect it.
    runtime.party = {
        p0={name='Player', mob={spawn_type=0}},
        p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
        party1_count=2,
    }
    expect(queue:start())
    equal(inputs[2], '/ma "Rahal" <me>')
    expect(queue:on_action(success_action(951, runtime.player_id)))
    runtime.party.p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}}
    runtime.party.party1_count = 3
    while queue:snapshot().active do
        expect(scheduler:run_next())
    end
    equal(queue:snapshot().status, 'complete')
    equal(#state:pending_entries(), 0)
end)

test('cancel invalidates scheduled work and preserves pending', function()
    local state, _, queue, scheduler, inputs = fixture()
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(queue:cancel('zone_change'))
    while scheduler:run_next() do end
    equal(queue:snapshot().status, 'cancelled')
    equal(#inputs, 1)
    equal(#state:pending_entries(), 1)
end)

test('command mutations are locked while a summon queue is active', function()
    local state, _, queue, _, _, output = fixture()
    expect(state:select('Rahal'))
    expect(queue:start())

    local handler = commands.new(state, function(line)
        output[#output + 1] = line
    end, queue)
    handler:handle({'clear'})
    handler:handle({'remove', 'Rahal'})
    handler:handle({'select', 'Mihli', 'Aliapoh'})

    equal(#state:pending_entries(), 1)
    equal(state:pending_entries()[1].en, 'Rahal')
    expect(output[#output]:find('already running', 1, true) ~= nil)
end)

test('uses the client language and Shift-JIS adapter', function()
    local state, runtime, queue, _, inputs = fixture()
    runtime.info.language = 'Japanese'
    expect(state:select('Rahal'))
    expect(queue:start())
    equal(inputs[1], '/ma "Rahal JP" <me>')
end)

test('records queue transitions and periodic active heartbeats', function()
    local state, _, queue, scheduler = fixture()
    local traces = {}
    queue.trace = function(event, detail)
        traces[#traces + 1] = tostring(event) .. ' ' .. tostring(detail)
    end
    expect(state:select('Rahal'))
    expect(queue:start())
    scheduler.now = 2.1
    queue:tick()
    local log = table.concat(traces, '|')
    expect(log:find('queue_started', 1, true),
        'the trace must identify the beginning of a queue run')
    expect(log:find('cast_command', 1, true),
        'the trace must identify each issued Trust command')
    expect(log:find('heartbeat', 1, true),
        'an active queue must record a heartbeat every two seconds')
    expect(log:find('status=awaiting_action', 1, true),
        'trace records must include the current queue state')
end)

test('a scheduled callback error stops instead of leaving the queue active', function()
    local state, _, queue, scheduler, _, output = fixture()
    local traces = {}
    queue.trace = function(event, detail)
        traces[#traces + 1] = tostring(event) .. ' ' .. tostring(detail)
    end
    expect(state:select('Rahal'))
    expect(queue:start())
    queue._observe_party_while_awaiting_action = function()
        error('deliberate callback failure')
    end
    expect(scheduler:run_next())
    equal(queue:snapshot().active, false)
    equal(queue:snapshot().status, 'stopped')
    equal(queue:snapshot().reason, 'internal_error')
    expect(table.concat(traces, '|'):find('deliberate callback failure', 1, true),
        'the callback failure must be preserved in diagnostics')
    expect(table.concat(output, '|'):find('data/queue.log', 1, true),
        'the user must be directed to the diagnostic log')
end)

io.write(('All %d summon queue tests passed.\n'):format(tests_run))
