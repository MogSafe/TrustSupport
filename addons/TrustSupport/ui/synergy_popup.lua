-- Synergy popup layout. Keep effects, art, and live partner availability separate.
return function(UI, theme)
    local C, popup = theme.colors, theme.marker.popup

    function UI:_synergy_popup_font_size(base)
        return math.max(base or 10, math.ceil(popup.min_font_pixels / self.scale))
    end

    local function text_width(ui, text, size, bold)
        return theme.measure(text, ui:_s(size), 'Arial', bold) / ui.scale
    end

    function UI:_wrap_synergy_popup_text(text, width, size, bold)
        local lines, line = {}, ''
        local words = {}
        for word in tostring(text or ''):gmatch('%S+') do
            if word:match('^[%d,%.]+$') and (words[#words] == 'unused') then
                -- Deliberately unreachable: token pairing happens in the next pass.
            end
            words[#words + 1] = word
        end
        local tokens, index = {}, 1
        while index <= #words do
            local word = words[index]
            local next_word = words[index + 1]
            local unit = next_word and next_word:match('^(%u%u)[%.,;:!?]*$')
            if word:match('^[%d,%.%-]+$')
                    and (unit == 'TP' or unit == 'HP' or unit == 'MP') then
                tokens[#tokens + 1] = word .. ' ' .. next_word
                index = index + 2
            else
                tokens[#tokens + 1] = word
                index = index + 1
            end
        end
        for _, word in ipairs(tokens) do
            if text_width(self, word, size, bold) > width then
                if line ~= '' then lines[#lines + 1], line = line, '' end
                while text_width(self, word, size, bold) > width do
                    local cut, hyphen = 0, nil
                    for char in word:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
                        local next_cut = cut + #char
                        if cut > 0 and text_width(self, word:sub(1, next_cut), size, bold) > width then
                            break
                        end
                        cut = next_cut
                        if char == '-' then hyphen = cut end
                    end
                    cut = hyphen or math.max(1, cut)
                    lines[#lines + 1] = word:sub(1, cut)
                    word = word:sub(cut + 1)
                end
            end
            local candidate = line == '' and word or line .. ' ' .. word
            if line ~= '' and text_width(self, candidate, size, bold) > width then
                lines[#lines + 1], line = line, word
            else
                line = candidate
            end
        end
        if line ~= '' then lines[#lines + 1] = line end
        if #lines == 0 then lines[1] = '' end
        return lines
    end

    -- Break only between complete names and minimize raggedness across lines.
    function UI:_synergy_balanced_names(members, width, size)
        local costs, breaks = {[#members + 1]=0}, {}
        for first = #members, 1, -1 do
            local best = math.huge
            for last = first, #members do
                local line = table.concat(members, ' / ', first, last)
                local measured = text_width(self, line, size, true)
                if measured > width and last > first then break end
                local cost = (width - measured)^2 + (costs[last + 1] or 0)
                if cost < best then
                    best, breaks[first] = cost, last
                end
            end
            costs[first] = best
        end
        local lines, first = {}, 1
        while first <= #members do
            local last = breaks[first] or first
            local line = table.concat(members, ' / ', first, last)
            for _, wrapped in ipairs(self:_wrap_synergy_popup_text(
                    line, width, size, true)) do
                lines[#lines + 1] = wrapped
            end
            first = last + 1
        end
        return lines
    end

    local function joined_names(names, conjunction)
        if #names == 1 then return names[1] end
        if #names == 2 then
            return names[1] .. ' ' .. conjunction .. ' ' .. names[2]
        end
        return table.concat(names, ', ', 1, #names - 1)
            .. ', ' .. conjunction .. ' ' .. names[#names]
    end

    function UI:_synergy_missing_requirement(group, present)
        local activation = group.activation
        if activation and activation.minimum then
            local count, missing = 0, {}
            for _, name in ipairs(activation.any or {}) do
                if present[name] then count = count + 1
                else missing[#missing + 1] = name end
            end
            local needed = activation.minimum - count
            if needed <= 0 then return nil end
            return 'Requires: ' .. (needed == 1 and 'one of ' or tostring(needed) .. ' of ')
                .. joined_names(missing, 'or')
        end
        local required = activation and activation.required or group.members
        local missing = {}
        for _, name in ipairs(required or {}) do
            if not present[name] then missing[#missing + 1] = name end
        end
        local parts = {}
        if #missing > 0 then
            parts[#parts + 1] = joined_names(missing, 'and')
        end
        if activation and activation.any then
            local has_any = false
            for _, name in ipairs(activation.any) do
                if present[name] then has_any = true; break end
            end
            if not has_any then
                local choices = activation.any
                if #choices == 2 then
                    parts[#parts + 1] = 'either ' .. joined_names(choices, 'or')
                elseif #choices > 2 then
                    parts[#parts + 1] = 'one of ' .. joined_names(choices, 'or')
                elseif #choices == 1 then
                    parts[#parts + 1] = choices[1]
                end
            end
        end
        if #parts == 0 then return nil end
        return 'Requires: ' .. table.concat(parts, ' and ')
    end

    function UI:_synergy_popup_rows(trust_name)
        local rows, entries, catalog = {}, {}, {}
        for _, entry in ipairs(self.state:roster('all')) do entries[entry.en] = entry end
        for _, entry in ipairs(self.state.catalog or {}) do catalog[entry.en] = entry end
        local pending = self:_pending_map()
        local present = self:_synergy_party_members()
        local queue = self.queue and self.queue:snapshot() or {active=false}
        local font = self:_synergy_popup_font_size(10)
        local step = math.ceil(font * 4 / 3 + 5)
        local width = popup.width - 24
        local inner = width - 24
        local narrow = self:_s(inner) < 430
        local actor_width = math.min(inner * 0.50, math.max(114, 114 / self.scale))
        local ability_width = math.min(120, inner * 0.30)
        local gap = 12
        local body_width = inner - actor_width - gap
        local effect_width = narrow and body_width or body_width - ability_width - gap
        local function append(row)
            row.font_size, row.line_step = row.font_size or font, row.line_step or step
            rows[#rows + 1] = row
        end
        local function prose(kind, key, text, bold)
            local lines = self:_wrap_synergy_popup_text(text, inner, font, bold)
            append({kind=kind, key=key, lines=lines, height=#lines * step + 8})
        end
        for _, group in ipairs(self:_roster_synergy_groups({en=trust_name})) do
            local active = self:_synergy_group_is_active(group, present)
            local title_size = self:_synergy_popup_font_size(11)
            local title_lines = group.display_name and {group.display_name}
                or self:_synergy_balanced_names(group.members or {}, inner, title_size)
            local title_step = math.ceil(title_size * 4 / 3 + 5)
            append({kind='group', key=group.id, lines=title_lines,
                font_size=title_size, line_step=title_step,
                height=#title_lines * title_step + 12})
            if group.trigger and group.trigger ~= '' then
                prose('condition', group.id .. ':trigger', group.trigger, false)
            end
            if not (self.state.source_status
                    and self.state.source_status.party == false) then
                local requirement = self:_synergy_missing_requirement(group, present)
                if requirement then
                    prose('requirement', group.id .. ':requirement', requirement, false)
                end
            end
            local previous_actor
            for index, effect in ipairs(group.effects or {}) do
                if self:_synergy_effect_is_reportable(effect) then
                    local actor = tostring(effect.trust or '')
                    local text = tostring(effect.text or effect.label or '')
                    local ability, description = text:match('^(.-):%s+(.+)$')
                    if not ability then ability, description = '', text end
                    local repeated = actor == previous_actor
                    local names = repeated and {} or self:_wrap_synergy_popup_text(
                        actor, actor_width, font, true)
                    local abilities = ability == '' and {} or self:_wrap_synergy_popup_text(
                        ability, narrow and body_width or ability_width, font, false)
                    local descriptions = self:_wrap_synergy_popup_text(description,
                        effect_width, font, false)
                    local copy_count = narrow and (#abilities + #descriptions)
                        or math.max(#abilities, #descriptions)
                    local actor_divider = previous_actor and not repeated
                    local padding = repeated and 10 or 12
                    local divider_height = actor_divider and 9 or 0
                    append({kind='effect', key=group.id .. ':effect:' .. index,
                        active=self:_synergy_effect_is_active(group, effect, present),
                        actor=actor, names=names, abilities=abilities,
                        descriptions=descriptions, actor_width=actor_width,
                        ability_width=ability_width, body_width=body_width,
                        effect_width=effect_width, gap=gap, narrow=narrow,
                        padding=padding, actor_divider=actor_divider,
                        divider_height=divider_height,
                        height=math.max(#names, copy_count) * step
                            + padding + divider_height})
                    previous_actor = actor
                end
            end
            for index, note in ipairs(group.notes or {}) do
                if self:_synergy_note_is_verified(note) then
                    prose('note', group.id .. ':note:' .. index, tostring(note), false)
                end
            end
            append({kind='partners_label', key=group.id .. ':partners',
                lines={'SYNERGY PARTNERS'}, height=step + 16})
            for index, name in ipairs(group.members or {}) do
                if name ~= trust_name then
                    local entry = entries[name]
                    local status, action, color = 'UNAVAILABLE', nil, C.muted
                    if not entry or entry.learned == false then
                        status = self.state.source_status
                            and self.state.source_status.spells == false
                            and 'UNAVAILABLE' or 'NOT LEARNED'
                    elseif queue.active then
                        status = 'QUEUE RUNNING'
                    elseif pending[entry.id] then
                        status, action, color = 'SUMMON', 'UNDO', C.cyan
                    elseif entry.in_party then
                        if entry.active_exact and self.state:is_pending_dismissal(entry) then
                            status, action, color = 'DISMISS', 'KEEP', C.red
                        else
                            status = entry.active_exact and 'IN PARTY' or 'IN USE'
                            color = entry.active_exact and C.blue or C.muted
                        end
                    elseif self:_pending_identity(entry) then
                        status = 'IN USE'
                    elseif entry.recast_raw == nil then
                        status = 'UNAVAILABLE'
                    elseif entry.recast_raw > 0 then
                        status, color = 'COOLDOWN', C.red
                    else
                        local ready, reason = true, 'ready'
                        if self.state.eligibility then
                            ready, reason = self.state:eligibility(entry)
                        else
                            ready = (tonumber(self.state:snapshot().remaining_slots) or 0) > 0
                            reason = 'party_full'
                        end
                        if ready then
                            status, action, color = 'READY', 'ADD', C.green
                        else
                            status = reason == 'party_full' and 'PARTY FULL' or 'UNAVAILABLE'
                        end
                    end
                    local art = catalog[name] or entry
                    local portrait = self:_compact_headshot_path(art)
                    local portrait_size = math.max(38, math.ceil(30 / self.scale))
                    local button_width = math.max(70, math.ceil(46 / self.scale))
                    local name_width = inner - portrait_size - button_width - 26
                    local names = self:_wrap_synergy_popup_text(name, name_width, font, true)
                    local statuses = self:_wrap_synergy_popup_text(status, name_width, font, false)
                    append({kind='partner', key=group.id .. ':partner:' .. index,
                        active=active and present[name] == true,
                        name=name, names=names, statuses=statuses, entry=entry,
                        portrait=portrait, portrait_size=portrait_size,
                        button_width=button_width, name_width=name_width,
                        status=status, status_color=color, action=action,
                        height=math.max(portrait_size + 12,
                            (#names + #statuses) * step + 12)})
                end
            end
            append({kind='separator', key=group.id .. ':separator', height=14})
        end
        return rows
    end

    function UI:_render_synergy_popup_row(row, x, y, width, top, bottom)
        local key = tostring(self.synergy_popup_trust) .. ':' .. row.key
        local font, step = row.font_size, row.line_step
        local function rect(rx, ry, rw, rh, color, alpha, kind, suffix)
            local clipped_top, clipped_bottom = math.max(top, ry), math.min(bottom, ry + rh)
            if clipped_bottom > clipped_top then
                self:_add_rect(rx, clipped_top, rw, clipped_bottom - clipped_top,
                    color, alpha, 'synergy_popup_' .. kind, key .. (suffix or ''))
            end
        end
        local function rounded(rx, ry, rw, rh, color, alpha, kind, mask)
            if ry >= top and ry + rh <= bottom then
                self:_add_mask(mask or 'assets/ui/roster-panel-rounded-mask.png',
                    rx, ry, rw, rh, color, alpha,
                    'synergy_popup_' .. kind, key)
            else
                rect(rx, ry, rw, rh, color, alpha, kind)
            end
        end
        local function lines(copy, tx, ty, tw, color, bold, kind)
            for index, text in ipairs(copy or {}) do
                local line_y = ty + (index - 1) * step
                if line_y >= top and line_y + step <= bottom then
                    self:_add_left_fitted_text(text, tx, line_y, tw, step, font,
                        color, 'Arial', bold, 0, 0, 100, 'synergy_popup_' .. kind,
                        key .. ':' .. index, popup.min_font_pixels)
                end
            end
        end
        if row.kind == 'group' then
            rounded(x + 1, y + 1, width - 2, row.height - 1, C.panel_alt, 255,
                'group_background')
            lines(row.lines, x + 12, y + 6, width - 24, C.gold_bright, true, 'group')
        elseif row.kind == 'condition' or row.kind == 'note'
                or row.kind == 'requirement' then
            lines(row.lines, x + 12, y + 4, width - 24,
                row.kind == 'note' and C.retry
                    or row.kind == 'requirement' and C.gold_dim
                    or C.muted, false, row.kind)
        elseif row.kind == 'effect' then
            if row.actor_divider then
                rect(x + 12, y + 3, width - 24, 1,
                    C.dim, 72, 'effect_divider')
            end
            local text_y = y + row.divider_height + row.padding / 2
            local ability_x = x + 12 + row.actor_width + row.gap
            lines(row.names, x + 12, text_y, row.actor_width,
                C.white, true, 'effect_name')
            lines(row.abilities, ability_x, text_y,
                row.narrow and row.body_width or row.ability_width,
                row.active and C.retry or C.gold_bright, false, 'effect_ability')
            local copy_x = row.narrow and ability_x or ability_x + row.ability_width + row.gap
            local copy_y = text_y + (row.narrow and #row.abilities * step or 0)
            lines(row.descriptions, copy_x, copy_y, row.effect_width,
                C.white, false, 'effect')
        elseif row.kind == 'partners_label' then
            rect(x + 12, y + 5, width - 24, 1, C.dim, 140, 'partners_divider')
            lines(row.lines, x + 12, y + 12, width - 24,
                C.muted, true, 'partners_label')
        elseif row.kind == 'partner' and y >= top and y + row.height <= bottom then
            local hover = 'synergy_popup:partner:' .. key
            local action_hover = 'synergy_popup:partner_action:' .. key
            local action_hovered = row.action and self.hover_key == action_hover
            local action_pressed = row.action and self.pressed_key == action_hover
            local hovered = self.hover_key == hover or action_hovered
            rounded(x + 8, y + 2, width - 16, row.height - 4,
                hovered and C.dropdown_selected or C.shell, 255, 'partner_row')
            local px, py = x + 12, y + (row.height - row.portrait_size) / 2
            if row.active then
                -- Keep the ring wholly outside the portrait: Windower can
                -- reveal a newly active image above an already-visible one.
                local margin = math.max(2, math.ceil(2 / self.scale))
                self:_add_mask('assets/ui/synergy-portrait-ring.png',
                    px - margin, py - margin,
                    row.portrait_size + margin * 2, row.portrait_size + margin * 2,
                    C.retry, 115, 'synergy_popup_active_portrait_border', key)
                self.synergy_popup_active_portrait_count =
                    self.synergy_popup_active_portrait_count + 1
            end
            rect(px, py, row.portrait_size, row.portrait_size,
                C.button_disabled, 255, 'partner_portrait_background')
            if row.portrait then
                local dim = row.status == 'NOT LEARNED'
                self:_add_image(row.portrait, px, py, row.portrait_size, row.portrait_size,
                    dim and {r=125,g=125,b=125} or C.white, dim and 170 or 255,
                    'synergy_popup_partner_portrait', key)
            else
                self:_add_centered_text('?', px, py, row.portrait_size, row.portrait_size,
                    font, C.muted, 'Arial', true, 0, font, 100, 0,
                    'synergy_popup_partner_placeholder', key, 0, false, popup.min_font_pixels)
            end
            local tx = px + row.portrait_size + 10
            local ty = y + (row.height - (#row.names + #row.statuses) * step) / 2
            lines(row.names, tx, ty, row.name_width, C.white, true, 'partner_name')
            lines(row.statuses, tx, ty + #row.names * step,
                row.name_width, row.status_color, false, 'partner_status')
            local bx = x + width - row.button_width - 12
            local bh = math.max(32, step + 6)
            local by = y + (row.height - bh) / 2
            rounded(bx, by, row.button_width, bh,
                row.action and (action_hovered and C.cyan or C.muted) or C.dim,
                row.action and (action_pressed and 255
                    or (action_hovered and 245 or 185)) or 150,
                'partner_action_border',
                'assets/ui/active-action-capsule-border-mask.png')
            rounded(bx + 1, by + 1, row.button_width - 2, bh - 2,
                not row.action and C.button_disabled
                    or (action_pressed and C.button_capsule_pressed
                        or (action_hovered and C.button_hot or C.shell)),
                row.action and (action_pressed and 220
                    or (action_hovered and 205 or 105)) or 125,
                'partner_action_fill',
                'assets/ui/active-action-capsule-mask.png')
            self:_add_centered_text(row.action or 'ADD', bx, by, row.button_width, bh,
                font, row.action and (action_hovered and C.gold_bright
                    or C.white) or C.muted, 'Arial', true,
                0, font, 100, -3, 'synergy_popup_partner_action_text', key,
                0, false, popup.min_font_pixels)
            self:_hitbox(x + 8, y, width - 16, row.height, nil,
                'synergy_popup_partner_row', hover)
            if row.action then
                self:_hitbox(bx, by, row.button_width, bh, function()
                    self:_select_entry(row.entry, row.action == 'UNDO')
                end, 'synergy_popup_partner_action', action_hover)
            end
        end
    end

    function UI:_render_synergy_popup()
        self.synergy_popup_active_portrait_count = 0
        local name = self.synergy_popup_trust
        if not name or self.mode ~= 'expanded' then return end
        local groups = self:_roster_synergy_groups({en=name})
        if #groups == 0 then self:_close_synergy_popup(); return end
        local x, y, width = theme.base_width - popup.width - popup.edge, popup.y, popup.width
        local font = self:_synergy_popup_font_size(10)
        local heading = self:_synergy_popup_font_size(12)
        local heading_step = math.ceil(heading * 4 / 3 + 7)
        local step = math.ceil(font * 4 / 3 + 5)
        local name_lines = self:_wrap_synergy_popup_text(name, width - 62, heading, true)
        local header_height = 24 + heading_step * (1 + #name_lines) + step + 14
        local rows, total_height = self:_synergy_popup_rows(name), 0
        for _, row in ipairs(rows) do total_height = total_height + row.height end
        local height = math.min(popup.height, header_height + total_height + 12)
        if windower and type(windower.get_windower_settings) == 'function' then
            local ok, screen = pcall(windower.get_windower_settings)
            if ok and type(screen) == 'table' then
                local screen_height, screen_width = tonumber(screen.ui_y_res), tonumber(screen.ui_x_res)
                if screen_height and screen_height > 32 then
                    height = math.min(height, (screen_height - 16) / self.scale)
                    local screen_top = (8 - self:_origin_y()) / self.scale
                    local screen_bottom = (screen_height - 8 - self:_origin_y()) / self.scale
                    y = theme.clamp(y, screen_top, screen_bottom - height)
                end
                if screen_width and screen_width > self:_s(width) + 16 then
                    x = theme.clamp(x, (8 - self:_origin_x()) / self.scale,
                        (screen_width - 8 - self:_origin_x()) / self.scale - width)
                end
            end
        end
        self.synergy_popup_bounds = {x=x, y=y, width=width, height=height}
        self:_add_mask('assets/ui/roster-panel-rounded-mask.png',
            x, y, width, height, C.gold_dim, 255, 'synergy_popup_border')
        self:_add_mask('assets/ui/roster-panel-inner-rounded-mask.png',
            x + 1, y + 1, width - 2, height - 2, C.popup_surface, 255,
            'synergy_popup_background')
        self:_hitbox(x, y, width, height, nil, 'synergy_popup_surface', 'synergy_popup:surface')
        self:_add_text('TRUST SYNERGY', x + 12, y + 10, heading, C.gold_bright,
            'Arial', false, 100, 'synergy_popup_title', nil, popup.min_font_pixels)
        local divider_y = y + 13 + heading_step
        self:_add_rect(x + 12, divider_y, width - 24, 1,
            C.dim, 120, 'synergy_popup_header_divider')
        for index, line in ipairs(name_lines) do
            self:_add_text(line, x + 12, y + 20 + index * heading_step, heading,
                C.white, 'Arial', true, 100, 'synergy_popup_trust_name', index,
                popup.min_font_pixels)
        end
        self:_add_text(('%d SYNERGY GROUP%s'):format(#groups, #groups == 1 and '' or 'S'),
            x + 12, y + 20 + (#name_lines + 1) * heading_step, font,
            C.muted, 'Arial', false, 100, 'synergy_popup_group_count', nil, popup.min_font_pixels)
        local close_size = math.max(24, math.ceil(24 / self.scale))
        local close_top = math.max(2,
            math.min(8, divider_y - y - close_size - 4))
        close_size = math.min(close_size,
            divider_y - y - close_top - 4)
        local close_y = y + close_top
        local close_x = x + width - close_size - 9
        local close_asset = self.pressed_key == 'synergy_popup:close'
            and 'assets/ui/close-button-pressed.png'
            or 'assets/ui/close-button-subtle.png'
        local close_path = self:_asset(close_asset)
        if self:_exists(close_path) then
            self:_add_image(close_path, close_x, close_y, close_size, close_size,
                self.hover_key == 'synergy_popup:close' and C.white or C.muted,
                255, 'synergy_popup_close')
        else
            self:_add_rect(close_x, close_y, close_size, close_size,
                C.button, 255, 'synergy_popup_close')
            self:_add_centered_text('X', close_x, close_y, close_size, close_size, font,
                C.white, 'Arial', true, 0, font, 100, 0,
                'synergy_popup_close_text', nil, 0, false, popup.min_font_pixels)
        end
        self:_hitbox(close_x, close_y, close_size, close_size, function()
            self:_close_synergy_popup()
            self:render(false)
        end, 'synergy_popup_close', 'synergy_popup:close')
        local content_y, bottom = y + header_height, y + height - 12
        local content_height = bottom - content_y
        self.synergy_popup_max_scroll = math.max(0, total_height - content_height)
        self.synergy_popup_scroll = theme.clamp(self.synergy_popup_scroll, 0,
            self.synergy_popup_max_scroll)
        -- Group borders are allocated before their row images/portraits.
        local row_y, group_y, group_key = content_y - self.synergy_popup_scroll
        for _, row in ipairs(rows) do
            if row.kind == 'group' then group_y, group_key = row_y, name .. ':' .. row.key end
            if row.kind == 'separator' and group_y then
                local panel_top, panel_bottom = math.max(content_y, group_y), math.min(bottom, row_y + 4)
                if panel_bottom > panel_top then
                    local full_panel = group_y >= content_y and row_y + 4 <= bottom
                    local border_mask = 'assets/ui/roster-panel-rounded-mask.png'
                    local fill_mask = 'assets/ui/roster-panel-inner-rounded-mask.png'
                    if full_panel then
                        self:_add_mask(border_mask, x + 12, panel_top,
                            width - 24, panel_bottom - panel_top,
                            C.dim, 230, 'synergy_popup_group_border', group_key)
                        self:_add_mask(fill_mask, x + 13, panel_top + 1,
                            width - 26, math.max(1, panel_bottom - panel_top - 2),
                            C.panel, 255, 'synergy_popup_group_fill', group_key)
                    else
                        self:_add_rect(x + 12, panel_top, width - 24,
                            panel_bottom - panel_top,
                            C.dim, 230, 'synergy_popup_group_border', group_key)
                        self:_add_rect(x + 13, panel_top + 1, width - 26,
                            math.max(1, panel_bottom - panel_top - 2),
                            C.panel, 255, 'synergy_popup_group_fill', group_key)
                    end
                end
            end
            row_y = row_y + row.height
        end
        row_y = content_y - self.synergy_popup_scroll
        for _, row in ipairs(rows) do
            if row_y + row.height > content_y and row_y < bottom then
                self:_render_synergy_popup_row(row, x + 12, row_y, width - 24, content_y, bottom)
            end
            row_y = row_y + row.height
        end
        if self.synergy_popup_max_scroll > 0 then
            local thumb = math.max(24, content_height * content_height / total_height)
            local thumb_y = content_y + (content_height - thumb)
                * self.synergy_popup_scroll / self.synergy_popup_max_scroll
            self:_add_rect(x + width - 7, content_y, 3, content_height,
                C.dim, 160, 'synergy_popup_scroll_track')
            self:_add_rect(x + width - 7, thumb_y, 3, thumb,
                C.cyan, 220, 'synergy_popup_scroll_thumb')
        end
    end

    function UI:_update_synergy_popup_portrait_pulse(now)
        local phase = (tonumber(now) or self.clock()) * (math.pi * 2 / 2.8)
        local alpha = math.floor(115 + 35 * math.sin(phase) + 0.5)
        local updated = false
        for _, record in pairs(self.keyed_pool.synergy_popup_active_portrait_border or {}) do
            if record.frame == self.frame_id and record.visible
                    and not record.texture_ready_frame then
                if record.image_alpha ~= alpha then
                    record.object:alpha(alpha)
                    record.image_alpha = alpha
                    record.alpha = alpha
                end
                updated = true
            end
        end
        return updated
    end

    function UI:_hide_synergy_underlay_text()
        local bounds = self.synergy_popup_trust and self.mode == 'expanded'
            and self.synergy_popup_bounds
        local function covered_card(card)
            return bounds and card and card.x < bounds.x + bounds.width
                and card.x + card.width > bounds.x
                and card.y < bounds.y + bounds.height
                and card.y + card.height > bounds.y
        end
        local all_cards_covered = false
        if bounds then
            local seen_cards, card_count, covered_count = {}, 0, 0
            for _, records in pairs(self.object_pool) do
                for _, record in ipairs(records) do
                    local card = record.frame == self.frame_id
                        and record.card_bounds or nil
                    if card and not seen_cards[card.y] then
                        seen_cards[card.y] = true
                        card_count = card_count + 1
                        if covered_card(card) then
                            covered_count = covered_count + 1
                        end
                    end
                end
            end
            all_cards_covered = card_count > 0
                and covered_count == card_count
        end
        for _, records in pairs(self.object_pool) do
            for _, record in ipairs(records) do
                record.synergy_obscured = false
                if bounds and record.frame == self.frame_id
                        and not tostring(record.kind):match('^synergy_popup_') then
                    local left, top = self:_s(bounds.x), self:_s(bounds.y)
                    local right, bottom = left + self:_s(bounds.width), top + self:_s(bounds.height)
                    local rx, ry = record.x or 0, record.y or 0
                    local rw, rh = record.image_width or 0, record.image_height or 0
                    if record.is_text then
                        rx, ry = rx - 2, ry - 3
                        rw = theme.measure(record.value or '', record.font_size or 8,
                            record.font or 'Arial', record.bold) + 4
                        rh = (record.font_size or 8) * 1.8 + 6
                    end
                    -- The window shell remains beneath the popup; all intersecting
                    -- card layers (including newly allocated ones) are suppressed.
                    local shell = not record.is_text and rx <= left and ry <= top
                        and rx + rw >= right and ry + rh >= bottom
                    record.synergy_obscured =
                        (all_cards_covered and record.key == 'dismiss_all')
                        or covered_card(record.card_bounds)
                        or (not shell and rx < right and rx + rw > left
                            and ry < bottom and ry + rh > top)
                    if record.synergy_obscured and record.visible then
                        record.object:hide()
                        record.visible = false
                    end
                end
            end
        end
        -- Outside clicks close and redraw first, restoring covered card targets.
        for index = #self.hitboxes, 1, -1 do
            if covered_card(self.hitboxes[index].card_bounds)
                    or (all_cards_covered
                        and self.hitboxes[index].hover_key
                            == 'dismiss_all_button') then
                table.remove(self.hitboxes, index)
            end
        end
    end
end
