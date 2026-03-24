# Plan Creation — Conditional Flows

Diagram of the varying paths a user can take when creating a plan, based on their preferences set during onboarding.

```mermaid
flowchart TD
    START["User taps +"] --> HAS_PLANS{Has existing plans?}

    HAS_PLANS -->|No, first plan ever| GUIDED_FLOW
    HAS_PLANS -->|Yes| MODE_CHOICE{Quick Create or Guided?}

    MODE_CHOICE -->|Quick Create| QUICK["Single-page form with everything inline"]
    QUICK --> SAVE_Q["Save Plan"]

    MODE_CHOICE -->|Guided| GUIDED_FLOW

    subgraph GUIDED ["Guided Flow"]
        GUIDED_FLOW["Name → Type / Intensity / Format → Duration"]
        GUIDED_FLOW --> MUSIC_PREF{Music preference?}

        MUSIC_PREF -->|Workout First| WF_WARMUP
        MUSIC_PREF -->|Music First| PICK_MUSIC
        MUSIC_PREF -->|Flexible| FLEX_CHOICE{Music first or moves first?}

        FLEX_CHOICE -->|Music First| PICK_MUSIC
        FLEX_CHOICE -->|Moves First| WF_WARMUP

        PICK_MUSIC["Pick playlists for each section"]

        PICK_MUSIC --> MF_WARMUP["Warm-up Movements"]
        MF_WARMUP --> MF_SECTIONS["Main Sections"]
        MF_SECTIONS --> MF_MAIN_MOVES["Main Movements"]
        MF_MAIN_MOVES --> MF_COOLDOWN["Cool-down Movements"]
        MF_COOLDOWN --> REVIEW

        WF_WARMUP["Warm-up Movements + playlist picker"]
        WF_WARMUP --> WF_SECTIONS["Main Sections + playlist picker"]
        WF_SECTIONS --> WF_MAIN_MOVES["Main Movements"]
        WF_MAIN_MOVES --> WF_COOLDOWN["Cool-down Movements + playlist picker"]
        WF_COOLDOWN --> REVIEW

        REVIEW["Review & Save"]
    end

    REVIEW --> SAVE_G["Save Plan"]

    subgraph DEFAULTS ["Format defaults from workoutStructure pref"]
        D1["timeBased → Timed pre-selected, goal form expanded"]
        D2["repBased → Reps pre-selected, goal form expanded"]
        D3["freeform → Nothing selected, goal form collapsed"]
        D4["flexible → Nothing selected, current default"]
    end

    style START fill:#000,color:#fff,stroke:#000
    style SAVE_Q fill:#000,color:#fff,stroke:#000
    style SAVE_G fill:#000,color:#fff,stroke:#000
    style GUIDED fill:none,stroke:#000,stroke-width:2px
    style DEFAULTS fill:none,stroke:#999,stroke-dasharray: 5 5
```

## Three Conditionals

### 1. Rep/Time/No Base Default (workoutStructure preference)
| Preference | FORMAT pill in Step 2 | Movement form behavior |
|---|---|---|
| timeBased | "Timed" pre-selected | Goal form expanded, seconds input |
| repBased | "Reps" pre-selected | Goal form expanded, reps input |
| freeform | Neither selected | Goal form collapsed, "Assign reps/time" link |
| flexible | Neither selected | Same as current default |

Users can always override the pre-selection.

### 2. Music First vs Moves First (musicApproach preference)
- **workoutFirst**: Current flow — playlist pickers inline below movements
- **musicFirst**: Dedicated "Pick Your Music" step after Duration; read-only playlist labels during movement steps
- **flexible**: Choice step asking "Music First or Moves First?" then branches accordingly

### 3. Experience-Based Quick Create
- First plan ever → always guided flow
- Returning users (≥1 plan) → choice between Guided and Quick Create
- Quick Create = single scrollable page with everything inline
