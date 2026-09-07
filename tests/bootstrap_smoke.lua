package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local events = {}
local output = {}
local settings = nil

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
        input = function() end,
    },
    to_shift_jis = function(value) return value end,
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

coroutine.schedule = function() end

dofile('./addons/TrustSupport/TrustSupport.lua')

assert(_addon.name == 'TrustSupport')
assert(_addon.author == 'MogSafe')
assert(#_addon.commands == 3)
assert(_addon.commands[1] == 'trustsupport')
assert(_addon.commands[2] == 'tsup')
assert(_addon.commands[3] == 'ts')
assert(settings.icon == true)
assert(settings.summon.max_attempts == 2)
assert(type(events.load) == 'function')
assert(type(events['addon command']) == 'function')
assert(type(events.action) == 'function')
assert(type(events['action message']) == 'function')

events.load()
events['addon command']('select', 'Mihli', 'Aliapoh')
events['addon command']('status')
events['addon command']('icon', 'off')

assert(settings.icon == false)
assert(#output >= 7)
assert(output[1]:find('State core loaded', 1, true))

io.write(('Bootstrap smoke test passed with %d chat messages.\n'):format(#output))
