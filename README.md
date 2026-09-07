# Trust Support

Trust Support is a Windower 4 addon for selecting and summoning Final Fantasy XI
Trust parties through a visual, card-based interface inspired by party-selection
screens.

## Status

The repository currently contains the production addon scaffold and the first
set of card-ready assets. Trust discovery, party selection, summon sequencing,
cooldown handling, dismissal, and the interactive UI are the next implementation
milestones.

## Planned behavior

- Show the Trusts currently available to the logged-in character.
- Add selected Trust cards in selection order.
- Summon only pending Trusts that are not already in the party.
- Disable Trusts while their spell recast is active.
- Reopen the window to add Trusts when party capacity permits.
- Dismiss one selected Trust or all active Trusts.
- Open from a persistent launcher icon or an addon command.

The launcher will be enabled by default. Players who prefer commands can hide it
with `//ts icon off` and restore it with `//ts icon on`.

## Commands

Trust Support registers three command aliases:

```text
//trustsupport
//tsup
//ts
```

`//trusts` is intentionally not registered because it belongs to Windower's
existing Trusts addon.

The command surface is currently limited to scaffold diagnostics and the saved
launcher preference; the visual panel will be added in the next milestone.

## Repository layout

```text
trust-support/
|-- addons/
|   `-- TrustSupport/
|       |-- TrustSupport.lua
|       |-- assets/cards/
|       `-- resources/card_assets.lua
|-- LICENSE
|-- README.md
`-- THIRD_PARTY_NOTICES.md
```

Only card-ready runtime PNGs are included here. Transparent source renders,
camera presets, capture scripts, and the reusable asset-generation skill remain
in the separate `trust-cards-prototype` workspace.

## Installation (development scaffold)

Copy `addons/TrustSupport` to the Windower `addons` directory, then load it with:

```text
//lua load TrustSupport
```

The scaffold is not yet a usable party-selection UI.
