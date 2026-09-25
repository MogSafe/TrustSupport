package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local events = {}
local output = {}
local settings = nil
local scheduled = {}
local inputs = {}
local ui_calls = {close=0, zone_change=0}

package.preload['ui/trust_ui'] = function()
    return {
        new = function()
            return {
                close = function() ui_calls.close = ui_calls.close + 1 end,
                destroy = function() end,
                on_mouse = function() return false end,
                on_zone_change = function()
                    ui_calls.zone_change = ui_calls.zone_change + 1
                end,
                open = function() end,
                reset_position = function() end,
                set_dialogue_mode = function() end,
                set_launcher_visible = function() end,
                set_scale = function() end,
                set_search = function() end,
                tick = function() end,
                toggle = function() end,
            }
        end,
    }
end

package.preload.config = function()
    return {
        load = function(defaults)
            defaults.save = function() end
            settings = defaults
            return defaults
        end,
    }
end

package.preload.resources = function()
    return {
        spells = {
            [909] = {
                id = 909,
                en = 'Mihli Aliapoh',
                ja = 'Mihli JP',
                model = 3013,
                party_name = 'MihliAliapoh',
                recast_id = 909,
                type = 'Trust',
            },
        },
    }
end

_addon = {}
windower = {
    add_to_chat = function(_, line)
        output[#output + 1] = line
    end,
    register_event = function(...)
        local args = {...}
        local callback = args[#args]
        for index = 1, #args - 1 do
            events[args[index]] = callback
        end
    end,
    chat = {
        input = function(command)
            inputs[#inputs + 1] = command
        end,
    },
    to_shift_jis = function(value) return value end,
    -- Enable UI construction with the lightweight stub above so lifecycle
    -- behavior can be covered without Windower's real primitives.
    prim = {},
    text = {},
    ffxi = {
        get_info = function() return {logged_in=true} end,
        get_spells = function() return {[909]=true} end,
        get_spell_recasts = function() return {[909]=0} end,
        get_party = function()
            return {p0={name='Player', mob={spawn_type=0}}, party1_count=1}
        end,
        get_key_items = function() return {2886} end,
        get_player = function() return {id=100} end,
    },
}

coroutine.schedule = function(callback)
    scheduled[#scheduled + 1] = callback
end

dofile('./addons/TrustSupport/TrustSupport.lua')

assert(_addon.name == 'TrustSupport')
assert(_addon.author == 'MogSafe')
assert(#_addon.commands == 3)
assert(_addon.commands[1] == 'trustsupport')
assert(_addon.commands[2] == 'tsup')
assert(_addon.commands[3] == 'ts')
assert(settings.icon == true)
assert(settings.summon.max_attempts == 2)
assert(settings.summon.next_cast_delay == 0.5)
assert(settings.summon.movement_retry_delay == 5)
assert(settings.summon.action_lock_retry_delay == 3)
assert(settings.summon.max_action_lock_retries == 2)
assert(type(events.load) == 'function')
assert(type(events['addon command']) == 'function')
assert(type(events.action) == 'function')
assert(type(events['action message']) == 'function')
assert(type(events['incoming text']) == 'function')
assert(type(events.prerender) == 'function')
assert(type(events.login) == 'function')
assert(type(events.logout) == 'function')
assert(type(events['zone change']) == 'function')
assert(type(events.unload) == 'function')

events.load()
events['addon command']('select', 'Mihli', 'Aliapoh')
events['addon command']('status')
events['addon command']('icon', 'off')

assert(settings.icon == false)
assert(#output >= 7)
assert(output[1]:find('State core loaded', 1, true))

-- External lifecycle events must stop active work, preserve the unapplied
-- selection, and invalidate delayed callbacks from the interrupted run.
events['addon command']('summon')
assert(#inputs == 1)
local stale_zone_callbacks = scheduled
scheduled = {}
events['zone change']()
assert(ui_calls.zone_change == 1,
    'zone change must ask an open compact UI to revalidate its preset')
for _, callback in ipairs(stale_zone_callbacks) do callback() end
assert(#inputs == 1)
events['addon command']('status')
assert(output[#output - 2]:find('Pending: Mihli Aliapoh', 1, true))
assert(output[#output]:find('cancelled', 1, true))

events['addon command']('summon')
assert(#inputs == 2)
local stale_logout_callbacks = scheduled
scheduled = {}
events.logout()
assert(ui_calls.close == 1,
    'logout must close the party UI and return to the standalone launcher')
for _, callback in ipairs(stale_logout_callbacks) do callback() end
assert(#inputs == 2)

events['addon command']('summon')
assert(#inputs == 3)
local stale_unload_callbacks = scheduled
scheduled = {}
events.unload()
for _, callback in ipairs(stale_unload_callbacks) do callback() end
assert(#inputs == 3)

io.write(('Bootstrap smoke test passed with %d chat messages.\n'):format(#output))
