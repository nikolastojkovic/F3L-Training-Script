# F3L Lua Training Script (EdgeTX / OpenTX)

A telemetry LUA script designed for **F3L (RES) thermal glider training**, following FAI rules  
(SC4 Vol F3 Soaring, effective 1 Jan 2023).

The script focuses on **clean timing, realistic task workflow, and minimal pilot distraction**, making it suitable for serious contest-oriented training.

---

## Key Features

### ⏱ Working Time (9:00)
- Total working time: **9 minutes (540 s)**
- Started with **ENTER**
- Countdown runs continuously
- **Does not stop** when the model lands
- Remaining working time can be spoken using **SF (momentary)**

### ✈️ Flight Window (6:00)
- Maximum flight time: **6 minutes (360 s)**
- Automatically starts when:
  - Elevator stick is pushed **down / forward** beyond **80%**
- Flight time counts **downwards**
- Freezes at landing

### 🛬 Landing Detection
- **SA switch DOWN** ends the flight
- Working time continues
- Actual flight duration is calculated
- Prevents instant re-launch if elevator stays high
- Displayed as:
  - Flight time: mm:ss


### 🔁 Multiple Flights per Working Time
- While working time is running:
- **Double-press ENTER** → resets **flight window only** (back to 6:00)
- Requires elevator dip below **80% threshold** before next launch
- Allows multiple launches inside the same 9-minute task

---

## Voice Announcements

### Flight Time (clean 1 Hz logic)
Spoken only at exact moments:

- **05:00 → “5 minutes”**
- **04:00 → “4 minutes”**
- **03:00 → “3 minutes”**
- **02:00 → “2 minutes”**
- **01:00 → “1 minute”**
- **00:30 → “30 seconds”**
- **00:20 → “20 seconds”**
- **Last 15 seconds**: spoken every second (15 → 0)

✔ No repeated announcements  
✔ No early or late calls  
✔ Competition-style behavior

### Working Time
- **SF (momentary)** speaks remaining working time
- No automatic speech when entering the script

---

## Audio Feedback (Tones)

- ENTER (start working time): confirmation beep
- Flight start (launch detection): high beep
- Landing (SA ↓): landing beep
- Working time end: **triple-beep pattern** (very distinct)
- Reset actions: distinct confirmation tones

---

## Controls Summary

| Control | Action |
|------|------|
| **ENTER** | Start working time (9:00) |
| **ENTER ×2** | Reset flight window to 6:00 (while WT runs) |
| **SA ↓** | End flight (landing) |
| **SF (momentary)** | Speak remaining working time |
| **BACK ×2** | Full reset (working time + flight) |

---

## Display Layout

- **Working** – remaining working time
- **Flight** – remaining flight time (freezes at landing)
- **Flight time** – actual time spent in the air (shown after landing)

---

## Installation

1. Copy the script to:
`/SCRIPTS/TELEMETRY/f3l.lua`


2. Assign it to a telemetry screen:
`Model Setup → Display → Screen → Script → f3l`


3. Ensure control mapping:
- Elevator source: `ele`
- SA switch: landing
- SF switch: momentary (voice)

---

## Design Philosophy

- Aligned with **FAI F3L rules**
- Predictable and non-distracting audio
- No voice spam
- Training-focused (not UI-heavy)
- Suitable for real contest preparation

---

## Planned Extensions (Optional)

- Automatic score calculation (2 points per second)
- Voice readout of flight time after landing
- Flight history (last N flights)
- Penalty / over-time indication

---

## Status

✅ **Stable training version**

Tested and validated for **EdgeTX / OpenTX** radios in F3L training scenarios.
If you find this script useful and want to support development,
you can buy me a coffee or beer 🙂


---

## License

This project is licensed under the MIT License.  
See the [LICENSE](LICENSE) file for details.


Happy thermal hunting ☀️🛩️
