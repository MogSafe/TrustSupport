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
    local result
    result = {
        creation_index = creation_index,
        show = function() show_calls = show_calls + 1 end,
        hide = function() hide_calls = hide_calls + 1 end,
        pos = function(_, x, y)
            result.last_x = x
            result.last_y = y
        end,
        size = function(_, next_size)
            current_size = next_size
            if is_text then
                text_resizes = text_resizes + 1
            end
        end,
        color = function() end,
        alpha = function() end,
        destroy = function()
            destroyed = destroyed + 1
        end,
    }
    if is_text then
        result.text = function(_, next_value)
            value = next_value
            rendered_text[#rendered_text + 1] = next_value
        end
        result.font = function() end
        result.bold = function() end
        result.stroke_width = function() end
        result.stroke_color = function() end
        result.stroke_alpha = function() end
        result.extents = function()
            extent_calls = extent_calls + 1
            return #tostring(value or '') * current_size * 0.7, current_size
        end
    else
        result.fit = function() end
        result.path = function() end
    end
    return result
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
local trust_synergy_pair = {
    id='mihli_valaineral',
    members={'Mihli Aliapoh','Valaineral'},
    trigger='When Valaineral is summoned with Mihli Aliapoh.',
    summary='Valaineral prioritizes Mihli Aliapoh for support.',
    effects={{trust='Valaineral', text='Healing magic: prioritizes Mihli Aliapoh.'}},
    notes={
        'Unconfirmed speculation must not appear in the popup.',
        'This behavior is documented on the Trust pages.',
        'It may leave the player without another target.',
    },
}
local trust_synergy_fixture = {
    by_trust={
        ['Mihli Aliapoh']={trust_synergy_pair},
        ['Valaineral']={trust_synergy_pair},
        ['Teodor']={{id='teodor_unverified', kind='unverified',
            confidence='unverified', detail_status='missing_details',
            members={'Teodor','Morimar'}, effects={}}},
        ['Mumor']={{id='estimated_only', kind='party_bonus',
            confidence='estimated', members={'Mumor','Uka Totlihn'},
            effects={{trust='Mumor', text='Samba duration: ~+10%.',
                confidence='estimated', value_status='approximate'}}}},
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
function state:clear()
    local removed = #pending
    pending, dismissals = {}, {}
    return removed, 0
end

local persisted_settings = {
    icon=true,
    ui={x=100, y=100, scale=0.78},
    presets=presets.new_settings(),
}
local saved = 0
local command_calls = {}
local command_options = {}
local commands = {}
function commands:handle(args, options)
    command_calls[#command_calls + 1] = args
    command_options[#command_calls] = options or false
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
    trust_synergy=trust_synergy_fixture,
    settings=persisted_settings,
    images=images,
    texts=texts,
    addon_path='C:/Windower/addons/TrustSupport/',
    windower_path='C:/Windower',
    file_exists=function() return true end,
    save_settings=function() saved = saved + 1 end,
    clock=function() return clock_now end,
})
assert(#ui:_roster_synergy_groups({en='Teodor'}) == 0,
    'a pairing with no reported effect must not expose a marker or popup group')
assert(#ui:_roster_synergy_groups({en='Mumor'}) == 0,
    'a group whose only effects are estimated or approximate must be hidden')
assert(type(ui.trust_synergy) == 'table',
    'UI constructor must retain the loaded Trust synergy resource')
do
    trust_synergy_fixture.by_trust['Missing Partner Test'] = {{
        id='missing_partner_test', members={'Missing Partner Test','Unknown Partner'},
        effects={{trust='Missing Partner Test', text='Test effect.'}},
    }}
    local rows = ui:_synergy_popup_rows('Missing Partner Test')
    local status
    for _, row in ipairs(rows) do
        if row.kind == 'partner' and row.name == 'Unknown Partner' then
            status = row.status
        end
    end
    assert(status == 'NOT LEARNED',
        'a synergy partner absent from the learned roster must display NOT LEARNED')
    trust_synergy_fixture.by_trust['Missing Partner Test'] = nil
end

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

do
    local original_party = state.party_trusts
    local original_pending = pending
    local original_dismissals = dismissals
    local active_a = {
        id=2001, name='Active A', identity_key='active_a',
        trust={id=2001, en='Active A', identity_key='active_a'},
    }
    local active_b = {
        id=2002, name='Active B', identity_key='active_b',
        trust={id=2002, en='Active B', identity_key='active_b'},
    }
    local active_c = {
        id=2003, name='Active C', identity_key='active_c',
        trust={id=2003, en='Active C', identity_key='active_c'},
    }
    local incoming_a = {id=3001, en='Incoming A', identity_key='incoming_a'}
    local incoming_b = {id=3002, en='Incoming B', identity_key='incoming_b'}

    state.party_trusts = {active_a, active_b, active_c}
    pending = {incoming_a, incoming_b}
    dismissals = {active_a=true}
    local rows = ui:_party_preview_rows()
    assert(#rows == 4
            and rows[1].active == active_b
            and rows[2].active == active_c
            and rows[3].outgoing == active_a
            and rows[3].incoming == incoming_a
            and rows[4].incoming == incoming_b,
        'party preview must keep retained Trusts first, then replacements and incoming-only rows')

    dismissals = {active_a=true, active_b=true, active_c=true}
    rows = ui:_party_preview_rows()
    assert(#rows == 3
            and rows[1].outgoing == active_a
            and rows[1].incoming == incoming_a
            and rows[2].outgoing == active_b
            and rows[2].incoming == incoming_b
            and rows[3].outgoing == active_c
            and rows[3].incoming == nil,
        'party preview must pair dismiss-all replacements in party and selection order')

    state.party_trusts = {}
    dismissals = {}
    rows = ui:_party_preview_rows()
    assert(#rows == 2 and rows[1].incoming == incoming_a
            and rows[2].incoming == incoming_b,
        'party preview must render queued summons in otherwise empty slots')

    state.party_trusts = original_party
    pending = original_pending
    dismissals = original_dismissals
end

do
    local original_party = state.party_trusts
    local original_pending = pending
    local original_dismissals = dismissals
    local original_queue = queue_state
    local active_a = {
        id=4001, name='Stable A', identity_key='stable_a',
        trust={id=4001, en='Stable A', identity_key='stable_a'},
    }
    local active_b = {
        id=4002, name='Stable B', identity_key='stable_b',
        trust={id=4002, en='Stable B', identity_key='stable_b'},
    }
    local active_c = {
        id=4003, name='Stable C', identity_key='stable_c',
        trust={id=4003, en='Stable C', identity_key='stable_c'},
    }
    local incoming_a = {id=5001, en='Incoming A', identity_key='incoming_a'}
    local incoming_b = {id=5002, en='Incoming B', identity_key='incoming_b'}

    state.party_trusts = {active_a, active_b, active_c}
    pending = {incoming_a, incoming_b}
    dismissals = {stable_a=true, stable_b=true}
    queue_state = {active=true, phase='dismissing', status='awaiting_dismissal'}
    ui.execution_party_rows = nil
    local rows = ui:_party_preview_rows()
    assert(rows[1].active == active_c
            and rows[2].outgoing == active_a
            and rows[2].incoming == incoming_a
            and rows[3].outgoing == active_b
            and rows[3].incoming == incoming_b,
        'Apply must capture the original retained and replacement row identities')

    state.party_trusts = {active_b, active_c}
    dismissals = {stable_b=true}
    rows = ui:_party_preview_rows()
    assert(rows[1].active == active_c
            and rows[2].incoming == incoming_a
            and rows[2].outgoing == nil
            and rows[3].outgoing == active_b
            and rows[3].incoming == incoming_b,
        'a confirmed dismissal must expand its paired incoming card without moving rows')

    queue_state = {active=false, status='cancelled', reason='user_cancelled'}
    rows = ui:_party_preview_rows()
    assert(ui.execution_party_rows == nil
            and rows[1].active == active_c
            and rows[2].outgoing == active_b
            and rows[2].incoming == incoming_a
            and rows[3].incoming == incoming_b,
        'Cancel must release the execution snapshot and reflow the remaining plan')

    state.party_trusts = {active_a, active_b, active_c}
    pending = {}
    dismissals = {stable_a=true, stable_b=true}
    queue_state = {active=true, phase='dismissing', status='awaiting_dismissal'}
    ui.execution_party_rows = nil
    ui:_party_preview_rows()
    state.party_trusts = {active_b, active_c}
    dismissals = {stable_b=true}
    rows = ui:_party_preview_rows()
    assert(rows[2].placeholder == 'EMPTY',
        'an outgoing-only execution row must use a neutral EMPTY placeholder')

    state.party_trusts = original_party
    pending = original_pending
    dismissals = original_dismissals
    queue_state = original_queue
    ui.execution_party_rows = nil
end

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
local initial_text = table.concat(rendered_text, '|')
assert(initial_text:find('CURRENT PARTY 1/4', 1, true),
    'the party heading must show the resulting Trust count and capacity')
assert(not initial_text:find('SUMMON  0 / 3', 1, true),
    'the removed staged-preview heading must not render')
assert(initial_text:find('|EMPTY|', 1, true))
assert(initial_text:find('|READY|', 1, true))
assert(initial_text:find('|DISMISS|', 1, true),
    'an active Trust must show a singular dismiss action button')
local mihli_synergy_marker = ui.keyed_pool.roster_synergy_marker
    and ui.keyed_pool.roster_synergy_marker['909']
assert(mihli_synergy_marker and mihli_synergy_marker.visible
        and mihli_synergy_marker.path:find('trust%-synergy%-marker%.png'),
    'a roster Trust with synergy data must show the twin-star marker asset')
do
    local ready_status_x, ready_status_count = nil, 0
    for _, record in pairs(ui.keyed_pool.roster_status or {}) do
        if record.frame == ui.frame_id and record.value == 'READY' then
            ready_status_x = ready_status_x or record.x
            ready_status_count = ready_status_count + 1
            assert(record.x == ready_status_x,
                'synergy markers must not shift the READY status column')
        end
    end
    assert(ready_status_count >= 2, 'status alignment test needs two ready rows')
end
assert(not ui.keyed_pool.roster_synergy_marker['1009'],
    'Trusts without synergy data must not get roster markers')
local valaineral_card_marker = ui.keyed_pool.active_card_synergy_marker
    and ui.keyed_pool.active_card_synergy_marker['896']
local valaineral_emblem = ui.keyed_pool.active_affiliation_emblem['896']
assert(valaineral_card_marker and valaineral_card_marker.visible
        and valaineral_emblem
        and valaineral_card_marker.object.creation_index
            > valaineral_emblem.object.creation_index
        and valaineral_card_marker.image_width == valaineral_emblem.image_width
        and valaineral_card_marker.y
            >= valaineral_emblem.y + valaineral_emblem.image_height
                + ui:_s(8),
    'card synergy badges must match emblem diameter with clear vertical spacing')
assert(valaineral_card_marker.image_alpha == 210
        and valaineral_card_marker.color.r == 220,
    'the card badge base should be muted against the soft card artwork')
assert(not ui.keyed_pool.active_card_synergy_marker['909'],
    'staged incoming Trusts must not receive active-card synergy markers')
;(function()
local marker_alpha = mihli_synergy_marker.image_alpha
local card_alpha = valaineral_card_marker.image_alpha
ui:_update_synergy_marker_animation(2.1)
assert(mihli_synergy_marker.image_alpha == marker_alpha
        and valaineral_card_marker.image_alpha == card_alpha,
    'roster markers and card seals must remain static')
assert(not ui.keyed_pool.active_card_synergy_stars
        or not ui.keyed_pool.active_card_synergy_stars['896'],
    'a lone Trust must not display an active-synergy pulse')
end)()
;(function()
local mihli_marker_hitbox
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'synergy_marker'
            and box.hover_key == 'synergy_marker:Mihli Aliapoh' then
        mihli_marker_hitbox = box
        break
    end
end
assert(mihli_marker_hitbox,
    'roster synergy markers must expose a popup hover and click target')
local mihli_marker_x = ui.x
    + math.floor((mihli_marker_hitbox.x + mihli_marker_hitbox.width / 2)
        * ui.scale + 0.5)
local mihli_marker_y = ui.y
    + math.floor((mihli_marker_hitbox.y + mihli_marker_hitbox.height / 2)
        * ui.scale + 0.5)
local popup_text_start = #rendered_text
ui:on_mouse(0, mihli_marker_x, mihli_marker_y, 0, false)
assert(ui.synergy_popup_trust == nil
        and ui.synergy_hover_candidate == 'Mihli Aliapoh',
    'brief marker crossings must not open a transient popup')
local warming_partner_stars = ui.keyed_pool.roster_synergy_partner_stars
    and ui.keyed_pool.roster_synergy_partner_stars['896']
assert(warming_partner_stars and warming_partner_stars.visible
        and warming_partner_stars.image_alpha == 0
        and warming_partner_stars.texture_ready_frame == ui.frame_id + 1
        and ui.deferred_texture_reveal,
    'a newly hovered partner-star texture must warm invisibly instead of flashing a gold square')
clock_now = clock_now + 0.08
ui:tick()
assert(warming_partner_stars.image_alpha > 0
        and warming_partner_stars.texture_ready_frame == nil,
    'the roster star overlay must reveal after its transparent warmup')
assert(ui.synergy_popup_trust == nil,
    'the popup should wait through the hover-intent interval')
clock_now = clock_now + 0.06
ui:tick()
assert(ui.synergy_popup_trust == 'Mihli Aliapoh'
        and not ui.synergy_popup_pinned,
    'sustained marker hover must open a transient shared synergy popup')
assert(mihli_synergy_marker.image_width > math.floor(18 * ui.scale),
    'hovering the roster synergy marker must enlarge it')
local partner_stars = ui.keyed_pool.roster_synergy_partner_stars
    and ui.keyed_pool.roster_synergy_partner_stars['896']
assert(partner_stars and partner_stars.visible
        and not (ui.keyed_pool.roster_synergy_partner_stars
            and ui.keyed_pool.roster_synergy_partner_stars['909']),
    'hovering a synergy icon should pulse visible partners, not the source')
local partner_alpha = partner_stars.image_alpha
ui:_update_synergy_marker_animation(0.525)
assert(partner_stars.image_alpha ~= partner_alpha,
    'a hovered roster partner should have a time-varying star highlight')
local unrelated_group = {{
    id='unrelated_hover_probe',
    members={'Mihli II', 'Other'},
    effects={{trust='Mihli II', text='Support: increases.'}},
}}
ui.hover_key = nil
ui.trust_synergy.by_trust['Mihli II'] = unrelated_group
ui:render(false)
local unrelated_marker = ui.keyed_pool.roster_synergy_marker['1009']
assert(unrelated_marker and unrelated_marker.image_alpha == 205,
    'an unrelated marker starts at normal opacity before source hover')
ui.hover_key = 'synergy_marker:Mihli Aliapoh'
ui:render(false)
assert(unrelated_marker and unrelated_marker.visible
        and unrelated_marker.image_alpha == 205
        and ui.synergy_roster_dim_active
        and mihli_synergy_marker.image_alpha >= 205
        and ui.keyed_pool.roster_synergy_marker['896'].image_alpha == 205,
    'source hover should begin a fade without flashing unrelated icons')
clock_now = clock_now + 0.09
ui:_update_synergy_marker_animation(clock_now)
assert(unrelated_marker.image_alpha > 65
        and unrelated_marker.image_alpha < 205,
    'unrelated marker opacity should pass through an intermediate value')
clock_now = clock_now + 0.11
ui:_update_synergy_marker_animation(clock_now)
assert(unrelated_marker.image_alpha == 65
        and mihli_synergy_marker.image_alpha == 245
        and ui.keyed_pool.roster_synergy_marker['896'].image_alpha == 205,
    'only unrelated markers should reach the dimmed target')
ui.hover_key = nil
ui:render(false)
assert(unrelated_marker.image_alpha == 65,
    'leaving the source icon should begin a fade back without flashing')
clock_now = clock_now + 0.20
ui:_update_synergy_marker_animation(clock_now)
assert(unrelated_marker.image_alpha == 205,
    'unrelated synergy icons must return to full strength after hover ends')
ui.synergy_popup_pinned = true
ui.hover_key = 'synergy_popup:surface'
ui:render(false)
clock_now = clock_now + 0.20
ui:_update_synergy_marker_animation(clock_now)
assert(unrelated_marker.image_alpha == 65
        and ui.keyed_pool.roster_synergy_marker['896'].image_alpha == 205
        and not partner_stars.visible,
    'a pinned popup must retain partner focus without continuously pulsing stars')
ui.hover_key = 'synergy_marker:Mihli II'
ui:render(false)
assert(ui.synergy_roster_dim_state['1009'].to == 65
        and not partner_stars.visible,
    'hovering another marker must not take focus from a pinned popup')
ui.synergy_popup_pinned = false
ui.synergy_hover_suppressed = 'Mihli Aliapoh'
ui.hover_key = 'synergy_marker:Mihli Aliapoh'
ui:render(false)
clock_now = clock_now + 0.20
ui:_update_synergy_marker_animation(clock_now)
assert(unrelated_marker.image_alpha == 205,
    'unpinning must clear dimming even while the pointer remains on its marker')
ui.synergy_hover_suppressed = nil
ui.trust_synergy.by_trust['Mihli II'] = nil
ui:render(false)
ui.pressed_key = 'synergy_marker:Mihli Aliapoh'
ui:render(false)
assert(mihli_synergy_marker.image_color.r > mihli_synergy_marker.image_color.b,
    'pressing the roster synergy marker must retain the neutral gold tint')
ui.pressed_key = nil
ui:render(false)
ui.synergy_popup_pinned = true
ui:render(false)
assert(mihli_synergy_marker.image_color.r > mihli_synergy_marker.image_color.b
        and mihli_synergy_marker.image_width > math.floor(18 * ui.scale),
    'a pinned popup must retain the roster marker hover treatment')
ui.synergy_popup_pinned = false
ui:render(false)
local popup_text = table.concat(rendered_text, '|', popup_text_start + 1)
assert(popup_text:find('Mihli Aliapoh', 1, true)
        and popup_text:find('Valaineral', 1, true)
        and popup_text:find('When Valaineral is summoned', 1, true)
        and popup_text:find('Healing magic', 1, true)
        and popup_text:find('This behavior is documented', 1, true)
        and popup_text:find('IN PARTY', 1, true),
    'the popup must show sourced effects, safe notes, and partner availability')
assert(not popup_text:find('Unconfirmed speculation', 1, true)
        and not popup_text:find('may leave the player', 1, true)
        and not popup_text:find('Valaineral prioritizes Mihli', 1, true)
        and not popup_text:find('WHEN  When', 1, true),
    'the popup must omit uncertain notes, redundant summaries, and a duplicate WHEN label')
local popup_body_text
for _, records in pairs(ui.object_pool) do
    for _, record in ipairs(records) do
        if record.is_text and record.kind == 'synergy_popup_effect_ability'
                and record.value and record.value:find('Healing magic', 1, true) then
            popup_body_text = record
            break
        end
    end
    if popup_body_text then break end
end
assert(popup_body_text and popup_body_text.font_size >= 10,
    'popup body copy must keep a readable minimum physical font size at reduced UI scales')
do
    local actor
    for _, record in pairs(ui.keyed_pool.synergy_popup_effect_name or {}) do
        if record.value == 'Valaineral' then
            actor = record
            break
        end
    end
    assert(actor and actor.bold == true,
        'effect descriptions must render their Trust actor names in bold')
end
local valaineral_roster_marker
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'synergy_marker'
            and box.hover_key == 'synergy_marker:Valaineral'
            and box.x < 480 then
        valaineral_roster_marker = box
        break
    end
end
assert(valaineral_roster_marker,
    'rapid hover switching test needs the partner marker in the roster')
local valaineral_roster_x = ui.x
    + math.floor((valaineral_roster_marker.x
        + valaineral_roster_marker.width / 2) * ui.scale + 0.5)
local valaineral_roster_y = ui.y
    + math.floor((valaineral_roster_marker.y
        + valaineral_roster_marker.height / 2) * ui.scale + 0.5)
local stable_popup = ui.object_pool.synergy_popup_background[1]
ui:on_mouse(0, valaineral_roster_x, valaineral_roster_y, 0, false)
assert(ui.synergy_popup_trust == 'Mihli Aliapoh' and stable_popup.visible,
    'crossing to another marker should keep the current popup stable')
clock_now = clock_now + 0.05
ui:tick()
ui:on_mouse(0, mihli_marker_x, mihli_marker_y, 0, false)
clock_now = clock_now + 0.14
ui:tick()
assert(ui.synergy_popup_trust == 'Mihli Aliapoh',
    'a brief pass over another marker should not switch popup content')
ui:on_mouse(0, valaineral_roster_x, valaineral_roster_y, 0, false)
clock_now = clock_now + 0.14
ui:tick()
assert(ui.synergy_popup_trust == 'Valaineral',
    'sustained hover over another marker should switch popup content')
ui:on_mouse(0, mihli_marker_x, mihli_marker_y, 0, false)
clock_now = clock_now + 0.14
ui:tick()
assert(ui.synergy_popup_trust == 'Mihli Aliapoh',
    'returning to the original marker should switch after the same intent delay')
local popup_surface
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'synergy_popup_surface' then
        popup_surface = box
        break
    end
end
assert(popup_surface,
    'the shared popup must capture pointer movement over its surface')
ui:on_mouse(0,
    ui.x + math.floor((popup_surface.x + popup_surface.width - 5)
        * ui.scale + 0.5),
    ui.y + math.floor((popup_surface.y + popup_surface.height - 5)
        * ui.scale + 0.5), 0, false)
assert(ui.synergy_popup_trust == 'Mihli Aliapoh',
    'moving from a marker into its transient popup must keep it open')
assert(not partner_stars.visible,
    'partner icon pulsing should stop when the source icon is no longer hovered')
ui:on_mouse(0, ui.x - 15, ui.y - 15, 0, false)
assert(ui.synergy_popup_trust == 'Mihli Aliapoh',
    'leaving the popup should start a short close grace, not hide it immediately')
clock_now = clock_now + 0.05
ui:tick()
assert(ui.synergy_popup_trust == 'Mihli Aliapoh',
    'the transient popup should remain during the exit grace')
ui:on_mouse(0,
    ui.x + math.floor((popup_surface.x + popup_surface.width - 5)
        * ui.scale + 0.5),
    ui.y + math.floor((popup_surface.y + popup_surface.height - 5)
        * ui.scale + 0.5), 0, false)
assert(ui.synergy_hover_close_started == nil,
    're-entering the popup should cancel the pending close')
ui:on_mouse(0, ui.x - 15, ui.y - 15, 0, false)
clock_now = clock_now + 0.12
ui:tick()
assert(ui.synergy_popup_trust == nil,
    'the transient popup should close after the exit grace expires')
ui:on_mouse(0, mihli_marker_x, mihli_marker_y, 0, false)
clock_now = clock_now + 0.14
ui:tick()
assert(ui.synergy_popup_trust == 'Mihli Aliapoh',
    'a sustained return to the marker should reopen the transient popup')
local roster_scroll_x = ui.x
    + math.floor((18 + 120) * ui.scale + 0.5)
local roster_scroll_y = ui.y
    + math.floor((143 + 10) * ui.scale + 0.5)
ui:on_mouse(10, roster_scroll_x, roster_scroll_y, -1, false)
assert(ui.synergy_popup_trust == nil,
    'a transient popup must close when the roster is scrolled')
ui:on_mouse(0, mihli_marker_x, mihli_marker_y, 0, false)
assert(ui.synergy_hover_candidate == 'Mihli Aliapoh'
        and ui.synergy_popup_trust == nil)
ui:on_mouse(0, ui.x - 15, ui.y - 15, 0, false)
clock_now = clock_now + 0.15
ui:tick()
assert(ui.synergy_popup_trust == nil,
    'a brief pass over a marker must never create a delayed popup after exit')
ui:on_mouse(1, mihli_marker_x, mihli_marker_y, 0, false)
ui:on_mouse(2, mihli_marker_x, mihli_marker_y, 0, false)
assert(ui.synergy_popup_trust == 'Mihli Aliapoh' and ui.synergy_popup_pinned,
    'clicking a roster marker must pin its popup')
ui:on_mouse(1, mihli_marker_x, mihli_marker_y, 0, false)
ui:on_mouse(2, mihli_marker_x, mihli_marker_y, 0, false)
assert(ui.synergy_popup_trust == nil and not ui.synergy_popup_pinned,
    'clicking the pinned roster marker again must close, not reopen, its popup')
ui:on_mouse(0, mihli_marker_x, mihli_marker_y, 0, false)
assert(ui.synergy_popup_trust == nil,
    'closing from the marker must suppress hover reopening until the pointer leaves')
ui:on_mouse(0, ui.x - 15, ui.y - 15, 0, false)

local valaineral_marker_hitbox
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'synergy_marker'
            and box.hover_key == 'synergy_marker:Valaineral'
            and box.x > 480 then
        valaineral_marker_hitbox = box
        break
    end
end
assert(valaineral_marker_hitbox,
    'active-card synergy markers must expose the same popup target')
local valaineral_marker_x = ui.x
    + math.floor((valaineral_marker_hitbox.x + valaineral_marker_hitbox.width / 2)
        * ui.scale + 0.5)
local valaineral_marker_y = ui.y
    + math.floor((valaineral_marker_hitbox.y + valaineral_marker_hitbox.height / 2)
        * ui.scale + 0.5)
ui:on_mouse(1, valaineral_marker_x, valaineral_marker_y, 0, false)
ui:on_mouse(2, valaineral_marker_x, valaineral_marker_y, 0, false)
assert(ui.synergy_popup_trust == 'Valaineral' and ui.synergy_popup_pinned,
    'clicking an active-card marker must pin the same shared popup')
local hidden_underlay_labels = {}
for _, records in pairs(ui.object_pool) do
    for _, record in ipairs(records) do
        if record.is_text and record.value then
            if record.value:find('CURRENT PARTY', 1, true)
                    or record.value == 'EMPTY'
                    or record.value == 'DISMISS ALL' then
                hidden_underlay_labels[record.value] = record.visible == false
            end
        end
    end
end
local obscured_count = 0
for _, record in ipairs(ui.objects) do
    if record.synergy_obscured then
        obscured_count = obscured_count + 1
        assert(not record.visible, 'overlapping text and image layers must stay hidden')
    end
end
assert(obscured_count > 0, 'the popup must suppress intersecting card layers')
local original_queue_state = queue_state
queue_state = {active=true, phase='dismissing', status='running'}
ui:render(false)
local popup_has_partner_action = false
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'synergy_popup_partner_action' and box.action then
        popup_has_partner_action = true
        break
    end
end
assert(ui.synergy_popup_trust == 'Valaineral'
        and not popup_has_partner_action,
    'synergy details remain inspectable during dismissal while partner changes are locked')
queue_state = original_queue_state
ui:render(false)
local pinned_popup = ui.object_pool.synergy_popup_background[1]
assert(pinned_popup.path:find('roster%-panel%-inner%-rounded%-mask%.png')
        and ui.object_pool.synergy_popup_border[1].path:find(
            'roster%-panel%-rounded%-mask%.png'),
    'the popup shell should use the rounded menu masks')
assert(ui.object_pool.synergy_popup_close[1].path:find(
        'close%-button%-subtle%.png'),
    'the popup should reuse the menu circular close control')
assert(ui.object_pool.synergy_popup_close[1].y
        + ui.object_pool.synergy_popup_close[1].image_height
        < ui.object_pool.synergy_popup_header_divider[1].y,
    'the close button must clear the header divider')
assert(ui.object_pool.synergy_popup_partner_action_border[1].path:find(
        'active%-action%-capsule%-border%-mask%.png'),
    'popup Add buttons should match the existing capsule actions')
local pinned_popup_x = pinned_popup.x
local pinned_popup_y = pinned_popup.y
ui.drag_preview = true
ui:_render_drag_preview()
assert(ui.synergy_popup_trust == 'Valaineral'
        and not pinned_popup.visible and #ui.objects == 1,
    'dragging must show only the lightweight shell preview while preserving popup state')
ui:_end_drag_preview()
assert(pinned_popup.visible and pinned_popup.x == pinned_popup_x
        and pinned_popup.y == pinned_popup_y,
    'the pinned popup must return in its fixed menu-relative position after dragging')
ui:on_mouse(10, roster_scroll_x, roster_scroll_y, -1, false)
assert(ui.synergy_popup_trust == 'Valaineral'
        and pinned_popup.x == pinned_popup_x and pinned_popup.y == pinned_popup_y,
    'a pinned popup must stay fixed to the menu while the roster scrolls')
local partner_action
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'synergy_popup_partner_action' and box.action then
        partner_action = box
        break
    end
end
assert(partner_action,
    'a ready popup partner must offer an add action')
local partner_x = ui.x
    + math.floor((partner_action.x + partner_action.width / 2)
        * ui.scale + 0.5)
local partner_y = ui.y
    + math.floor((partner_action.y + partner_action.height / 2)
        * ui.scale + 0.5)
ui:on_mouse(0, partner_x, partner_y, 0, false)
assert(ui.hover_key == partner_action.hover_key,
    'the Add button needs its own hover target')
local hovered_action_border = false
for _, record in ipairs(ui.object_pool.synergy_popup_partner_action_border or {}) do
    if record.visible and record.color and record.color.r == 112
            and record.color.g == 224 then
        hovered_action_border = true
    end
end
assert(hovered_action_border,
    'hovering Add should visibly brighten its capsule border')
ui.synergy_popup_pinned = false
ui:render(false)
local original_select_entry = ui._select_entry
local selected_popup_partner
ui._select_entry = function(_, entry, is_pending)
    selected_popup_partner = {entry=entry, is_pending=is_pending}
end
ui:on_mouse(1, partner_x, partner_y, 0, false)
ui:on_mouse(2, partner_x, partner_y, 0, false)
ui._select_entry = original_select_entry
assert(selected_popup_partner and selected_popup_partner.entry == entries[1]
        and selected_popup_partner.is_pending == false,
    'popup partner actions must delegate the selected Trust to the existing planner')
assert(ui.synergy_popup_trust == 'Valaineral'
        and not ui.synergy_popup_pinned,
    'Add from a transient popup must not silently pin it')
ui.synergy_popup_pinned = true
ui:render(false)
local popup_close
for _, box in ipairs(ui.hitboxes) do
    if box.kind == 'synergy_popup_close' then
        popup_close = box
        break
    end
end
assert(popup_close,
    'a pinned synergy popup must expose a close control')
local popup_close_x = ui.x
    + math.floor((popup_close.x + popup_close.width / 2) * ui.scale + 0.5)
local popup_close_y = ui.y
    + math.floor((popup_close.y + popup_close.height / 2) * ui.scale + 0.5)
ui:on_mouse(1, popup_close_x, popup_close_y, 0, false)
ui:on_mouse(2, popup_close_x, popup_close_y, 0, false)
assert(ui.synergy_popup_trust == nil,
    'the popup close control must dismiss its pinned details')
ui:_toggle_synergy_popup('Valaineral')
ui:on_mouse(1, ui.x + math.floor(300 * ui.scale + 0.5),
    ui.y + math.floor(800 * ui.scale + 0.5), 0, false)
assert(ui.synergy_popup_trust == nil,
    'clicking outside the popup must dismiss it')
ui.synergy_popup_trust = 'Valaineral'
ui.synergy_popup_pinned = true
ui:render(false)
ui:close()
assert(ui.synergy_popup_trust == nil
        and not ui.object_pool.synergy_popup_background[1].visible,
    'closing the main menu must also close and hide the synergy popup')
ui:open()
end)()
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
assert(not initial_text:find('//tsup search', 1, true))
assert(not initial_text:find('EMPTY TRUST SLOT', 1, true))
assert(not initial_text:find('ACTIVE 1', 1, true),
    'active-card badges must not cover the portrait')
assert(initial_text:find('PRESETS', 1, true),
    'the current-party header must expose the preset controls')
assert(ui.object_pool.party_capacity_header[1].value == 'CURRENT PARTY 1/4',
    'the current-party header must expose the resulting Trust capacity')
assert(ui.object_pool.preset_load_button_disabled_rect
        and ui.object_pool.preset_load_button_disabled_rect[1].visible,
    'LOAD must be disabled while the selected preset slot is empty')
assert(ui.object_pool.preset_save_button_enabled_rect
        and ui.object_pool.preset_save_button_enabled_rect[1].visible,
    'SAVE must retain the selected slot after zoning')

local preset_slot_2_x = ui.x + math.floor((748 + 13) * ui.scale + 0.5)
local preset_control_y = ui.y + math.floor((99 + 13) * ui.scale + 0.5)
assert(ui:on_mouse(1, preset_slot_2_x, preset_control_y, 0, false) == true)
assert(ui:on_mouse(2, preset_slot_2_x, preset_control_y, 0, false) == true)
assert(persisted_settings.presets.selected == 2,
    'clicking a preset slot must select it without changing the party')
assert(ui.object_pool.preset_save_button_enabled_rect
        and ui.object_pool.preset_save_button_enabled_rect[1].visible,
    'SAVE must enable after choosing a slot with a confirmed party')
assert(command_options[#command_calls].silent == true,
    'visible preset selection must not duplicate its state in game chat')

local preset_save_x = ui.x + math.floor((946 + 37) * ui.scale + 0.5)
assert(ui:on_mouse(1, preset_save_x, preset_control_y, 0, false) == true)
assert(ui:on_mouse(2, preset_save_x, preset_control_y, 0, false) == true)
assert(#persisted_settings.presets.slots.slot_2 == 1,
    'SAVE must populate the selected slot')
assert(command_options[#command_calls] == false,
    'preset saving must retain its user-facing confirmation')
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
        and command_calls[#command_calls][2] == 'load'
        and command_options[#command_calls].silent == true,
    'LOAD must use the silent validated preset command path')

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

-- Four saved slots require twelve rectangles from the shared occupied palette.
-- Selecting the lone empty slot must not create late backgrounds above slot 5.
persisted_settings.presets.slots.slot_4 = {
    presets.member(909, 'Mihli Aliapoh'),
}
persisted_settings.presets.slots.slot_5 = {
    presets.member(909, 'Mihli Aliapoh'),
}
assert(presets.select(persisted_settings.presets, 3))
ui:render(false)
assert(ui.keyed_pool.preset_occupied_marker['5'].visible,
    'slot 5 saved marker must remain visible after selecting the empty slot')

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
persisted_settings.presets.slots.slot_4 = {}
persisted_settings.presets.slots.slot_5 = {}

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
for _ = 1, 7 do
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
for _, label in ipairs({'ALL', 'TANK', 'MELEE', 'RANGED', 'CASTER', 'HEALER', 'SUPPORT', 'SYNERGY'}) do
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
ui.filter_index = 8
local synergy_roster = ui:_filtered_roster()
assert(#synergy_roster == 2
        and synergy_roster[1].en ~= 'Mihli II'
        and synergy_roster[2].en ~= 'Mihli II',
    'the Synergy filter must include only Trusts with displayable synergy groups')
ui.hover_key = 'synergy_marker:Mihli Aliapoh'
ui:render(false)
assert(ui.keyed_pool.roster_synergy_partner_stars['896'].visible,
    'visible partners should pulse while the Synergy filter is active')
ui.hover_key = nil
ui:render(false)
ui.search = 'Mihli'
synergy_roster = ui:_filtered_roster()
assert(#synergy_roster == 1 and synergy_roster[1].en == 'Mihli Aliapoh',
    'the Synergy filter must combine with roster search')
ui.search = ''
ui.filter_index = 1
ui:render(false)

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
assert(#ui.object_pool.active_gradient_preload == 11,
    'every active-card gradient must be loaded offscreen before a slot changes')
assert(#ui.object_pool.incoming_card_texture_preload == 6,
    'every reusable incoming-card texture must be loaded before first selection')
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
assert(ui.keyed_pool.card_action_button_border['896']
        and ui.keyed_pool.card_action_button_fill['896']
        and ui.keyed_pool.card_action_button_border['896']
            .object.creation_index
            > ui.keyed_pool.active_portrait['896'].object.creation_index
        and ui.keyed_pool.card_action_button_fill['896']
            .object.creation_index
            > ui.keyed_pool.active_portrait['896'].object.creation_index,
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
            and ui.keyed_pool.card_action_button_border[unresolved_key],
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
    assert(not ui.keyed_pool.card_action_button_border['human'],
        'human party members must never receive Trust dismissal controls')
    assert(not ui.keyed_pool.active_action_button_disabled_border.dismiss_all.visible,
        'dismiss all must remain hidden when no Trust card can be dismissed')

    state.party_trusts = saved_party
    state.other_members = saved_other_members
    state.max_trusts = saved_max_trusts
    ui:render(false)
end
assert(not ui.object_pool.pending_card_background,
    'the removed staged-preview panel must not reserve card surfaces')
assert(#ui.object_pool.roster_row_background == 22,
    'all visible roster-row backgrounds must be reserved before scrolling')
assert(#ui.object_pool.roster_row_hover_fill == 22
        and #ui.object_pool.roster_row_hover_rail == 22,
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
    + math.floor((first_row_box.x + 120) * ui.scale + 0.5)
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
for index = 1, 30 do
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
assert(ui.scroll == #entries - 22,
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
assert(command_calls[#command_calls][1] == 'select'
        and command_options[#command_calls].silent == true,
    'adding a visible roster Trust must remain quiet in game chat')
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
assert(not ui.keyed_pool.pending_summon_comet,
    'step 1 must not retain staged-preview comet primitives')
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
    assert(primed_mihli and primed_mihli.visible
        and primed_mihli.frame == ui.frame_id
        and primed_mihli.alpha == 150,
        'a full incoming card must keep its portrait positioned and visible')
assert(ui.keyed_pool.active_card_dismiss_overlay['909']
        and ui.keyed_pool.active_card_dismiss_overlay['909'].visible
        and ui.keyed_pool.active_card_dismiss_overlay['909'].alpha == 0
        and ui.keyed_pool.active_card_replacement_darken['909']
        and ui.keyed_pool.active_card_replacement_darken['909'].alpha == 0,
    'a full incoming portrait must use portrait alpha without darkening the surface')
assert(not ui.keyed_pool.incoming_card_band,
    'the rejected incoming state band must not reserve a runtime primitive')
assert(not ui.keyed_pool.incoming_card_wash,
    'a full incoming card must not use the split overlay surface')
assert(ui.keyed_pool.active_card_name_text['909']
        and ui.keyed_pool.active_card_name_text['909'].visible
        and ui.keyed_pool.active_card_name_text['909'].value == 'Mihli Aliapoh'
        and ui.keyed_pool.active_card_name_text['909'].alpha == 165
        and ui.keyed_pool.active_card_job_text['909'].alpha == 160
        and ui.keyed_pool.active_card_role_text['909'].alpha == 145
        and ui.keyed_pool.active_affiliation_emblem['909'].alpha == 140
        and ui.keyed_pool.incoming_card_state['909:1']
        and ui.keyed_pool.incoming_card_state['909:1'].alpha == 175
        and ui.keyed_pool.incoming_card_state['909:1'].tracking == 3
        and ui.keyed_pool.incoming_card_state['909:1']
            .glyph_advance_scale == 1.45
        and (ui.keyed_pool.incoming_card_state['909:1'].shimmer_mode
            == 'raster'
            or ui.keyed_pool.incoming_card_state['909:1'].shimmer_mode
                == 'whole_label'
            or ui.keyed_pool.incoming_card_state['909:1'].shimmer_mode
                == 'glyph')
        and ui.keyed_pool.incoming_card_state['909:1'].state_center == 914,
    'a full incoming card must keep its normal name and efficient shimmer state')
local staged_shimmer_started = ui.state_label_started['summon:909']
clock_now = clock_now + 2.4
ui:render(false)
assert(ui.state_label_started['summon:909'] == staged_shimmer_started
        and (ui.keyed_pool.incoming_card_state['909:1'].shimmer_mode
            == 'raster'
            or ui.keyed_pool.incoming_card_state['909:1'].shimmer_mode
                == 'whole_label'
            or ui.keyed_pool.incoming_card_state['909:1'].shimmer_mode
                == 'glyph'),
    'a staged state label must retain its whole-label shimmer each cycle')
local full_incoming_state_right =
    ui.keyed_pool.incoming_card_state['909:1'].state_right_edge
assert(ui.keyed_pool.incoming_action_button_border['incoming:909']
        and ui.keyed_pool.incoming_action_button_border['incoming:909'].visible,
    'a full incoming card must use the shared UNDO action treatment')
assert(ui.keyed_pool.active_card_border['909'].alpha == 166,
    'an idle full incoming card must use the restrained variation-06 border')
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
         and ui.keyed_pool.card_action_button_border['896'].visible,
    'staging a dismissal must reuse the identity-keyed action button')
assert(ui.state:snapshot().remaining_slots == 3,
    'a staged dismissal must make one additional replacement slot available')
assert(ui.keyed_pool.incoming_split_gradient['909']
        and ui.keyed_pool.incoming_split_gradient['909'].visible
        and ui.keyed_pool.incoming_split_wash['909']
        and ui.keyed_pool.incoming_split_wash['909'].visible
        and ui.keyed_pool.incoming_split_border['909']
        and ui.keyed_pool.incoming_split_border['909'].visible
        and ui.keyed_pool.incoming_split_state['909:1']
        and ui.keyed_pool.incoming_split_state['909:1'].alpha == 175
        and (not ui.keyed_pool.incoming_split_state['909:1'].shimmer_mode
            or ui.keyed_pool.incoming_split_state['909:1'].shimmer_mode
                == 'raster'
            or ui.keyed_pool.incoming_split_state['909:1'].shimmer_mode
                == 'whole_label'
            or ui.keyed_pool.incoming_split_state['909:1'].shimmer_mode
                == 'glyph'),
    'a paired replacement must use the cropped role surface and large state')
assert(ui.keyed_pool.incoming_split_portrait['909']
        and ui.keyed_pool.incoming_split_portrait['909'].visible
        and ui.keyed_pool.incoming_split_portrait['909'].path
            :find('assets/cards/mihli_aliapoh%.png'),
    'a paired replacement must reuse the full-card portrait framing')
assert(ui.keyed_pool.incoming_split_portrait_darken['909']
        and ui.keyed_pool.incoming_split_portrait_darken['909'].visible
        and ui.keyed_pool.incoming_split_portrait_darken['909'].alpha == 255,
    'a paired replacement portrait must reuse the dismissal darkening treatment')
assert(ui.keyed_pool.incoming_split_action_button_border['incoming:909']
        and ui.keyed_pool.incoming_split_action_button_border['incoming:909'].visible
        and ui.keyed_pool.incoming_split_action_button_border['incoming:909'].x
            == math.floor(724 * ui.scale + 0.5),
    'a paired replacement must widen its incoming side and retain the matching UNDO control')
assert(ui.keyed_pool.incoming_split_gradient['909'].object.creation_index
            < ui.keyed_pool.incoming_split_portrait['909'].object.creation_index
        and ui.keyed_pool.incoming_split_portrait['909'].object.creation_index
            < ui.keyed_pool.incoming_split_portrait_darken['909']
                .object.creation_index
        and ui.keyed_pool.incoming_split_portrait_darken['909']
                .object.creation_index
            < ui.keyed_pool.incoming_split_wash['909'].object.creation_index
        and ui.keyed_pool.incoming_split_wash['909'].object.creation_index
            < ui.keyed_pool.incoming_split_border['909'].object.creation_index
        and ui.keyed_pool.incoming_split_action_button_border['incoming:909']
            .object.creation_index
            > ui.keyed_pool.incoming_split_border['909'].object.creation_index
        and ui.keyed_pool.incoming_split_action_button_fill['incoming:909']
            .object.creation_index
            > ui.keyed_pool.incoming_split_border['909'].object.creation_index,
    'split cards must keep backgrounds below portraits and actions above them')
assert(full_incoming_state_right
        > ui.keyed_pool.incoming_split_state['909:1'].state_right_edge,
    'full SUMMON must use the right-side state region while split SUMMON uses its left half')
assert(not ui.keyed_pool.active_card_name_text['896'].visible
        and not ui.keyed_pool.active_card_job_text['896'].visible
        and not ui.keyed_pool.active_card_role_text['896'].visible,
    'a paired outgoing card must hide metadata that competes with SUMMON')
assert(ui.keyed_pool.outgoing_card_state['896:1']
        and ui.keyed_pool.outgoing_card_state['896:1'].visible
        and ui.keyed_pool.outgoing_card_state['896:1'].alpha == 220
        and ui.keyed_pool.outgoing_card_state['896:1'].base_color.r == 183
        and ui.keyed_pool.outgoing_card_state['896:1'].base_color.g == 192
        and ui.keyed_pool.outgoing_card_state['896:1'].base_color.b == 198
        and ui.keyed_pool.incoming_split_state['909:1'].state_region_x == 542
        and ui.keyed_pool.outgoing_card_state['896:1'].state_region_x
            - ui.keyed_pool.incoming_split_state['909:1'].state_region_x == 306
        and ui.keyed_pool.outgoing_card_state['896:1'].state_right_edge
            == 1006
        and math.abs(ui.keyed_pool.outgoing_card_state['896:1'].state_center
            - 914) < 1,
    'a paired outgoing card must center its large dismissal state before the portrait')
queue_state = {
    active=true,
    phase='dismissing',
    current_id=entries[2].id,
    current_identity_key=entries[2].identity_key,
    current_name=entries[2].en,
}
ui:render(false)
assert(ui.keyed_pool.card_action_button_disabled_border['896']
        and ui.keyed_pool.card_action_button_disabled_border['896'].visible,
    'a card-level UNDO control must use its disabled treatment while the queue runs')
assert(not ui.keyed_pool.card_action_button_border['896'].visible,
    'the actionable UNDO treatment must be hidden while the queue runs')
local active_dismiss_state = ui.keyed_pool.outgoing_card_state['896:1']
assert(ui.state_label_pulse_active
        and (active_dismiss_state.shimmer_mode == 'raster'
            or active_dismiss_state.shimmer_mode == 'whole_label'
            or active_dismiss_state.shimmer_mode == 'glyph'),
    'the active dismissal label must use a restrained brightness pulse')
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
queue_state = {
    active=true,
    phase='summoning',
    current_id=entries[1].id,
    current_identity_key=entries[1].identity_key,
    current_name=entries[1].en,
}
ui:render(false)
local active_summon_state = ui.keyed_pool.incoming_split_state['909:1']
assert(ui.state_label_pulse_active
        and (active_summon_state.shimmer_mode == 'raster'
            or active_summon_state.shimmer_mode == 'whole_label'
            or active_summon_state.shimmer_mode == 'glyph'),
    'the active summoning label must use the same restrained brightness pulse')
queue_state = {active=false, status='idle', position=0, total=0}
ui:render(false)
assert(ui.keyed_pool.active_card_border[tostring(entries[2].id)].alpha == 215,
    'the staged dismissal border must restore its normal brightness after dismissal')

-- A confirmed summon changes party and pending state while the queue remains
-- active. Retained Trusts move ahead of outgoing rows, and a newly exposed
-- full-card gradient must still receive its one-frame texture warmup.
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
local warming_gradient = ui.object_pool.active_card_gradient[1]
local warming_fill = ui.object_pool.active_card_inner_fill[1]
assert(warming_gradient.alpha == 0
        and warming_gradient.target_alpha == 255
        and warming_gradient.texture_ready_frame == ui.frame_id + 1,
    'a confirmed replacement card gradient must warm invisibly for one prerender')
assert(warming_fill.color.r == 14 and warming_fill.color.g == 32
        and warming_fill.color.b == 45,
    'a warming replacement card must keep a neutral slate fallback surface')
assert(ui.deferred_texture_reveal == true,
    'a warming replacement texture must request the immediate follow-up render')
ui.last_refresh = -1
ui:tick()
assert(warming_gradient.alpha == 255
        and warming_gradient.texture_ready_frame == nil,
    'the warmed replacement gradient must reveal on the following render')
assert(ui.deferred_texture_reveal == false,
    'the replacement texture warmup must finish after the reveal pass')
queue_state = {active=false, status='complete', position=2, total=1}

-- With two dismissals staged, confirming the first departure moves the second
-- card upward. Its identity-keyed action button must move with it and remain
-- visible rather than inheriting the departed slot's transparent state.
dismissals.mihliapoh = true
ui:render(false)
local mihli_action = ui.keyed_pool.card_action_button_border['909']
assert(mihli_action and mihli_action.visible,
    'each active Trust must own a visible identity-keyed action button')
assert(mihli_action.object.creation_index
        > ui.keyed_pool.active_portrait['909'].object.creation_index,
    'an action button must be created above its owning portrait')
local full_party = state.party_trusts
state.party_trusts = {full_party[2]}
dismissals.Valaineral = nil
ui:render(false)
assert(ui.keyed_pool.card_action_button_border['909'] == mihli_action
        and mihli_action.visible,
    'the remaining action button must survive another Trust leaving')
assert(mihli_action.y == math.floor((133 + 114 - 29) * ui.scale + 0.5),
    'the remaining action button must move to the first card slot')
state.party_trusts = full_party
dismissals.Valaineral = true
ui:render(false)

pending = {}
dismissals = {}
ui.planning_order = nil
ui:render(false)

-- CLEAR is a permanent, dedicated preset action. It remains available for an
-- occupied slot while SAVE follows the resulting party, including staged
-- additions when the confirmed party is empty.
assert(presets.select(persisted_settings.presets, 2))
local confirmed_party = state.party_trusts
state.party_trusts = {}
pending = {entries[1]}
ui:render(false)
assert(ui.object_pool.preset_clear_button_enabled_rect[1].visible,
    'an occupied selected preset must enable its dedicated CLEAR action')
assert(ui.object_pool.preset_save_button_enabled_rect[1].visible,
    'a staged addition must enable SAVE without a confirmed party')
preset_clear_x = ui.x + math.floor((1028 + 37) * ui.scale + 0.5)
assert(ui:on_mouse(1, preset_clear_x, preset_control_y, 0, false) == true)
assert(ui:on_mouse(2, preset_clear_x, preset_control_y, 0, false) == true)
preset_clear_x = nil
assert(#persisted_settings.presets.slots.slot_2 == 0,
    'CLEAR must empty the selected preset slot')
assert(ui.object_pool.preset_save_button_enabled_rect[1].visible,
    'clearing a preset must not disable SAVE while a staged addition remains')
assert(ui.object_pool.preset_clear_button_disabled_rect[1].visible,
    'an empty selected preset must disable CLEAR')
pending = {}
ui:render(false)
assert(ui.object_pool.preset_save_button_disabled_rect[1].visible,
    'SAVE must disable when the resulting party is empty')
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
assert(ui.object_pool.party_capacity_header[1].color.r == 246
        and ui.object_pool.party_capacity_header[1].color.g == 205,
    'the party-capacity indicator must initially share the warning color')
state.snapshot = normal_snapshot
clock_now = clock_now + 0.25
ui:render(false)
assert(ui.ui_warning ~= nil
        and ui.object_pool.party_capacity_header[1].color.r == 190
        and ui.object_pool.party_capacity_header[1].color.g == 213,
    'the capacity pulse must reach the normal indicator color at its trough')
clock_now = clock_now + 0.25
ui:render(false)
assert(ui.object_pool.party_capacity_header[1].color.r == 246
        and ui.object_pool.party_capacity_header[1].color.g == 205,
    'the capacity pulse must return to full warning yellow at its next peak')
clock_now = clock_now + 1.6
ui:render(false)
assert(ui.ui_warning ~= nil
        and ui.object_pool.party_capacity_header[1].color.r == 190
        and ui.object_pool.party_capacity_header[1].color.g == 213,
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
assert(not mihli_synergy_marker.visible,
    'roster synergy markers must be hidden from the compact preset strip')
assert(not valaineral_card_marker.visible,
    'active-card synergy markers must be hidden from the compact preset strip')
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
queue_state.status = 'next_dismissal_wait'
queue_state.current_name = nil
queue_state.handoff_remaining = 0.75
ui:render(false)
assert(visible_compact_status().value == 'NEXT DISMISSAL - 1s',
    'compact dismissal handoff must show a concise live countdown')
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

-- Compact is a saved-preset shortcut: selection updates the preview, while
-- SUMMON is the only control that turns that choice into queue work.
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

(function()
    local saved_commands = ui.commands
    local saved_queue_state = queue_state
    local saved_party = state.party_trusts
    local saved_slot_2 = persisted_settings.presets.slots.slot_2
    local saved_selection = persisted_settings.presets.selected
    local saved_pending = pending
    local saved_dismissals = dismissals
    local slot_2_x = ui.launcher_x
        + math.floor((64 + 28 + 4 + 14) * ui.scale + 0.5)
    local slot_5_x = ui.launcher_x
        + math.floor((64 + 4 * (28 + 4) + 14) * ui.scale + 0.5)
    local slot_y = ui.launcher_y + math.floor((23 + 14) * ui.scale + 0.5)
    local action_x = ui.launcher_x
        + math.floor((244 + 75) * ui.scale + 0.5)
    local action_y = ui.launcher_y
        + math.floor((9 + 19) * ui.scale + 0.5)

    persisted_settings.presets.slots.slot_2 = {
        presets.member(1009, 'Mihli II'),
    }
    persisted_settings.presets.slots.slot_5 = {}
    assert(presets.select(persisted_settings.presets, 5))
    pending = {}
    dismissals = {}
    queue_state = {active=false, status='idle'}
    ui:render(false)
    assert(ui.object_pool.compact_preset_caption[1].value == 'PRESETS'
            and ui.object_pool.queue_action_button_disabled_rect[1].visible,
        'an empty compact shortcut must have no action and no planning label')

    local before = #command_calls
    assert(ui:on_mouse(1, slot_2_x, slot_y, 0, false))
    assert(ui:on_mouse(2, slot_2_x, slot_y, 0, false))
    assert(#command_calls == before + 1
            and command_calls[#command_calls][2] == 'select'
            and persisted_settings.presets.selected == 2
            and #pending == 0 and next(dismissals) == nil,
        'compact selection must only change the saved choice, not the plan')
    assert(ui.object_pool.queue_action_button_enabled_rect[1].visible
            and visible_text_record('APPLY (-2 / +1)')
            and ui.object_pool.compact_preset_portrait[1].visible,
        'the selected shortcut must preview members and show its direct action')

    before = #command_calls
    assert(ui:on_mouse(1, slot_5_x, slot_y, 0, false))
    assert(ui:on_mouse(2, slot_5_x, slot_y, 0, false))
    assert(#command_calls == before + 1
            and persisted_settings.presets.selected == 5
            and #pending == 0 and next(dismissals) == nil
            and ui.object_pool.queue_action_button_disabled_rect[1].visible,
        'selecting an empty shortcut must not retain the prior action')

    assert(ui:on_mouse(1, slot_2_x, slot_y, 0, false))
    assert(ui:on_mouse(2, slot_2_x, slot_y, 0, false))
    ui:on_zone_change()
    state.party_trusts = {}
    state.source_status.spells = false
    ui:render(false)
    state.source_status.spells = true
    for _ = 1, 4 do ui:render(false) end
    assert(persisted_settings.presets.selected == 2
            and #pending == 0 and next(dismissals) == nil
            and ui.object_pool.compact_preset_caption[1].value == 'PRESETS'
            and ui.object_pool.compact_preset_portrait[1].visible,
        'zoning must retain compact selection and preview without a plan')
    state.party_trusts = saved_party
    ui:render(false)
    assert(ui.object_pool.queue_action_button_enabled_rect[1].visible,
        'the saved shortcut must become actionable again after party refresh')

    pending = {entries[1]}
    dismissals = {}
    assert(ui:restore())
    assert(ui:minimize())
    assert(#pending == 0 and next(dismissals) == nil,
        'minimizing must hide the full-menu draft from compact')
    assert(ui:restore())
    assert(#pending == 1 and pending[1].id == entries[1].id,
        'restoring full menu must recover its separate draft')
    assert(ui:minimize())

    local command_output = {}
    local real_commands = command_module.new(state,
        function(line) command_output[#command_output + 1] = line end,
        queue, {
            presets=persisted_settings.presets,
            save_settings=function() saved = saved + 1 end,
        })
    local started = false
    queue.start = function()
        started = #pending == 1 and pending[1].id == 1009
            and next(dismissals) ~= nil
        if started then
            queue_state = {active=true, phase='dismissing',
                status='awaiting_action', position=1, total=3}
            return true
        end
        return false, 'no_pending'
    end
    ui.commands = {handle=function(_, args, options)
        command_calls[#command_calls + 1] = args
        command_options[#command_calls] = options or false
        real_commands:handle(args, options)
    end}
    assert(ui:on_mouse(1, action_x, action_y, 0, false))
    assert(ui:on_mouse(2, action_x, action_y, 0, false))
    assert(started and queue_state.active
            and command_calls[#command_calls][1] == 'summon'
            and ui.expanded_plan_draft == nil,
        'compact SUMMON alone must validate and start the selected shortcut')
    assert(visible_text_record('CANCEL')
            and not has_hitbox('preset_slot:'),
        'active compact execution must show CANCEL and lock preset selection')

    queue_state = {active=false, status='idle'}
    ui:render(false)
    assert(#pending == 0 and next(dismissals) == nil,
        'compact must clear transient queue work when execution ends')
    local held_draft = {plan={summon={{entry=entries[1]}}, dismiss={}}}
    ui.expanded_plan_draft = held_draft
    queue.start = function() return false, 'busy' end
    assert(ui:on_mouse(1, action_x, action_y, 0, false))
    assert(ui:on_mouse(2, action_x, action_y, 0, false))
    assert(#pending == 0 and next(dismissals) == nil
            and ui.expanded_plan_draft == held_draft,
        'a failed compact SUMMON must leave no plan and keep the full-menu draft')
    ui.expanded_plan_draft = nil
    ui.commands = saved_commands
    queue.start = nil
    persisted_settings.presets.slots.slot_2 = saved_slot_2
    assert(presets.select(persisted_settings.presets, saved_selection))
    pending = saved_pending
    dismissals = saved_dismissals
    state.party_trusts = saved_party
    queue_state = saved_queue_state
    ui:render(false)
end)()
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
        local saved_slot_2 = persisted_settings.presets.slots.slot_2
        local saved_selection = persisted_settings.presets.selected

        target_ui:minimize()
        pending = {}
        dismissals = {}
        queue_state = {active=false, status='idle'}
        persisted_settings.presets.slots.slot_5 = {}
        assert(presets.select(persisted_settings.presets, 5))
        target_ui:render(false)
        assert(target_ui.object_pool.queue_action_button_disabled_rect[1].visible)

        persisted_settings.presets.slots.slot_2 = {
            presets.member(1009, 'Mihli II'),
        }
        assert(presets.select(persisted_settings.presets, 2))
        target_ui:render(false)
        assert(target_ui.object_pool.queue_action_button_enabled_rect[1].visible
                and not target_ui.object_pool
                    .queue_action_button_disabled_rect[1].visible,
            'an actionable compact shortcut must show only the enabled palette')

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

        persisted_settings.presets.slots.slot_2 = saved_slot_2
        assert(presets.select(persisted_settings.presets, saved_selection))
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
require('tests/synergy_popup_layout')(ui, state)
;(function()
    local source = require('resources/trust_synergy')
    local function group(id)
        for _, candidate in ipairs(source.groups) do
            if candidate.id == id then return candidate end
        end
        error('missing synergy group: ' .. id)
    end
    assert(ui:_synergy_group_is_active(group('nashmeira_automata'),
            {Nashmeira=true, Mnejing=true})
        and not ui:_synergy_group_is_active(group('nashmeira_automata'),
            {Mnejing=true, Ovjang=true}),
        'automaton synergy requires Nashmeira plus one companion')
    assert(ui:_synergy_group_is_active(group('rughadjeen_serpent_generals'),
            {Rughadjeen=true, ['Mihli Aliapoh']=true})
        and not ui:_synergy_group_is_active(
            group('rughadjeen_serpent_generals'),
            {['Mihli Aliapoh']=true, Gadalar=true}),
        'Serpent General synergy requires Rughadjeen plus another general')
    assert(ui:_synergy_group_is_active(group('aldo_lion_zeid'),
            {Aldo=true, Lion=true})
        and not ui:_synergy_group_is_active(group('aldo_lion_zeid'),
            {Lion=true, Zeid=true}),
        'Aldo synergy requires Aldo plus Lion or Zeid')
    assert(ui:_synergy_group_is_active(group('chebukki_trio'),
            {['Kukki-Chebukki']=true, ['Makki-Chebukki']=true,
                Cherukiki=true})
        and not ui:_synergy_group_is_active(group('chebukki_trio'),
            {['Kukki-Chebukki']=true, ['Makki-Chebukki']=true}),
        'all-member synergies require the complete group')
    assert(ui:_synergy_missing_requirement(group('noillurie_iroha_ii'),
            {Noillurie=true}) == 'Requires: Iroha II',
        'a missing skillchain partner must be named explicitly')
    assert(ui:_synergy_missing_requirement(group('noillurie_iroha_ii'),
            {}) == 'Requires: Noillurie and Iroha II',
        'the cue must include the viewed Trust when it is not selected')
    assert(ui:_synergy_missing_requirement(group('noillurie_iroha_ii'),
            {Noillurie=true, ['Iroha II']=true}) == nil,
        'completed groups must not show a missing-partner cue')
    assert(ui:_synergy_missing_requirement(group('nashmeira_automata'),
            {Nashmeira=true}) == 'Requires: either Mnejing or Ovjang',
        'either/or groups must not imply both partners are necessary')
    assert(ui:_synergy_missing_requirement(group('nashmeira_automata'),
            {Mnejing=true}) == 'Requires: Nashmeira',
        'present alternatives must leave only the required Trust')
    assert(ui:_synergy_missing_requirement(group('rughadjeen_serpent_generals'),
            {}) == 'Requires: Rughadjeen and one of Mihli Aliapoh, Gadalar, Najelith, or Zazarg',
        'larger either/or groups must remain grammatically clear')
    state:replace_plan({summon={}, dismiss={}})
    ui:open()
    state.party_trusts[2] = {slot=2, id=909, name='Mihli Aliapoh',
        identity_key='mihliapoh', trust=entries[1]}
    entries[1].in_party, entries[1].active_exact = true, true
    ui:render(false)
    ui:render(false) -- finish the first-load star texture warm-up
    local stars = ui.keyed_pool.active_card_synergy_stars
        and ui.keyed_pool.active_card_synergy_stars['896']
    local ring = ui.keyed_pool.active_card_synergy_ring
        and ui.keyed_pool.active_card_synergy_ring['896']
    assert(stars and stars.visible
            and stars.path:find('trust%-synergy%-stars%.png'),
        'an active party pairing must pulse its card stars')
    assert(ring and ring.visible
            and ring.path:find('trust%-synergy%-ring%.png'),
        'an active pairing must have a separate border pulse')
    assert(ui.keyed_pool.active_card_synergy_stars['909'],
        'both partners must receive the card-only star pulse')
    local before_alpha, before_size = stars.image_alpha, stars.image_width
    local seal = ui.keyed_pool.active_card_synergy_marker['896']
    local roster = ui.keyed_pool.roster_synergy_marker['909']
    local seal_alpha, roster_alpha = seal.image_alpha, roster.image_alpha
    ui:_update_synergy_marker_animation(0.525)
    assert(stars.image_alpha ~= before_alpha or stars.image_width ~= before_size,
        'only the inner star layer must animate')
    assert(seal.image_alpha == seal_alpha and roster.image_alpha == roster_alpha,
        'star animation must not alter the seal or roster marker')
    state.source_status.party = false
    ui:render(false)
    assert(not stars.visible,
        'a stale party read must not claim an active synergy')
    state.source_status.party = true
    state.party_trusts[2] = nil
    entries[1].in_party, entries[1].active_exact = false, false
    ui:render(false)
    assert(not stars.visible, 'pulse must stop after the partner leaves')
    state:replace_plan({summon={{entry=entries[1]}}, dismiss={}})
    ui:render(false)
    ui:render(false)
    assert(stars.visible
            and ui.keyed_pool.active_card_synergy_stars['909'].visible,
        'a qualifying staged partner must pulse both party-card star layers')
    local bright_alpha, bright_scale = ui:_synergy_star_frame(0.525)
    local ring_alpha, ring_scale = ui:_synergy_ring_frame(0.525)
    local dim_alpha, dim_scale = ui:_synergy_star_frame(1.575)
    assert(bright_alpha >= 225 and bright_scale >= 1.19
            and dim_alpha == 0 and dim_scale == 1,
        'the inner stars need a clear, enlarged bright phase')
    assert(ring_alpha > 0 and ring_alpha < bright_alpha
            and ring_scale > 1 and ring_scale < bright_scale,
        'the badge border must pulse less than the stars')
    ui:_close_synergy_popup()
    ui:_toggle_synergy_popup('Valaineral')
    assert(not stars.visible and not ring.visible,
        'the open popup must hide both pulse layers on covered cards')
    local chip = ui.keyed_pool.card_synergy_chip_icon
        and ui.keyed_pool.card_synergy_chip_icon.Valaineral
    assert(chip and chip.visible
            and chip.x + chip.image_width < ui:_s(ui.synergy_popup_bounds.x),
        'a card popup must retain a separate badge chip outside its bounds')
    assert(ui.keyed_pool.card_synergy_chip_border.Valaineral.path:find(
            'trust%-synergy%-chip%-circle%-mask%.png'),
        'the floating card badge chip should use a true circular mask')
    local popup_bounds = {x=600, y=88, width=472, height=660}
    assert(not ui:_synergy_card_chip_needed({
            x=540, y=800,
            card_bounds={x=500, y=760, width=500, height=180},
        }, popup_bounds),
        'a fully visible card must keep its original badge without a dark chip')
    assert(ui:_synergy_card_chip_needed({
            x=540, y=350,
            card_bounds={x=500, y=300, width=500, height=180},
        }, popup_bounds),
        'a popup-covered card must retain its badge outside the popup')
    assert(not ui:_synergy_card_chip_needed({
            x=640, y=350,
            card_bounds={x=500, y=300, width=500, height=180},
        }, popup_bounds),
        'the floating chip must not cover popup content')
    local chip_hitbox
    for _, box in ipairs(ui.hitboxes) do
        if box.kind == 'synergy_marker'
                and box.hover_key == 'synergy_marker:Valaineral' then
            chip_hitbox = box
        end
    end
    assert(chip_hitbox, 'the card chip must remain clickable')
    local chip_x = ui.x + ui:_s(chip_hitbox.x + chip_hitbox.width / 2)
    local chip_y = ui.y + ui:_s(chip_hitbox.y + chip_hitbox.height / 2)
    ui:on_mouse(1, chip_x, chip_y, 0, false)
    ui:on_mouse(2, chip_x, chip_y, 0, false)
    assert(ui.synergy_popup_trust == nil,
        'clicking the pinned card chip must close its popup')
    assert(stars.visible and ring.visible,
        'card pulse layers must return when the popup closes')
    state:replace_plan({summon={{entry=entries[1]}},
        dismiss={{active=state.party_trusts[1]}}})
    ui:render(false)
    assert(not stars.visible,
        'staging dismissal of the required partner must stop the pulse')
    assert(ui.keyed_pool.active_card_synergy_marker['909'].visible,
        'a split staged card must retain its static synergy seal')
    state:replace_plan({summon={}, dismiss={}})
    ui:render(false)
end)()
;(function()
    local old_synergy = ui.trust_synergy
    local alternate_group = {
        id='alternate_status_probe',
        members={'Valaineral', 'Mihli II'},
        trigger='When both Trusts are in the party.',
        effects={{trust='Valaineral', text='Support: increases.'}},
    }
    ui.trust_synergy = {by_trust={Valaineral={alternate_group}}}
    local function alternate_status()
        for _, row in ipairs(ui:_synergy_popup_rows('Valaineral')) do
            if row.kind == 'partner' and row.name == 'Mihli II' then
                return row.status, row.action
            end
        end
    end
    state:replace_plan({summon={{entry=entries[1]}}, dismiss={}})
    local staged_status, staged_action = alternate_status()
    assert(staged_status == 'IN USE' and staged_action == nil,
        'a staged alternate identity must read IN USE with Add disabled')
    state:replace_plan({summon={}, dismiss={}})
    entries[3].in_party, entries[3].active_exact = true, false
    local active_status, active_action = alternate_status()
    assert(active_status == 'IN USE' and active_action == nil,
        'an active alternate identity must use the same popup label')
    entries[3].in_party, entries[3].active_exact = false, false
    ui.trust_synergy = old_synergy
end)()
;(function()
    local unlearned = {
        id=1100, icon_id=1100, en='Iroha II',
        identity_key='iroha', learned=false, recast_raw=nil,
        in_party=false, active_exact=false,
        metadata={role='melee', affiliation='other'},
    }
    local old_roster = state.roster
    local old_group = ui.trust_synergy.by_trust['Iroha II']
    local group = {
        id='settings_unlearned_probe',
        members={'Iroha II', 'Mihli Aliapoh'},
        trigger='When both Trusts are in the party.',
        effects={{trust='Iroha II', text='Support: increases.'}},
    }
    state.roster = function(self, filter, include_unlearned)
        local result = {}
        for _, entry in ipairs(old_roster(self, filter)) do
            result[#result + 1] = entry
        end
        if include_unlearned then result[#result + 1] = unlearned end
        return result
    end
    ui.trust_synergy.by_trust['Iroha II'] = {group}
    ui.sort_index = 1
    ui.filter_index = 1
    ui.search = ''
    ui.planning_order = nil
    ui:render(false)
    assert(ui.settings.ui.show_unlearned_trusts == false
            and not ui.keyed_pool.roster_synergy_marker['1100'],
        'unlearned Trusts should be hidden by default')

    queue_state.active = true
    ui:render(false)
    assert(not ui:_toggle_settings_view()
            and not ui.settings_view_open,
        'settings must be unavailable while the queue runs')
    for _, box in ipairs(ui.hitboxes) do
        assert(box.hover_key ~= 'settings_button',
            'the settings button must have no click target while the queue runs')
    end
    queue_state.active = false
    ui:render(false)
    local function click(key)
        local box
        for _, candidate in ipairs(ui.hitboxes) do
            if candidate.hover_key == key then box = candidate end
        end
        assert(box, 'missing settings hitbox: ' .. key)
        local x = ui.x + ui:_s(box.x + box.width / 2)
        local y = ui.y + ui:_s(box.y + box.height / 2)
        assert(ui:on_mouse(1, x, y, 0, false) == true)
        assert(ui:on_mouse(2, x, y, 0, false) == true)
    end

    ui:_toggle_synergy_popup('Mihli Aliapoh')
    ui.filter_dropdown_open = true
    ui:render(false)
    assert(ui.synergy_popup_trust == 'Mihli Aliapoh',
        'settings transition test requires an open synergy popup')
    click('settings_button')
    assert(ui.settings_view_open and ui.synergy_popup_trust == nil,
        'the settings button must replace the menu and close synergy popups')
    assert(not ui.filter_dropdown_open,
        'entering settings must close open dropdowns')
    for _, kind in ipairs({'roster_row_background', 'active_card_border_fill'}) do
        for _, record in ipairs(ui.object_pool[kind] or {}) do
            assert(not record.visible,
                'settings must hide previously rendered ' .. kind)
        end
    end
    for _, box in ipairs(ui.hitboxes) do
        assert(box.kind ~= 'row' and box.kind ~= 'synergy_marker'
                and box.kind ~= 'resize',
            'settings must remove normal-menu click targets')
    end
    local old_save_count = saved
    click('settings_show_unlearned')
    assert(ui.settings.ui.show_unlearned_trusts == true
            and saved == old_save_count + 1
            and ui.settings_view_open,
        'the checkbox must save immediately without leaving settings')
    local check = ui.object_pool.settings_check_mark[1]
    assert(check and check.path:find('settings%-check%.png')
            and check.image_width == ui:_s(20),
        'the checked state must use a full-size check asset')
    clock_now = clock_now + 1
    ui:tick()
    assert(check.visible and check.image_alpha == 255,
        'the checkmark must appear after first-use texture warmup')
    local gear = ui.object_pool.settings_button_glyph[1]
    assert(gear and gear.path:find('settings%-gear%.png')
            and gear.image_color.g > gear.image_color.r
            and ui.object_pool.settings_button_hover[1].image_alpha == 0,
        'selection must color the gear without a persistent backing chip')
    ui.hover_key = 'settings_button'
    ui:render(false)
    assert(ui.object_pool.settings_button_hover[1].image_alpha == 255,
        'the gear must use the header hover surface')
    ui.pressed_key = 'settings_button'
    ui:render(false)
    assert(ui.object_pool.settings_button_pressed[1].image_alpha == 255
            and ui.object_pool.settings_button_hover[1].image_alpha == 0,
        'the gear must use the header pressed surface')
    ui.pressed_key = nil
    ui.hover_key = nil
    ui:render(false)
    click('settings_button')
    local roster = ui:_filtered_roster()
    assert(not ui.settings_view_open and roster[#roster] == unlearned,
        'returning to the menu must show the newly enabled Trust')
    assert(ui:_entry_status(unlearned) == 'NOT LEARNED'
            and ui.keyed_pool.roster_synergy_marker['1100'].visible,
        'an unlearned Trust must show its status and synergy marker')
    for _, box in ipairs(ui.hitboxes) do
        assert(not (box.kind == 'row'
                and box.hover_key == 'roster_row:1100'),
            'an unlearned roster entry must not stage a summon')
    end
    local staged_before = #pending
    click('synergy_marker:Iroha II')
    assert(ui.synergy_popup_trust == 'Iroha II'
            and ui.synergy_popup_pinned
            and #pending == staged_before,
        'an unlearned synergy icon must open its popup without summoning')
    ui:_close_synergy_popup()
    ui:render(false)
    ui.filter_index = 8
    roster = ui:_filtered_roster()
    assert(roster[#roster] == unlearned,
        'the synergy filter must include visible unlearned Trusts')
    ui.filter_index = 1
    ui.search = 'Iroha II'
    roster = ui:_filtered_roster()
    assert(#roster == 1 and roster[1] == unlearned,
        'search must include visible unlearned Trusts')
    ui.search = ''
    ui:_toggle_settings_view()
    ui:minimize()
    assert(not ui.settings_view_open
            and ui.settings.ui.show_unlearned_trusts,
        'minimizing must leave settings without discarding the choice')
    ui:restore()
    state.roster = old_roster
    ui.trust_synergy.by_trust['Iroha II'] = old_group
    ui.settings.ui.show_unlearned_trusts = false
    ui:render(false)
end)()
;(function()
    local color = {r=255, g=255, b=255, a=255}
    ui:_begin_frame()
    ui:_add_centered_text('2', 64, 23, 28, 28, 12, color,
        'Arial', true, 4, 8, 0, -1, 'center_reuse', 'slot')
    local record = ui.keyed_pool.center_reuse.slot
    local centered_x = record.object.last_x
    ui:_add_text('2', 111, 23, 12, color,
        'Arial', true, 0, 'center_reuse', 'slot')
    ui:_add_centered_text('2', 64, 23, 28, 28, 12, color,
        'Arial', true, 4, 8, 0, -1, 'center_reuse', 'slot')
    assert(record.object.last_x == centered_x,
        'a reused preset number must return to its centered position')
    ui:_finish_frame()
end)()
ui:close()
ui:destroy()
assert(destroyed > 20)

io.write(('UI smoke test passed with %d primitives created.\n'):format(created))
