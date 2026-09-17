package.path = table.concat({
    './addons/TrustSupport/?.lua',
    './addons/TrustSupport/?/init.lua',
    package.path,
}, ';')

local trust_ui = require('ui/trust_ui')
local presets = require('core/presets')
local command_module = require('core/commands')

local created = 0
local destroyed = 0
local image_settings = {}
local rendered_text = {}
local text_resizes = 0
local extent_calls = 0
local show_calls = 0
local hide_calls = 0
local clock_now = 100

local function object(value, initial_size, is_text)
    created = created + 1
    local creation_index = created
    local current_size = tonumber(initial_size) or 12
    return {
        creation_index = creation_index,
        show = function() show_calls = show_calls + 1 end,
        hide = function() hide_calls = hide_calls + 1 end,
        pos = function() end,
        size = function(_, next_size)
            current_size = next_size
            if is_text then
                text_resizes = text_resizes + 1
            end
        end,
        text = function(_, next_value)
            value = next_value
            rendered_text[#rendered_text + 1] = next_value
        end,
        font = function() end,
        color = function() end,
        alpha = function() end,
        bold = function() end,
        stroke_width = function() end,
        stroke_color = function() end,
        stroke_alpha = function() end,
        fit = function() end,
        path = function() end,
        extents = function()
            extent_calls = extent_calls + 1
            return #tostring(value or '') * current_size * 0.7, current_size
        end,
        destroy = function()
            destroyed = destroyed + 1
        end,
    }
end

local images = {new=function(_, settings)
    image_settings[#image_settings + 1] = settings
    return object(nil, nil, false)
end}
local texts = {new=function(value, settings)
    rendered_text[#rendered_text + 1] = value
    return object(value, settings and settings.text and settings.text.size, true)
end}

local entries = {
    {
        id=909,
        icon_id=909,
        en='Mihli Aliapoh',
        identity_key='mihliapoh',
        learned=true,
        recast_raw=0,
        cooldown_seconds=0,
        in_party=false,
        active_exact=false,
        card='assets/cards/mihli_aliapoh.png',
        metadata={role='healer', affiliation='aht_urhgan'},
    },
    {
        id=896,
        icon_id=896,
        en='Valaineral',
        identity_key='Valaineral',
        learned=true,
        recast_raw=0,
        cooldown_seconds=0,
        in_party=true,
        active_exact=true,
        card='assets/cards/valaineral.png',
        metadata={role='tank', affiliation='san_doria'},
    },
    {
        id=1009,
        icon_id=1009,
        en='Mihli II',
        identity_key='mihliapoh',
        learned=true,
        recast_raw=0,
        cooldown_seconds=0,
        in_party=false,
        active_exact=false,
        card='assets/cards/mihli_aliapoh.png',
        metadata={role='healer', affiliation='aht_urhgan'},
    },
}

local pending = {}
local dismissals = {}
local state = {
    catalog=entries,
    by_id={[909]=entries[1], [896]=entries[2], [1009]=entries[3]},
    source_status={spells=true, recasts=true, party=true, key_items=true},
    party_trusts={{slot=1, id=896, name='Valaineral', identity_key='Valaineral', trust=entries[2]}},
    max_trusts=4,
    other_members=0,
}

function state:refresh() return self:snapshot() end
function state:roster() return entries end
function state:pending_entries() return pending end
function state:pending_dismissal_records()
    local result = {}
    for _, record in ipairs(self.party_trusts) do
        if dismissals[record.identity_key] then
            result[#result + 1] = record
        end
    end
    return result
end
function state:is_pending_dismissal(value)
    local key = type(value) == 'table' and (value.identity_key
        or value.trust and value.trust.identity_key) or tostring(value)
    return dismissals[key] == true
end
function state:snapshot()
    local active = #self.party_trusts
    local dismissal_count = 0
    for _ in pairs(dismissals) do dismissal_count = dismissal_count + 1 end
    return {
        logged_in=true,
        sources={
            info=self.source_status.info,
            spells=self.source_status.spells,
            recasts=self.source_status.recasts,
            party=self.source_status.party,
            key_items=self.source_status.key_items,
        },
        max_trusts=self.max_trusts,
        other_members=self.other_members,
        trust_capacity=math.max(0, self.max_trusts - self.other_members),
        party_count=active + 1,
        active_trusts=active,
        pending=#pending,
        pending_dismissals=dismissal_count,
        remaining_slots=4 - active + dismissal_count - #pending,
        stats={learned=2},
    }
end
function state:replace_plan(plan)
    local next_pending = {}
    local next_dismissals = {}
    for _, operation in ipairs(plan.dismiss or {}) do
        local record = operation.active
        local key = record and (record.identity_key
            or record.trust and record.trust.identity_key)
        if key then next_dismissals[key] = true end
    end
    for _, operation in ipairs(plan.summon or {}) do
        local entry = operation.entry or self.by_id[operation.id]
        if entry then next_pending[#next_pending + 1] = entry end
    end
    pending = next_pending
    dismissals = next_dismissals
    local dismissal_count = 0
    for _ in pairs(next_dismissals) do
        dismissal_count = dismissal_count + 1
    end
    return true, nil, #next_pending, dismissal_count
end

local persisted_settings = {
    icon=true,
    ui={x=100, y=100, scale=0.78},
    presets=presets.new_settings(),
}
local saved = 0
local command_calls = {}
local commands = {}
function commands:handle(args)
    command_calls[#command_calls + 1] = args
    if args[1] == 'select' then
        pending = {entries[1]}
    elseif args[1] == 'remove' or args[1] == 'clear' then
        pending = {}
        if args[1] == 'clear' then dismissals = {} end
    elseif args[1] == 'dismiss' then
        dismissals.Valaineral = true
    elseif args[1] == 'keep' then
        dismissals.Valaineral = nil
    elseif args[1] == 'preset' then
        if args[2] == 'select' then
            presets.select(persisted_settings.presets, args[3])
            saved = saved + 1
        elseif args[2] == 'save' then
            local key = presets.slot_key(persisted_settings.presets.selected)
            persisted_settings.presets.slots[key] = {
                presets.member(896, 'Valaineral'),
            }
            saved = saved + 1
        elseif args[2] == 'clear' then
            local ok = presets.clear(persisted_settings.presets)
            assert(ok, 'preset clear command stub must clear the selected slot')
            saved = saved + 1
        end
    end
end

local queue_state = {active=false, status='idle', position=0, total=0}
local queue = {}
function queue:snapshot()
    return queue_state
end

local ui = trust_ui.new({
    state=state,
    commands=commands,
    queue=queue,
    settings=persisted_settings,
    images=images,
    texts=texts,
    addon_path='C:/Windower/addons/TrustSupport/',
    windower_path='C:/Windower',
    file_exists=function() return true end,
    save_settings=function() saved = saved + 1 end,
    clock=function() return clock_now end,
})

function _run_startup_signature_test()
    local original_spells = state.source_status.spells
    local original_learned = entries[1].learned
    local initial = ui:_signature()
    state.source_status.spells = not original_spells
    local source_changed = ui:_signature()
    assert(source_changed ~= initial,
        'preset source readiness must invalidate the UI signature')
    state.source_status.spells = original_spells
    entries[1].learned = not original_learned
    local learned_changed = ui:_signature()
    assert(learned_changed ~= initial,
        'learned Trust availability must invalidate the UI signature')
    entries[1].learned = original_learned
end
_run_startup_signature_test()
_run_startup_signature_test = nil

assert(ui.launcher ~= nil)
assert(ui.keyed_pool.window_frame and ui.keyed_pool.window_frame.main,
    'the expanded frame must be reserved before compact-first preset controls')
assert(ui.keyed_pool.title_surface and ui.keyed_pool.title_surface.main
        and ui.keyed_pool.footer_background
        and ui.keyed_pool.footer_background.main,
    'every expanded shell surface must be reserved before compact-first controls')
assert(image_settings[#image_settings].visible == false,
    'a newly created launcher must remain hidden while its texture loads')
local launcher_created = created
local launcher_warmup_shows = show_calls
ui:tick()
assert(show_calls == launcher_warmup_shows + 1,
    'the preloaded launcher must be revealed on the following prerender')
ui:set_launcher_visible(false)
assert(created == launcher_created and ui.launcher ~= nil,
    'disabling the launcher must retain its preloaded primitive')
ui:set_launcher_visible(true)
assert(created == launcher_created,
    're-enabling the launcher must not recreate its textured primitive')
ui:set_launcher_visible(true)
assert(created == launcher_created,
    'enabling an already-visible launcher must remain idempotent')
ui:open()
assert(ui.visible == true)
assert(ui.mode == 'expanded' and persisted_settings.ui.mode == 'expanded',
    'the first-use presentation mode must default to expanded')
assert(created > 30)
assert(table.concat(rendered_text, '|'):find('SUMMON  0 / 3', 1, true),
    'pending header must show additions that fit the current party plan')
local initial_text = table.concat(rendered_text, '|')
assert(initial_text:find('|Click a |READY|Trust to add it.|', 1, true),
    'the available-slot hint must render one non-overlaid READY label')
assert(ui.object_pool.pending_empty_hint[2].color.r == 139
        and ui.object_pool.pending_empty_hint[2].color.g == 195
        and ui.object_pool.pending_empty_hint[2].color.b == 171,
    'READY in the staging hint must use the restrained green treatment')
assert(ui.object_pool.pending_empty_hint[3].x
        - ui.object_pool.pending_empty_hint[2].x
            >= math.floor(72 * ui.scale + 0.5),
    'the suffix must begin after READY\'s fixed-width status column')
assert(initial_text:find('|EMPTY|', 1, true))
assert(initial_text:find('|READY|', 1, true))
assert(initial_text:find('|DISMISS|', 1, true),
    'an active Trust must show a singular dismiss action button')
do
    local active_role = ui.keyed_pool.active_card_role_text['896']
    assert(active_role and active_role.color.r == 220
            and active_role.color.g == 230 and active_role.color.b == 234
            and active_role.color.a == 255,
        'small active-card role labels must retain AA-oriented opaque contrast')

    -- An expanded window also receives incomplete party/capacity snapshots
    -- while zoning. Present that as a neutral refresh instead of claiming
    -- human members occupy all available Trust positions.
    local expanded_zone_text_start = #rendered_text
    ui:on_zone_change()
    local expanded_zone_text = table.concat(
        rendered_text, '|', expanded_zone_text_start + 1)
    assert(expanded_zone_text:find('REFRESHING PARTY STATUS', 1, true)
            and expanded_zone_text:find('WAITING FOR PARTY DATA', 1, true)
            and not expanded_zone_text:find('OTHER PARTY MEMBERS', 1, true),
        'expanded zoning must render neutral transition copy, not capacity claims')
    state.source_status.party = false
    ui:render(false)
    state.source_status.party = true
    local settled_text_start = #rendered_text
    for _ = 1, 4 do
        clock_now = clock_now + 0.5
        ui:tick()
    end
    assert(ui.party_zone_transition == nil,
        'expanded zone transition must end after party data becomes ready')
    local settled_text = table.concat(rendered_text, '|', settled_text_start + 1)
    assert(settled_text:find('Valaineral', 1, true),
        'finishing a zone transition must redraw an otherwise unchanged party')
end
queue_state = {
    active=true,
    phase='summoning',
    current_id=entries[1].id,
    current_identity_key=entries[1].identity_key,
    current_name=entries[1].en,
}
assert(ui:_is_action_target(entries[1])
        and not ui:_is_action_target(entries[2]),
    'summon pulse must target only the Trust currently being summoned')
assert(ui:_action_fade_target(entries[1], true)
        and not ui:_action_fade_target(entries[1], false),
    'summoning must fade only the staged preview, not the full party card')
assert(ui:_action_pulse_alpha() >= 20 and ui:_action_pulse_alpha() <= 78,
    'action pulse alpha must stay within a readable range')
local summon_queue, summon_progress = ui:_action_progress()
assert(summon_progress >= 0 and summon_progress <= 0.9,
    'summon strip progress must remain an estimate below completion')
assert(ui:_action_strip_fraction(entries[1], summon_queue, summon_progress)
        == summon_progress,
    'summon strip must grow toward its estimated leading edge')
queue_state = {
    active=true,
    phase='dismissing',
    current_identity_key=entries[2].identity_key,
    current_name=entries[2].en,
}
local dismiss_queue, dismiss_progress = ui:_action_progress()
assert(ui:_action_strip_fraction(entries[2], dismiss_queue, dismiss_progress)
        == 1 - dismiss_progress,
    'dismiss strip must shrink from its estimated leading edge')
assert(ui:_is_action_target(entries[2])
        and not ui:_is_action_target(entries[1]),
    'dismiss pulse must target only the Trust currently being dismissed')
assert(ui:_action_fade_target(entries[2], false)
        and not ui:_action_fade_target(entries[2], true),
    'dismissal must fade only the full party card')
queue_state = {active=false, status='idle', position=0, total=0}
local circle_button_count = 0
local window_frame_count = 0
for _, settings in ipairs(image_settings) do
    local texture = settings.texture
    if texture and texture.path:find('close%-glyph%.png') then
        circle_button_count = circle_button_count + 1
        assert(settings.color.alpha == 255,
            'close controls must use a transparent glyph texture')
    elseif texture and texture.path:find('window%-frame%.png') then
        window_frame_count = window_frame_count + 1
    end
end
assert(circle_button_count >= 1,
    'the title bar must retain its circular close control')
assert(window_frame_count >= 1,
    'the window must render its rounded transparent frame asset')
local close_box = nil
for _, box in ipairs(ui.hitboxes) do
    if box.hover_key and box.x == 1120 - 48 and box.y == 12 then
        close_box = box
        break
    end
end
assert(close_box, 'the title close control must expose a hover target')
local close_x = ui.x + math.floor((close_box.x + close_box.width / 2)
    * ui.scale + 0.5)
local close_y = ui.y + math.floor((close_box.y + close_box.height / 2)
    * ui.scale + 0.5)
ui:on_mouse(0, close_x, close_y, 0, false)
assert(ui.hover_key == close_box.hover_key
        and ui.object_pool.circle_control[1].path:find('close%-button%-subtle%.png'),
    'hovering a close control must reveal its subtle circular backing')
ui.pressed_key = close_box.hover_key
ui:render(false)
assert(ui.object_pool.circle_control[1].path:find('close%-button%-pressed%.png'),
    'pressing a close control must reveal its pressed treatment')
ui.pressed_key = nil
ui:render(false)
assert(ui.object_pool.circle_control[1].path:find('close%-button%-subtle%.png'),
    'releasing a hovered close control must restore its hover treatment')
ui:on_mouse(0, ui.x - 10, ui.y - 10, 0, false)
assert(ui.hover_key == nil
        and ui.object_pool.circle_control[1].path:find('close%-glyph%.png'),
    'leaving a close control must restore its borderless glyph')
assert(not initial_text:find('PARTY SELECTION', 1, true),
    'the title bar must omit the redundant party-selection subtitle')

function _run_obscured_launcher_test()
    local original_x = ui.launcher_x
    local original_y = ui.launcher_y
    ui.launcher_x = ui.x + math.floor(600 * ui.scale + 0.5)
    ui.launcher_y = ui.y + math.floor(18 * ui.scale + 0.5)
    ui.launcher:pos(ui.launcher_x, ui.launcher_y)
    ui.launcher_pressed_icon:pos(ui.launcher_x, ui.launcher_y)
    local pointer_x = ui.launcher_x + 14
    local pointer_y = ui.launcher_y + 14
    ui:on_mouse(0, pointer_x, pointer_y, 0, false)
    assert(ui.launcher_hovered == false,
        'a launcher beneath the expanded window must not receive hover')
    assert(ui:on_mouse(1, pointer_x, pointer_y, 0, false) == true)
    assert(ui.launcher_drag == nil,
        'a launcher beneath the expanded window must not capture presses')
    assert(ui:on_mouse(2, pointer_x, pointer_y, 0, false) == true)
    assert(ui.visible == true,
        'pressing above an obscured launcher must not dismiss the window')
    ui.launcher_x = original_x
    ui.launcher_y = original_y
    ui.launcher:pos(original_x, original_y)
    ui.launcher_pressed_icon:pos(original_x, original_y)
    assert(ui:_launcher_contains(original_x + 14, original_y + 14),
        'a launcher visible outside the expanded window must remain interactive')
end
_run_obscured_launcher_test()
_run_obscured_launcher_test = nil

assert(not initial_text:find(' learned  | ', 1, true),
    'the idle footer must omit learned, active, and open summary text')
assert(not initial_text:find('//ts search', 1, true))
assert(not initial_text:find('EMPTY TRUST SLOT', 1, true))
assert(not initial_text:find('ACTIVE 1', 1, true),
    'active-card badges must not cover the portrait')
assert(initial_text:find('PRESETS', 1, true),
    'the current-party header must expose the preset controls')
assert(not initial_text:find('1 / 4', 1, true),
    'the current-party header must omit the redundant party count')
assert(ui.object_pool.preset_load_button_disabled_rect
        and ui.object_pool.preset_load_button_disabled_rect[1].visible,
    'LOAD must be disabled while the selected preset slot is empty')
assert(ui.object_pool.preset_save_button_enabled_rect
        and ui.object_pool.preset_save_button_enabled_rect[1].visible,
    'SAVE must be enabled when the confirmed party is not empty')

local preset_slot_2_x = ui.x + math.floor((748 + 13) * ui.scale + 0.5)
local preset_control_y = ui.y + math.floor((99 + 13) * ui.scale + 0.5)
assert(ui:on_mouse(1, preset_slot_2_x, preset_control_y, 0, false) == true)
assert(ui:on_mouse(2, preset_slot_2_x, preset_control_y, 0, false) == true)
assert(persisted_settings.presets.selected == 2,
    'clicking a preset slot must select it without changing the party')

local preset_save_x = ui.x + math.floor((946 + 37) * ui.scale + 0.5)
assert(ui:on_mouse(1, preset_save_x, preset_control_y, 0, false) == true)
assert(ui:on_mouse(2, preset_save_x, preset_control_y, 0, false) == true)
assert(#persisted_settings.presets.slots.slot_2 == 1,
    'SAVE must populate the selected slot')
assert(ui.object_pool.preset_match_marker
        and ui.object_pool.preset_match_marker[1].visible,
    'the saved party matching the authoritative party must use the matched marker')
assert(ui.object_pool.preset_load_button_enabled_rect
        and ui.object_pool.preset_load_button_enabled_rect[1].visible,
    'LOAD must become enabled for an occupied selected slot')
ui.hover_key = nil
ui:render(false)
assert(ui.object_pool.preset_load_button_enabled_rect[2].color.r == 93
        and ui.object_pool.preset_save_button_enabled_rect[2].color.r == 93,
    'preset capsules must not appear hovered without their own hover key')

ui.hover_key = 'preset_slot:3'
ui:render(false)
local hovered_slot_text = nil
for _, record in ipairs(ui.objects) do
    if record.value == '3' and record.color and record.x > 600 and record.y < 100 then
        hovered_slot_text = record.color
    end
end
assert(hovered_slot_text and hovered_slot_text.r == 210,
    'hovering a preset slot must update its slot-number text color')
ui.hover_key = nil
ui:render(false)

local preset_load_x = ui.x + math.floor((872 + 34) * ui.scale + 0.5)
local calls_before_load = #command_calls
assert(ui:on_mouse(1, preset_load_x, preset_control_y, 0, false) == true)
assert(ui:on_mouse(2, preset_load_x, preset_control_y, 0, false) == true)
assert(#command_calls == calls_before_load + 1
        and command_calls[#command_calls][1] == 'preset'
        and command_calls[#command_calls][2] == 'load',
    'LOAD must delegate to the validated preset command path')

-- Saved status tabs must survive the exact selection history that previously let
-- newly created slot backgrounds cover them: two occupied slots, followed by
-- selecting each occupied slot and then an empty third slot.
persisted_settings.presets.slots.slot_1 = {
    presets.member(909, 'Mihli Aliapoh'),
}
for _, selected_slot in ipairs({1, 2, 3}) do
    assert(presets.select(persisted_settings.presets, selected_slot))
    ui:render(false)
    assert(ui.object_pool.preset_occupied_marker[1].visible,
        'slot 1 saved marker must remain visible when slot '
            .. tostring(selected_slot) .. ' is selected')
    assert(ui.keyed_pool.preset_occupied_marker['1'].visible
            and not ui.keyed_pool.preset_occupied_marker['1:fold:2'],
        'a saved preset must render its status tab as one stable primitive')
    assert(ui.object_pool.preset_occupied_marker[1].color.r == 217
            and ui.object_pool.preset_occupied_marker[1].color.g == 169,
        'an actionable saved preset must use the amber marker')
    assert(ui.object_pool.preset_match_marker[1].visible,
        'slot 2 matched marker must remain visible when slot '
            .. tostring(selected_slot) .. ' is selected')
    assert(ui.keyed_pool.preset_match_marker['2'].visible
            and not ui.keyed_pool.preset_match_marker['2:fold:2'],
        'a matched preset must render its status tab as one stable primitive')
    assert(ui.object_pool.preset_match_marker[1].color.r == 99
            and ui.object_pool.preset_match_marker[1].color.g == 217,
        'an active preset membership match must use the green marker')
end

local lowest_slot_background_depth = math.huge
local highest_slot_background_depth = 0
for kind, records in pairs(ui.object_pool) do
    if kind:find('preset_slot_', 1, true) == 1 then
        for _, record in ipairs(records) do
            lowest_slot_background_depth = math.min(
                lowest_slot_background_depth, record.object.creation_index)
            highest_slot_background_depth = math.max(
                highest_slot_background_depth, record.object.creation_index)
        end
    end
end
assert(ui.object_pool.window_frame[1].object.creation_index
        < lowest_slot_background_depth,
    'every preset border must be created above the complete window frame')
assert(ui.object_pool.preset_occupied_marker[1].object.creation_index
        > highest_slot_background_depth
        and ui.object_pool.preset_match_marker[1].object.creation_index
        > highest_slot_background_depth,
    'every saved marker must be created above every possible slot background')

-- A temporarily unsummonable preset remains selectable but uses a grey saved
-- marker and disables Load. Selecting it displays a short-lived inline reason.
entries[1].recast_raw = 60
assert(presets.select(persisted_settings.presets, 1))
ui:render(false)
assert(ui.object_pool.preset_blocked_marker
        and ui.object_pool.preset_blocked_marker[1].visible,
    'a preset containing a cooldown Trust must use the blocked marker')
assert(ui.object_pool.preset_blocked_marker[1].color.r == 197
        and ui.object_pool.preset_blocked_marker[1].color.g == 206
        and ui.keyed_pool.preset_blocked_marker['1:left'].visible
        and ui.keyed_pool.preset_blocked_marker['1:right'].visible,
    'a blocked preset must use the split high-contrast silver marker')
assert(ui.object_pool.preset_load_button_disabled_rect[1].visible,
    'a temporarily blocked preset must disable its Load control')
assert(ui.object_pool.preset_blocked_marker[1].object.creation_index
        > highest_slot_background_depth,
    'the blocked marker must be created above every preset background')
local preset_slot_1_x = ui.x + math.floor((718 + 13) * ui.scale + 0.5)
local warning_text_start = #rendered_text
assert(ui:on_mouse(1, preset_slot_1_x, preset_control_y, 0, false) == true)
assert(ui:on_mouse(2, preset_slot_1_x, preset_control_y, 0, false) == true)
local warning_text = table.concat(rendered_text, '|', warning_text_start + 1)
assert(warning_text:find('MIHLI ALIAPOH: COOLDOWN', 1, true),
    'selecting a blocked preset must show its inline reason')
assert(ui.preset_warning ~= nil,
    'the footer preset warning must remain active during its hold period')
local warning_in_footer = false
for _, record in ipairs(ui.objects) do
    if record.value == 'MIHLI ALIAPOH: COOLDOWN' and record.y > 500 then
        warning_in_footer = true
    end
end
assert(warning_in_footer,
    'preset warnings must render in the footer message area')
clock_now = clock_now + 4.1
ui.last_refresh = -1
ui:tick()
assert(ui.preset_warning == nil,
    'the inline preset warning must expire after its hold and fade duration')

-- A preset with both a ready missing member and a cooldown member uses the
-- partial marker and remains loadable. The same cooldown-only preset above
-- remains grey because loading it would only dismiss the current party.
local partial_ready_entry = {
    id=951,
    icon_id=951,
    en='Rahal',
    identity_key='rahal',
    learned=true,
    recast_raw=0,
    cooldown_seconds=0,
    in_party=false,
    active_exact=false,
    card='assets/cards/rahal.png',
    metadata={role='tank', affiliation='san_doria'},
}
entries[#entries + 1] = partial_ready_entry
state.by_id[951] = partial_ready_entry
persisted_settings.presets.slots.slot_1 = {
    presets.member(896, 'Valaineral'),
    presets.member(951, 'Rahal'),
    presets.member(909, 'Mihli Aliapoh'),
}
ui:render(false)
assert(ui.object_pool.preset_partial_marker
        and ui.object_pool.preset_partial_marker[1].visible,
    'a useful cooldown-skipping preset load must use the partial marker')
assert(ui.object_pool.preset_load_button_enabled_rect[1].visible,
    'a partial preset with an available member must keep Load enabled')
assert(ui.object_pool.preset_partial_marker[1].color.r == 242
        and ui.object_pool.preset_partial_marker[1].color.g == 167
        and ui.object_pool.preset_partial_marker[1].color.b == 198,
    'the partial marker must use its distinct soft rose state color')
assert(ui.object_pool.preset_partial_marker[1].object.creation_index
        > highest_slot_background_depth,
    'the partial marker must be created above every preset background')
ui:_show_preset_warning(ui.selected_preset_summary)
ui:render(false)
assert(ui.preset_warning and ui.preset_warning.partial,
    'a partial preset must retain its short cooldown notice')

local order_only_summary = {
    slot=4,
    occupied=true,
    loadable=true,
    partial=false,
    order_mismatch=true,
}
ui:_show_preset_warning(order_only_summary)
local order_notice, order_notice_color =
    ui:_preset_warning_notice(order_only_summary)
assert(order_notice == 'ACTIVE TRUSTS MATCH - PARTY ORDER DIFFERS',
    'an order-only preset no-op must explain why no changes were staged')
assert(order_notice_color.r == 190 and order_notice_color.g == 213,
    'an order-only preset notice must be informational rather than an error')
ui:_preset_slot_foreground(order_only_summary, 800, 99, 26, false)
local order_match_marker = ui.keyed_pool.preset_match_marker
    and ui.keyed_pool.preset_match_marker['4']
assert(order_match_marker and order_match_marker.frame == ui.frame_id
        and order_match_marker.color.r == 99
        and order_match_marker.color.g == 217,
    'an order-only preset match must use the standard green matched marker')

table.remove(entries)
state.by_id[951] = nil
entries[1].recast_raw = 0
assert(presets.select(persisted_settings.presets, 2))
ui:render(false)

queue_state.active = true
ui:render(false)
assert(ui.object_pool.preset_load_button_disabled_rect[1].visible
        and ui.object_pool.preset_save_button_disabled_rect[1].visible,
    'preset load/save controls must lock while the party queue is active')
queue_state.active = false
ui:render(false)

-- The filter is a split control: its main area cycles in role order while the
-- narrow chevron opens a direct-selection menu.
local filter_x = ui.x + math.floor((18 + 73) * ui.scale + 0.5)
local filter_menu_x = ui.x + math.floor((168 + 12) * ui.scale + 0.5)
local filter_y = ui.y + math.floor((70 + 17) * ui.scale + 0.5)
local pending_before_filter = #pending
assert(ui:on_mouse(1, filter_x, filter_y, 0, false) == true)
assert(ui:on_mouse(2, filter_x, filter_y, 0, false) == true)
assert(ui.filter_index == 2 and ui.filter_dropdown_open == false,
    'the main filter button must cycle directly from ALL to TANK')
for _ = 1, 6 do
    assert(ui:on_mouse(1, filter_x, filter_y, 0, false) == true)
    assert(ui:on_mouse(2, filter_x, filter_y, 0, false) == true)
end
assert(ui.filter_index == 1,
    'the main filter button must cycle through every role and return to ALL')

assert(ui:on_mouse(1, filter_menu_x, filter_y, 0, false) == true)
assert(ui:on_mouse(2, filter_menu_x, filter_y, 0, false) == true)
assert(ui.filter_dropdown_open == true,
    'the filter chevron must open its option menu')
assert(ui.object_pool.filter_dropdown_frame[1].visible,
    'the open filter menu must render above the roster')
assert(ui.object_pool.filter_dropdown_row[1].color.r == 38
        and ui.object_pool.filter_dropdown_row[1].color.g == 53
        and ui.object_pool.filter_dropdown_row[1].color.b == 66,
    'filter options must use the dedicated dropdown palette, not roster-row colors')
assert(ui.object_pool.filter_dropdown_row_selected[1].color.r == 35
        and ui.object_pool.filter_dropdown_row_selected[1].color.g == 70
        and ui.object_pool.filter_dropdown_row_selected[1].color.b == 83,
    'the selected filter option must retain a distinct dropdown selection surface')
local covered_list_top = math.floor(112 * ui.scale + 0.5)
local covered_list_bottom = math.floor((108 + 62) * ui.scale + 0.5)
local covered_list_right = math.floor((18 + 455) * ui.scale + 0.5)
for _, record in ipairs(ui.objects) do
    local covered = record.x < covered_list_right
        and record.y >= covered_list_top
        and record.y < covered_list_bottom
    assert(not (covered and (record.kind == 'text'
            or record.kind == 'roster_icon')),
        'roster text and icons covered by the filter menu must leave the active frame')
end
local newest_filter_background = 0
for _, kind in ipairs({
        'filter_dropdown_frame',
        'filter_dropdown_row',
        'filter_dropdown_row_selected',
        'filter_dropdown_row_hovered',
        'filter_dropdown_selection',
    }) do
    for _, record in ipairs(ui.object_pool[kind] or {}) do
        newest_filter_background = math.max(
            newest_filter_background, record.object.creation_index)
    end
end
local oldest_filter_text = math.huge
for _, record in ipairs(ui.object_pool.filter_dropdown_option_text or {}) do
    oldest_filter_text = math.min(oldest_filter_text, record.object.creation_index)
end
assert(newest_filter_background < oldest_filter_text,
    'every filter-menu background palette must be created below its dedicated text layer')
local menu_labels = {}
for _, value in ipairs(rendered_text) do
    menu_labels[value] = true
end
for _, label in ipairs({'ALL', 'TANK', 'MELEE', 'RANGED', 'CASTER', 'HEALER', 'SUPPORT'}) do
    assert(menu_labels[label],
        'the filter menu must expose the ' .. label .. ' option')
end
local tank_x = ui.x + math.floor((18 + 3 + 112.25 + 56) * ui.scale + 0.5)
local first_option_y = ui.y + math.floor((108 + 3 + 13) * ui.scale + 0.5)
ui:on_mouse(0, tank_x, first_option_y, 0, false)
assert(ui.object_pool.filter_dropdown_row_hovered[1].visible,
    'moving over a filter option must show its hover treatment')
assert(ui:on_mouse(1, tank_x, first_option_y, 0, false) == true)
assert(ui:on_mouse(2, tank_x, first_option_y, 0, false) == true)
assert(ui.filter_index == 2 and ui.filter_dropdown_open == false,
    'choosing TANK must apply the filter and close the menu')
assert(#pending == pending_before_filter,
    'a dropdown option must not activate the roster row underneath it')

assert(ui:on_mouse(1, filter_menu_x, filter_y, 0, false) == true)
assert(ui:on_mouse(2, filter_menu_x, filter_y, 0, false) == true)
assert(ui:on_mouse(1, filter_x, first_option_y, 0, false) == true)
assert(ui:on_mouse(2, filter_x, first_option_y, 0, false) == true)
assert(ui.filter_index == 1 and ui.scroll == 0,
    'choosing ALL must restore the complete filter and reset scrolling')

assert(ui:on_mouse(1, filter_menu_x, filter_y, 0, false) == true)
assert(ui:on_mouse(2, filter_menu_x, filter_y, 0, false) == true)
local pending_before_outside_click = #pending
local covered_roster_x = ui.x + math.floor(300 * ui.scale + 0.5)
local covered_roster_y = ui.y + math.floor(200 * ui.scale + 0.5)
assert(ui:on_mouse(1, covered_roster_x, covered_roster_y, 0, false) == true)
assert(ui:on_mouse(2, covered_roster_x, covered_roster_y, 0, false) == true)
assert(ui.filter_dropdown_open == false
        and #pending == pending_before_outside_click,
    'an outside click over the roster must only dismiss the filter menu')

-- Sort mirrors the filter split control: the main area cycles while the
-- chevron opens a compact direct-selection menu.
local sort_x = ui.x + math.floor((202 + 53) * ui.scale + 0.5)
local sort_menu_x = ui.x + math.floor((312 + 12) * ui.scale + 0.5)
local sort_y = ui.y + math.floor((70 + 17) * ui.scale + 0.5)
local expected_sorts = {
    {index=2, key='name', label='SORT: NAME'},
    {index=3, key='role', label='SORT: ROLE'},
    {index=4, key='affiliation', label='SORT: AFFIL.'},
    {index=1, key='status', label='SORT: STATUS'},
}
for _, expected in ipairs(expected_sorts) do
    local before_sort_render = #rendered_text
    assert(ui:on_mouse(1, sort_x, sort_y, 0, false) == true)
    assert(ui:on_mouse(2, sort_x, sort_y, 0, false) == true)
    assert(ui.sort_index == expected.index
            and persisted_settings.ui.sort == expected.key,
        'the sort button must cycle and persist ' .. expected.key)
    local changed_text = table.concat(rendered_text, '|', before_sort_render + 1)
    assert(changed_text:find(expected.label, 1, true),
        'the sort button must display ' .. expected.label)
end

assert(ui:on_mouse(1, sort_menu_x, sort_y, 0, false) == true)
assert(ui:on_mouse(2, sort_menu_x, sort_y, 0, false) == true)
assert(ui.sort_dropdown_open == true,
    'the sort chevron must open its direct-selection menu')
assert(ui.object_pool.sort_dropdown_frame[1].visible,
    'the open sort menu must render above the roster')
assert(ui.object_pool.sort_dropdown_row[1].color.r == 38
        and ui.object_pool.sort_dropdown_row[1].color.g == 53
        and ui.object_pool.sort_dropdown_row[1].color.b == 66,
    'sort options must use the dedicated dropdown palette, not roster-row colors')
local sort_menu_labels = {}
for _, value in ipairs(rendered_text) do
    sort_menu_labels[value] = true
end
for _, label in ipairs({'STATUS', 'NAME', 'ROLE', 'AFFILIATION'}) do
    assert(sort_menu_labels[label],
        'the sort menu must expose the ' .. label .. ' option')
end
local affiliation_x = ui.x
    + math.floor((18 + 3 + 3 * 112.25 + 56) * ui.scale + 0.5)
local sort_option_y = ui.y + math.floor((108 + 3 + 13) * ui.scale + 0.5)
assert(ui:on_mouse(1, affiliation_x, sort_option_y, 0, false) == true)
assert(ui:on_mouse(2, affiliation_x, sort_option_y, 0, false) == true)
assert(ui.sort_index == 4 and ui.sort_dropdown_open == false
        and persisted_settings.ui.sort == 'affiliation',
    'choosing AFFILIATION must apply, persist, and close the sort menu')
assert(ui:on_mouse(1, sort_x, sort_y, 0, false) == true)
assert(ui:on_mouse(2, sort_x, sort_y, 0, false) == true)
assert(ui.sort_index == 1,
    'cycling after AFFILIATION must return Sort to STATUS')

local sort_probe = {
    {id=4, en='Alpha', metadata={}},
    {id=2, en='Bravo', metadata={role='tank', affiliation='windurst'}},
    {id=3, en='Charlie', metadata={role='melee', affiliation='bastok'}},
    {id=1, en='Delta', metadata={role='healer', affiliation='bastok'}},
}
local function sorted_probe_names(sort_index)
    local copy = {}
    for index, entry in ipairs(sort_probe) do copy[index] = entry end
    ui.sort_index = sort_index
    table.sort(copy, function(left, right)
        return ui:_sort_less(left, right, {}, {})
    end)
    local names = {}
    for index, entry in ipairs(copy) do names[index] = entry.en end
    return table.concat(names, '|')
end
assert(sorted_probe_names(2) == 'Alpha|Bravo|Charlie|Delta',
    'name sorting must be case-insensitive and alphabetical')
assert(sorted_probe_names(3) == 'Delta|Charlie|Bravo|Alpha',
    'role sorting must order role labels and put unclassified entries last')
assert(sorted_probe_names(4) == 'Delta|Charlie|Bravo|Alpha',
    'affiliation sorting must use role as a secondary key and put unknown entries last')
ui.sort_index = 4
assert(ui:_roster_descriptor(sort_probe[2]) == 'WINDURST',
    'affiliation sorting must show the explicit affiliation in the roster descriptor')
assert(ui:_roster_descriptor(sort_probe[1]) == '',
    'an unknown affiliation must leave the roster descriptor blank')
ui.sort_index = 3
assert(ui:_roster_descriptor(sort_probe[4]) == 'HEALER',
    'non-affiliation sorting must keep the role descriptor')
ui.sort_index = 1
local created_after_open = created
local shows_after_open = show_calls
local hides_after_open = hide_calls
ui:render(false)
assert(created == created_after_open,
    'an unchanged redraw must reuse the existing Windower primitives')
assert(show_calls == shows_after_open and hide_calls == hides_after_open,
    'an unchanged redraw must update visible primitives in place')
assert(extent_calls == 0,
    'layout must not depend on stale Windower text extents from pooled labels')
assert(#ui.object_pool.active_card_border_fill == 4
        and #ui.object_pool.active_card_inner_fill == 4
        and #ui.object_pool.active_card_gradient == 5
        and #ui.object_pool.active_card_empty_accent == 3,
    ('party slots must reserve every gradient below identity-keyed flags '
        .. '(border=%d inner=%d gradient=%d empty=%d)'):format(
            #ui.object_pool.active_card_border_fill,
            #ui.object_pool.active_card_inner_fill,
            #ui.object_pool.active_card_gradient,
            #ui.object_pool.active_card_empty_accent))
assert(#ui.object_pool.active_gradient_preload == 9,
    'every active-card gradient must be loaded offscreen before a slot changes')
local newest_gradient_creation = 0
for _, record in ipairs(ui.object_pool.active_card_gradient) do
    newest_gradient_creation = math.max(newest_gradient_creation,
        record.object.creation_index)
end
assert(ui.keyed_pool.active_card_flag['896']
        and ui.keyed_pool.active_card_flag['896'].object.creation_index
            > newest_gradient_creation,
    'every affiliation flag must retain creation depth above all card gradients')
assert(#ui.object_pool.active_portrait == 1
        and #ui.object_pool.active_portrait_placeholder == 3,
    'active portraits must be identity-keyed while empty slots reserve placeholders')
assert(ui.keyed_pool.active_card_clip['896']
        and ui.keyed_pool.active_card_border['896'],
    'active portraits must be followed by rounded clip and border layers')
assert(ui.keyed_pool.active_action_button_border['896']
        and ui.keyed_pool.active_action_button_fill['896'],
    'every active Trust must expose one glass dismiss action button')
local dismiss_all_hitbox = nil
for _, hitbox in ipairs(ui.hitboxes) do
    if hitbox.hover_key == 'dismiss_all_button' then
        dismiss_all_hitbox = hitbox
        break
    end
end
assert(dismiss_all_hitbox and dismiss_all_hitbox.x == 1012
        and dismiss_all_hitbox.y == 630
        and dismiss_all_hitbox.width == 76
        and dismiss_all_hitbox.height == 22,
    'dismiss all must match card action geometry below the fourth rendered slot')

function _run_five_slot_dismiss_all_test()
    local saved_max_trusts = state.max_trusts
    state.max_trusts = 5
    ui:render(true)
    local five_slot_hitbox = nil
    for _, hitbox in ipairs(ui.hitboxes) do
        if hitbox.hover_key == 'dismiss_all_button' then
            five_slot_hitbox = hitbox
            break
        end
    end
    assert(five_slot_hitbox and five_slot_hitbox.y == 752,
        'dismiss all must remain above the footer when all five slots render')
    state.max_trusts = saved_max_trusts
    ui:render(true)
end
assert(ui.keyed_pool.active_card_dismiss_overlay['896'],
    'every active Trust must reserve an identity-keyed dismissal dim layer')

_run_party_fallback_test = function()
    local saved_party = state.party_trusts
    local saved_other_members = state.other_members
    local saved_max_trusts = state.max_trusts

    -- A spawn-type Trust unknown to the current resource catalog must render
    -- a neutral, dismissible fallback instead of crashing on absent metadata.
    local unresolved = {
        slot=1,
        name='FutureTrust',
        model=9999,
        identity_key='futuretrust',
        unresolved=true,
        trust=nil,
    }
    state.party_trusts = {unresolved}
    state.other_members = 0
    local text_start = #rendered_text
    ui:render(false)
    local fallback_text = table.concat(rendered_text, '|', text_start + 1)
    assert(fallback_text:find('TRUST', 1, true)
            and fallback_text:find('UNRESOLVED', 1, true)
            and fallback_text:find('FutureTrust', 1, true),
        'an unresolved Trust card must identify its safe fallback state')
    local unresolved_key = ui:_active_record_primitive_key(unresolved, 1)
    assert(ui.keyed_pool.active_card_border[unresolved_key]
            and ui.keyed_pool.active_action_button_border[unresolved_key],
        'an unresolved spawn-type Trust must retain card and dismissal controls')
    assert(ui.object_pool.active_card_inner_fill[1].color.r == 14
            and ui.object_pool.active_card_inner_fill[1].color.g == 32,
        'an unresolved Trust must use the neutral slate surface')

    -- A future Trust present in resources but lacking addon metadata uses the
    -- same neutral classification while retaining its stable resource ID.
    local future_entry = {
        id=2001,
        en='Catalog Future Trust',
        identity_key='catalogfuturetrust',
        learned=true,
        recast_raw=0,
        in_party=true,
        active_exact=true,
        metadata=nil,
    }
    state.party_trusts = {{
        slot=1,
        id=2001,
        name='CatalogFutureTrust',
        identity_key='catalogfuturetrust',
        trust=future_entry,
    }}
    text_start = #rendered_text
    ui:render(false)
    fallback_text = table.concat(rendered_text, '|', text_start + 1)
    assert(fallback_text:find('Catalog Future Trust', 1, true)
            and fallback_text:find('UNCLASSIFIED', 1, true),
        'a catalog Trust without metadata must render as unclassified')

    -- Human members consume capacity without becoming Trust cards or gaining
    -- a dismissal control. With all capacity consumed, show one informational
    -- surface rather than a false EMPTY Trust slot.
    state.party_trusts = {}
    state.other_members = state.max_trusts
    text_start = #rendered_text
    ui:render(false)
    local no_capacity_text = table.concat(rendered_text, '|', text_start + 1)
    assert(no_capacity_text:find('NO TRUST SLOTS AVAILABLE', 1, true)
            and no_capacity_text:find('OTHER PARTY MEMBERS', 1, true),
        'human-filled parties must show capacity information without human cards')
    assert(not ui.keyed_pool.active_action_button_border['human'],
        'human party members must never receive Trust dismissal controls')
    assert(not ui.keyed_pool.active_action_button_disabled_border.dismiss_all.visible,
        'dismiss all must remain hidden when no Trust card can be dismissed')

    state.party_trusts = saved_party
    state.other_members = saved_other_members
    state.max_trusts = saved_max_trusts
    ui:render(false)
end
assert(#ui.object_pool.pending_card_background == 15,
    'all five staged-card background and gradient layers must be reserved before selection')
assert(#ui.object_pool.roster_row_background == 15,
    'all visible roster-row backgrounds must be reserved before scrolling')
assert(#ui.object_pool.roster_row_hover_fill == 15
        and #ui.object_pool.roster_row_hover_rail == 15,
    'every visible roster row must reserve stable hover layers')
local last_roster_background = 0
local last_roster_hover = 0
local first_roster_icon = math.huge
for position, record in ipairs(ui.objects) do
    if record.kind == 'roster_row_background' then
        last_roster_background = math.max(last_roster_background, position)
    elseif record.kind == 'roster_row_hover_fill'
        or record.kind == 'roster_row_hover_rail' then
        last_roster_hover = math.max(last_roster_hover, position)
    elseif record.kind == 'roster_icon' then
        first_roster_icon = math.min(first_roster_icon, position)
    end
end
assert(last_roster_background > 0 and last_roster_background < first_roster_icon,
    'every roster-row background must be drawn below every moving role icon')
assert(last_roster_hover > 0 and last_roster_hover < first_roster_icon,
    'every roster hover treatment must remain below moving icons and row text')

local first_row_box = nil
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'row' then
        first_row_box = box
        break
    end
end
assert(first_row_box and first_row_box.hover_key,
    'every Trust row must expose a stable hover target')
local primitives_before_roster_hover = created
local first_row_x = ui.x
    + math.floor((first_row_box.x + first_row_box.width / 2) * ui.scale + 0.5)
local first_row_y = ui.y
    + math.floor((first_row_box.y + first_row_box.height / 2) * ui.scale + 0.5)
ui:on_mouse(0, first_row_x, first_row_y, 0, false)
assert(ui.hover_key == first_row_box.hover_key,
    'moving over a Trust row must activate its hover key')
local active_hover_fills = 0
local active_hover_rails = 0
for _, record in ipairs(ui.object_pool.roster_row_hover_fill) do
    if record.alpha > 0 then active_hover_fills = active_hover_fills + 1 end
end
for _, record in ipairs(ui.object_pool.roster_row_hover_rail) do
    if record.alpha > 0 then active_hover_rails = active_hover_rails + 1 end
end
assert(active_hover_fills == 1 and active_hover_rails == 1,
    'hovering a row must show exactly one fill and one left rail')
assert(created == primitives_before_roster_hover,
    'first-time row hover must reuse preallocated primitives')
ui:on_mouse(0, ui.x - 10, ui.y - 10, 0, false)
for _, record in ipairs(ui.object_pool.roster_row_hover_fill) do
    assert(record.alpha == 0,
        'leaving the roster must clear every hover fill')
end
for _, record in ipairs(ui.object_pool.roster_row_hover_rail) do
    assert(record.alpha == 0,
        'leaving the roster must clear every hover rail')
end
local newest_roster_panel = 0
local oldest_roster_icon = math.huge
for _, record in ipairs(ui.object_pool.roster_panel_background or {}) do
    newest_roster_panel = math.max(newest_roster_panel, record.object.creation_index)
end
for _, record in ipairs(ui.object_pool.roster_icon or {}) do
    oldest_roster_icon = math.min(oldest_roster_icon, record.object.creation_index)
end
assert(newest_roster_panel > 0 and newest_roster_panel < oldest_roster_icon,
    'the stable roster panel must be created below every identity-keyed role icon')
for _, settings in ipairs(image_settings) do
    if settings.texture and settings.texture.path ~= '' then
        assert(settings.texture.fit == false, 'textured primitives must respect explicit UI dimensions')
    end
end

-- A roster longer than the viewport exposes a thumb which must support direct
-- dragging even though its visible bar remains deliberately narrow.
local original_entry_count = #entries
for index = 1, 18 do
    entries[#entries + 1] = {
        id=1000 + index,
        icon_id=1000 + index,
        en=('Test Trust %02d'):format(index),
        identity_key=('test_trust_%02d'):format(index),
        learned=true,
        recast_raw=0,
        cooldown_seconds=0,
        in_party=false,
        active_exact=false,
        card='assets/cards/valaineral.png',
        metadata={role='melee', affiliation='bastok'},
    }
end
ui:render(false)
local scrollbar_box = nil
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'scrollbar_thumb' then
        scrollbar_box = box
        break
    end
end
assert(scrollbar_box, 'a long roster must expose a draggable scrollbar thumb')
local thumb_x = ui.x + math.floor((scrollbar_box.x + scrollbar_box.width / 2) * ui.scale + 0.5)
local thumb_y = ui.y + math.floor((scrollbar_box.y + scrollbar_box.height / 2) * ui.scale + 0.5)
local thumb_travel = math.floor((scrollbar_box.track_height - scrollbar_box.thumb_height)
    * ui.scale + 0.5)
assert(ui:on_mouse(1, thumb_x, thumb_y, 0, false) == true)
assert(ui.scrollbar_drag ~= nil, 'pressing the scrollbar thumb must capture a drag')
assert(ui:on_mouse(0, thumb_x, thumb_y + thumb_travel, 0, false) == true)
assert(ui.scroll == #entries - 15,
    'dragging the thumb to the bottom must reveal the end of the roster')
assert(ui:on_mouse(2, thumb_x, thumb_y + thumb_travel, 0, false) == true)
assert(ui.scrollbar_drag == nil and ui.mouse_capture == nil,
    'releasing the thumb must end its mouse capture')
for index = #entries, original_entry_count + 1, -1 do
    entries[index] = nil
end
ui.scroll = 0
ui:render(false)

entries[1].recast_raw = 120
local cooldown_signature = ui:_signature()
local before_cooldown_render = #rendered_text
ui:render(false)
local cooldown_text = table.concat(rendered_text, '|', before_cooldown_render + 1)
assert(cooldown_text:find('COOLDOWN', 1, true),
    'a learned Trust with an active recast must render a cooldown status')
local cooldown_calls = #command_calls
ui:_select_entry(entries[1], false)
assert(#command_calls == cooldown_calls,
    'clicking a cooldown Trust must not invoke the selection command')
assert(ui.ui_warning
        and ui.ui_warning.text == 'MIHLI ALIAPOH: COOLDOWN - 2s',
    'clicking a cooldown Trust must show its remaining cooldown inline')
entries[1].recast_raw = 119
assert(ui:_signature() == cooldown_signature,
    'a decrementing cooldown must not force a full UI rebuild')
entries[1].recast_raw = 0
assert(ui:_signature() ~= cooldown_signature,
    'the cooldown-to-ready transition must update the UI')

-- First row is the active/status-prioritized Valaineral; second is Mihli.
local row_x = 100 + math.floor((18 + 20) * 0.78 + 0.5)
local second_row_y = 100 + math.floor((143 + 26 + 10) * 0.78 + 0.5)
assert(ui:on_mouse(1, row_x, second_row_y, 0, false) == true)
assert(ui:on_mouse(2, row_x, second_row_y, 0, false) == true)
assert(#pending == 1)
assert(command_calls[#command_calls][1] == 'select')
assert(ui.object_pool.sort_split_button_disabled_rect[1].visible
        and not ui.object_pool.sort_split_button_enabled_rect[1].visible,
    'both parts of Sort must be disabled while party changes are pending')
local staged_text = table.concat(rendered_text, '|')
assert(staged_text:find('|SUMMON|', 1, true),
    'a staged Trust row must use the unnumbered SUMMON status')
assert(not staged_text:find('|SUMMON 1|', 1, true),
    'roster status must not imply party position or duplicate preview order')
assert(staged_text:find('|TRUST IN USE|', 1, true),
    'an alternate version of a staged identity must render as unavailable')
local calls_before_alternate = #command_calls
local third_row_y = 100 + math.floor((143 + 2 * 26 + 10) * 0.78 + 0.5)
assert(ui:on_mouse(1, row_x, third_row_y, 0, false) == true)
assert(ui:on_mouse(2, row_x, third_row_y, 0, false) == true)
assert(#command_calls == calls_before_alternate and #pending == 1,
    'clicking an alternate version of a staged identity must be a no-op')
assert(ui.ui_warning
        and ui.ui_warning.text
            == 'ANOTHER VERSION OF THIS TRUST IS ALREADY IN USE',
    'clicking a TRUST IN USE row must explain why it cannot be staged')
assert(ui.object_pool.clear_changes_button_enabled_rect[1].visible
         and ui.object_pool.queue_action_button_enabled_rect[1].visible
        and not ui.object_pool.clear_changes_button_disabled_rect[1].visible
        and not ui.object_pool.queue_action_button_disabled_rect[1].visible,
    'staging a summon must switch both footer controls to their enabled palettes')
assert(#ui.object_pool.queue_action_button_enabled_rect == 3
        and ui.object_pool.queue_action_button_enabled_rect[1].path:find(
            'primary-action-capsule-mask', 1, true)
        and ui.object_pool.queue_action_button_enabled_rect[1].color.r == 75
        and ui.object_pool.queue_action_button_enabled_rect[2].color.r == 143
        and ui.object_pool.queue_action_button_enabled_rect[1].y
            > ui.object_pool.queue_action_button_enabled_rect[2].y,
    'the primary footer action must use an offset rounded capsule shadow')
assert(ui.keyed_pool.primary_ready_pulse.outer.visible
        and ui.keyed_pool.primary_ready_pulse.outer.alpha > 0,
    'enabling a party plan must begin a short primary-action readiness pulse')
ui.hover_key = 'queue_action_button'
ui:render(false)
assert(ui.object_pool.queue_action_button_enabled_rect[2].color.r == 112
        and ui.object_pool.queue_action_button_enabled_rect[2].color.g == 224,
    'the primary footer action must use cyan on hover')
assert(ui.object_pool.queue_action_button_enabled_rect[1].color.r == 68
        and ui.object_pool.queue_action_button_enabled_rect[1].color.g == 112,
    'the primary footer action hover shadow must remain desaturated')
ui.pressed_key = 'queue_action_button'
ui:render(false)
assert(ui.object_pool.queue_action_button_enabled_rect[1].color.r == 42
        and ui.object_pool.queue_action_button_enabled_rect[2].color.r == 232
        and ui.object_pool.queue_action_button_enabled_rect[3].color.r == 42,
    'a real hovered press must let the primary pressed palette override hover')
ui.hover_key = nil
ui:render(false)
assert(ui.object_pool.queue_action_button_enabled_rect[2].color.r == 232
        and ui.object_pool.queue_action_button_enabled_rect[3].color.r == 42,
    'the primary footer action must have a distinct pressed state')
ui.pressed_key = 'clear_changes_button'
ui:render(false)
assert(ui.object_pool.clear_changes_button_enabled_rect[2].color.r == 210
        and ui.object_pool.clear_changes_button_enabled_rect[3].color.r == 30,
    'clear changes must have a distinct pressed state')
ui.pressed_key = 'dismiss_all_button'
ui:render(false)
assert(ui.keyed_pool.active_action_button_border.dismiss_all.visible
        and ui.keyed_pool.active_action_button_border.dismiss_all.alpha == 255,
    'card-sized dismiss all must retain a distinct pressed state')
ui.pressed_key = nil
ui:render(false)
queue_state = {
    active=true,
    phase='summoning',
    status='awaiting_action',
    current_id=entries[1].id,
    current_identity_key=entries[1].identity_key,
    current_name=entries[1].en,
}
ui:render(false)
assert(ui.object_pool.queue_cancel_button_enabled_rect[1].visible
        and not ui.object_pool.queue_action_button_enabled_rect[1].visible
        and not ui.object_pool.queue_action_button_disabled_rect[1].visible,
    'an active queue must replace the normal action palette with CANCEL')
assert(ui.object_pool.queue_cancel_button_enabled_rect[2].color.r
        > ui.object_pool.queue_cancel_button_enabled_rect[2].color.g,
    'CANCEL must use a warm destructive border distinct from SUMMON')
ui.hover_key = 'queue_action_button'
ui.pressed_key = 'queue_action_button'
ui:render(false)
assert(ui.object_pool.queue_cancel_button_enabled_rect[1].color.r == 42
        and ui.object_pool.queue_cancel_button_enabled_rect[2].color.r == 190
        and ui.object_pool.queue_cancel_button_enabled_rect[3].color.r == 42,
    'a real CANCEL press must stay in the destructive palette while depressed')
ui.hover_key = nil
ui.pressed_key = nil
ui:render(false)
local summon_comet_count = 0
for _ in pairs(ui.keyed_pool.pending_summon_comet or {}) do
    summon_comet_count = summon_comet_count + 1
end
assert(summon_comet_count >= 14,
    'the active staged summon must render two opposite perimeter comet trails')
assert(ui.keyed_pool.pending_card_border[tostring(entries[1].id)].alpha == 215
        and ui.keyed_pool.pending_card_border[tostring(entries[1].id)].color.r < 200,
    'the active summon must use a dark same-hue base border behind the comet')
local retry_text_start = #rendered_text
queue_state.status = 'retry_wait'
queue_state.reason = 'cast_temporarily_blocked'
queue_state.block_cause = 'movement'
queue_state.retry_remaining = 2.4
ui:render(false)
local retry_text = table.concat(rendered_text, '|', retry_text_start + 1)
assert(retry_text:find('MOVEMENT DETECTED - RETRYING IN 3s', 1, true),
    'movement retry must display a yellow countdown in the footer message area')
local action_lock_text_start = #rendered_text
queue_state.block_cause = 'action_lock'
ui:render(false)
local action_lock_text = table.concat(rendered_text, '|', action_lock_text_start + 1)
assert(action_lock_text:find('PREVIOUS SUMMON STILL SETTLING', 1, true),
    'an action-lock retry must not be mislabeled as player movement')
queue_state.status = 'awaiting_action'
queue_state.action_timeout = 10
queue_state.action_remaining = 6
ui:render(false)
assert(ui.object_pool.footer_queue_notice[1].value
        == 'WAITING FOR SUMMONING TO BEGIN: MIHLI ALIAPOH - 6s',
    'timed summon feedback must end with the seconds value without LEFT')
queue_state.status = 'awaiting_party'
queue_state.current_name = 'Mihli Aliapoh'
queue_state.confirm_timeout = 5
queue_state.confirm_remaining = 4.7
ui:render(false)
assert(ui.object_pool.footer_queue_notice[1].value
        == 'VERIFYING MIHLI ALIAPOH JOINED PARTY - 5s',
    'party-confirmation feedback must end with the seconds value without LEFT')
assert(ui.object_pool.status_name_highlight[1].visible
        and ui.object_pool.status_name_highlight[1].value == 'MIHLI ALIAPOH'
        and ui.object_pool.status_name_highlight[1].color.r == 158
        and ui.object_pool.status_name_highlight[1].color.g == 210
        and ui.object_pool.status_name_highlight[1].segment_gap_px >= 2,
    'full-menu queue messages must raise the Trust name in accessible blue')
assert(ui.object_pool.footer_queue_notice[1].color.r == 190
        and ui.object_pool.footer_queue_notice[1].color.g == 208,
    'normal party confirmation must use accessible neutral status text')
queue_state.confirm_remaining = 2.9
ui:render(false)
assert(ui.object_pool.footer_queue_notice[1].color.r == 246
        and ui.object_pool.footer_queue_notice[1].color.g == 205,
    'party confirmation may turn yellow only after it has been delayed')
queue_state.status = 'retry_wait'
queue_state.block_cause = 'action_lock'
queue_state.retry_remaining = 2.4
ui:render(false)
for _, record in pairs(ui.keyed_pool.pending_summon_comet or {}) do
    assert(not record.visible,
        'the active-card comet must pause while the queue waits to retry')
end
local stopped_text_start = #rendered_text
queue_state = {active=false, status='stopped', reason='internal_error'}
ui:render(false)
local stopped_text = table.concat(rendered_text, '|', stopped_text_start + 1)
assert(stopped_text:find('SUMMONING STOPPED - SEE DATA/QUEUE.LOG', 1, true),
    'an internal queue failure must remain visible in the footer after CANCEL returns to SUMMON')
assert(ui.object_pool.footer_queue_notice[1].color.r == 255
        and ui.object_pool.footer_queue_notice[1].color.g == 184,
    'a stopped full-menu operation must use accessible error status text')
queue_state = {
    active=false,
    phase='summoning',
    status='stopped',
    reason='action_timeout',
    last_trust_name='Amchuchu',
}
ui:render(false)
assert(ui.object_pool.footer_queue_notice[1].value
        == 'SUMMONING AMCHUCHU DID NOT BEGIN - TRY AGAIN',
    'a silent summon failure must persist as a self-contained status message')
local capacity_text_start = #rendered_text
queue_state = {active=false, phase='summoning', status='stopped', reason='party_full'}
ui:render(false)
local capacity_text = table.concat(rendered_text, '|', capacity_text_start + 1)
assert(capacity_text:find('PARTY CAPACITY CHANGED - REVIEW SELECTIONS', 1, true),
    'capacity loss during execution must explain why the queue stopped')
queue_state = {active=false, status='idle', position=0, total=0}
ui:render(false)
assert(ui.keyed_pool.pending_card_border[tostring(entries[1].id)].alpha == 215,
    'the staged preview border must restore its normal brightness after summoning')
local footer_creation = ui.object_pool.window_frame[1].object.creation_index
assert(footer_creation
        < ui.object_pool.clear_changes_button_enabled_rect[1].object.creation_index
        and footer_creation
        < ui.object_pool.queue_action_button_enabled_rect[1].object.creation_index,
    'the stable rounded window frame must remain below newly activated button palettes')
local active_alternate_status = ui:_entry_status({
    id=1010,
    identity_key='Valaineral',
    in_party=true,
    active_exact=false,
}, {})
assert(active_alternate_status == 'TRUST IN USE',
    'only the exact active version may display IN PARTY')
local primed_mihli = ui.keyed_pool.active_portrait['909']
assert(primed_mihli and primed_mihli.visible and primed_mihli.frame == ui.frame_id,
    'a staged Trust must keep its full party-card portrait resident and transparent')
local planned_roster = ui:_filtered_roster()
assert(planned_roster[1].en == 'Valaineral' and planned_roster[2].en == 'Mihli Aliapoh',
    'status sorting must freeze while party changes are being planned')

-- The active Trust remains on the first row while Mihli is pending.
local first_row_y = 100 + math.floor((143 + 10) * 0.78 + 0.5)
assert(ui:on_mouse(1, row_x, first_row_y, 0, false) == true)
assert(ui:on_mouse(2, row_x, first_row_y, 0, false) == true)
assert(dismissals.Valaineral == true)
assert(ui.keyed_pool.active_action_button_disabled_border.dismiss_all.visible,
    'dismiss all must become visibly inactive after every active Trust is staged')
assert(table.concat(rendered_text, '|'):find('|UNDO|', 1, true),
    'a staged dismissal must change the same action button to UNDO')
assert(#ui.object_pool.active_card_border_fill == 4
         and #ui.object_pool.active_card_inner_fill == 4
         and #ui.object_pool.active_card_gradient == 5
         and #ui.object_pool.active_card_empty_accent == 3
         and #ui.object_pool.active_portrait == 2
         and #ui.object_pool.active_portrait_placeholder == 3
         and ui.keyed_pool.active_action_button_border['896'].visible,
    'staging a dismissal must reuse the identity-keyed action button')
assert(ui.state:snapshot().remaining_slots == 3,
    'a staged dismissal must make one additional replacement slot available')
queue_state = {
    active=true,
    phase='dismissing',
    current_id=entries[2].id,
    current_identity_key=entries[2].identity_key,
    current_name=entries[2].en,
}
ui:render(false)
assert(ui.keyed_pool.active_action_button_disabled_border['896']
        and ui.keyed_pool.active_action_button_disabled_border['896'].visible,
    'a card-level UNDO control must use its disabled treatment while the queue runs')
assert(not ui.keyed_pool.active_action_button_border['896'].visible,
    'the actionable UNDO treatment must be hidden while the queue runs')
local card_action_hitbox = false
local cancel_hitbox = false
for _, hitbox in ipairs(ui.hitboxes) do
    local hover_key = tostring(hitbox.hover_key or '')
    card_action_hitbox = card_action_hitbox
        or hover_key:find('active_action:', 1, true) == 1
    cancel_hitbox = cancel_hitbox or hover_key == 'queue_action_button'
end
assert(not card_action_hitbox,
    'card-level DISMISS and UNDO controls must have no hitbox while the queue runs')
assert(cancel_hitbox,
    'the footer CANCEL control must remain actionable while the queue runs')
local dismissal_comet_count = 0
for _ in pairs(ui.keyed_pool.active_dismiss_comet or {}) do
    dismissal_comet_count = dismissal_comet_count + 1
end
assert(dismissal_comet_count >= 14,
    'the active dismissal must render two opposite perimeter comet trails')
assert(ui.keyed_pool.active_card_border[tostring(entries[2].id)].alpha == 215
        and ui.keyed_pool.active_card_border[tostring(entries[2].id)].color.r < 200,
    'the active dismissal must use a dark same-hue base border behind the comet')
queue_state = {active=false, status='idle', position=0, total=0}
ui:render(false)
assert(ui.keyed_pool.active_card_border[tostring(entries[2].id)].alpha == 215,
    'the staged dismissal border must restore its normal brightness after dismissal')

-- A confirmed summon changes party and pending state while the queue remains
-- active. The UI must redraw once for that semantic change.
queue_state = {active=true, status='awaiting_action', position=1, total=1, current_name='Mihli Aliapoh'}
ui.last_refresh = -1
ui:tick()
local before_success_render = #rendered_text
state.party_trusts[2] = {
    slot=2,
    id=909,
    name='Mihli Aliapoh',
    identity_key='mihliapoh',
    trust=entries[1],
}
entries[1].in_party = true
entries[1].active_exact = true
pending = {}
queue_state = {active=true, status='validating', position=2, total=1}
ui.last_refresh = -1
ui:tick()
assert(#rendered_text > before_success_render,
    'confirmed party membership must update the open UI')
assert(ui.keyed_pool.active_portrait['909'] == primed_mihli and primed_mihli.visible,
    'summon confirmation must reveal the preloaded portrait without changing objects')
local warming_gradient = ui.object_pool.active_card_gradient[2]
local warming_fill = ui.object_pool.active_card_inner_fill[2]
assert(warming_gradient.alpha == 0
        and warming_gradient.target_alpha == 255
        and warming_gradient.texture_ready_frame == ui.frame_id + 1,
    'a newly occupied card gradient must warm invisibly for one prerender')
assert(warming_fill.color.r == 14 and warming_fill.color.g == 32
        and warming_fill.color.b == 45,
    'a warming active card must keep a neutral slate fallback surface')
assert(ui.deferred_texture_reveal == true,
    'a warming card texture must request the immediate follow-up render')
ui.last_refresh = -1
ui:tick()
assert(warming_gradient.alpha == 255
        and warming_gradient.texture_ready_frame == nil,
    'the warmed active-card gradient must reveal on the following render')
assert(ui.deferred_texture_reveal == false,
    'the texture warmup must finish after the one-frame reveal pass')
queue_state = {active=false, status='complete', position=2, total=1}

-- With two dismissals staged, confirming the first departure moves the second
-- card upward. Its identity-keyed action button must move with it and remain
-- visible rather than inheriting the departed slot's transparent state.
dismissals.mihliapoh = true
ui:render(false)
local mihli_action = ui.keyed_pool.active_action_button_border['909']
assert(mihli_action and mihli_action.visible,
    'each active Trust must own a visible identity-keyed action button')
assert(mihli_action.object.creation_index
        > ui.keyed_pool.active_portrait['909'].object.creation_index,
    'an action button must be created above its owning portrait')
local full_party = state.party_trusts
state.party_trusts = {full_party[2]}
dismissals.Valaineral = nil
ui:render(false)
assert(ui.keyed_pool.active_action_button_border['909'] == mihli_action
        and mihli_action.visible,
    'the remaining action button must survive another Trust leaving')
assert(mihli_action.y == math.floor((133 + 114 - 29) * ui.scale + 0.5),
    'the remaining action button must move to the first card slot')
state.party_trusts = full_party
dismissals.Valaineral = true
ui:render(false)

-- Previews are normally staged one at a time. Each later portrait therefore
-- has a newer Windower creation depth than the earlier slot captions. Caption
-- bars and close controls must follow their Trust identity so shrinking a full
-- pending list cannot move a newer portrait above an older slot foreground.
local function preview_entry(id, name, card, role, job)
    return {
        id=id,
        en=name,
        card='assets/cards/' .. card,
        metadata={role=role, job_label=job},
    }
end
local preview_entries = {
    preview_entry(1001, 'Preview One', 'domina_shantotto.png',
        'offensive_caster', 'SAM/WHM/BLM'),
    preview_entry(1002, 'Preview Two', 'curilla.png', 'tank'),
    preview_entry(1003, 'Preview Three', 'areuhat.png', 'melee'),
    preview_entry(1004, 'Preview Four', 'cid.png', 'melee'),
    preview_entry(1005, 'Preview Five', 'valaineral.png', 'tank'),
}
pending = {}
local preview_captions = {}
local preview_controls = {}
for index, entry in ipairs(preview_entries) do
    pending[index] = entry
    ui:render(false)
    local key = tostring(entry.id)
    local caption = ui.keyed_pool.pending_card_caption[key]
    local control = ui.keyed_pool.pending_control[key]
    local portrait = ui.keyed_pool.pending_portrait[key]
    local border = ui.keyed_pool.pending_card_border[key]
    assert(caption and control and portrait and border,
        'each staged preview must own identity-keyed foreground layers')
    assert(caption.object.creation_index > portrait.object.creation_index
            and border.object.creation_index > portrait.object.creation_index
            and control.object.creation_index > border.object.creation_index,
        'each preview foreground must be created above its own portrait')
    preview_captions[key] = caption
    preview_controls[key] = control
end
local first_preview_portrait = math.huge
local last_preview_background = 0
for position, record in ipairs(ui.objects) do
    if record.kind == 'pending_portrait' then
        first_preview_portrait = math.min(first_preview_portrait, position)
    elseif record.kind == 'pending_card_background' then
        last_preview_background = math.max(last_preview_background, position)
    end
end
assert(#ui.object_pool.pending_portrait >= 5,
    'all five staged Trusts must retain distinct identity-keyed portraits')
assert(#ui.object_pool.pending_card_caption >= 5,
    'each staged preview caption must use its identity-keyed layer pool')
local main_job_caption = ui.keyed_pool.pending_card_caption_main_text['1001']
local subjob_caption = ui.keyed_pool.pending_card_caption_subjob_text['1001']
assert(main_job_caption and main_job_caption.value == 'SAM'
        and main_job_caption.color.r == 239
        and main_job_caption.color.g == 244
        and main_job_caption.color.b == 246,
    'a preview badge must render its main job as the bright primary label')
assert(subjob_caption and subjob_caption.value == ' / WHM/BLM'
        and subjob_caption.color.r == 142
        and subjob_caption.color.g == 161
        and subjob_caption.color.b == 174,
    'a preview badge must render every subjob as one subtler suffix')
assert(subjob_caption.x > main_job_caption.x,
    'the subjob suffix must begin after the main job without overlapping it')
assert(ui.object_pool.pending_card_background[1].x
        == math.floor(40 * ui.scale + 0.5)
        and ui.object_pool.pending_card_background[13].x
        == math.floor(376 * ui.scale + 0.5),
    'the first and fifth preview slots must keep balanced outer margins')
assert(last_preview_background > 0 and last_preview_background < first_preview_portrait,
    'all staged-card backgrounds must be drawn below all staged portraits')

local completed_preview = table.remove(pending, 1)
ui:render(false)
assert(not preview_captions[tostring(completed_preview.id)].visible
        and not preview_controls[tostring(completed_preview.id)].visible,
    'the completed preview foreground must be hidden after confirmation')
for index, entry in ipairs(pending) do
    local key = tostring(entry.id)
    local expected_x = math.floor((46 + (index - 1) * 84) * ui.scale + 0.5)
    local caption = ui.keyed_pool.pending_card_caption[key]
    local control = ui.keyed_pool.pending_control[key]
    assert(caption == preview_captions[key] and caption.visible,
        'a remaining caption must keep its identity while moving left')
    assert(control == preview_controls[key] and control.visible,
        'a remaining close control must keep its identity while moving left')
    assert(caption.x == expected_x,
        'a remaining caption must move to its new preview position')
    assert(caption.object.creation_index
            > ui.keyed_pool.pending_portrait[key].object.creation_index,
        'a remaining caption must stay above its own portrait after the list shrinks')
end
pending = {}
dismissals = {}
ui.planning_order = nil
ui:render(false)

-- CLEAR is a permanent, dedicated preset action. It remains available for an
-- occupied slot even when SAVE is disabled because the confirmed party is
-- empty; staged additions are not treated as confirmed party members.
assert(presets.select(persisted_settings.presets, 2))
local confirmed_party = state.party_trusts
state.party_trusts = {}
pending = {entries[1]}
ui:render(false)
assert(ui.object_pool.preset_clear_button_enabled_rect[1].visible,
    'an occupied selected preset must enable its dedicated CLEAR action')
assert(not ui.object_pool.preset_save_button_enabled_rect[1].visible,
    'staged additions must not enable SAVE without a confirmed party')
preset_clear_x = ui.x + math.floor((1028 + 37) * ui.scale + 0.5)
assert(ui:on_mouse(1, preset_clear_x, preset_control_y, 0, false) == true)
assert(ui:on_mouse(2, preset_clear_x, preset_control_y, 0, false) == true)
preset_clear_x = nil
assert(#persisted_settings.presets.slots.slot_2 == 0,
    'CLEAR must empty the selected preset slot')
assert(ui.object_pool.preset_save_button_disabled_rect[1].visible,
    'an empty preset and empty confirmed party must show disabled SAVE')
assert(ui.object_pool.preset_clear_button_disabled_rect[1].visible,
    'an empty selected preset must disable CLEAR')
pending = {}
state.party_trusts = confirmed_party
persisted_settings.presets.slots.slot_2 = {
    presets.member(896, 'Valaineral'),
}
ui:render(false)

ui:set_search('Mihli')
assert(ui.search == 'Mihli')
assert(table.concat(rendered_text, '|'):find('|CLEAR SEARCH|', 1, true),
    'an active search must expose its fitted, centered clear control')
assert(#ui.object_pool.clear_search_button_enabled_rect == 3
        and ui.object_pool.clear_search_button_disabled_rect == nil,
    'the conditional search control must use an isolated enabled palette')
assert(#ui.object_pool.roster_panel_background == 2,
    'showing the search control must not shift or recreate roster panel layers')
assert(#ui.object_pool.clear_changes_button_enabled_rect == 3
        and #ui.object_pool.clear_changes_button_disabled_rect == 3
        and #ui.object_pool.queue_action_button_enabled_rect == 3
        and #ui.object_pool.queue_action_button_disabled_rect == 3,
    'footer controls must retain both palettes across state changes')
assert(ui.object_pool.clear_changes_button_disabled_rect[1].visible
        and ui.object_pool.queue_action_button_disabled_rect[1].visible
        and not ui.object_pool.clear_changes_button_enabled_rect[1].visible
        and not ui.object_pool.queue_action_button_enabled_rect[1].visible,
    'clearing a plan must restore both footer controls to their disabled palettes')
ui:set_scale(0.8)
assert(ui.scale == 0.8)
assert(saved >= 1)

-- Clicking an otherwise summonable Trust after effective capacity is full
-- must keep the plan unchanged and provide transient in-window guidance.
local normal_snapshot = state.snapshot
state.snapshot = function(self)
    local value = normal_snapshot(self)
    value.remaining_slots = 0
    return value
end
local full_party_candidate = {
    id=2001,
    en='Full Party Candidate',
    identity_key='fullpartycandidate',
    learned=true,
    recast_raw=0,
    in_party=false,
    active_exact=false,
}
local full_party_calls = #command_calls
local full_party_text_start = #rendered_text
ui:_select_entry(full_party_candidate, false)
assert(#command_calls == full_party_calls,
    'a full-party selection attempt must not alter the staged plan')
assert(ui.ui_warning
        and ui.ui_warning.text
            == 'PARTY CAPACITY REACHED',
    'a full-party selection attempt must create the capacity warning')
local full_party_text = table.concat(rendered_text, '|', full_party_text_start + 1)
assert(full_party_text:find(
        'PARTY CAPACITY REACHED',
        1, true),
    'the capacity warning must render in the expanded footer notice region')
assert(ui.object_pool.pending_header[1].color.r == 246
        and ui.object_pool.pending_header[1].color.g == 205,
    'the staging header must initially share the capacity warning color')
state.snapshot = normal_snapshot
clock_now = clock_now + 0.25
ui:render(false)
assert(ui.ui_warning ~= nil
        and ui.object_pool.pending_header[1].color.r == 190
        and ui.object_pool.pending_header[1].color.g == 213,
    'the capacity pulse must reach the normal header color at its trough')
clock_now = clock_now + 0.25
ui:render(false)
assert(ui.object_pool.pending_header[1].color.r == 246
        and ui.object_pool.pending_header[1].color.g == 205,
    'the capacity pulse must return to full warning yellow at its next peak')
clock_now = clock_now + 1.6
ui:render(false)
assert(ui.ui_warning ~= nil
        and ui.object_pool.pending_header[1].color.r == 190
        and ui.object_pool.pending_header[1].color.g == 213,
    'the capacity pulse must end after half of the warning duration')
clock_now = clock_now + 2
ui:render(false)
assert(ui.ui_warning == nil,
    'the full-party warning must expire after its hold and fade duration')

local unavailable_candidate = {
    id=2002,
    en='Unavailable Candidate',
    identity_key='unavailablecandidate',
    learned=true,
    recast_raw=nil,
    in_party=false,
    active_exact=false,
}
local unavailable_calls = #command_calls
ui:_select_entry(unavailable_candidate, false)
assert(#command_calls == unavailable_calls,
    'clicking an unavailable Trust must not invoke the selection command')
assert(ui.ui_warning
        and ui.ui_warning.text
            == 'UNAVAILABLE CANDIDATE: STATUS UNAVAILABLE',
    'clicking an unavailable Trust must explain the missing status inline')

-- The speech-bubble implementation is retained but globally gated off during
-- the current UI pass, even when an older setting still requests it.
clock_now = 200
queue_state = {
    active=true,
    status='next_summon_wait',
    run_id=44,
    summoned=1,
    last_trust_id=909,
    last_trust_name='Mihli Aliapoh',
}
ui.last_refresh = -1
ui:tick()
assert(ui.summon_dialogue == nil,
    'confirmed membership must not display a speech bubble while gated off')
assert(not (ui.keyed_pool.summon_dialogue_asset
        and ui.keyed_pool.summon_dialogue_asset.bubble
        and ui.keyed_pool.summon_dialogue_asset.bubble.visible),
    'the disabled speech-bubble layer must remain absent or hidden')
assert(ui:set_dialogue_mode('off'))
queue_state.run_id = 45
ui.last_refresh = -1
ui:tick()
assert(ui.summon_dialogue == nil,
    'the off setting must consume confirmations without displaying a bubble')
assert(ui:set_dialogue_mode('always'))
queue_state = {active=false, status='complete', run_id=45, summoned=1,
    last_trust_id=909, last_trust_name='Mihli Aliapoh'}

local resize_x = ui.x + math.floor((1120 - 8) * ui.scale + 0.5)
local resize_y = ui.y + math.floor((860 - 8) * ui.scale + 0.5)
assert(ui:on_mouse(1, resize_x, resize_y, 0, false) == true)
assert(ui:on_mouse(0, resize_x + 70, resize_y + 50, 0, false) == true)
assert(ui.scale > 0.8, 'the window must redraw at the new scale during a resize drag')
assert(ui:on_mouse(2, resize_x + 70, resize_y + 50, 0, false) == true)
assert(ui.scale > 0.8)

-- Compact mode uses the launcher position and its independently persisted
-- scale while preserving the full window position and scale for restoration.
local expanded_x = ui.x
local expanded_y = ui.y
local expanded_scale = ui.scale
local compact_scale = ui.compact_scale
local minimize_x = ui.x + math.floor((1120 - 88 + 17) * ui.scale + 0.5)
local minimize_y = ui.y + math.floor((12 + 17) * ui.scale + 0.5)
assert(ui:on_mouse(1, minimize_x, minimize_y, 0, false) == true)
assert(ui:on_mouse(2, minimize_x, minimize_y, 0, false) == true)
assert(ui.mode == 'compact' and persisted_settings.ui.mode == 'compact',
    'minimizing must persist compact as the last panel mode')
assert(ui.scale == compact_scale and ui.x == expanded_x and ui.y == expanded_y,
    'compact mode must restore its own scale without changing the expanded position')
assert(persisted_settings.ui.expanded_scale == expanded_scale
        and persisted_settings.ui.compact_scale == compact_scale,
    'switching modes must persist separate expanded and compact scales')
assert(ui.object_pool.compact_shell[1].visible,
    'compact mode must render its own anchored shell')
assert(ui.keyed_pool.compact_shell.outer.path
        :find('compact%-shell%-border%-mask%.png')
        and ui.keyed_pool.compact_shell_fill.inner.path
            :find('compact%-shell%-inner%-rounded%-mask%.png'),
    'compact mode must use the visibly rounded panel masks')
assert(ui.keyed_pool.compact_shell_fill.inner.alpha == 210,
    'compact mode must keep only its shell background subtly translucent')
assert(ui.object_pool.compact_resize_grip[1].visible,
    'compact mode must expose a bottom-right resize grip')
assert(ui.object_pool.compact_shell[1].object.creation_index
        < ui.object_pool.preset_occupied_marker[1].object.creation_index
        and ui.object_pool.compact_shell[1].object.creation_index
            < ui.object_pool.preset_match_marker[1].object.creation_index,
    'the compact shell must remain beneath saved and matched preset markers')

local compact_resize_x = ui.launcher_x
    + math.floor((720 - 8) * ui.scale + 0.5)
local compact_resize_y = ui.launcher_y
    + math.floor((60 - 8) * ui.scale + 0.5)
assert(ui:on_mouse(0, compact_resize_x, compact_resize_y, 0, false) == false)
assert(ui.object_pool.compact_resize_grip[1].color.r == 112,
    'hovering the compact resize grip must use the cyan affordance')
assert(ui:on_mouse(1, compact_resize_x, compact_resize_y, 0, false) == true)
assert(ui:on_mouse(0, compact_resize_x + 60, compact_resize_y + 12, 0, false) == true)
assert(ui.scale > compact_scale,
    'dragging the compact resize grip must redraw at the new scale')
assert(ui:on_mouse(2, compact_resize_x + 60, compact_resize_y + 12, 0, false) == true)
compact_scale = ui.scale
assert(persisted_settings.ui.compact_scale == compact_scale
        and persisted_settings.ui.expanded_scale == expanded_scale,
    'compact resizing must not overwrite the expanded scale')
assert(ui.keyed_pool.window_frame.main.object.creation_index
        < ui.object_pool.preset_slot_selected[1].object.creation_index
        and ui.keyed_pool.window_frame.main.object.creation_index
            < ui.object_pool.preset_load_button_enabled_rect[1].object.creation_index,
    'the expanded frame must remain beneath preset slots and action surfaces')
local compact_launcher_icon = ui.keyed_pool.compact_launcher_icon.launcher
local compact_launcher_pressed_icon =
    ui.keyed_pool.compact_launcher_icon_pressed.launcher
assert(compact_launcher_icon and compact_launcher_icon.visible
        and compact_launcher_icon.alpha == 255
        and compact_launcher_pressed_icon
        and compact_launcher_pressed_icon.alpha == 0,
    'the integrated launcher must show only its normal icon at rest')
local compact_icon_hover_x = ui.launcher_x
    + math.floor((8 + 20) * ui.scale + 0.5)
local compact_icon_hover_y = ui.launcher_y
    + math.floor((10 + 20) * ui.scale + 0.5)
assert(ui:on_mouse(0, compact_icon_hover_x, compact_icon_hover_y, 0, false) == false)
assert(compact_launcher_icon.color.r == 190
        and compact_launcher_icon.color.g == 238
        and compact_launcher_icon.color.b == 246,
    'hovering the integrated launcher must tint only the hat icon')
assert(not ui.keyed_pool.compact_launcher_hover
        and not ui.keyed_pool.compact_launcher_pressed
        and not ui.keyed_pool.compact_launcher_frame
        and not ui.keyed_pool.compact_launcher_fill,
    'the integrated launcher must not render a hover or pressed background')
assert(ui:on_mouse(0, ui.launcher_x + math.floor(55 * ui.scale + 0.5),
    compact_icon_hover_y, 0, false) == false)
assert(compact_launcher_icon.color.r == 239
        and compact_launcher_icon.color.g == 244
        and compact_launcher_icon.color.b == 246,
    'leaving the integrated launcher must restore its normal color')
assert(ui:on_mouse(1, compact_icon_hover_x, compact_icon_hover_y, 0, false) == true)
assert(compact_launcher_icon.alpha == 0
        and compact_launcher_pressed_icon.alpha == 255
        and compact_launcher_pressed_icon.path:find('trust%-hat%-pressed%.png'),
    'pressing the integrated launcher must reveal the preloaded tilted icon')
assert(ui:on_mouse(2, compact_icon_hover_x, compact_icon_hover_y, 0, false) == true)
assert(ui.visible == false,
    'clicking the integrated launcher must close the compact bar')
ui:open()
assert(ui.mode == 'compact',
    'opening after an integrated launcher click must restore compact mode')
assert(ui.keyed_pool.compact_launcher_seam.right.visible,
    'the launcher must retain a subtle separator from the preset controls')
assert(ui.keyed_pool.compact_preset_seam.right.visible
        and ui.keyed_pool.compact_preset_seam.right.x
            == math.floor(232 * ui.scale + 0.5),
    'the preset group must retain an equally spaced separator from the primary action')
assert(table.concat(rendered_text, '|'):find('|PRESETS|', 1, true),
    'compact mode must retain the preset caption')

-- Compact feedback consumes the same queue states as the expanded footer,
-- preserves their priority, and remains readable at the minimum scale.
function visible_pool_record(kind)
    for _, record in ipairs(ui.object_pool[kind] or {}) do
        if record.visible then return record end
    end
    return nil
end

function visible_pool_records(kind)
    local result = {}
    for _, record in ipairs(ui.object_pool[kind] or {}) do
        if record.visible then result[#result + 1] = record end
    end
    return result
end

function visible_compact_status()
    return visible_pool_record('compact_status')
end

local saved_ui_warning = ui.ui_warning
local saved_preset_warning = ui.preset_warning
ui.ui_warning = {
    text='LOWER PRIORITY WARNING',
    color={r=246, g=205, b=86, a=255},
    started=clock_now,
}
ui.preset_warning = nil
queue_state = {
    active=true,
    phase='summoning',
    status='awaiting_action',
    current_name='Najelith',
    attempt=1,
    max_attempts=2,
    action_timeout=10,
    action_remaining=9,
}
ui:render(false)
local compact_status = visible_compact_status()
assert(compact_status
        and compact_status.value == 'SUMMONING NAJELITH - ATTEMPT 1/2',
    'an active compact queue message must take priority over UI warnings')
local status_center = math.floor(12 * ui.scale + 0.5)
    + math.floor(40 * ui.scale + 0.5) / 2
local text_center = compact_status.y
    + compact_status.font_size * (4 / 3) / 2
assert(math.abs(status_center - text_center) <= 1,
    'compact queue messages must be vertically centered in their fixed region')

queue_state = {active=false, status='idle'}
ui:render(false)
compact_status = visible_compact_status()
assert(compact_status and compact_status.value == 'LOWER PRIORITY WARNING',
    'a compact UI warning must appear after the active queue message clears')
ui.ui_warning = nil
ui:render(false)
assert(visible_compact_status() == nil,
    'compact status primitives must hide when no current message remains')

ui:set_scale(0.55)
queue_state = {
    active=true,
    phase='summoning',
    status='awaiting_action',
    current_name='Kuyin Hathdenna',
    attempt=1,
    max_attempts=2,
    action_timeout=10,
    action_remaining=9,
}
ui:render(false)
compact_status = visible_compact_status()
assert(compact_status
        and compact_status.value == 'SUMMON KUYIN HATHDENNA - 1/2'
        and compact_status.font_size == 6,
    'minimum scale must use a readable abbreviated summon message')

queue_state.action_remaining = 6
ui:render(false)
compact_status = visible_compact_status()
assert(compact_status.value == 'WAITING TO SUMMON: KUYIN HATHDENNA - 6s'
        and compact_status.color.r == 246
        and compact_status.alpha >= 155
        and compact_status.alpha <= 255,
    'a delayed minimum-scale action response must become a yellow countdown')

queue_state.status = 'retry_wait'
queue_state.reason = 'cast_temporarily_blocked'
queue_state.block_cause = 'movement'
queue_state.retry_remaining = 2.4
ui:render(false)
compact_status = visible_compact_status()
assert(compact_status.value == 'MOVEMENT - RETRY 3s'
        and compact_status.color.r == 246
        and compact_status.alpha >= 155
        and compact_status.alpha <= 255,
    'minimum-scale movement retry must remain concise, yellow, and blinking')

queue_state.block_cause = 'action_lock'
ui:render(false)
assert(visible_compact_status().value == 'WAITING - RETRY 3s',
    'minimum-scale action-lock retry must not be described as movement')

queue_state.status = 'next_summon_wait'
queue_state.handoff_remaining = 2.1
ui:render(false)
assert(visible_compact_status().value == 'NEXT SUMMON - 3s',
    'minimum-scale handoff status must retain its live countdown')

queue_state.status = 'awaiting_party'
queue_state.confirm_timeout = 5
queue_state.confirm_remaining = 4.8
ui:render(false)
assert(visible_compact_status().value == 'PARTY CHECK: KUYIN HATHDENNA - 5s'
        and visible_compact_status().color.r == 190,
    'normal compact party confirmation must remain concise and accessible')
queue_state.confirm_remaining = 2.8
ui:render(false)
assert(visible_compact_status().color.r == 246,
    'a delayed compact party confirmation must change to warning yellow')

queue_state = {
    active=true,
    phase='dismissing',
    status='awaiting_dismissal',
    current_name='Ferreous Coffin',
    position=2,
    total=4,
}
ui:render(false)
assert(visible_compact_status().value == 'DISMISS FERREOUS COFFIN - 2/4',
    'compact dismissal progress must identify the Trust and queue position')
assert(ui.object_pool.status_name_highlight[1].visible
        and ui.object_pool.status_name_highlight[1].value == 'FERREOUS COFFIN'
        and ui.object_pool.status_name_highlight[1].color.r == 158
        and ui.object_pool.status_name_highlight[1].color.g == 210,
    'compact queue messages must raise the Trust name in accessible blue')
queue_state = {
    active=false,
    phase='dismissing',
    status='stopped',
    reason='dismissal_unconfirmed',
}
ui:render(false)
assert(visible_compact_status().value == 'DISMISS NOT VERIFIED: TRUST'
        and visible_compact_status().color.r == 255
        and visible_compact_status().color.g == 184,
    'a stopped dismissal must use phase-specific compact error wording')
queue_state = {
    active=false,
    phase='summoning',
    status='stopped',
    reason='internal_error',
}
ui:render(false)
assert(visible_compact_status().value == 'STOPPED - SEE QUEUE.LOG'
        and visible_compact_status().color.r == 255
        and visible_compact_status().color.g == 184,
    'a compact internal failure must remain concise and point to queue.log')
queue_state = {
    active=false,
    phase='summoning',
    status='stopped',
    reason='party_full',
}
ui:render(false)
assert(visible_compact_status().value == 'PARTY CAPACITY CHANGED'
        and visible_compact_status().color.r == 255
        and visible_compact_status().color.g == 184,
    'compact mode must explain a capacity-related stop without overflowing')

-- Long live messages keep the same reserved region at every supported scale.
queue_state = {
    active=true,
    phase='summoning',
    status='awaiting_action',
    current_name='Kuyin Hathdenna',
    attempt=1,
    max_attempts=2,
    action_timeout=10,
    action_remaining=9,
}
for _, test_scale in ipairs({0.55, 0.78, 1.0, 1.25}) do
    ui:set_scale(test_scale)
    ui:render(false)
    local scaled_status = visible_compact_status()
    local status_width = scaled_status.object:extents()
    local left_edge = math.floor(404 * test_scale + 0.5)
    local right_edge = math.floor((404 + 262) * test_scale + 0.5)
    local scaled_center = math.floor((12 + 20) * test_scale + 0.5)
    local scaled_text_center = scaled_status.y
        + scaled_status.font_size * (4 / 3) / 2
    assert(scaled_status.x >= left_edge
            and scaled_status.x + status_width <= right_edge,
        'compact status text must remain between both dividers at every scale')
    assert(math.abs(scaled_center - scaled_text_center) <= 2,
        'compact status text must remain vertically centered at every scale')
end

queue_state = {active=false, status='idle'}
ui:set_scale(compact_scale)
ui.ui_warning = saved_ui_warning
ui.preset_warning = saved_preset_warning
ui:render(false)

-- The compact action retains the shared action vocabulary and palette while
-- keeping every non-cancel planning control locked during execution.
local action_pending = pending
local action_dismissals = dismissals
local action_identity = state.party_trusts[1]
    and state.party_trusts[1].identity_key or entries[2].identity_key
local function visible_text_record(value)
    for _, record in ipairs(ui.objects) do
        if record.visible and record.value == value then return record end
    end
    return nil
end
local function has_hitbox(hover_key_prefix)
    for _, box in ipairs(ui.hitboxes) do
        if box.hover_key
            and box.hover_key:sub(1, #hover_key_prefix) == hover_key_prefix then
            return true, box
        end
    end
    return false, nil
end

pending = {}
dismissals = {}
queue_state = {active=false, status='idle'}
ui:render(false)
assert(ui.object_pool.queue_action_button_disabled_rect[1].visible
        and visible_text_record('SUMMON'),
    'compact idle state must show the disabled SUMMON action')

pending = {entries[1]}
ui:render(false)
local action_hitbox_present, action_hitbox = has_hitbox('queue_action_button')
assert(ui.object_pool.queue_action_button_enabled_rect[1].visible
        and visible_text_record('SUMMON (1)')
        and action_hitbox_present
        and action_hitbox.y == 9
        and action_hitbox.height == 38,
    'compact staged summon must show its count in the centered action control')

pending = {}
dismissals[action_identity] = true
ui:render(false)
assert(visible_text_record('DISMISS (1)'),
    'compact dismissal-only plan must use the DISMISS action label')

pending = {entries[1]}
ui:render(false)
assert(visible_text_record('APPLY (-1 / +1)'),
    'compact replacement plan must show both sides of its staged delta')

local action_hitbox_geometry = nil
for _, test_scale in ipairs({0.55, 0.78, 1.0, 1.25}) do
    ui:set_scale(test_scale)
    ui:render(false)
    local fitted_action = visible_text_record('APPLY (-1 / +1)')
    local fitted_width = fitted_action.object:extents()
    local left_edge = math.floor(244 * test_scale + 0.5)
    local right_edge = math.floor((244 + 150) * test_scale + 0.5)
    -- Capsule labels use the shared three-unit optical lift that compensates
    -- for Arial's low visual baseline.
    local action_center = math.floor(9 * test_scale + 0.5)
        + math.floor(38 * test_scale + 0.5) / 2
        + math.floor(-3 * test_scale + 0.5)
    local action_text_center = fitted_action.y
        + fitted_action.font_size * (4 / 3) / 2
    local _, scaled_hitbox = has_hitbox('queue_action_button')
    assert(fitted_action.font_size >= 6
            and fitted_action.x >= left_edge
            and fitted_action.x + fitted_width <= right_edge,
        'compact APPLY must fit inside its capsule at every scale')
    assert(math.abs(action_center - action_text_center) <= 2,
        ('compact action text must remain vertically centered at every scale '
            .. '(scale=%.2f target=%.2f actual=%.2f)'):format(
            test_scale, action_center, action_text_center))
    local geometry = table.concat({
        scaled_hitbox.x, scaled_hitbox.y,
        scaled_hitbox.width, scaled_hitbox.height,
    }, ':')
    action_hitbox_geometry = action_hitbox_geometry or geometry
    assert(geometry == action_hitbox_geometry,
        'compact action hitbox geometry must not change with UI scale')
end
ui:set_scale(compact_scale)

queue_state = {
    active=true,
    phase='summoning',
    status='awaiting_action',
    current_name='Mihli Aliapoh',
    attempt=1,
    max_attempts=2,
}
ui:render(false)
local preset_hitbox_present = has_hitbox('preset_slot:')
assert(ui.object_pool.queue_cancel_button_enabled_rect[1].visible
        and visible_text_record('CANCEL')
        and not preset_hitbox_present,
    'compact execution must show CANCEL and remove preset-slot hitboxes')
local compact_cancel_x = ui.launcher_x
    + math.floor((244 + 75) * ui.scale + 0.5)
local compact_cancel_y = ui.launcher_y
    + math.floor((9 + 19) * ui.scale + 0.5)
local cancel_calls = #command_calls
assert(ui:on_mouse(1, compact_cancel_x, compact_cancel_y, 0, false) == true)
assert(ui:on_mouse(2, compact_cancel_x, compact_cancel_y, 0, false) == true)
assert(#command_calls == cancel_calls + 1
        and command_calls[#command_calls][1] == 'cancel',
    'compact CANCEL must delegate immediately to the shared queue command')

ui.hover_key = 'queue_action_button'
ui.pressed_key = 'queue_action_button'
ui:render(false)
assert(ui.object_pool.queue_cancel_button_enabled_rect[1].color.r == 42
        and ui.object_pool.queue_cancel_button_enabled_rect[2].color.r == 190
        and ui.object_pool.queue_cancel_button_enabled_rect[3].color.r == 42,
    'compact CANCEL press must retain the destructive pressed palette')
ui.hover_key = nil
ui.pressed_key = nil
queue_state = {active=false, status='idle'}
ui:render(false)
assert(not ui.object_pool.queue_cancel_button_enabled_rect[1].visible
        and not (ui.object_pool.queue_cancel_button_disabled_rect
            and ui.object_pool.queue_cancel_button_disabled_rect[1]
            and ui.object_pool.queue_cancel_button_disabled_rect[1].visible)
        and ui.object_pool.queue_action_button_enabled_rect[1].visible
        and visible_text_record('APPLY (-1 / +1)'),
    'compact action must return immediately from CANCEL to the staged plan')

pending = action_pending
dismissals = action_dismissals
ui:render(false)

-- Exercise the compact two-click workflow through the real command adapter,
-- not only the UI command spy. Loading must atomically replace unrelated
-- staging with the selected preset's membership delta.
persisted_settings.presets.slots.slot_2 = {
    presets.member(1009, 'Mihli II'),
}
assert(presets.select(persisted_settings.presets, 2))
pending = {entries[3]}
dismissals = {}
local compact_command_output = {}
local real_compact_commands = command_module.new(
    state,
    function(line) compact_command_output[#compact_command_output + 1] = line end,
    queue,
    {
        presets=persisted_settings.presets,
        save_settings=function() saved = saved + 1 end,
    })
local spy_commands = commands
ui.commands = {
    handle=function(_, args)
        command_calls[#command_calls + 1] = args
        real_compact_commands:handle(args)
    end,
}

-- A persisted selection in a compact-first session has no separate Load
-- button to press. It must wait for authoritative startup state, restore the
-- preset plan once, and never restage it on later redraws.
function _run_compact_startup_restore_test()
    pending = {}
    dismissals = {}
    state.source_status.spells = false
    ui.compact_preset_restore_pending = true
    local restore_calls = #command_calls
    ui:render(false)
    assert(#command_calls == restore_calls and #pending == 0,
        'compact startup restoration must wait for authoritative source state')
    state.source_status.spells = true
    ui:render(false)
    assert(#command_calls == restore_calls + 1
            and command_calls[#command_calls][1] == 'preset'
            and command_calls[#command_calls][2] == 'load'
            and command_calls[#command_calls][3] == '2',
        'compact startup must restore its persisted selected preset automatically')
    assert(#pending == 1 and pending[1].id == 1009
            and dismissals.Valaineral == true
            and dismissals.mihliapoh == true,
        'compact startup restoration must stage the same delta as expanded Load')
    ui:render(false)
    assert(#command_calls == restore_calls + 1,
        'compact startup restoration must run only once')

    -- Remaining open through a zone must schedule the same revalidation as
    -- closing and reopening compact mode. The transient snapshot must not
    -- consume that request before the new zone reports authoritative state.
    local zone_calls = #command_calls
    local pre_zone_party = state.party_trusts
    pending = {}
    dismissals = {}
    ui.expanded_plan_draft = {plan={summon={}, dismiss={}}}
    ui:on_zone_change()
    ui:render(false)
    assert(ui.party_zone_transition ~= nil
            and ui.party_zone_transition.ready_refreshes >= 1
            and ui.party_zone_transition.ready_refreshes < 12
            and #command_calls == zone_calls,
        'the stale pre-zone party must not consume compact preset revalidation')
    state.party_trusts = {}
    state.source_status.spells = false
    ui:render(false)
    assert(ui.party_zone_transition ~= nil
            and ui.compact_preset_restore_pending == false
            and ui.compact_preset_selection_pending == false
            and ui.expanded_plan_draft == nil
            and #command_calls == zone_calls,
        'compact zone revalidation must discard the stale expanded draft and wait')
    state.source_status.spells = true
    for _ = 1, 4 do ui:render(false) end
    assert(#command_calls == zone_calls + 1
            and command_calls[#command_calls][1] == 'preset'
            and command_calls[#command_calls][2] == 'load'
            and command_calls[#command_calls][3] == '2'
            and #pending == 1 and pending[1].id == 1009,
        'an open compact bar must restage its selected preset after zoning')
    assert(ui:restore())
    assert(#pending == 1 and pending[1].id == 1009
            and ui.object_pool.queue_action_button_enabled_rect[1].visible,
        'maximizing after zoning must retain the rebuilt actionable preset plan')
    assert(ui:minimize())
    ui.expanded_plan_draft = nil
    state.party_trusts = pre_zone_party

    -- Reproduce selecting a preset in the expanded window, closing/reopening,
    -- and then entering compact mode without pressing expanded Load.
    pending = {}
    dismissals = {}
    assert(ui:restore())
    local transition_calls = #command_calls
    assert(ui:minimize())
    assert(#command_calls == transition_calls + 1
            and command_calls[#command_calls][1] == 'preset'
            and command_calls[#command_calls][2] == 'load'
            and command_calls[#command_calls][3] == '2',
        'entering compact mode must restore the selected preset plan')
    assert(#pending == 1 and pending[1].id == 1009
            and dismissals.Valaineral == true
            and dismissals.mihliapoh == true,
        'compact mode transition must enable its action with the selected delta')
    assert(ui:restore())
    assert(#pending == 0 and next(dismissals) == nil,
        'returning to expanded mode must restore an explicitly empty draft')

    -- If an older preset plan is still staged, selecting a different preset
    -- in expanded mode must make that latest selection win when compact mode
    -- is reopened. Otherwise its SUMMON count describes the previous preset.
    persisted_settings.presets.slots.slot_1 = {
        presets.member(896, 'Valaineral'),
    }
    pending = {entries[3]}
    dismissals = {}
    local expanded_slot_1_x = ui.x + math.floor((718 + 13) * ui.scale + 0.5)
    local expanded_slot_y = ui.y + math.floor((99 + 13) * ui.scale + 0.5)
    assert(ui:on_mouse(1, expanded_slot_1_x, expanded_slot_y, 0, false) == true)
    assert(ui:on_mouse(2, expanded_slot_1_x, expanded_slot_y, 0, false) == true)
    assert(ui.compact_preset_selection_pending == true,
        'expanded preset selection must mark an older plan as superseded')
    assert(ui:minimize())
    assert(#pending == 0 and dismissals.Valaineral == nil
            and dismissals.mihliapoh == true,
        'compact reopen must replace the stale plan with the latest preset selection')
    assert(ui:restore())
    assert(#pending == 1 and pending[1].id == entries[3].id
            and next(dismissals) == nil,
        'returning to expanded mode must restore its unexecuted staged draft')
    pending = {}
    dismissals = {}
    assert(ui:minimize())
end
_run_compact_startup_restore_test()
_run_compact_startup_restore_test = nil

pending = {entries[3]}
dismissals = {}
ui:render(false)

local compact_slot_2_x = ui.launcher_x
    + math.floor((64 + 28 + 4 + 14) * ui.scale + 0.5)
local compact_slot_y = ui.launcher_y + math.floor((23 + 14) * ui.scale + 0.5)
local compact_calls = #command_calls
assert(ui:on_mouse(1, compact_slot_2_x, compact_slot_y, 0, false) == true)
assert(ui:on_mouse(2, compact_slot_2_x, compact_slot_y, 0, false) == true)
assert(#command_calls == compact_calls + 2
        and command_calls[#command_calls - 1][2] == 'select'
        and command_calls[#command_calls][2] == 'load'
        and command_calls[#command_calls][3] == '2',
    'an occupied compact preset slot must select and stage its plan immediately')
assert(#pending == 1 and pending[1].id == 1009
        and dismissals.Valaineral == true
        and dismissals.mihliapoh == true,
    ('compact preset loading must replace unrelated staging with its validated delta '
        .. '(pending=%s, dismissal=%s, output=%s)'):format(
        tostring(pending[1] and pending[1].id),
        tostring(dismissals.Valaineral),
        tostring(compact_command_output[#compact_command_output])))
assert(compact_command_output[#compact_command_output]
        and compact_command_output[#compact_command_output]:find(
            '1 summon and 2 dismissals selected', 1, true),
    'compact preset loading must use the same real planning result as expanded Load')

-- Selecting an empty compact slot represents an empty compact plan. It must
-- clear the previous preset delta so SUMMON cannot retain a stale count.
function _run_empty_compact_preset_test()
    persisted_settings.presets.slots.slot_5 = {}
    local slot_x = ui.launcher_x
        + math.floor((64 + 4 * (28 + 4) + 14) * ui.scale + 0.5)
    local calls = #command_calls
    assert(ui:on_mouse(1, slot_x, compact_slot_y, 0, false) == true)
    assert(ui:on_mouse(2, slot_x, compact_slot_y, 0, false) == true)
    assert(#command_calls == calls + 1
            and command_calls[#command_calls][2] == 'select',
        'an empty compact preset must clear the previous compact plan')
    assert(#pending == 0 and next(dismissals) == nil,
        'an empty compact preset must leave no stale summons or dismissals')
    assert(ui.object_pool.queue_action_button_disabled_rect[1].visible,
        'an empty compact preset must disable SUMMON')
end
_run_empty_compact_preset_test()
_run_empty_compact_preset_test = nil

-- A partial compact load remains actionable, skips only the cooldown member,
-- and replaces the previous plan. Its inline reason uses the shared compact
-- status region.
entries[3].recast_raw = 60
persisted_settings.presets.slots.slot_1 = {
    presets.member(896, 'Valaineral'),
    presets.member(1009, 'Mihli II'),
}
ui:render(false)
local compact_slot_1_x = ui.launcher_x
    + math.floor((64 + 14) * ui.scale + 0.5)
local partial_calls = #command_calls
assert(ui:on_mouse(1, compact_slot_1_x, compact_slot_y, 0, false) == true)
assert(ui:on_mouse(2, compact_slot_1_x, compact_slot_y, 0, false) == true)
assert(#command_calls == partial_calls + 2
        and command_calls[#command_calls][2] == 'load',
    'an actionable partial compact preset must still use the load path')
assert(#pending == 0 and dismissals.Valaineral == nil
        and dismissals.mihliapoh == true,
    'a partial compact load must replace the prior plan and retain target members')
assert(ui.preset_warning and ui.preset_warning.partial
        and visible_compact_status() == nil
        and visible_pool_record('compact_preset_preview_status').value
            == '1 COOLDOWN',
    'a partial compact preset must summarize its skipped cooldown member beside the portraits')
_partial_portraits = visible_pool_records('compact_preset_portrait')
assert(#_partial_portraits == 2
        and _partial_portraits[1].target_alpha == 255
        and _partial_portraits[2].target_alpha == 145,
    'compact preset previews must mute only the member on cooldown')
assert(_partial_portraits[1].path:find(
            'assets/compact_headshots/valaineral.png', 1, true),
    'compact preset previews must use dedicated square headshot assets')
assert(_partial_portraits[1].x == ui:_s(406),
    'compact preset headshots must remain left-aligned in the status region')
_partial_markers = visible_pool_records('compact_preset_portrait_marker')
assert(#_partial_markers == 2
        and _partial_markers[1].color.g == 216
        and _partial_markers[2].color.r == 246,
    'active and cooldown preset portraits must retain distinct green and amber markers')
_partial_portraits = nil
_partial_markers = nil

queue_state = {active=true, status='awaiting_action', phase='summoning',
    current_name='Mihli Aliapoh', attempt=1, max_attempts=2,
    action_timeout=10, action_remaining=9}
ui:render(false)
assert(visible_pool_record('compact_preset_portrait') == nil,
    'compact preset portraits must disappear while party changes are running')
queue_state = {active=false, status='cancelled', reason='user_cancelled'}
ui:render(false)
assert(#visible_pool_records('compact_preset_portrait') == 2,
    'compact preset portraits must return immediately after cancellation')

-- If every target member is unavailable, compact selection must not call Load
-- or destroy the useful plan that is already staged.
persisted_settings.presets.slots.slot_1 = {
    presets.member(1009, 'Mihli II'),
}
ui:render(false)
local blocked_calls = #command_calls
assert(ui:on_mouse(1, compact_slot_1_x, compact_slot_y, 0, false) == true)
assert(ui:on_mouse(2, compact_slot_1_x, compact_slot_y, 0, false) == true)
assert(#command_calls == blocked_calls + 1
        and command_calls[#command_calls][2] == 'select',
    'a blocked compact preset must remain selectable without invoking Load')
assert(#pending == 0 and dismissals.mihliapoh == true,
    'a blocked compact preset must preserve the existing staged plan')
assert(ui.preset_warning and not ui.preset_warning.partial
        and visible_compact_status() == nil
        and visible_pool_record('compact_preset_preview_status').value
            == '1 COOLDOWN'
        and visible_pool_record('compact_preset_portrait').target_alpha == 145,
    'a blocked compact preset must visibly mute and summarize its cooldown member')
assert(ui.compact_preset_restore_pending == true,
    'a cooldown-blocked compact preset must remain eligible for revalidation')
entries[3].recast_raw = 0
ui:render(false)
assert(#command_calls == blocked_calls + 2
        and command_calls[#command_calls][1] == 'preset'
        and command_calls[#command_calls][2] == 'load'
        and command_calls[#command_calls][3] == '1',
    'a selected compact preset must automatically load when zoning clears its cooldown')
assert(ui.object_pool.queue_action_button_enabled_rect[1].visible,
    'cooldown recovery must immediately enable the compact primary action')
pending = {}
dismissals = {mihliapoh=true}
assert(presets.select(persisted_settings.presets, 2))
ui.commands = spy_commands

queue_state = {active=true, status='awaiting_action', phase='dismissing',
    position=1, total=1, current_name='Valaineral', attempt=1,
    max_attempts=2, action_timeout=10, action_remaining=9}
ui:render(false)
local compact_comets = ui.object_pool.compact_preset_comet
assert(compact_comets and compact_comets[1].visible
        and compact_comets[1].color.r == 255,
    'compact preset activity must render the red dismissal comet')
queue_state.phase = 'summoning'
ui:render(false)
assert(compact_comets[1].visible and compact_comets[1].color.r == 239,
    'compact preset activity must switch to the white summoning comet')
queue_state = {active=false, status='complete', run_id=45, summoned=1,
    last_trust_id=909, last_trust_name='Mihli Aliapoh'}

local compact_start_x = ui.launcher_x
local compact_start_y = ui.launcher_y
local compact_drag_x = compact_start_x + math.floor(500 * ui.scale + 0.5)
local compact_drag_y = compact_start_y + math.floor(6 * ui.scale + 0.5)
assert(ui:on_mouse(1, compact_drag_x, compact_drag_y, 0, false) == true)
assert(ui:on_mouse(0, compact_drag_x + 20, compact_drag_y + 15, 0, false) == true)
assert(ui:on_mouse(2, compact_drag_x + 20, compact_drag_y + 15, 0, false) == true)
assert(ui.launcher_x == compact_start_x + 20
        and ui.launcher_y == compact_start_y + 15,
    'dragging compact padding must move the entire launcher-anchored bar')
assert(ui.x == expanded_x and ui.y == expanded_y,
    'dragging compact mode must not change the expanded window position')

local restore_x = ui.launcher_x + math.floor((676 + 16) * ui.scale + 0.5)
local restore_y = ui.launcher_y + math.floor((14 + 16) * ui.scale + 0.5)
assert(ui:on_mouse(1, restore_x, restore_y, 0, false) == true)
assert(ui:on_mouse(2, restore_x, restore_y, 0, false) == true)
assert(ui.mode == 'expanded' and ui.x == expanded_x and ui.y == expanded_y
        and ui.scale == expanded_scale,
    'restoring must return to the independently saved expanded position and scale')
assert(ui:minimize())
assert(ui.scale == compact_scale,
    'minimizing again must restore the independently saved compact scale')
ui:close()
ui:open()
assert(ui.mode == 'compact',
    'closing and reopening must restore the last compact panel mode')
local integrated_icon_x = ui.launcher_x + math.floor((10 + 18) * ui.scale + 0.5)
local integrated_icon_y = ui.launcher_y + math.floor((12 + 18) * ui.scale + 0.5)
assert(ui:on_mouse(1, integrated_icon_x, integrated_icon_y, 0, false) == true)
assert(ui:on_mouse(2, integrated_icon_x, integrated_icon_y, 0, false) == true)
assert(ui.visible == false and ui.mode == 'compact',
    'clicking the integrated Trust icon must collapse to launcher-only')
ui:open()

ui:close()
assert(ui.visible == false)
local launcher_start_x = ui.launcher_x
local launcher_start_y = ui.launcher_y
assert(ui:on_mouse(1, ui.launcher_x + 5, ui.launcher_y + 5, 0, false) == true)
assert(ui.launcher_pressed, 'pressing the launcher must show its pressed treatment')
assert(ui:on_mouse(0, launcher_start_x + 35, launcher_start_y + 25, 0, false) == true)
assert(ui:on_mouse(2, launcher_start_x + 35, launcher_start_y + 25, 0, false) == true)
assert(not ui.launcher_pressed, 'releasing a dragged launcher must restore its normal tint')
assert(ui.launcher_x == launcher_start_x + 30 and ui.launcher_y == launcher_start_y + 20,
    'dragging the launcher must reposition it by the pointer movement')
assert(ui.visible == false, 'dragging the launcher must not toggle the window')
assert(ui:on_mouse(1, ui.launcher_x + 5, ui.launcher_y + 5, 0, false) == true)
assert(ui.launcher_pressed, 'a launcher click must show its pressed treatment')
assert(ui.visible == false, 'launcher clicks toggle only on release')
assert(ui:on_mouse(2, ui.launcher_x + 5, ui.launcher_y + 5, 0, false) == true)
assert(not ui.launcher_pressed, 'releasing a launcher click must restore its normal tint')
assert(ui.visible == true)

-- Repeated state/layout changes must reuse the bounded primitive pools rather
-- than accumulating layers or hitboxes. One warm-up pass visits every layout;
-- subsequent passes should leave the number of live primitives unchanged.
_run_ui_stability_stress = function(target_ui, target_entries)
    target_ui:restore()
    local original_entry_count = #target_entries
    for index = 1, 24 do
        target_entries[#target_entries + 1] = {
            id=2000 + index,
            icon_id=2000 + index,
            en=('Stability Trust %02d'):format(index),
            identity_key=('stability_trust_%02d'):format(index),
            learned=true,
            recast_raw=0,
            cooldown_seconds=0,
            in_party=false,
            active_exact=false,
            card='assets/cards/valaineral.png',
            metadata={
                role=({'tank', 'melee', 'ranged', 'caster', 'healer', 'support'})
                    [(index - 1) % 6 + 1],
                affiliation='bastok',
            },
        }
    end

    local function pass()
        target_ui:restore()
        for _, scale in ipairs({0.55, 0.78, 1.0, 1.25}) do
            target_ui:set_scale(scale)
            for filter_index = 1, 7 do
                target_ui.filter_index = filter_index
                target_ui.filter_dropdown_open = filter_index % 2 == 0
                target_ui.scroll = filter_index * 3
                target_ui:render(false)
            end
            target_ui.filter_dropdown_open = false
            for sort_index = 1, 4 do
                target_ui.sort_index = sort_index
                target_ui.sort_dropdown_open = sort_index % 2 == 0
                target_ui.scroll = sort_index * 4
                target_ui:render(false)
            end
            target_ui.sort_dropdown_open = false
        end
        target_ui:minimize()
        target_ui:render(false)
        target_ui:restore()
        target_ui:close()
        target_ui:open()
    end

    local function action_state_pass()
        local saved_pending = pending
        local saved_dismissals = dismissals
        local saved_queue = queue_state
        local identity = state.party_trusts[1]
            and state.party_trusts[1].identity_key or entries[2].identity_key

        target_ui:minimize()
        pending = {}
        dismissals = {}
        queue_state = {active=false, status='idle'}
        target_ui:render(false)
        assert(target_ui.object_pool.queue_action_button_disabled_rect[1].visible)

        pending = {target_entries[1]}
        target_ui:render(false)
        assert(visible_text_record('SUMMON (1)'))
        assert(target_ui.object_pool.queue_action_button_enabled_rect[1].visible
                and not target_ui.object_pool
                    .queue_action_button_disabled_rect[1].visible,
            'an actionable plan must show only the enabled primary palette')

        pending = {}
        dismissals[identity] = true
        target_ui:render(false)
        assert(visible_text_record('DISMISS (1)'))

        pending = {target_entries[1]}
        target_ui:render(false)
        assert(visible_text_record('APPLY (-1 / +1)'))

        queue_state = {
            active=true,
            phase='summoning',
            status='awaiting_action',
            current_id=target_entries[1].id,
            current_name=target_entries[1].en,
            attempt=1,
            max_attempts=2,
            action_timeout=10,
            action_remaining=9,
        }
        target_ui:render(false)
        assert(visible_text_record('CANCEL'))
        assert(not has_hitbox('preset_slot:'),
            'compact preset hitboxes must remain absent throughout execution')

        queue_state.status = 'retry_wait'
        queue_state.reason = 'cast_temporarily_blocked'
        queue_state.block_cause = 'movement'
        queue_state.retry_remaining = 4.2
        target_ui:render(false)
        local movement_notice = visible_compact_status().value
        assert(movement_notice:find('MOVEMENT', 1, true)
                and movement_notice:find('5s', 1, true),
            'compact movement recovery must retain its cause and countdown')

        -- Restoring during execution must retain the shared queue state and
        -- active CANCEL action rather than interrupting or resetting progress.
        target_ui:restore()
        target_ui:render(false)
        local enabled_cancel =
            target_ui.object_pool.queue_cancel_button_enabled_rect
        assert(enabled_cancel and #enabled_cancel == 3
                and enabled_cancel[1].visible
                and enabled_cancel[2].visible
                and enabled_cancel[3].visible,
            'restoring during compact execution must show every enabled CANCEL layer')
        for _, record in ipairs(
                target_ui.object_pool.queue_cancel_button_disabled_rect or {}) do
            assert(not record.visible,
                'restoring during compact execution must hide disabled CANCEL layers')
        end
        for _, record in ipairs(
                target_ui.object_pool.queue_action_button_disabled_rect or {}) do
            assert(not record.visible,
                'restoring during compact execution must hide the disabled action palette')
        end
        assert(target_ui.keyed_pool.footer_background.main.object.creation_index
                < enabled_cancel[1].object.creation_index,
            'the expanded footer must remain beneath compact-created CANCEL layers')
        assert(queue_state.active and queue_state.status == 'retry_wait')
        target_ui:minimize()

        queue_state = {
            active=false,
            phase='summoning',
            status='stopped',
            reason='party_full',
        }
        target_ui:render(false)
        assert(visible_compact_status().value:find(
            'PARTY CAPACITY CHANGED', 1, true))

        queue_state = {active=false, status='idle'}
        target_ui:render(false)
        assert(visible_compact_status() == nil,
            'returning to idle must hide the previous compact status')

        pending = saved_pending
        dismissals = saved_dismissals
        queue_state = saved_queue
        target_ui:restore()
        target_ui:set_scale(0.55)
        target_ui:render(false)
        assert(visible_text_record('ALL'),
            'minimum expanded scale must abbreviate DISMISS ALL to fit')
        target_ui:set_scale(0.78)
        target_ui:render(false)
        assert(visible_text_record('DISMISS ALL'),
            'larger expanded scales must retain the full batch-action label')
        target_ui:set_scale(0.82449009136785)
        target_ui:render(false)
        assert(visible_text_record('DISMISS ALL'),
            'rounded font-size transitions must not revert the batch label')
        target_ui:set_scale(0.78)
        target_ui:render(false)
    end

    pass()
    action_state_pass()
    local stable_live_objects = created - destroyed
    local stable_hitboxes = #target_ui.hitboxes
    for _ = 1, 10 do
        pass()
        action_state_pass()
        assert(created - destroyed == stable_live_objects,
            'repeated filter, scroll, resize, mode, and visibility cycles must not leak primitives')
        assert(#target_ui.hitboxes == stable_hitboxes,
            'repeated layout cycles must not accumulate stale hitboxes')
    end

    -- Simulate five minutes of idle refresh ticks without making the test wait
    -- in real time. A stable signature must not create new visual objects.
    local before_soak_created = created
    for _ = 1, 600 do
        clock_now = clock_now + 0.5
        target_ui:tick()
    end
    assert(created == before_soak_created,
        'five minutes of stable refresh ticks must not create additional primitives')
    assert(target_ui.mouse_capture == nil and target_ui.scrollbar_drag == nil
            and target_ui.drag == nil and target_ui.resize == nil,
        'stress cycles must leave no stale pointer capture')
    for _, box in ipairs(target_ui.hitboxes) do
        assert(box.kind ~= 'filter_dropdown_option'
                and box.kind ~= 'sort_dropdown_option',
            'closed dropdowns must leave no stale option hitboxes')
    end

    for index = #target_entries, original_entry_count + 1, -1 do
        target_entries[index] = nil
    end
    target_ui.filter_index = 1
    target_ui.sort_index = 1
    target_ui.scroll = 0
    target_ui:set_scale(0.78)
    target_ui:render(false)
end
_run_ui_stability_stress(ui, entries)
_run_ui_stability_stress = nil
_run_party_fallback_test()
_run_party_fallback_test = nil
_run_five_slot_dismiss_all_test()
_run_five_slot_dismiss_all_test = nil
ui:close()
ui:destroy()
assert(destroyed > 20)

io.write(('UI smoke test passed with %d primitives created.\n'):format(created))
