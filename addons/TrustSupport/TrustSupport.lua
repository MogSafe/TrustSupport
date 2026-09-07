_addon.name = 'TrustSupport'
_addon.author = 'MogSafe'
_addon.version = '0.1.0-dev'
_addon.commands = {'trustsupport', 'tsup', 'ts'}

local config = require('config')

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

local function show_help()
    message('Commands:')
    message('//ts - toggle the Trust Support window (UI pending)')
    message('//ts icon on|off - show or hide the launcher icon')
    message('//ts help - show this command list')
end

windower.register_event('addon command', function(command, value)
    command = command and command:lower() or 'toggle'
    value = value and value:lower() or nil

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

    if command == 'help' then
        show_help()
        return
    end

    if command == 'toggle' then
        message('The party-selection UI is not implemented yet.')
        return
    end

    show_help()
end)

windower.register_event('load', function()
    message('Development scaffold loaded. Use //ts help for commands.')
end)
