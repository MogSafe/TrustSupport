# TrustSupport

<img width="1813" height="1387" alt="Trust-banner0" src="https://github.com/user-attachments/assets/88113403-20f6-4268-9508-b01656624608" />


TrustSupport is a visual Windower 4 addon for assembling, saving, and summoning
Final Fantasy XI Trust parties. 
Features: 

- browse learned Trusts by role, status, name, or affiliation
- Trust cards and portraits
- replace active Trusts through one dismissal/summon action
- up to five savable presets
- a compact UI for quick access to presets


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
//tsup
```

<img width="960" height="540" alt="Trust_launcher_github" src="https://github.com/user-attachments/assets/13f262fb-c176-4c92-8f82-3773db334f8c" />

The launcher icon can be repositioned. The menus can be repositioned and also resized

<img width="960" height="270" alt="Trust_resize_comparison_github" src="https://github.com/user-attachments/assets/b53a0863-3a81-4420-8437-65868766b137" />

## Main Menu

The expanded interface features the currently learned Trust roster, party slots that show current Trusts & those queued for summon/dismissal, and preset controls.


<h4><ins>Filtering</ins></h4>

- Filter Trusts by combat role

https://github.com/user-attachments/assets/6e937f65-8f1e-4edb-83f3-59906d37b170

<h4><ins>Sorting</ins></h4>

- Sort by status, name, role, or affiliation.

https://github.com/user-attachments/assets/f29a000b-2b93-41bf-82a5-6492c5004f08

<h4><ins>Summoning</ins></h4> 

- Select Trusts that are labeled "READY" from your roster. When ready, press the **SUMMON** / **APPLY** button to apply them.
Dismissals are processed before summons.

https://github.com/user-attachments/assets/4d8925b0-e802-489e-a832-55ff821aeb0d


<h4><ins>Dismissing</ins></h4>

- Queue individual dismissals or dismiss all active Trusts. Press the **DISMISS** to apply the dismissals

https://github.com/user-attachments/assets/b809cbe4-d557-4ba6-b3ed-e193c8e5ca61


<h4><ins>Dismissing + Summoning</ins></h4>

- Applying dismissals and summons will process dismissals first, then summons in order

https://github.com/user-attachments/assets/f9a48e88-ebbf-46a8-bca2-a82a0eb9e671



## Minimized Menu

The minimized UI provides access to the presets

https://github.com/user-attachments/assets/85f57d02-c0ac-4d8e-9223-0c647027360e


## Presets

Five preset slots save your selected Trust party, combining currently summoned Trusts with staged changes. Queued dismissals are excluded, while queued summons are included in selection order.


| Marker | Meaning |
| --- | --- |
| Gold | A saved preset that can be loaded. <img width="1046" height="96" alt="Trust-preset-gold" src="https://github.com/user-attachments/assets/6ef41730-d024-4f4e-85e1-8721b24358d4" /> |
| Green | All Trusts in the preset are currently loaded. <img width="1046" height="98" alt="Trust-preset-green" src="https://github.com/user-attachments/assets/a1c66e71-8422-40fb-8085-1a8b51b08e16" /> |
| Pink | Part of the preset can be loaded, but one or more are on cooldown. <img width="1055" height="99" alt="Trust-preset-pink" src="https://github.com/user-attachments/assets/fec415a7-44b8-4d48-b649-684635b7dcca" /> |
| Segmented grey | None of the Trusts can be loaded. <img width="1050" height="94" alt="Trust-preset-grey" src="https://github.com/user-attachments/assets/0595d515-895b-4c57-9a49-c757a52bce9a" />


<h4><ins>Saving Presets</ins></h4>

- Trusts in your party, or queued for summoning, can be saved to a preset
- Presets of the stored Trusts can then be loaded, applying dismissals for Trusts not included

https://github.com/user-attachments/assets/6494d924-b460-40bd-afac-22c304ea1e78


<details>
<summary><h2>Commands</h2></summary>

*Note: you generally shouldn't need these commands. This addon is designed to be fully interactable through the UI.*

This addon registers `//trustsupport` and `//tsup`. Use `//tsup` as the short
command; `//trustsupport` is the full alias.

Common commands:

```text
//tsup                              Toggle the TrustSupport window
//tsup open|close                   Explicitly show or hide the window
//tsup scale <0.55-1.25>            Scale the current expanded or compact UI
//tsup resetui                      Restore the default UI position
//tsup icon on|off                  Show or hide the launcher icon
//tsup status                       Report capacity, active Trusts, and changes
//tsup summon                       Apply queued dismissals and summons
//tsup cancel                       Stop the active party-change queue
```

<details>
<summary><h3>All commands</h3></summary>

```text
//tsup search <name>                Filter the visible Trust roster
//tsup list [ready|cooldown|party|selected|all] [page]
//tsup select <name>                Add a ready Trust to the pending order
//tsup remove <name>                Remove a pending Trust
//tsup dismiss <name|all>           Queue active Trusts for dismissal
//tsup keep <name>                  Undo a queued dismissal
//tsup clear                        Clear all pending party changes
//tsup diag                         Report underlying state-source health

//tsup preset select <1-5>
//tsup preset save [1-5]
//tsup preset load [1-5]
//tsup preset clear [1-5]
//tsup preset list

//tsup dialogue off|occasional|always   Compatibility setting; bubbles disabled
```

The command-only workflow is fully supported:

```text
//tsup select Rahal
//tsup select Mihli Aliapoh
//tsup status
//tsup summon
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
- If the UI position or scale becomes unusable, run `//tsup resetui`.
- For state-source details, run `//tsup diag`.
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
