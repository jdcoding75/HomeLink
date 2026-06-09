# Pointward — App Store Screenshot Plan

Five screenshots, ordered for emotional impact. The first two carry the store —
lead with drama and the "wow," then explain.

## Required sizes (App Store Connect, 2025)

You only strictly need **two** sets; App Store Connect scales down from the
6.9" set for most listings, but provide both to be safe:

| Display | Device | Portrait pixels |
|---------|--------|-----------------|
| 6.9" | iPhone 16 Pro Max / 15 Pro Max | 1320 × 2868 |
| 6.5" | iPhone 11 Pro Max / XS Max | 1242 × 2688 |

Capture on **iPhone 15 Pro Max (or 16 Pro Max)** for best resolution and let
ASC downscale. 3–10 screenshots allowed per size; we ship 5.

---

## SCREENSHOT 1 — HERO SEND
- **Show:** Rocket mid-blast-off — full-screen flame trail, the thought
  climbing away. Deep purple ground, orange/gold ignition.
- **How:** Pick the 🚀 Rocket instrument (Pro tab → your style → Rocket), open
  the compass, send a thought, and capture at peak ignition/flight (~0.3–0.6s
  after launch). Use the Animation Test Lab (Settings → Developer →
  🧪 Animation Test Lab → Rocket Send) to fire it in isolation and time the grab.
- **Caption:** `send a feeling their way`
- **Device:** iPhone 15 Pro Max

## SCREENSHOT 2 — RECEIPT WOW
- **Show:** The most dramatic *receive* moment — the paper plane banking in a
  circle, OR the rocket landing on the catch pad.
- **How:** Animation Test Lab → Plane Land (or Rocket Land). Capture mid-bank /
  at touchdown when the emoji is emerging.
- **Caption:** `catch what they sent you`
- **Device:** iPhone 15 Pro Max

## SCREENSHOT 3 — INSTRUMENTS
- **Show:** The Pro tab "your style" grid with all instruments visible, each
  with its looping preview.
- **How:** Open the **Pro** tab. Scroll so the full instrument grid is framed
  (compass · bow · flick · rocket · wind · wand · plane).
- **Caption:** `six ways to send a feeling`
- **Device:** iPhone 15 Pro Max

## SCREENSHOT 4 — COMPASS
- **Show:** The vintage brass compass, needle pointing toward a saved person,
  with their name and distance visible.
- **How:** Compass tab with a person selected (use a warm name + a real-feeling
  distance — Settings → Developer → Simulate far away gives a clean "5000 km").
  Wait for the needle to settle near lock for the glow.
- **Caption:** `always know which way they are`
- **Device:** iPhone 15 Pro Max

## SCREENSHOT 5 — GIVING BACK
- **Show:** The Giving Back screen — "50% of every Pro purchase supports
  families separated by distance." Warm, emotional.
- **How:** Settings → account → giving back (❤️).
- **Caption:** `every upgrade helps families`
- **Device:** iPhone 15 Pro Max

---

## Tips for great screenshots
- Use **iPhone 15 Pro Max** (or 16 Pro Max) for best resolution.
- App is always dark mode — no toggle needed, but confirm.
- Show a **full battery** and clean status bar.
- **No notifications** visible — enable Do Not Disturb / Focus.
- Clean home screen behind the app (irrelevant for full-screen grabs, but tidy).
- Take **multiple of each** and pick the best frame, especially for the
  animation shots (1 and 2) where timing is everything.

## Status-bar override (optional, for pristine bars)
On the booted simulator you can force a perfect status bar before each grab:
```
xcrun simctl status_bar booted override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3
```
Capture with:
```
xcrun simctl io booted screenshot ~/Desktop/pointward-shot-N.png
```

## Caption styling (if adding text overlays in a tool like Figma/Screenshots.pro)
- Background band: #0d0d14 (the app ground)
- Caption text: #e8e0f0, elegant serif, large, generous margins
- Keep captions short and lowercase to match the app's voice
