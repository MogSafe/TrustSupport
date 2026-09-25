-- Interactive Windower 4 party-selection panel.
--
-- This first rendering pass intentionally stays on the capabilities already
-- provided by the tested state and party-change queue: dismissals and summons
-- are staged independently, then applied in a safe dismissal-first order.

local trust_ui = {}
local preset_engine = require('core/presets')
local trust_dialogue = require('resources/trust_dialogue')
local affiliation_assets = require('resources/affiliation_assets')

local BASE_WIDTH = 1120
local BASE_HEIGHT = 860
local COMPACT_WIDTH = 720
local COMPACT_HEIGHT = 60
-- Keep the world visible through compact mode without weakening its opaque
-- controls and status text. 210 / 255 is approximately 82% opacity.
local COMPACT_BACKGROUND_ALPHA = 210
local COMPACT_ICON_X = 15
local COMPACT_ICON_Y = 17
local COMPACT_ICON_SIZE = 26
local COMPACT_PRESET_X = 64
local COMPACT_PRESET_Y = 23
local COMPACT_PRESET_SIZE = 28
local COMPACT_PRESET_GAP = 4
local COMPACT_PRESET_WIDTH = 5 * COMPACT_PRESET_SIZE
    + 4 * COMPACT_PRESET_GAP
local COMPACT_PRESET_SEAM_X = COMPACT_PRESET_X + COMPACT_PRESET_WIDTH + 12
local COMPACT_ACTION_X = COMPACT_PRESET_SEAM_X + 12
-- The primary button adds a four-pixel depth layer below its nominal bounds.
-- Nine pixels centers the complete 42-pixel footprint within the 60-pixel bar.
local COMPACT_ACTION_Y = 9
local COMPACT_ACTION_WIDTH = 150
local COMPACT_ACTION_HEIGHT = 38
local COMPACT_STATUS_X = 404
local COMPACT_STATUS_Y = 12
local COMPACT_STATUS_WIDTH = 262
local COMPACT_STATUS_HEIGHT = 40
-- Dedicated square headshots keep faces legible at compact-menu scales. They
-- are authored at 96x96 and drawn at 30x30; the taller card previews remain
-- available to the expanded UI and are not repurposed here.
local COMPACT_PREVIEW_WIDTH = 30
local COMPACT_PREVIEW_HEIGHT = 30
local COMPACT_PREVIEW_GAP = 4
local COMPACT_PREVIEW_MARKER_HEIGHT = 3
local COMPACT_RESTORE_X = 676
local COMPACT_RESTORE_Y = 14
local COMPACT_RESTORE_SIZE = 32
local COMPACT_RESIZE_GRIP_SIZE = 14
local COMPACT_RESIZE_GRIP_X = COMPACT_WIDTH - COMPACT_RESIZE_GRIP_SIZE - 2
local COMPACT_RESIZE_GRIP_Y = COMPACT_HEIGHT - COMPACT_RESIZE_GRIP_SIZE - 2
-- Retain the progress-strip implementation as an alternate treatment while
-- the card-tint treatment is evaluated.
local SHOW_ACTION_STRIPS = false
-- Retain directional fades as another alternate treatment while pulse contrast
-- is evaluated.
local SHOW_ACTION_FADES = false
-- Keep the completed speech-bubble implementation available for a later UI
-- pass, but do not display it in the current in-game build.
local SUMMON_DIALOGUE_ENABLED = false
local LIST_X = 18
local LIST_Y = 112
local LIST_WIDTH = 455
-- The roster now occupies the full content column. Its bottom aligns with the
-- fifth party card after the separate staged-summon preview was removed.
local LIST_HEIGHT = 623
local LIST_ROW_Y = 143
local LIST_ROW_HEIGHT = 26
local LIST_ROWS = 22
local FILTER_BUTTON_X = 18
local FILTER_BUTTON_Y = 70
local FILTER_BUTTON_WIDTH = 174
local FILTER_BUTTON_HEIGHT = 34
local FILTER_CYCLE_WIDTH = 146
local FILTER_SPLIT_GAP = 0
local FILTER_MENU_BUTTON_X = FILTER_BUTTON_X + FILTER_CYCLE_WIDTH
    + FILTER_SPLIT_GAP
local FILTER_MENU_BUTTON_WIDTH = FILTER_BUTTON_WIDTH - FILTER_CYCLE_WIDTH
    - FILTER_SPLIT_GAP
local FILTER_MENU_Y = 108
local FILTER_MENU_WIDTH = LIST_WIDTH
local FILTER_MENU_PADDING = 3
local FILTER_MENU_ROW_HEIGHT = 28
local FILTER_MENU_COLUMNS = 4
local SORT_BUTTON_X = 202
local SORT_BUTTON_Y = 70
local SORT_BUTTON_WIDTH = 134
local SORT_BUTTON_HEIGHT = 34
local SORT_CYCLE_WIDTH = 106
local SORT_SPLIT_GAP = 0
local SORT_MENU_BUTTON_X = SORT_BUTTON_X + SORT_CYCLE_WIDTH + SORT_SPLIT_GAP
local SORT_MENU_BUTTON_WIDTH = SORT_BUTTON_WIDTH - SORT_CYCLE_WIDTH
    - SORT_SPLIT_GAP
local SORT_MENU_Y = FILTER_MENU_Y
local SORT_MENU_WIDTH = LIST_WIDTH
local SORT_MENU_PADDING = FILTER_MENU_PADDING
local SORT_MENU_ROW_HEIGHT = FILTER_MENU_ROW_HEIGHT
local SORT_MENU_COLUMNS = 4
local RIGHT_X = 490
local RIGHT_WIDTH = 612
local INCOMING_SPLIT_WIDTH = math.floor(RIGHT_WIDTH * 0.53)
local ACTIVE_CARD_Y = 133
local ACTIVE_CARD_HEIGHT = 114
local ACTIVE_CARD_STEP = 122
local CONTENT_BOTTOM_Y = ACTIVE_CARD_Y + ACTIVE_CARD_STEP * 4
    + ACTIVE_CARD_HEIGHT
local MAX_PARTY_ACTION_Y = CONTENT_BOTTOM_Y + 17
local CARD_ACTION_WIDTH = 76
local CARD_ACTION_HEIGHT = 22
local CARD_STATE_LABEL_SIZE = 20
local CARD_STATE_LABEL_TRACKING = 3
-- Revert to the text-per-glyph implementation by setting this false.
local USE_PRE_RENDERED_STATE_LABEL_SWEEP = false
local STATE_LABEL_SWEEP_FRAME_COUNT = 8
local STATE_LABEL_SWEEP_WIDTH = 256
local STATE_LABEL_SWEEP_HEIGHT = 32
local FULL_CARD_STATE_OFFSET_X = 22
-- Michroma's display capitals are materially wider than the conservative
-- estimator used for general UI fitting. State labels render per glyph for
-- tracking, so compensate locally instead of disturbing every other label.
local CARD_STATE_GLYPH_ADVANCE_SCALE = 1.45
local CARD_STATE_PULSE_DURATION = 0.9
local CARD_STATE_IDLE_SWEEP_CYCLE = 2.4
local CARD_STATE_ACTIVE_SWEEP_DURATION = 1.4
local CARD_STATE_SWEEP_WIDTH = 0.32
local CARD_STATE_REFRESH_INTERVAL = 1 / 15
local PRESET_WARNING_HOLD = 2.5
local PRESET_WARNING_FADE = 1.5
local DIALOGUE_FONT = 'Lucida Console'
local DIALOGUE_FONT_SIZE = 12
local DIALOGUE_LINE_HEIGHT = 20
local DIALOGUE_MIN_WIDTH = 190
local DIALOGUE_MAX_WIDTH = 370
local DIALOGUE_MAX_LINES = 3
local DIALOGUE_PADDING_X = 16
local DIALOGUE_PADDING_Y = 12
local DIALOGUE_ASSET = 'assets/ui/speech-bubble-reference.png'
local DIALOGUE_ASSET_WIDTH = 988
local DIALOGUE_ASSET_HEIGHT = 413
local DIALOGUE_WINDOW_OVERLAP = 24
local ANIMATION_REFRESH_INTERVAL = 1 / 30
local DRAG_ANIMATION_REFRESH_INTERVAL = 1 / 15
local DRAG_PREVIEW_ALPHA = 160
local SUMMON_COMET_SEGMENTS = 7
local SUMMON_COMET_SEGMENT_LENGTH = 8
local SUMMON_COMET_SPEED = 92
local PRIMARY_ACTION_MASK = 'assets/ui/primary-action-capsule-mask.png'
local COMPACT_SHELL_MASK = 'assets/ui/compact-shell-border-mask.png'
local COMPACT_SHELL_INNER_MASK = 'assets/ui/compact-shell-inner-rounded-mask.png'
local PRIMARY_ACTION_LEFT_MASK = 'assets/ui/primary-action-left-half-mask.png'
local PRIMARY_ACTION_RIGHT_MASK = 'assets/ui/primary-action-right-half-mask.png'
local SPLIT_RIGHT_MASK = 'assets/ui/split-control-right-cap-mask.png'
local RESIZE_GRIP_ASSET = 'assets/ui/resize-grip-dots.png'
local FILTER_SPLIT_MASK = 'assets/ui/filter-split-capsule-mask.png'
local SORT_SPLIT_MASK = 'assets/ui/sort-split-capsule-mask.png'
local FOOTER_SURFACE_MASK = 'assets/ui/footer-surface-mask.png'
local HEADER_SURFACE_MASK = 'assets/ui/header-surface-mask.png'
local ACTIVE_ACTION_MASK = 'assets/ui/active-action-capsule-mask.png'
local ACTIVE_ACTION_BORDER_MASK = 'assets/ui/active-action-capsule-border-mask.png'
local ACTIVE_CARD_PORTRAIT_FADE_MASK = 'assets/ui/active-card-portrait-fade-mask.png'
local ACTIVE_CARD_PORTRAIT_DARKEN_MASK = 'assets/ui/active-card-portrait-darken-mask.png'
local INCOMING_REPLACEMENT_OVERLAY =
    'assets/ui/incoming-left-replacement-overlay.png'
local INCOMING_SPLIT_BORDER_MASK =
    'assets/ui/incoming-split-left-border-mask.png'
local ACTIVE_CARD_GRADIENTS = {
    tank = {'assets/ui/active-card-gradient-blue.png',
        'assets/ui/active-card-gradient-blue-b.png',
        'assets/ui/active-card-gradient-blue-c.png'},
    damage = {'assets/ui/active-card-gradient-red.png',
        'assets/ui/active-card-gradient-red-b.png',
        'assets/ui/active-card-gradient-red-c.png'},
    healer = {'assets/ui/active-card-gradient-green.png',
        'assets/ui/active-card-gradient-green-b.png',
        'assets/ui/active-card-gradient-green-c.png'},
    support = {'assets/ui/active-card-gradient-green.png',
        'assets/ui/active-card-gradient-green-b.png',
        'assets/ui/active-card-gradient-green-c.png'},
}
local INCOMING_SPLIT_GRADIENTS = {
    tank = {'assets/ui/incoming-split-gradient-blue.png'},
    damage = {'assets/ui/incoming-split-gradient-red.png'},
    healer = {'assets/ui/incoming-split-gradient-green.png'},
    support = {'assets/ui/incoming-split-gradient-green.png'},
}
local PRIMARY_ACTION_X = 918
local PRIMARY_ACTION_WIDTH = 184
local PRIMARY_ACTION_DEBUG_MAGENTA = false
local PRIMARY_READY_PULSE_DURATION = 2.4
local FOOTER_SURFACE_Y = 788
local FOOTER_CONTROL_Y = 801
local FOOTER_DIVIDER_X = PRIMARY_ACTION_X - 12
local CLEAR_CHANGES_WIDTH = 210
local CLEAR_CHANGES_X = FOOTER_DIVIDER_X - CLEAR_CHANGES_WIDTH - 12
local DEFERRED_TEXTURE_SWAP_KINDS = {
    active_card_gradient = true,
    active_portrait = true,
    compact_preset_portrait = true,
}
local FOOTER_NOTICE_X = 18
local FOOTER_NOTICE_Y = FOOTER_CONTROL_Y
local FOOTER_NOTICE_WIDTH = CLEAR_CHANGES_X - FOOTER_NOTICE_X - 12
local FOOTER_NOTICE_HEIGHT = 40

-- Windower text sizes are point-like while image positions use screen pixels.
-- Estimate widths deterministically: get_extents() can briefly describe the
-- previous pooled label after its text changes, which makes controls resize or
-- jump for one frame during party planning.
local TEXT_EXTENT_SCALE = 4 / 3

local NARROW_GLYPHS = {[' ']=0.34, ['I']=0.30, ['J']=0.43, ['L']=0.53,
    ['i']=0.25, ['l']=0.25, ['t']=0.36, ['f']=0.38, ['r']=0.38,
    ['1']=0.48, ['.']=0.28, [':']=0.28, ['/']=0.42, ['-']=0.40,
    ['(']=0.34, [')']=0.34, ['+']=0.58}
local WIDE_GLYPHS = {['M']=0.88, ['W']=0.96, ['m']=0.84, ['w']=0.82,
    ['O']=0.76, ['Q']=0.76, ['G']=0.74, ['@']=0.96}

local function estimated_text_width(value, pixel_size, font, bold)
    local michroma = tostring(font or ''):lower() == 'michroma'
    local width = 0
    for glyph in tostring(value or ''):gmatch('.') do
        width = width + (NARROW_GLYPHS[glyph]
            or WIDE_GLYPHS[glyph]
            or (michroma and 0.72 or 0.64))
    end
    return width * pixel_size * TEXT_EXTENT_SCALE * (bold and 1.04 or 1)
end

