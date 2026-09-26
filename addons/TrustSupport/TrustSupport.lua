_addon.name = 'TrustSupport'
_addon.author = 'MogSafe'
_addon.version = '1.0.1'
_addon.commands = {'trustsupport', 'tsup'}

local config = require('config')
local resources = require('resources')
local card_assets = require('resources/card_assets')
local trust_metadata = require('resources/trust_metadata')
local trust_state = require('core/trust_state')
local command_adapter = require('core/commands')
local change_queue = require('core/change_queue')
local preset_engine = require('core/presets')
local trust_ui = require('ui/trust_ui')
local socket_ok, socket = pcall(require, 'socket')
local wall_clock = socket_ok and socket and socket.gettime or os.clock

local addon_path = tostring(windower.addon_path or '')
if addon_path ~= '' and not addon_path:match('[\\/]$') then
    addon_path = addon_path .. '/'
end
local queue_log_path = addon_path .. 'data/queue.log'
local queue_log_started = false

local function queue_trace(event, detail)
    local mode = queue_log_started and 'a' or 'w'
    local file = io.open(queue_log_path, mode)
    if not file then
        return
    end
    if not queue_log_started then
        file:write(('# TrustSupport queue diagnostics %s version=%s\n'):format(
            os.date('%Y-%m-%d %H:%M:%S'), _addon.version))
        queue_log_started = true
    end
    file:write(('%s wall=%.3f %-28s %s\n'):format(
        os.date('%H:%M:%S'), wall_clock(), tostring(event), tostring(detail or '')))
    file:close()
end

local defaults = {
    icon = true,
    summon = {
        action_timeout = 10,
        next_cast_delay = 0.5,
        post_summon_delay = 3,
        confirm_interval = 0.25,
        confirm_timeout = 5,
        retry_delay = 3,
        movement_retry_delay = 5,
        action_lock_retry_delay = 3,
        max_action_lock_retries = 2,
        max_attempts = 2,
    },
    presets = preset_engine.new_settings(),
    dialogue = {
        mode = 'always',
        chance = 0.25,
        characters_per_second = 30,
        hold = 3.25,
    },
    ui = {
        x = 220,
        y = 95,
        scale = 0.78,
        mode = 'expanded',
        sort = 'status',
        launcher_x = 32,
        launcher_y = 280,
    },
}

local settings = config.load(defaults)
settings.presets = preset_engine.normalize_settings(settings.presets)

local function message(text)
    windower.add_to_chat(207, ('[TrustSupport] %s'):format(text))
end

local ui = nil

local function set_dialogue_mode(value)
    local aliases = {on='always', yes='always', occasional='occasional',
        sometimes='occasional', ['25']='occasional', off='off', no='off'}
    local mode = aliases[tostring(value or ''):lower()]
    if not mode then
        return false
    end
    settings.dialogue = settings.dialogue or {}
    settings.dialogue.mode = mode
    settings:save('all')
    if ui then
        ui:set_dialogue_mode(mode, false)
    end
    return true
end

local function set_icon(enabled)
    settings.icon = enabled
    settings:save('all')
    if ui then
        ui:set_launcher_visible(enabled)
    end
    message(('Launcher icon %s.'):format(enabled and 'enabled' or 'disabled'))
end

local state = trust_state.new({
    spells = resources.spells,
    card_assets = card_assets,
    trust_metadata = trust_metadata.by_name,
    get_info = windower.ffxi.get_info,
    get_spells = windower.ffxi.get_spells,
    get_spell_recasts = windower.ffxi.get_spell_recasts,
    get_party = windower.ffxi.get_party,
    get_key_items = windower.ffxi.get_key_items,
})

local queue = change_queue.new(state, {
    input = function(command)
        windower.chat.input(command)
    end,
    schedule = function(callback, delay)
        coroutine.schedule(callback, delay)
    end,
    emit = message,
    clock = wall_clock,
    trace = queue_trace,
    get_player_id = function()
        local player = windower.ffxi.get_player()
        return player and player.id or nil
    end,
    get_player_position = function()
        local mob = windower.ffxi.get_mob_by_target
            and windower.ffxi.get_mob_by_target('me') or nil
        if not mob then
            local player = windower.ffxi.get_player()
            mob = player and windower.ffxi.get_mob_by_id
                and windower.ffxi.get_mob_by_id(player.id) or nil
        end
        return mob and {x=mob.x, y=mob.y, z=mob.z} or nil
    end,
    get_language = function()
        local info = windower.ffxi.get_info()
        return info and info.language or 'English'
    end,
    to_shift_jis = windower.to_shift_jis,
    action_timeout = settings.summon.action_timeout,
    -- FFXI retains an action lock after a Trust joins. The established Trusts
    -- addon waits three seconds after each successful cast; use the same
    -- conservative handoff instead of issuing a command during that lock.
    next_cast_delay = settings.summon.post_summon_delay or 3,
    confirm_interval = settings.summon.confirm_interval,
    confirm_timeout = settings.summon.confirm_timeout,
    retry_delay = settings.summon.retry_delay,
    movement_retry_delay = settings.summon.movement_retry_delay,
    action_lock_retry_delay = settings.summon.action_lock_retry_delay,
    max_action_lock_retries = settings.summon.max_action_lock_retries,
    max_attempts = settings.summon.max_attempts,
})

