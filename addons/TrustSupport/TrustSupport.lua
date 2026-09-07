_addon.name = 'TrustSupport'
_addon.author = 'MogSafe'
_addon.version = '0.1.0-dev'
_addon.commands = {'trustsupport', 'tsup', 'ts'}

local config = require('config')
local resources = require('resources')
local card_assets = require('resources/card_assets')
local trust_metadata = require('resources/trust_metadata')
local trust_state = require('core/trust_state')
local command_adapter = require('core/commands')
local summon_queue = require('core/summon_queue')

local defaults = {
    icon = true,
    summon = {
        action_timeout = 10,
        settle_delay = 3,
        confirm_interval = 0.25,
        confirm_timeout = 5,
        retry_delay = 3,
        max_attempts = 2,
    },
}

local settings = config.load(defaults)

local function message(text)
    windower.add_to_chat(207, ('[TrustSupport] %s'):format(text))
end

local function set_icon(enabled)
    settings.icon = enabled
    settings:save('all')
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

local queue = summon_queue.new(state, {
    input = function(command)
        windower.chat.input(command)
    end,
    schedule = function(callback, delay)
        coroutine.schedule(callback, delay)
    end,
    emit = message,
    get_player_id = function()
        local player = windower.ffxi.get_player()
        return player and player.id or nil
    end,
    get_language = function()
        local info = windower.ffxi.get_info()
        return info and info.language or 'English'
    end,
    to_shift_jis = windower.to_shift_jis,
    action_timeout = settings.summon.action_timeout,
    settle_delay = settings.summon.settle_delay,
    confirm_interval = settings.summon.confirm_interval,
    confirm_timeout = settings.summon.confirm_timeout,
    retry_delay = settings.summon.retry_delay,
    max_attempts = settings.summon.max_attempts,
})

local commands = command_adapter.new(state, message, queue)

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

    commands:handle(args)
end)

windower.register_event('load', function()
    local snapshot = state:refresh()
    message(('State core loaded: %d learned Trusts, %d active, %d pending.'):format(
        snapshot.stats.learned,
        snapshot.active_trusts,
        snapshot.pending
    ))
    message('Use //ts status or //ts help for commands.')
end)

windower.register_event('login', function()
    state:refresh()
end)

windower.register_event('logout', function()
    queue:cancel('logout')
    state:refresh()
end)

windower.register_event('zone change', function()
    queue:cancel('zone_change')
    state:refresh()
end)

windower.register_event('action', function(action)
    queue:on_action(action)
end)

windower.register_event('action message', function(actor_id, target_id, _, _, message_id)
    queue:on_action_message(actor_id, target_id, message_id)
end)
