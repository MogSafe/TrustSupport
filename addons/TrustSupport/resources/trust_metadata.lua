-- Official Trust role, affiliation, and signature-skill metadata.
--
-- Source: https://www.playonline.com/ff11us/guide/trust/
-- The first 21 images in the site's "New Alter Egos" section duplicate cards
-- 022-132 in the role sections, so only the 111 categorized cards are indexed.
-- Job labels are maintained as display metadata separately from role labels.

local metadata = {
    source = {
        name = 'FINAL FANTASY XI Official Web Site - Trust',
        url = 'https://www.playonline.com/ff11us/guide/trust/',
        accessed = '2026-09-07',
        card_url_pattern = 'https://www.playonline.com/ff11us/guide/trust/imgs/character/%03d.png',
        first_card = 22,
        last_card = 132,
    },
    roles = {
        tank = {label='Tank', theme='blue'},
        melee = {label='Melee Fighter', theme='red'},
        ranged = {label='Ranged Fighter', official_label='Ranged Figher', theme='red'},
        offensive_caster = {label='Offensive Caster', theme='red'},
        healer = {label='Healer', theme='green'},
        support = {label='Support', theme='green'},
    },
    affiliations = {
        san_doria = {label="The Kingdom of San d'Oria"},
        bastok = {label='The Republic of Bastok'},
        windurst = {label='The Federation of Windurst'},
        jeuno = {label='The Grand Duchy of Jeuno'},
        aht_urhgan = {label='The Empire of Aht Urhgan'},
        adoulin = {label='The Sacred City of Adoulin'},
        unknown = {label='Unknown', official_label='?????'},
    },
    by_name = {
        -- Tank
        ['Curilla'] = {role='tank', affiliation='san_doria', signature='Swift Blade', official_card=22},
        ['Trion'] = {role='tank', affiliation='san_doria', signature='Royal Savior', official_card=23},
        ['Valaineral'] = {role='tank', affiliation='san_doria', signature='Uriel Blade', official_card=24},
        ['Mnejing'] = {role='tank', affiliation='aht_urhgan', signature='Shield Subverter', official_card=25},
        ['Gessho'] = {role='tank', affiliation='unknown', signature='Rinpyotosha', official_card=26},
        ['Rahal'] = {role='tank', affiliation='san_doria', signature='Swift Blade', official_card=27},
        ['Rughadjeen'] = {role='tank', affiliation='aht_urhgan', signature='Victory Beacon', official_card=28},
        ['Amchuchu'] = {role='tank', affiliation='adoulin', signature='Dimidiation', official_card=29},
        ['August'] = {role='tank', affiliation='unknown', signature='Daybreak', official_card=30},

        -- Melee Fighter
        ['Excenmille'] = {role='melee', affiliation='san_doria', signature='Penta Thrust', official_card=31},
        ['Naji'] = {role='melee', affiliation='bastok', signature='Vorpal Blade', official_card=32},
        ['Zeid'] = {role='melee', affiliation='bastok', signature='Abyssal Drain', official_card=33},
        ['Ayame'] = {role='melee', affiliation='bastok', signature='Tachi: Jinpu', official_card=34},
        ['Nanaa Mihgo'] = {role='melee', affiliation='windurst', signature='King Cobra Clamp', official_card=35},
        ['Lion'] = {role='melee', affiliation='unknown', signature='Powder Keg', official_card=36},
        ['Volker'] = {role='melee', affiliation='bastok', signature='Berserk-Ruf', official_card=37},
        ['Tenzen'] = {role='melee', affiliation='unknown', signature='Amatsu: Yukiarashi', official_card=38},
        ['Prishe'] = {role='melee', affiliation='unknown', signature='Nullifying Dropkick', official_card=39},
        ['Iron Eater'] = {role='melee', affiliation='bastok', signature='Steel Cyclone', official_card=40},
        ['Naja Salaheem'] = {role='melee', affiliation='aht_urhgan', signature='Hexa Strike', official_card=41},
        ['Nashmeira'] = {role='melee', affiliation='aht_urhgan', signature='Imperial Authority', official_card=42},
        ['Zazarg'] = {role='melee', affiliation='aht_urhgan', signature='Meteoric Impact', official_card=43},
        ['Lehko Habhoka'] = {role='melee', affiliation='unknown', signature='Debonair Rush', official_card=44},
        ['Luzaf'] = {role='melee', affiliation='unknown', signature='Leaden Salute', official_card=45},
        ['Maat'] = {role='melee', affiliation='jeuno', signature='Bear Killer', official_card=46},
        ['Aldo'] = {role='melee', affiliation='jeuno', signature='Choreographed Carnage', official_card=47},
        ['Fablinix'] = {role='melee', affiliation='unknown', signature='Goblin Rush', official_card=48},
        ['Noillurie'] = {role='melee', affiliation='san_doria', signature='Tachi: Kaiten', official_card=49},
        ['Lhu Mhakaracca'] = {role='melee', affiliation='windurst', signature='Onslaught', official_card=50},
        ['Rainemard'] = {role='melee', affiliation='san_doria', signature='Vorpal Blade', official_card=51},
        ['Excenmille [S]'] = {role='melee', affiliation='san_doria', signature='Orcsbane', official_card=52},
        ['Klara'] = {role='melee', affiliation='bastok', signature='Temblor Blade', official_card=53},
        ['Romaa Mihgo'] = {role='melee', affiliation='windurst', signature='Cobra Clamp', official_card=54},
        ['Mumor'] = {role='melee', affiliation='unknown', signature='Skullbreaker', official_card=55},
        ['Uka Totlihn'] = {role='melee', affiliation='unknown', signature='Judgement', official_card=56},
        ['Cid'] = {role='melee', affiliation='bastok', signature='Fiery Tailings', official_card=57},
        ['Lilisette'] = {role='melee', affiliation='san_doria', signature="Dancer's Fury", official_card=58},
        ['Babban'] = {role='melee', affiliation='unknown', signature='Petal Pirouette', official_card=59},
        ['Abenzio'] = {role='melee', affiliation='unknown', signature='Antiphase', official_card=60},
        ['Gilgamesh'] = {role='melee', affiliation='unknown', signature='Iainuki', official_card=61},
        ['Areuhat'] = {role='melee', affiliation='unknown', signature='Dragon Breath', official_card=62},
        ['Lhe Lhangavo'] = {role='melee', affiliation='adoulin', signature='Dragon Kick', official_card=63},
        ['Chacharoon'] = {role='melee', affiliation='unknown', signature='Sharp Eye', official_card=64},
        ['Mayakov'] = {role='melee', affiliation='san_doria', signature='Coming Up Roses', official_card=65},
        ['Mildaurion'] = {role='melee', affiliation='unknown', signature='Light Blade', official_card=66},
        ['Halver'] = {role='melee', affiliation='san_doria', signature='Impulse Drive', official_card=67},
        ['Zeid II'] = {role='melee', affiliation='bastok', signature='Ground Strike', official_card=68},
        ['Lion II'] = {role='melee', affiliation='unknown', signature='Powder Keg', official_card=69},
        ['Flaviria (UC)'] = {role='melee', affiliation='adoulin', signature="Celidon's Torment", official_card=70},
        ['I. Shield (UC)'] = {role='melee', affiliation='bastok', signature="Soturi's Fury", official_card=71, official_name='Invincible Shield (UC)'},
        ['Jakoh (UC)'] = {role='melee', affiliation='unknown', signature="Sarva's Storm", official_card=72},
        ['Ayame (UC)'] = {role='melee', affiliation='bastok', signature='Tachi: Mudo', official_card=73},
        ['Maat (UC)'] = {role='melee', affiliation='jeuno', signature='Hollow Smite', official_card=74},
        ['Aldo (UC)'] = {role='melee', affiliation='jeuno', signature="Sarva's Storm", official_card=75},
        ['Naja (UC)'] = {role='melee', affiliation='aht_urhgan', signature='Nott', official_card=76, official_name='Naja Salaheem (UC)'},
        ['Rongelouts'] = {role='melee', affiliation='aht_urhgan', signature='Tongue Lash', official_card=77},
        ['Shikaree Z'] = {role='melee', affiliation='unknown', signature='Wheeling Thrust', official_card=78},
        ['Maximilian'] = {role='melee', affiliation='bastok', signature='Swift Blade', official_card=79},
        ['Prishe II'] = {role='melee', affiliation='unknown', signature='Nullifying Dropkick', official_card=80},
        ['Nashmeira II'] = {role='melee', affiliation='aht_urhgan', signature='Imperial Authority', official_card=81},
        ['Lilisette II'] = {role='melee', affiliation='san_doria', signature="Dancer's Fury", official_card=82},
        ['Abquhbah'] = {role='melee', affiliation='aht_urhgan', signature='Salaheem Spirit', official_card=83},
        ['Balamor'] = {role='melee', affiliation='unknown', signature='Last Laugh', official_card=84},
        ['Selh\'teus'] = {role='melee', affiliation='unknown', signature='Luminous Lance', official_card=85},
        ['Ingrid II'] = {role='melee', affiliation='adoulin', signature='Ruthlessness', official_card=86},
        ['Teodor'] = {role='melee', affiliation='unknown', signature='Start from Scratch', official_card=87},
        ['Morimar'] = {role='melee', affiliation='unknown', signature='Vehement Resolution', official_card=88},
        ['Darrcuiln'] = {role='melee', affiliation='unknown', signature='Stalking Prey', official_card=89},
        ['Iroha'] = {role='melee', affiliation='unknown', signature='Amatsu: Gachirin', official_card=90},
        ['Iroha II'] = {role='melee', affiliation='unknown', signature='Rise from Ashes', official_card=91},

        -- Ranged Fighter
        ['Najelith'] = {role='ranged', affiliation='aht_urhgan', signature='Typhonic Arrow', official_card=92},
        ['Elivira'] = {role='ranged', affiliation='bastok', signature='Coronach', official_card=93, official_name='Elivira Gogol'},
        ['Margret'] = {role='ranged', affiliation='adoulin', signature='Arching Arrow', official_card=94},
        ['Semih Lafihna'] = {role='ranged', affiliation='windurst', signature='Stellar Arrow', official_card=95},
        ['Tenzen II'] = {role='ranged', affiliation='unknown', signature='Oisoya', official_card=96},
        ['Makki-Chebukki'] = {role='ranged', affiliation='unknown', signature='Sidewinder', official_card=97},

        -- Offensive Caster
        ['Ajido-Marujido'] = {role='offensive_caster', affiliation='windurst', signature='Elemental Magic', official_card=98},
        ['Shantotto'] = {role='offensive_caster', affiliation='windurst', signature='Elemental Magic', official_card=99},
        ['Gadalar'] = {role='offensive_caster', affiliation='aht_urhgan', signature='Salamander Flame', official_card=100},
        ['Ingrid'] = {role='offensive_caster', affiliation='adoulin', signature='Hexa Strike', official_card=101},
        ['Ovjang'] = {role='offensive_caster', affiliation='aht_urhgan', signature='Sixth Element', official_card=102},
        ['D. Shantotto'] = {role='offensive_caster', affiliation='unknown', signature='Salvation Scythe', official_card=103},
        ['Kukki-Chebukki'] = {role='offensive_caster', affiliation='unknown', signature='Elemental Magic', official_card=104},
        ['Adelheid'] = {role='offensive_caster', affiliation='bastok', signature='Twirling Dervish', official_card=105},
        ['Leonoyne'] = {role='offensive_caster', affiliation='san_doria', signature='Spine Chiller', official_card=106},
        ['Kayeel-Payeel'] = {role='offensive_caster', affiliation='windurst', signature='Gate of Tartarus', official_card=107},
        ['Robel-Akbel'] = {role='offensive_caster', affiliation='windurst', signature='Quietus Sphere', official_card=108},
        ['Rosulatia'] = {role='offensive_caster', affiliation='unknown', signature="Dryad's Kiss", official_card=109},
        ['Ullegore'] = {role='offensive_caster', affiliation='unknown', signature='Bored to Tears', official_card=110},
        ['Mumor II'] = {role='offensive_caster', affiliation='unknown', signature='Firesday Night Fever', official_card=111},
        ['Shantotto II'] = {role='offensive_caster', affiliation='unknown', signature='Final Exam', official_card=112},

        -- Healer
        ['Kupipi'] = {role='healer', affiliation='windurst', signature='Healing Magic', official_card=113},
        ['Mihli Aliapoh'] = {role='healer', affiliation='aht_urhgan', signature='Scouring Bubbles', official_card=114},
        ['Cherukiki'] = {role='healer', affiliation='unknown', signature='Healing Magic', official_card=115},
        ['Ferreous Coffin'] = {role='healer', affiliation='unknown', signature='Randgrith', official_card=116},
        ['Karaha-Baruha'] = {role='healer', affiliation='windurst', signature='Howling Moon', official_card=117},
        ['Pieuje (UC)'] = {role='healer', affiliation='san_doria', signature='Nott', official_card=118},
        ['Apururu (UC)'] = {role='healer', affiliation='windurst', signature='Nott', official_card=119},

        -- Support
        ['Joachim'] = {role='support', affiliation='unknown', signature='Songs', official_card=120},
        ['Ulmia'] = {role='support', affiliation='unknown', signature='Songs', official_card=121},
        ['Sakura'] = {role='support', affiliation='unknown', signature='Healing Magic', official_card=122},
        ['Moogle'] = {role='support', affiliation='unknown', signature='Healing Magic', official_card=123},
        ['Star Sibyl'] = {role='support', affiliation='windurst', signature='Enhancement', official_card=124},
        ['Kuyin Hathdenna'] = {role='support', affiliation='adoulin', signature='Enhancement', official_card=125},
        ['Koru-Moru'] = {role='support', affiliation='windurst', signature='Enhancement', official_card=126},
        ['Arciela'] = {role='support', affiliation='adoulin', signature='Guiding Light', official_card=127},
        ['Qultada'] = {role='support', affiliation='unknown', signature='Detonator', official_card=128},
        ['Brygid'] = {role='support', affiliation='bastok', signature='Enhancement', official_card=129},
        ['Kupofried'] = {role='support', affiliation='unknown', signature='Enhancement', official_card=130},
        ['King of Hearts'] = {role='support', affiliation='windurst', signature='Bludgeon', official_card=131},
        ['Arciela II'] = {role='support', affiliation='unknown', signature="Naakual's Vengeance", official_card=132},
    },
}

