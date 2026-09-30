package.path = './addons/TrustSupport/?.lua;' .. package.path
local store = require('core/settings_store')
local presets = require('core/presets')
local defaults = {icon=true, ui={x=220, mode='expanded'}, summon={max_attempts=2},
    dialogue={mode='always'}, presets=presets.new_settings()}
local files, faults = {}, {}
local fs = {}
function fs.exists(path) return files[path] ~= nil end
function fs.read(path) if faults.read then return nil, 'read failed' end; return files[path], 'missing' end
function fs.mkdir() if faults.mkdir then return false, 'mkdir failed' end; return true end
function fs.write(path, bytes)
    if faults.write then return false, 'write failed' end
    files[path] = faults.truncate and bytes:sub(1, 10) or bytes
    return true
end
function fs.remove(path) if faults.remove then return false, 'remove failed' end; files[path]=nil; return true end
function fs.rename(from, to)
    if faults.rename and faults.rename(from, to) then return false, 'rename failed' end
    if not files[from] or files[to] then return false, 'invalid rename' end
    files[to], files[from] = files[from], nil
    return true
end
local function repository() return store.new({defaults=defaults, fs=fs}) end
local a, b = repository(), repository()
assert(store.identity({logged_in=true, server=15}, {name='Alice'}) == '15/alice')
assert(not store.identity({logged_in=false, server=15}, {name='Alice'}))
assert(not store.identity({logged_in=true}, {name='Alice'}))
assert(not store.identity({logged_in=true, server=15}, {name='../escape'}))
local legacy = [[<?xml version="1.1"?>
<settings><global><icon>false</icon><presets><selected>8</selected><slots>
<slot_1><1><id>907</id><name>Lion</name></1></slot_1>
<slot_8><1><id>909</id><name>Mihli Aliapoh</name></1></slot_8>
</slots></presets></global><alice><ui><x>99</x></ui></alice></settings>]]
files['data/settings.xml'] = legacy
local alice = assert(a:load('15/alice', 'alice'))
local bob = assert(b:load('15/bob', 'bob'))
assert(alice.icon == false and alice.ui.x == 99 and bob.ui.x == 220)
assert(alice.presets.selected == 8 and alice.presets.compact_selected == 8)
assert(alice.presets.slots.slot_1[1].name == 'Lion')
assert(alice.presets.slots.slot_8[1].id == 909 and #alice.presets.slots.slot_10 == 0)
local ap, bp = a:path('15/alice'), b:path('15/bob')
alice.ui.x, alice.presets.compact_selected = 55, 1
alice.presets.slots.slot_10 = {presets.member(951, 'Rahal')}
assert(a:save('15/alice', alice))
bob.ui.x, bob.presets.selected = 500, 6
bob.presets.slots.slot_1 = {}
assert(b:save('15/bob', bob))
alice, bob = assert(repository():load('15/alice','alice')), assert(repository():load('15/bob','bob'))
assert(alice.ui.x == 55 and alice.presets.compact_selected == 1 and alice.presets.selected == 8)
assert(alice.presets.slots.slot_10[1].id == 951 and #bob.presets.slots.slot_1 == 0)
assert(bob.ui.x == 500 and bob.presets.selected == 6)
assert(files['data/settings.xml'] == legacy, 'migration must never rewrite legacy settings')
local other_server = assert(a:load('16/alice','alice'))
assert(other_server.ui.x == 99, 'same name on another server must have its own profile')
local before = files[ap]
files['data/settings.xml'] = '<broken>'
assert(a:load('15/alice','alice'), 'existing profiles must not reread legacy settings')
assert(not a:load('15/newcharacter','newcharacter'), 'malformed legacy file must not seed defaults')
files['data/settings.xml'] = legacy
for _, fault in ipairs({'mkdir','write','truncate','remove'}) do
    faults[fault] = true
    assert(not a:save('15/alice', alice), fault)
    assert(files[ap] == before, 'failure must preserve previous profile: ' .. fault)
    faults[fault] = nil
end
faults.rename = function(from) return from == ap end
assert(not a:save('15/alice', alice)); assert(files[ap] == before)
faults.rename = function(from) return from == ap .. '.pending' end
assert(not a:save('15/alice', alice)); assert(files[ap] == before, 'failed promotion must roll back')
faults.rename = nil
assert(a:save('15/alice', alice))
files[ap] = '<corrupt>'
local recovered, err, notice = a:load('15/alice','alice')
assert(recovered and notice and files[ap .. '.corrupt'] == '<corrupt>', tostring(err))
files[ap] = nil
assert(a:load('15/alice','alice'), 'backup must recover an interrupted replacement')
local broken_path = a:path('15/broken')
files[broken_path] = '<bad>'
assert(not a:load('15/broken','broken')); assert(files[broken_path] == '<bad>')
files[broken_path .. '.bak'] = '<also-bad>'
assert(not a:load('15/broken','broken'))
local unicode = 'A & B <C> "quoted" apostrophe\' and ]]> end'
local encoded = store.encode({string=unicode, numeric_string='123', empty='', bool=false, number=2,
    list={{name='Lion', id=907}}})
local decoded = assert(store.decode(encoded)).global
assert(decoded.string == unicode and decoded.numeric_string == '123' and decoded.empty == '')
assert(decoded.bool == false and decoded.number == 2 and decoded.list['1'].id == 907)
assert(not store.decode('<settings><global></settings>'))
assert(not store.decode('<settings><global/><global/></settings>'))
assert(not store.decode('<!DOCTYPE settings><settings><global/></settings>'))
assert(store.decode('<settings><global><name>A &amp; B &#65;</name></global></settings>').global.name == 'A & B A')
-- Preserve explicit empty per-character slots rather than inheriting contents.
files['data/settings.xml'] = legacy:gsub('<alice>', '<alice><presets><slots><slot_1/></slots></presets>')
files[a:path('17/alice')] = nil
assert(#assert(a:load('17/alice','alice')).presets.slots.slot_1 == 0)
-- Both failed promotion and failed rollback leave a recoverable backup.
local original = files[ap]
faults.rename = function(from) return from == ap .. '.pending' or from == ap .. '.bak' end
assert(not a:save('15/alice', alice))
assert(not files[ap] and files[ap .. '.bak'] == original)
faults.rename = nil
assert(a:load('15/alice','alice'))
-- An interrupted first write has no backup; a complete pending file can recover.
local interrupted = a:path('15/interrupted')
files[interrupted .. '.pending'] = store.encode(alice)
assert(a:load('15/interrupted','interrupted'))
-- Explicit filesystem exceptions must be reported, not crash the addon.
local normal_write = fs.write
fs.write = function() error('unexpected disk failure') end
assert(not a:save('15/alice', alice))
fs.write = normal_write
files = {}
local fresh = assert(a:load('15/fresh','fresh'))
assert(fresh.icon and #fresh.presets.slots.slot_10 == 0)
io.write('Settings store tests passed.\n')
