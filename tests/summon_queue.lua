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
        get_player_id = function() return runtime.player_id end,
        get_language = function() return runtime.info.language end,
        to_shift_jis = function(value) return value end,
        action_timeout = 2,
        settle_delay = 0.1,
        confirm_interval = 0.1,
        confirm_timeout = 0.5,
        retry_delay = 0.1,
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
    expect(scheduler:run_next())
    equal(inputs[2], '/ma "Rahal" <me>')

    expect(queue:on_action(success_action(951, runtime.player_id)))
    runtime.party.p2 = {name='Rahal', mob={spawn_type=14, models={[1]=3056}}}
    runtime.party.party1_count = 3
    expect(scheduler:run_next())

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
    expect(scheduler:run_next())
    equal(#inputs, 2)

    expect(queue:on_action(interruption_action(951, runtime.player_id)))
    equal(queue:snapshot().status, 'stopped')
    equal(queue:snapshot().reason, 'interrupted')
    equal(#state:pending_entries(), 1)
end)

test('stops on an action timeout and preserves pending', function()
    local state, _, queue, scheduler = fixture()
    expect(state:select('Rahal'))
    expect(queue:start())
    expect(scheduler:run_next())
    equal(queue:snapshot().reason, 'action_timeout')
    equal(#state:pending_entries(), 1)
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
    local state, runtime, queue, scheduler = fixture()
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
    expect(scheduler:run_next())
    equal(queue:snapshot().reason, 'party_full')
    equal(#state:pending_entries(), 1)
    equal(state:pending_entries()[1].en, 'Rahal')
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

io.write(('All %d summon queue tests passed.\n'):format(tests_run))
