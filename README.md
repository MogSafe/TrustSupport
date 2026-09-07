# Trust Support

Trust Support is a Windower 4 addon for selecting and summoning Final Fantasy XI
Trust parties through a visual, card-based interface inspired by party-selection
screens.

Maintainer: [MogSafe](https://github.com/MogSafe)

## Status

The repository contains the production addon scaffold, the first set of
card-ready assets, and a tested headless state layer. The state layer discovers
Trusts from Windower resources, reads learned spells and recasts, resolves the
active party, calculates available slots, and maintains ordered pending
selections without performing game actions.

Summon sequencing, dismissal, and the interactive UI are subsequent
implementation milestones.

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

Headless state commands available before the visual panel is implemented:

```text
//ts status
//ts list [ready|cooldown|party|selected|all] [page]
//ts select <name>
//ts remove <name>
//ts clear
//ts diag
//ts icon on|off
```

## Repository layout

```text
trust-support/
|-- addons/
|   `-- TrustSupport/
|       |-- TrustSupport.lua
|       |-- assets/cards/
|       |-- core/commands.lua
|       |-- core/trust_state.lua
|       `-- resources/card_assets.lua
|-- tests/
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

The addon does not summon or dismiss Trusts yet. Its state can be inspected and
its pending selection order exercised through the commands above.

## Development checks

From the repository root:

```text
lua tests/run.lua
lua tests/bootstrap_smoke.lua
lua tests/audit_resources.lua <path-to-Windower/res/spells.lua>
```