local function utf8_characters(value)
    value = tostring(value or '')
    local result = {}
    local index = 1
    while index <= #value do
        local byte = value:byte(index)
        local width = 1
        if byte and byte >= 240 then
            width = 4
        elseif byte and byte >= 224 then
            width = 3
        elseif byte and byte >= 192 then
            width = 2
        end
        result[#result + 1] = value:sub(index, math.min(#value, index + width - 1))
        index = index + width
    end
    return result
end

local function utf8_prefix(value, count)
    local characters = utf8_characters(value)
    local limit = math.max(0, math.min(#characters,
        math.floor(tonumber(count) or 0)))
    local result = {}
    for index = 1, limit do
        result[index] = characters[index]
    end
    return table.concat(result)
end

local function fit_dialogue_line(value, max_width)
    local characters = utf8_characters(value)
    local result = tostring(value or '')
    while #characters > 1
        and estimated_text_width(result .. '...', DIALOGUE_FONT_SIZE,
            DIALOGUE_FONT, false)
            > max_width do
        characters[#characters] = nil
        result = table.concat(characters)
    end
    return result .. '...'
end

local function wrap_dialogue(value)
    local max_text_width = DIALOGUE_MAX_WIDTH - DIALOGUE_PADDING_X * 2
    local lines = {}
    local current = ''
    for word in tostring(value or ''):gmatch('%S+') do
        local candidate = current == '' and word or (current .. ' ' .. word)
        if current == '' or estimated_text_width(candidate, DIALOGUE_FONT_SIZE,
                DIALOGUE_FONT, false) <= max_text_width then
            current = candidate
        else
            lines[#lines + 1] = current
            current = word
        end
    end
    if current ~= '' then
        lines[#lines + 1] = current
    end
    if #lines == 0 then
        lines[1] = ''
    end
    if #lines > DIALOGUE_MAX_LINES then
        lines[DIALOGUE_MAX_LINES] = fit_dialogue_line(
            lines[DIALOGUE_MAX_LINES], max_text_width)
        for index = #lines, DIALOGUE_MAX_LINES + 1, -1 do
            lines[index] = nil
        end
    elseif estimated_text_width(lines[#lines], DIALOGUE_FONT_SIZE,
            DIALOGUE_FONT, false) > max_text_width then
        lines[#lines] = fit_dialogue_line(lines[#lines], max_text_width)
    end
    return lines
end

local FILTERS = {
    {key='all', label='ALL'},
    {key='tank', label='TANK'},
    {key='melee', label='MELEE'},
    {key='ranged', label='RANGED'},
    {key='offensive_caster', label='CASTER'},
    {key='healer', label='HEALER'},
    {key='support', label='SUPPORT'},
}
local FILTER_MENU_ROWS = math.ceil(#FILTERS / FILTER_MENU_COLUMNS)
local FILTER_MENU_HEIGHT = FILTER_MENU_PADDING * 2
    + FILTER_MENU_ROWS * FILTER_MENU_ROW_HEIGHT

local SORTS = {
    {key='status', label='STATUS'},
    {key='name', label='NAME'},
    {key='role', label='ROLE'},
    {key='affiliation', label='AFFILIATION', compact='AFFIL.'},
}
local SORT_MENU_ROWS = math.ceil(#SORTS / SORT_MENU_COLUMNS)
local SORT_MENU_HEIGHT = SORT_MENU_PADDING * 2
    + SORT_MENU_ROWS * SORT_MENU_ROW_HEIGHT

local COLORS = {
    shell = {r=8, g=16, b=25, a=244},
    shell_border = {r=77, g=122, b=143, a=255},
    panel = {r=14, g=32, b=45, a=238},
    panel_alt = {r=20, g=44, b=56, a=235},
    dropdown_surface = {r=25, g=36, b=47, a=255},
    dropdown_item = {r=38, g=53, b=66, a=255},
    dropdown_selected = {r=35, g=70, b=83, a=255},
    title = {r=24, g=48, b=65, a=250},
    footer = {r=34, g=45, b=56, a=250},
    cyan = {r=112, g=224, b=245, a=255},
    gold = {r=190, g=213, b=220, a=255},
    gold_bright = {r=232, g=248, b=250, a=255},
    gold_dim = {r=91, g=119, b=132, a=255},
    white = {r=239, g=244, b=246, a=255},
    muted = {r=142, g=161, b=174, a=255},
    -- Small role labels need normal-text contrast against every base card
    -- surface. Size and weight preserve hierarchy; reduced opacity did not.
    card_subtext = {r=220, g=230, b=234, a=255},
    dim = {r=72, g=91, b=106, a=255},
    dismissed_card = {r=50, g=53, b=55, a=255},
    red = {r=231, g=103, b=103, a=255},
    red_bright = {r=255, g=151, b=145, a=255},
    red_dim = {r=132, g=47, b=51, a=255},
    green = {r=112, g=216, b=170, a=255},
    ready_hint = {r=139, g=195, b=171, a=255},
    dismiss_hint = {r=205, g=145, b=148, a=255},
    blue = {r=113, g=160, b=235, a=255},
    preset_saved = {r=217, g=169, b=78, a=255},
    preset_matched = {r=99, g=217, b=149, a=255},
    preset_partial = {r=242, g=167, b=198, a=255},
    preset_blocked = {r=197, g=206, b=211, a=255},
    retry = {r=246, g=205, b=86, a=255},
    -- Queue/status text is rendered over both the opaque footer and the
    -- translucent compact shell. These colors retain WCAG AA text contrast
    -- even when the compact shell is composited over a bright scene.
    status_neutral = {r=190, g=208, b=216, a=255},
    status_name = {r=158, g=210, b=230, a=255},
    status_error = {r=255, g=184, b=180, a=255},
    launcher_hover = {r=190, g=238, b=246, a=255},
    launcher_pressed = {r=205, g=224, b=231, a=255},
    dialogue_text = {r=8, g=10, b=11, a=255},
    button = {r=38, g=62, b=76, a=255},
    button_hot = {r=50, g=91, b=103, a=255},
    button_disabled = {r=31, g=40, b=49, a=255},
    button_glass_border = {r=143, g=183, b=197, a=255},
    button_capsule_fill = {r=91, g=132, b=151, a=255},
    button_capsule_pressed = {r=42, g=74, b=89, a=255},
    button_capsule_bottom = {r=75, g=112, b=127, a=255},
    button_capsule_hover_bottom = {r=68, g=112, b=125, a=255},
    button_capsule_text = {r=15, g=38, b=50, a=255},
    footer_button_border = {r=93, g=127, b=140, a=255},
    footer_button_fill = {r=48, g=75, b=88, a=255},
    footer_button_pressed = {r=30, g=52, b=64, a=255},
    footer_button_bottom = {r=31, g=62, b=76, a=255},
    footer_button_text = {r=210, g=229, b=235, a=255},
    footer_dismiss_border = {r=151, g=91, b=96, a=255},
    footer_dismiss_fill = {r=55, g=46, b=52, a=255},
    footer_dismiss_pressed = {r=42, g=32, b=37, a=255},
    footer_dismiss_bottom = {r=82, g=53, b=59, a=255},
    footer_dismiss_hover = {r=190, g=112, b=117, a=255},
    footer_dismiss_text = {r=210, g=165, b=168, a=255},
    button_debug_border = {r=255, g=0, b=255, a=255},
    button_debug_fill = {r=190, g=0, b=190, a=255},
    button_debug_bottom = {r=96, g=0, b=96, a=255},
    tank = {r=37, g=65, b=103, a=246},
    tank_dark = {r=22, g=41, b=72, a=246},
    damage = {r=118, g=51, b=57, a=246},
    damage_dark = {r=70, g=28, b=34, a=246},
    support = {r=40, g=108, b=70, a=246},
    support_dark = {r=22, g=64, b=39, a=246},
}

local REPLACEMENT_AMBER = {
    summon_gradient = 'assets/ui/incoming-split-gradient-amber.png',
    dismiss_gradient = 'assets/ui/active-card-gradient-amber-dismiss.png',
    split_gradient = 'assets/ui/incoming-split-gradient-amber.png',
    summon_surface = {r=203, g=148, b=62, a=246},
    dismiss_surface = {r=140, g=90, b=35, a=246},
    border = {r=245, g=190, b=91, a=255},
    border_dim = {r=165, g=108, b=40, a=255},
    glow = {r=255, g=230, b=168, a=255},
    wash = {r=145, g=91, b=28, a=105},
}

local AFFILIATIONS = {}
local AFFILIATION_EMBLEMS = {}
local AFFILIATION_FLAGS = {}
for key, assets in pairs(affiliation_assets) do
    AFFILIATIONS[key] = assets.card_label
    AFFILIATION_EMBLEMS[key] = assets.emblem
    AFFILIATION_FLAGS[key] = assets.flag
end

local ROLE_SHORT = {
    tank = 'TANK',
    melee = 'MELEE FIGHTER',
    ranged = 'RANGED FIGHTER',
    offensive_caster = 'OFFENSIVE CASTER',
    healer = 'HEALER',
    support = 'SUPPORT',
}

local ROLE_LIST = {
    tank = 'TANK',
    melee = 'MELEE',
    ranged = 'RANGED',
    offensive_caster = 'CASTER',
    healer = 'HEALER',
    support = 'SUPPORT',
}

-- The textures are pre-cropped to the card bounds. This is necessary because
-- Windower image primitives do not provide CSS-style overflow clipping.
local ACTIVE_CARD_FLAG_WIDTH = 612
local ACTIVE_CARD_FLAG_HEIGHT = 114
local ACTIVE_CARD_FLAG_ALPHA = 36
local ACTIVE_CARD_INCOMING_FLAG_TINT_ALPHA = 32
local ACTIVE_CARD_INCOMING_PORTRAIT_ALPHA = 150

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function lower(value)
    return tostring(value or ''):lower()
end

local function shorten(value, maximum)
    value = tostring(value or '')
    if #value <= maximum then
        return value
    end
    return value:sub(1, math.max(1, maximum - 3)) .. '...'
end

local function normalize_path(path)
    return tostring(path or ''):gsub('\\', '/')
end

local function copy_color(color, alpha)
    return {
        red = color.r,
        green = color.g,
        blue = color.b,
        alpha = alpha or color.a or 255,
    }
end

local function role_key(entry)
    return entry and entry.metadata and entry.metadata.role or nil
end

local function role_label(entry)
    return ROLE_SHORT[role_key(entry)] or 'UNCLASSIFIED'
end

local function job_label(entry)
    return entry and entry.metadata and entry.metadata.job_label
        or 'TRUST'
end

local function job_label_parts(entry)
    local label = job_label(entry)
    local main_job, subjobs = label:match('^([^/]+)(/.*)$')
    return main_job or label, subjobs
end

local function affiliation_label(entry)
    local affiliation = entry and entry.metadata and entry.metadata.affiliation or nil
    return AFFILIATIONS[affiliation]
end

local function role_colors(entry)
    local role = role_key(entry)
    if role == 'tank' then
        return COLORS.tank, COLORS.tank_dark
    elseif role == 'healer' or role == 'support' then
        return COLORS.support, COLORS.support_dark
    elseif role == 'melee' or role == 'ranged' or role == 'offensive_caster' then
        return COLORS.damage, COLORS.damage_dark
    end
    return COLORS.panel_alt, COLORS.panel
end

local function gradient_group(entry)
    local role = role_key(entry)
    if role == 'tank' then
        return 'tank'
    elseif role == 'healer' or role == 'support' then
        return 'support'
    elseif role == 'melee' or role == 'ranged' or role == 'offensive_caster' then
        return 'damage'
    end
    return nil
end

local function card_gradient_path(gradients, entry, index, entries)
    local variants = gradients[gradient_group(entry)]
    if not variants then
        return nil
    end
    local occurrence = 0
    local target_group = gradient_group(entry)
    for position = 1, index do
        local item = entries[position]
        local item_entry = item and item.trust or item
        if gradient_group(item_entry) == target_group then
            occurrence = occurrence + 1
        end
    end
    return variants[((occurrence - 1) % #variants) + 1]
end

local UI = {}
UI.__index = UI

function trust_ui.new(options)
    assert(type(options) == 'table', 'trust_ui.new requires options')
    assert(options.state, 'trust_ui.new requires state')
    assert(options.commands, 'trust_ui.new requires commands')

    local images = options.images or require('images')
    local texts = options.texts or require('texts')
    local settings = options.settings or {}
    settings.ui = settings.ui or {}
    settings.presets = settings.presets or preset_engine.new_settings()
    settings.dialogue = settings.dialogue or {}

    local self = setmetatable({
        state = options.state,
        commands = options.commands,
        queue = options.queue,
        metadata = options.metadata or {},
        settings = settings,
        images = images,
        texts = texts,
        emit = options.emit or function() end,
        clock = options.clock or os.clock,
        random = options.random or math.random,
        save_settings = options.save_settings or function() end,
        file_exists = options.file_exists or function() return true end,
        addon_path = normalize_path(options.addon_path or ''),
        windower_path = normalize_path(options.windower_path or ''),
        objects = {},
        object_pool = {rect={}, image={}, text={}},
        keyed_pool = {},
        pool_cursor = {rect=0, image=0, text=0},
        frame_id = 0,
        hitboxes = {},
        visible = false,
        launcher = nil,
        launcher_pressed_icon = nil,
        launcher_pending_frames = 0,
        launcher_drag = nil,
        launcher_pressed = false,
        launcher_hovered = false,
        scrollbar_drag = nil,
        drag = nil,
        drag_preview = false,
        resize = nil,
        mouse_capture = nil,
        hover_key = nil,
        pressed_key = nil,
        scroll = 0,
        filter_index = 1,
        filter_dropdown_open = false,
        sort_index = 1,
        sort_dropdown_open = false,
        search = '',
        planning_order = nil,
        last_refresh = 0,
        signature = nil,
        action_progress_key = nil,
        action_progress_started = 0,
        state_label_started = {},
        state_label_active_started = {},
        state_label_last_frame = {},
        state_label_pulse_active = false,
        primary_action_enabled = false,
        primary_action_kind = nil,
        primary_ready_pulse_started = nil,
        primary_surface_kind = nil,
        ui_warning = nil,
        preset_warning = nil,
        selected_preset_summary = nil,
        compact_preset_selection_pending = false,
        party_zone_transition = nil,
        expanded_plan_draft = nil,
        execution_party_rows = nil,
        summon_dialogue = nil,
        dialogue_event_key = nil,
        deferred_texture_reveal = false,
        active_card_surface_warmup = {},
        active_split_signature = nil,
        filter_dropdown_primed = false,
        sort_dropdown_primed = false,
    }, UI)

    local ui_settings = settings.ui
    local dialogue_mode = tostring(settings.dialogue.mode or 'always'):lower()
    if dialogue_mode ~= 'off' and dialogue_mode ~= 'occasional'
        and dialogue_mode ~= 'always' then
        dialogue_mode = 'always'
    end
    settings.dialogue.mode = dialogue_mode
    self.x = tonumber(ui_settings.x) or 220
    self.y = tonumber(ui_settings.y) or 95
    -- Preserve the legacy shared scale as the migration source for both modes.
    -- Once either mode is resized, each presentation keeps its own value.
    local legacy_scale = clamp(tonumber(ui_settings.scale) or 0.78, 0.55, 1.25)
    self.expanded_scale = clamp(
        tonumber(ui_settings.expanded_scale) or legacy_scale, 0.55, 1.25)
    self.compact_scale = clamp(
        tonumber(ui_settings.compact_scale) or legacy_scale, 0.55, 1.25)
    self.launcher_x = tonumber(ui_settings.launcher_x) or 32
    self.launcher_y = tonumber(ui_settings.launcher_y) or 280
    self.mode = tostring(ui_settings.mode or 'expanded'):lower()
    if self.mode ~= 'compact' and self.mode ~= 'expanded' then
        self.mode = 'expanded'
    end
    -- Compact mode has no separate Load control. Restore the persisted
    -- selection once startup state becomes authoritative so its action button
    -- behaves exactly as if the user had selected that preset in this session.
    -- This is deliberately one-shot: subsequent party changes must not cause
    -- an old preset to be silently staged again.
    self.compact_preset_restore_pending = self.mode == 'compact'
    ui_settings.mode = self.mode
    self.scale = self.mode == 'compact'
        and self.compact_scale or self.expanded_scale
    ui_settings.expanded_scale = self.expanded_scale
    ui_settings.compact_scale = self.compact_scale
    self.icon_enabled = settings.icon ~= false
    local saved_sort = lower(ui_settings.sort)
    for index, option in ipairs(SORTS) do
        if option.key == saved_sort then
            self.sort_index = index
            break
        end
    end

    if self.windower_path == '' then
        self.windower_path = self.addon_path:match('^(.-)/addons/[^/]+/?$') or ''
    end
    self.spell_icon_path = self.windower_path ~= ''
        and (self.windower_path .. '/plugins/icons/spells/') or ''

    self:_build_icon_representatives()
    self:_render_launcher()
    -- Both presentation shells must exist before any shared preset controls.
    -- If the addon starts compact and the expanded frame is created only on
    -- restore, Windower places that new frame above the already-created preset
    -- backgrounds and hides every slot/button surface while leaving its later
    -- text visible.
    self:_prime_image(self:_asset('assets/ui/window-frame.png'),
        BASE_WIDTH, BASE_HEIGHT, 'window_frame', 'main')
    -- The title and footer are separate overlays on the frame texture. They
    -- must be reserved here as part of the shell as well: if compact mode
    -- creates a shared primary-action palette first, lazily creating the
    -- expanded footer on restore gives that footer a newer Windower depth and
    -- makes an enabled CANCEL button look disabled beneath it.
    self:_prime_image(self:_asset(HEADER_SURFACE_MASK),
        BASE_WIDTH - 6, 57, 'title_surface', 'main')
    self:_prime_image(self:_asset(FOOTER_SURFACE_MASK),
        BASE_WIDTH - 6, 69, 'footer_background', 'main')
    -- Reserve the compact shell before any preset foreground can be created.
    -- Windower's primitive depth follows creation order, so lazily creating
    -- this shell after the expanded preset controls would cover saved markers
    -- until a new marker state happened to allocate a later primitive.
    self:_prime_image(self:_asset(COMPACT_SHELL_MASK),
        COMPACT_WIDTH, COMPACT_HEIGHT, 'compact_shell', 'outer')
    self:_prime_image(self:_asset(COMPACT_SHELL_INNER_MASK),
        COMPACT_WIDTH - 4, COMPACT_HEIGHT - 4,
        'compact_shell_fill', 'inner')
    self:_prime_image(self:_asset('assets/ui/trust-hat.png'),
        COMPACT_ICON_SIZE, COMPACT_ICON_SIZE,
        'compact_launcher_icon', 'launcher')
    self:_prime_image(self:_asset('assets/ui/trust-hat-pressed.png'),
        COMPACT_ICON_SIZE, COMPACT_ICON_SIZE,
        'compact_launcher_icon_pressed', 'launcher')
    return self
end

function UI:_s(value)
    return math.floor(value * self.scale + 0.5)
end

function UI:_origin_x()
    return self.mode == 'compact' and self.launcher_x or self.x
end

function UI:_origin_y()
    return self.mode == 'compact' and self.launcher_y or self.y
end

function UI:_exists(path)
    if path == '' then
        return false
    end
    local ok, exists = pcall(self.file_exists, path)
    return ok and exists == true
end

function UI:_asset(relative_path)
    return self.addon_path .. normalize_path(relative_path)
end

function UI:_record(record, relative_x, relative_y)
    record.x = self:_s(relative_x)
    record.y = self:_s(relative_y)
    record.frame = self.frame_id
    self.objects[#self.objects + 1] = record
    return record.object
end

function UI:_acquire(kind, create)
    local index = (self.pool_cursor[kind] or 0) + 1
    self.pool_cursor[kind] = index
    local records = self.object_pool[kind]
    if not records then
        records = {}
        self.object_pool[kind] = records
    end
    local record = records[index]
    if record then
        return record, false
    end

    record = {kind=kind, object=create(), visible=false}
    -- A newly allocated primitive may use a library whose default is visible.
    -- Hide only this new object until the current frame has initialized it.
    pcall(function() record.object:hide() end)
    records[index] = record
    return record, true
end

function UI:_acquire_keyed(kind, key, create)
    key = tostring(key)
    local lookup = self.keyed_pool[kind]
    if not lookup then
        lookup = {}
        self.keyed_pool[kind] = lookup
    end
    local record = lookup[key]
    if record then
        return record, false
    end

    local records = self.object_pool[kind]
    if not records then
        records = {}
        self.object_pool[kind] = records
    end
    record = {kind=kind, key=key, object=create(), visible=false}
    pcall(function() record.object:hide() end)
    records[#records + 1] = record
    lookup[key] = record
    return record, true
end

function UI:_prime_rect_pool(kind, count)
    local previous_cursor = self.pool_cursor[kind] or 0
    for _ = 1, count do
        self:_acquire(kind, function()
            return self.images.new('', {
                pos = {x=self:_origin_x() - 200, y=self:_origin_y() - 200},
                size = {width=1, height=1},
                color = copy_color(COLORS.white, 0),
                texture = {path='', fit=false},
                draggable = false,
                visible = false,
            })
        end)
    end
    -- Priming allocates records but must not consume this frame's draw cursor;
    -- the visible controls below reuse records 1..count immediately.
    self.pool_cursor[kind] = previous_cursor
end

function UI:_prime_preset_controls()
    -- Every slot-background palette must exist before any slot number or saved
    -- marker. Otherwise the first later appearance of a palette creates it at
    -- a higher depth and can cover the foreground for that slot.
    for _, state_key in ipairs({
        'selected', 'occupied', 'empty',
        'selected_locked', 'occupied_locked', 'empty_locked',
    }) do
        -- Each slot background uses three rectangles. Reserve the true
        -- five-slot worst case so late backgrounds cannot cover saved markers.
        self:_prime_rect_pool('preset_slot_' .. state_key,
            preset_engine.SLOT_COUNT * 3)
    end
    self:_prime_rect_pool('preset_load_button_enabled_rect', 3)
    self:_prime_rect_pool('preset_load_button_disabled_rect', 3)
    self:_prime_rect_pool('preset_save_button_enabled_rect', 3)
    self:_prime_rect_pool('preset_save_button_disabled_rect', 3)
    self:_prime_rect_pool('preset_clear_button_enabled_rect', 3)
    self:_prime_rect_pool('preset_clear_button_disabled_rect', 3)
end

function UI:_prime_active_card_gradients()
    local seen = {}
    for _, variants in pairs(ACTIVE_CARD_GRADIENTS) do
        for _, relative_path in ipairs(variants) do
            if not seen[relative_path] then
                seen[relative_path] = true
                local path = self:_asset(relative_path)
                if self:_exists(path) then
                    self:_prime_image(path, RIGHT_WIDTH - 2,
                        ACTIVE_CARD_HEIGHT - 2, 'active_gradient_preload',
                        relative_path)
                end
            end
        end
    end
end

local function incoming_state_color(entry)
    local role = role_key(entry)
    if role == 'tank' then
        return {r=145, g=181, b=221, a=220}
    elseif role == 'healer' or role == 'support' then
        return {r=137, g=213, b=171, a=220}
    elseif role == 'melee' or role == 'ranged'
        or role == 'offensive_caster' then
        return {r=224, g=145, b=151, a=220}
    end
    return {r=177, g=199, b=209, a=220}
end

function UI:_prime_incoming_card_textures()
    local textures = {
        {INCOMING_REPLACEMENT_OVERLAY,
            math.floor(RIGHT_WIDTH / 2), ACTIVE_CARD_HEIGHT},
        {REPLACEMENT_AMBER.split_gradient,
            math.floor(RIGHT_WIDTH / 2), ACTIVE_CARD_HEIGHT - 2},
        {INCOMING_SPLIT_BORDER_MASK,
            math.floor(RIGHT_WIDTH / 2), ACTIVE_CARD_HEIGHT},
        {'assets/ui/incoming-split-gradient-blue.png',
            math.floor(RIGHT_WIDTH / 2), ACTIVE_CARD_HEIGHT - 2},
        {'assets/ui/incoming-split-gradient-green.png',
            math.floor(RIGHT_WIDTH / 2), ACTIVE_CARD_HEIGHT - 2},
        {'assets/ui/incoming-split-gradient-red.png',
            math.floor(RIGHT_WIDTH / 2), ACTIVE_CARD_HEIGHT - 2},
    }
    for _, texture in ipairs(textures) do
        local path = self:_asset(texture[1])
        if self:_exists(path) then
            self:_prime_image(path, texture[2], texture[3],
                'incoming_card_texture_preload', texture[1])
        end
    end
end

function UI:_add_image(path, x, y, width, height, color, alpha, primitive_kind,
        primitive_key)
    color = color or COLORS.white
    local kind = primitive_kind or 'image'
    local next_path = path or ''
    local target_alpha = alpha or color.a or 255
    local image_settings = {
        pos = {x=self:_origin_x() + self:_s(x),
            y=self:_origin_y() + self:_s(y)},
        size = {width=self:_s(width), height=self:_s(height)},
        color = copy_color(color, target_alpha),
        -- fit=true tells Windower to restore the texture's native dimensions,
        -- which breaks row icons, card crops, and their mouse hitboxes.
        texture = {path=next_path, fit=false},
        draggable = false,
        -- Window redraws are double-buffered. Keep each replacement primitive
        -- hidden until the complete tree has been positioned and styled.
        visible = false,
    }
    local create = function() return self.images.new('', image_settings) end
    local record, created
    if primitive_key ~= nil then
        record, created = self:_acquire_keyed(kind, primitive_key, create)
    else
        record, created = self:_acquire(kind, create)
    end
    local object = record.object
    local path_changed = record.path ~= next_path
    local defer_swap = next_path ~= '' and DEFERRED_TEXTURE_SWAP_KINDS[kind]
        and (created or path_changed)
    local image_x = image_settings.pos.x
    local image_y = image_settings.pos.y
    local image_width = image_settings.size.width
    local image_height = image_settings.size.height
    local color_changed = not record.image_color
        or record.image_color.r ~= color.r
        or record.image_color.g ~= color.g
        or record.image_color.b ~= color.b
    local track_inner = self.performance_diagnostics
        and kind == 'active_card_inner_fill'

    -- Windower can expose a white or magenta fallback quad when a visible
    -- primitive changes to a texture that has not completed one prerender.
    -- Hide the real slot primitive before its path swap, warm it at zero alpha
    -- for one frame, then reveal it on the following render.
    if defer_swap and record.visible then
        pcall(function() object:hide() end)
        record.visible = false
    end

    if not created then
        if record.image_x ~= image_x or record.image_y ~= image_y then
            local setter_started = track_inner and self.clock() or nil
            object:pos(image_x, image_y)
            self:_performance_stage_add('active-base-inner-pos',
                setter_started)
        end
        if record.image_width ~= image_width
                or record.image_height ~= image_height then
            local setter_started = track_inner and self.clock() or nil
            object:size(image_width, image_height)
            self:_performance_stage_add('active-base-inner-size',
                setter_started)
        end
        if color_changed then
            local setter_started = track_inner and self.clock() or nil
            object:color(color.r, color.g, color.b)
            self:_performance_stage_add('active-base-inner-color',
                setter_started)
        end
        if record.image_fit ~= false then
            object:fit(false)
        end
        if path_changed then
            local setter_started = track_inner and self.clock() or nil
            object:path(next_path)
            self:_performance_stage_add('active-base-inner-path',
                setter_started)
        end
    end
    local applied_alpha = target_alpha
    if defer_swap then
        applied_alpha = 0
        record.texture_ready_frame = self.frame_id + 1
        self.deferred_texture_reveal = true
    elseif record.texture_ready_frame
        and self.frame_id < record.texture_ready_frame then
        applied_alpha = 0
        self.deferred_texture_reveal = true
    else
        record.texture_ready_frame = nil
    end
    if record.image_alpha ~= applied_alpha then
        local setter_started = track_inner and self.clock() or nil
        object:alpha(applied_alpha)
        self:_performance_stage_add('active-base-inner-alpha',
            setter_started)
    end
    record.image_x = image_x
    record.image_y = image_y
    record.image_width = image_width
    record.image_height = image_height
    record.image_fit = false
    record.image_color = {r=color.r, g=color.g, b=color.b}
    record.image_alpha = applied_alpha
    record.path = next_path
    record.color = color
    record.alpha = applied_alpha
    record.target_alpha = target_alpha
    return self:_record(record, x, y)
end

function UI:_prime_image(path, width, height, primitive_kind, primitive_key)
    if not path then return end
    local image_settings = {
        pos = {x=self:_origin_x() - self:_s(width) - 100,
            y=self:_origin_y()},
        size = {width=self:_s(width), height=self:_s(height)},
        color = copy_color(COLORS.white, 0),
        texture = {path=path, fit=false},
        draggable = false,
        visible = false,
    }
    local record, created = self:_acquire_keyed(primitive_kind, primitive_key, function()
        return self.images.new('', image_settings)
    end)
    local object = record.object
    -- Keep the resident texture visible only offscreen and fully transparent.
    -- Windower can expose a white quad when a hidden texture is revealed before
    -- its first load completes; an alpha-zero prerender avoids that transition.
    if record.prime_x ~= image_settings.pos.x
            or record.prime_y ~= image_settings.pos.y then
        object:pos(image_settings.pos.x, image_settings.pos.y)
    end
    if record.prime_width ~= image_settings.size.width
            or record.prime_height ~= image_settings.size.height then
        object:size(image_settings.size.width, image_settings.size.height)
    end
    if not record.prime_styled then
        object:color(COLORS.white.r, COLORS.white.g, COLORS.white.b)
        object:fit(false)
        record.prime_styled = true
    end
    -- A keyed primitive can have been visible as a split card before it is
    -- reused for preload. Always restore its transparent preload state.
    object:alpha(0)
    if record.path ~= path then
        record.object:path(path)
    end
    if not record.visible then
        pcall(function() record.object:show() end)
        record.visible = true
    end
    record.frame = self.frame_id
    record.path = path
    record.prime_x = image_settings.pos.x
    record.prime_y = image_settings.pos.y
    record.prime_width = image_settings.size.width
    record.prime_height = image_settings.size.height
end

function UI:_add_rect(x, y, width, height, color, alpha, primitive_kind,
        primitive_key)
    return self:_add_image('', x, y, width, height, color, alpha,
        primitive_kind or 'rect', primitive_key)
end

function UI:_add_mask(relative_path, x, y, width, height, color, alpha,
        primitive_kind, primitive_key)
    local path = self:_asset(relative_path)
    if self:_exists(path) then
        return self:_add_image(path, x, y, width, height, color, alpha,
            primitive_kind, primitive_key)
    end
    return self:_add_rect(x, y, width, height, color, alpha,
        primitive_kind, primitive_key)
end

function UI:_add_text(value, x, y, size, color, font, bold, stroke_alpha,
        primitive_kind, primitive_key, minimum_pixels, cache_static)
    color = color or COLORS.white
    stroke_alpha = tonumber(stroke_alpha)
        or 190
    value = tostring(value or '')
    local text_settings = {
        pos = {x=self:_origin_x() + self:_s(x),
            y=self:_origin_y() + self:_s(y)},
        bg = {visible=false, alpha=0, red=0, green=0, blue=0},
        flags = {right=false, bottom=false, bold=bold == true, draggable=false, italic=false},
        padding = 0,
        text = {
            size=math.max(tonumber(minimum_pixels) or 6, self:_s(size)),
            font=font or 'Michroma',
            fonts={'Arial'},
            alpha=color.a or 255,
            red=color.r,
            green=color.g,
            blue=color.b,
            stroke={width=1, alpha=stroke_alpha, red=0, green=0, blue=0},
        },
    }
    local kind = primitive_kind or 'text'
    local create = function() return self.texts.new(value, text_settings) end
    local record, created
    if primitive_key ~= nil then
        record, created = self:_acquire_keyed(kind, primitive_key, create)
    else
        record, created = self:_acquire(kind, create)
    end
    local object = record.object

    local static_signature = table.concat({tostring(text_settings.text.size),
        tostring(text_settings.text.font), tostring(bold == true),
        tostring(stroke_alpha)}, '|')
    local color_changed = not record.cached_color
        or record.cached_color.r ~= color.r
        or record.cached_color.g ~= color.g
        or record.cached_color.b ~= color.b
        or record.cached_color.a ~= (color.a or 255)
    local static_cache_warm = cache_static
        and record.frame == self.frame_id - 1
    local is_metadata_text = cache_static
        and type(primitive_kind) == 'string'
        and (primitive_kind:match('^active_card_job_')
            or primitive_kind:match('^active_card_role_')
            or primitive_kind:match('^active_card_name_')) ~= nil
    if is_metadata_text and self.performance_frame then
        local cache_hit = not created and static_cache_warm
            and record.static_signature == static_signature
            and record.text_value == value
        if cache_hit then
            self.performance_frame.metadata_text_cache_hits =
                (self.performance_frame.metadata_text_cache_hits or 0) + 1
        else
            self.performance_frame.metadata_text_cache_misses =
                (self.performance_frame.metadata_text_cache_misses or 0) + 1
        end
    end
    if not created then
        local style_changed = not static_cache_warm
            or record.static_signature ~= static_signature
        local value_changed = not static_cache_warm
            or record.text_value ~= value
        if not cache_static then
            style_changed = true
            value_changed = true
        end
        if value_changed then
            object:text(value)
        end
        if style_changed then
            object:font(text_settings.text.font, unpack(text_settings.text.fonts))
            object:size(text_settings.text.size)
            object:bold(bold == true)
            object:stroke_width(1)
            object:stroke_color(0, 0, 0)
            object:stroke_alpha(stroke_alpha)
            record.static_signature = static_signature
        end
        if record.text_pos_x ~= text_settings.pos.x
                or record.text_pos_y ~= text_settings.pos.y then
            object:pos(text_settings.pos.x, text_settings.pos.y)
        end
        record.text_pos_x = text_settings.pos.x
        record.text_pos_y = text_settings.pos.y
        if not cache_static or color_changed then
            object:color(color.r, color.g, color.b)
            object:alpha(color.a or 255)
        end
    elseif cache_static then
        record.static_signature = static_signature
    end
    if created then
        record.text_pos_x = text_settings.pos.x
        record.text_pos_y = text_settings.pos.y
    end
    record.text_value = value
    record.cached_color = {r=color.r, g=color.g, b=color.b, a=color.a or 255}
    record.value = value
    record.color = color
    record.alpha = color.a or 255
    record.font_size = text_settings.text.size
    return self:_record(record, x, y)
end

function UI:_measure_text(value, pixel_size, font, bold)
    return estimated_text_width(value, pixel_size, font, bold),
        pixel_size * TEXT_EXTENT_SCALE
end

function UI:_add_centered_text(value, x, y, width, height, size, color, font, bold,
        horizontal_padding, minimum_size, stroke_alpha, vertical_offset,
        primitive_kind, primitive_key, horizontal_offset, cache_static)
    local object = self:_add_text(value, x, y, size, color, font, bold,
        stroke_alpha, primitive_kind, primitive_key, nil, cache_static)
    local record = self.objects[#self.objects]
    local pixel_size = math.max(6, self:_s(size))
    local text_width, text_height = self:_measure_text(value, pixel_size, font, bold)
    local padding = self:_s(tonumber(horizontal_padding) or 8)
    local available_width = math.max(1, self:_s(width) - padding * 2)

    if text_width > available_width then
        local minimum_pixels = math.max(6, self:_s(tonumber(minimum_size) or 8))
        local fitted_size = math.max(minimum_pixels,
            math.floor(pixel_size * available_width / text_width))
        if fitted_size < pixel_size then
            local ratio = fitted_size / pixel_size
            pcall(function() object:size(fitted_size) end)
            record.font_size = fitted_size
            text_width = text_width * ratio
            text_height = text_height * ratio
        end
    end

    local relative_x = self:_s(x) + (self:_s(width) - text_width) / 2
        + self:_s(tonumber(horizontal_offset) or 0)
    local relative_y = self:_s(y) + (self:_s(height) - text_height) / 2
        + self:_s(tonumber(vertical_offset) or 0)
    local final_x = self:_origin_x() + relative_x
    local final_y = self:_origin_y() + relative_y
    if record.text_layout_x ~= final_x
            or record.text_layout_y ~= final_y then
        object:pos(final_x, final_y)
    end
    record.text_layout_x = final_x
    record.text_layout_y = final_y
    record.x = relative_x
    record.y = relative_y
    return object
end

function UI:_state_label_sweep(state_key, active, idle_enabled)
    if not self.state_label_started[state_key] then
        self.state_label_started[state_key] = self.clock()
        self.state_label_active_started[state_key] = nil
    end
    self.state_label_last_frame[state_key] = self.frame_id

    if active then
        if not self.state_label_active_started[state_key] then
            self.state_label_active_started[state_key] = self.clock()
        end
        self.state_label_pulse_active = true
        local elapsed = math.max(0,
            self.clock() - self.state_label_active_started[state_key])
        return (elapsed % CARD_STATE_ACTIVE_SWEEP_DURATION)
            / CARD_STATE_ACTIVE_SWEEP_DURATION, true
    end
    self.state_label_active_started[state_key] = nil

    if not idle_enabled then
        return nil, false
    end

    local elapsed = math.max(0,
        self.clock() - (self.state_label_started[state_key] or self.clock()))
    local cycle_elapsed = elapsed % CARD_STATE_IDLE_SWEEP_CYCLE
    if cycle_elapsed >= CARD_STATE_PULSE_DURATION then
        return nil, false
    end
    self.state_label_pulse_active = true

    return cycle_elapsed / CARD_STATE_PULSE_DURATION, false
end

function UI:_state_label_glyph_color(base_color, glyph_index, glyph_count,
        sweep_progress, active, emphasized, summon_accent)
    if sweep_progress == nil then
        return base_color
    end
    local glyph_position = glyph_count > 1
        and (glyph_index - 1) / (glyph_count - 1) or 0
    local sweep_position = sweep_progress * 1.4 - 0.1
    local distance = math.abs(glyph_position - sweep_position)
    local sweep_width = emphasized and 0.24 or CARD_STATE_SWEEP_WIDTH
    local intensity = math.max(0, 1 - distance / sweep_width)
    intensity = intensity * intensity
    local amount
    if summon_accent then
        amount = intensity * (active and 0.50 or 0.68)
    else
        amount = intensity * (emphasized
            and (active and 0.58 or 0.72)
            or (active and 0.32 or 0.40))
    end
    return {
        r=math.floor(base_color.r + (255 - base_color.r) * amount + 0.5),
        g=math.floor(base_color.g + (255 - base_color.g) * amount + 0.5),
        b=math.floor(base_color.b + (255 - base_color.b) * amount + 0.5),
        a=base_color.a or 255,
    }
end

function UI:_add_card_state_label(value, region_x, region_y, region_width,
        region_height, base_color, state_key, primitive_kind, primitive_key,
        active, alignment)
    self.animation_state_labels = self.animation_state_labels or {}
    self.animation_state_labels[state_key] = {
        value=value,
        region_x=region_x,
        region_y=region_y,
        region_width=region_width,
        region_height=region_height,
        base_color=base_color,
        state_key=state_key,
        primitive_kind=primitive_kind,
        primitive_key=primitive_key,
        active=active,
        alignment=alignment,
    }
    local font = 'Michroma'
    local size = CARD_STATE_LABEL_SIZE
    local bold = true
    local tracking = CARD_STATE_LABEL_TRACKING
    local glyphs = utf8_characters(value)
    local glyph_widths = {}
    local tracked_width = 0
    for index, glyph in ipairs(glyphs) do
        local visual_width = estimated_text_width(glyph, size, font, bold)
        local glyph_width = visual_width * CARD_STATE_GLYPH_ADVANCE_SCALE
        glyph_widths[index] = glyph_width
        if index == #glyphs then
            -- Do not reserve inter-glyph advance after the final character;
            -- its visible edge is the label edge used for alignment.
            tracked_width = tracked_width + visual_width
        else
            tracked_width = tracked_width + glyph_width + tracking
        end
    end

    -- Match the previous centered label's right edge, then let tracking grow
    -- exclusively toward the left.
    local untracked_width = estimated_text_width(value, size, font, bold)
    local right_edge
    if type(alignment) == 'number' then
        right_edge = alignment
    elseif alignment == 'center' then
        right_edge = region_x + region_width / 2 + tracked_width / 2
    else
        right_edge = region_x + (region_width + untracked_width) / 2
    end
    local glyph_x = right_edge - tracked_width
    local text_height = size * TEXT_EXTENT_SCALE
    local text_y = region_y + (region_height - text_height) / 2 - 2
    local sweep_progress, active_sweep =
        self:_state_label_sweep(state_key, active, true)
    if self.performance_frame and sweep_progress ~= nil then
        self.performance_frame.state_label_shimmer = true
        if active_sweep then
            self.performance_frame.active_state_label = true
        end
    end
    local opacity_ratio = math.min(1, (base_color.a or 255) / 220)
    local shadow_color = {
        r=0, g=4, b=8,
        a=math.floor(190 * opacity_ratio + 0.5),
    }
    local shadow_stroke_alpha = math.floor(220 * opacity_ratio + 0.5)
    local main_stroke_alpha = math.floor(230 * opacity_ratio + 0.5)

    -- During queue execution, keep the shimmer as a whole-label color pulse
    -- instead of allocating four text primitives for every glyph. The normal
    -- idle path below retains the per-glyph sweep used outside execution.
    if USE_PRE_RENDERED_STATE_LABEL_SWEEP then
        local frame_index = sweep_progress and
            (math.floor(sweep_progress * STATE_LABEL_SWEEP_FRAME_COUNT)
                % STATE_LABEL_SWEEP_FRAME_COUNT) + 1 or 1
        local frame_path = self:_asset(('assets/ui/prototypes/'
            .. 'state-label-sweep/%s-%02d.png'):format(
                value:lower(), frame_index))
        if self:_exists(frame_path) then
            if not self.state_label_sweep_primed then
                for _, label_name in ipairs({'summon', 'dismiss'}) do
                    for preload_index = 1, STATE_LABEL_SWEEP_FRAME_COUNT do
                        self:_prime_image(self:_asset(('assets/ui/prototypes/'
                            .. 'state-label-sweep/%s-%02d.png'):format(
                                label_name, preload_index)),
                            STATE_LABEL_SWEEP_WIDTH,
                            STATE_LABEL_SWEEP_HEIGHT,
                            'state_label_sweep_preload',
                            label_name .. ':' .. tostring(preload_index))
                    end
                end
                self.state_label_sweep_primed = true
            end
            local single_key = tostring(primitive_key) .. ':1'
            self:_add_image(frame_path,
                right_edge - STATE_LABEL_SWEEP_WIDTH,
                region_y + (region_height - STATE_LABEL_SWEEP_HEIGHT) / 2,
                STATE_LABEL_SWEEP_WIDTH, STATE_LABEL_SWEEP_HEIGHT,
                base_color, base_color.a or 255,
                primitive_kind, single_key)
            local record = self.keyed_pool[primitive_kind]
                and self.keyed_pool[primitive_kind][single_key]
                or self.objects[#self.objects]
            record.value = value
            record.base_color = base_color
            record.tracking = tracking
            record.glyph_advance_scale = CARD_STATE_GLYPH_ADVANCE_SCALE
            record.state_region_x = region_x
            record.state_region_width = region_width
            record.state_center = right_edge - tracked_width / 2
            record.state_right_edge = right_edge
            record.shimmer_mode = 'raster'
            return
        end
    end
    for index, glyph in ipairs(glyphs) do
        local glyph_key = tostring(primitive_key) .. ':' .. tostring(index)
        local color = self:_state_label_glyph_color(base_color,
            index, #glyphs, sweep_progress, active_sweep,
            value == 'DISMISS', value == 'SUMMON')
        self:_add_text(glyph, glyph_x - 1.25, text_y + 1.5,
            size, shadow_color, font, bold, shadow_stroke_alpha,
            primitive_kind .. '_shadow', glyph_key, 6, true)
        -- Windower exposes only a binary bold flag. A second fill copy offset
        -- toward the left adds a little display weight without moving the
        -- label's right edge toward the portrait.
        self:_add_text(glyph, glyph_x - 1, text_y,
            size, color, font, bold, 0,
            primitive_kind .. '_weight', glyph_key, 6, true)
        self:_add_text(glyph, glyph_x + 1, text_y,
            size, color, font, bold, 0,
            primitive_kind .. '_weight_right', glyph_key, 6, true)
        self:_add_text(glyph, glyph_x, text_y,
            size, color, font, bold, main_stroke_alpha,
            primitive_kind, glyph_key, 6, true)
        local record = self.keyed_pool[primitive_kind]
            and self.keyed_pool[primitive_kind][glyph_key]
        if record then
            record.state_right_edge = right_edge
            record.state_center = right_edge - tracked_width / 2
            record.state_region_x = region_x
            record.tracking = tracking
            record.glyph_advance_scale = CARD_STATE_GLYPH_ADVANCE_SCALE
            record.base_color = base_color
            record.shimmer_mode = 'glyph'
        end
        glyph_x = glyph_x + glyph_widths[index] + tracking
    end
end

function UI:_add_left_fitted_text(value, x, y, width, height, size, color, font,
        bold, horizontal_padding, minimum_size, stroke_alpha, primitive_kind,
        primitive_key)
    local object = self:_add_text(value, x, y, size, color, font, bold,
        stroke_alpha, primitive_kind, primitive_key)
    local record = self.objects[#self.objects]
    local pixel_size = math.max(6, self:_s(size))
    local text_width, text_height = self:_measure_text(
        value, pixel_size, font, bold)
    local padding = self:_s(tonumber(horizontal_padding) or 0)
    local available_width = math.max(1, self:_s(width) - padding * 2)

    if text_width > available_width then
        local minimum_pixels = math.max(6, self:_s(tonumber(minimum_size) or 8))
        local fitted_size = math.max(minimum_pixels,
            math.floor(pixel_size * available_width / text_width))
        if fitted_size < pixel_size then
            local ratio = fitted_size / pixel_size
            pcall(function() object:size(fitted_size) end)
            record.font_size = fitted_size
            text_width = text_width * ratio
            text_height = text_height * ratio
        end
    end

    local relative_x = self:_s(x) + padding
    local relative_y = self:_s(y) + (self:_s(height) - text_height) / 2
    object:pos(self:_origin_x() + relative_x,
        self:_origin_y() + relative_y)
    record.x = relative_x
    record.y = relative_y
    return object
end

function UI:_add_vertically_centered_text(value, x, y, height, size, color, font,
        bold, primitive_kind, primitive_key, minimum_pixels, stroke_alpha)
    local object = self:_add_text(value, x, y, size, color, font, bold,
        stroke_alpha, primitive_kind, primitive_key, minimum_pixels, true)
    local pixel_size = math.max(tonumber(minimum_pixels) or 6, self:_s(size))
    local _, text_height = self:_measure_text(value, pixel_size, font, bold)
    local relative_x = self:_s(x)
    local relative_y = self:_s(y) + (self:_s(height) - text_height) / 2
    local record = self.objects[#self.objects]
    local final_x = self:_origin_x() + relative_x
    local final_y = self:_origin_y() + relative_y
    if record.text_layout_x ~= final_x
            or record.text_layout_y ~= final_y then
        object:pos(final_x, final_y)
    end
    record.text_layout_x = final_x
    record.text_layout_y = final_y
    record.x = relative_x
    record.y = relative_y
    return object
end

function UI:_hitbox(x, y, width, height, action, kind, hover_key)
    self.hitboxes[#self.hitboxes + 1] = {
        x=x,
        y=y,
        width=width,
        height=height,
        action=action,
        kind=kind,
        hover_key=hover_key,
    }
end

function UI:_button(label, x, y, width, height, action, enabled, primitive_kind)
    enabled = enabled ~= false
    local base_kind = primitive_kind or 'button'
    local enabled_kind = base_kind .. '_enabled_rect'
    local disabled_kind = base_kind .. '_disabled_rect'
    local cancel = base_kind == 'queue_cancel_button'
    local primary = base_kind == 'queue_action_button' or cancel
    local footer_capsule = base_kind == 'clear_changes_button'
        or base_kind == 'dismiss_all_button'
    local compact_capsule = base_kind == 'preset_load_button'
        or base_kind == 'preset_save_button'
        or base_kind == 'preset_clear_button'
        or base_kind == 'filter_cycle_button'
        or base_kind == 'filter_menu_button'
        or base_kind == 'sort_cycle_button'
        or base_kind == 'sort_menu_button'
        or base_kind == 'clear_search_button'
    local capsule = primary or footer_capsule or compact_capsule
    local destructive = base_kind == 'dismiss_all_button' or cancel
    local track_clear = self.performance_diagnostics
        and base_kind == 'clear_changes_button'
    local control_key = primary and 'queue_action_button'
        or ((footer_capsule or compact_capsule) and base_kind or nil)
    local hovered = capsule and self.hover_key == control_key
    local pressed = capsule and self.pressed_key == control_key
    local debug_primary = primary and PRIMARY_ACTION_DEBUG_MAGENTA
        and not hovered and not pressed
    -- Hide the opposite palette as soon as the logical button state is known.
    -- Waiting for frame finalization can leave a later-created disabled surface
    -- above an enabled, pressable control for the duration of the transition.
    local inactive_kind = enabled and disabled_kind or enabled_kind
    local hide_started = track_clear and self.clock() or nil
    for _, record in ipairs(self.object_pool[inactive_kind] or {}) do
        if record.visible then
            pcall(function() record.object:hide() end)
            record.visible = false
        end
    end
    self:_performance_stage_add('footer-clear-hide', hide_started)
    -- Windower can retain both the creation color and creation alpha of a
    -- blank-texture primitive. Each palette therefore owns separate records,
    -- and only the active palette participates in the frame. _finish_frame()
    -- switches palettes with reliable show/hide calls rather than mutations.
    local surface_started = track_clear and self.clock() or nil
    if enabled then
        local base_border = cancel and COLORS.footer_dismiss_border
            or (primary and COLORS.button_glass_border
            or (destructive and COLORS.footer_dismiss_border
                or COLORS.footer_button_border))
        local base_fill = cancel and COLORS.footer_dismiss_fill
            or (primary and COLORS.button_capsule_fill
            or (destructive and COLORS.footer_dismiss_fill
                or COLORS.footer_button_fill))
        local base_shadow = cancel and COLORS.footer_dismiss_bottom
            or (primary and COLORS.button_capsule_bottom
            or (destructive and COLORS.footer_dismiss_bottom
                or COLORS.footer_button_bottom))
        local base_text = cancel and COLORS.footer_dismiss_text
            or (primary and COLORS.button_capsule_text
            or (destructive and COLORS.footer_dismiss_text
                or COLORS.footer_button_text))
        local border = capsule
            and (primary and debug_primary and COLORS.button_debug_border
                or (pressed and (destructive and COLORS.footer_dismiss_hover
                    or (primary and COLORS.gold_bright
                        or COLORS.footer_button_text))
                    or (hovered and (destructive and COLORS.footer_dismiss_hover
                        or COLORS.cyan)
                        or base_border)))
            or COLORS.shell_border
        local fill = capsule
            and (primary and debug_primary and COLORS.button_debug_fill
                or (pressed and (primary and COLORS.button_capsule_pressed
                    or (destructive and COLORS.footer_dismiss_pressed
                        or COLORS.footer_button_pressed)) or base_fill))
            or COLORS.button
        if capsule then
            local shadow_color = base_shadow
            if primary then
                if cancel then
                    shadow_color = pressed and COLORS.footer_dismiss_pressed
                        or (hovered and COLORS.footer_dismiss_hover
                            or COLORS.footer_dismiss_bottom)
                elseif debug_primary then
                    shadow_color = COLORS.button_debug_bottom
                else
                    shadow_color = pressed and COLORS.button_capsule_pressed
                        or (hovered and COLORS.button_capsule_hover_bottom
                            or COLORS.button_capsule_bottom)
                end
            elseif pressed then
                shadow_color = destructive and COLORS.footer_dismiss_pressed
                    or COLORS.footer_button_pressed
            elseif hovered then
                shadow_color = destructive and COLORS.footer_dismiss_bottom
                    or COLORS.footer_button_bottom
            end
            self:_add_mask(PRIMARY_ACTION_MASK,
                x, y + (primary and 4 or (compact_capsule and 2 or 3)), width, height,
                shadow_color,
                pressed and 220 or 255, enabled_kind)
            self:_add_mask(PRIMARY_ACTION_MASK,
                x, y, width, height, border, 255, enabled_kind)
            self:_add_mask(PRIMARY_ACTION_MASK,
                x + 3, y + 2, width - 6, height - 6, fill, 250, enabled_kind)
        else
            self:_add_rect(x, y, width, height, border,
                230, enabled_kind)
            self:_add_rect(x + 2, y + 2, width - 4, height - 4,
                fill, 250, enabled_kind)
        end
    else
        if capsule then
            self:_add_mask(PRIMARY_ACTION_MASK,
                x, y + (primary and 3 or (compact_capsule and 2 or 2)),
                width, height, COLORS.dim, 190, disabled_kind)
            self:_add_mask(PRIMARY_ACTION_MASK,
                x, y, width, height, COLORS.dim, 230, disabled_kind)
            self:_add_mask(PRIMARY_ACTION_MASK,
                x + 3, y + 2, width - 6, height - 6,
                COLORS.button_disabled, 250, disabled_kind)
        else
            self:_add_rect(x, y, width, height,
                COLORS.dim, 230, disabled_kind)
            self:_add_rect(x + 2, y + 2, width - 4, height - 4,
                COLORS.button_disabled, 250, disabled_kind)
        end
    end
    self:_performance_stage_add('footer-clear-surface', surface_started)
    local text_color = COLORS.muted
    if enabled then
        if capsule then
            local base_text = cancel and COLORS.red_bright
                or (destructive and COLORS.red_bright or COLORS.footer_button_text)
            text_color = primary and debug_primary and COLORS.white
                or (pressed and (destructive and COLORS.footer_dismiss_text
                    or COLORS.gold_bright)
                or (hovered and COLORS.white or base_text))
        else
            text_color = COLORS.gold
        end
    end
    local label_started = track_clear and self.clock() or nil
    self:_add_centered_text(label, x, y, width, height,
        primary and 12 or (capsule and 11 or 13), text_color, 'Arial', true,
        12, 8, capsule and 0 or nil, capsule and -3 or 0,
        base_kind .. '_label', 'main',
        base_kind == 'preset_clear_button' and -1 or 0,
        base_kind == 'clear_changes_button'
            or base_kind == 'queue_action_button'
            or base_kind == 'queue_cancel_button')
    self:_performance_stage_add('footer-clear-label', label_started)
    if enabled and action then
        local hitbox_started = track_clear and self.clock() or nil
        self:_hitbox(x, y, width, height, action, 'button', control_key)
        self:_performance_stage_add('footer-clear-hitbox', hitbox_started)
    end
end

function UI:_split_control(cycle_label, x, y, width, height, cycle_width,
        cycle_action, menu_action, enabled, group_key, menu_label)
    enabled = enabled ~= false
    local menu_width = width - cycle_width
    local cycle_key = group_key .. ':cycle'
    local menu_key = group_key .. ':menu'
    local cycle_hovered = enabled and self.hover_key == cycle_key
    local menu_hovered = enabled and self.hover_key == menu_key
    local cycle_pressed = enabled and self.pressed_key == cycle_key
    local menu_pressed = enabled and self.pressed_key == menu_key
    local state_kind = group_key .. (enabled and '_enabled_rect' or '_disabled_rect')
    local group_mask = group_key == 'filter_split_button'
        and FILTER_SPLIT_MASK or SORT_SPLIT_MASK
    local border = enabled and COLORS.footer_button_border or COLORS.dim
    local fill = enabled and COLORS.footer_button_fill or COLORS.button_disabled
    local shadow = enabled and COLORS.footer_button_bottom or COLORS.dim
    local cycle_state = cycle_pressed and COLORS.footer_button_pressed
        or (cycle_hovered and COLORS.footer_button_border or fill)
    local menu_state = menu_pressed and COLORS.footer_button_pressed
        or (menu_hovered and COLORS.footer_button_border or fill)
    local cycle_alpha = enabled and ((cycle_hovered or cycle_pressed) and 255 or 0) or 0
    local menu_alpha = enabled and ((menu_hovered or menu_pressed) and 255 or 0) or 0

    self:_add_mask(group_mask, x, y + 2, width, height,
        shadow, enabled and 255 or 190, state_kind)
    self:_add_mask(group_mask, x, y, width, height,
        border, enabled and 255 or 230, state_kind)
    self:_add_mask(group_mask, x + 3, y + 2, width - 6, height - 6,
        fill, 250, state_kind)
    self:_add_mask(PRIMARY_ACTION_LEFT_MASK,
        x + 3, y + 2, cycle_width - 3, height - 6,
        cycle_state, cycle_alpha, state_kind)
    self:_add_mask(SPLIT_RIGHT_MASK,
        x + cycle_width, y + 2, menu_width - 3, height - 6,
        menu_state, menu_alpha, state_kind)
    self:_add_rect(x + cycle_width, y + 7, 1, height - 14,
        COLORS.footer_button_border,
        enabled and 180 or 110, state_kind)

    local cycle_text_size = group_key == 'sort_split_button' and 11 or 13
    self:_add_centered_text(cycle_label, x, y, cycle_width, height,
        cycle_text_size,
        enabled and (cycle_hovered and COLORS.white or COLORS.footer_button_text)
            or COLORS.muted,
        'Arial', true, 2, 6, 0, -3)
    self:_add_centered_text(menu_label or 'v', x + cycle_width, y,
        menu_width, height, 9,
        enabled and (menu_hovered and COLORS.white or COLORS.muted)
            or COLORS.dim,
        'Arial', true, 2, 7, 0, -3)

    if enabled then
        self:_hitbox(x, y, cycle_width, height, cycle_action,
            'button', cycle_key)
        self:_hitbox(x + cycle_width, y, menu_width, height, menu_action,
            'button', menu_key)
    end
end

local function preset_slot_state(summary, locked)
    local selected = summary.selected
    local occupied = summary.occupied
    local state_key = selected and 'selected'
        or (occupied and 'occupied' or 'empty')
    if locked then
        state_key = state_key .. '_locked'
    end
    return state_key
end

function UI:_preset_slot_background(summary, x, y, size, locked)
    local selected = summary.selected
    local control_key = 'preset_slot:' .. tostring(summary.slot)
    local hovered = not locked and self.hover_key == control_key
    local pressed = not locked and self.pressed_key == control_key
    -- Occupancy is communicated only by the upper-right status marker. Keeping every
    -- unselected border blue prevents a saved-slot border from competing with
    -- the cyan selected-slot highlight.
    local border = locked and COLORS.dim
        or (pressed and COLORS.white
            or (selected and COLORS.cyan
                or (hovered and COLORS.footer_button_border or COLORS.shell_border)))
    local fill = locked and COLORS.button_disabled
        or (pressed and COLORS.button_capsule_pressed
            or (selected and COLORS.button_hot
                or (hovered and COLORS.footer_button_fill or COLORS.button)))
    local shadow = locked and COLORS.dim
        or (selected and COLORS.button_capsule_bottom or COLORS.footer_button_bottom)
    local kind = 'preset_slot_' .. preset_slot_state(summary, locked)
    self:_add_rect(x, y, size, size, border, 245, kind)
    self:_add_rect(x + 2, y + 2, size - 4, size - 4, fill, 250, kind)
    self:_add_rect(x + 2, y + size - 4, size - 4, 2,
        shadow, locked and 170 or 255, kind)
end

function UI:_preset_slot_foreground(summary, x, y, size, locked, activate)
    local selected = summary.selected
    local occupied = summary.occupied
    local control_key = 'preset_slot:' .. tostring(summary.slot)
    local hovered = not locked and self.hover_key == control_key
    local pressed = not locked and self.pressed_key == control_key
    local text_color = locked and COLORS.muted
        or (pressed and COLORS.white
            or (selected and COLORS.white
                or (hovered and COLORS.footer_button_text or COLORS.gold)))
    self:_add_centered_text(tostring(summary.slot), x, y, size, size,
        12, text_color, 'Arial', true, 4, 8, 0, -1)

    if occupied then
        local marker_kind = 'preset_occupied_marker'
        local marker_color = COLORS.preset_saved
        -- Party order is useful saved metadata, but it cannot be safely
        -- enforced without dismissing already-active Trusts into cooldown.
        -- Treat an order-only difference as fulfilled for the marker while
        -- retaining the explanatory status notice on interaction.
        if summary.matches_active or summary.order_mismatch then
            marker_kind = 'preset_match_marker'
            marker_color = COLORS.preset_matched
        elseif summary.partial and summary.loadable ~= false then
            marker_kind = 'preset_partial_marker'
            marker_color = COLORS.preset_partial
        elseif summary.loadable == false then
            marker_kind = 'preset_blocked_marker'
            marker_color = COLORS.preset_blocked
        end
        -- Use one thick upper-right tab instead of separately scaled fold
        -- steps. A single primitive preserves its silhouette at reduced UI
        -- scales and leaves the cyan selected border independently readable.
        local fold_color = locked and COLORS.muted or marker_color
        local marker_width = 10
        local marker_height = 5
        local marker_x = x + size - marker_width - 3
        if marker_kind == 'preset_blocked_marker' then
            -- A two-unit central break distinguishes blocked from partial even
            -- when hue perception or reduced-scale rendering obscures color.
            self:_add_rect(marker_x, y + 3, 4, marker_height,
                fold_color, 255, marker_kind,
                tostring(summary.slot) .. ':left')
            self:_add_rect(marker_x + 6, y + 3, 4, marker_height,
                fold_color, 255, marker_kind,
                tostring(summary.slot) .. ':right')
        else
            self:_add_rect(marker_x, y + 3,
                marker_width, marker_height, fold_color, 255,
                marker_kind, tostring(summary.slot))
        end
    end

    if not locked then
        local slot = summary.slot
        self:_hitbox(x, y, size, size, function()
            if activate then
                activate(summary)
            else
                self.commands:handle({'preset', 'select', tostring(slot)}, {silent=true})
                -- Selection alone is intentionally non-mutating in expanded
                -- mode. Remember that it supersedes any older preset plan if
                -- the user subsequently enters the direct-action compact UI.
                self.compact_preset_selection_pending = true
                self.compact_preset_restore_pending = true
                self:_show_preset_warning(summary)
                self:render(false)
            end
        end, 'button', 'preset_slot:' .. tostring(slot))
    end
end

local function preset_warning_text(summary)
    if summary and summary.order_mismatch then
        return 'ACTIVE TRUSTS MATCH - PARTY ORDER DIFFERS'
    end
    local blockers = summary and summary.blockers or {}
    if #blockers == 0 then
        return 'PRESET UNAVAILABLE'
    end
    if #blockers > 1 then
        local all_cooldown = true
        local named = 0
        for _, blocker in ipairs(blockers) do
            all_cooldown = all_cooldown and blocker.reason == 'cooldown'
            if blocker.name then named = named + 1 end
        end
        if all_cooldown then
            return ('%d TRUSTS ON COOLDOWN'):format(#blockers)
        elseif named == #blockers then
            return ('%d TRUSTS UNAVAILABLE'):format(#blockers)
        end
        return ('%d PRESET ISSUES'):format(#blockers)
    end

    local blocker = blockers[1]
    local name = blocker.name and tostring(blocker.name):upper() or nil
    if blocker.reason == 'cooldown' and name then
        return name .. ': COOLDOWN'
    elseif blocker.reason == 'not_learned' and name then
        return name .. ': NOT AVAILABLE'
    elseif blocker.reason == 'capacity_exceeded' then
        return 'INSUFFICIENT PARTY SPACE'
    elseif blocker.reason == 'state_unavailable' then
        return 'TRUST STATUS UNAVAILABLE'
    elseif name then
        return name .. ': UNAVAILABLE'
    end
    return 'PRESET UNAVAILABLE'
end

local function preset_is_cooldown_blocked(summary)
    if not summary or summary.loadable ~= false then
        return false
    end
    local blockers = summary.blockers or {}
    if #blockers == 0 then
        return false
    end
    for _, blocker in ipairs(blockers) do
        if blocker.reason ~= 'cooldown' then
            return false
        end
    end
    return true
end

local function preset_has_only_cooldown_blockers(summary)
    local blockers = summary and summary.blockers or {}
    if #blockers == 0 then
        return false
    end
    for _, blocker in ipairs(blockers) do
        if blocker.reason ~= 'cooldown' then
            return false
        end
    end
    return true
end

function UI:_show_preset_warning(summary)
    if not summary or (summary.loadable ~= false and not summary.partial
        and not summary.order_mismatch) then
        self.preset_warning = nil
        return
    end
    self.preset_warning = {
        slot = summary.slot,
        text = preset_warning_text(summary),
        partial = summary.partial == true,
        informational = summary.order_mismatch == true,
        started = self.clock(),
    }
end

function UI:_show_ui_warning(text, color, kind)
    self.ui_warning = {
        text = tostring(text or ''),
        color = color or COLORS.retry,
        kind = kind,
        started = self.clock(),
    }
end

function UI:_ui_warning_notice()
    local warning = self.ui_warning
    if not warning then return nil end
    local elapsed = math.max(0, self.clock() - warning.started)
    local total = PRESET_WARNING_HOLD + PRESET_WARNING_FADE
    if elapsed >= total then
        self.ui_warning = nil
        return nil
    end
    local alpha = 255
    if elapsed > PRESET_WARNING_HOLD then
        alpha = math.floor(255 * (1
            - (elapsed - PRESET_WARNING_HOLD) / PRESET_WARNING_FADE) + 0.5)
    end
    local color = warning.color
    return warning.text, {r=color.r, g=color.g, b=color.b, a=alpha}
end

function UI:_preset_warning_notice(selected)
    local warning = self.preset_warning
    if not warning then return nil end
    if not selected or selected.slot ~= warning.slot
        or (selected.loadable ~= false and not selected.partial
            and not selected.order_mismatch) then
        self.preset_warning = nil
        return nil
    end

    local elapsed = math.max(0, self.clock() - warning.started)
    local total = PRESET_WARNING_HOLD + PRESET_WARNING_FADE
    if elapsed >= total then
        self.preset_warning = nil
        return nil
    end

    local alpha = 255
    if elapsed > PRESET_WARNING_HOLD then
        alpha = math.floor(255 * (1
            - (elapsed - PRESET_WARNING_HOLD) / PRESET_WARNING_FADE) + 0.5)
    end
    local warning_color = warning.informational and COLORS.gold
        or (warning.partial and COLORS.preset_partial or COLORS.red)
    return warning.text, {r=warning_color.r, g=warning_color.g,
        b=warning_color.b, a=alpha}
end

function UI:_render_preset_warning(selected, suppressed)
    local label, color = self:_preset_warning_notice(selected)
    if label then
        if not suppressed then
            self:_add_left_fitted_text(label,
                FOOTER_NOTICE_X, FOOTER_NOTICE_Y,
                FOOTER_NOTICE_WIDTH, FOOTER_NOTICE_HEIGHT,
                11, color,
                'Arial', true, 0, 7, nil, 'footer_preset_warning')
        end
        return true
    end
    return false
end

function UI:_preset_summaries()
    local snapshot = self.state:snapshot()
    local sources = snapshot.sources or self.state.source_status or {}
    local queue_active = self.queue and self.queue:snapshot().active or false
    local ok, summaries = preset_engine.list(self.settings.presets, {
        active = self.state.party_trusts or {},
        by_id = self.state.by_id,
        max_trusts = snapshot.max_trusts,
        other_members = snapshot.other_members,
        -- Queue activity locks controls in the renderer, but it is not a
        -- property of the stored preset. Keep its saved/matched/partial/blocked
        -- marker stable while the selected slot's comet shows progress.
        queue_active = false,
        state_ready = snapshot.logged_in
            and sources.spells and sources.recasts
            and sources.party and sources.key_items,
    })
    if not ok then
        return nil, nil, snapshot, queue_active
    end

    local selected = nil
    for _, summary in ipairs(summaries) do
        if summary.selected then
            selected = summary
            break
        end
    end
    return summaries, selected, snapshot, queue_active
end

function UI:_render_presets()
    local summaries, selected, snapshot, queue_active = self:_preset_summaries()
    if not summaries then
        self.selected_preset_summary = nil
        return
    end

    -- Windower fonts have a six-pixel floor, so free-running labels do not
    -- shrink in lockstep with controls at compact UI scales. Constrain this
    -- label to its own box and preserve a ten-unit gap before slot 1.
    self:_add_centered_text(
        'PRESETS', 632, 99, 76, 26, 9, COLORS.gold, 'Arial', true, 2, 6)

    local first_x = 718
    local slot_size = 26
    local gap = 4
    for index, summary in ipairs(summaries) do
        self:_preset_slot_background(summary,
            first_x + (index - 1) * (slot_size + gap), 99, slot_size, queue_active)
    end
    for index, summary in ipairs(summaries) do
        self:_preset_slot_foreground(summary,
            first_x + (index - 1) * (slot_size + gap), 99, slot_size, queue_active)
    end
    self.selected_preset_summary = selected

    local load_enabled = selected and selected.occupied
        and selected.loadable ~= false and not queue_active
    local intended_count = snapshot.active_trusts
        - #self.state:pending_dismissal_records()
        + #self.state:pending_entries()
    local save_enabled = intended_count > 0 and not queue_active
    local clear_enabled = selected and selected.occupied and not queue_active
    self:_button('LOAD', 872, 99, 68, 26, function()
        self.commands:handle({'preset', 'load'}, {silent=true})
        self.compact_preset_selection_pending = false
        self.compact_preset_restore_pending = false
        self:_show_preset_warning(selected)
        self:render(true)
    end, load_enabled, 'preset_load_button')
    self:_button('SAVE', 946, 99, 74, 26, function()
        self.commands:handle({'preset', 'save'})
        self:render(false)
    end, save_enabled, 'preset_save_button')
    self:_button('CLEAR', 1028, 99, 74, 26, function()
        self.commands:handle({'preset', 'clear'}, {silent=true})
        self:render(false)
    end, clear_enabled, 'preset_clear_button')
end

function UI:_circle_button(label, x, y, size, action, primitive_kind,
        primitive_key, enabled, framed_idle)
    enabled = enabled ~= false
    local control_key = ('%s:%s:%s:%s'):format(
        tostring(primitive_kind or 'circle_control'),
        tostring(primitive_key or ''), tostring(x), tostring(y))
    local path = self:_asset(
        enabled and self.pressed_key == control_key
            and 'assets/ui/close-button-pressed.png'
        or enabled and self.hover_key == control_key
            and 'assets/ui/close-button-subtle.png'
        or framed_idle and 'assets/ui/close-button-subtle.png'
        or 'assets/ui/close-glyph.png')
    if self:_exists(path) then
        -- Keep idle, hover, and pressed treatments in complete textures so
        -- font metrics cannot move the glyph at different UI scales.
        self:_add_image(path, x, y, size, size,
            enabled and COLORS.white or COLORS.muted,
            enabled and 255 or 145,
            primitive_kind or 'circle_control', primitive_key)
    else
        self:_add_rect(x, y, size, size, COLORS.button, 255,
            primitive_kind or 'circle_control', primitive_key)
        self:_add_centered_text(label, x, y - size * 0.10, size, size, size * 0.55,
            COLORS.gold, 'Arial', true, 0, 6)
    end
    if enabled then
        self:_hitbox(x, y, size, size, action, 'button', control_key)
    end
end

function UI:_glyph_button(glyph, x, y, size, action, primitive_key)
    local control_key = 'window_glyph:' .. tostring(primitive_key or glyph)
    local hovered = self.hover_key == control_key
    local pressed = self.pressed_key == control_key
    if glyph == 'minus' then
        local state_asset = pressed and 'assets/ui/minimize-button-pressed.png'
            or hovered and 'assets/ui/minimize-button-subtle.png'
            or 'assets/ui/minimize-button.png'
        self:_add_image(self:_asset(state_asset), x, y, size, size,
            COLORS.white, 255, 'window_glyph_state', primitive_key)
        self:_hitbox(x, y, size, size, action, 'button', control_key)
        return
    elseif glyph == 'restore' then
        local state_asset = pressed and 'assets/ui/maximize-button-pressed.png'
            or hovered and 'assets/ui/maximize-button-subtle.png'
            or 'assets/ui/maximize-button.png'
        self:_add_image(self:_asset(state_asset), x, y, size, size,
            COLORS.white, 255, 'window_glyph_state', primitive_key)
        self:_hitbox(x, y, size, size, action, 'button', control_key)
        return
    end
    local show_frame = hovered or pressed
    self:_add_image(self:_asset('assets/ui/generic-control-hover.png'), x, y,
        size, size, COLORS.white,
        hovered and not pressed and 255 or 0,
        'window_glyph_hover', primitive_key)
    self:_add_image(self:_asset('assets/ui/generic-control-pressed.png'), x, y,
        size, size, COLORS.white, pressed and 255 or 0,
        'window_glyph_pressed', primitive_key)
    if not (hovered and not pressed) and not pressed then
        local border = pressed and COLORS.white or COLORS.footer_button_text
        local fill = pressed and COLORS.button_capsule_pressed or COLORS.muted
        -- Minimize and restore share close's circular hover language without
        -- baking a close glyph into the background texture.
        self:_add_mask(PRIMARY_ACTION_MASK, x, y, size, size,
            border, show_frame and (pressed and 115 or 65) or 0,
            'window_glyph_button', primitive_key)
        self:_add_mask(PRIMARY_ACTION_MASK,
            x + 2, y + 2, size - 4, size - 4, fill,
            show_frame and (pressed and 145 or 85) or 0,
            'window_glyph_fill', primitive_key)
    end
    if glyph == 'minus' then
        self:_add_rect(x + size * 0.27, y + size * 0.58,
            size * 0.46, 2, COLORS.white, 235,
            'window_glyph_mark', primitive_key)
    else
        local gx = x + size * 0.27
        local gy = y + size * 0.29
        local gw = size * 0.46
        local gh = size * 0.42
        self:_add_rect(gx, gy, gw, 2, COLORS.white, 235,
            'window_glyph_mark', tostring(primitive_key) .. ':top')
        self:_add_rect(gx, gy + gh - 2, gw, 2, COLORS.white, 235,
            'window_glyph_mark', tostring(primitive_key) .. ':bottom')
        self:_add_rect(gx, gy, 2, gh, COLORS.white, 235,
            'window_glyph_mark', tostring(primitive_key) .. ':left')
        self:_add_rect(gx + gw - 2, gy, 2, gh, COLORS.white, 235,
            'window_glyph_mark', tostring(primitive_key) .. ':right')
    end
    self:_hitbox(x, y, size, size, action, 'button', control_key)
end

function UI:_glass_action_button(label, x, y, width, height, action,
        primitive_key, enabled, control_key_override, primitive_kind_prefix)
    enabled = enabled ~= false
    local control_key = control_key_override
        or ('active_action:%s:%s:%s'):format(
            tostring(primitive_key or ''), tostring(x), tostring(y))
    local hovered = enabled and self.hover_key == control_key
    local pressed = enabled and self.pressed_key == control_key
    local undo = label == 'UNDO'
    local destructive = label == 'DISMISS' or label == 'DISMISS ALL'
    local accent = not enabled and COLORS.dim
        or (undo and COLORS.gold
            or (destructive and (hovered and COLORS.footer_dismiss_hover
                or COLORS.muted)
                or (hovered and COLORS.cyan or COLORS.muted)))
    local border_alpha = not enabled and 150
        or (pressed and 255 or (hovered and 235 or 185))
    local fill_alpha = not enabled and 125
        or (pressed and 185 or (hovered and 145 or 105))
    local kind_prefix = primitive_kind_prefix or 'active_action_button'
    local border_kind = enabled and kind_prefix .. '_border'
        or kind_prefix .. '_disabled_border'
    local fill_kind = enabled and kind_prefix .. '_fill'
        or kind_prefix .. '_disabled_fill'
    self:_add_mask(ACTIVE_ACTION_BORDER_MASK, x, y, width, height, accent, border_alpha,
        border_kind, primitive_key)
    self:_add_mask(ACTIVE_ACTION_MASK, x + 1, y + 1, width - 2, height - 2,
        enabled and (destructive and hovered and COLORS.footer_dismiss_fill
            or COLORS.shell)
            or COLORS.button_disabled, fill_alpha,
        fill_kind, primitive_key)
    local display_label = label
    local display_size = 8
    if label == 'DISMISS ALL' then
        -- Use a slightly smaller base size for the longer batch label. Testing
        -- fit at size 8 made the result non-monotonic: when rounded font size
        -- jumped from six to seven pixels, the label could revert to ALL even
        -- though the window was being enlarged.
        local full_label_size = 7
        local text_pixels = math.max(6, self:_s(full_label_size))
        local available_pixels = math.max(1,
            self:_s(width) - self:_s(2) * 2)
        local safety_pixels = 2
        if estimated_text_width(label, text_pixels, 'Arial', true)
                + safety_pixels
                > available_pixels then
            display_label = 'ALL'
        else
            display_size = full_label_size
        end
    end
    self:_add_centered_text(display_label, x, y, width, height, display_size,
        not enabled and COLORS.muted
            or (undo and COLORS.gold
                or COLORS.white),
        'Arial', true, 2, 7, nil, undo and -3 or -2,
        kind_prefix .. '_label', primitive_key, nil, true)
    if enabled then
        self:_hitbox(x, y, width, height, action, 'button', control_key)
    end
end

function UI:_destroy_objects(records)
    for _, record in ipairs(records or {}) do
        pcall(function() record.object:destroy() end)
    end
end

function UI:_show_objects(records)
    for _, record in ipairs(records or {}) do
        pcall(function() record.object:show() end)
    end
end

function UI:_begin_frame()
    -- Existing primitives stay visible while they are updated. Hiding the
    -- complete tree here produced a blank/magenta frame after every confirmed
    -- dismissal and summon.
    self.frame_id = self.frame_id + 1
    self.deferred_texture_reveal = false
    self.state_label_pulse_active = false
    self.pool_cursor = {rect=0, image=0, text=0}
    self.objects = {}
    self.hitboxes = {}
    self.animation_state_labels = {}
end

function UI:_render_drag_preview()
    self:_begin_frame()
    local window_frame = self:_asset('assets/ui/window-frame.png')
    local window_frame_available = self:_exists(window_frame)
    if window_frame_available then
        self:_add_image(window_frame, 0, 0, BASE_WIDTH, BASE_HEIGHT,
            COLORS.white, DRAG_PREVIEW_ALPHA,
            'drag_shell_frame', 'background')
    else
        self:_add_rect(0, 0, BASE_WIDTH, BASE_HEIGHT,
            COLORS.title, DRAG_PREVIEW_ALPHA, 'drag_shell_fill')
    end
    self:_finish_frame()
end

function UI:_end_drag_preview()
    if not self.drag_preview then
        return
    end
    self.drag_preview = false
    if self.visible and self.mode == 'expanded' then
        self:render(false)
    end
end

function UI:_finish_frame()
    -- Reveal only newly needed records and hide only surplus records after the
    -- complete replacement frame has been laid out. Frame marks support both
    -- ordinal pools and identity-keyed textures.
    -- New records must be shown in draw order; iterating pools with pairs()
    -- allowed a newly created preview background to be shown after its portrait.
    for _, record in ipairs(self.objects) do
        if not record.visible then
            pcall(function() record.object:show() end)
            record.visible = true
        end
    end
    for _, records in pairs(self.object_pool) do
        for _, record in ipairs(records) do
            if record.frame ~= self.frame_id and record.visible then
                pcall(function() record.object:hide() end)
                record.visible = false
            end
        end
    end
end

function UI:_hide_window()
    for _, records in pairs(self.object_pool) do
        for _, record in ipairs(records) do
            if record.visible then
                pcall(function() record.object:hide() end)
                record.visible = false
            end
        end
    end
    self.objects = {}
    self.hitboxes = {}
    self.primary_surface_kind = nil
end

function UI:_destroy_window()
    for _, records in pairs(self.object_pool) do
        self:_destroy_objects(records)
    end
    self.object_pool = {rect={}, image={}, text={}}
    self.keyed_pool = {}
    self.pool_cursor = {rect=0, image=0, text=0}
    self.objects = {}
    self.hitboxes = {}
    self.preset_controls_primed = false
    self.filter_dropdown_primed = false
    self.sort_dropdown_primed = false
    self.primary_surface_kind = nil
end

function UI:_render_launcher()
    if not self.icon_enabled or (self.visible and self.mode == 'compact') then
        self.launcher_pending_frames = 0
        if self.launcher then
            pcall(function() self.launcher:hide() end)
        end
        if self.launcher_pressed_icon then
            pcall(function() self.launcher_pressed_icon:hide() end)
        end
        return
    end

    self.launcher_size = 28
    if self.launcher then
        -- Keep the launcher primitive alive while disabled. Recreating a
        -- textured Windower primitive can expose its white, untextured quad
        -- for one frame; a resident texture can be shown again immediately.
        self.launcher:pos(self.launcher_x, self.launcher_y)
        if self.launcher_pressed_icon then
            self.launcher_pressed_icon:pos(self.launcher_x, self.launcher_y)
        end
        self:_refresh_launcher_visual()
        return
    end

    local path = self:_asset('assets/ui/trust-hat.png')
    self.launcher = self.images.new('', {
        pos = {x=self.launcher_x, y=self.launcher_y},
        size = {width=self.launcher_size, height=self.launcher_size},
        color = copy_color(COLORS.white),
        texture = {path=path, fit=false},
        draggable = false,
        visible = false,
    })
    self.launcher_pressed_icon = self.images.new('', {
        pos = {x=self.launcher_x, y=self.launcher_y},
        size = {width=self.launcher_size, height=self.launcher_size},
        color = copy_color(COLORS.launcher_pressed),
        texture = {path=self:_asset('assets/ui/trust-hat-pressed.png'), fit=false},
        draggable = false,
        visible = false,
    })
    self.launcher:hide()
    self.launcher_pressed_icon:hide()
    -- Give the texture one complete prerender before revealing it. This also
    -- prevents a flash when the addon initially loads with the icon enabled.
    self.launcher_pending_frames = 1
end

function UI:_refresh_launcher_visual()
    if not self.launcher then
        return
    end

    local tint = self.launcher_hovered and COLORS.launcher_hover or COLORS.white
    self.launcher:color(tint.r, tint.g, tint.b)
    self.launcher:alpha(255)
    if self.launcher_pressed_icon then
        self.launcher_pressed_icon:color(
            COLORS.launcher_pressed.r,
            COLORS.launcher_pressed.g,
            COLORS.launcher_pressed.b)
        self.launcher_pressed_icon:alpha(255)
    end

    local can_show = self.icon_enabled
        and not (self.visible and self.mode == 'compact')
        and self.launcher_pending_frames <= 0
    if not can_show then
        self.launcher:hide()
        if self.launcher_pressed_icon then
            self.launcher_pressed_icon:hide()
        end
    elseif self.launcher_pressed and self.launcher_pressed_icon then
        self.launcher:hide()
        self.launcher_pressed_icon:show()
    else
        if self.launcher_pressed_icon then
            self.launcher_pressed_icon:hide()
        end
        self.launcher:show()
    end
end

function UI:_set_launcher_pressed(pressed)
    self.launcher_pressed = pressed == true
    self:_refresh_launcher_visual()
end

function UI:_set_launcher_hovered(hovered)
    self.launcher_hovered = hovered == true
    self:_refresh_launcher_visual()
end

function UI:_tick_launcher()
    if not self.launcher or not self.icon_enabled
        or (self.visible and self.mode == 'compact')
        or self.launcher_pending_frames <= 0 then
        return
    end
    self.launcher_pending_frames = self.launcher_pending_frames - 1
    if self.launcher_pending_frames == 0 then
        self:_refresh_launcher_visual()
    end
end

function UI:_build_icon_representatives()
    self.icon_representatives = {}
    if self.spell_icon_path == '' then
        return
    end
    for _, entry in ipairs(self.state.catalog or {}) do
        local path = self.spell_icon_path .. ('%05d.png'):format(entry.id)
        if entry.icon_id and entry.id ~= 945 and not self.icon_representatives[entry.icon_id]
            and self:_exists(path) then
            self.icon_representatives[entry.icon_id] = path
        end
    end
end

function UI:_icon_path(entry)
    if not entry or self.spell_icon_path == '' then
        return nil
    end
    local exact = self.spell_icon_path .. ('%05d.png'):format(entry.id)
    if entry.id ~= 945 and self:_exists(exact) then
        return exact
    end
    return entry.icon_id and self.icon_representatives[entry.icon_id] or nil
end

function UI:_card_path(entry)
    if not entry or not entry.card then
        return nil
    end
    local relative = normalize_path(entry.card)
    local path = self:_asset(relative)
    return self:_exists(path) and path or nil
end

function UI:_compact_headshot_path(entry)
    if not entry or not entry.card then
        return nil
    end
    local relative = normalize_path(entry.card)
        :gsub('assets/cards/', 'assets/compact_headshots/')
    local path = self:_asset(relative)
    return self:_exists(path) and path or nil
end

function UI:_compact_cooldown_label(count, available_width)
    local full_label = count == 1 and '1 COOLDOWN'
        or ('%d COOLDOWNS'):format(count)
    local pixel_size = math.max(6, self:_s(8))
    local available_pixels = math.max(1, self:_s(available_width))
    local safety_pixels = 2
    if estimated_text_width(full_label, pixel_size, 'Arial', true)
            + safety_pixels <= available_pixels then
        return full_label
    end
    return ('%d CD'):format(count)
end

function UI:_entry_primitive_key(entry)
    return tostring(entry and (entry.id or entry.en) or 'unknown')
end

function UI:_active_record_primitive_key(record, index)
    if record and record.trust then
        return self:_entry_primitive_key(record.trust)
    end
    return table.concat({
        'unresolved',
        tostring(record and (record.model or record.identity_key or record.name) or 'trust'),
        tostring(index or (record and record.slot) or 0),
    }, ':')
end

function UI:_pending_map()
    local map = {}
    for index, entry in ipairs(self.state:pending_entries()) do
        map[entry.id] = index
    end
    return map
end

function UI:_pending_identity(entry)
    if not entry then return nil end
    if self.state.is_identity_pending then
        local pending, selected = self.state:is_identity_pending(entry)
        return pending and selected or nil
    end
    for _, selected in ipairs(self.state:pending_entries()) do
        if selected.identity_key == entry.identity_key then
            return selected
        end
    end
    return nil
end

function UI:_alternate_locked(entry, pending)
    return (entry.in_party and not entry.active_exact)
        or (not pending[entry.id] and self:_pending_identity(entry) ~= nil)
end

function UI:_dismissal_map()
    local map = {}
    for _, record in ipairs(self.state:pending_dismissal_records()) do
        map[record.identity_key] = true
    end
    return map
end

function UI:_status_bucket(entry, pending, dismissals)
    if pending[entry.id] then return 1 end
    if self:_pending_identity(entry) then return 2 end
    if entry.active_exact and dismissals[entry.identity_key] then return 3 end
    if entry.in_party then return 4 end
    if entry.recast_raw == nil then return 5 end
    if entry.recast_raw > 0 then return 6 end
    return 7
end

function UI:_status_less(left, right, pending, dismissals)
    local left_bucket = self:_status_bucket(left, pending, dismissals)
    local right_bucket = self:_status_bucket(right, pending, dismissals)
    if left_bucket ~= right_bucket then
        return left_bucket < right_bucket
    end
    return self:_name_less(left, right)
end

function UI:_name_less(left, right)
    local left_name = lower(left and left.en)
    local right_name = lower(right and right.en)
    if left_name ~= right_name then
        return left_name < right_name
    end
    return (tonumber(left and left.id) or math.huge)
        < (tonumber(right and right.id) or math.huge)
end

function UI:_role_less(left, right)
    local left_label = ROLE_LIST[role_key(left)]
    local right_label = ROLE_LIST[role_key(right)]
    if left_label ~= right_label then
        if left_label == nil then return false end
        if right_label == nil then return true end
        return left_label < right_label
    end
    return self:_name_less(left, right)
end

function UI:_affiliation_less(left, right)
    local left_label = affiliation_label(left)
    local right_label = affiliation_label(right)
    if left_label ~= right_label then
        if left_label == nil then return false end
        if right_label == nil then return true end
        return left_label < right_label
    end
    local left_role = ROLE_LIST[role_key(left)]
    local right_role = ROLE_LIST[role_key(right)]
    if left_role ~= right_role then
        if left_role == nil then return false end
        if right_role == nil then return true end
        return left_role < right_role
    end
    return self:_name_less(left, right)
end

function UI:_sort_less(left, right, pending, dismissals)
    local sort = SORTS[self.sort_index] and SORTS[self.sort_index].key or 'status'
    if sort == 'name' then
        return self:_name_less(left, right)
    elseif sort == 'role' then
        return self:_role_less(left, right)
    elseif sort == 'affiliation' then
        return self:_affiliation_less(left, right)
    end
    return self:_status_less(left, right, pending, dismissals)
end

function UI:_roster_descriptor(entry)
    local sort = SORTS[self.sort_index] and SORTS[self.sort_index].key or 'status'
    if sort == 'affiliation' then
        -- Spell-icon color uses the game's broader association/era taxonomy,
        -- which does not consistently match the official-card affiliation.
        -- Show the explicit affiliation while this grouping is active and
        -- leave unclassified entries blank rather than inventing a category.
        return affiliation_label(entry) or ''
    end
    return ROLE_LIST[role_key(entry)] or 'OTHER'
end

function UI:_capture_planning_order()
    if self.planning_order then return end
    local pending = self:_pending_map()
    local dismissals = self:_dismissal_map()
    local roster = {}
    for _, entry in ipairs(self.state:roster('all')) do
        roster[#roster + 1] = entry
    end
    table.sort(roster, function(left, right)
        return self:_sort_less(left, right, pending, dismissals)
    end)
    self.planning_order = {}
    for index, entry in ipairs(roster) do
        self.planning_order[entry.id] = index
    end
end

function UI:_has_pending_changes()
    return #self.state:pending_entries() > 0
        or #self.state:pending_dismissal_records() > 0
end

function UI:_release_planning_order_if_complete()
    local queue = self.queue and self.queue:snapshot() or {active=false}
    if not queue.active and not self:_has_pending_changes() then
        self.planning_order = nil
    end
end

function UI:_filtered_roster()
    local filter = FILTERS[self.filter_index].key
    local query = lower(self.search)
    local pending = self:_pending_map()
    local roster = {}
    for _, entry in ipairs(self.state:roster('all')) do
        local role_matches = filter == 'all' or role_key(entry) == filter
        local name_matches = query == '' or lower(entry.en):find(query, 1, true) ~= nil
        if role_matches and name_matches then
            roster[#roster + 1] = entry
        end
    end

    local dismissals = self:_dismissal_map()
    table.sort(roster, function(left, right)
        if self.planning_order then
            local left_position = self.planning_order[left.id] or math.huge
            local right_position = self.planning_order[right.id] or math.huge
            if left_position ~= right_position then
                return left_position < right_position
            end
        end
        return self:_sort_less(left, right, pending, dismissals)
    end)
    return roster, pending
end

function UI:_entry_status(entry, pending)
    local pending_position = pending[entry.id]
    if pending_position then
        -- Summon order is communicated by the previews' left-to-right order.
        -- Keeping both the roster status and preview footer unnumbered avoids
        -- suggesting that the value is an eventual party position or level.
        return 'SUMMON', COLORS.cyan
    elseif self:_pending_identity(entry) then
        return 'TRUST IN USE', COLORS.muted
    elseif entry.active_exact and self.state:is_pending_dismissal(entry) then
        return 'DISMISS', COLORS.red
    elseif entry.in_party and not entry.active_exact then
        return 'TRUST IN USE', COLORS.muted
    elseif entry.in_party then
        return 'IN PARTY', COLORS.blue
    elseif entry.recast_raw == nil then
        return 'UNAVAILABLE', COLORS.muted
    elseif entry.recast_raw > 0 then
        -- Exact recast values change continuously. A stable state label avoids
        -- rebuilding the entire primitive tree just to update a countdown.
        return 'COOLDOWN', COLORS.red
    end
    return 'READY', COLORS.green
end

function UI:_is_action_target(entry)
    local queue = self.queue and self.queue:snapshot() or nil
    if not queue or not queue.active or queue.status == 'retry_wait' or not entry then
        return false
    end
    local candidate = entry.trust or entry
    local candidate_id = candidate.id or entry.id
    local identity_key = entry.identity_key or candidate.identity_key
    local name = candidate.en or entry.name
    return (queue.current_id ~= nil and queue.current_id == candidate_id)
        or (queue.current_identity_key ~= nil
            and queue.current_identity_key == identity_key)
        or (queue.current_name ~= nil and queue.current_name == name)
end

function UI:_queue_notice(queue)
    if queue.active and queue.status == 'next_dismissal_wait' then
        local seconds = math.max(1, math.ceil(
            math.max(0, tonumber(queue.handoff_remaining) or 0)))
        return ('PREPARING NEXT DISMISSAL - %ds'):format(seconds),
            COLORS.status_neutral, false, false
    end

    if queue.active and queue.phase == 'dismissing' then
        return ('DISMISSING %s - %d/%d'):format(
            tostring(queue.current_name or 'TRUST'):upper(),
            tonumber(queue.position) or 0,
            tonumber(queue.total) or 0), COLORS.status_neutral, false, false
    end

    local retrying = queue.active and queue.status == 'retry_wait'
    local stopped = not queue.active and queue.status == 'stopped'
    if retrying then
        local remaining = math.max(0, tonumber(queue.retry_remaining) or 0)
        local seconds = math.max(1, math.ceil(remaining))
        local label = queue.block_cause == 'movement'
            and ('MOVEMENT DETECTED - RETRYING IN %ds'):format(seconds)
            or (queue.reason == 'cast_temporarily_blocked'
                and ('PREVIOUS SUMMON STILL SETTLING - RETRYING IN %ds'):format(seconds)
                or ('SUMMON INTERRUPTED - RETRYING IN %ds'):format(seconds))
        return label, COLORS.retry, true, true
    end

    if queue.active and queue.status == 'next_summon_wait' then
        local seconds = math.max(1, math.ceil(
            math.max(0, tonumber(queue.handoff_remaining) or 0)))
        return ('PREPARING NEXT TRUST - %ds'):format(seconds),
            COLORS.status_neutral, false, false
    end

    if queue.active and queue.status == 'awaiting_action' then
        local remaining = tonumber(queue.action_remaining)
        local timeout = tonumber(queue.action_timeout) or 10
        local elapsed = remaining and math.max(0, timeout - remaining) or 0
        if remaining and elapsed >= 3 then
            return ('WAITING FOR SUMMONING TO BEGIN: %s - %ds'):format(
                tostring(queue.current_name or 'TRUST'):upper(),
                math.max(1, math.ceil(remaining))), COLORS.retry, true, true
        else
            return ('SUMMONING %s - ATTEMPT %d/%d'):format(
                tostring(queue.current_name or 'TRUST'):upper(),
                tonumber(queue.attempt) or 0,
                tonumber(queue.max_attempts) or 0), COLORS.status_neutral, false, false
        end
    end

    if queue.active and queue.status == 'awaiting_party' then
        local remaining = math.max(0, tonumber(queue.confirm_remaining) or 0)
        local timeout = tonumber(queue.confirm_timeout) or 5
        local delayed = math.max(0, timeout - remaining) >= 2
        local format = queue.reason == 'missed_action'
            and 'CHECKING IF %s JOINED PARTY - %ds'
            or 'VERIFYING %s JOINED PARTY - %ds'
        return format:format(
            tostring(queue.current_name or 'TRUST'):upper(),
            math.max(1, math.ceil(remaining))),
            delayed and COLORS.retry or COLORS.status_neutral, delayed, delayed
    end

    if stopped then
        local operation = queue.phase == 'dismissing'
            and 'DISMISSAL' or 'SUMMONING'
        local trust_name = tostring(queue.last_trust_name
            or queue.current_name or 'TRUST'):upper()
        local reason_label = tostring(queue.reason or 'UNKNOWN')
            :upper():gsub('_', ' ')
        local label
        if queue.reason == 'party_full' then
            label = 'PARTY CAPACITY CHANGED - REVIEW SELECTIONS'
        elseif queue.reason == 'action_timeout' then
            label = ('SUMMONING %s DID NOT BEGIN - TRY AGAIN'):format(trust_name)
        elseif queue.reason == 'party_unconfirmed' then
            label = ('SUMMONING %s FINISHED - PARTY JOIN NOT VERIFIED'):format(
                trust_name)
        elseif queue.reason == 'dismissal_unconfirmed' then
            label = ('DISMISSAL NOT VERIFIED FOR %s - TRY AGAIN'):format(trust_name)
        elseif queue.reason == 'dismiss_input_failed' then
            label = ('COULD NOT REQUEST DISMISSAL FOR %s - TRY AGAIN'):format(
                trust_name)
        elseif queue.reason == 'interrupted' then
            label = ('SUMMONING %s WAS INTERRUPTED - TRY AGAIN'):format(trust_name)
        elseif queue.reason == 'zone_restricted' then
            label = 'TRUSTS CANNOT BE SUMMONED IN THIS AREA'
        elseif queue.reason == 'trust_unavailable' then
            label = 'TRUST SUMMONING IS NOT AVAILABLE NOW'
        elseif queue.reason == 'cast_input_failed' then
            label = ('COULD NOT REQUEST SUMMONING %s - TRY AGAIN'):format(
                trust_name)
        elseif queue.reason == 'cast_temporarily_blocked'
                and queue.block_cause == 'movement' then
            label = operation .. ' STOPPED - TRY AGAIN WHEN STATIONARY'
        elseif queue.reason == 'cast_temporarily_blocked' then
            label = operation .. ' STOPPED - TRY AGAIN IN A MOMENT'
        elseif queue.reason == 'internal_error' then
            label = operation .. ' STOPPED - SEE DATA/QUEUE.LOG'
        else
            label = operation .. ' STOPPED - ' .. reason_label
        end
        return label, COLORS.status_error, false, true
    end

    return nil
end

-- Windower text has a practical six-pixel floor. At the minimum UI scale the
-- compact status region therefore uses shorter, state-equivalent wording
-- rather than allowing a full phrase to cross its fixed dividers.
function UI:_compact_queue_notice(queue)
    local label, color, blinking, bold = self:_queue_notice(queue)
    if self.scale > 0.70 or not label then
        return label, color, blinking, bold
    end

    local name = tostring(queue.current_name or 'TRUST'):upper()
    local position = tonumber(queue.position) or 0
    local total = tonumber(queue.total) or 0
    if queue.active and queue.status == 'next_dismissal_wait' then
        local seconds = math.max(1, math.ceil(
            math.max(0, tonumber(queue.handoff_remaining) or 0)))
        label = ('NEXT DISMISSAL - %ds'):format(seconds)
    elseif queue.active and queue.phase == 'dismissing' then
        label = ('DISMISS %s - %d/%d'):format(name, position, total)
    elseif queue.active and queue.status == 'retry_wait' then
        local seconds = math.max(1, math.ceil(
            math.max(0, tonumber(queue.retry_remaining) or 0)))
        if queue.block_cause == 'movement' then
            label = ('MOVEMENT - RETRY %ds'):format(seconds)
        elseif queue.reason == 'cast_temporarily_blocked' then
            label = ('WAITING - RETRY %ds'):format(seconds)
        else
            label = ('INTERRUPTED - RETRY %ds'):format(seconds)
        end
    elseif queue.active and queue.status == 'next_summon_wait' then
        local seconds = math.max(1, math.ceil(
            math.max(0, tonumber(queue.handoff_remaining) or 0)))
        label = ('NEXT SUMMON - %ds'):format(seconds)
    elseif queue.active and queue.status == 'awaiting_action' then
        local remaining = tonumber(queue.action_remaining)
        local timeout = tonumber(queue.action_timeout) or 10
        local elapsed = remaining and math.max(0, timeout - remaining) or 0
        if remaining and elapsed >= 3 then
            label = ('WAITING TO SUMMON: %s - %ds'):format(
                name, math.max(1, math.ceil(remaining)))
        else
            label = ('SUMMON %s - %d/%d'):format(
                name,
                tonumber(queue.attempt) or 0,
                tonumber(queue.max_attempts) or 0)
        end
    elseif queue.active and queue.status == 'awaiting_party' then
        label = ('PARTY CHECK: %s - %ds'):format(name,
            math.max(1, math.ceil(
                math.max(0, tonumber(queue.confirm_remaining) or 0))))
    elseif not queue.active and queue.status == 'stopped' then
        local operation = queue.phase == 'dismissing'
            and 'DISMISSAL STOPPED' or 'STOPPED'
        if queue.reason == 'party_full' then
            label = 'PARTY CAPACITY CHANGED'
        elseif queue.reason == 'action_timeout' then
            label = ('SUMMON FAILED: %s'):format(
                tostring(queue.last_trust_name or name):upper())
        elseif queue.reason == 'party_unconfirmed' then
            label = ('JOIN NOT VERIFIED: %s'):format(
                tostring(queue.last_trust_name or name):upper())
        elseif queue.reason == 'dismissal_unconfirmed' then
            label = ('DISMISS NOT VERIFIED: %s'):format(
                tostring(queue.last_trust_name or name):upper())
        elseif queue.reason == 'dismiss_input_failed' then
            label = ('DISMISS FAILED: %s'):format(
                tostring(queue.last_trust_name or name):upper())
        elseif queue.reason == 'cast_temporarily_blocked'
            and queue.block_cause == 'movement' then
            label = operation == 'DISMISSAL STOPPED'
                and 'DISMISSAL STOPPED - CHECK CHAT'
                or 'STOPPED - RETRY WHEN STATIONARY'
        elseif queue.reason == 'cast_temporarily_blocked' then
            label = operation == 'DISMISSAL STOPPED'
                and 'DISMISSAL STOPPED - CHECK CHAT'
                or 'STOPPED - RETRY IN A MOMENT'
        elseif queue.reason == 'internal_error' then
            label = operation .. ' - SEE QUEUE.LOG'
        else
            label = operation .. ' - '
                .. tostring(queue.reason or 'UNKNOWN'):upper():gsub('_', ' ')
        end
    end
    return label, color, blinking, bold
end

function UI:_render_notice(label, color, blinking, bold, x, y, width, height,
        primitive_kind, horizontal_padding, minimum_size, left_aligned,
        highlighted_name)
    local alpha = color.a or 255
    if blinking then
        local wave = (math.sin(self.clock() * math.pi * 2 * 1.6) + 1) * 0.5
        alpha = math.floor(155 + wave * 100 + 0.5)
    end
    local rendered_color = {r=color.r, g=color.g, b=color.b, a=alpha}
    local name = highlighted_name
        and tostring(highlighted_name):upper() or ''
    local start_index = name ~= '' and label:find(name, 1, true) or nil
    if start_index then
        local prefix = label:sub(1, start_index - 1)
        local suffix = label:sub(start_index + #name)
        local pixel_size = math.max(6, self:_s(11))
        local padding = self:_s(tonumber(horizontal_padding)
            or (left_aligned and 0 or 8))
        local available_width = math.max(1, self:_s(width) - padding * 2)
        local prefix_width = estimated_text_width(
            prefix, pixel_size, 'Arial', bold == true)
        local name_width = estimated_text_width(
            name, pixel_size, 'Arial', true)
        local suffix_width = estimated_text_width(
            suffix, pixel_size, 'Arial', bold == true)
        -- Font strokes make ordinary spaces between separately rendered runs
        -- appear much tighter than spaces inside one text primitive. Reserve
        -- a small physical gutter on both sides of the highlighted name.
        local name_gap = math.max(2, self:_s(3))
        local total_width = prefix_width + name_gap + name_width
            + name_gap + suffix_width
        if total_width > available_width then
            local minimum_pixels = math.max(6,
                self:_s(tonumber(minimum_size) or 7))
            local fitted_size = math.max(minimum_pixels,
                math.floor(pixel_size * available_width / total_width))
            if fitted_size < pixel_size then
                local ratio = fitted_size / pixel_size
                pixel_size = fitted_size
                prefix_width = prefix_width * ratio
                name_width = name_width * ratio
                suffix_width = suffix_width * ratio
                total_width = prefix_width + name_gap + name_width
                    + name_gap + suffix_width
            end
        end

        local run_x = left_aligned
            and (self:_s(x) + padding)
            or (self:_s(x) + (self:_s(width) - total_width) / 2)
        local _, text_height = self:_measure_text('', pixel_size, 'Arial', false)
        local run_y = self:_s(y) + (self:_s(height) - text_height) / 2
        local kind = primitive_kind or 'footer_queue_notice'
        local name_color = {
            r=COLORS.status_name.r,
            g=COLORS.status_name.g,
            b=COLORS.status_name.b,
            a=alpha,
        }

        local function add_run(value, run_color, run_bold, run_kind, offset)
            if value == '' then return nil end
            local object = self:_add_text(value, 0, 0,
                pixel_size / self.scale, run_color, 'Arial', run_bold,
                nil, run_kind, nil, 6)
            pcall(function() object:size(pixel_size) end)
            object:pos(self:_origin_x() + run_x + offset,
                self:_origin_y() + run_y)
            local record = self.objects[#self.objects]
            record.x = run_x + offset
            record.y = run_y
            record.font_size = pixel_size
            return record
        end

        local prefix_record = add_run(prefix, rendered_color, bold == true,
            kind, 0)
        -- Preserve the complete semantic value on the first status record for
        -- diagnostics while its underlying primitive contains only the prefix.
        if prefix_record then
            prefix_record.segment_value = prefix
            prefix_record.value = label
        end
        local name_record = add_run(name, name_color, true,
            'status_name_highlight', prefix_width + name_gap)
        if name_record then
            name_record.segment_gap_px = name_gap
        end
        add_run(suffix, rendered_color, bold == true,
            kind, prefix_width + name_gap + name_width + name_gap)
        return
    end

    if left_aligned then
        self:_add_left_fitted_text(label, x, y, width, height,
            11, rendered_color, 'Arial', bold == true,
            horizontal_padding or 0, minimum_size or 7, nil,
            primitive_kind or 'footer_queue_notice')
    else
        self:_add_centered_text(label, x, y, width, height,
            11, rendered_color, 'Arial', bold == true,
            horizontal_padding or 8, minimum_size or 7, nil, 0,
            primitive_kind or 'footer_queue_notice')
    end
end

function UI:_render_footer_notice(queue, fallback_status)
    local label, color, blinking, bold = self:_queue_notice(queue)
    local ui_warning_label, ui_warning_color = self:_ui_warning_notice()
    local stopped = not queue.active and queue.status == 'stopped'
    local preset_warning_active = self:_render_preset_warning(
        self.selected_preset_summary,
        queue.active or stopped or ui_warning_label ~= nil)

    if label then
        self:_render_notice(label, color, blinking, bold,
            FOOTER_NOTICE_X, FOOTER_NOTICE_Y,
            FOOTER_NOTICE_WIDTH, FOOTER_NOTICE_HEIGHT,
            'footer_queue_notice', 0, 7, true,
            queue.current_name or queue.last_trust_name)
        return
    end

    if ui_warning_label then
        self:_render_notice(ui_warning_label, ui_warning_color,
            false, true, FOOTER_NOTICE_X, FOOTER_NOTICE_Y,
            FOOTER_NOTICE_WIDTH, FOOTER_NOTICE_HEIGHT,
            'footer_ui_warning', 0, 7, true)
        return
    end

    if preset_warning_active then
        return
    end

    if fallback_status then
        self:_add_left_fitted_text(fallback_status,
            FOOTER_NOTICE_X, FOOTER_NOTICE_Y,
            FOOTER_NOTICE_WIDTH, FOOTER_NOTICE_HEIGHT,
            11, COLORS.muted, 'Arial', false, 0, 7, nil,
            'footer_status')
    end
end

function UI:_render_primary_ready_pulse(x, y, width, height, enabled, action_kind)
    local was_enabled = self.primary_action_enabled == true
    local kind_changed = enabled and was_enabled
        and self.primary_action_kind ~= action_kind
    if enabled and (not was_enabled or kind_changed) then
        self.primary_ready_pulse_started = self.clock()
    elseif not enabled then
        self.primary_ready_pulse_started = nil
    end
    self.primary_action_enabled = enabled == true
    self.primary_action_kind = enabled and action_kind or nil

    local alpha = 0
    local started = self.primary_ready_pulse_started
    if enabled and started then
        local elapsed = math.max(0, self.clock() - started)
        if elapsed >= PRIMARY_READY_PULSE_DURATION then
            self.primary_ready_pulse_started = nil
        else
            local envelope = 1 - elapsed / PRIMARY_READY_PULSE_DURATION
            local wave = (math.sin(elapsed * math.pi * 2 * 1.7) + 1) * 0.5
            alpha = math.floor((28 + wave * 92) * envelope + 0.5)
        end
    end

    -- This layer is submitted before the primary button on every frame so it
    -- reads as a short outer readiness glow rather than tinting the label.
    self:_add_mask(PRIMARY_ACTION_MASK, x - 3, y - 3,
        width + 6, height + 6, COLORS.cyan, alpha,
        'primary_ready_pulse', 'outer')
    if self.performance_frame and alpha > 0 then
        self.performance_frame.primary_pulse = true
    end
end

function UI:_render_primary_action(x, y, width, height)
    local track_primary = self.performance_diagnostics
    local pending_count = #self.state:pending_entries()
    local dismissal_count = #self.state:pending_dismissal_records()
    local queue = self.queue and self.queue:snapshot()
        or {active=false, status='idle'}
    local plan_enabled = pending_count > 0 or dismissal_count > 0
    -- The normal action and CANCEL use separate resident primitive pools at
    -- the same coordinates. Force-hide every non-current surface before
    -- drawing so a stale disabled palette cannot sit above a clickable,
    -- enabled APPLY or CANCEL button after a state transition.
    local desired_surface = queue.active
        and 'queue_cancel_button_enabled_rect'
        or (plan_enabled and 'queue_action_button_enabled_rect'
            or 'queue_action_button_disabled_rect')
    local surface_changed = self.primary_surface_kind ~= desired_surface
    local hide_started = track_primary and self.clock() or nil
    for _, kind in ipairs({
        'queue_action_button_enabled_rect',
        'queue_action_button_disabled_rect',
        'queue_cancel_button_enabled_rect',
        'queue_cancel_button_disabled_rect',
    }) do
        if kind ~= desired_surface then
            for _, record in ipairs(self.object_pool[kind] or {}) do
                -- On a logical transition, issue the hide even when our
                -- bookkeeping already says hidden. Windower can retain an
                -- older mask above the newly enabled, clickable palette.
                if surface_changed or record.visible then
                    pcall(function() record.object:hide() end)
                    record.visible = false
                end
            end
        end
    end
    self:_performance_stage_add('footer-primary-hide', hide_started)
    self.primary_surface_kind = desired_surface
    local action_kind = pending_count > 0 and dismissal_count > 0 and 'apply'
        or (dismissal_count > 0 and 'dismiss' or 'summon')
    local pulse_started = track_primary and self.clock() or nil
    self:_render_primary_ready_pulse(
        x, y, width, height, plan_enabled and not queue.active, action_kind)
    self:_performance_stage_add('footer-primary-pulse', pulse_started)
    if queue.active then
        local button_started = track_primary and self.clock() or nil
        self:_button('CANCEL', x, y, width, height, function()
            self.commands:handle({'cancel'})
            self.execution_party_rows = nil
            self:render(true)
        end, true, 'queue_cancel_button')
        self:_performance_stage_add('footer-primary-button', button_started)
        return
    end

    local action_label = 'SUMMON'
    if dismissal_count > 0 and pending_count > 0 then
        action_label = ('APPLY (-%d / +%d)'):format(
            dismissal_count, pending_count)
    elseif dismissal_count > 0 then
        action_label = ('DISMISS (%d)'):format(dismissal_count)
    elseif pending_count > 0 then
        action_label = ('SUMMON (%d)'):format(pending_count)
    end
    local button_started = track_primary and self.clock() or nil
    self:_button(action_label, x, y, width, height, function()
        -- Pressing the compact action commits its preset plan. Do not restore
        -- an older expanded draft after execution has been requested.
        if self.mode == 'compact' then
            self.expanded_plan_draft = nil
        end
        self:_capture_execution_party_rows()
        self.commands:handle({'summon'})
        local started = self.queue and self.queue:snapshot().active
        if not started then
            self.execution_party_rows = nil
        end
        self:render(true)
        end, plan_enabled, 'queue_action_button')
    self:_performance_stage_add('footer-primary-button', button_started)
end

function UI:_action_progress()
    local queue = self.queue and self.queue:snapshot() or nil
    local key = queue and queue.active and table.concat({
        tostring(queue.phase or ''),
        tostring(queue.current_id or ''),
        tostring(queue.current_identity_key or ''),
        tostring(queue.current_name or ''),
    }, ':') or nil
    if key ~= self.action_progress_key then
        self.action_progress_key = key
        self.action_progress_started = self.clock()
    end
    if not key then
        return nil, 0
    end
    -- Keep the strip deliberately estimated: a cast can be interrupted and a
    -- dismissal completes only after the party confirms the departure.
    local duration = queue.phase == 'dismissing' and 2 or 3
    local progress = (self.clock() - self.action_progress_started) / duration
    return queue, math.min(0.9, math.max(0, progress * 0.9))
end

function UI:_action_strip_fraction(entry, queue, progress)
    if not self:_is_action_target(entry) then
        return 0
    end
    return queue.phase == 'dismissing' and (1 - progress) or progress
end

function UI:_action_fade_target(entry, is_pending)
    local queue = self.queue and self.queue:snapshot() or nil
    if not queue or not queue.active or not self:_is_action_target(entry) then
        return false
    end
    return (is_pending and queue.phase == 'summoning')
        or (not is_pending and queue.phase == 'dismissing')
end

function UI:_action_pulse_alpha()
    local queue = self.queue and self.queue:snapshot() or nil
    if not queue or not queue.active then
        return 0
    end
    local wave = (math.sin(self.clock() * math.pi * 2 * 1.25) + 1) * 0.5
    return math.floor(20 + wave * 58 + 0.5)
end

function UI:_render_perimeter_comet(x, y, width, height, primitive_key, color,
        primitive_kind, speed)
    if self.performance_frame then
        self.performance_frame.comet = true
    end
    local perimeter = 2 * (width + height)
    local phase = (self.clock() * (speed or SUMMON_COMET_SPEED)) % perimeter
    local thickness = 2
    local halo_thickness = 5
    local segment_length = math.min(SUMMON_COMET_SEGMENT_LENGTH,
        math.max(2, math.floor(perimeter / (SUMMON_COMET_SEGMENTS * 2))))
    local alpha_by_segment = {28, 43, 64, 91, 128, 178, 245}

    local function add_piece(comet_index, segment_index, piece_index,
            position, length, alpha, piece_thickness, layer)
        local px, py, piece_width, piece_height
        if position < width then
            px, py = x + position, y
            piece_width, piece_height = length, piece_thickness
        elseif position < width + height then
            px, py = x + width - piece_thickness, y + position - width
            piece_width, piece_height = piece_thickness, length
        elseif position < 2 * width + height then
            local bottom_position = position - width - height
            px, py = x + width - bottom_position - length,
                y + height - piece_thickness
            piece_width, piece_height = length, piece_thickness
        else
            local left_position = position - 2 * width - height
            px, py = x, y + height - left_position - length
            piece_width, piece_height = piece_thickness, length
        end
        self:_add_rect(px, py, math.max(1, piece_width),
            math.max(1, piece_height), color, alpha, primitive_kind,
            ('%s:%s:%d:%d'):format(tostring(primitive_key), layer,
                comet_index, segment_index * 2 + piece_index))
    end

    local function add_layered_piece(comet_index, segment_index, piece_index,
            position, length, alpha)
        -- The wider, dimmer halo makes the effect readable at small UI scales;
        -- the bright core remains the same width as the normal border.
        add_piece(comet_index, segment_index, piece_index, position, length,
            math.floor(alpha * 0.28 + 0.5), halo_thickness, 'halo')
        add_piece(comet_index, segment_index, piece_index, position, length,
            alpha, thickness, 'core')
    end

    local function add_segment(comet_index, segment_index, head_position)
        local start = (head_position
            - (SUMMON_COMET_SEGMENTS - segment_index) * segment_length) % perimeter
        local remaining = segment_length
        local position = start
        local piece_index = 1
        while remaining > 0.01 and piece_index <= 2 do
            local side_end
            if position < width then
                side_end = width
            elseif position < width + height then
                side_end = width + height
            elseif position < 2 * width + height then
                side_end = 2 * width + height
            else
                side_end = perimeter
            end
            local length = math.min(remaining, side_end - position)
            add_layered_piece(comet_index, segment_index, piece_index, position,
                length, alpha_by_segment[segment_index])
            remaining = remaining - length
            position = (position + length) % perimeter
            piece_index = piece_index + 1
        end
        -- Most segments fit on one side. Reserve a second keyed piece so a
        -- corner crossing can be drawn without changing primitive depth.
        if piece_index == 2 then
            add_layered_piece(comet_index, segment_index, piece_index, 0, 1, 0)
        end
    end

    for comet_index, offset in ipairs({0, perimeter * 0.5}) do
        local head_position = (phase + offset) % perimeter
        for segment_index = 1, SUMMON_COMET_SEGMENTS do
            add_segment(comet_index, segment_index, head_position)
        end
    end
end

function UI:_render_action_pulse(entry, x, y, width, height, primitive_key,
        pool_prefix, is_pending, primary)
    local queue = self.queue and self.queue:snapshot() or nil
    local target = self:_is_action_target(entry)
    local dismiss_target = target and not is_pending
        and queue and queue.phase == 'dismissing'
    local alpha = self:_action_pulse_alpha()
    if not dismiss_target or alpha <= 0 then
        return
    end
    if self.performance_frame then
        self.performance_frame.action_pulse_masks =
            (self.performance_frame.action_pulse_masks or 0) + 3
    end
    if self.performance_frame and alpha > 0 then
        self.performance_frame.visible_action_pulse = true
    end
    local mask_path = is_pending and 'assets/ui/preview-card-inner-rounded-mask.png'
        or 'assets/ui/active-card-inner-rounded-mask.png'
    self:_add_mask(mask_path,
        x, y, width, height, primary,
        0, pool_prefix .. '_saturation', primitive_key)
    self:_add_mask(mask_path,
        x, y, width, height, COLORS.shell,
        alpha, pool_prefix .. '_dark', primitive_key)
    self:_add_mask(mask_path,
        x, y, width, height, COLORS.dim,
        math.floor(alpha * 0.35 + 0.5),
        pool_prefix .. '_desaturate', primitive_key)
end

function UI:_render_action_fade(entry, x, y, width, height, primitive_key,
        pool_prefix, is_pending)
    local queue, progress = self:_action_progress()
    local target = self:_action_fade_target(entry, is_pending)
    local band_height = math.min(52, height - 4)
    local direction = queue and queue.phase == 'dismissing' and 'down' or 'up'
    local band_y = y
    if target then
        local travel = height - band_height
        band_y = direction == 'down'
            and y + travel * progress
            or y + travel * (1 - progress)
    end
    local fade_path = direction == 'down'
        and 'assets/ui/action-fade-down.png'
        or 'assets/ui/action-fade-up.png'
    local fade_color = direction == 'down' and COLORS.shell or COLORS.white
    self:_add_image(self:_asset(fade_path), x, band_y, width, band_height,
        fade_color, target and (direction == 'down' and 125 or 165) or 0,
        pool_prefix, primitive_key)
end

function UI:_render_action_strip(entry, x, y, width, height, primitive_key,
        pool_prefix)
    local queue, progress = self:_action_progress()
    local target = self:_is_action_target(entry)
    local color = queue and queue.phase == 'dismissing' and COLORS.red or COLORS.gold
    local alpha = target and 220 or 0
    local fraction = self:_action_strip_fraction(entry, queue, progress)
    local leading_width = math.max(1, math.floor(width * fraction + 0.5))
    local head_width = math.min(24, leading_width)
    local body_width = math.max(1, leading_width - head_width)
    local head_x = x + leading_width - head_width
    local track_color = target and color or COLORS.white
    self:_add_rect(x, y, width, height, track_color, target and 72 or 0,
        pool_prefix .. '_track', primitive_key)
    self:_add_rect(x, y, body_width, height, color, alpha,
        pool_prefix .. '_fill', primitive_key)
    self:_add_image(self:_asset('assets/ui/action-strip-head.png'),
        head_x, y, head_width, height, color, target and 235 or 0,
        pool_prefix .. '_head', primitive_key)
end

function UI:_select_entry(entry, is_pending)
    local queue_snapshot = self.queue and self.queue:snapshot() or {active=false}
    if queue_snapshot.active then
        self.emit('The summon queue is running; party changes are locked.')
        return
    end
    if is_pending then
        self:_capture_planning_order()
        self.compact_preset_selection_pending = false
        self:_hide_incoming_split_entry(entry)
        local removed = self.state:remove(entry.en)
        if not removed then
            self.commands:handle({'remove', entry.en}, {silent=true})
        end
    elseif self:_pending_identity(entry) then
        self:_show_ui_warning(
            'ANOTHER VERSION OF THIS TRUST IS ALREADY IN USE',
            COLORS.muted)
    elseif entry.active_exact then
        self:_capture_planning_order()
        self.compact_preset_selection_pending = false
        if self.state:is_pending_dismissal(entry) then
            self.commands:handle({'keep', entry.en}, {silent=true})
        else
            self.commands:handle({'dismiss', entry.en}, {silent=true})
        end
    elseif entry.in_party then
        self:_show_ui_warning(
            'ANOTHER VERSION OF THIS TRUST IS ALREADY IN USE',
            COLORS.muted)
    elseif entry.recast_raw == nil then
        self:_show_ui_warning(
            tostring(entry.en or 'TRUST'):upper() .. ': STATUS UNAVAILABLE',
            COLORS.retry)
    elseif entry.recast_raw > 0 then
        local seconds = tonumber(entry.cooldown_seconds)
        if not seconds or seconds <= 0 then
            seconds = tonumber(entry.recast_raw) / 60
        end
        self:_show_ui_warning(('%s: COOLDOWN - %ds'):format(
            tostring(entry.en or 'TRUST'):upper(),
            math.max(1, math.ceil(seconds))),
            COLORS.retry)
    else
        local party_snapshot = self.state:snapshot()
        local ready = entry.learned ~= false
            and entry.recast_raw ~= nil and entry.recast_raw <= 0
        if ready and (tonumber(party_snapshot.remaining_slots) or 0) <= 0 then
            self:_show_ui_warning(
                'PARTY CAPACITY REACHED',
                COLORS.retry,
                'capacity')
        else
            self:_capture_planning_order()
            self.compact_preset_selection_pending = false
            self.commands:handle({'select', entry.en}, {silent=true})
        end
    end
    self:_release_planning_order_if_complete()
    self:render(true)
end

function UI:_render_filter_dropdown()
    if not self.filter_dropdown_open then
        return
    end

    if not self.filter_dropdown_primed then
        -- All possible menu backgrounds must exist below the menu's dedicated
        -- text layer before hover or selection can switch palettes.
        self:_prime_rect_pool('filter_dropdown_frame', 2)
        self:_prime_rect_pool('filter_dropdown_row', #FILTERS)
        self:_prime_rect_pool('filter_dropdown_row_selected', #FILTERS)
        self:_prime_rect_pool('filter_dropdown_row_hovered', #FILTERS)
        self:_prime_rect_pool('filter_dropdown_selection', 1)
        self.filter_dropdown_primed = true
    end

    local x = FILTER_BUTTON_X
    local y = FILTER_MENU_Y
    local width = FILTER_MENU_WIDTH
    local cell_width = (width - FILTER_MENU_PADDING * 2)
        / FILTER_MENU_COLUMNS
    self:_add_rect(x, y, width, FILTER_MENU_HEIGHT,
        COLORS.shell_border, 255, 'filter_dropdown_frame')
    self:_add_rect(x + 2, y + 2, width - 4, FILTER_MENU_HEIGHT - 4,
        COLORS.dropdown_surface, 252, 'filter_dropdown_frame')

    for index, option in ipairs(FILTERS) do
        local row = math.floor((index - 1) / FILTER_MENU_COLUMNS)
        local column = (index - 1) % FILTER_MENU_COLUMNS
        local row_y = y + FILTER_MENU_PADDING
            + row * FILTER_MENU_ROW_HEIGHT
        local cell_x = x + FILTER_MENU_PADDING + column * cell_width
        local hover_key = 'filter_option:' .. tostring(index)
        local selected = index == self.filter_index
        local hovered = self.hover_key == hover_key
        local background = hovered and COLORS.button_hot
            or (selected and COLORS.dropdown_selected or COLORS.dropdown_item)
        self:_add_rect(cell_x, row_y,
            cell_width - 1, FILTER_MENU_ROW_HEIGHT - 1,
            background, 252, hovered and 'filter_dropdown_row_hovered'
                or (selected and 'filter_dropdown_row_selected'
                    or 'filter_dropdown_row'))
        if selected then
            self:_add_rect(cell_x, row_y, 4,
                FILTER_MENU_ROW_HEIGHT - 1, COLORS.cyan, 255,
                'filter_dropdown_selection')
            self:_add_centered_text('>', cell_x + 5, row_y, 13,
                FILTER_MENU_ROW_HEIGHT - 1, 9, COLORS.cyan,
                'Arial', true, 0, 7, nil, 0,
                'filter_dropdown_marker_text', tostring(index))
        end
        self:_add_centered_text(option.label,
            cell_x + 18, row_y, cell_width - 20,
            FILTER_MENU_ROW_HEIGHT - 1, 9,
            selected and COLORS.white
                or (hovered and COLORS.gold_bright or COLORS.muted),
            'Arial', true, 2, 7, nil, 0,
            'filter_dropdown_option_text', tostring(index))

        local captured_index = index
        self:_hitbox(cell_x, row_y,
            cell_width - 1, FILTER_MENU_ROW_HEIGHT - 1,
            function()
                self.filter_index = captured_index
                self.filter_dropdown_open = false
                self.scroll = 0
                self:render(false)
            end, 'filter_option', hover_key)
    end
end

function UI:_render_sort_dropdown()
    if not self.sort_dropdown_open then
        return
    end

    if not self.sort_dropdown_primed then
        self:_prime_rect_pool('sort_dropdown_frame', 2)
        self:_prime_rect_pool('sort_dropdown_row', #SORTS)
        self:_prime_rect_pool('sort_dropdown_row_selected', #SORTS)
        self:_prime_rect_pool('sort_dropdown_row_hovered', #SORTS)
        self:_prime_rect_pool('sort_dropdown_selection', 1)
        self.sort_dropdown_primed = true
    end

    local x = LIST_X
    local y = SORT_MENU_Y
    local width = SORT_MENU_WIDTH
    local cell_width = (width - SORT_MENU_PADDING * 2) / SORT_MENU_COLUMNS
    self:_add_rect(x, y, width, SORT_MENU_HEIGHT,
        COLORS.shell_border, 255, 'sort_dropdown_frame')
    self:_add_rect(x + 2, y + 2, width - 4, SORT_MENU_HEIGHT - 4,
        COLORS.dropdown_surface, 252, 'sort_dropdown_frame')

    for index, option in ipairs(SORTS) do
        local row = math.floor((index - 1) / SORT_MENU_COLUMNS)
        local column = (index - 1) % SORT_MENU_COLUMNS
        local row_y = y + SORT_MENU_PADDING + row * SORT_MENU_ROW_HEIGHT
        local cell_x = x + SORT_MENU_PADDING + column * cell_width
        local hover_key = 'sort_option:' .. tostring(index)
        local selected = index == self.sort_index
        local hovered = self.hover_key == hover_key
        local background = hovered and COLORS.button_hot
            or (selected and COLORS.dropdown_selected or COLORS.dropdown_item)
        self:_add_rect(cell_x, row_y, cell_width - 1,
            SORT_MENU_ROW_HEIGHT - 1, background, 252,
            hovered and 'sort_dropdown_row_hovered'
                or (selected and 'sort_dropdown_row_selected'
                    or 'sort_dropdown_row'))
        if selected then
            self:_add_rect(cell_x, row_y, 4, SORT_MENU_ROW_HEIGHT - 1,
                COLORS.cyan, 255, 'sort_dropdown_selection')
            self:_add_centered_text('>', cell_x + 5, row_y, 13,
                SORT_MENU_ROW_HEIGHT - 1, 9, COLORS.cyan,
                'Arial', true, 0, 7, nil, 0,
                'sort_dropdown_marker_text', tostring(index))
        end
        self:_add_centered_text(option.label,
            cell_x + 18, row_y, cell_width - 20,
            SORT_MENU_ROW_HEIGHT - 1, 9,
            selected and COLORS.white
                or (hovered and COLORS.gold_bright or COLORS.muted),
            'Arial', true, 2, 7, nil, 0,
            'sort_dropdown_option_text', tostring(index))

        local captured_index = index
        self:_hitbox(cell_x, row_y, cell_width - 1,
            SORT_MENU_ROW_HEIGHT - 1, function()
                self.sort_index = captured_index
                self.sort_dropdown_open = false
                self.scroll = 0
                self.settings.ui.sort = SORTS[self.sort_index].key
                self.save_settings()
                self:render(false)
            end, 'sort_option', hover_key)
    end
end

function UI:_render_roster()
    local roster, pending = self:_filtered_roster()
    local max_scroll = math.max(0, #roster - LIST_ROWS)
    self.scroll = clamp(self.scroll, 0, max_scroll)
    local dropdown_bottom = self.filter_dropdown_open
        and FILTER_MENU_Y + FILTER_MENU_HEIGHT
        or (self.sort_dropdown_open
            and SORT_MENU_Y + SORT_MENU_HEIGHT or nil)
    local function row_is_obscured(y)
        return dropdown_bottom ~= nil and y < dropdown_bottom
    end
    local function row_hover_key(entry)
        return entry and ('roster_row:'
            .. tostring(self:_entry_primitive_key(entry))) or nil
    end

    self:_add_mask('assets/ui/roster-panel-rounded-mask.png',
        LIST_X, LIST_Y, LIST_WIDTH, LIST_HEIGHT,
        COLORS.shell_border, 230, 'roster_panel_background')
    self:_add_mask('assets/ui/roster-panel-inner-rounded-mask.png',
        LIST_X + 2, LIST_Y + 2, LIST_WIDTH - 4, LIST_HEIGHT - 4,
        COLORS.panel, 250, 'roster_panel_background')
    if not self.filter_dropdown_open and not self.sort_dropdown_open then
        self:_add_text(('AVAILABLE TRUSTS  %d'):format(#roster),
            LIST_X + 10, LIST_Y + 7,
            13, COLORS.gold, 'Michroma', false)
    end

    local first = self.scroll + 1
    local last = math.min(#roster, first + LIST_ROWS - 1)

    -- Reserve every visible row background before rendering any icon. Roster
    -- icons are identity-keyed and move between rows while scrolling; if row
    -- backgrounds are created later, Windower can retain them above a moved
    -- icon even after subsequent show calls.
    for row = 0, LIST_ROWS - 1 do
        local entry = roster[first + row]
        local y = LIST_ROW_Y + row * LIST_ROW_HEIGHT
        if not row_is_obscured(y) then
            local background = row % 2 == 0 and COLORS.panel_alt or COLORS.panel
            if entry and entry.active_exact and self.state:is_pending_dismissal(entry) then
                background = COLORS.damage
            elseif entry and pending[entry.id] ~= nil then
                background = COLORS.button_hot
            end
            self:_add_rect(LIST_X + 4, y, LIST_WIDTH - 14, LIST_ROW_HEIGHT - 1,
                background, entry and 240 or 0, 'roster_row_background')
            -- Keep a fixed hover layer for every visible row below its icon
            -- and text. Preallocating these transparent surfaces prevents a
            -- first-time hover from creating a new primitive above content.
            local hovered = entry
                and self.hover_key == row_hover_key(entry)
            self:_add_rect(LIST_X + 4, y, LIST_WIDTH - 14,
                LIST_ROW_HEIGHT - 1, COLORS.cyan,
                hovered and 34 or 0, 'roster_row_hover_fill')
            self:_add_rect(LIST_X + 4, y, 3,
                LIST_ROW_HEIGHT - 1, COLORS.cyan,
                hovered and 235 or 0, 'roster_row_hover_rail')
        end
    end

    for index = first, last do
        local entry = roster[index]
        local row = index - first
        local y = LIST_ROW_Y + row * LIST_ROW_HEIGHT
        if not row_is_obscured(y) then
            local status, status_color = self:_entry_status(entry, pending)
            local alternate_locked = self:_alternate_locked(entry, pending)

            local icon = self:_icon_path(entry)
            if icon then
                self:_add_image(icon, LIST_X + 8, y + 3, 20, 20, COLORS.white,
                    alternate_locked and 115 or 255,
                    'roster_icon', self:_entry_primitive_key(entry))
            end
            self:_add_vertically_centered_text(shorten(entry.en, 20),
                LIST_X + 34, y - 8, LIST_ROW_HEIGHT - 1, 13,
                alternate_locked and COLORS.muted or COLORS.white,
                'Michroma', false)
            self:_add_centered_text(self:_roster_descriptor(entry),
                LIST_X + 245, y, 105, LIST_ROW_HEIGHT - 1,
                9, COLORS.muted, 'Arial', false, 3, 7)
            self:_add_centered_text(status,
                LIST_X + 350, y, 93, LIST_ROW_HEIGHT - 1,
                9, status_color, 'Arial', true, 3, 7)

            local captured = entry
            self:_hitbox(LIST_X + 4, y, LIST_WIDTH - 14,
                LIST_ROW_HEIGHT - 1, function()
                self:_select_entry(captured, pending[captured.id] ~= nil)
            end, 'row', row_hover_key(entry))
        end
    end

    if #roster == 0 and not self.filter_dropdown_open
        and not self.sort_dropdown_open then
        self:_add_text('No matching Trusts found.', LIST_X + 28, LIST_ROW_Y + 30,
            14, COLORS.muted, 'Arial', false)
    end

    local track_x = LIST_X + LIST_WIDTH - 8
    local track_y = LIST_ROW_Y
    local track_height = LIST_ROWS * LIST_ROW_HEIGHT
    self:_add_rect(track_x, track_y, 4, track_height,
        COLORS.dim, 190, 'roster_scroll_track')
    if #roster > LIST_ROWS then
        local thumb_height = math.max(28, track_height * LIST_ROWS / #roster)
        local travel = track_height - thumb_height
        local thumb_y = track_y + travel * self.scroll / max_scroll
        self:_add_rect(track_x, thumb_y, 4, thumb_height,
            COLORS.cyan, 230, 'roster_scroll_thumb')
        -- The visible bar stays slim, but its larger transparent interaction
        -- area makes the thumb practical to grab at every supported UI scale.
        self.hitboxes[#self.hitboxes + 1] = {
            x = track_x - 6,
            y = thumb_y,
            width = 16,
            height = thumb_height,
            kind = 'scrollbar_thumb',
            track_y = track_y,
            track_height = track_height,
            thumb_height = thumb_height,
            max_scroll = max_scroll,
        }
    else
        self:_add_rect(track_x, track_y, 4, track_height,
            COLORS.cyan, 150, 'roster_scroll_thumb')
    end

    self.list_count = #roster
end

-- Pending Trusts no longer have a separate preview panel, but their full card
-- portraits still need to be resident before party confirmation. Otherwise a
-- newly summoned card can expose Windower's white first-load texture frame.
function UI:_prime_pending_party_portraits()
    for _, entry in ipairs(self.state:pending_entries()) do
        local primitive_key = self:_entry_primitive_key(entry)
        local existing = self.keyed_pool.active_portrait
            and self.keyed_pool.active_portrait[primitive_key]
        -- A full incoming card has already positioned this same keyed
        -- primitive for the current frame. Re-priming it here would move the
        -- visible portrait offscreen at alpha zero.
        if not existing or existing.frame ~= self.frame_id then
            self:_prime_image(self:_card_path(entry), 456, 114,
                'active_portrait', primitive_key)
        end
    end
end

-- Build the party-card presentation from authoritative members plus the
-- current editing plan. Retained members keep party order. Dismissals move
-- below them and share rows with pending summons in selection order.
-- Pairing is visual only and never changes the queue's dismissal-first order.
function UI:_build_party_preview_rows()
    local retained = {}
    local outgoing = {}
    local incoming = self.state:pending_entries()
    for _, record in ipairs(self.state.party_trusts or {}) do
        if self.state:is_pending_dismissal(record) then
            outgoing[#outgoing + 1] = record
        else
            retained[#retained + 1] = record
        end
    end

    local rows = {}
    for _, record in ipairs(retained) do
        rows[#rows + 1] = {active=record}
    end
    for index = 1, math.max(#outgoing, #incoming) do
        rows[#rows + 1] = {
            outgoing=outgoing[index],
            incoming=incoming[index],
        }
    end
    return rows
end

function UI:_capture_execution_party_rows()
    local rows = self:_build_party_preview_rows()
    local captured = {}
    for index, row in ipairs(rows) do
        captured[index] = {
            active = row.active,
            outgoing = row.outgoing,
            incoming = row.incoming,
        }
    end
    self.execution_party_rows = captured
    return captured
end

local function record_identity(record)
    return record and (record.identity_key
        or (record.trust and record.trust.identity_key))
end

local function record_id(record)
    return record and tonumber(record.id
        or (record.trust and record.trust.id))
end

function UI:_resolve_execution_party_rows()
    local active_by_identity = {}
    local active_by_id = {}
    for _, record in ipairs(self.state.party_trusts or {}) do
        local identity_key = record_identity(record)
        local id = record_id(record)
        if identity_key then active_by_identity[identity_key] = record end
        if id then active_by_id[id] = record end
    end
    local pending_by_id = {}
    for _, entry in ipairs(self.state:pending_entries()) do
        pending_by_id[tonumber(entry.id)] = entry
    end
    local queue_active = self.queue and self.queue:snapshot().active == true

    local rows = {}
    for index, captured in ipairs(self.execution_party_rows or {}) do
        local retained = captured.active
        local retained_record = retained and (
            active_by_id[record_id(retained)]
            or active_by_identity[record_identity(retained)]) or nil
        local outgoing = captured.outgoing
        local outgoing_record = outgoing and (
            active_by_id[record_id(outgoing)]
            or active_by_identity[record_identity(outgoing)]) or nil
        local incoming = captured.incoming
        local incoming_pending = incoming
            and pending_by_id[tonumber(incoming.id)] or nil
        local incoming_active = incoming and (
            active_by_id[tonumber(incoming.id)]
            or active_by_identity[incoming.identity_key]) or nil
        local incoming_display = incoming_pending
            or (queue_active and incoming and not incoming_active and incoming)

        if retained_record then
            rows[index] = {active=retained_record}
        elseif incoming_active then
            -- Party confirmation is authoritative for this row. Prefer the
            -- newly active Trust if a transient refresh still reports the
            -- outgoing member at the same time.
            rows[index] = {active=incoming_active}
        elseif outgoing_record then
            rows[index] = {
                outgoing=outgoing_record,
                incoming=incoming_display,
            }
        elseif incoming_display then
            rows[index] = {incoming=incoming_display}
        else
            rows[index] = {
                placeholder='EMPTY',
            }
        end
    end
    return rows
end

function UI:_dedupe_party_preview_rows(rows)
    local seen_incoming = {}
    for index, row in ipairs(rows) do
        local incoming = row.incoming
        if incoming then
            local key = tostring(incoming.identity_key or incoming.en
                or incoming.name or incoming.id or index)
            if seen_incoming[key] then
                row.incoming = nil
                if not row.outgoing then
                    row.placeholder = 'EMPTY'
                end
            else
                seen_incoming[key] = true
            end
        end
    end
    return rows
end

function UI:_hide_stale_incoming_split_primitives(rows)
    local function key_matches(record_key, active_key)
        record_key = tostring(record_key or '')
        active_key = tostring(active_key or '')
        return record_key == active_key
            or record_key:sub(1, #active_key + 1) == active_key .. ':'
    end
    local active_keys = {}
    for _, row in ipairs(rows) do
        local entry = row.incoming
        if entry then
            local key = self:_entry_primitive_key(entry)
            active_keys[key] = true
            active_keys['incoming:' .. key] = true
        end
    end
    for kind, records in pairs(self.object_pool) do
        if kind:match('^incoming_split_') then
            for _, record in ipairs(records) do
                local active = false
                for active_key in pairs(active_keys) do
                    if key_matches(record.key, active_key) then
                        active = true
                        break
                    end
                end
                if record.visible and not active then
                    pcall(function() record.object:hide() end)
                    record.visible = false
                end
            end
        end
    end
    for key, relative_path in pairs({
        summon = REPLACEMENT_AMBER.summon_gradient,
        dismiss = REPLACEMENT_AMBER.dismiss_gradient,
    }) do
        local path = self:_asset(relative_path)
        if self:_exists(path) then
            self:_prime_image(path, RIGHT_WIDTH - 2, ACTIVE_CARD_HEIGHT - 2,
                'active_gradient_preload', 'replacement:' .. key)
        end
    end
end

function UI:_hide_incoming_split_entry(entry)
    local key = self:_entry_primitive_key(entry)
    local function key_matches(record_key, active_key)
        record_key = tostring(record_key or '')
        active_key = tostring(active_key or '')
        return record_key == active_key
            or record_key:sub(1, #active_key + 1) == active_key .. ':'
    end
    for kind, records in pairs(self.object_pool) do
        if kind:match('^incoming_split_') then
            for _, record in ipairs(records) do
                if key_matches(record.key, key)
                        or key_matches(record.key, 'incoming:' .. key) then
                    pcall(function() record.object:hide() end)
                    record.visible = false
                end
            end
        end
    end
end

function UI:_reset_incoming_split_pools(active_keys)
    local function key_matches(record_key, active_key)
        record_key = tostring(record_key or '')
        active_key = tostring(active_key or '')
        return record_key == active_key
            or record_key:sub(1, #active_key + 1) == active_key .. ':'
    end
    for kind, records in pairs(self.object_pool) do
        if kind:match('^incoming_split_')
                and not kind:match('^incoming_split_state') then
            for _, record in ipairs(records) do
                local record_key = tostring(record.key or '')
                local keep = false
                if active_keys then
                    for active_key in pairs(active_keys) do
                        if key_matches(record_key, active_key) then
                            keep = true
                            break
                        end
                    end
                end
                if not keep then
                    pcall(function() record.object:destroy() end)
                    record.visible = false
                    if self.keyed_pool[kind] then
                        self.keyed_pool[kind][record.key] = nil
                    end
                end
            end
        end
    end
end

function UI:_party_preview_rows()
    local queue = self.queue and self.queue:snapshot() or {active=false}
    local rows
    if queue.active then
        if not self.execution_party_rows then
            self:_capture_execution_party_rows()
        end
        rows = self:_dedupe_party_preview_rows(
            self:_resolve_execution_party_rows())
    else
        self.execution_party_rows = nil
        rows = self:_dedupe_party_preview_rows(
            self:_build_party_preview_rows())
    end
    return rows
end

local function incoming_record(entry)
    return entry and {
        id=entry.id,
        name=entry.en,
        identity_key=entry.identity_key,
        trust=entry,
        incoming=true,
    } or nil
end


function UI:_render_active_card_base(record, index, is_incoming)
    local entry = record.trust
    local card_y = ACTIVE_CARD_Y + (index - 1) * ACTIVE_CARD_STEP
    local card_height = ACTIVE_CARD_HEIGHT
    local _, secondary = role_colors(entry)
    local dismissing = not is_incoming and self.state:is_pending_dismissal(record)
    local replacement = dismissing or is_incoming
    local warming_surface = not replacement
        and self.active_card_surface_warmup[index] == true
    local card_secondary = dismissing and COLORS.dismissed_card
        or (is_incoming and REPLACEMENT_AMBER.summon_surface
            or (warming_surface and COLORS.panel or secondary))
    if dismissing then
        card_secondary = REPLACEMENT_AMBER.dismiss_surface
    end
    local shadow_stage_started = self.performance_diagnostics
        and self.clock() or nil
    self:_add_mask('assets/ui/active-card-rounded-mask.png',
        RIGHT_X + 2, card_y + 3, RIGHT_WIDTH, card_height,
        COLORS.shell, 105, 'active_card_shadow')
    self:_performance_stage_add('active-base-shadow', shadow_stage_started)
    local border_stage_started = self.performance_diagnostics
        and self.clock() or nil
    self:_add_mask('assets/ui/active-card-rounded-mask.png',
        RIGHT_X, card_y, RIGHT_WIDTH, card_height,
        dismissing and REPLACEMENT_AMBER.border_dim
            or (is_incoming and REPLACEMENT_AMBER.border or COLORS.shell_border),
        215,
        'active_card_border_fill')
    self:_performance_stage_add('active-base-border', border_stage_started)
    local inner_stage_started = self.performance_diagnostics
        and self.clock() or nil
    local inner_asset_started = self.performance_diagnostics
        and self.clock() or nil
    local inner_path = self:_asset(
        'assets/ui/active-card-inner-rounded-mask.png')
    local inner_available = self:_exists(inner_path)
    self:_performance_stage_add('active-base-inner-asset',
        inner_asset_started)
    local inner_update_started = self.performance_diagnostics
        and self.clock() or nil
    if inner_available then
        self:_add_image(inner_path, RIGHT_X + 1, card_y + 1,
            RIGHT_WIDTH - 2, card_height - 2, card_secondary, 255,
            'active_card_inner_fill')
    else
            self:_add_rect(RIGHT_X + 1, card_y + 1,
                RIGHT_WIDTH - 2, card_height - 2, card_secondary, 255,
                'active_card_inner_fill')
    end
    self:_performance_stage_add('active-base-inner-update',
        inner_update_started)
    self:_performance_stage_add('active-base-inner', inner_stage_started)
end

function UI:_render_active_card_surface(record, index, is_incoming, display_records)
    local entry = record.trust
    local card_y = ACTIVE_CARD_Y + (index - 1) * ACTIVE_CARD_STEP
    local card_height = ACTIVE_CARD_HEIGHT
    local _, secondary = role_colors(entry)
    local dismissing = not is_incoming and self.state:is_pending_dismissal(record)
    local card_secondary = dismissing and COLORS.dismissed_card or secondary
    local gradient_kind = is_incoming and 'active_card_summon_gradient'
        or (dismissing and 'active_card_dismiss_gradient'
            or 'active_card_gradient')
    local gradient = card_gradient_path(ACTIVE_CARD_GRADIENTS, entry, index,
        display_records or self.state.party_trusts)
    if is_incoming or dismissing then
        local replacement_gradient = self:_asset(is_incoming
            and REPLACEMENT_AMBER.summon_gradient
            or REPLACEMENT_AMBER.dismiss_gradient)
        if self:_exists(replacement_gradient) then
            self:_add_image(replacement_gradient,
                RIGHT_X + 1, card_y + 1, RIGHT_WIDTH - 2, card_height - 2,
                COLORS.white, 255, gradient_kind)
        else
            self:_add_rect(RIGHT_X + 1, card_y + 1, RIGHT_WIDTH - 2,
                card_height - 2,
                is_incoming and REPLACEMENT_AMBER.summon_surface
                    or REPLACEMENT_AMBER.dismiss_surface,
                255, gradient_kind)
        end
    elseif gradient and self:_exists(self:_asset(gradient)) then
        self:_add_image(self:_asset(gradient),
            RIGHT_X + 1, card_y + 1, RIGHT_WIDTH - 2, card_height - 2,
            COLORS.white, dismissing and 0 or 255, gradient_kind)
    else
        self:_add_rect(RIGHT_X + 1, card_y + 1, RIGHT_WIDTH - 2,
            card_height - 2, card_secondary, dismissing and 0 or 255,
            gradient_kind)
    end
    local affiliation_key = entry and entry.metadata and entry.metadata.affiliation
    local flag = AFFILIATION_FLAGS[affiliation_key]
    if flag and not dismissing and self:_exists(self:_asset(flag)) then
        if is_incoming then
            local monochrome_flag = flag:gsub(
                '_flag_card_crop%.png$', '_flag_card_crop_amber.png')
            local flag_path = self:_exists(self:_asset(monochrome_flag))
                and monochrome_flag or flag
            self:_add_image(self:_asset(flag_path), RIGHT_X, card_y,
                ACTIVE_CARD_FLAG_WIDTH, ACTIVE_CARD_FLAG_HEIGHT,
                COLORS.white,
                ACTIVE_CARD_INCOMING_FLAG_TINT_ALPHA,
                'active_card_flag_tint', self:_entry_primitive_key(entry))
        else
            self:_add_image(self:_asset(flag), RIGHT_X, card_y,
                ACTIVE_CARD_FLAG_WIDTH, ACTIVE_CARD_FLAG_HEIGHT,
                COLORS.white, ACTIVE_CARD_FLAG_ALPHA, 'active_card_flag',
                self:_entry_primitive_key(entry))
        end
    end
end

function UI:_render_empty_card_background(index)
    local card_y = ACTIVE_CARD_Y + (index - 1) * ACTIVE_CARD_STEP
    local card_height = ACTIVE_CARD_HEIGHT
    self:_add_mask('assets/ui/active-card-rounded-mask.png',
        RIGHT_X + 2, card_y + 3, RIGHT_WIDTH, card_height,
        COLORS.shell, 105, 'active_card_shadow')
    self:_add_mask('assets/ui/active-card-rounded-mask.png',
        RIGHT_X, card_y, RIGHT_WIDTH, card_height,
        COLORS.dim, 140, 'active_card_border_fill')
    self:_add_mask('assets/ui/active-card-inner-rounded-mask.png',
        RIGHT_X + 1, card_y + 1, RIGHT_WIDTH - 2, card_height - 2,
        COLORS.panel, 205, 'active_card_inner_fill')
    self:_add_mask('assets/ui/active-card-accent-rounded-mask.png',
        RIGHT_X + 1, card_y + 1, 198, card_height - 2,
        COLORS.panel, 0, 'active_card_empty_accent')
end

function UI:_render_active_card(record, index, is_incoming, hide_metadata)
    local entry = record.trust
    local primitive_key = self:_active_record_primitive_key(record, index)
    local card_y = ACTIVE_CARD_Y + (index - 1) * ACTIVE_CARD_STEP
    local card_height = ACTIVE_CARD_HEIGHT
    local dismissing = not is_incoming and self.state:is_pending_dismissal(record)
    local queue = self.queue and self.queue:snapshot() or nil

    local portrait_stage_started = self.performance_diagnostics
        and self.clock() or nil
    local portrait = entry and self:_card_path(entry) or nil
    local portrait_width = card_height * 4
    if portrait then
        self:_add_image(portrait, RIGHT_X + RIGHT_WIDTH - portrait_width, card_y,
            portrait_width, card_height,
            COLORS.white,
            is_incoming and ACTIVE_CARD_INCOMING_PORTRAIT_ALPHA
                or (dismissing and 165 or 255),
            'active_portrait', primitive_key)
    else
        self:_add_image('', RIGHT_X + RIGHT_WIDTH - portrait_width, card_y,
            portrait_width, card_height, COLORS.white, 0,
            'active_portrait_placeholder', 'slot:' .. tostring(index))
    end
    if entry then
        local portrait_key = primitive_key
        if SHOW_ACTION_STRIPS then
            self:_render_action_strip(entry, RIGHT_X + 8, card_y + 5,
                RIGHT_WIDTH - 16, 4, portrait_key, 'active_action_strip')
        end
        self:_add_mask(ACTIVE_CARD_PORTRAIT_FADE_MASK,
            RIGHT_X, card_y, RIGHT_WIDTH, card_height,
            COLORS.shell, 255, 'active_card_clip', portrait_key)
        self:_add_mask(ACTIVE_CARD_PORTRAIT_DARKEN_MASK,
            RIGHT_X, card_y, RIGHT_WIDTH, card_height,
            COLORS.shell, 0,
            'active_card_dismiss_overlay', portrait_key)
        if dismissing or is_incoming then
            self:_add_mask(ACTIVE_CARD_PORTRAIT_DARKEN_MASK,
                RIGHT_X, card_y, RIGHT_WIDTH, card_height,
                COLORS.shell, dismissing and 150 or 0,
                'active_card_replacement_darken',
                portrait_key)
        end
        if SHOW_ACTION_FADES then
            self:_render_action_fade(entry, RIGHT_X, card_y, RIGHT_WIDTH, card_height,
                portrait_key, 'active_card_action_fade', false)
        end
        local primary = role_colors(entry)
        self:_render_action_pulse(entry, RIGHT_X + 1, card_y + 1,
            RIGHT_WIDTH - 2, card_height - 2, portrait_key,
            'active_card_action_pulse', false, primary)
    end
    local active_dismissal = dismissing and queue and queue.active
        and queue.phase == 'dismissing' and self:_is_action_target(record)
    local active_summon = entry and not dismissing and queue and queue.active
        and queue.phase == 'summoning' and self:_is_action_target(record)
    self:_add_mask('assets/ui/active-card-border-mask.png',
        RIGHT_X, card_y, RIGHT_WIDTH, card_height,
        is_incoming and (active_summon and REPLACEMENT_AMBER.glow
            or REPLACEMENT_AMBER.border)
            or dismissing and REPLACEMENT_AMBER.border_dim
            or (active_summon and COLORS.gold_dim or COLORS.shell_border),
        is_incoming and (active_summon and 215 or 166) or 215,
        'active_card_border', primitive_key)
    if active_dismissal or active_summon then
        self:_render_perimeter_comet(RIGHT_X, card_y, RIGHT_WIDTH,
            card_height, primitive_key,
            active_dismissal and REPLACEMENT_AMBER.glow or COLORS.gold_bright,
            'active_dismiss_comet')
    end
    self:_performance_stage_add('active-portrait', portrait_stage_started)

    local metadata_stage_started = self.performance_diagnostics
        and self.clock() or nil
    if not hide_metadata then
        local job = entry and job_label(entry) or 'TRUST'
        local affiliation_key = entry and entry.metadata and entry.metadata.affiliation
        local emblem = AFFILIATION_EMBLEMS[affiliation_key]
        local metadata_job_color = dismissing
            and {r=157, g=166, b=171, a=170}
            or (is_incoming and {r=154, g=173, b=183, a=160}
                or COLORS.gold)
        local metadata_role_color = dismissing
            and {r=145, g=154, b=159, a=155}
            or (is_incoming and {r=154, g=173, b=183, a=145}
                or COLORS.card_subtext)
        local metadata_name_color = dismissing
            and {r=176, g=184, b=188, a=170}
            or (is_incoming and {r=240, g=245, b=247, a=165}
                or COLORS.white)
        local header_x = RIGHT_X + 16
        local header_y = card_y + 7
        local emblem_size = 27
        local text_x = header_x
        local metadata_asset_started = self.performance_diagnostics
            and self.clock() or nil
        if emblem and self:_exists(self:_asset(emblem)) then
            self:_add_image(self:_asset(emblem), header_x,
                header_y,
                emblem_size, emblem_size, COLORS.white,
                dismissing and 120 or (is_incoming and 140 or 220),
                'active_affiliation_emblem', primitive_key)
            text_x = header_x + 31
        end
        self:_performance_stage_add('active-metadata-assets',
            metadata_asset_started)
        local metadata_text_started = self.performance_diagnostics
            and self.clock() or nil
        local shadow = {r=0, g=0, b=0, a=is_incoming and 90 or 150}
        local job_stroke_alpha = is_incoming and 85 or 155
        local role_stroke_alpha = is_incoming and 80 or 175
        local name_stroke_alpha = is_incoming and 90 or 165
        -- Michroma's visible cap-height begins below the text primitive's
        -- nominal y coordinate. Pull the job upward so its visible top aligns
        -- with the emblem, and pull the role up slightly so its visible bottom
        -- aligns with the emblem's lower edge.
        local job_y = header_y - 6
        local job_height = 16
        local role_y = header_y + job_height - 3
        local role_height = emblem_size - job_height
        local role = entry and role_label(entry) or 'UNRESOLVED'
        self:_add_vertically_centered_text(job, text_x + 1.25, job_y + 1.75,
            job_height, 11, shadow, 'Michroma', false,
            'active_card_job_shadow', primitive_key, 8, 0)
        self:_add_vertically_centered_text(job, text_x, job_y, job_height,
            11, metadata_job_color, 'Michroma', false,
            'active_card_job_text', primitive_key, 8, job_stroke_alpha)
        self:_add_vertically_centered_text(role, text_x + 1.25, role_y + 1.5,
            role_height, 7, shadow, 'Michroma', false,
            'active_card_role_shadow', primitive_key, 6, 0)
        self:_add_vertically_centered_text(role, text_x, role_y, role_height,
            7, metadata_role_color, 'Michroma', false,
            'active_card_role_text', primitive_key, 6, role_stroke_alpha)
        local display_name = entry and entry.en or record.name or 'Unknown Trust'
        local name_size = #display_name > 18 and 16
            or (#display_name > 14 and 18 or 21)
        -- Anchor every name to the same lower edge. Previously all names used
        -- the same top coordinate, so reduced names appeared to have
        -- progressively more padding beneath them than 21 pt names.
        local name_bottom = card_y + card_height - 12
        local name_y = name_bottom - name_size * TEXT_EXTENT_SCALE
        self:_add_text(display_name, RIGHT_X + 17.25, name_y + 1.75,
            name_size, {r=0, g=0, b=0, a=is_incoming and 95 or 165},
            'Michroma', false, 0,
            'active_card_name_shadow', primitive_key, nil, true)
        self:_add_text(display_name, RIGHT_X + 16, name_y,
            name_size, metadata_name_color, 'Michroma', false,
            name_stroke_alpha,
             'active_card_name_text', primitive_key, nil, true)
        self:_performance_stage_add('active-metadata-text',
            metadata_text_started)
    end
    self:_performance_stage_add('active-metadata', metadata_stage_started)

    local controls_stage_started = self.performance_diagnostics
        and self.clock() or nil
    local captured = record
    if is_incoming then
        -- Reserve the complete split stack in its eventual depth order before
        -- allocating this Trust's foreground action surfaces. Windower keeps
        -- primitive creation depth, so priming only the portrait would allow
        -- a later-created role background to cover it after a full card turns
        -- into a replacement card.
        local split_width = INCOMING_SPLIT_WIDTH
        local split_gradient = card_gradient_path(INCOMING_SPLIT_GRADIENTS,
            entry, index, self.state:pending_entries())
        local split_gradient_path = split_gradient
            and self:_asset(split_gradient) or nil
        if split_gradient_path and self:_exists(split_gradient_path) then
            self:_prime_image(split_gradient_path, split_width,
                card_height - 2, 'incoming_split_gradient', primitive_key)
        else
            self:_prime_image('', split_width, card_height - 2,
                'incoming_split_fill', primitive_key)
        end
        self:_prime_image(self:_card_path(entry), card_height * 4,
            card_height, 'incoming_split_portrait', primitive_key)
        self:_prime_image(self:_asset(ACTIVE_CARD_PORTRAIT_DARKEN_MASK),
            split_width, card_height,
            'incoming_split_portrait_darken', primitive_key)
        self:_prime_image(self:_asset(INCOMING_REPLACEMENT_OVERLAY),
            split_width, card_height, 'incoming_split_wash', primitive_key)
        self:_prime_image(self:_asset(INCOMING_SPLIT_BORDER_MASK),
            split_width, card_height, 'incoming_split_border', primitive_key)
        self:_add_card_state_label('SUMMON',
            RIGHT_X + math.floor(RIGHT_WIDTH / 2) + FULL_CARD_STATE_OFFSET_X,
            card_y,
            192, card_height,
            {r=REPLACEMENT_AMBER.glow.r,
                g=REPLACEMENT_AMBER.glow.g,
                b=REPLACEMENT_AMBER.glow.b, a=175},
            'summon:' .. primitive_key,
            'incoming_card_state', primitive_key, active_summon, 'center')
        self:_glass_action_button('UNDO',
            RIGHT_X + RIGHT_WIDTH - CARD_ACTION_WIDTH - 14,
            card_y + card_height - 29,
            CARD_ACTION_WIDTH, CARD_ACTION_HEIGHT, function()
                self:_select_entry(captured.trust, true)
            end, 'incoming:' .. primitive_key,
         not (queue and queue.active), nil, 'incoming_action_button')
        self:_performance_stage_add('active-controls', controls_stage_started)
        return
    end
    if dismissing then
        local dismiss_state_x = RIGHT_X + math.floor(RIGHT_WIDTH / 2)
            + (hide_metadata and 52 or FULL_CARD_STATE_OFFSET_X)
        local dismiss_alignment = hide_metadata
            and (RIGHT_X + RIGHT_WIDTH - CARD_ACTION_WIDTH - 20)
            or 'center'
        self:_add_card_state_label('DISMISS',
            dismiss_state_x,
            card_y,
            192,
            card_height,
            {r=183, g=192, b=198, a=220},
            'dismiss:' .. primitive_key,
            'outgoing_card_state', primitive_key, active_dismissal,
            dismiss_alignment)
    end
    self:_glass_action_button(dismissing and 'UNDO' or 'DISMISS',
        RIGHT_X + RIGHT_WIDTH - CARD_ACTION_WIDTH - 14,
        card_y + card_height - 29,
        CARD_ACTION_WIDTH, CARD_ACTION_HEIGHT, function()
        self:_capture_planning_order()
        local name = captured.trust and captured.trust.en or captured.name
        local keeping = self.state:is_pending_dismissal(captured)
        local result = self.commands:handle(
            {keeping and 'keep' or 'dismiss', name}, {silent=true})
        if keeping and result and result.removed then
            local removed_name = result.removed.en
                or result.removed.name or 'TRUST'
            self:_show_ui_warning(
                ('KEEPING %s - %s REMOVED'):format(
                    tostring(name or 'TRUST'):upper(),
                    tostring(removed_name):upper()),
                COLORS.retry)
        end
        self:_release_planning_order_if_complete()
        self:render(true)
    end, primitive_key, not (queue and queue.active), nil,
        'card_action_button')
    self:_performance_stage_add('active-controls', controls_stage_started)
end

-- A replacement keeps the complete outgoing card underneath an independently
-- actionable incoming half. Windower image primitives cannot clip another
-- image primitive, so the transparent card-preview portrait is used over a
-- purpose-cropped role gradient rather than allowing full-card art to bleed
-- outside the left half.
function UI:_render_split_incoming(entry, index)
    if not entry then return end
    local primitive_key = self:_entry_primitive_key(entry)
    local card_y = ACTIVE_CARD_Y + (index - 1) * ACTIVE_CARD_STEP
    local card_height = ACTIVE_CARD_HEIGHT
    local split_width = INCOMING_SPLIT_WIDTH
    local primary = role_colors(entry)
    local split_gradient = self:_asset(REPLACEMENT_AMBER.split_gradient)
    if self:_exists(split_gradient) then
        self:_add_image(split_gradient, RIGHT_X + 1, card_y + 1,
            split_width, card_height - 2, COLORS.white, 255,
            'incoming_split_gradient', primitive_key)
    else
        self:_add_rect(RIGHT_X + 1, card_y + 1,
            split_width, card_height - 2,
            REPLACEMENT_AMBER.summon_surface, 255,
            'incoming_split_gradient', primitive_key)
    end

    -- Use the same wide transparent portrait layer as a full incoming card.
    -- Right-aligning that 4:1 layer to the split seam preserves the authored
    -- model scale and framing; its transparent lead-in can extend left
    -- without squeezing the character into the half-card bounds.
    local portrait = self:_card_path(entry)
    local portrait_width = card_height * 4
    if portrait then
        self:_add_image(portrait,
            RIGHT_X + split_width - portrait_width, card_y,
            portrait_width, card_height, COLORS.white, 255,
            'incoming_split_portrait', primitive_key)
    end
    -- Match the portrait restraint used by a queued dismissal. The mask is
    -- scaled to the incoming half so its darker edge still falls beside the
    -- state label and action control without making the PNG itself translucent.
    self:_add_mask(ACTIVE_CARD_PORTRAIT_DARKEN_MASK,
        RIGHT_X, card_y, split_width, card_height,
        COLORS.shell, 255, 'incoming_split_portrait_darken', primitive_key)
    self:_add_mask(ACTIVE_CARD_PORTRAIT_DARKEN_MASK,
        RIGHT_X, card_y, split_width, card_height,
        COLORS.shell, 90, 'incoming_split_replacement_darken', primitive_key)
    self:_add_rect(RIGHT_X, card_y, split_width, card_height,
        REPLACEMENT_AMBER.wash, REPLACEMENT_AMBER.wash.a,
        'incoming_split_wash', primitive_key)

    -- This is the exact left crop of the normal full-card border mask. It
    -- retains the same rounded outer corners as the red dismissal outline
    -- and has no artificial square seam at the card midpoint.
    self:_add_mask(INCOMING_SPLIT_BORDER_MASK,
        RIGHT_X, card_y, split_width, card_height,
        REPLACEMENT_AMBER.border, 220, 'incoming_split_border', primitive_key)

    local queue = self.queue and self.queue:snapshot() or nil
    local active_summon = queue and queue.active
        and queue.phase == 'summoning' and self:_is_action_target(entry)
    self:_render_action_pulse(entry, RIGHT_X + 2, card_y + 2,
        split_width - 2, card_height - 4, primitive_key,
        'incoming_split_action_pulse', true, primary)
    if active_summon then
        self:_render_perimeter_comet(RIGHT_X + 1, card_y + 1,
            split_width, card_height - 2, primitive_key,
            COLORS.gold_bright, 'incoming_split_summon_comet')
    end

    local split_state_color = {
        r=REPLACEMENT_AMBER.glow.r,
        g=REPLACEMENT_AMBER.glow.g,
        b=REPLACEMENT_AMBER.glow.b,
        a=175,
    }
    self:_add_card_state_label('SUMMON',
        RIGHT_X + 52, card_y,
        192,
        card_height,
        split_state_color,
        'summon:' .. primitive_key,
        'incoming_split_state', primitive_key, active_summon)
    local captured = entry
    self:_glass_action_button('UNDO',
        RIGHT_X + split_width - CARD_ACTION_WIDTH - 14,
        card_y + card_height - 29,
        CARD_ACTION_WIDTH, CARD_ACTION_HEIGHT, function()
            self:_select_entry(captured, true)
        end, 'incoming:' .. primitive_key,
         not (queue and queue.active), nil, 'incoming_split_action_button')
end

function UI:_render_empty_card(index, label)
    local card_y = ACTIVE_CARD_Y + (index - 1) * ACTIVE_CARD_STEP
    local card_height = ACTIVE_CARD_HEIGHT
    local portrait_width = card_height * 4
    label = label or 'EMPTY'
    self:_add_image('', RIGHT_X + RIGHT_WIDTH - portrait_width, card_y,
        portrait_width, card_height, COLORS.white, 0,
        'active_portrait_placeholder', 'slot:' .. tostring(index))
    self:_add_text(tostring(index), RIGHT_X + 18, card_y + 40, 24, COLORS.dim, 'Michroma', false)
    self:_add_text(label, RIGHT_X + 63, card_y + 47,
        12, label == 'DISMISSED' and COLORS.red_dim or COLORS.muted,
        'Michroma', false)
end

function UI:_render_no_trust_slots()
    local card_y = ACTIVE_CARD_Y
    self:_add_mask('assets/ui/active-card-rounded-mask.png',
        RIGHT_X + 2, card_y + 3, RIGHT_WIDTH, ACTIVE_CARD_HEIGHT,
        COLORS.shell, 105, 'active_card_shadow')
    self:_add_mask('assets/ui/active-card-rounded-mask.png',
        RIGHT_X, card_y, RIGHT_WIDTH, ACTIVE_CARD_HEIGHT,
        COLORS.dim, 170, 'active_card_border_fill')
    self:_add_mask('assets/ui/active-card-inner-rounded-mask.png',
        RIGHT_X + 1, card_y + 1, RIGHT_WIDTH - 2, ACTIVE_CARD_HEIGHT - 2,
        COLORS.panel, 235, 'active_card_inner_fill')
    self:_add_text('NO TRUST SLOTS AVAILABLE', RIGHT_X + 18, card_y + 37,
        15, COLORS.muted, 'Michroma', false)
    self:_add_text('OTHER PARTY MEMBERS OCCUPY THE AVAILABLE CAPACITY',
        RIGHT_X + 18, card_y + 67, 9, COLORS.dim, 'Michroma', false)
end

function UI:_render_party_zone_transition()
    local card_y = ACTIVE_CARD_Y
    self:_add_mask('assets/ui/active-card-rounded-mask.png',
        RIGHT_X + 2, card_y + 3, RIGHT_WIDTH, ACTIVE_CARD_HEIGHT,
        COLORS.shell, 105, 'active_card_shadow')
    self:_add_mask('assets/ui/active-card-rounded-mask.png',
        RIGHT_X, card_y, RIGHT_WIDTH, ACTIVE_CARD_HEIGHT,
        COLORS.shell_border, 170, 'active_card_border_fill')
    self:_add_mask('assets/ui/active-card-inner-rounded-mask.png',
        RIGHT_X + 1, card_y + 1, RIGHT_WIDTH - 2, ACTIVE_CARD_HEIGHT - 2,
        COLORS.panel, 235, 'active_card_inner_fill')
    self:_add_text('REFRESHING PARTY STATUS', RIGHT_X + 18, card_y + 37,
        15, COLORS.status_neutral, 'Michroma', false)
    self:_add_text('WAITING FOR PARTY DATA',
        RIGHT_X + 18, card_y + 67, 9, COLORS.muted, 'Michroma', false)
end

function UI:_render_active()
    local snapshot = self.state:snapshot()
    if self.party_zone_transition
            and not self.party_zone_transition.settled then
        self:_add_text('CURRENT PARTY', RIGHT_X, 65,
            17, COLORS.gold, 'Michroma', false)
        self:_render_party_zone_transition()
        return
    end
    local trust_capacity = tonumber(snapshot.trust_capacity)
        or math.max(0, snapshot.max_trusts - (snapshot.other_members or 0))
    local preview_rows = self:_party_preview_rows()
    self:_hide_stale_incoming_split_primitives(preview_rows)
    local split_signature = {}
    local split_keys = {}
    for index, row in ipairs(preview_rows) do
        if row.outgoing and row.incoming then
            local incoming_key = self:_entry_primitive_key(row.incoming)
            split_signature[#split_signature + 1] = table.concat({
                tostring(index), incoming_key,
            }, ':')
            split_keys[incoming_key] = true
        end
    end
    split_signature = table.concat(split_signature, '|')
    if split_signature ~= self.active_split_signature then
        self:_reset_incoming_split_pools(split_keys)
        self.active_split_signature = split_signature
    end
    local capacity = snapshot.max_trusts <= 0 and 1
        or clamp(math.max(trust_capacity, snapshot.active_trusts), 0, 5)
    capacity = math.max(capacity, #preview_rows)
    local intended_count = math.max(0, snapshot.active_trusts
        - #self.state:pending_dismissal_records()
        + #self.state:pending_entries())
    local capacity_color = COLORS.gold
    local warning = self.ui_warning
    if warning and warning.kind == 'capacity' then
        local warning_duration = PRESET_WARNING_HOLD + PRESET_WARNING_FADE
        local elapsed = math.max(0, self.clock() - warning.started)
        if elapsed < warning_duration * 0.5 then
            local warning_color = warning.color or COLORS.retry
            local wave = (math.cos(elapsed * math.pi * 4) + 1) * 0.5
            capacity_color = {
                r=math.floor(COLORS.gold.r
                    + (warning_color.r - COLORS.gold.r) * wave + 0.5),
                g=math.floor(COLORS.gold.g
                    + (warning_color.g - COLORS.gold.g) * wave + 0.5),
                b=math.floor(COLORS.gold.b
                    + (warning_color.b - COLORS.gold.b) * wave + 0.5),
                a=255,
            }
        end
    end
    self:_add_text(('CURRENT PARTY %d/%d'):format(
        intended_count, math.max(0, trust_capacity)),
        RIGHT_X, 65, 17, capacity_color, 'Michroma', false,
        nil, 'party_capacity_header')
    if capacity == 0 then
        self:_render_no_trust_slots()
        return
    end

    -- Determine path changes before drawing the slot fills. A changing
    -- gradient receives one transparent warmup frame, so its fallback fill
    -- must remain neutral rather than briefly exposing the role color.
    local active_stage_started = self.performance_diagnostics
        and self.clock() or nil
    self.active_card_surface_warmup = {}
    local gradient_records = self.object_pool.active_card_gradient or {}
    local display_records = {}
    active_stage_started = self.performance_diagnostics
        and self.clock() or nil
    for index = 1, capacity do
        local row = preview_rows[index]
        local record = row and (row.active or row.outgoing
            or incoming_record(row.incoming)) or nil
        display_records[index] = record
    end
    for index = 1, capacity do
        local record = display_records[index]
        local entry = record and record.trust
        local gradient = entry and card_gradient_path(
            ACTIVE_CARD_GRADIENTS, entry, index, display_records)
        local path = gradient and self:_asset(gradient) or nil
        if path and self:_exists(path) then
            local gradient_record = gradient_records[index]
            self.active_card_surface_warmup[index] = not gradient_record
                or gradient_record.path ~= path
        end
    end

    self:_performance_stage('active-prepare', active_stage_started)

    -- Build every card background before any portrait. Identity-keyed
    -- portraits may move between slots as party members leave; keeping every
    -- background below every portrait preserves their z-order after a move.
    for index = 1, capacity do
        local row = preview_rows[index]
        local record = row and (row.active or row.outgoing
            or incoming_record(row.incoming)) or nil
        if record then
            self:_render_active_card_base(record, index,
                row and row.incoming and not row.outgoing)
        else
            local empty_stage_started = self.performance_diagnostics
                and self.clock() or nil
            self:_render_empty_card_background(index)
            self:_performance_stage_add('active-base-empty',
                empty_stage_started)
        end
    end
    self:_performance_stage('active-base', active_stage_started)
    -- Reserve every possible gradient primitive before rendering any flag.
    -- Windower preserves primitive creation depth when party members move, so
    -- allowing this pool to grow later can put a new opaque gradient above an
    -- older Trust's affiliation flag.
    active_stage_started = self.performance_diagnostics
        and self.clock() or nil
    self:_prime_rect_pool('active_card_gradient', 5)
    self:_prime_rect_pool('active_card_summon_gradient', 5)
    self:_prime_rect_pool('active_card_dismiss_gradient', 5)
    for index = 1, capacity do
        local row = preview_rows[index]
        local record = row and (row.active or row.outgoing
            or incoming_record(row.incoming)) or nil
        if record then
            self:_render_active_card_surface(record, index,
                row and row.incoming and not row.outgoing,
                display_records)
        end
    end
    self:_performance_stage('active-surface', active_stage_started)
    active_stage_started = self.performance_diagnostics
        and self.clock() or nil
    for index = 1, capacity do
        local row = preview_rows[index]
        if row and row.active then
            self:_render_active_card(row.active, index, false)
        elseif row and row.outgoing then
            self:_render_active_card(row.outgoing, index, false,
                row.incoming ~= nil)
            local split_controls_started = self.performance_diagnostics
                and self.clock() or nil
            self:_render_split_incoming(row.incoming, index)
            self:_performance_stage_add('active-controls', split_controls_started)
        elseif row and row.incoming then
            self:_render_active_card(incoming_record(row.incoming),
                index, true)
        else
            self:_render_empty_card(index, row and row.placeholder)
        end
    end
    self:_performance_stage('active-foreground', active_stage_started)
end

function UI:_dialogue_party_index(trust_id)
    local numeric_id = tonumber(trust_id)
    for index, record in ipairs(self.state.party_trusts or {}) do
        local entry = record.trust
        if tonumber(record.id) == numeric_id
            or (entry and tonumber(entry.id) == numeric_id) then
            return index
        end
    end
    return nil
end

function UI:_start_summon_dialogue(entry, event_key)
    if type(entry) ~= 'table' then
        return false
    end
    local text = trust_dialogue.for_entry(entry, role_key(entry))
    local lines = wrap_dialogue(text)
    local width = DIALOGUE_MIN_WIDTH
    local total_characters = math.max(0, #lines - 1)
    local line_lengths = {}
    for index, line in ipairs(lines) do
        line_lengths[index] = #utf8_characters(line)
        total_characters = total_characters + line_lengths[index]
        width = math.max(width, math.ceil(estimated_text_width(line,
            DIALOGUE_FONT_SIZE, DIALOGUE_FONT, false)) + DIALOGUE_PADDING_X * 2)
    end
    width = clamp(width, DIALOGUE_MIN_WIDTH, DIALOGUE_MAX_WIDTH)
    local speed = math.max(1,
        tonumber(self.settings.dialogue.characters_per_second) or 30)
    local hold = math.max(0, tonumber(self.settings.dialogue.hold) or 3.25)
    self.summon_dialogue = {
        event_key = event_key,
        trust_id = entry.id,
        trust_name = entry.en,
        lines = lines,
        line_lengths = line_lengths,
        total_characters = total_characters,
        width = width,
        -- The supplied reference is always scaled uniformly. Its tail,
        -- outline, and blue shadow therefore keep their exact proportions.
        height = math.floor(width * DIALOGUE_ASSET_HEIGHT
            / DIALOGUE_ASSET_WIDTH + 0.5),
        started = self.clock(),
        typing_duration = total_characters / speed,
        hold = hold,
    }
    return true
end

function UI:_observe_summon_dialogue(queue, allow_show)
    if not SUMMON_DIALOGUE_ENABLED then
        self.summon_dialogue = nil
        return false
    end
    queue = queue or {}
    local summoned = tonumber(queue.summoned) or 0
    local trust_id = tonumber(queue.last_trust_id)
    if summoned < 1 or not trust_id then
        return false
    end
    local event_key = table.concat({
        tostring(queue.run_id or 0), tostring(summoned), tostring(trust_id),
    }, ':')
    if event_key == self.dialogue_event_key then
        return false
    end
    self.dialogue_event_key = event_key
    if not allow_show or self.settings.dialogue.mode == 'off' then
        return false
    end
    if self.settings.dialogue.mode == 'occasional' then
        local chance = clamp(tonumber(self.settings.dialogue.chance) or 0.25, 0, 1)
        local ok, roll = pcall(self.random)
        if ok and tonumber(roll) and tonumber(roll) > chance then
            return false
        end
    end
    local entry = self.state.by_id and self.state.by_id[trust_id] or nil
    return self:_start_summon_dialogue(entry, event_key)
end

function UI:_render_summon_dialogue()
    if not SUMMON_DIALOGUE_ENABLED then
        self.summon_dialogue = nil
        return
    end
    local dialogue = self.summon_dialogue
    local now = self.clock()
    local index = dialogue and self:_dialogue_party_index(dialogue.trust_id) or nil
    local active = dialogue ~= nil and index ~= nil
    local alpha_scale = 0
    local shown_characters = 0
    if active then
        local age = math.max(0, now - dialogue.started)
        local finish = dialogue.typing_duration + dialogue.hold
        if age >= finish then
            self.summon_dialogue = nil
            dialogue = nil
            active = false
        else
            if dialogue.typing_duration <= 0 then
                shown_characters = dialogue.total_characters
            else
                shown_characters = math.min(dialogue.total_characters,
                    math.floor(age / dialogue.typing_duration
                        * dialogue.total_characters + 0.0001))
            end
            alpha_scale = 1
        end
    end

    local width = dialogue and dialogue.width or 260
    local height = dialogue and dialogue.height
        or math.floor(width * DIALOGUE_ASSET_HEIGHT
            / DIALOGUE_ASSET_WIDTH + 0.5)
    local card_y = ACTIVE_CARD_Y + ((index or 1) - 1) * ACTIVE_CARD_STEP
    -- The reference tail occupies its lower-left corner. A small overlap lets
    -- that unmodified tail emerge from the window edge toward the confirmed
    -- Trust card without redrawing or extending it.
    local x = BASE_WIDTH - DIALOGUE_WINDOW_OVERLAP
    local y = card_y + (ACTIVE_CARD_HEIGHT - height) / 2

    self:_add_image(self:_asset(DIALOGUE_ASSET), x, y, width, height,
        COLORS.white, math.floor(255 * alpha_scale),
        'summon_dialogue_asset', 'bubble')

    local remaining = shown_characters
    for line_index = 1, DIALOGUE_MAX_LINES do
        local value = ''
        if dialogue and dialogue.lines[line_index] then
            local line_count = dialogue.line_lengths[line_index]
            value = utf8_prefix(dialogue.lines[line_index],
                math.min(line_count, math.max(0, remaining)))
            remaining = math.max(0, remaining - line_count - 1)
        end
        self:_add_text(value, x + DIALOGUE_PADDING_X,
            y + DIALOGUE_PADDING_Y + (line_index - 1) * DIALOGUE_LINE_HEIGHT,
            DIALOGUE_FONT_SIZE,
            {r=COLORS.dialogue_text.r, g=COLORS.dialogue_text.g,
                b=COLORS.dialogue_text.b,
                a=math.floor(COLORS.dialogue_text.a * alpha_scale)},
            DIALOGUE_FONT, false, 0, 'summon_dialogue_text', tostring(line_index))
    end
end

function UI:_signature()
    local values = {
        tostring(self.mode),
        tostring(self.filter_index),
        tostring(self.filter_dropdown_open),
        tostring(self.sort_index),
        tostring(self.sort_dropdown_open),
        tostring(self.search),
        tostring(self.scroll),
    }
    local snapshot = self.state:snapshot()
    local sources = snapshot.sources or self.state.source_status or {}
    values[#values + 1] = table.concat({
        tostring(snapshot.logged_in),
        tostring(snapshot.max_trusts),
        tostring(snapshot.party_count),
        tostring(snapshot.active_trusts),
        tostring(snapshot.pending),
        tostring(snapshot.pending_dismissals),
        tostring(snapshot.remaining_slots),
    }, ':')
    -- The UI is constructed before Windower's first authoritative refresh.
    -- Include every source that controls preset validation so a selected slot
    -- is automatically reevaluated as startup data becomes available.
    values[#values + 1] = table.concat({
        'sources',
        tostring(sources.info),
        tostring(sources.spells),
        tostring(sources.recasts),
        tostring(sources.party),
        tostring(sources.key_items),
    }, ':')
    for _, entry in ipairs(self.state:roster('all')) do
        local recast_state = entry.recast_raw == nil and 'unknown'
            or (entry.recast_raw > 0 and 'cooldown' or 'ready')
        values[#values + 1] = table.concat({
            tostring(entry.id),
            tostring(entry.learned),
            recast_state,
            tostring(entry.in_party),
        }, ':')
    end
    for _, member in ipairs(self.state.party_trusts or {}) do
        values[#values + 1] = ('a%s:%s'):format(
            tostring(member.slot),
            tostring(member.id or member.name)
        )
    end
    for _, entry in ipairs(self.state:pending_entries()) do
        values[#values + 1] = 'p' .. tostring(entry.id)
    end
    for _, record in ipairs(self.state:pending_dismissal_records()) do
        values[#values + 1] = 'd' .. tostring(record.identity_key)
    end
    local queue = self.queue and self.queue:snapshot() or {}
    -- Queue status passes through several states per cast. Party/pending state
    -- already records each confirmed success; only the active transition is
    -- needed to switch the footer between Summon and Cancel.
    values[#values + 1] = 'queue:' .. tostring(queue.active == true)
    local preset_ok, preset_slots = preset_engine.list(self.settings.presets)
    if preset_ok then
        values[#values + 1] = 'preset-selected:'
            .. tostring(self.settings.presets.selected)
        for _, preset in ipairs(preset_slots) do
            local members = {}
            for _, member in ipairs(preset.members) do
                members[#members + 1] = tostring(member.id)
            end
            values[#values + 1] = ('preset-%d:%s'):format(
                preset.slot, table.concat(members, ','))
        end
    end
    return table.concat(values, '|')
end

function UI:_restore_compact_preset(selected, snapshot, queue_active)
    if not self.compact_preset_restore_pending then
        return false
    end
    if self.party_zone_transition
            and not self.party_zone_transition.settled then
        return false
    end

    local sources = snapshot.sources or self.state.source_status or {}
    local state_ready = snapshot.logged_in
        and sources.spells and sources.recasts
        and sources.party and sources.key_items
    if not state_ready or queue_active then
        return false
    end

    if not selected or not selected.occupied then
        -- Compact mode has its own direct-action context. The expanded draft
        -- has already been captured, so an empty selection must expose no
        -- action here regardless of what was staged in the full planner.
        self.state:replace_plan({summon={}, dismiss={}})
        self.compact_preset_restore_pending = false
        self.compact_preset_selection_pending = false
        return false
    end
    if selected.loadable == false then
        -- A newly selected direct-action preset supersedes the previous
        -- compact plan even when every remaining member is blocked. Clear the
        -- stale work so the action cannot execute a different preset.
        self.state:replace_plan({summon={}, dismiss={}})
        -- A cooldown-only block is transient, especially across zoning. Keep
        -- watching the selected compact preset so it becomes actionable as
        -- soon as authoritative recasts report READY again.
        self.compact_preset_restore_pending = preset_is_cooldown_blocked(selected)
        self.compact_preset_selection_pending = self.compact_preset_restore_pending
        return false
    end

    -- The full planner's work is held in expanded_plan_draft. Always replace
    -- the shared live plan with the selected preset while compact mode is
    -- visible so its action cannot describe hidden expanded-only staging.
    self.compact_preset_restore_pending = false
    self.compact_preset_selection_pending = false
    self.commands:handle({'preset', 'load', tostring(selected.slot)}, {silent=true})
    self:_show_preset_warning(selected)
    return true
end

function UI:_active_party_signature()
    local values = {}
    for index, record in ipairs(self.state.party_trusts or {}) do
        values[#values + 1] = table.concat({
            tostring(index),
            tostring(record.id or ''),
            tostring(record.identity_key or record.name or ''),
        }, ':')
    end
    return table.concat(values, '|')
end

function UI:_party_zone_snapshot_signature(snapshot)
    return table.concat({
        self:_active_party_signature(),
        tostring(snapshot.max_trusts or ''),
        tostring(snapshot.other_members or ''),
        tostring(snapshot.trust_capacity or ''),
    }, '|')
end

function UI:_observe_party_zone_transition()
    local transition = self.party_zone_transition
    if not transition then
        return false
    end

    local snapshot = self.state:snapshot()
    local sources = snapshot.sources or self.state.source_status or {}
    local state_ready = snapshot.logged_in
        and sources.spells and sources.recasts
        and sources.party and sources.key_items

    if not transition.settled then
        if not state_ready then
            transition.saw_unready = true
            transition.candidate_signature = nil
            transition.stable_refreshes = 0
            return false
        end

        transition.ready_refreshes = (transition.ready_refreshes or 0) + 1
        local current_signature = self:_party_zone_snapshot_signature(snapshot)
        if current_signature == transition.candidate_signature then
            transition.stable_refreshes = transition.stable_refreshes + 1
        else
            transition.candidate_signature = current_signature
            transition.stable_refreshes = 1
        end

        -- A changed party signature is not enough: Windower can briefly expose
        -- one member while the rest of the party is still being rebuilt. Wait
        -- for the full party/capacity tuple to remain unchanged across several
        -- refreshes. The bounded fallback handles clients that never expose an
        -- unavailable or visibly changed snapshot during zoning.
        local post_zone_evidence = transition.saw_unready
            or current_signature ~= transition.initial_snapshot_signature
        local stable = transition.stable_refreshes >= 4
        local fallback_stable = transition.ready_refreshes >= 12
            and transition.stable_refreshes >= 2
        if not (stable and post_zone_evidence) and not fallback_stable then
            return false
        end

        transition.settled = true
        if transition.restore_compact_preset then
            self.compact_preset_selection_pending = true
            self.compact_preset_restore_pending = true
        else
            self.party_zone_transition = nil
            return true
        end
    end

    local _, selected, ready_snapshot, queue_active = self:_preset_summaries()
    local restored = self:_restore_compact_preset(
        selected, ready_snapshot, queue_active)
    if restored or not self.compact_preset_restore_pending then
        self.party_zone_transition = nil
    end
    return restored
end

function UI:_capture_expanded_plan_draft()
    local pending = self.state:pending_entries()
    local dismissals = self.state:pending_dismissal_records()
    local plan = {summon={}, dismiss={}}
    for _, entry in ipairs(pending) do
        plan.summon[#plan.summon + 1] = {
            id = entry.id,
            entry = entry,
        }
    end
    for _, record in ipairs(dismissals) do
        plan.dismiss[#plan.dismiss + 1] = {
            id = record.id,
            name = record.name,
            identity_key = record.identity_key,
            active = record,
        }
    end

    local order = nil
    if type(self.planning_order) == 'table' then
        order = {}
        for index, value in ipairs(self.planning_order) do
            order[index] = value
        end
    end
    return {plan=plan, planning_order=order}
end

function UI:_restore_expanded_plan_draft()
    local draft = self.expanded_plan_draft
    self.expanded_plan_draft = nil
    if not draft then
        return false
    end

    local queue = self.queue and self.queue:snapshot() or {active=false}
    if queue.active then
        return false
    end
    local restored = self.state:replace_plan(draft.plan)
    if restored then
        self.planning_order = draft.planning_order
        return true
    end
    return false
end

function UI:_render_compact_preset_preview(selected, notice_label, notice_color)
    local members = selected and selected.members or {}
    if not selected or not selected.occupied or #members == 0 then
        return false
    end

    local cooldown_ids = {}
    local unavailable_ids = {}
    local cooldown_count = 0
    for _, blocker in ipairs(selected.blockers or {}) do
        local id = tonumber(blocker.id)
        if id then
            if blocker.reason == 'cooldown' then
                if not cooldown_ids[id] then
                    cooldown_ids[id] = true
                    cooldown_count = cooldown_count + 1
                end
            else
                unavailable_ids[id] = true
            end
        end
    end

    local active_ids = {}
    for _, record in ipairs(self.state.party_trusts or {}) do
        local id = tonumber(record.id or (record.trust and record.trust.id))
        if id then active_ids[id] = true end
    end

    local member_count = math.min(#members, preset_engine.MAX_MEMBERS)
    local member_ids = {}
    for position = 1, member_count do
        local id = tonumber(members[position].id)
        if id then member_ids[id] = true end
    end
    -- Party departure can be visible one packet before the corresponding
    -- recast update. Preserve the cooldown affordance for confirmed recent
    -- dismissals until the authoritative recast table catches up.
    local queue_snapshot = self.queue and self.queue:snapshot() or {}
    for _, value in ipairs(queue_snapshot.recent_dismissed_ids or {}) do
        local id = tonumber(value)
        if id and member_ids[id] and not active_ids[id]
                and not cooldown_ids[id] then
            cooldown_ids[id] = true
            cooldown_count = cooldown_count + 1
        end
    end
    local row_width = member_count * COMPACT_PREVIEW_WIDTH
        + math.max(0, member_count - 1) * COMPACT_PREVIEW_GAP
    local has_summary = cooldown_count > 0
        or (type(notice_label) == 'string' and notice_label ~= '')
    local summary_gap = has_summary and 8 or 0
    local start_x = COMPACT_STATUS_X + 2
    local portrait_y = COMPACT_STATUS_Y
        + (COMPACT_STATUS_HEIGHT - COMPACT_PREVIEW_HEIGHT) / 2

    for position = 1, member_count do
        local member = members[position]
        local id = tonumber(member.id)
        local cooldown = id and cooldown_ids[id] == true
        local unavailable = id and unavailable_ids[id] == true
        local active = id and active_ids[id] == true
        local portrait_x = start_x
            + (position - 1) * (COMPACT_PREVIEW_WIDTH + COMPACT_PREVIEW_GAP)
        -- Status is already communicated by tinting and the lower strip. A
        -- neutral frame keeps three- and five-member previews visually equal.
        local frame_color = COLORS.shell_border

        self:_add_rect(portrait_x - 1, portrait_y - 1,
            COMPACT_PREVIEW_WIDTH + 2, COMPACT_PREVIEW_HEIGHT + 2,
            frame_color, 205, 'compact_preset_portrait_frame')
        self:_add_rect(portrait_x, portrait_y,
            COMPACT_PREVIEW_WIDTH, COMPACT_PREVIEW_HEIGHT,
            COLORS.button_disabled, 245, 'compact_preset_portrait_background')

        local entry = id and self.state.by_id and self.state.by_id[id] or nil
        local path = self:_compact_headshot_path(entry)
        if path then
            local tint = (cooldown or unavailable) and COLORS.muted or COLORS.white
            local alpha = cooldown and 145 or (unavailable and 110 or 255)
            self:_add_image(path, portrait_x, portrait_y,
                COMPACT_PREVIEW_WIDTH, COMPACT_PREVIEW_HEIGHT,
                tint, alpha, 'compact_preset_portrait')
        else
            self:_add_centered_text('?', portrait_x, portrait_y,
                COMPACT_PREVIEW_WIDTH, COMPACT_PREVIEW_HEIGHT,
                10, COLORS.muted, 'Arial', true, 0, 6,
                nil, -1, 'compact_preset_portrait_placeholder')
        end

        if cooldown or unavailable then
            self:_add_rect(portrait_x, portrait_y,
                COMPACT_PREVIEW_WIDTH, COMPACT_PREVIEW_HEIGHT,
                COLORS.dim, cooldown and 78 or 105,
                'compact_preset_portrait_mute')
        end
        if cooldown or unavailable or active then
            local marker_color = cooldown and COLORS.retry
                or (unavailable and COLORS.red or COLORS.green)
            self:_add_rect(portrait_x,
                portrait_y + COMPACT_PREVIEW_HEIGHT
                    - COMPACT_PREVIEW_MARKER_HEIGHT,
                COMPACT_PREVIEW_WIDTH, COMPACT_PREVIEW_MARKER_HEIGHT,
                marker_color, 255, 'compact_preset_portrait_marker')
        end
    end

    if has_summary then
        local text_x = start_x + row_width + summary_gap
        local text_width = COMPACT_STATUS_X + COMPACT_STATUS_WIDTH - text_x
        local label = notice_label
        local label_color = notice_color or COLORS.gold
        if cooldown_count > 0 then
            label = self:_compact_cooldown_label(cooldown_count, text_width)
            label_color = COLORS.retry
        end
        self:_add_left_fitted_text(label, text_x, COMPACT_STATUS_Y,
            text_width, COMPACT_STATUS_HEIGHT, 8, label_color,
            'Arial', true, 0, 6, nil, 'compact_preset_preview_status')
    end
    return true
end

function UI:_render_compact()
    self:_begin_frame()

    self:_add_mask(COMPACT_SHELL_MASK,
        0, 0, COMPACT_WIDTH, COMPACT_HEIGHT,
        COLORS.shell_border, 250, 'compact_shell', 'outer')
    self:_add_mask(COMPACT_SHELL_INNER_MASK,
        2, 2, COMPACT_WIDTH - 4, COMPACT_HEIGHT - 4,
        COLORS.title, COMPACT_BACKGROUND_ALPHA,
        'compact_shell_fill', 'inner')
    self:_add_rect(12, 4, COMPACT_WIDTH - 24, 1,
        COLORS.footer_button_text, 36, 'compact_shell_highlight')

    if not self.preset_controls_primed then
        self:_prime_preset_controls()
        self.preset_controls_primed = true
    end

    local launcher_hovered = self.hover_key == 'compact_launcher'
    self:_add_image(self:_asset('assets/ui/trust-hat.png'),
        COMPACT_ICON_X, COMPACT_ICON_Y, COMPACT_ICON_SIZE, COMPACT_ICON_SIZE,
        launcher_hovered and COLORS.launcher_hover or COLORS.white,
        self.launcher_pressed and 0 or 255,
        'compact_launcher_icon', 'launcher')
    self:_add_image(self:_asset('assets/ui/trust-hat-pressed.png'),
        COMPACT_ICON_X, COMPACT_ICON_Y + 1,
        COMPACT_ICON_SIZE, COMPACT_ICON_SIZE,
        COLORS.launcher_pressed, self.launcher_pressed and 255 or 0,
        'compact_launcher_icon_pressed', 'launcher')
    self:_hitbox(8, 10, 40, 40, nil,
        'compact_launcher', 'compact_launcher')
    self:_add_rect(52, 17, 1, 26,
        COLORS.footer_button_border, 80,
        'compact_launcher_seam', 'right')

    self:_add_centered_text('PRESETS', COMPACT_PRESET_X, 2,
        5 * COMPACT_PRESET_SIZE + 4 * COMPACT_PRESET_GAP, 17,
        8, COLORS.gold, 'Arial', true, 2, 6,
        nil, -1, 'compact_preset_caption')

    local summaries, selected, snapshot, queue_active = self:_preset_summaries()
    local queue = self.queue and self.queue:snapshot()
        or {active=false, status='idle'}
    if queue.active then
        self.expanded_plan_draft = nil
    end
    self:_restore_compact_preset(selected, snapshot, queue_active)
    if summaries then
        for index, summary in ipairs(summaries) do
            local slot_x = COMPACT_PRESET_X
                + (index - 1) * (COMPACT_PRESET_SIZE + COMPACT_PRESET_GAP)
            self:_preset_slot_background(summary, slot_x, COMPACT_PRESET_Y,
                COMPACT_PRESET_SIZE, queue_active)
        end
        if queue.active and selected then
            local selected_x = COMPACT_PRESET_X
                + (selected.slot - 1)
                    * (COMPACT_PRESET_SIZE + COMPACT_PRESET_GAP)
            local comet_color = queue.phase == 'dismissing'
                and COLORS.red_bright or COLORS.white
            self:_render_perimeter_comet(selected_x, COMPACT_PRESET_Y,
                COMPACT_PRESET_SIZE, COMPACT_PRESET_SIZE,
                'compact_preset:' .. tostring(selected.slot), comet_color,
                'compact_preset_comet', 58)
        end
        for index, summary in ipairs(summaries) do
            local slot_x = COMPACT_PRESET_X
                + (index - 1) * (COMPACT_PRESET_SIZE + COMPACT_PRESET_GAP)
            self:_preset_slot_foreground(summary, slot_x, COMPACT_PRESET_Y,
                COMPACT_PRESET_SIZE, queue_active, function(chosen)
                    local slot = tostring(chosen.slot)
                    self.commands:handle({'preset', 'select', slot}, {silent=true})
                    if chosen.occupied and chosen.loadable ~= false then
                        self.commands:handle({'preset', 'load', slot}, {silent=true})
                    else
                        -- Compact selection is also load intent. Empty and
                        -- fully blocked slots therefore replace the previous
                        -- compact plan with no action, rather than leaving a
                        -- different preset behind the selected slot.
                        -- Any expanded draft is held separately and restored
                        -- only when the full window is reopened.
                        self.state:replace_plan({summon={}, dismiss={}})
                    end
                    self.compact_preset_selection_pending = false
                    self.compact_preset_restore_pending =
                        preset_is_cooldown_blocked(chosen)
                    self:_show_preset_warning(chosen)
                    self:render(true)
                end)
        end
    end
    self.selected_preset_summary = selected

    self:_add_rect(COMPACT_PRESET_SEAM_X, 17, 1, 26,
        COLORS.footer_button_border, 80,
        'compact_preset_seam', 'right')

    self:_render_primary_action(COMPACT_ACTION_X, COMPACT_ACTION_Y,
        COMPACT_ACTION_WIDTH, COMPACT_ACTION_HEIGHT)

    self:_add_rect(COMPACT_STATUS_X - 5, 17, 1, 26,
        COLORS.footer_button_border, 80, 'compact_status_seam', 'left')
    self:_add_rect(COMPACT_STATUS_X + COMPACT_STATUS_WIDTH + 5, 17, 1, 26,
        COLORS.footer_button_border, 80, 'compact_status_seam', 'right')

    local preset_preview_label = nil
    local preset_preview_color = nil
    local label, color, blinking, bold = self:_compact_queue_notice(queue)
    if not label and queue.active then
        local verb = queue.phase == 'dismissing' and 'Dismissing' or 'Summoning'
        label = ('%s %d/%d  %s'):format(verb,
            tonumber(queue.position) or 0,
            tonumber(queue.total) or #self.state:pending_entries(),
            queue.current_name or queue.status or '')
        color = COLORS.status_neutral
    elseif not label then
        label, color = self:_ui_warning_notice()
    end
    if not label then
        label, color = self:_preset_warning_notice(selected)
        -- Cooldown-only preset warnings are represented persistently by the
        -- muted portraits, amber markers, and count below. Preserve the text
        -- region for hard blockers and other warnings that need explanation.
        if label and preset_has_only_cooldown_blockers(selected) then
            label = nil
            color = nil
        elseif label and selected and selected.order_mismatch then
            -- Keep the selected preset portraits visible while the transient
            -- order explanation occupies the remaining status space.
            preset_preview_label = 'ORDER DIFFERS'
            preset_preview_color = color
            label = nil
            color = nil
        end
    end
    if label then
        self:_render_notice(label, color or COLORS.muted, blinking, bold,
            COMPACT_STATUS_X, COMPACT_STATUS_Y,
            COMPACT_STATUS_WIDTH, COMPACT_STATUS_HEIGHT,
            'compact_status', 4, 6, false,
            queue.current_name or queue.last_trust_name)
    elseif not queue.active then
        self:_render_compact_preset_preview(
            selected, preset_preview_label, preset_preview_color)
    end

    self:_glyph_button('restore', COMPACT_RESTORE_X, COMPACT_RESTORE_Y,
        COMPACT_RESTORE_SIZE, function() self:restore() end,
        'compact_restore')

    local resize_grip_color = self.hover_key == 'compact_resize_grip'
        and COLORS.cyan or COLORS.muted
    self:_add_image(self:_asset(RESIZE_GRIP_ASSET),
        COMPACT_RESIZE_GRIP_X, COMPACT_RESIZE_GRIP_Y,
        COMPACT_RESIZE_GRIP_SIZE, COMPACT_RESIZE_GRIP_SIZE,
        resize_grip_color, 220, 'compact_resize_grip')
    self:_hitbox(COMPACT_WIDTH - 18, COMPACT_HEIGHT - 18, 18, 18, nil,
        'resize', 'compact_resize_grip')

    self.signature = self:_signature()
    self:_finish_frame()
    self:_render_launcher()
end

function UI:render(refresh_state)
    local performance_started
    if not self.visible then
        return
    end
    if self.performance_diagnostics then
        performance_started = self.clock()
        local queue = self.queue and self.queue:snapshot() or nil
        self.performance_frame = {
            queue_active = queue and queue.active == true or false,
            metadata_text_cache_hits = 0,
            metadata_text_cache_misses = 0,
        }
    else
        self.performance_frame = nil
    end
    if refresh_state ~= false then
        self.state:refresh()
    end
    self:_observe_party_zone_transition()
    if self:_has_pending_changes() then
        self:_capture_planning_order()
    else
        self:_release_planning_order_if_complete()
    end

    if self.mode == 'compact' then
        self:_render_compact()
        self:_finish_performance_sample(performance_started)
        return
    end

    -- Reuse the existing primitive pools instead of deleting and recreating
    -- every texture on a state change. Besides being cheaper, this avoids the
    -- magenta missing-texture frame Windower can expose while card PNGs reload.
    self:_begin_frame()

    local chrome_stage_started = self.performance_diagnostics
        and self.clock() or nil
    local window_frame = self:_asset('assets/ui/window-frame.png')
    local window_frame_available = self:_exists(window_frame)
    if window_frame_available then
        -- The transparent corners reveal the game world without introducing
        -- seams between separately scaled border pieces.
        self:_add_image(window_frame, 0, 0, BASE_WIDTH, BASE_HEIGHT,
            COLORS.white, 255, 'window_frame')
    else
        self:_add_rect(0, 0, BASE_WIDTH, BASE_HEIGHT,
            COLORS.shell_border, 245)
        self:_add_rect(3, 3, BASE_WIDTH - 6, BASE_HEIGHT - 6,
            COLORS.shell, 248)
            self:_add_rect(3, 3, BASE_WIDTH - 6, 57,
            COLORS.title, 252)
    end
    if window_frame_available then
        -- The frame texture has a baked blue header/footer. Slate Ice owns
        -- those surfaces, so overlay only the interior bands and preserve the
        -- frame border and transparent corners.
        self:_add_mask(HEADER_SURFACE_MASK, 3, 3, BASE_WIDTH - 6, 57,
            COLORS.title, 252, 'title_surface')
    end
    if not self.preset_controls_primed then
        -- Prime after the shell so preset borders sit above it, but before all
        -- slot foregrounds so saved markers can never be covered later.
        self:_prime_preset_controls()
        self.preset_controls_primed = true
    end
    if not self.active_card_gradients_primed then
        -- Load every small, reusable card surface while it is transparent and
        -- offscreen. A newly occupied slot can then reveal an already-resident
        -- gradient instead of exposing Windower's white loading quad.
        self:_prime_active_card_gradients()
        self:_prime_incoming_card_textures()
        self.active_card_gradients_primed = true
    end
    self:_add_text('TRUST SUPPORT', 20, 14, 24, COLORS.white, 'Michroma', false)
    self:_glyph_button('minus', BASE_WIDTH - 88, 12, 34,
        function() self:minimize() end, 'expanded_minimize')
    self:_circle_button('x', BASE_WIDTH - 48, 12, 34, function() self:close() end)
    self:_render_presets()

    local current_filter = FILTERS[self.filter_index]
    self:_split_control('FILTER: ' .. current_filter.label,
        FILTER_BUTTON_X, FILTER_BUTTON_Y, FILTER_BUTTON_WIDTH,
        FILTER_BUTTON_HEIGHT, FILTER_CYCLE_WIDTH, function()
        self.filter_index = self.filter_index % #FILTERS + 1
        self.filter_dropdown_open = false
        self.sort_dropdown_open = false
        self.scroll = 0
        self:render(false)
    end, function()
        self.sort_dropdown_open = false
        self.filter_dropdown_open = not self.filter_dropdown_open
        self:render(false)
    end, true, 'filter_split_button', self.filter_dropdown_open and '^' or 'v')
    local current_sort = SORTS[self.sort_index]
    local sort_locked = self:_has_pending_changes()
        or (self.queue and self.queue:snapshot().active)
    if sort_locked then
        self.sort_dropdown_open = false
    end
    self:_split_control('SORT: ' .. (current_sort.compact or current_sort.label),
        SORT_BUTTON_X, SORT_BUTTON_Y, SORT_BUTTON_WIDTH,
        SORT_BUTTON_HEIGHT, SORT_CYCLE_WIDTH, function()
        self.sort_index = self.sort_index % #SORTS + 1
        self.filter_dropdown_open = false
        self.sort_dropdown_open = false
        self.settings.ui.sort = SORTS[self.sort_index].key
        self.scroll = 0
        self.save_settings()
        self:render(false)
    end, function()
        self.filter_dropdown_open = false
        self.sort_dropdown_open = not self.sort_dropdown_open
        self:render(false)
    end, not sort_locked, 'sort_split_button', self.sort_dropdown_open and '^' or 'v')
    if self.search ~= '' then
        self:_button('CLEAR SEARCH', 346, 70, 127, 34, function()
            self.search = ''
            self.scroll = 0
            self:render(false)
        end, true, 'clear_search_button')
    end

    self:_performance_stage('chrome', chrome_stage_started)
    local stage_started = self.performance_diagnostics and self.clock() or nil
    self:_render_roster()
    self:_performance_stage('roster', stage_started)
    stage_started = self.performance_diagnostics and self.clock() or nil
    self:_render_active()
    local prime_stage_started = self.performance_diagnostics and self.clock() or nil
    -- Pending entries that are paired with a dismissal use the split portrait
    -- pool. Let the full incoming card allocate/update its own foreground
    -- portrait instead of reusing an offscreen preload primitive on undo.
    self:_performance_stage('active-prime', prime_stage_started)
    -- Keep the speech-bubble layer resident above cards and portraits even
    -- while transparent. This avoids first-use texture flashes and preserves
    -- its draw order when a confirmed summon begins the typewriter animation.
    self:_render_summon_dialogue()
    self:_performance_stage('active', stage_started)

    stage_started = self.performance_diagnostics and self.clock() or nil
    local footer_surface_started = self.performance_diagnostics
        and self.clock() or nil
    self:_add_mask(FOOTER_SURFACE_MASK, 3, FOOTER_SURFACE_Y,
        BASE_WIDTH - 6, 69,
        COLORS.footer, 245, 'footer_background')
    self:_performance_stage_add('footer-surface', footer_surface_started)
    local footer_model_started = self.performance_diagnostics
        and self.clock() or nil
    local pending_count = #self.state:pending_entries()
    local dismissal_count = #self.state:pending_dismissal_records()
    local queue = self.queue and self.queue:snapshot() or {active=false, status='idle'}
    local snapshot = self.state:snapshot()
    local all_dismissals_staged = snapshot.active_trusts > 0
        and dismissal_count >= snapshot.active_trusts
    local stats = snapshot.stats or {}
    local trust_feature_available = snapshot.max_trusts > 0
        and ((tonumber(stats.learned) or 0) > 0
            or snapshot.active_trusts > 0)
    local trust_capacity = tonumber(snapshot.trust_capacity)
        or math.max(0, snapshot.max_trusts - (snapshot.other_members or 0))
    local rendered_capacity = snapshot.max_trusts <= 0 and 1
        or clamp(math.max(trust_capacity, snapshot.active_trusts), 0, 5)
    -- Follow the last rendered slot, including EMPTY cards. This removes the
    -- unused fifth-slot gap for four-slot parties without making the control
    -- jump whenever an individual Trust joins or leaves.
    local last_rendered_slot = math.max(1, rendered_capacity)
    local party_action_y = math.min(MAX_PARTY_ACTION_Y,
        ACTIVE_CARD_Y + (last_rendered_slot - 1) * ACTIVE_CARD_STEP
            + ACTIVE_CARD_HEIGHT + 17)
    self:_performance_stage_add('footer-model', footer_model_started)
    local footer_controls_started = self.performance_diagnostics
        and self.clock() or nil
    local footer_clear_started = self.performance_diagnostics
        and self.clock() or nil
    self:_button('CLEAR CHANGES', CLEAR_CHANGES_X, FOOTER_CONTROL_Y,
        CLEAR_CHANGES_WIDTH, 40, function()
        self.compact_preset_selection_pending = false
        self.commands:handle({'clear'}, {silent=true})
        self.planning_order = nil
        self:render(true)
    end, (pending_count > 0 or dismissal_count > 0) and not queue.active,
        'clear_changes_button')
    self:_performance_stage_add('footer-clear', footer_clear_started)
    local footer_dismiss_started = self.performance_diagnostics
        and self.clock() or nil
    if rendered_capacity > 0 then
        self:_glass_action_button('DISMISS ALL',
            RIGHT_X + RIGHT_WIDTH - CARD_ACTION_WIDTH - 14, party_action_y,
            CARD_ACTION_WIDTH, CARD_ACTION_HEIGHT, function()
            self:_capture_planning_order()
            self.compact_preset_selection_pending = false
            self.commands:handle({'dismiss', 'all'}, {silent=true})
            self:_release_planning_order_if_complete()
            self:render(true)
            end, 'dismiss_all', trust_feature_available
                and snapshot.active_trusts > 0 and not queue.active
                and not all_dismissals_staged, 'dismiss_all_button')
    end
    self:_performance_stage_add('footer-dismiss', footer_dismiss_started)

    local footer_divider_started = self.performance_diagnostics
        and self.clock() or nil
    self:_add_rect(FOOTER_DIVIDER_X, FOOTER_CONTROL_Y,
        1, 40, COLORS.footer_button_border, 90, 'footer_action_divider')
    self:_performance_stage_add('footer-divider', footer_divider_started)
    self:_performance_stage_add('footer-controls', footer_controls_started)

    local status = nil
    if queue.active then
        local verb = queue.phase == 'dismissing' and 'Dismissing' or 'Summoning'
        status = ('%s %d/%d  %s'):format(
            verb,
            tonumber(queue.position) or 0,
            tonumber(queue.total) or pending_count,
            queue.current_name or queue.status or '')
    elseif pending_count > 0 and dismissal_count > 0 then
        status = ('%d %s + %d %s SELECTED'):format(
            pending_count, pending_count == 1 and 'SUMMON' or 'SUMMONS',
            dismissal_count,
            dismissal_count == 1 and 'DISMISSAL' or 'DISMISSALS')
    elseif pending_count > 0 then
        status = ('%d %s SELECTED'):format(
            pending_count, pending_count == 1 and 'SUMMON' or 'SUMMONS')
    elseif dismissal_count > 0 then
        status = ('%d %s SELECTED'):format(dismissal_count,
            dismissal_count == 1 and 'DISMISSAL' or 'DISMISSALS')
    elseif self.search ~= '' then
        status = 'Search: ' .. self.search
    end
    local footer_notice_started = self.performance_diagnostics
        and self.clock() or nil
    self:_render_footer_notice(queue, status)
    self:_performance_stage_add('footer-notice', footer_notice_started)

    local primary_action_started = self.performance_diagnostics
        and self.clock() or nil
    self:_render_primary_action(PRIMARY_ACTION_X, FOOTER_CONTROL_Y,
        PRIMARY_ACTION_WIDTH, 40)
    self:_performance_stage_add('footer-primary', primary_action_started)
    self:_performance_stage('footer', stage_started)

    local resize_grip_color = self.hover_key == 'resize_grip'
        and COLORS.cyan or COLORS.muted
    self:_add_image(self:_asset(RESIZE_GRIP_ASSET), BASE_WIDTH - 32,
        BASE_HEIGHT - 32, 28, 28, resize_grip_color, 235, 'resize_grip')
    self:_hitbox(BASE_WIDTH - 30, BASE_HEIGHT - 25, 30, 25, nil,
        'resize', 'resize_grip')

    -- Render the transient menu last so its opaque surface, labels, and
    -- hitboxes stay above the roster rows it temporarily covers.
    stage_started = self.performance_diagnostics and self.clock() or nil
    self:_render_filter_dropdown()
    self:_render_sort_dropdown()

    local signature_stage_started = self.performance_diagnostics
        and self.clock() or nil
    self.signature = self:_signature()
    self:_performance_stage('signature', signature_stage_started)
    self:_finish_frame()
    self:_performance_stage('cleanup', stage_started)
    self:_finish_performance_sample(performance_started)
end

function UI:_finish_performance_sample(started)
    if not started or not self.performance then return end
    local elapsed = math.max(0, self.clock() - started)
    local allocated = 0
    for _, pool in pairs(self.object_pool) do
        allocated = allocated + #pool
    end
    local performance = self.performance
    performance.renders = performance.renders + 1
    performance.total_seconds = performance.total_seconds + elapsed
    performance.max_seconds = math.max(performance.max_seconds, elapsed)
    performance.last_frame_objects = #self.objects
    performance.last_allocated_primitives = allocated
    for name, duration in pairs((self.performance_frame or {}).stages or {}) do
        performance.stage_total[name] =
            (performance.stage_total[name] or 0) + duration
        performance.stage_max[name] = math.max(
            performance.stage_max[name] or 0, duration)
    end
    local frame = self.performance_frame or {}
    if frame.queue_active then
        performance.queue_active_frames = performance.queue_active_frames + 1
    end
    if frame.state_label_shimmer then
        performance.state_label_shimmer_frames =
            performance.state_label_shimmer_frames + 1
    end
    if frame.active_state_label then
        performance.active_state_label_frames =
            performance.active_state_label_frames + 1
    end
    if frame.primary_pulse then
        performance.primary_pulse_frames = performance.primary_pulse_frames + 1
    end
    local texture_warmup = self.deferred_texture_reveal
    for _, warming in pairs(self.active_card_surface_warmup or {}) do
        texture_warmup = texture_warmup or warming == true
    end
    if texture_warmup then
        performance.texture_warmup_frames =
            performance.texture_warmup_frames + 1
    end
    if frame.comet then
        performance.comet_frames = performance.comet_frames + 1
    end
    performance.action_pulse_mask_submissions =
        performance.action_pulse_mask_submissions
        + (frame.action_pulse_masks or 0)
    if frame.visible_action_pulse then
        performance.visible_action_pulse_frames =
            performance.visible_action_pulse_frames + 1
    end
    performance.metadata_text_cache_hits =
        performance.metadata_text_cache_hits
        + (frame.metadata_text_cache_hits or 0)
    performance.metadata_text_cache_misses =
        performance.metadata_text_cache_misses
        + (frame.metadata_text_cache_misses or 0)
    self.performance_frame = nil
end

function UI:_performance_stage(name, started)
    if not started or not self.performance_frame then return end
    self.performance_frame.stages = self.performance_frame.stages or {}
    self.performance_frame.stages[name] = math.max(0,
        self.clock() - started)
end

function UI:_performance_stage_add(name, started)
    if not started or not self.performance_frame then return end
    self.performance_frame.stages = self.performance_frame.stages or {}
    self.performance_frame.stages[name] =
        (self.performance_frame.stages[name] or 0)
        + math.max(0, self.clock() - started)
end

function UI:set_performance_diagnostics(enabled)
    self.performance_diagnostics = enabled == true
    self.performance = {
        started = self.clock(),
        renders = 0,
        total_seconds = 0,
        max_seconds = 0,
        last_frame_objects = 0,
        last_allocated_primitives = 0,
        queue_active_frames = 0,
        state_label_shimmer_frames = 0,
        active_state_label_frames = 0,
        primary_pulse_frames = 0,
        texture_warmup_frames = 0,
        comet_frames = 0,
        action_pulse_mask_submissions = 0,
        visible_action_pulse_frames = 0,
        metadata_text_cache_hits = 0,
        metadata_text_cache_misses = 0,
        reposition_calls = 0,
        reposition_total_seconds = 0,
        reposition_max_seconds = 0,
        reposition_objects = 0,
        stage_total = {},
        stage_max = {},
    }
end

function UI:performance_report()
    local performance = self.performance
    if not performance then
        return 'UI performance diagnostics unavailable.'
    end
    local elapsed = math.max(0, self.clock() - performance.started)
    local average_ms = performance.renders > 0
        and performance.total_seconds / performance.renders * 1000 or 0
    local max_ms = performance.max_seconds * 1000
    local render_rate = elapsed > 0 and performance.renders / elapsed or 0
    local reposition_average_ms = performance.reposition_calls > 0
        and performance.reposition_total_seconds
            / performance.reposition_calls * 1000 or 0
    local reposition_max_ms = performance.reposition_max_seconds * 1000
    local stage_report = {}
    for _, name in ipairs({'chrome', 'roster', 'active', 'active-prepare',
        'active-base', 'active-surface', 'active-foreground',
        'active-portrait', 'active-metadata', 'active-metadata-assets',
        'active-metadata-text', 'active-controls',
        'active-base-shadow', 'active-base-border', 'active-base-inner',
        'active-base-inner-asset', 'active-base-inner-update',
        'active-base-inner-pos', 'active-base-inner-size',
        'active-base-inner-color', 'active-base-inner-path',
        'active-base-inner-alpha',
        'active-base-empty',
        'active-prime', 'footer', 'footer-surface', 'footer-model',
        'footer-controls', 'footer-clear', 'footer-dismiss',
        'footer-clear-hide', 'footer-clear-surface', 'footer-clear-label',
        'footer-clear-hitbox', 'footer-divider', 'footer-notice',
        'footer-primary', 'footer-primary-hide', 'footer-primary-pulse',
        'footer-primary-button',
        'cleanup', 'signature'}) do
        local total = performance.stage_total[name] or 0
        local maximum = performance.stage_max[name] or 0
        stage_report[#stage_report + 1] = ('%s=%.1f/%.1f'):format(
            name, performance.renders > 0
                and total / performance.renders * 1000 or 0,
            maximum * 1000)
    end
    return ('UI performance: %.2fms avg, %.2fms max, %.1f renders/s, '
        .. '%d frame objects, %d allocated primitives; frames '
        .. 'queue=%d labels=%d active-labels=%d primary=%d warmup=%d '
        .. 'comets=%d action-masks=%d visible-action=%d; '
        .. 'metadata-cache=%d/%d; reposition=%.2f/%.2fms x%d/%d; stages %s'):format(
            average_ms, max_ms, render_rate,
            performance.last_frame_objects,
            performance.last_allocated_primitives,
            performance.queue_active_frames,
            performance.state_label_shimmer_frames,
            performance.active_state_label_frames,
            performance.primary_pulse_frames,
            performance.texture_warmup_frames,
            performance.comet_frames,
            performance.action_pulse_mask_submissions,
            performance.visible_action_pulse_frames,
            performance.metadata_text_cache_hits,
            performance.metadata_text_cache_misses,
            reposition_average_ms,
            reposition_max_ms,
            performance.reposition_calls,
            performance.reposition_objects,
            table.concat(stage_report, ' '))
end

function UI:open()
    if self.visible then
        self:render(true)
        return
    end
    self.visible = true
    self.scroll = 0
    if self.mode == 'compact' then
        -- The menu may have been closed while a zone transition refreshed
        -- recasts. Revalidate the selected direct-action preset on reopen.
        self.compact_preset_restore_pending = true
    end
    self:_render_launcher()
    self:render(true)
end

function UI:on_zone_change()
    local restore_compact_preset = self.mode == 'compact'
    if restore_compact_preset then
        -- Compact selection is also its load intent. A zone clears the active
        -- Trust party and may refresh cooldowns while this bar remains open,
        -- so re-run the selected preset once authoritative state returns.
        -- Any expanded draft was calculated against the pre-zone party; do
        -- not let it replace the newly rebuilt preset plan on maximize.
        self.expanded_plan_draft = nil
        self.compact_preset_selection_pending = false
        self.compact_preset_restore_pending = false
    end
    self.party_zone_transition = {
        initial_snapshot_signature = self:_party_zone_snapshot_signature(
            self.state:snapshot()),
        saw_unready = false,
        ready_refreshes = 0,
        stable_refreshes = 0,
        settled = false,
        restore_compact_preset = restore_compact_preset,
    }
    if self.visible then
        -- Show a neutral transition immediately from the pre-zone state. Do
        -- not reinterpret an incomplete snapshot as real party capacity.
        self:render(false)
    end
end

function UI:_set_mode(mode)
    if mode ~= 'compact' and mode ~= 'expanded' then
        return false
    end
    local entering_compact = mode == 'compact' and self.mode ~= 'compact'
    local restoring_expanded = mode == 'expanded' and self.mode == 'compact'
    if entering_compact then
        self.expanded_plan_draft = self:_capture_expanded_plan_draft()
    elseif restoring_expanded then
        self:_restore_expanded_plan_draft()
    end
    if self.mode == 'compact' then
        self.compact_scale = self.scale
        self.settings.ui.compact_scale = self.compact_scale
    else
        self.expanded_scale = self.scale
        self.settings.ui.expanded_scale = self.expanded_scale
        self.settings.ui.scale = self.expanded_scale
    end
    self.mode = mode
    if entering_compact then
        -- Compact has no staging surface or separate Load button. Rebuild its
        -- action from the selected preset every time it is entered; the full
        -- planner remains isolated in expanded_plan_draft until restored.
        self.compact_preset_restore_pending = true
    end
    self.scale = mode == 'compact'
        and self.compact_scale or self.expanded_scale
    self.settings.ui.mode = mode
    self.filter_dropdown_open = false
    self.sort_dropdown_open = false
    self.hover_key = nil
    self.pressed_key = nil
    self.save_settings()
    self:_render_launcher()
    if self.visible then
        self:render(true)
    end
    return true
end

function UI:minimize()
    return self:_set_mode('compact')
end

function UI:restore()
    return self:_set_mode('expanded')
end

function UI:close()
    self.visible = false
    self.summon_dialogue = nil
    self.ui_warning = nil
    self.filter_dropdown_open = false
    self.sort_dropdown_open = false
    self.scrollbar_drag = nil
    self.drag = nil
    self.drag_preview = false
    self.resize = nil
    self.mouse_capture = nil
    self.hover_key = nil
    self.pressed_key = nil
    self:_set_launcher_hovered(false)
    self:_set_launcher_pressed(false)
    self:_hide_window()
    self:_render_launcher()
end

function UI:toggle()
    if self.visible then
        self:close()
    else
        self:open()
    end
end

function UI:set_launcher_visible(enabled)
    self.icon_enabled = enabled == true
    self:_render_launcher()
end

function UI:set_search(query)
    self.search = tostring(query or '')
    self.scroll = 0
    if self.search ~= '' and self.mode == 'compact' then
        self:_set_mode('expanded')
    end
    if self.visible then
        self:render(true)
    end
end

function UI:set_dialogue_mode(mode, persist)
    mode = tostring(mode or ''):lower()
    if mode ~= 'off' and mode ~= 'occasional' and mode ~= 'always' then
        return false
    end
    self.settings.dialogue.mode = mode
    if mode == 'off' then
        self.summon_dialogue = nil
    end
    if persist ~= false then
        self.save_settings()
    end
    if self.visible then
        self:render(false)
    end
    return true
end

function UI:set_scale(scale)
    self.scale = clamp(tonumber(scale) or self.scale, 0.55, 1.25)
    if self.mode == 'compact' then
        self.compact_scale = self.scale
        self.settings.ui.compact_scale = self.scale
    else
        self.expanded_scale = self.scale
        self.settings.ui.expanded_scale = self.scale
        -- Retain the original setting for backward compatibility. It now
        -- represents the expanded window scale.
        self.settings.ui.scale = self.scale
    end
    self.save_settings()
    if self.visible then
        self:render(false)
    end
end

function UI:reset_position()
    self.x = 220
    self.y = 95
    self.settings.ui.x = self.x
    self.settings.ui.y = self.y
    self.save_settings()
    if self.visible then
        self:render(false)
    end
end

function UI:_inside(x, y, box)
    local left = self:_origin_x() + self:_s(box.x)
    local top = self:_origin_y() + self:_s(box.y)
    return x >= left and x <= left + self:_s(box.width)
        and y >= top and y <= top + self:_s(box.height)
end

function UI:_launcher_contains(x, y)
    if not self.icon_enabled or not self.launcher
        or (self.visible and self.mode == 'compact') then
        return false
    end
    if x < self.launcher_x or x > self.launcher_x + self.launcher_size
        or y < self.launcher_y or y > self.launcher_y + self.launcher_size then
        return false
    end

    -- The expanded window is visually above the independent launcher. Match
    -- that stacking order in hit testing so an obscured launcher cannot close
    -- or drag the window through its surface.
    if self.visible and self.mode == 'expanded'
        and self:_inside(x, y, {
            x=0, y=0, width=BASE_WIDTH, height=BASE_HEIGHT,
        }) then
        return false
    end
    return true
end

function UI:_reposition()
    local started = self.performance_diagnostics and self.clock() or nil
    local origin_x = self:_origin_x()
    local origin_y = self:_origin_y()
    for _, record in ipairs(self.objects) do
        record.object:pos(origin_x + record.x, origin_y + record.y)
    end
    if started and self.performance then
        local elapsed = math.max(0, self.clock() - started)
        self.performance.reposition_calls = self.performance.reposition_calls + 1
        self.performance.reposition_total_seconds =
            self.performance.reposition_total_seconds + elapsed
        self.performance.reposition_max_seconds = math.max(
            self.performance.reposition_max_seconds, elapsed)
        self.performance.reposition_objects = #self.objects
    end
end

function UI:_update_hover(x, y)
    if not self.visible or self.mouse_capture or self.launcher_drag
        or self.scrollbar_drag or self.drag or self.resize then
        return
    end

    local next_hover = nil
    for index = #self.hitboxes, 1, -1 do
        local box = self.hitboxes[index]
        if box.hover_key and self:_inside(x, y, box) then
            next_hover = box.hover_key
            break
        end
    end
    if next_hover ~= self.hover_key then
        self.hover_key = next_hover
        self:render(false)
    end
end

function UI:on_mouse(type, x, y, delta, blocked)
    if blocked then
        self.hover_key = nil
        self.pressed_key = nil
        self:_set_launcher_hovered(false)
        self:_set_launcher_pressed(false)
        if type == 2 then
            self:_end_drag_preview()
            self.launcher_drag = nil
            self.scrollbar_drag = nil
            self.drag = nil
            self.resize = nil
            self.mouse_capture = nil
        end
        return
    end

    if type == 0 then
        local hovering_launcher = self:_launcher_contains(x, y)
        if hovering_launcher ~= self.launcher_hovered then
            self:_set_launcher_hovered(hovering_launcher)
        end
        self:_update_hover(x, y)
        if self.launcher_drag then
            local next_x = math.floor(x - self.launcher_drag.offset_x)
            local next_y = math.floor(y - self.launcher_drag.offset_y)
            if math.abs(x - self.launcher_drag.start_x) >= 3
                or math.abs(y - self.launcher_drag.start_y) >= 3 then
                self.launcher_drag.moved = true
            end
            self.launcher_x = next_x
            self.launcher_y = next_y
            if self.visible and self.mode == 'compact' then
                self:_reposition()
            elseif self.launcher then
                self.launcher:pos(next_x, next_y)
                if self.launcher_pressed_icon then
                    self.launcher_pressed_icon:pos(next_x, next_y)
                end
            end
            return true
        elseif self.scrollbar_drag then
            local drag = self.scrollbar_drag
            local thumb_top = clamp(y - drag.offset_y,
                drag.track_top, drag.track_top + drag.travel)
            local ratio = drag.travel > 0 and (thumb_top - drag.track_top) / drag.travel or 0
            local next_scroll = clamp(math.floor(ratio * drag.max_scroll + 0.5),
                0, drag.max_scroll)
            if next_scroll ~= self.scroll then
                self.scroll = next_scroll
                self:render(false)
            end
            return true
        elseif self.resize then
            local delta_x = x - self.resize.x
            local delta_y = y - self.resize.y
            local width = self.resize.width or BASE_WIDTH
            local height = self.resize.height or BASE_HEIGHT
            -- Project pointer movement onto the shell diagonal. This keeps the
            -- shallow compact bar from reacting too aggressively to a few
            -- vertical pixels while preserving fixed-aspect scaling.
            local change = (delta_x * width + delta_y * height)
                / (width * width + height * height)
            local pending = clamp(self.resize.scale + change, 0.55, 1.25)
            self.resize.pending = pending
            if math.abs(pending - (self.resize.rendered or self.resize.scale)) >= 0.01 then
                self.scale = pending
                self.resize.rendered = pending
                self:render(false)
            end
            return true
        elseif self.drag then
            if self.drag.compact then
                self.launcher_x = math.floor(x - self.drag.x)
                self.launcher_y = math.floor(y - self.drag.y)
                self:_reposition()
            else
                self.x = math.floor(x - self.drag.x)
                self.y = math.floor(y - self.drag.y)
                self:_reposition()
            end
            return true
        elseif self.mouse_capture then
            return true
        end
    elseif type == 2 then
        local released_press = self.pressed_key ~= nil
        self.pressed_key = nil
        if released_press and self.visible then
            self:render(false)
        end
        if self.launcher_drag then
            local moved = self.launcher_drag.moved
            self.launcher_drag = nil
            self.mouse_capture = nil
            self:_set_launcher_pressed(false)
            if moved then
                self.settings.ui.launcher_x = self.launcher_x
                self.settings.ui.launcher_y = self.launcher_y
                self.save_settings()
                if self.visible and self.mode == 'compact' then
                    self:render(false)
                end
            else
                self:toggle()
            end
            return true
        elseif self.scrollbar_drag then
            self.scrollbar_drag = nil
            self.mouse_capture = nil
            return true
        elseif self.resize then
            local scale = self.resize.pending or self.resize.scale
            self.resize = nil
            self.mouse_capture = nil
            self:set_scale(scale)
            return true
        elseif self.drag then
            local compact_drag = self.drag.compact == true
            self.drag = nil
            self.mouse_capture = nil
            if compact_drag then
                self.settings.ui.launcher_x = self.launcher_x
                self.settings.ui.launcher_y = self.launcher_y
            else
                self.settings.ui.x = self.x
                self.settings.ui.y = self.y
            end
            self.save_settings()
            if not compact_drag then
                self:_end_drag_preview()
            end
            return true
        elseif self.mouse_capture then
            self.mouse_capture = nil
            return true
        end
    elseif type == 1 then
        self:_update_hover(x, y)
        if self:_launcher_contains(x, y) then
            self.launcher_drag = {
                start_x=x,
                start_y=y,
                offset_x=x - self.launcher_x,
                offset_y=y - self.launcher_y,
                moved=false,
            }
            self:_set_launcher_pressed(true)
            self.mouse_capture = 'launcher'
            return true
        end
        if not self.visible then
            return false
        end

        if self.mode == 'expanded'
            and (self.filter_dropdown_open or self.sort_dropdown_open) then
            local dropdown_is_filter = self.filter_dropdown_open
            local button_x = dropdown_is_filter
                and FILTER_BUTTON_X or SORT_BUTTON_X
            local button_y = dropdown_is_filter
                and FILTER_BUTTON_Y or SORT_BUTTON_Y
            local button_width = dropdown_is_filter
                and FILTER_BUTTON_WIDTH or SORT_BUTTON_WIDTH
            local button_height = dropdown_is_filter
                and FILTER_BUTTON_HEIGHT or SORT_BUTTON_HEIGHT
            local menu_x = dropdown_is_filter and FILTER_BUTTON_X or LIST_X
            local menu_y = dropdown_is_filter and FILTER_MENU_Y or SORT_MENU_Y
            local menu_width = dropdown_is_filter
                and FILTER_MENU_WIDTH or SORT_MENU_WIDTH
            local menu_height = dropdown_is_filter
                and FILTER_MENU_HEIGHT or SORT_MENU_HEIGHT
            local inside_button = self:_inside(x, y, {
                x=button_x,
                y=button_y,
                width=button_width,
                height=button_height,
            })
            local inside_menu = self:_inside(x, y, {
                x=menu_x,
                y=menu_y,
                width=menu_width,
                height=menu_height,
            })
            if not inside_button and not inside_menu then
                self.filter_dropdown_open = false
                self.sort_dropdown_open = false
                self.pressed_key = nil
                self:render(false)
                -- A click on the obscured roster only dismisses the menu; it
                -- must not also stage the row that happened to be underneath.
                if self:_inside(x, y, {
                    x=LIST_X,
                    y=LIST_Y,
                    width=LIST_WIDTH,
                    height=LIST_HEIGHT,
                }) then
                    self.mouse_capture = 'window'
                    return true
                end
            end
        end

        for index = #self.hitboxes, 1, -1 do
            local box = self.hitboxes[index]
            if self:_inside(x, y, box) then
                self.mouse_capture = 'window'
                if box.kind == 'compact_launcher' then
                    self.launcher_drag = {
                        start_x=x,
                        start_y=y,
                        offset_x=x - self.launcher_x,
                        offset_y=y - self.launcher_y,
                        moved=false,
                    }
                    self:_set_launcher_pressed(true)
                    self:render(false)
                    self.mouse_capture = 'launcher'
                elseif box.kind == 'resize' then
                    self.resize = {
                        x=x,
                        y=y,
                        scale=self.scale,
                        pending=self.scale,
                        rendered=self.scale,
                        width=self.mode == 'compact' and COMPACT_WIDTH or BASE_WIDTH,
                        height=self.mode == 'compact' and COMPACT_HEIGHT or BASE_HEIGHT,
                    }
                elseif box.kind == 'scrollbar_thumb' then
                    local thumb_top = self.y + self:_s(box.y)
                    self.scrollbar_drag = {
                        offset_y = y - thumb_top,
                        track_top = self.y + self:_s(box.track_y),
                        travel = self:_s(box.track_height - box.thumb_height),
                        max_scroll = box.max_scroll,
                    }
                    self.mouse_capture = 'scrollbar'
                elseif box.action then
                    if box.hover_key then
                        self.pressed_key = box.hover_key
                        self:render(false)
                    end
                    box.action()
                    -- close() may clear the ordinary UI state, but Windower
                    -- still needs the matching button release consumed.
                    self.mouse_capture = 'window'
                end
                return true
            end
        end

        if self.mode == 'compact'
            and self:_inside(x, y, {
                x=0, y=0, width=COMPACT_WIDTH, height=COMPACT_HEIGHT,
            }) then
            self.mouse_capture = 'window'
            self.drag = {
                x=x - self.launcher_x,
                y=y - self.launcher_y,
                compact=true,
            }
            return true
        end
        if self.mode == 'expanded'
            and self:_inside(x, y, {x=0, y=0, width=BASE_WIDTH, height=60}) then
            self.mouse_capture = 'window'
            self.drag = {x=x - self.x, y=y - self.y}
            self.drag_preview = true
            self:_render_drag_preview()
            return true
        end
        if self.mode == 'expanded'
            and self:_inside(x, y, {x=0, y=0, width=BASE_WIDTH, height=BASE_HEIGHT}) then
            self.mouse_capture = 'window'
            return true
        end
    elseif type == 10 and self.visible and self.mode == 'expanded' then
        if (self.filter_dropdown_open or self.sort_dropdown_open)
            and self:_inside(x, y, {
                x=LIST_X,
                y=LIST_Y,
                width=LIST_WIDTH,
                height=LIST_HEIGHT,
            }) then
            return true
        end
        if self:_inside(x, y, {x=LIST_X, y=LIST_Y, width=LIST_WIDTH, height=LIST_HEIGHT}) then
            local direction = delta > 0 and -3 or 3
            local max_scroll = math.max(0, (self.list_count or 0) - LIST_ROWS)
            self.scroll = clamp(self.scroll + direction, 0, max_scroll)
            self:render(false)
            return true
        elseif self:_inside(x, y, {x=0, y=0, width=BASE_WIDTH, height=60}) then
            self:set_scale(self.scale + (delta > 0 and 0.05 or -0.05))
            return true
        end
    end
    return false
end

function UI:_update_state_label_animation(descriptor)
    local sweep_progress, active_sweep = self:_state_label_sweep(
        descriptor.state_key, descriptor.active,
        true)
    local glyphs = utf8_characters(descriptor.value)
    for index, glyph in ipairs(glyphs) do
        local color = self:_state_label_glyph_color(
            descriptor.base_color, index, #glyphs, sweep_progress,
            active_sweep, descriptor.value == 'DISMISS',
            descriptor.value == 'SUMMON')
        local glyph_key = tostring(descriptor.primitive_key) .. ':'
            .. tostring(index)
        for _, kind in ipairs({
            descriptor.primitive_kind,
            descriptor.primitive_kind .. '_weight',
            descriptor.primitive_kind .. '_weight_right',
        }) do
            local record = self.keyed_pool[kind]
                and self.keyed_pool[kind][glyph_key]
            if record then
                record.object:color(color.r, color.g, color.b)
                record.object:alpha(color.a or 255)
                record.color = color
                record.alpha = color.a or 255
            end
        end
    end
end

function UI:_update_primary_pulse_animation()
    local record = self.keyed_pool.primary_ready_pulse
        and self.keyed_pool.primary_ready_pulse.outer
    if not record then return false end
    local alpha = 0
    local started = self.primary_ready_pulse_started
    if started then
        local elapsed = math.max(0, self.clock() - started)
        if elapsed >= PRIMARY_READY_PULSE_DURATION then
            self.primary_ready_pulse_started = nil
        else
            local envelope = 1 - elapsed / PRIMARY_READY_PULSE_DURATION
            local wave = (math.sin(elapsed * math.pi * 2 * 1.7) + 1) * 0.5
            alpha = math.floor((28 + wave * 92) * envelope + 0.5)
        end
    end
    record.object:alpha(alpha)
    record.alpha = alpha
    return alpha > 0
end

function UI:_render_animation_frame()
    if USE_PRE_RENDERED_STATE_LABEL_SWEEP then return false end
    if not self.animation_state_labels then return false end
    local started = self.performance_diagnostics and self.clock() or nil
    local queue = self.queue and self.queue:snapshot() or nil
    self.performance_frame = {
        queue_active = queue and queue.active == true or false,
    }
    self.state_label_pulse_active = false
    for _, descriptor in pairs(self.animation_state_labels) do
        self:_update_state_label_animation(descriptor)
    end
    self:_update_primary_pulse_animation()
    self:_finish_performance_sample(started)
    return true
end

function UI:_state_label_pulse_due(now)
    if not self:_has_pending_changes() then
        return false
    end
    for state_key, started in pairs(self.state_label_started or {}) do
        local descriptor = self.animation_state_labels
            and self.animation_state_labels[state_key]
        local idle_enabled = descriptor ~= nil
        if idle_enabled and now - started >= CARD_STATE_IDLE_SWEEP_CYCLE then
            return true
        end
    end
    return false
end

function UI:tick()
    self:_tick_launcher()
    local queue = self.queue and self.queue:snapshot() or {active=false}
    self:_observe_summon_dialogue(queue, self.visible)
    if not self.visible then
        return
    end
    if self.drag_preview then
        return
    end
    local now = self.clock()
    local warning_active = self.preset_warning ~= nil or self.ui_warning ~= nil
    local dialogue_active = self.summon_dialogue ~= nil
    local texture_reveal_active = self.deferred_texture_reveal == true
    local primary_pulse_active = self.primary_ready_pulse_started ~= nil
    local state_label_pulse_active = self.state_label_pulse_active == true
    local state_label_pulse_due = not state_label_pulse_active
        and self:_state_label_pulse_due(now)
    local state_label_animation_active = state_label_pulse_active
        or state_label_pulse_due
    local fast_animation_active = queue.active or dialogue_active
        or texture_reveal_active or primary_pulse_active
    local dragging_expanded = self.drag and not self.drag.compact
    local refresh_interval = fast_animation_active
            and (dragging_expanded and DRAG_ANIMATION_REFRESH_INTERVAL
                or ANIMATION_REFRESH_INTERVAL)
        or (state_label_animation_active and CARD_STATE_REFRESH_INTERVAL
            or (warning_active and 0.1 or 0.5))
    if now - self.last_refresh < refresh_interval then
        return
    end
    self.last_refresh = now
    self.state:refresh()
    local zone_transition_changed = self:_observe_party_zone_transition()
    local signature = self:_signature()
    local animation_only = signature == self.signature
        and not queue.active
        and not warning_active
        and not dialogue_active
        and not texture_reveal_active
        and not zone_transition_changed
        and (state_label_animation_active or primary_pulse_active)
    if animation_only and self:_render_animation_frame() then
        return
    end
    if signature ~= self.signature or queue.active or warning_active
        or dialogue_active or texture_reveal_active or primary_pulse_active
        or state_label_animation_active
        or zone_transition_changed then
        self:render(false)
    end
end

function UI:destroy()
    self:close()
    self:_destroy_window()
    if self.launcher then
        pcall(function() self.launcher:destroy() end)
        self.launcher = nil
    end
    if self.launcher_pressed_icon then
        pcall(function() self.launcher_pressed_icon:destroy() end)
        self.launcher_pressed_icon = nil
    end
end

return trust_ui
