-- Trust pair/group interactions collected from BG-Wiki's Trust index.
--
-- This is deliberately data-only so the UI can present numeric bonuses,
-- partner-specific behavior, skillchain notes, and uncertain reports without
-- assuming every entry is the same kind of stat buff.

local master_url = 'https://www.bg-wiki.com/ffxi/BGWiki:Trusts'

local function bgwiki_source(section, fragment)
    local anchor = fragment or section:gsub(' ', '_')
    return {
        label = 'BG-Wiki: Trusts - ' .. section,
        url = master_url .. '#' .. anchor,
    }
end

local synergy = {
    source = {
        name = 'BG-Wiki:Trusts',
        url = master_url,
        accessed = '2026-09-26',
        non_empty_sections_reviewed = 44,
        note = 'Repeated member-side entries are normalized; unresolved partner candidates remain separate pairs.',
    },
    cross_reference = {
        name = 'FFXIclopedia',
        url = 'https://ffxiclopedia.fandom.com/wiki/Category:Trust',
        accessed = '2026-09-26',
        note = 'Relevant Trust pages were checked in batches for extra effects; dialogue alone is not treated as a combat effect.',
    },
    additional_cross_reference = {
        name = 'Gamer Escape',
        url = 'https://ffxi.gamerescape.com/wiki/Category:Trust',
        accessed = '2026-09-26',
        note = 'Search-result checks for unresolved pairings exposed party dialogue but no additional combat effects.',
    },

-- confidence values: documented, reported, estimated, mixed, unverified.
-- kind values: party_bonus, behavior, skillchain, relationship, unverified.
-- value_status values mark missing/approximate data: approximate, uncertain,
-- partially_reported, not_reported, condition_unspecified.
-- detail_status='missing_details' keeps listed candidate pairs whose effect or
-- activation condition is not documented; these entries have no effects.
-- values_by_group_size stores numeric scaling separately from display text so
-- a popup can render either a comparison table or a natural-language sentence.
-- source_text stores verbatim, source-linked excerpts; text/trigger/summary are
-- the normalized, source-neutral copy intended for display.
-- research_notes hold source commentary that must never appear in the popup.
    groups = {
        {
            id = 'ark_angel_quintet',
            -- Ark Angel spell names are abbreviated in Windower's spell
            -- resources and card_assets.lua, so keep runtime keys here.
            members = {'AAEV', 'AAHM', 'AAMR', 'AAGK', 'AATT'},
            kind = 'party_bonus',
            confidence = 'estimated',
            trigger = 'When all five Ark Angels are in the party.',
            summary = 'All five Ark Angels gain a defensive bonus.',
            effects = {
                {trust='All five Ark Angels', text='Magic Evasion: ~+240 (~50%).', confidence='estimated', value_status='approximate', source='BG-Wiki'},
                {trust='All five Ark Angels', text='Magic Defense: increases.', confidence='reported', value_status='not_reported', source='FFXIclopedia'},
            },
            research_notes = {
                'The Magic Evasion estimate is flagged for verification.',
                'A separate report names Magic Defense; the two stat claims remain separate.',
                'The bonus is described as a reference to the Accumulative Magic Resistance used in Divine Might.',
            },
            source = bgwiki_source('Ark Angel EV'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Ark_Angel_EV', text=[=[ArkEV / ArkHM / ArkMR / ArkGK / ArkTT: When all 5 Ark Angels are summoned, they possess a Magic Evasion bonus (see: Resist). Estimated 240 Magic Evasion, a 50% increase. The bonus is a reference to the Accumulative Magic Resistance that was added to counter the strategy of clearing Divine Might with an alliance of Black Mages.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:AAEV', text=[=[When all five Ark Angels trusts are present, they gain a bonus to magic defense (this is related to an update to Divine Might).]=]},
            },
            references = {
                {label='Official Synergy Hint', url='https://forum.square-enix.com/ffxi/threads/53227'},
                {label='Accumulative Magic Resistance', url='http://www.playonline.com/pcd/topics/ff11us/detail/675/detail.html'},
                {label='FFXIclopedia: Ark Angel EV', url='https://ffxiclopedia.fandom.com/wiki/Trust:AAEV'},
                {label='FFXIclopedia: Ark Angel GK', url='https://ffxiclopedia.fandom.com/wiki/Trust:AAGK'},
            },
        },
        {
            id = 'curilla_rainemard',
            members = {'Curilla', 'Rainemard'},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When Curilla and Rainemard are in the party.',
            summary = 'Rainemard prioritizes Curilla with enhancing magic.',
            effects = {
                {trust='Rainemard', text='Haste, Phalanx, and Refresh: casts on Curilla.', value_status='not_reported', source='FFXIclopedia'},
                {trust='Rainemard', text='Phalanx II: reduces damage taken by 35 for Curilla and Rainemard (level 75+).', value_status='condition_unspecified', source='BG-Wiki'},
            },
            research_notes = {
                'Rainemard’s high enhancing-magic skill may increase Phalanx and enspell potency.',
            },
            source = bgwiki_source('Curilla'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Curilla', text=[=[Curilla: Rainemard casts Phalanx II (unlocked at level 75) only on Curilla and himself. His Phalanx, like his Enspells, also appears to benefit from his extremely high enhancing magic skill, his Phalanx II is -35 damage.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Curilla', text=[=[Synergy: Trust: Rainemard (her father) will cast Haste/Phalanx/Refresh on her.]=]},
            },
            references = {
                {label='FFXIclopedia: Curilla', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Curilla'},
            },
        },
        {
            id = 'nashmeira_automata',
            members = {'Nashmeira', 'Mnejing', 'Ovjang'},
            activation = {required={'Nashmeira'}, any={'Mnejing', 'Ovjang'}},
            kind = 'party_bonus',
            confidence = 'documented',
            trigger = 'When Nashmeira is in the party with Mnejing, Ovjang, or both.',
            summary = 'Each automaton companion receives a different bonus.',
            effects = {
                {trust='Mnejing', text='Defense: +10%'},
                {trust='Mnejing', text='Enmity: +10%'},
                {trust='Ovjang', text='Enmity: -10%'},
                {trust='Ovjang', text='Magic Damage: +10%'},
            },
            source = bgwiki_source('Nashmeira'),
            references = {
                {label='Official Note', url='https://forum.square-enix.com/ffxi/threads/40822-Freshly-Picked-Vana%E2%80%99diel-5-Digest?p=499745&viewfull=1'},
                {label='FFXIclopedia: Nashmeira', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Nashmeira'},
                {label='FFXIclopedia: Ovjang', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ovjang'},
            },
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Nashmeira', text=[=[Nashmeira: Mnejing receives increased defense (+10%) and increased enmity (+10%) (not compatible with Nashmeira II).]=]},
                {source='BG-Wiki', url=master_url .. '#Ovjang', text=[=[Nashmeira: Ovjang receives reduced enmity (-10%) and increased magic damage (+10%).]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Nashmeira', text=[=[Provides synergy bonuses to Trust: Ovjang and Trust: Mnejing while summoned in the same party.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Mnejing', text=[=[Receives increased defense and increased enmity while Nashmeira is in the party.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ovjang', text=[=[Receives reduced enmity and increased magic damage while Nashmeira is in the party.]=]},
            },
        },
        {
            id = 'rughadjeen_serpent_generals',
            display_name = 'Serpent Generals',
            members = {'Rughadjeen', 'Mihli Aliapoh', 'Gadalar', 'Najelith', 'Zazarg'},
            activation = {required={'Rughadjeen'},
                any={'Mihli Aliapoh', 'Gadalar', 'Najelith', 'Zazarg'}},
            kind = 'party_bonus',
            confidence = 'mixed',
            trigger = 'When Rughadjeen is in the party with at least one other Serpent General.',
            summary = 'Rughadjeen and the other Serpent Generals receive member-specific bonuses.',
            effects = {
                {trust='Mihli Aliapoh', text='Cure Potency: +25%'},
                {trust='Gadalar', text='Magic Attack Bonus: +25'},
                {trust='Najelith', text='Ranged Accuracy: +40'},
                {trust='Najelith', text='Barrage: accuracy increases.', value_status='not_reported'},
                {trust='Zazarg', text='Damage: ~+5-15%.', confidence='estimated', value_status='uncertain'},
                {trust='Rughadjeen', text='Damage Taken: -29% while in combat.'},
                {trust='Rughadjeen', text='Enfire: changes to Enlight when all four other Serpent Generals are in the party.', condition='All four other Serpent Generals are in the party.', source='FFXIclopedia'},
                {trust='Rughadjeen', text='Sentinel: becomes available.', value_status='condition_unspecified', source='FFXIclopedia'},
            },
            source = bgwiki_source('Rughadjeen'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Rughadjeen', text=[=[Mihli Aliapoh/Gadalar/Zazarg/Najelith: Rughadjeen empowers the other serpent generals. Mihli Aliapoh gains +25% Cure Potency increase. Gadalar gains +25 Magic Attack Bonus. Najelith gains +40 ranged accuracy and enhanced Barrage accuracy. Zazarg gains ~5-15%{{question}} damage. When any other serpent generals are in the party, Rughadjeen has Damage Taken -29% while in combat with a foe.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Rughadjeen', text=[=[Enfire effect changes to Enlight when all 4 other serpent generals are present. Sentinel also only available with the other generals.]=]},
            },
            references = {
                {label='Official Synergy Hint', url='https://forum.square-enix.com/ffxi/threads/45544-Freshly-Picked-Vana-diel-14-Digest?p=535931&viewfull=1'},
                {label='FFXIclopedia: Rughadjeen', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Rughadjeen'},
            },
        },
        {
            id = 'trion_pieuje_uc',
            members = {'Trion', 'Pieuje (UC)'},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When Trion and Pieuje (UC) are in the party.',
            summary = 'Pieuje (UC) prioritizes Trion for healing and support.',
            effects = {
                {trust='Pieuje (UC)', text='Regen: casts only on Trion.'},
                {trust='Pieuje (UC)', text='Haste and -na spells: prioritizes Trion, then the player, then other party members.'},
            },
            source = bgwiki_source('Trion'),
            references = {
                {label='FFXIclopedia: Trion', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Trion'},
                {label='FFXIclopedia: Pieuje (UC)', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Pieuje_(UC)'},
            },
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Trion', text=[=[Pieuje (UC) only uses Regen on Trion. Pieuje prioritizes Trion > Player > Others when casting Haste and -na Spells.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Trion', text=[=[Synergy: Receives Regen from his WHM brother Trust: Pieuje (UC).]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Pieuje_(UC)', text=[=[Casts Regen on his PLD brother Trion.]=]},
            },
        },
        {
            id = 'aldo_lion_zeid',
            members = {'Aldo', 'Lion', 'Zeid'},
            activation = {required={'Aldo'}, any={'Lion', 'Zeid'}},
            kind = 'party_bonus',
            confidence = 'mixed',
            trigger = 'When Aldo is in the party with Lion, Zeid, or both.',
            summary = 'Aldo gains partner-specific attack effects; Lion and Zeid gain bonuses by group size.',
            effects = {
                {trust='Aldo', text='Dual Wield: gains a chance for extra attacks with Lion (level 20+).', condition='Lion is present; level 20+.', value_status='not_reported', source='FFXIclopedia'},
                {trust='Aldo', text='Attack: increases with Zeid.', condition='Zeid is present.', value_status='not_reported', source='FFXIclopedia'},
                {trust='Lion', effect='Attack Speed', text='Attack Speed increases with group size: two Trusts (~+6%) or all three (~+12%).', values_by_group_size={[2]={value=6, unit='%'}, [3]={value=12, unit='%'}}, confidence='estimated', value_status='approximate', source='BG-Wiki'},
                {trust='Zeid', effect='Attack', text='Attack increases with group size: two Trusts (~+10%) or all three (~+20%).', values_by_group_size={[2]={value=10, unit='%'}, [3]={value=20, unit='%'}}, confidence='estimated', value_status='approximate', source='BG-Wiki'},
            },
            source = {label='BG-Wiki: Cipher: Aldo', url='https://www.bg-wiki.com/ffxi/Cipher:_Aldo'},
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Aldo', text=[=[Aldo/Lion/Zeid: When two or three of them are in a party together, they gain a power boost from each of the others in the party. Aldo gains an “enhances Dual Wield effect” bonus (Requires level 20 or greater). Adds a chance for extra attacks instead of reducing delay: his TP gain is still multiples of 50. Lion gains an attack speed increase ~6%/~12%. Zeid gains an attack bonus ~10%/~20%.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Aldo', text=[=[When teamed up with Lion (at level 20 minimum), he gains enhanced Dual Wield. With Zeid, he gains enhanced attack. Lion II and Zeid II do not work.]=]},
            },
            references = {
                {label='Official Synergy Hint', url='https://forum.square-enix.com/ffxi/threads/41421-DD-Trusts-are-terrible?p=508133&viewfull=1'},
                {label='Aldo Dual Wield patch note', url='https://forum.square-enix.com/ffxi/threads/43135-Jul-8-2014-%28JST%29-Version-Update?p=514802&viewfull=1'},
                {label='FFXIclopedia: Aldo', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Aldo'},
            },
        },
        {
            id = 'chacharoon_zeids',
            members = {'Chacharoon', 'Zeid', 'Zeid II'},
            activation = {required={'Chacharoon'}, any={'Zeid', 'Zeid II'}},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When Chacharoon is in the party with Zeid or Zeid II.',
            summary = 'Zeid can absorb Chacharoon’s Attack Boost.',
            effects = {
                {trust='Zeid / Zeid II', text='Absorb-Attri: steals Tripe Gripe’s Attack Boost.'},
            },
            source = bgwiki_source('Chacharoon'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Chacharoon', text=[=[Zeid / Zeid II: Zeid can Absorb-Attri to steal the attack bonus granted by Chacharoon's Tripe Gripe.]=]},
            },
        },
        {
            id = 'darrcuiln_morimar',
            members = {'Darrcuiln', 'Morimar'},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When Darrcuiln and Morimar are in the party.',
            summary = 'Morimar affects Darrcuiln’s Weapon Skill usage: 1,000 TP without Morimar’s aura, 1,500-2,000 TP with Morimar’s aura.',
            effects = {
                {trust='Darrcuiln', text='Weapon Skills: uses them at 1,000 TP without waiting for Morimar to be ready to skillchain. While Morimar’s aura is active, waits until 1,500-2,000 TP.'},
            },
            source = bgwiki_source('Darrcuiln'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Darrcuiln', text=[=[Darrcuiln and Morimar will uses TP moves more often when summoned together. Darrcuiln will use TP moves with 1000 TP, regardless of whether Morimar is ready to complete a skillchain or not. If Morimar's aura is up, Darrcuiln behaves normally and saves its TP until 1500-2000.]=]},
            },
        },
        {
            id = 'morimar_teodor_unverified',
            members = {'Morimar', 'Teodor'},
            kind = 'unverified',
            confidence = 'unverified',
            detail_status = 'missing_details',
            trigger = 'Possible pairing: Morimar with Teodor; activation condition unknown.',
            summary = 'Possible pairing; effect details are needed.',
            effects = {},
            notes = {'Party-specific dialogue is documented, but no combat effect is described.'},
            source = bgwiki_source('Morimar'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Morimar', text=[=[Teodor: Unknown]=]},
                {source='BG-Wiki', url='https://www.bg-wiki.com/ffxi/Cipher:_Teodor', text=[=[Morimar: Unknown]=]},
            },
            references = {
                {label='FFXIclopedia: Morimar', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Morimar'},
                {label='FFXIclopedia: Teodor', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Teodor'},
            },
        },
        {
            id = 'mumor_uka',
            members = {'Mumor', 'Uka Totlihn'},
            kind = 'party_bonus',
            confidence = 'estimated',
            trigger = 'When Mumor and Uka Totlihn are in the party.',
            summary = 'Mumor’s Samba duration and Uka’s Waltz potency increase.',
            effects = {
                {trust='Mumor', text='Samba duration: ~+10% (Saber Dance: 108s to 120s).', confidence='estimated', value_status='approximate'},
                {trust='Uka Totlihn', text='Waltz potency: ~+10% (Curing Waltz V: 1,067 to 1,173 HP).', confidence='estimated', value_status='approximate'},
            },
            source = {
                label = 'BG-Wiki: Cipher: Mumor',
                url = 'https://www.bg-wiki.com/ffxi/Cipher:_Mumor',
            },
            references = {
                {label='Official Synergy Hint', url='https://forum.square-enix.com/ffxi/threads/43262-%E2%80%9CFreshly-Picked-Vana%E2%80%99diel-9%E2%80%9D-Digest?p=515770&viewfull=1'},
                {label='FFXIclopedia: Mumor', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Mumor'},
                {label='FFXIclopedia: Uka Totlihn', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Uka_Totlihn'},
            },
            source_text = {
                {source='BG-Wiki', url='https://www.bg-wiki.com/ffxi/Cipher:_Mumor', text=[=[Uka Totlihn: By summoning them both at the same time, the stats of the abilities they use will increase. Mumor gains ~10% enhanced samba duration (stacks with Saber Dance: 108s -> 120s). Uka gains ~10% enhanced waltz potency (Curing Waltz V: 1067 HP -> 1173 HP).]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Mumor', text=[=[Gains increased Samba effect duration with Trust: Uka Totlihn present.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Uka_Totlihn', text=[=[Gains enhanced waltz potency with Trust: Mumor.]=]},
            },
        },
        {
            id = 'noillurie_iroha_ii',
            members = {'Noillurie', 'Iroha II'},
            kind = 'skillchain',
            confidence = 'reported',
            trigger = 'When Noillurie and Iroha II can form a Light skillchain.',
            summary = 'Noillurie frequently opens Light skillchains for Iroha II.',
            effects = {
                {trust='Noillurie', text='Light skillchains: frequently opens with Tachi: Kaiten for Iroha II to follow.'},
            },
            source = bgwiki_source('Noillurie'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Noillurie', text=[=[Excellent skillchain partner with Iroha II due to her frequency in opening Light skillchains with Tachi: Kaiten.]=]},
            },
        },
        {
            id = 'prishe_ulmia',
            members = {'Prishe', 'Ulmia'},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When Prishe and Ulmia are in the party.',
            summary = 'Prishe and Ulmia prioritize support for one another.',
            effects = {
                {trust='Ulmia', text='Sentinel’s Scherzo: uses Pianissimo to cast on Prishe after she takes a large single hit, while two songs are active.', value_status='condition_unspecified'},
                {trust='Prishe', text='Cure: casts on Ulmia when she is below 75% HP.'},
            },
            research_notes = {'This behavior may leave the player without Scherzo after area damage.'},
            source = bgwiki_source('Prishe'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Prishe', text=[=[Prishe and Ulmia will prioritize supporting each other. Ulmia will cast Pianissimo and Sentinel's Scherzo on Prishe if she takes a large amount of damage in a single hit and two songs are already active. This seems to prevent the player from receiving Scherzo after AoE damage. This does not apply to Prishe II. Prishe will cast Cure spells on Ulmia at yellow (75%) HP.]=]},
            },
        },
        {
            id = 'prishe_ii_ulmia',
            members = {'Prishe II', 'Ulmia'},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When Prishe II and Ulmia are in the party.',
            summary = 'Prishe II directs single-target Cure spells to Ulmia.',
            effects = {
                {trust='Prishe II', text='Cure I-IV: casts on Ulmia when she is below 75% HP.'},
            },
            source = bgwiki_source('Prishe II'),
            references = {
                {label='FFXIclopedia: Prishe II', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Prishe_II'},
            },
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Prishe_II', text=[=[Ulmia: Prishe II can cast Cure I - IV only on Ulmia.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Prishe_II', text=[=[Casts Cure Spells on Trust Ulmia when she is below 75% HP (yellow). However she only casts up to Cure IV on her. And not Cure V or Cure VI.]=]},
            },
        },
        {
            id = 'romaa_nanaa_unverified',
            members = {'Romaa Mihgo', 'Nanaa Mihgo'},
            kind = 'unverified',
            confidence = 'unverified',
            detail_status = 'missing_details',
            trigger = 'Possible pairing: Romaa Mihgo with Nanaa Mihgo; activation condition unknown.',
            summary = 'Possible pairing; effect details are needed.',
            effects = {},
            notes = {'Party-specific dialogue is documented, but no combat effect is described.'},
            source = bgwiki_source('Romaa Mihgo'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Romaa_Mihgo', text=[=[Nanaa Mihgo/Lehko Habhoka:{{Information Needed}}]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Romaa_Mihgo', text=[=[Summon (with Lehko Habhoka in the party): Lehko, If you're hungrrry... then maybe I can help you out. Summon (with Nanaa Mihgo in the party): There's something familiarrr about you... Nanaa, was it?]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Nanaa_Mihgo', text=[=[Summoned (with Romaa Mihgo in party): Rrromaa? And what's that smell? It can't be....!?]=]},
            },
            references = {
                {label='FFXIclopedia: Romaa Mihgo', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Romaa_Mihgo'},
                {label='FFXIclopedia: Nanaa Mihgo', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Nanaa_Mihgo'},
            },
        },
        {
            id = 'romaa_lehko_unverified',
            members = {'Romaa Mihgo', 'Lehko Habhoka'},
            kind = 'unverified',
            confidence = 'unverified',
            detail_status = 'missing_details',
            trigger = 'Possible pairing: Romaa Mihgo with Lehko Habhoka; activation condition unknown.',
            summary = 'Possible pairing; effect details are needed.',
            effects = {},
            notes = {'Party-specific dialogue is documented, but no combat effect is described.'},
            source = bgwiki_source('Romaa Mihgo'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Romaa_Mihgo', text=[=[Nanaa Mihgo/Lehko Habhoka:{{Information Needed}}]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Romaa_Mihgo', text=[=[Summon (with Lehko Habhoka in the party): Lehko, If you're hungrrry... then maybe I can help you out.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Lehko_Habhoka', text=[=[Summon (while Romaa is in party): Romaa, come, let us be frrree... together.]=]},
            },
            references = {
                {label='FFXIclopedia: Romaa Mihgo', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Romaa_Mihgo'},
                {label='FFXIclopedia: Lehko Habhoka', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Lehko_Habhoka'},
            },
        },
        {
            id = 'ajido_apururu_uc',
            members = {'Ajido-Marujido', 'Apururu (UC)'},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When Ajido-Marujido and Apururu (UC) are in the party.',
            summary = 'Apururu (UC) prioritizes Ajido-Marujido for support.',
            effects = {
                {trust='Apururu (UC)', text='Haste and status removal: prioritizes Ajido-Marujido, then the player, then herself, then other party members.'},
                {trust='Apururu (UC)', text='Devotion: prioritizes Ajido-Marujido when multiple party members qualify.'},
                {trust='Apururu (UC)', text='Cure Potency: +25%'},
            },
            source = bgwiki_source('Ajido-Marujido'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Ajido-Marujido', text=[=[Apururu: Apururu will prioritize supporting her brother, Ajido-Marujido. Status Removal and Haste priority changes to Ajido-Marujido > Player > Herself > Others. If multiple party members meet the conditions for Devotion, will use it on Ajido-Marujido preferentially. Apururu gains +25% Cure Potency Bonus.]=]},
            },
        },
        {
            id = 'kayeel_robel',
            members = {'Kayeel-Payeel', 'Robel-Akbel'},
            kind = 'behavior',
            confidence = 'mixed',
            trigger = 'When Kayeel-Payeel and Robel-Akbel are in the party.',
            summary = 'Both casters use spells more frequently when paired.',
            effects = {
                {trust='Kayeel-Payeel / Robel-Akbel', text='Spellcasting: casts more frequently.', confidence='reported', value_status='not_reported'},
            },
            source = bgwiki_source('Kayeel-Payeel'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Kayeel-Payeel', text=[=[Robel-Akbel: Robel-Akbel and Kayeel-Payeel will cast spells much more frequently: improved Fast Cast effect{{question}}]=]},
            },
        },
        {
            id = 'chebukki_trio',
            members = {'Kukki-Chebukki', 'Makki-Chebukki', 'Cherukiki'},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When all three siblings are in the party for the Meteor sequence.',
            summary = 'The siblings coordinate a Meteor sequence and regain MP when emoting.',
            effects = {
                {trust='Makki-Chebukki', text='Meteor sequence: starts with the “Meeeeee!” emote.'},
                {trust='Kukki-Chebukki', text='Meteor sequence: follows with the “Tee!” emote and casts Meteor.'},
                {trust='Cherukiki', text='Meteor damage: increases after the “Ooor!” emote.', value_status='not_reported'},
                {trust='Player (Black Mage)', text='Meteor sequence: can join the three siblings.'},
                {trust='All three', text='MP recovery: emotes restore ~+3 MP while the sequence is active.', confidence='estimated', value_status='approximate'},
            },
            source = bgwiki_source('Kukki-Chebukki'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Kukki-Chebukki', text=[=[When all three are present, Makki-Chebukki can cause Kukki-Chebukki to cast Meteor by shouting “MEEE”. Kukki-Chebukki and Cherukiki may join with “TEEE” and “ORRR!” which increases the damage of the spell. A player-BLM CAN join this Meteor-casting. They gain a small amount of mp when they do their emotes. They take turns emoting, so it's like the 3 of them have 1 Refresh (+3mp/tick) effect that they have to share.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Kukki-Chebukki', text=[=[His Meteor damage is boosted when he shouts “Tee!” after Makki-Chebukki starts with “Meeeeee!” and Cherukiki ends with “Ooor!”.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Makki-Chebukki', text=[=[Boosts Kukki-Chebukki's Meteor damage when he shouts “Meeeeee!”, followed by Kukki-Chebukki with “Tee!” and Cherukiki with “Ooor!”.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Cherukiki', text=[=[Boosts Kukki-Chebukki's Meteor damage when she shouts “Ooor!” (only after Makki-Chebukki starts with “Meeeeee!” and Kukki-Chebukki follows with “Tee!”).]=]},
            },
            references = {
                {label='FFXIclopedia: Kukki-Chebukki', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Kukki-Chebukki'},
                {label='FFXIclopedia: Makki-Chebukki', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Makki-Chebukki'},
                {label='FFXIclopedia: Cherukiki', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Cherukiki'},
            },
        },
        {
            id = 'king_of_hearts_shantotto',
            members = {'King of Hearts', 'Shantotto'},
            kind = 'behavior',
            confidence = 'reported',
            trigger = 'When King of Hearts and Shantotto are in the party.',
            summary = 'King of Hearts prioritizes Shantotto for enhancing magic.',
            effects = {
                {trust='King of Hearts', text='Enhancing spells: prioritizes Shantotto over the player and himself.'},
            },
            source = bgwiki_source('Shantotto'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Shantotto', text=[=[King of Hearts uses the full range of his enhancing spells on Shantotto in the same way as on himself and his player and even prioritizes her over the player and himself. Does not apply to Shantotto II or Domina Shantotto.]=]},
            },
        },
        {
            id = 'karaha_robel',
            members = {'Karaha-Baruha', 'Robel-Akbel'},
            kind = 'skillchain',
            confidence = 'reported',
            trigger = 'When Karaha-Baruha and Robel-Akbel are in the party.',
            summary = 'Robel-Akbel opens skillchains for Karaha-Baruha to close.',
            effects = {
                {trust='Robel-Akbel', text='Skillchains: opens when Karaha-Baruha has 1,000 TP.'},
            },
            source = bgwiki_source('Karaha-Baruha'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Karaha-Baruha', text=[=[Robel-Akbel: Robel will prioritize opening skillchains for Karaha to close.]=]},
                {source='BG-Wiki', url=master_url .. '#Robel-Akbel', text=[=[Karaha-Baruha: Robel-Akbel opens skillchains when Karaha-Baruha is at 1000 TP.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Robel-Akbel', text=[=[Opens up skillchains for Karaha-Baruha.]=]},
            },
        },
        {
            id = 'karaha_star_sibyl',
            members = {'Karaha-Baruha', 'Star Sibyl'},
            kind = 'party_bonus',
            confidence = 'reported',
            trigger = 'When Karaha-Baruha and Star Sibyl are in the party.',
            summary = 'Star Sibyl increases Karaha-Baruha’s Auto Refresh and Weapon Skill damage.',
            effects = {
                {trust='Karaha-Baruha', text='Auto Refresh: gains Refresh +2 while in combat (+3 total).'},
                {trust='Karaha-Baruha', text='Indi-Acumen: increases Weapon Skill damage, except Spirit Taker.'},
            },
            research_notes = {'Indi-Acumen also increases damage for Karaha-Baruha’s dark Weapon Skills.'},
            source = bgwiki_source('Karaha-Baruha'),
            references = {
                {label='FFXIclopedia: Karaha-Baruha', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Karaha-Baruha'},
            },
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Karaha-Baruha', text=[=[Star Sibyl: Karaha-Baruha gains an additional 2 MP/tick auto-refresh (3 MP/tick total) while engaged with a foe. Karaha-Baruha uses Dark weapon skills which deal more damage with Star Sibyl's Indi-Acumen effect.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Karaha-Baruha', text=[=[Gains an additional 2MP per tick Auto Refresh in combat when Trust: Star Sibyl is present, and his weapon skills (except Spirit Taker) get a boost from her Indi-Acumen.]=]},
            },
        },
        {
            id = 'ygnas_arcielas',
            members = {'Ygnas', 'Arciela', 'Arciela II'},
            activation = {required={'Ygnas'}, any={'Arciela', 'Arciela II'}},
            kind = 'party_bonus',
            confidence = 'reported',
            trigger = 'When Ygnas is in the party with Arciela or Arciela II.',
            summary = 'Ygnas gains an Indi-Refresh aura with Arciela or Arciela II.',
            effects = {
                {trust='Ygnas', text='Indi-Refresh: gains an aura that grants Refresh +2.'},
            },
            source = bgwiki_source('Ygnas'),
            references = {
                {label='FFXIclopedia: Ygnas', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas'},
            },
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Ygnas', text=[=[Arciela or Arciela II: Ygnas will gain a 2/tick Indi-Refresh.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas', text=[=[Gains a full-time Indi-Refresh aura (2 MP/tick) if either Trust: Arciela or Trust: Arciela II are present.]=]},
            },
        },
        {
            id = 'ygnas_darrcuiln_unverified',
            members = {'Ygnas', 'Darrcuiln'},
            kind = 'unverified',
            confidence = 'unverified',
            detail_status = 'missing_details',
            trigger = 'Possible pairing: Ygnas with Darrcuiln; activation condition unknown.',
            summary = 'Possible pairing; effect details are needed.',
            effects = {},
            notes = {'Party-specific dialogue is documented, but no combat effect is described.'},
            source = bgwiki_source('Ygnas'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Ygnas', text=[=[Darrcuiln/Morimar/August/Teodor/Rosulatia:{{Information Needed}}.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas', text=[=[Summon (while Trust: Darrcuiln is in the party): D...Darry...Let me ride...!]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Darrcuiln', text=[=[Summon (while Trust: Ygnas is in the party): (Yg, I entreat you to not ride me like a chocobo.)]=]},
            },
            references = {
                {label='FFXIclopedia: Ygnas', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas'},
                {label='FFXIclopedia: Darrcuiln', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Darrcuiln'},
            },
        },
        {
            id = 'ygnas_morimar_unverified',
            members = {'Ygnas', 'Morimar'},
            kind = 'unverified',
            confidence = 'unverified',
            detail_status = 'missing_details',
            trigger = 'Possible pairing: Ygnas with Morimar; activation condition unknown.',
            summary = 'Possible pairing; effect details are needed.',
            effects = {},
            notes = {'Party-specific dialogue is documented, but no combat effect is described.'},
            source = bgwiki_source('Ygnas'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Ygnas', text=[=[Darrcuiln/Morimar/August/Teodor/Rosulatia:{{Information Needed}}.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas', text=[=[Summon (while Trust: Morimar is in the party): Morimar...He...hello...]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Morimar', text=[=[Summon (while Trust: Ygnas is in the party): If it isn't th' king himself! I trust you've got things in order back in Adoulin?]=]},
            },
            references = {
                {label='FFXIclopedia: Ygnas', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas'},
                {label='FFXIclopedia: Morimar', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Morimar'},
            },
        },
        {
            id = 'ygnas_august_unverified',
            members = {'Ygnas', 'August'},
            kind = 'unverified',
            confidence = 'unverified',
            detail_status = 'missing_details',
            trigger = 'Possible pairing: Ygnas with August; activation condition unknown.',
            summary = 'Possible pairing; effect details are needed.',
            effects = {},
            notes = {'The checked Trust-page entries do not describe a combat effect.'},
            source = bgwiki_source('Ygnas'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Ygnas', text=[=[Darrcuiln/Morimar/August/Teodor/Rosulatia:{{Information Needed}}.]=]},
            },
            references = {
                {label='FFXIclopedia: Ygnas', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas'},
                {label='FFXIclopedia: August', url='https://ffxiclopedia.fandom.com/wiki/Trust:_August'},
            },
        },
        {
            id = 'ygnas_teodor_unverified',
            members = {'Ygnas', 'Teodor'},
            kind = 'unverified',
            confidence = 'unverified',
            detail_status = 'missing_details',
            trigger = 'Possible pairing: Ygnas with Teodor; activation condition unknown.',
            summary = 'Possible pairing; effect details are needed.',
            effects = {},
            notes = {'Party-specific dialogue is documented, but no combat effect is described.'},
            source = bgwiki_source('Ygnas'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Ygnas', text=[=[Darrcuiln/Morimar/August/Teodor/Rosulatia:{{Information Needed}}.]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas', text=[=[Summon (while Trust: Teodor is in the party): Teodor... Want to play...a game?]=]},
                {source='FFXIclopedia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Teodor', text=[=[Summon (while Trust: Ygnas is in the party): Ygnas, that book of yours may let you cheat at Boom or Bust, but here we play for keeps!]=]},
            },
            references = {
                {label='FFXIclopedia: Ygnas', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas'},
                {label='FFXIclopedia: Teodor', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Teodor'},
            },
        },
        {
            id = 'ygnas_rosulatia_unverified',
            members = {'Ygnas', 'Rosulatia'},
            kind = 'unverified',
            confidence = 'unverified',
            detail_status = 'missing_details',
            trigger = 'Possible pairing: Ygnas with Rosulatia; activation condition unknown.',
            summary = 'Possible pairing; effect details are needed.',
            effects = {},
            notes = {'The checked Trust-page entries do not describe a combat effect.'},
            source = bgwiki_source('Ygnas'),
            source_text = {
                {source='BG-Wiki', url=master_url .. '#Ygnas', text=[=[Darrcuiln/Morimar/August/Teodor/Rosulatia:{{Information Needed}}.]=]},
            },
            references = {
                {label='FFXIclopedia: Ygnas', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Ygnas'},
                {label='FFXIclopedia: Rosulatia', url='https://ffxiclopedia.fandom.com/wiki/Trust:_Rosulatia'},
            },
        },
    },
}

-- Index each shared group under every participating Trust. A Trust can appear
-- in several entries; consumers should display every group in this list.
synergy.by_trust = {}
for _, group in ipairs(synergy.groups) do
    for _, trust_name in ipairs(group.members) do
        local groups = synergy.by_trust[trust_name]
        if not groups then
            groups = {}
            synergy.by_trust[trust_name] = groups
        end
        groups[#groups + 1] = group
    end
end

function synergy.for_trust(trust_name)
    return synergy.by_trust[trust_name] or {}
end

return synergy
