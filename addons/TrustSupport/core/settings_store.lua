-- Independent character profiles. No config.load/save or automatic event hooks.
local presets = require('core/presets')
local store = {}
local Repository = {}
Repository.__index = Repository

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

local function overlay(base, value)
    for key, child in pairs(value or {}) do
        if type(child) == 'table' and next(child) ~= nil and type(base[key]) == 'table' then
            overlay(base[key], child)
        else base[key] = copy(child) end
    end
    return base
end

-- Settings XML is a deliberately small data format: tags, scalars, comments,
-- and CDATA. Never evaluate Lua, DTDs, entities from files, or external content.
local function unescape(s)
    return (s:gsub('&([^;]+);', function(entity)
        local named = {amp='&', lt='<', gt='>', quot='"', apos="'"}
        if named[entity] then return named[entity] end
        local code = entity:match('^#x(%x+)$')
        code = code and tonumber(code, 16) or tonumber(entity:match('^#(%d+)$'))
        assert(code and code > 0 and code <= 0x10ffff
            and not (code >= 0xd800 and code <= 0xdfff), 'Invalid XML entity')
        if code < 128 then return string.char(code) end
        if code < 2048 then return string.char(192 + math.floor(code / 64), 128 + code % 64) end
        if code < 65536 then return string.char(224 + math.floor(code / 4096),
            128 + math.floor(code / 64) % 64, 128 + code % 64) end
        return string.char(240 + math.floor(code / 262144),
            128 + math.floor(code / 4096) % 64, 128 + math.floor(code / 64) % 64, 128 + code % 64)
    end))
end

