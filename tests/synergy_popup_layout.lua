-- Real-data regression cases for the popup, run with the UI smoke harness.
return function(ui, state)
    local old_resource, old_catalog, old_scale = ui.trust_synergy, state.catalog, ui.scale
    local resource = require('resources/trust_synergy')
    local cards = require('resources/card_assets')
    ui.trust_synergy = resource
    local catalog = {}
    for name, card in pairs(cards) do catalog[#catalog + 1] = {en=name, card=card} end
    state.catalog = catalog
    local seen_portrait, seen_dim_portrait, seen_learned_portrait = false, false, false
    local hidden_left_fragment, visible_uncovered_card = false, false
    local noillurie_rows = ui:_synergy_popup_rows('Noillurie')
    local condition_index, requirement_index, effect_index
    for index, row in ipairs(noillurie_rows) do
        if row.key == 'noillurie_iroha_ii:trigger' then
            condition_index = index
        elseif row.key == 'noillurie_iroha_ii:requirement' then
            requirement_index = index
            assert(table.concat(row.lines, ' '):find('Requires:', 1, true),
                'the inactive skillchain group must show a requirement cue')
        elseif row.kind == 'effect' and not effect_index then
            effect_index = index
        end
    end
    assert(condition_index and requirement_index and effect_index
            and condition_index < requirement_index
            and requirement_index < effect_index,
        'the requirement belongs between the condition and the effects')
    assert(noillurie_rows[effect_index].active == false,
        'inactive effects must not take the active color')
    local original_party = state.party_trusts
    local generals = resource.for_trust('Rughadjeen')[1]
    -- Every subset: an active group does not imply every member's effect is active.
    for mask = 0, 31 do
        local present, count = {}, 0
        state.party_trusts = {}
        for index, name in ipairs(generals.members) do
            if math.floor(mask / 2 ^ (index - 1)) % 2 == 1 then
                present[name], count = true, count + 1
                state.party_trusts[#state.party_trusts + 1] = {name=name}
            end
        end
        for index, effect in ipairs(generals.effects) do
            local expected = present.Rughadjeen == true and count >= 2
                and present[effect.trust] == true
            if effect.text:match('^Enfire:') then expected = count == 5 end
            assert(ui:_synergy_effect_is_active(generals, effect, present) == expected,
                'Serpent General effect must require its recipient and specific partners')
            for _, row in ipairs(ui:_synergy_popup_rows('Rughadjeen')) do
                if row.key == 'rughadjeen_serpent_generals:effect:' .. index then
                    assert(row.active == expected, 'popup must use per-effect activation')
                end
            end
        end
    end
    state.party_trusts = original_party
    local old_level = ui.get_player_level
    local level = 99
    ui.get_player_level = function() return level end
    local trio = resource.for_trust('Aldo')[1]
    local cases = {
        {{}, {false, false, false}},
        {{'Aldo'}, {false, false, false}},
        {{'Lion'}, {false, false, false}},
        {{'Zeid'}, {false, false, false}},
        {{'Aldo', 'Lion'}, {true, true, false}},
        {{'Aldo', 'Zeid'}, {false, false, true}},
        {{'Lion', 'Zeid'}, {false, true, true}},
        {{'Aldo', 'Lion', 'Zeid'}, {true, true, true}},
    }
    for _, case in ipairs(cases) do
        local present = {}
        state.party_trusts = {}
        for _, name in ipairs(case[1]) do
            present[name] = true
            state.party_trusts[#state.party_trusts + 1] = {name=name}
        end
        assert(ui:_synergy_group_is_active(trio, present) == (#case[1] >= 2))
        assert((ui:_synergy_missing_requirement(trio, present) == nil) == (#case[1] >= 2))
        for _, popup_name in ipairs({'Aldo', 'Lion', 'Zeid'}) do
            for _, row in ipairs(ui:_synergy_popup_rows(popup_name)) do
                local index = row.key:match('^aldo_lion_zeid:effect:(%d+)$')
                if index then assert(row.active == case[2][tonumber(index)],
                    'trio popup highlights must follow individual effect conditions') end
            end
        end
    end
    local pair = {Aldo=true, Lion=true}
    for _, value in ipairs({19, 20}) do
        level = value
        assert(ui:_synergy_effect_is_active(trio, trio.effects[1], pair) == (value >= 20))
    end
    level = nil
    assert(not ui:_synergy_effect_is_active(trio, trio.effects[1], pair),
        'unknown player level must not confirm the level-gated effect')
    ui.get_player_level = old_level
    state.party_trusts = original_party
    local function noillurie_requirement()
        for _, row in ipairs(ui:_synergy_popup_rows('Noillurie')) do
            if row.key == 'noillurie_iroha_ii:requirement' then
                return table.concat(row.lines, ' ')
            end
        end
    end
    state.party_trusts = {{name='Noillurie'}}
    assert(noillurie_requirement() == 'Requires: Iroha II',
        'the popup must name only the missing partner')
    state.party_trusts = {{name='Noillurie'}, {name='Iroha II'}}
    assert(noillurie_requirement() == nil,
        'the cue must disappear when both partners are present')
    local active_effect, active_partner
    for _, row in ipairs(ui:_synergy_popup_rows('Noillurie')) do
        if row.kind == 'effect' then active_effect = row.active end
        if row.kind == 'partner' and row.name == 'Iroha II' then
            active_partner = row.active
        end
    end
    assert(active_effect and active_partner,
        'active effects and contributing partners need a popup cue')
    ui.synergy_popup_trust = 'Noillurie'
    ui:render(false)
    local border
    for _, record in ipairs(ui.object_pool.synergy_popup_active_portrait_border or {}) do
        if record.visible then border = record; break end
    end
    assert(border and ui.synergy_popup_active_portrait_count > 0,
        'an active partner portrait must have a visible border')
    ui:_update_synergy_popup_portrait_pulse(0.7)
    assert(border.image_alpha ~= 115,
        'the active portrait border must pulse without a redraw')
    ui:_close_synergy_popup()
    state.party_trusts = {{name='Aldo'}}
    ui.synergy_popup_trust = 'Aldo'
    ui:render(false)
    ui.synergy_popup_scroll = ui.synergy_popup_max_scroll
    ui:render(false)
    assert(not (ui.keyed_pool.synergy_popup_active_portrait_border or {})
            ['Aldo:aldo_lion_zeid:partner:2'],
        'the Lion portrait must begin without an active ring')
    -- Create the ring after the portrait already exists: the solid-mask
    -- version could appear above it and pulse over the entire face.
    state.party_trusts = {{name='Aldo'}, {name='Lion'}}
    ui:render(false)
    ui:render(false)
    local lion_ring = ui.keyed_pool.synergy_popup_active_portrait_border
        ['Aldo:aldo_lion_zeid:partner:2']
    assert(lion_ring and lion_ring.visible
            and lion_ring.path:find('synergy%-portrait%-ring%.png'),
        'late activation must use a transparent-center ring for Lion')
    ui.synergy_popup_trust, ui.synergy_popup_scroll = 'Lion', 0
    ui:render(false)
    ui.synergy_popup_scroll = ui.synergy_popup_max_scroll
    ui:render(false)
    ui:render(false)
    local aldo_ring = ui.keyed_pool.synergy_popup_active_portrait_border
        ['Lion:aldo_lion_zeid:partner:1']
    assert(aldo_ring and aldo_ring.visible
            and aldo_ring.path:find('synergy%-portrait%-ring%.png'),
        'the reciprocal Aldo popup must use the same ring')
    local lion_portrait = ui.keyed_pool.synergy_popup_partner_portrait
        ['Aldo:aldo_lion_zeid:partner:2']
    local aldo_portrait = ui.keyed_pool.synergy_popup_partner_portrait
        ['Lion:aldo_lion_zeid:partner:1']
    assert(lion_ring.image_width - lion_portrait.image_width
            == aldo_ring.image_width - aldo_portrait.image_width,
        'reciprocal partner rings must have the same border allowance')
    ui:_close_synergy_popup()
    state.source_status.party = false
    assert(noillurie_requirement() == nil,
        'an unavailable party read must not claim partners are missing')
    state.source_status.party = true
    state.party_trusts = original_party

    local function snapshot(label)
        local directory = os.getenv('TRUST_SUPPORT_POPUP_CAPTURE')
        if not directory then return end
        local file = assert(io.open(directory .. '/' .. label .. '.tsv', 'w'))
        local bounds = ui.synergy_popup_bounds
        file:write(('bounds\t%d\t%d\t%d\t%d\n'):format(
            ui:_s(bounds.x), ui:_s(bounds.y), ui:_s(bounds.width), ui:_s(bounds.height)))
        for _, record in ipairs(ui.objects) do
            if record.visible and record.kind:match('^synergy_popup_') then
                local c = record.color or {r=255,g=255,b=255}
                local value = record.is_text and record.value or record.path
                file:write(table.concat({record.is_text and 'text' or 'image',
                    record.x, record.y, record.image_width or 0, record.image_height or 0,
                    record.font_size or 0, record.bold and 1 or 0,
                    c.r, c.g, c.b, record.alpha or 255,
                    tostring(value or ''):gsub('[\t\r\n]', ' ')}, '\t') .. '\n')
            end
        end
        file:close()
    end

    for _, scale in ipairs({0.55, 0.78, 1.0, 1.25}) do
        ui:set_scale(scale)
        for name in pairs(resource.by_trust) do
            for _, row in ipairs(ui:_synergy_popup_rows(name)) do
                if row.kind == 'effect' then
                    for _, column in ipairs({
                        {row.names, row.actor_width, true},
                        {row.abilities, row.narrow and row.body_width or row.ability_width, false},
                        {row.descriptions, row.effect_width, false},
                    }) do
                        for _, line in ipairs(column[1]) do
                            local measured = ui:_measure_text(line, ui:_s(row.font_size), 'Arial', column[3])
                            assert(measured <= ui:_s(column[2]) + 2,
                                'catalog effect overflows its column: ' .. name .. ': ' .. line)
                        end
                    end
                elseif row.kind == 'partner' and cards[row.name] then
                    assert(row.portrait, 'catalog artwork must resolve even when not learned')
                end
            end
        end
        for _, name in ipairs({'Mihli Aliapoh', 'Karaha-Baruha', 'Robel-Akbel', 'Rughadjeen', 'Aldo'}) do
            ui.synergy_popup_trust, ui.synergy_popup_pinned, ui.synergy_popup_scroll = name, true, 0
            ui:render(false)
            ui:render(false) -- finish deferred portrait warm-up
            local rows = ui:_synergy_popup_rows(name)
            if name == 'Karaha-Baruha' then
                local saw_disabled_add, saw_unit_pair = false, false
                for _, row in ipairs(rows) do
                    if row.kind == 'partner' and row.status == 'NOT LEARNED' then
                        saw_disabled_add = row.action == nil
                    elseif row.kind == 'effect' then
                        for _, line in ipairs(row.descriptions) do
                            if line:find('1,000 TP', 1, true) then
                                saw_unit_pair = true
                            end
                        end
                    end
                end
                assert(saw_disabled_add, 'unlearned partners must keep an inactive ADD control')
                assert(saw_unit_pair, 'TP values and units must stay on the same line')
            end
            local total, offsets, observed = 0, {}, {}
            local actor_width
            for _, row in ipairs(rows) do
                offsets[#offsets + 1] = total
                total = total + row.height
                if row.kind == 'effect' then
                    assert(not actor_width or actor_width == row.actor_width,
                        'all effects must use the same Trust column width')
                    actor_width = row.actor_width
                    assert(row.effect_width > 0 and row.actor_width > 0)
                    local function check_lines(lines, width, bold)
                        for _, line in ipairs(lines) do
                            local measured = ui:_measure_text(line, ui:_s(row.font_size), 'Arial', bold)
                            assert(measured <= ui:_s(width) + 2,
                                'wrapped text exceeds its column: ' .. name .. ': ' .. line)
                        end
                    end
                    check_lines(row.names, row.actor_width, true)
                    check_lines(row.abilities, row.narrow and row.body_width or row.ability_width, false)
                    check_lines(row.descriptions, row.effect_width, false)
                end
            end
            if name == 'Karaha-Baruha' and scale >= 1 then
                assert(ui.synergy_popup_bounds.height <= 660,
                    'requirement cues must stay within the popup height limit')
            end
            snapshot(name:gsub('[^%w]', '_') .. '_' .. tostring(scale))
            local stops = {0, ui.synergy_popup_max_scroll}
            for value = 0, ui.synergy_popup_max_scroll, 8 do stops[#stops + 1] = value end
            for _, value in ipairs(stops) do
                ui.synergy_popup_scroll = value
                ui:render(false)
                local bounds = ui.synergy_popup_bounds
                local right, bottom = ui:_s(bounds.x + bounds.width), ui:_s(bounds.y + bounds.height)
                for _, record in ipairs(ui.objects) do
                    local card = record.card_bounds
                    if card then
                        local covered = card.x < bounds.x + bounds.width
                            and card.x + card.width > bounds.x
                            and card.y < bounds.y + bounds.height
                            and card.y + card.height > bounds.y
                        if covered then
                            assert(not record.visible,
                                'every covered card component must hide, including left-side labels: '
                                    .. tostring(record.value or record.kind))
                            if record.is_text and record.x < ui:_s(bounds.x) then
                                hidden_left_fragment = true
                            end
                        elseif card.y >= bounds.y + bounds.height then
                            assert(record.visible, 'cards below a short popup must remain intact')
                            visible_uncovered_card = true
                        end
                    end
                    if record.synergy_obscured then
                        assert(not record.visible, 'underlying images/text must remain hidden during redraw')
                    end
                    if record.visible and record.kind:match('^synergy_popup_') then
                        assert(record.x >= ui:_s(bounds.x) - 1 and record.y >= ui:_s(bounds.y) - 1)
                        if record.is_text then
                            local measured = ui:_measure_text(record.value, record.font_size, record.font, record.bold)
                            assert(record.x + measured <= right + 2, 'text crosses popup right edge: ' .. record.value)
                            assert(record.y + record.font_size * 4 / 3 <= bottom + 2,
                                'text crosses popup bottom edge: ' .. record.value)
                            observed[record.kind .. ':' .. tostring(record.key)] = true
                        elseif record.kind == 'synergy_popup_partner_portrait' then
                            assert(record.x + record.image_width <= right and record.y + record.image_height <= bottom)
                            seen_portrait = true
                            if record.target_alpha == 170 and record.image_color.r == 125 then
                                seen_dim_portrait = true
                            elseif record.target_alpha == 255 then
                                seen_learned_portrait = true
                            end
                        end
                    end
                end
            end
            for _, row in ipairs(rows) do
                if row.kind == 'effect' then
                    for _, part in ipairs({
                        {'effect_name', row.names}, {'effect_ability', row.abilities},
                        {'effect', row.descriptions},
                    }) do
                        for index in ipairs(part[2]) do
                            assert(observed['synergy_popup_' .. part[1] .. ':' .. name .. ':' .. row.key .. ':' .. index],
                                'every effect line must be reachable by scrolling: ' .. name .. ':' .. row.key)
                        end
                    end
                end
            end
        end
    end
    assert(hidden_left_fragment, 'test must cover orphan labels to the left of the popup')
    assert(seen_portrait and seen_dim_portrait, 'catalog-only partners need dimmed portraits')
    assert(seen_learned_portrait, 'learned partners must keep their full-brightness portraits')
    local original_windower, original_x, original_y = windower, ui.x, ui.y
    _G.windower = {get_windower_settings=function()
        return {ui_x_res=800, ui_y_res=600}
    end}
    ui.x, ui.y = 620, 500
    ui:render(false)
    local edge = ui.synergy_popup_bounds
    assert(ui.x + ui:_s(edge.x) >= 7 and ui.y + ui:_s(edge.y) >= 7
        and ui.x + ui:_s(edge.x + edge.width) <= 793
        and ui.y + ui:_s(edge.y + edge.height) <= 593,
        'popup must remain inside the screen when the menu is near an edge')
    _G.windower, ui.x, ui.y = original_windower, original_x, original_y
    local old_capacity, old_other_members = state.max_trusts, state.other_members
    state.max_trusts, state.other_members = 5, 0
    ui:set_scale(1.0)
    ui.synergy_popup_trust, ui.synergy_popup_scroll = 'Noillurie', 0
    ui:render(false)
    local short_bounds = ui.synergy_popup_bounds
    for _, record in ipairs(ui.objects) do
        local card = record.card_bounds
        if card and card.y >= short_bounds.y + short_bounds.height then
            assert(record.visible, 'cards below a short popup must remain intact')
            visible_uncovered_card = true
        end
    end
    assert(visible_uncovered_card, 'five-slot case needs an intact card below the popup')
    state.max_trusts, state.other_members = old_capacity, old_other_members
    ui.synergy_popup_scroll = 0
    ui:render(false)
    local hidden = {}
    for _, record in ipairs(ui.objects) do
        if record.synergy_obscured then hidden[#hidden + 1] = record end
    end
    assert(#hidden > 0)
    ui:_close_synergy_popup()
    ui:render(false)
    for _, record in ipairs(hidden) do
        if record.frame == ui.frame_id then assert(record.visible, 'underlay must return on close') end
    end
    do
        state.max_trusts, state.other_members = 4, 0
        ui:render(false)
        local dismiss_count = 0
        for _, record in ipairs(ui.objects) do
            if record.frame == ui.frame_id and record.key == 'dismiss_all' and record.visible then
                dismiss_count = dismiss_count + 1
            end
        end
        assert(dismiss_count > 0, 'test needs a visible DISMISS ALL control')
        ui.synergy_popup_trust = 'Aldo'
        ui.synergy_popup_bounds = {x=490, y=133, width=612, height=480}
        ui:_hide_synergy_underlay_text()
        local obscured_count = 0
        for _, record in ipairs(ui.objects) do
            if record.frame == ui.frame_id and record.key == 'dismiss_all' then
                assert(not record.visible and record.synergy_obscured,
                    'DISMISS ALL must hide when every card is covered')
                obscured_count = obscured_count + 1
            end
        end
        assert(obscured_count == dismiss_count)
        for _, box in ipairs(ui.hitboxes) do
            assert(box.hover_key ~= 'dismiss_all_button',
                'hidden DISMISS ALL control must not remain clickable')
        end
        ui:_close_synergy_popup()
        ui:render(false)
        local restored = false
        for _, record in ipairs(ui.objects) do
            if record.frame == ui.frame_id and record.key == 'dismiss_all' and record.visible then
                restored = true
            end
        end
        assert(restored, 'DISMISS ALL must return after the popup closes')
        state.max_trusts, state.other_members = old_capacity, old_other_members
    end
    ui.trust_synergy, state.catalog = old_resource, old_catalog
    ui:set_scale(old_scale)
    ui:render(false)
end
