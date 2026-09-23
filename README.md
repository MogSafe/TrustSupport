# TrustSupport

<!--
MEDIA TODO — HERO SCREENSHOT
Capture the expanded interface over a readable in-game scene with 3–4 Trusts
in the current party and several available Trusts visible in the roster.
Recommended: 1600x900 PNG, cropped tightly enough that card artwork and labels
remain legible. Upload it to GitHub and insert it here.
-->

TrustSupport is a visual Windower 4 addon for assembling, saving, and summoning
Final Fantasy XI Trust parties. Build a party from the full card-based planner,
save it to one of five presets, then switch to the compact bar for quick access
during ordinary play.

- Browse learned Trusts by role, status, name, or affiliation.
- Preview party changes before applying them.
- Save five reusable party presets.
- Replace active Trusts through one dismissal-and-summon action.
- Keep a smaller preset bar on screen when the full planner is not needed.

Maintainer: [MogSafe](https://github.com/MogSafe)

## Installation

### Release ZIP

Download the ZIP attached to the latest GitHub release. Extract its
`TrustSupport` folder into Windower's `addons` directory:

```text
Windower/
`-- addons/
    `-- TrustSupport/
        |-- TrustSupport.lua
        |-- assets/
        |-- core/
        |-- resources/
        `-- ui/
```

Load the addon in game:

```text
//lua load TrustSupport
```

To load it automatically, add this line to `Windower/scripts/init.txt` or your
profile's startup commands:

```text
lua load TrustSupport
```

### Installing from Git

Clone the repository, then copy or link `addons/TrustSupport` into Windower's
`addons` directory:

```powershell
git clone https://github.com/MogSafe/TrustSupport.git
```

The repository also contains tests and development documentation. Users need
only the `addons/TrustSupport` folder.

## Getting started

Open the interface from the launcher icon or with:

```text
//ts
```

Select ready Trusts from the roster. They appear in summon order in the pending
changes area. Review the resulting party, then select **SUMMON** to apply them.
TrustSupport dismisses queued Trusts first and summons replacements in the
displayed order.

<!--
MEDIA TODO — PRIMARY WORKFLOW GIF
Record a 10–15 second loop: open the launcher, select two Trusts, queue one
dismissal, press SUMMON, and show the cards updating. Keep chat visible enough
to demonstrate that the addon is controlling normal Trust commands.
Recommended: 960x540 GIF or an optimized video attachment under about 10 MB.
Insert the uploaded attachment URL on its own line here.
-->

## Full party planner

The expanded interface combines the learned-Trust roster, a party-change
preview, active-party cards, and preset controls in one window.

<!--
MEDIA TODO — ANNOTATED EXPANDED UI
Capture the full window and add four unobtrusive callouts: Available Trusts,
Pending Changes, Current Party, and Presets. Recommended: 1400–1800 px wide.
-->

- Filter Trusts by combat role.
- Sort by status, name, role, or affiliation.
- See ready, active, pending, and cooldown states at a glance.
- Add Trusts in the order they should be summoned.
- Queue individual dismissals or dismiss all active Trusts.
- Clear planned changes before applying them.
- Resize and reposition the interface to suit the game layout.

Card artwork uses curated job, role, and affiliation metadata for the Trusts
represented in the official PlayOnline Trust gallery. Unknown future entries
remain usable instead of receiving guessed classifications.

### Replacing a party

Loading a different composition does not immediately alter the party. It
prepares the required dismissals and available summons so they can be reviewed
first. Selecting **SUMMON** applies the complete plan.

<!--
MEDIA TODO — PARTY REPLACEMENT GIF
Start with 3–4 active cards, load a preset that replaces at least two Trusts,
pause briefly on the dismissal/summon preview, then apply it. This should make
the two-phase workflow obvious. Recommended: 960x540.
-->

## Compact preset bar

Minimize the planner when only preset access is needed. The compact bar keeps
the launcher, five preset slots, the primary action, headshot previews, live
queue status, and the restore control in a small translucent layout.

<!--
MEDIA TODO — COMPACT MODE COMPARISON
Use either one wide image or two images side by side:
1. A selected preset showing five headshots and a short status message.
2. The active queue showing CANCEL and a summoning/dismissing status.
Recommended per image: approximately 1000x180 at 100% UI scale.
-->

Expanded and compact modes keep separate scale values. Their scale, position,
and the selected mode persist between sessions. Logging out closes the party UI
and leaves only the standalone launcher.

## Presets

Five preset slots store confirmed in-game Trust parties. Pending summons and
queued dismissals are not included when saving.

Selecting a saved preset in the expanded planner previews its changes. In
compact mode, selecting one prepares its available changes immediately; the
main action button then applies them. Active Trusts that do not belong to the
preset are queued for dismissal, but already-active members are not dismissed
solely to change their order.

| Marker | Meaning |
| --- | --- |
| Gold | A party is saved in this slot. |
| Green | The active Trust party fulfills the preset. |
| Pink | Part of the preset can load, but one or more members are on cooldown. |
| Segmented grey | The preset is currently blocked. |
| Cyan outline | The slot is selected; this is independent of its marker. |

<!--
MEDIA TODO — PRESET STATES
Capture or composite all four marker states at the same scale, with a short
label beneath each. Include the cyan selected outline on one example.
Recommended: 900x220 PNG.
-->

If only some missing preset members are on cooldown, TrustSupport can still
prepare the available portion. A preset whose entire missing target is
unavailable will not become a dismissal-only plan.

## Safer party changes

TrustSupport validates each dismissal and summon immediately before executing
it. Dismissals are confirmed against party membership before summoning begins,
and summons are confirmed from game responses and party updates rather than
chat timing alone.

Movement and temporary action locks use bounded retries. A failed Trust gets at
most two summon attempts; unresolved work remains selected if the queue stops.
Use the visible **CANCEL** control or `//ts cancel` to interrupt an active
operation. Planning controls remain locked while changes are being applied.

<!--
MEDIA TODO — STATUS AND RECOVERY STRIP
Create a single horizontal image showing 3 compact-bar moments: summoning,
dismissing, and a stopped/retry message. Use real status wording from the addon
rather than fabricated labels. Recommended: 1200x300 composite PNG.
-->

During zoning, the expanded cards show a neutral party-refresh state until the
new party and capacity snapshot stabilizes.

## Commands

TrustSupport registers `//trustsupport`, `//tsup`, and `//ts`. The shorter
`//trusts` alias is intentionally not used because it belongs to Windower's
existing Trusts addon.

Common commands:

```text
//ts                              Toggle the TrustSupport window
//ts open|close                   Explicitly show or hide the window
//ts scale <0.55-1.25>            Scale the current expanded or compact UI
//ts resetui                      Restore the default UI position
//ts icon on|off                  Show or hide the launcher icon
//ts status                       Report capacity, active Trusts, and changes
//ts summon                       Apply queued dismissals and summons
//ts cancel                       Stop the active party-change queue
```

<details>
<summary><h3>All commands</h3></summary>

```text
//ts search <name>                Filter the visible Trust roster
//ts list [ready|cooldown|party|selected|all] [page]
//ts select <name>                Add a ready Trust to the pending order
//ts remove <name>                Remove a pending Trust
//ts dismiss <name|all>           Queue active Trusts for dismissal
//ts keep <name>                  Undo a queued dismissal
//ts clear                        Clear all pending party changes
//ts diag                         Report underlying state-source health

//ts preset select <1-5>
//ts preset save [1-5]
//ts preset load [1-5]
//ts preset clear [1-5]
//ts preset list

//ts dialogue off|occasional|always   Compatibility setting; bubbles disabled
```

The command-only workflow is fully supported:

```text
//ts select Rahal
//ts select Mihli Aliapoh
//ts status
//ts summon
```

</details>

## Local data and diagnostics

TrustSupport stores presets, interface positions, separate expanded/compact
scales, and other preferences through Windower's configuration system.

Queue diagnostics for the current addon session are written to:

```text
addons/TrustSupport/data/queue.log
```

The log records transitions, summon attempts, deadlines, player coordinates,
and an active heartbeat. If the interface stops progressing, copy this file
before reloading the addon so the stalled session can be examined.

Post-summon speech bubbles are disabled in the current build.

## Troubleshooting

- If the roster or party cards are temporarily empty while zoning, wait for the
  party-refresh state to finish.
- If a preset cannot be applied, check its marker and the compact status area
  for cooldown or capacity information.
- If summoning stops after movement or an action lock, remain stationary and
  apply the remaining selection again.
- If the UI position or scale becomes unusable, run `//ts resetui`.
- For state-source details, run `//ts diag`.
- For queue failures, preserve `data/queue.log` before reloading.

## Development

```text
addons/TrustSupport/       Installable Windower addon
tests/                     Automated unit, integration, and smoke tests
.github/workflows/         Release packaging workflow
```

Only card-ready runtime portraits, compact headshots, and previews are included
in the addon. Transparent model renders, capture tooling, and camera presets
remain in the separate `trust-cards-prototype` workspace.

Run the automated checks from the repository root:

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

### Release packaging

The [`Package TrustSupport release`](.github/workflows/release.yml) workflow
creates a ZIP containing one top-level `TrustSupport` folder. A manual workflow
run stores it as a GitHub Actions artifact; publishing a GitHub release also
attaches the ZIP directly to that release.

## License

TrustSupport code authored by MogSafe is distributed under the MIT License. See
the repository [`LICENSE`](LICENSE) or the `LICENSE.md` included with the addon.
Third-party and asset notices are documented in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Acknowledgements

TrustSupport is maintained and authored by
[MogSafe](https://github.com/MogSafe). It is inspired by Final Fantasy XI's
Trust system and party-selection interfaces. Final Fantasy XI names, models,
and related game assets remain the property of Square Enix.
