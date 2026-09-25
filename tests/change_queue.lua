package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local trust_state = require('core/trust_state')
local change_queue = require('core/change_queue')

local Scheduler = {}
Scheduler.__index = Scheduler
function Scheduler.new() return setmetatable({now=0, tasks={}}, Scheduler) end
function Scheduler:schedule(callback, delay)
    self.tasks[#self.tasks + 1] = {at=self.now + delay, callback=callback}
end
function Scheduler:run_next()
    if #self.tasks == 0 then return false end
    local selected = 1
    for index = 2, #self.tasks do
        if self.tasks[index].at < self.tasks[selected].at then selected = index end
    end
    local task = table.remove(self.tasks, selected)
    self.now = task.at
    task.callback()
    return true
end

local spells = {
    [909] = {id=909, en='Mihli Aliapoh', model=3013, party_name='MihliAliapoh', recast_id=909, type='Trust'},
    [951] = {id=951, en='Rahal', model=3056, party_name='Rahal', recast_id=951, type='Trust'},
}

local function fixture()
    local runtime = {
        info={logged_in=true, language='English'},
        learned={[909]=true, [951]=true},
        recasts={[909]=0, [951]=0},
        party={
            p0={name='Player', mob={spawn_type=0}},
            p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
            party1_count=2,
        },
        key_items={2886},
        player_id=100,
    }
    local state = trust_state.new({
        spells=spells,
        get_info=function() return runtime.info end,
        get_spells=function() return runtime.learned end,
        get_spell_recasts=function() return runtime.recasts end,
        get_party=function() return runtime.party end,
        get_key_items=function() return runtime.key_items end,
    })
    state:refresh()
    local scheduler = Scheduler.new()
    local inputs, output, traces = {}, {}, {}
    local queue = change_queue.new(state, {
        input=function(command) inputs[#inputs + 1] = command end,
        schedule=function(callback, delay) scheduler:schedule(callback, delay) end,
        emit=function(line) output[#output + 1] = line end,
        trace=function(event, detail)
            traces[#traces + 1] = tostring(event) .. ' ' .. tostring(detail)
        end,
        clock=function() return scheduler.now end,
        get_player_id=function() return runtime.player_id end,
        get_language=function() return runtime.info.language end,
        to_shift_jis=function(value) return value end,
        action_timeout=2,
        next_cast_delay=0.1,
        confirm_interval=0.1,
        confirm_timeout=0.5,
        retry_delay=0.1,
        max_attempts=2,
    })
    return state, runtime, queue, scheduler, inputs, output, traces
end

local function expect(value, message) assert(value, message or 'expectation failed') end
local function equal(actual, expected)
    assert(actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end

local state, runtime, queue, scheduler, inputs, output = fixture()
expect(state:stage_dismissal('Mihli Aliapoh'))
expect(state:select('Rahal'))
expect(queue:start())
equal(#output, 1)
equal(output[1], 'Applying party changes: 1 dismissal, 1 summon.')
equal(inputs[1], '/refa "MihliAliapoh"')
equal(queue:snapshot().phase, 'dismissing')
equal(queue:snapshot().dismiss_total, 1)
equal(queue:snapshot().summon_total, 1)

runtime.party = {p0={name='Player', mob={spawn_type=0}}, party1_count=1}
expect(scheduler:run_next())
equal(inputs[2], '/ma "Rahal" <me>')
equal(queue:snapshot().phase, 'summoning')
equal(queue:snapshot().dismiss_total, 1)
equal(queue:snapshot().summon_total, 1)
local recent_after_dismissal = queue:snapshot().recent_dismissed_ids
equal(#recent_after_dismissal, 1)
equal(recent_after_dismissal[1], 909)

expect(queue:on_action({category=4, param=951, actor_id=runtime.player_id}))
runtime.party.p1 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}}
runtime.party.party1_count = 2
while queue:snapshot().active do
    expect(scheduler:run_next())
end
equal(queue:snapshot().status, 'complete')
equal(queue:snapshot().dismissed, 1)
equal(#state:pending_entries(), 0)
equal(#state:pending_dismissal_records(), 0)
equal(#output, 1,
    'mixed queue progress and normal completion must remain quiet')
scheduler.now = scheduler.now + 6
equal(#queue:snapshot().recent_dismissed_ids, 0)

local cancel_state, _, cancel_queue, cancel_scheduler, cancel_inputs,
    cancel_output = fixture()
expect(cancel_state:stage_dismissal('Mihli Aliapoh'))
expect(cancel_queue:start())
expect(cancel_queue:cancel('user_cancelled'))
equal(#cancel_output, 2)
equal(cancel_output[1], 'Applying party changes: 1 dismissal.')
equal(cancel_output[2], 'Party changes cancelled.')
while cancel_scheduler:run_next() do end
equal(#cancel_inputs, 1)
equal(cancel_queue:snapshot().status, 'cancelled')
equal(#cancel_state:pending_dismissal_records(), 1)
expect(cancel_queue:start())
equal(cancel_inputs[2], '/refa "MihliAliapoh"')
expect(cancel_queue:cancel('test_complete'))
while cancel_scheduler:run_next() do end
equal(#cancel_inputs, 2)

-- Cancelling after the dismissal-to-summon handoff preserves the pending
-- Trust and permits an immediate restart. Callbacks from the cancelled run
-- must not issue another command or delay that restart.
local handoff_state, handoff_runtime, handoff_queue,
    handoff_scheduler, handoff_inputs = fixture()
expect(handoff_state:stage_dismissal('Mihli Aliapoh'))
expect(handoff_state:select('Rahal'))
expect(handoff_queue:start())
handoff_runtime.party = {
    p0={name='Player', mob={spawn_type=0}},
    party1_count=1,
}
expect(handoff_scheduler:run_next())
equal(handoff_inputs[2], '/ma "Rahal" <me>')
equal(handoff_queue:snapshot().phase, 'summoning')
expect(handoff_queue:cancel('user_cancelled'))
equal(handoff_queue:snapshot().status, 'cancelled')
equal(#handoff_state:pending_entries(), 1)
expect(handoff_queue:start())
equal(handoff_inputs[3], '/ma "Rahal" <me>')
expect(handoff_queue:cancel('test_complete'))
while handoff_scheduler:run_next() do end
equal(#handoff_inputs, 3)

-- Consecutive dismissals leave a short handoff window after the first
-- departure so the client can settle before receiving another /refa command.
local multi_state, multi_runtime, multi_queue,
    multi_scheduler, multi_inputs = fixture()
multi_runtime.party = {
    p0={name='Player', mob={spawn_type=0}},
    p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
    p2={name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
    party1_count=3,
}
multi_state:refresh()
expect(multi_state:stage_dismissal('Mihli Aliapoh'))
expect(multi_state:stage_dismissal('Rahal'))
expect(multi_queue:start())
equal(multi_inputs[1], '/refa "MihliAliapoh"')
multi_runtime.party = {
    p0={name='Player', mob={spawn_type=0}},
    p1={name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
    party1_count=2,
}
expect(multi_scheduler:run_next())
equal(#multi_inputs, 1)
equal(multi_queue:snapshot().status, 'next_dismissal_wait')
expect(math.abs(multi_queue:snapshot().handoff_remaining - 0.75) < 0.001)
expect(multi_scheduler:run_next())
equal(multi_inputs[2], '/refa "Rahal"')
expect(math.abs(multi_scheduler.now - 0.85) < 0.001)
multi_runtime.party = {
    p0={name='Player', mob={spawn_type=0}},
    party1_count=1,
}
expect(multi_scheduler:run_next())
equal(multi_queue:snapshot().status, 'complete')
equal(multi_queue:snapshot().dismissed, 2)

-- The render-loop watchdog also completes a lost handoff callback.
local handoff_watchdog_state, handoff_watchdog_runtime,
    handoff_watchdog_queue, handoff_watchdog_scheduler,
    handoff_watchdog_inputs = fixture()
handoff_watchdog_runtime.party = {
    p0={name='Player', mob={spawn_type=0}},
    p1={name='MihliAliapoh', mob={spawn_type=14, models={[1]=3013}}},
    p2={name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
    party1_count=3,
}
handoff_watchdog_state:refresh()
expect(handoff_watchdog_state:stage_dismissal('Mihli Aliapoh'))
expect(handoff_watchdog_state:stage_dismissal('Rahal'))
expect(handoff_watchdog_queue:start())
handoff_watchdog_runtime.party = {
    p0={name='Player', mob={spawn_type=0}},
    p1={name='Rahal', mob={spawn_type=14, models={[1]=3056}}},
    party1_count=2,
}
expect(handoff_watchdog_scheduler:run_next())
equal(handoff_watchdog_queue:snapshot().status, 'next_dismissal_wait')
handoff_watchdog_scheduler.tasks = {}
handoff_watchdog_scheduler.now = 0.9
expect(handoff_watchdog_queue:tick())
equal(handoff_watchdog_inputs[2], '/refa "Rahal"')
equal(handoff_watchdog_queue:snapshot().status, 'awaiting_dismissal')
expect(handoff_watchdog_queue:cancel('test_complete'))

local failed_state, _, failed_queue, failed_scheduler,
    _, failed_output, failed_traces = fixture()
expect(failed_state:stage_dismissal('Mihli Aliapoh'))
expect(failed_queue:start())
while failed_queue:snapshot().active do
    expect(failed_scheduler:run_next())
end
equal(failed_queue:snapshot().status, 'stopped')
equal(failed_queue:snapshot().reason, 'dismissal_unconfirmed')
equal(failed_queue:snapshot().phase, 'dismissing')
equal(failed_output[2],
    [=[Mihli Aliapoh's dismissal was unsuccessful. Try again.]=])
local saw_scheduled_deadline = false
for _, trace in ipairs(failed_traces) do
    if trace:find('change_dismissal_deadline', 1, true) then
        saw_scheduled_deadline = true
    end
end
expect(saw_scheduled_deadline, 'scheduled dismissal timeout should be traced')

-- The render-loop watchdog must bound dismissal confirmation even if the
-- scheduled callback is lost. This prevents an indefinitely animated card
-- border and CANCEL state.
local watchdog_state, _, watchdog_queue, watchdog_scheduler,
    _, watchdog_output = fixture()
expect(watchdog_state:stage_dismissal('Mihli Aliapoh'))
expect(watchdog_queue:start())
watchdog_scheduler.tasks = {}
watchdog_scheduler.now = 0.6
expect(watchdog_queue:tick())
equal(watchdog_queue:snapshot().active, false)
equal(watchdog_queue:snapshot().status, 'stopped')
equal(watchdog_queue:snapshot().reason, 'dismissal_unconfirmed')
equal(watchdog_queue:snapshot().phase, 'dismissing')
equal(#watchdog_state:pending_dismissal_records(), 1)
equal(watchdog_output[2],
    [=[Mihli Aliapoh's dismissal was unsuccessful. Try again.]=])

-- The same watchdog must also recognize a completed departure and advance to
-- summons when its scheduled confirmation callback disappears.
local recovery_state, recovery_runtime, recovery_queue,
    recovery_scheduler, recovery_inputs = fixture()
expect(recovery_state:stage_dismissal('Mihli Aliapoh'))
expect(recovery_state:select('Rahal'))
expect(recovery_queue:start())
recovery_scheduler.tasks = {}
recovery_runtime.party = {
    p0={name='Player', mob={spawn_type=0}},
    party1_count=1,
}
recovery_scheduler.now = 0.2
expect(recovery_queue:tick())
equal(recovery_inputs[2], '/ma "Rahal" <me>')
equal(recovery_queue:snapshot().phase, 'summoning')
equal(recovery_queue:snapshot().dismissed, 1)
expect(recovery_queue:cancel('test_complete'))

io.write('Change queue tests passed.\n')
