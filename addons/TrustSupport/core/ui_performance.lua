local Performance = {}
Performance.__index = Performance

function Performance.new(options)
    options = options or {}
    local addon_path = tostring(options.addon_path or '')
    if addon_path ~= '' and not addon_path:match('[\\/]$') then
        addon_path = addon_path .. '/'
    end
    return setmetatable({
        wall_clock = options.wall_clock or os.clock,
        queue_trace = options.queue_trace or function() end,
        message = options.message or function() end,
        log_paths = {
            addon_path .. 'data/ui-performance.log',
            addon_path .. 'ui-performance.log',
        },
    }, Performance)
end

function Performance:trace(report)
    for _, path in ipairs(self.log_paths) do
        local file = io.open(path, 'a')
        if file then
            file:write(('%s wall=%.3f %s\n'):format(
                os.date('%Y-%m-%d %H:%M:%S'), self.wall_clock(),
                tostring(report)))
            file:close()
            return
        end
    end
    self.queue_trace('ui_performance', report)
end

function Performance:handle(ui, value)
    if value == 'on' then
        ui:set_performance_diagnostics(true)
        self.message('UI performance diagnostics enabled.')
    elseif value == 'off' then
        local report = ui:performance_report()
        self:trace(report)
        ui:set_performance_diagnostics(false)
        self.message(('UI performance diagnostics disabled. %s'):format(report))
    elseif value == 'report' or not value then
        local report = ui:performance_report()
        self:trace(report)
        self.message(report)
    else
        self.message('Usage: //tsup perf <on|off|report>')
    end
end

return Performance
