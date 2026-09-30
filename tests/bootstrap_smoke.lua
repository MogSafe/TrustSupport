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
local ui_calls = {close=0, destroy=0, zone_change=0}
local logged_in, server, character = true, 15, 'Alice'
local ui_options = nil

package.preload['ui/trust_ui'] = function()
    return {
        new = function(options)
            ui_options = options
            settings = options.settings
            return {
                close = function() ui_calls.close = ui_calls.close + 1 end,
                destroy = function() ui_calls.destroy = ui_calls.destroy + 1 end,
                on_mouse = function() return false end,
                on_zone_change = function()
                    ui_calls.zone_change = ui_calls.zone_change + 1
                    options.state:clear()
                end,
                open = function() end,
                apply_startup_view = function() end,
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

-- Real repository and codec, isolated in-memory filesystem (never live profiles).
local real_store = require('core/settings_store')
local profile_files = {}
local fail_write = false
local profile_fs = {
    exists=function(path) return profile_files[path] ~= nil end,
    read=function(path) return profile_files[path], 'missing' end,
    mkdir=function() return true end,
    write=function(path, bytes)
        if fail_write then return false, 'disk full' end
        profile_files[path] = bytes; return true
    end,
    remove=function(path) profile_files[path]=nil; return true end,
    rename=function(from, to)
        if not profile_files[from] or profile_files[to] then return false, 'rename failed' end
        profile_files[to], profile_files[from] = profile_files[from], nil
        return true
    end,
}
package.loaded['core/settings_store'] = nil
package.preload['core/settings_store'] = function()
    return {new=real_store.new, identity=real_store.identity,
        filesystem=function() return profile_fs end}
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
        get_info = function() return {logged_in=logged_in, server=server} end,
        get_spells = function() return {[909]=true} end,
        get_spell_recasts = function() return {[909]=0} end,
        get_party = function()
            return {p0={name='Player', mob={spawn_type=0}}, party1_count=1}
        end,
        get_key_items = function() return {2886} end,
        get_player = function() return logged_in and {id=100, name=character} or nil end,
    },
}

coroutine.schedule = function(callback)
    scheduled[#scheduled + 1] = callback
end

dofile('./addons/TrustSupport/TrustSupport.lua')

assert(ui_options and ui_options.trust_synergy,
    'bootstrap must pass Trust synergy data to the UI constructor')
assert(#ui_options.trust_synergy.groups == 27,
    'bootstrap must pass the loaded Trust synergy groups')
assert(_addon.name == 'TrustSupport')
assert(_addon.author == 'MogSafe')
assert(#_addon.commands == 2)
assert(_addon.commands[1] == 'trustsupport')
assert(_addon.commands[2] == 'tsup')
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
assert(ui_calls.zone_change == 1
        and settings.presets.selected == 1,
    'zone change must retain the selected preset while clearing unfinished work')
for _, callback in ipairs(stale_zone_callbacks) do callback() end
assert(#inputs == 1)
events['addon command']('status')
assert(output[#output - 2]:find('Pending: none', 1, true))
assert(output[#output]:find('cancelled', 1, true))

events['addon command']('select', 'Mihli', 'Aliapoh')
events['addon command']('summon')
assert(#inputs == 2)
local stale_logout_callbacks = scheduled
scheduled = {}
local old_ui = ui_options
logged_in = false
events.logout()
assert(ui_calls.close == 1 and ui_calls.destroy == 1,
    'logout must close the party UI and return to the standalone launcher')
for _, callback in ipairs(stale_logout_callbacks) do callback() end
assert(#inputs == 2)

events['addon command']('summon')
assert(#inputs == 2, 'logged-out commands must not execute')
local file_count = 0
for _ in pairs(profile_files) do file_count = file_count + 1 end
old_ui.save_settings()
local next_count = 0
for _ in pairs(profile_files) do next_count = next_count + 1 end
assert(next_count == file_count, 'stale UI callbacks must not save')
logged_in, character, server = true, 'Bob', nil
events.login()
assert(ui_options == old_ui, 'missing server identity must defer initialization')
server = 15
events.prerender()
assert(ui_options ~= old_ui and settings.icon == true,
    'new character must receive independent defaults, not previous in-memory settings')
assert(#ui_options.state:pending_entries() == 0, 'character switch clears temporary plan')
settings.presets.selected, settings.presets.compact_selected = 8, 2
ui_options.save_settings()
local bob_bytes = profile_files['data/characters/15/bob/settings.xml']
old_ui.save_settings()
assert(profile_files['data/characters/15/bob/settings.xml'] == bob_bytes)
fail_write = true
local before_failure = #output
events['addon command']('preset', 'select', '7')
assert(output[#output]:find('could not be saved', 1, true))
for index = before_failure + 1, #output do
    assert(not output[index]:find('Preset 7 selected.', 1, true), 'failed writes must not report success')
end
fail_write = false
logged_in = false
events.logout()
logged_in, character = true, 'Alice'
events.login()
assert(settings.icon == false and settings.presets.selected == 1,
    'returning character must reload its own profile')
assert(profile_files['data/characters/15/bob/settings.xml'] == bob_bytes)
events['addon command']('select', 'Mihli', 'Aliapoh')
events['addon command']('summon')
assert(#inputs == 3)
local stale_unload_callbacks = scheduled
scheduled = {}
events.unload()
for _, callback in ipairs(stale_unload_callbacks) do callback() end
assert(#inputs == 3)

-- Loading at character selection must neither write a global file nor build a UI.
logged_in, ui_options = false, nil
local before_logged_out = 0
for _ in pairs(profile_files) do before_logged_out = before_logged_out + 1 end
dofile('./addons/TrustSupport/TrustSupport.lua')
events.load()
events.prerender()
assert(ui_options == nil)
local after_logged_out = 0
for _ in pairs(profile_files) do after_logged_out = after_logged_out + 1 end
assert(before_logged_out == after_logged_out and profile_files['data/settings.xml'] == nil)
logged_in, character, server = true, 'Bob', 15
events.login()
assert(ui_options and settings.presets.selected == 8 and settings.presets.compact_selected == 2)
events.unload()

io.write(('Bootstrap smoke test passed with %d chat messages.\n'):format(#output))
