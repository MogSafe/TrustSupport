# TrustSupport

<img width="1902" height="1459" alt="Screenshot 2026-09-22 010950-main" src="https://github.com/user-attachments/assets/31117cd1-82b7-4494-96d1-a6e6a9692a67" />

TrustSupport is a visual Windower 4 addon for assembling, saving, and summoning
Final Fantasy XI Trust parties. 
Features: 

- browse learned Trusts by role, status, name, or affiliation
- Trust cards and portraits
- replace active Trusts through one dismissal/summon action
- up to five savable presets
- a compact UI for quick access


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

<details>
<summary><h3>Installing from Git</h3></summary>

Clone the repository, then copy or link `addons/TrustSupport` into Windower's
`addons` directory:

```powershell
git clone https://github.com/MogSafe/TrustSupport.git
```

The repository also contains tests and development documentation. Users need
only the `addons/TrustSupport` folder.

</details>

## Getting started

Open the interface from the launcher icon or with:

```text
//ts
```

<img width="1280" height="720" alt="trust-open-full" src="https://github.com/user-attachments/assets/20e4efda-28d0-443d-9cb2-5783a5a20825" />

The launcher icon can be repositioned. The menus can be repositioned and also resized

<img width="960" height="270" alt="trust-resize-side-by-side" src="https://github.com/user-attachments/assets/01821dda-a06e-422b-af60-989266fb64f9" />

## Main UI

The expanded interface features the currently learned Trust roster, a summon
preview, active party cards, and preset controls.


<h4><ins>Filtering</ins></h4>

- Filter Trusts by combat role
  
https://github.com/user-attachments/assets/f8343f61-9ca5-4c00-b28e-9863d60ae5cf

<h4><ins>Sorting</ins></h4>

- Sort by status, name, role, or affiliation.

https://github.com/user-attachments/assets/985d5382-da1d-4aff-ae0a-8fe19d4d030d

<h4><ins>Summoning</ins></h4> 

- Select Trusts that are labeled "READY" from your roster. They appear in summon order in the preview area directly below. When ready, press the **SUMMON** / **APPLY** / **DISMISS** button to apply them.
Dismissals are processed before summons.

https://github.com/user-attachments/assets/4ff794c3-5996-4555-a2e9-250dce14a86a

<h4><ins>Dismissing</ins></h4>

- Queue individual dismissals or dismiss all active Trusts.

https://github.com/user-attachments/assets/9e97cee1-91e2-4c0f-bbad-40b4da4e3cb5


<h4><ins>Dismissing + Summoning</ins></h4>

- Applying dismissals and summons will process dismissals first, then summons in order

https://github.com/user-attachments/assets/1cfbb113-a7d3-446c-81f9-f975a6366de4



## Compact preset bar

The minimized UI provides access to the presets

https://github.com/user-attachments/assets/a4ff66ee-eea0-458e-8de3-ee153602136d



## Presets

Five preset slots store confirmed in-game Trust parties. Pending summons and
queued dismissals are not included when saving.


| Marker | Meaning |
| --- | --- |
| Gold | A saved preset that can be loaded. <img width="1046" height="96" alt="Trust-preset-gold" src="https://github.com/user-attachments/assets/6ef41730-d024-4f4e-85e1-8721b24358d4" /> |
| Green | All Trusts in the preset are currently loaded. <img width="1046" height="98" alt="Trust-preset-green" src="https://github.com/user-attachments/assets/a1c66e71-8422-40fb-8085-1a8b51b08e16" /> |
| Pink | Part of the preset can be loaded, but one or more are on cooldown. <img width="1055" height="99" alt="Trust-preset-pink" src="https://github.com/user-attachments/assets/fec415a7-44b8-4d48-b649-684635b7dcca" /> |
| Segmented grey | None of the Trusts can be loaded. <img width="1050" height="94" alt="Trust-preset-grey" src="https://github.com/user-attachments/assets/0595d515-895b-4c57-9a49-c757a52bce9a" />


<h4><ins>Saving Presets</ins></h4>

- Trusts in your party can be saved to a preset

https://github.com/user-attachments/assets/de0d4050-22ec-4a89-b6a9-f18b1875f458



<details>
<summary><h2>Commands</h2></summary>

*Note: you generally shouldn't need these commands. This addon is designed to be fully interactable through the UI.*

This addon registers `//trustsupport`, `//tsup`, and `//ts`. The shorter
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

</details>

<details>
<summary><h2>Local data and diagnostics</h2></summary>

Presets, interface positions, separate expanded/compact
scales, and other preferences are stored through Windower's configuration system.

Queue diagnostics for the current addon session are written to:

```text
addons/TrustSupport/data/queue.log
```

The log records transitions, summon attempts, deadlines, player coordinates,
and an active heartbeat. If the interface stops progressing, copy this file
before reloading the addon so the stalled session can be examined.

</details>

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

<details>
<summary><h2>Development</h2></summary>

```text
addons/TrustSupport/       Installable Windower addon
tests/                     Automated unit, integration, and smoke tests
.github/workflows/         Release packaging workflow
```

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

</details>

## License

TrustSupport code authored by MogSafe is distributed under the MIT License. See
the repository [`LICENSE`](LICENSE) or the `LICENSE.md` included with the addon.
Third-party and asset notices are documented in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Acknowledgements

TrustSupport is maintained and authored by
[MogSafe](https://github.com/MogSafe). It is inspired by Final Fantasy XIV's Duty Support
system and party selection interfaces. Affiliation flag images were
sourced from [FuzzyRen](https://vgen.co/fuzzyren). Final Fantasy XI names,
models, and related game assets remain the property of Square Enix.
