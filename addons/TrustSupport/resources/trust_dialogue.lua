-- Provisional summon-bubble copy.
--
-- These lines are UI flavor text, not transcriptions of official/localized
-- Trust dialogue.  Keeping them isolated makes it straightforward to replace
-- them when authoritative lines are available.

local dialogue = {}

dialogue.by_name = {
    ['Valaineral'] = 'My shield is yours. Let us proceed.',
    ['Curilla'] = 'I will defend our company. Advance without fear.',
    ['Trion'] = 'Stand with me. We shall meet the enemy head-on!',
    ['Shantotto II'] = 'Ohohoho! Let us see how long our enemies can withstand me.',
    ['King of Hearts'] = 'Calculations complete. Your victory is all but assured!',
    ['Lion'] = "Ready when you are. Let's get moving!",
    ['Lion II'] = "No time to waste. Let's get moving!",
    ['Mihli Aliapoh'] = 'Stay close. I will see that your wounds are mended.',
    ['Karaha-Baruha'] = 'I shall lend you the strength of the stars.',
    ['Rahal'] = 'Remain vigilant. I will hold the line.',
    ['Fablinix'] = 'Fablinix is ready! Point the way!',
}

dialogue.by_role = {
    tank = 'Stay close. I will hold the line.',
    melee = 'Point me toward our next opponent.',
    ranged = 'I will support you from here.',
    offensive_caster = 'Our enemies will not stand for long.',
    healer = 'Leave your wounds to me.',
    support = 'I will lend you my strength.',
}

dialogue.default = 'I am ready. Let us proceed.'

function dialogue.for_entry(entry, role)
    if type(entry) ~= 'table' then
        return dialogue.default
    end
    return dialogue.by_name[entry.en]
        or dialogue.by_role[role]
        or dialogue.default
end

return dialogue
