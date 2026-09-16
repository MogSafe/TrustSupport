# Trust Support

Trust Support is a Windower 4 addon for assembling and summoning Final Fantasy XI
Trust parties through a visual, card-based interface inspired by party-selection
screens.

Maintainer: [MogSafe](https://github.com/MogSafe)

## Status

The repository contains the initial-release implementation: a full party planner,
a compact preset bar, card-ready assets, curated Trust metadata, persistent
presets, safe dismissal and summon queues, diagnostics, and automated tests.

The state layer discovers Trust spells from Windower resources, reads learned
spells and recasts, resolves the active party, accounts for human party members,
calculates Trust capacity, and preserves ordered pending changes across transient
login and zoning snapshots.

The local catalog currently discovers 122 Trusts. Metadata classifies the 111
unique entries represented in the official PlayOnline Trust gallery by combat
role and affiliation and supplies audited job labels for the card UI. Trusts not
represented in that gallery remain explicitly unclassified instead of receiving
guessed metadata.

## Interface

The expanded window provides:

- a scrollable Trust roster with role filters and status, name, role, and
  affiliation sorting;
- hover and status feedback for ready, active, pending, and cooldown Trusts;
- ordered summon previews and active-party cards;
- individual or all-Trust dismissal planning;
- dismissal-first replacement plans followed by ordered summoning;
- five persistent party presets with separate Load, Save, and Clear controls;
- draggable positioning and corner resizing; and
- phase-specific status, retry, capacity, cooldown, and failure messages.

The window can be minimized to a translucent preset bar. In compact mode,
selecting an occupied preset immediately prepares its available party changes;
the primary action then applies them. The bar includes the launcher, preset
states, action progress, queue status, a restore control, and its own resize
grip.

Expanded and compact scale values are stored separately. The selected mode,
scale, full-window position, and launcher/compact-bar position persist between
sessions. Logging out closes the party UI back to the standalone launcher.
During zoning, the expanded cards display a neutral party-refresh state until
the new party and capacity snapshot has remained stable.

The launcher is enabled by default. Use `//ts icon off` to hide it and
`//ts icon on` to restore it.

## Presets

Each preset stores up to five Trusts from the party confirmed in game. Pending
summons and staged dismissals are not included when saving.

Loading a preset replaces the current plan with the dismissals and summons
needed to approach its stored party. Active Trusts not in the preset are staged
for dismissal. If only some missing preset members are on cooldown, the
available portion can still be loaded; a preset whose entire target is
unavailable will not become a dismissal-only plan.

Preset markers communicate their current state:

- gold: saved;
- green: the active Trust party fulfills the preset;
- pink: partially loadable because one or more members are on cooldown; and
- segmented grey: currently blocked.

A cyan border identifies the selected slot independently of its marker. Party
order is stored for future summons, but already-active Trusts are not dismissed
solely to reorder an otherwise matching party.

## Queue behavior

The queue revalidates each operation immediately before execution. Dismissals
are confirmed from party membership before summoning begins, and summons are
confirmed from both game responses and party membership rather than relying on
chat timing alone.

Movement and temporary action locks use bounded, stationary retries. A failed
Trust receives at most two summon attempts; unresolved work remains staged when
the queue stops. Use the visible `CANCEL` control or `//ts cancel` to interrupt
the active process. Planning controls are locked while a queue is running.

Post-summon speech-bubble rendering is currently disabled. The dialogue setting
command remains accepted for development compatibility, but it does not display
bubbles in this build.

## Commands

Trust Support registers three aliases:

```text
//trustsupport
//tsup
//ts
```

`//trusts` is intentionally not registered because it belongs to Windower's
existing Trusts addon.

```text
//ts                              Toggle the Trust Support window
//ts open|close                   Explicitly show or hide the window
//ts search <name>                Filter the visible Trust roster
//ts scale <0.55-1.25>            Scale the current expanded or compact UI
//ts resetui                      Restore the default UI position
//ts icon on|off                  Show or hide the launcher icon

//ts status                       Report capacity, active Trusts, and changes
//ts list [ready|cooldown|party|selected|all] [page]
//ts select <name>                Add a ready Trust to the pending order
//ts remove <name>                Remove a pending Trust
//ts dismiss <name|all>           Stage active Trusts for dismissal
//ts keep <name>                  Undo a staged dismissal
//ts clear                        Clear all pending party changes
//ts summon                       Apply dismissals, then summon pending Trusts
//ts cancel                       Stop the active party-change queue
//ts diag                         Report underlying state-source health

//ts preset select <1-5>
//ts preset save [1-5]
//ts preset load [1-5]
//ts preset clear [1-5]
//ts preset list

//ts dialogue off|occasional|always   Retained development setting; UI disabled
```

## Installation

Download the ZIP attached to the latest GitHub release and extract its
`TrustSupport` folder into the Windower `addons` directory. When installing from
a source checkout instead, copy `addons/TrustSupport` into that directory.

Then load the addon:

```text
//lua load TrustSupport
```

The visual panel can be opened with the launcher or `//ts`. A command-only
workflow is also supported:

```text
//ts select "Rahal"
//ts select "Mihli Aliapoh"
//ts status
//ts summon
```

## Diagnostics

Queue diagnostics for the current addon session are written to
`addons/TrustSupport/data/queue.log`. The log records transitions, attempts,
deadlines, player coordinates, and a heartbeat every two seconds while work is
active. If the UI remains active without progressing, copy this file before
reloading the addon so the stalled state can be examined.

## Repository layout

```text
trust-support/
|-- .github/
|   `-- workflows/release.yml
|-- addons/
|   `-- TrustSupport/
|       |-- TrustSupport.lua
|       |-- assets/
|       |   |-- card_previews/
|       |   |-- cards/
|       |   |-- fonts/
|       |   `-- ui/
|       |-- core/
|       |   |-- change_queue.lua
|       |   |-- commands.lua
|       |   |-- presets.lua
|       |   |-- summon_queue.lua
|       |   `-- trust_state.lua
|       |-- resources/
|       |   |-- affiliation_assets.lua
|       |   |-- card_assets.lua
|       |   `-- trust_metadata.lua
|       `-- ui/trust_ui.lua
|-- tests/
|-- LICENSE
|-- README.md
`-- THIRD_PARTY_NOTICES.md
```

Only card-ready runtime portraits and previews are included. Transparent source
renders, capture tooling, and camera presets remain in the separate
`trust-cards-prototype` workspace.

## Development checks

Run from the repository root:

```text
lua tests/run.lua
lua tests/presets.lua
lua tests/preset_integration.lua
lua tests/summon_queue.lua
lua tests/change_queue.lua
lua tests/bootstrap_smoke.lua
lua tests/ui_smoke.lua
lua tests/audit_resources.lua <path-to-Windower/res/spells.lua>
```
