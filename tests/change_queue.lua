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
    local inputs, output = {}, {}
    local queue = change_queue.new(state, {
        input=function(command) inputs[#inputs + 1] = command end,
        schedule=function(callback, delay) scheduler:schedule(callback, delay) end,
        emit=function(line) output[#output + 1] = line end,
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
    return state, runtime, queue, scheduler, inputs, output
end

local function expect(value, message) assert(value, message or 'expectation failed') end
local function equal(actual, expected)
    assert(actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end

local state, runtime, queue, scheduler, inputs = fixture()
expect(state:stage_dismissal('Mihli Aliapoh'))
expect(state:select('Rahal'))
expect(queue:start())
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

local cancel_state, _, cancel_queue, cancel_scheduler, cancel_inputs = fixture()
expect(cancel_state:stage_dismissal('Mihli Aliapoh'))
expect(cancel_queue:start())
expect(cancel_queue:cancel('user_cancelled'))
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

local failed_state, _, failed_queue, failed_scheduler = fixture()
expect(failed_state:stage_dismissal('Mihli Aliapoh'))
expect(failed_queue:start())
while failed_queue:snapshot().active do
    expect(failed_scheduler:run_next())
end
equal(failed_queue:snapshot().status, 'stopped')
equal(failed_queue:snapshot().reason, 'dismissal_unconfirmed')
equal(failed_queue:snapshot().phase, 'dismissing')

-- The render-loop watchdog must bound dismissal confirmation even if the
-- scheduled callback is lost. This prevents an indefinitely animated card
-- border and CANCEL state.
local watchdog_state, _, watchdog_queue, watchdog_scheduler = fixture()
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