function store.decode(text)
    local ok, result = pcall(function()
        assert(type(text) == 'string' and #text <= 4 * 1024 * 1024, 'Invalid settings document size')
        text = text:gsub('^\239\187\191', '')
        local stack, root, position = {}, nil, 1
        local function content(value, literal)
            local node = stack[#stack]
            if not node then assert(not value:match('%S'), 'Text outside settings root'); return end
            if literal then node.literal = true end
            node.text = node.text .. (literal and value or unescape(value))
        end
        local function finish(node)
            local value
            if node.has_children then
                assert(not node.text:match('%S'), 'Mixed settings content')
                value = node.values
            elseif node.literal then value = node.text
            else
                local scalar = node.text:match('^%s*(.-)%s*$')
                if scalar == '' then value = {}
                elseif scalar:lower() == 'true' then value = true
                elseif scalar:lower() == 'false' then value = false
                else value = tonumber(scalar) or scalar end
            end
            local parent = stack[#stack]
            if parent then
                assert(parent.values[node.name] == nil, 'Duplicate settings key: ' .. node.name)
                parent.has_children = true
                parent.values[node.name] = value
            else
                assert(root == nil and node.name == 'settings' and type(value) == 'table', 'Invalid settings root')
                root = value
            end
        end
        while position <= #text do
            local at = text:find('<', position, true)
            if not at then content(text:sub(position)); break end
            content(text:sub(position, at - 1))
            if text:sub(at, at + 3) == '<!--' then
                local last = assert(text:find('-->', at + 4, true), 'Unclosed XML comment')
                position = last + 3
            elseif text:sub(at, at + 8) == '<![CDATA[' then
                assert(#stack > 0, 'CDATA outside settings root')
                local last = assert(text:find(']]>', at + 9, true), 'Unclosed CDATA')
                content(text:sub(at + 9, last - 1), true)
                position = last + 3
            elseif text:sub(at, at + 4) == '<?xml' then
                assert(not root and #stack == 0, 'Unexpected XML declaration')
                position = assert(text:find('?>', at + 5, true), 'Unclosed XML declaration') + 2
            else
                local last = assert(text:find('>', at + 1, true), 'Unclosed XML tag')
                local tag = text:sub(at + 1, last - 1)
                local close = tag:match('^/([%w_%-]+)%s*$')
                if close then
                    local node = table.remove(stack)
                    assert(node and node.name == close:lower(), 'Mismatched XML tag')
                    finish(node)
                else
                    local name, tail = tag:match('^([%w_%-]+)(.-)$')
                    assert(name and (tail:match('^%s*$') or tail:match('^%s*/%s*$')), 'Unsupported XML tag')
                    assert(#stack < 32, 'Settings nesting too deep')
                    local node = {name=name:lower(), values={}, text=''}
                    if tail:find('/', 1, true) then finish(node)
                    else stack[#stack + 1] = node end
                end
                position = last + 1
            end
        end
        assert(#stack == 0 and root, 'Incomplete settings XML')
        return root
    end)
    if not ok then return nil, tostring(result) end
    return result
end

function store.encode(settings)
    local lines = {'<?xml version="1.0" encoding="UTF-8"?>', '<settings>', '  <global>'}
    local function emit(values, depth)
        assert(depth < 32, 'Settings nesting too deep')
        local keys = {}
        for key in pairs(values) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            local value, name = values[key], tostring(key)
            assert(name:match('^[%w_%-]+$'), 'Invalid settings key')
            local pad = string.rep('  ', depth)
            if type(value) == 'table' then
                lines[#lines + 1] = pad .. '<' .. name .. '>'
                emit(value, depth + 1)
                lines[#lines + 1] = pad .. '</' .. name .. '>'
            else
                assert(type(value) == 'string' or type(value) == 'boolean' or type(value) == 'number', 'Invalid settings value')
                local encoded = tostring(value)
                if type(value) == 'string' then
                    encoded = '<![CDATA[' .. value:gsub(']]>', ']]]]><![CDATA[>') .. ']]>'
                elseif type(value) == 'number' then
                    assert(value == value and value ~= math.huge and value ~= -math.huge, 'Invalid settings number')
                end
                lines[#lines + 1] = pad .. '<' .. name .. '>' .. encoded .. '</' .. name .. '>'
            end
        end
    end
    emit(settings, 2)
    lines[#lines + 1] = '  </global>'
    lines[#lines + 1] = '</settings>'
    return table.concat(lines, '\n') .. '\n'
end

function store.identity(info, player)
    if not info or not info.logged_in or not player then return nil end
    local server, name = tonumber(info.server), player.name
    if not server or server < 0 or server ~= math.floor(server)
            or type(name) ~= 'string' or not name:match('^[A-Za-z]+$') then return nil end
    return tostring(server) .. '/' .. name:lower(), name:lower()
end

function store.new(options)
    return setmetatable({defaults=copy(options.defaults), fs=options.fs,
        root=options.root or 'data/characters', legacy=options.legacy or 'data/settings.xml'}, Repository)
end

function Repository:path(identity)
    assert(type(identity) == 'string' and identity:match('^%d+/[a-z]+$'), 'Invalid character identity')
    return self.root .. '/' .. identity .. '/settings.xml'
end

function Repository:normalize(document, character)
    assert(type(document.global) == 'table', 'Missing global settings section')
    local result = overlay(copy(self.defaults), document.global)
    if character and document[character] ~= nil then
        assert(type(document[character]) == 'table', 'Invalid character settings section')
        overlay(result, document[character])
    end
    local function validate(value, defaults)
        for key, default in pairs(defaults) do
            local item = value[key]
            if item == nil then value[key] = copy(default); item = value[key] end
            if type(default) == 'table' then
                assert(type(item) == 'table', 'Invalid settings section: ' .. key)
                validate(item, default)
            elseif type(default) == 'string' and type(item) == 'table' and next(item) == nil then
                value[key] = ''
            else assert(type(item) == type(default), 'Invalid settings value: ' .. key) end
        end
    end
    -- Preset normalization already handles numeric strings and legacy arrays.
    local preset_data = result.presets
    assert(type(preset_data) == 'table', 'Invalid presets section')
    result.presets = copy(self.defaults.presets)
    validate(result, self.defaults)
    result.presets = presets.normalize_settings(preset_data)
    return result
end

function Repository:read(path, character)
    local bytes, err = self.fs.read(path)
    if not bytes then return nil, err or ('Cannot read ' .. path) end
    local document, parse_error = store.decode(bytes)
    if not document then return nil, parse_error end
    local ok, settings = pcall(self.normalize, self, document, character)
    if not ok then return nil, tostring(settings) end
    return settings
end

function Repository:_save(identity, settings)
    local path = self:path(identity)
    local pending, backup = path .. '.pending', path .. '.bak'
    local ok, bytes = pcall(store.encode, settings)
    if not ok then return false, bytes end
    local success, err = self.fs.mkdir(path:match('^(.*)/[^/]+$'))
    if not success then return false, err end
    success, err = self.fs.write(pending, bytes)
    if not success then return false, err end
    local verified, verify_error = self:read(pending)
    if not verified then return false, verify_error end
    local written = self.fs.read(pending)
    if written ~= bytes then return false, 'Settings verification mismatch' end
    local had_target = self.fs.exists(path)
    if had_target then
        if self.fs.exists(backup) then
            success, err = self.fs.remove(backup)
            if not success then return false, err end
        end
        success, err = self.fs.rename(path, backup)
        if not success then return false, err end
    end
    success, err = self.fs.rename(pending, path)
    if not success then
        if had_target then
            local restored, restore_error = self.fs.rename(backup, path)
            if not restored then err = tostring(err) .. '; backup retained: ' .. tostring(restore_error) end
        end
        return false, err
    end
    return true
end

function Repository:_load(identity, character)
    local path = self:path(identity)
    local exists = self.fs.exists(path)
    local settings, err
    if exists then
        settings, err = self:read(path)
        if settings then return settings end
    end
    for _, suffix in ipairs({'.bak', '.pending'}) do
        if self.fs.exists(path .. suffix) then
            local recovered, recovery_error = self:read(path .. suffix)
            if recovered then
                if exists then
                    local quarantine, index = path .. '.corrupt', 0
                    while self.fs.exists(quarantine) do index = index + 1; quarantine = path .. '.corrupt.' .. index end
                    local moved, move_error = self.fs.rename(path, quarantine)
                    if not moved then return nil, move_error end
                end
                local saved, save_error = self:save(identity, recovered)
                if not saved then return nil, save_error end
                return recovered, nil, 'Recovered character settings from ' .. suffix .. '.'
            end
            err = err or recovery_error
        end
    end
    if exists or err then return nil, err or 'Unreadable character settings' end
    if self.fs.exists(self.legacy) then
        settings, err = self:read(self.legacy, character)
        if not settings then return nil, err end
    else settings = copy(self.defaults) end
    settings.presets = presets.normalize_settings(settings.presets)
    local saved, save_error = self:save(identity, settings)
    if not saved then return nil, save_error end
    return settings
end

-- Convert thrown filesystem errors into explicit results, too. Any interrupted
-- promotion leaves the prior file at the target or the recovery backup.
function Repository:save(identity, settings)
    local ok, saved, err = pcall(self._save, self, identity, settings)
    if not ok then return false, tostring(saved) end
    return saved, err
end

function Repository:load(identity, character)
    local ok, settings, err, notice = pcall(self._load, self, identity, character)
    if not ok then return nil, tostring(settings) end
    return settings, err, notice
end

-- Runtime adapter; test repositories use in-memory injected operations.
function store.filesystem(root, api)
    local function absolute(path) return root .. path end
    return {
        exists=function(path) return api.file_exists(absolute(path)) end,
        mkdir=function(path)
            local current = root:gsub('[\\/]$', '')
            for segment in path:gmatch('[^/]+') do
                current = current .. '/' .. segment
                if not api.dir_exists(current) then
                    local ok, err = api.create_dir(current)
                    if not ok and not api.dir_exists(current) then return false, err or ('Cannot create ' .. current) end
                end
            end
            return true
        end,
        read=function(path)
            local file, err = io.open(absolute(path), 'rb')
            if not file then return nil, err end
            local bytes = file:read('*a'); file:close()
            return bytes
        end,
        write=function(path, bytes)
            local file, err = io.open(absolute(path), 'wb')
            if not file then return false, err end
            local ok, write_error = file:write(bytes)
            local closed, close_error = file:close()
            return ok ~= nil and closed ~= nil, write_error or close_error
        end,
        rename=function(from, to) return os.rename(absolute(from), absolute(to)) end,
        remove=function(path) return os.remove(absolute(path)) end,
    }
end

return store