-- Display jobs are kept separate from the official role taxonomy because a
-- Trust's combat job and party role are related but not interchangeable.
-- Job fields are audited against BGWiki's Trust database:
-- https://www.bg-wiki.com/ffxi/BGWiki:Trusts
local JOB_LABELS = {
    ['Curilla'] = 'PLD/PLD', ['Trion'] = 'PLD/WAR',
    ['Valaineral'] = 'PLD/WAR', ['Mnejing'] = 'PLD/PLD',
    ['Gessho'] = 'NIN/WAR', ['Rahal'] = 'PLD/WAR',
    ['Rughadjeen'] = 'PLD/PLD', ['Amchuchu'] = 'RUN/WAR',
    ['August'] = 'PLD/WAR',
    ['Excenmille'] = 'PLD/PLD', ['Naji'] = 'WAR/WAR',
    ['Zeid'] = 'DRK/DRK', ['Ayame'] = 'SAM/SAM',
    ['Nanaa Mihgo'] = 'THF/THF', ['Lion'] = 'THF/THF',
    ['Volker'] = 'WAR/WAR', ['Tenzen'] = 'SAM/SAM',
    ['Prishe'] = 'MNK/WHM', ['Iron Eater'] = 'WAR/WAR',
    ['Naja Salaheem'] = 'MNK/WAR', ['Nashmeira'] = 'PUP/WHM',
    ['Zazarg'] = 'MNK/MNK', ['Lehko Habhoka'] = 'THF/BLM',
    ['Luzaf'] = 'COR/NIN', ['Maat'] = 'MNK/THF', ['Aldo'] = 'THF/NIN',
    ['Fablinix'] = 'THF/RDM', ['Noillurie'] = 'SAM/PLD',
    ['Lhu Mhakaracca'] = 'BST/WAR', ['Rainemard'] = 'RDM/PLD',
    ['Excenmille [S]'] = 'WAR/PLD', ['Klara'] = 'WAR/WAR',
    ['Romaa Mihgo'] = 'THF/WAR', ['Mumor'] = 'DNC/WAR',
    ['Uka Totlihn'] = 'DNC/WAR', ['Cid'] = 'WAR/RNG',
    ['Lilisette'] = 'DNC/DNC', ['Babban'] = 'MNK/MNK',
    ['Abenzio'] = 'MNK/WAR', ['Gilgamesh'] = 'SAM/WAR',
    ['Areuhat'] = 'WAR/PLD', ['Lhe Lhangavo'] = 'MNK/WAR',
    ['Chacharoon'] = 'THF/RNG', ['Mayakov'] = 'DNC/WAR',
    ['Mildaurion'] = 'PLD/SAM', ['Halver'] = 'PLD/WAR',
    ['Zeid II'] = 'DRK/WAR', ['Lion II'] = 'THF/NIN',
    ['Flaviria (UC)'] = 'DRG/WAR', ['I. Shield (UC)'] = 'WAR/COR',
    ['Jakoh (UC)'] = 'THF/WAR', ['Ayame (UC)'] = 'SAM/WAR',
    ['Maat (UC)'] = 'MNK/WAR', ['Aldo (UC)'] = 'THF/NIN',
    ['Naja (UC)'] = 'MNK/WAR', ['Rongelouts'] = 'WAR/WAR',
    ['Shikaree Z'] = 'DRG/WHM', ['Maximilian'] = 'THF/NIN',
    ['Prishe II'] = 'WHM/MNK', ['Nashmeira II'] = 'WHM/PUP',
    ['Lilisette II'] = 'DNC/WAR', ['Abquhbah'] = 'WAR/MNK',
    ['Balamor'] = 'DRK/BLM', ['Selh\'teus'] = 'PLD/SAM',
    ['Ingrid II'] = 'WHM/WAR', ['Teodor'] = 'BLM/DRK',
    ['Morimar'] = 'WAR/BST', ['Darrcuiln'] = 'WAR/RDM',
    ['Iroha'] = 'SAM/WHM', ['Iroha II'] = 'SAM/WHM/BLM',
    ['Najelith'] = 'RNG/RNG', ['Elivira'] = 'RNG/WAR', ['Margret'] = 'RNG/THF',
    ['Semih Lafihna'] = 'RNG/WAR', ['Tenzen II'] = 'SAM/RNG',
    ['Makki-Chebukki'] = 'RNG/BLM',
    ['Ajido-Marujido'] = 'BLM/RDM', ['Shantotto'] = 'BLM/BLM',
    ['Gadalar'] = 'BLM/BLM', ['Ingrid'] = 'WHM/WHM',
    ['Ovjang'] = 'RDM/BLM', ['D. Shantotto'] = 'BLM/DRK',
    ['Kukki-Chebukki'] = 'BLM/BLM', ['Adelheid'] = 'SCH/BLM',
    ['Leonoyne'] = 'BLM/PLD', ['Kayeel-Payeel'] = 'BLM/SMN',
    ['Robel-Akbel'] = 'BLM/SMN', ['Rosulatia'] = 'BLM/DRK',
    ['Ullegore'] = 'BLM/DRK', ['Mumor II'] = 'BLM/DNC',
    ['Shantotto II'] = 'BLM/WHM',
    ['Kupipi'] = 'WHM/WHM', ['Mihli Aliapoh'] = 'WHM/WHM',
    ['Cherukiki'] = 'WHM/BLM', ['Ferreous Coffin'] = 'WHM/WAR',
    ['Karaha-Baruha'] = 'WHM/SMN', ['Pieuje (UC)'] = 'WHM/PLD',
    ['Apururu (UC)'] = 'WHM/RDM',
    ['Joachim'] = 'BRD/WHM', ['Ulmia'] = 'BRD/BRD',
    ['Sakura'] = 'GEO/BRD', ['Moogle'] = 'GEO/BRD',
    ['Star Sibyl'] = 'GEO/BRD', ['Kuyin Hathdenna'] = 'GEO/BRD',
    ['Koru-Moru'] = 'RDM/WHM', ['Arciela'] = 'RDM/PLD',
    ['Qultada'] = 'COR/RNG', ['Brygid'] = 'GEO/BRD',
    ['Kupofried'] = 'GEO/BRD', ['King of Hearts'] = 'RDM/WHM',
    ['Arciela II'] = 'RDM/BLM',
}

local function compact_job_label(label)
    local parts = {}
    local seen = {}
    for part in tostring(label or ''):gmatch('[^/]+') do
        if not seen[part] then
            parts[#parts + 1] = part
            seen[part] = true
        end
    end
    return table.concat(parts, '/')
end

for name, entry in pairs(metadata.by_name) do
    entry.official_name = entry.official_name or name
    entry.stratagem = metadata.roles[entry.role].label
    entry.affiliation_label = metadata.affiliations[entry.affiliation].label
    entry.official_affiliation_label = metadata.affiliations[entry.affiliation].official_label
        or entry.affiliation_label
    entry.official_url = metadata.source.card_url_pattern:format(entry.official_card)
    -- Preserve the audited main/subjob value for future detail views, but do
    -- not spend compact roster/card space repeating an identical job. Thus
    -- PLD/PLD displays as PLD, while PLD/WAR and SAM/WHM/BLM remain unchanged.
    entry.job_source_label = JOB_LABELS[name] or entry.job_source_label
        or entry.job_label
    entry.job_label = compact_job_label(entry.job_source_label)
end

return metadata