local commands = command_adapter.new(state, message, queue, {
    presets = settings.presets,
    save_settings = function()
        settings:save('all')
    end,
})

-- The pure state remains usable in the test harness and in unusual Windower
-- environments where primitives are unavailable. Rendering is enabled only
-- when Windower exposes both image and text primitives.
if windower.prim and windower.text then
    local ok, result = pcall(trust_ui.new, {
        state = state,
        commands = commands,
        queue = queue,
        metadata = trust_metadata,
        settings = settings,
        emit = message,
        save_settings = function()
            settings:save('all')
        end,
        file_exists = windower.file_exists,
        addon_path = windower.addon_path,
        windower_path = windower.windower_path,
    })
    if ok then
        ui = result
    else
        message(('UI could not be initialized: %s'):format(tostring(result)))
    end
end

windower.register_event('addon command', function(...)
    local args = {...}
    local command = args[1] and args[1]:lower() or 'toggle'
    local value = args[2] and args[2]:lower() or nil

    if command == 'icon' then
        if value == 'on' then
            set_icon(true)
        elseif value == 'off' then
            set_icon(false)
        else
            message(('Launcher icon is %s.'):format(settings.icon and 'enabled' or 'disabled'))
        end
        return
    end

    if command == 'dialogue' or command == 'dialog' then
        if value and set_dialogue_mode(value) then
            message(('Summon dialogue set to %s.'):format(settings.dialogue.mode))
        elseif value then
            message('Usage: //tsup dialogue <off|occasional|always>')
        else
            local mode = settings.dialogue and settings.dialogue.mode or 'always'
            message(('Summon dialogue is %s.'):format(mode))
        end
        return
    end

    if ui then
        if command == 'toggle' or command == '' then
            ui:toggle()
            return
        elseif command == 'open' or command == 'show' then
            ui:open()
            return
        elseif command == 'close' or command == 'hide' then
            ui:close()
            return
        elseif command == 'search' then
            local terms = {}
            for index = 2, #args do
                terms[#terms + 1] = tostring(args[index])
            end
            ui:set_search(table.concat(terms, ' '))
            ui:open()
            return
        elseif command == 'scale' then
            local scale = tonumber(args[2])
            if not scale then
                message('Usage: //tsup scale <0.55-1.25>')
            else
                ui:set_scale(scale)
                message(('UI scale set to %.2f.'):format(ui.scale))
            end
            return
        elseif command == 'resetui' then
            ui:reset_position()
            message('UI position restored.')
            return
        end
    end

    commands:handle(args)
end)

windower.register_event('load', function()
    local snapshot = state:refresh()
    message(('State core loaded: %d learned Trusts, %d active, %d pending.'):format(
        snapshot.stats.learned,
        snapshot.active_trusts,
        snapshot.pending
    ))
    message(ui and 'Click the launcher or use //tsup to open party selection.'
        or 'Use //tsup status or //tsup help for commands.')
end)

windower.register_event('login', function()
    state:refresh()
end)

windower.register_event('logout', function()
    queue:cancel('logout')
    state:refresh()
    if ui then
        -- Logging out leaves Windower and the addon loaded. Collapse either
        -- presentation back to the standalone launcher so the party UI does
        -- not remain over the character-select screen.
        ui:close()
    end
end)

windower.register_event('zone change', function()
    queue:cancel('zone_change')
    if ui then
        -- Capture the pre-zone party before refresh can expose either the old
        -- or a transiently empty snapshot. The UI will reload a compact preset
        -- only after it observes the transition.
        ui:on_zone_change()
    end
    state:refresh()
end)

windower.register_event('action', function(action)
    local ok, queue_error = pcall(function()
        queue:on_action(action)
    end)
    if not ok then
        queue:fail_internal('action_event', queue_error)
    end
end)

windower.register_event('action message', function(actor_id, target_id, _, _, message_id)
    local ok, queue_error = pcall(function()
        queue:on_action_message(actor_id, target_id, message_id)
    end)
    if not ok then
        queue:fail_internal('action_message_event', queue_error)
    end
end)

windower.register_event('incoming text', function(original, modified)
    local ok, queue_error = pcall(function()
        queue:on_incoming_text(original, modified)
    end)
    if not ok then
        queue:fail_internal('incoming_text_event', queue_error)
    end
end)

windower.register_event('prerender', function()
    local ok, queue_error = pcall(function()
        queue:tick()
    end)
    if not ok then
        queue:fail_internal('prerender_tick', queue_error)
    end
    if ui then
        ui:tick()
    end
end)

if ui then
    windower.register_event('mouse', function(type, x, y, delta, blocked)
        return ui:on_mouse(type, x, y, delta, blocked)
    end)
end

windower.register_event('unload', function()
    queue:cancel('addon_unload')
    if ui then
        ui:destroy()
    end
end)
