_addon.name = 'TrustSupport'
_addon.author = 'MogSafe'
_addon.version = '0.1.0-dev'
_addon.commands = {'trustsupport', 'tsup', 'ts'}

local config = require('config')
local resources = require('resources')
local card_assets = require('resources/card_assets')
local trust_state = require('core/trust_state')
local command_adapter = require('core/commands')

local defaults = {
    icon = true,
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
    get_info = windower.ffxi.get_info,
    get_spells = windower.ffxi.get_spells,
    get_spell_recasts = windower.ffxi.get_spell_recasts,
    get_party = windower.ffxi.get_party,
    get_key_items = windower.ffxi.get_key_items,
})

local commands = command_adapter.new(state, message)

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

windower.register_event('login', 'logout', 'zone change', function()
    state:refresh()
end)
