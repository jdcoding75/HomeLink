# PAIRING / SEND-PATH AUDIT
**Read-only blast-radius map for the planned pivot** (2026-06-11)

Target end state: **no pairing required · recipients are the sender's own
contacts · one send path · sender-side directionality only.**

This file changes nothing in the app — it maps what removing pairing touches.

---

## 1. Where pairing / paired-state is assumed

| Area | File | What it assumes |
|---|---|---|
| **Data model** | `Models/Person.swift` | `pairedUserID: String?` is the ONLY link to a remote account. `isDynamic: Bool` implies a *live*-location partner (Phase-2 dynamic location). `latitude/longitude/displayAddress` are a **static saved address** (not live). |
| | `Models/UserProfile.swift` | The local user's own account id — i.e. *I* am a paired recipient for others. |
| **Send flow** | `Views/CompassView.swift` `sendThought()` | Recipient = `people.selectedPerson?.pairedUserID.flatMap(UUID.init) ?? SupabaseService.connectedFriendID`. No paired id → logs "local only — no paired recipient" and **nothing is delivered**. |
| | `Managers/PingManager.swift` | `sendRemote(to userID:)` and `sendPing(to person:)` both require a partner UUID / `pairedUserID`. `syncMissedThoughts(partnerID:partnerName:)` keyed on a partner. |
| **Receipt flow** | `Managers/PingManager.swift` | `receivePing` / `nowPlaying` arrive from a paired partner; realtime ping subscription (SupabaseService) is partner-scoped. `caughtHistory` is received pings *from partners*. |
| **Presence / "pointing at you"** | `Managers/CompassManager.swift` `reportPointingIfNeeded` | Guarded by `target.pairedUserID == connectedFriend`; writes the sender's bearing to `compass_bearings`. The partner subscribes (SupabaseService realtime) and shows an **edge-glow presence**. This is the only *receiver-side* directional signal. |
| **Services** | `Services/Implementations/SupabaseService.swift` | `connections` table (`code, owner, friend, owner_person_id`), `connectedFriendID`, `redeem` / `redeemCode` / `discoverConnections`, `reportPointing`, `compass_bearings` realtime, partner ping subscription. |
| | `Services/Protocols/PairingServiceProtocol.swift`, `Services/Implementations/MockPairingService.swift` | `generatePairingCode()`, `completePairing(code:)` → `PairedUser{id, displayName}`. |
| **Pairing UI** | `Views/ConnectView.swift`, `Views/PairAcceptView.swift`, `Views/MutualMomentView.swift` | Generate/enter codes, accept a pair, the "mutual moment" celebration on connect. |
| | `Views/AddPersonView.swift`, `Views/OnboardingView.swift`, `Views/PeopleListView.swift` | Add/invite a person via a connection; onboarding pairing step. |
| | `Utilities/AppLinks.swift` | Deep link `pointward.app/pair/<code>` → pairing. |
| **People mgmt** | `Managers/PeopleManager.swift` | `insertFromInvite` / `addFromInvite` / `bindConnection(friendID:toPersonID:)` — connection-initiated cards bypass the free-tier gate. |

---

## 2. The TWO current send paths

| | Path A — **real send** | Path B — **legacy / mock send** |
|---|---|---|
| Method | `PingManager.sendRemote(to userID: UUID, emoji:style:message:tagline:)` | `PingManager.sendPing(to person: Person, emoji:)` |
| Backend | `SupabaseService.shared.sendPing(to: userID, …)` — real insert, retry, failure surfaced | `networkService.sendPing(toPairedUserID:emoji:)` — style-less mock |
| Caller | **`CompassView.sendThought` (the live path, line ~1797)** | No live caller found — legacy/mock (kept for the mock service) |
| Carries | emoji · style · message · tagline | emoji only |
| Pairing dependency | recipient UUID resolved from `selectedPerson.pairedUserID` (or `connectedFriendID` fallback) | `person.pairedUserID ?? "local-stub"` |

**Differences:** A is the production path (full payload, real Supabase, error
handling); B is a style-less legacy mock with no live caller. **Both** require a
paired UUID. There is also an implicit third outcome: **no recipient → local
only** (the flight animation plays, nothing is delivered).

→ **To collapse to one path:** keep `sendRemote` as the single send; retire
`sendPing(to person:)`. Replace "recipient = `selectedPerson.pairedUserID`" with
a contact-derived recipient (see §3). The `connectedFriendID` fallback goes away.

---

## 3. Recipient identity

- **Today:** a recipient is a `Person` (SwiftData `@Model`) with an editable
  `name` (display) + a **stored address** (`latitude/longitude/displayAddress/
  locationDisplayName`) + `pairedUserID` (the remote link). Delivery targets the
  `pairedUserID` UUID. There is **no contact-book linkage** — a Person is a
  hand-made card, optionally bound to a paired account.
- **Display name vs contact name:** there is currently only `Person.name` (one
  field, user-editable). A "contact name vs display name" split would live on
  `Person` — e.g. add `contactIdentifier: String?` (CNContact id) + `contactName`
  (immutable, from Contacts) alongside the existing editable `name` (display).
  `Models/Person.swift` is the single place to add it; `PeopleManager` (CRUD)
  and `AddPersonView`/`EditPersonView`/`ContactPickerView` would populate it.
- **Preview-before-send:** **does not exist** and **needs building.** Today the
  flow is select person → select feeling → do the mechanic, which sends
  immediately; the only "preview" is the *post*-send arrival glimpse
  (`ArrivalPreviewView`, now superseded by the sent-confirmation reveal). A
  pre-send "to <contact> — confirm?" step would be new UI between selection and
  the send mechanic.

---

## 4. Location / compass — direction & distance

- **Where computed:** `Managers/CompassManager.swift`. Bearing + distance are
  `BearingCalculator.bearing/distanceKm(from: userLocation.coordinate, to:
  target.coordinate)` — i.e. **the SENDER's live location → the Person's STORED
  coordinate.** This is **already sender-side**: the directional compass needs
  the sender's location and the contact's saved address, nothing from the
  receiver. ✅ Good for the pivot.
- **Receiver-side direction (the part to drop):** `reportPointingIfNeeded` writes
  the sender's bearing to `compass_bearings`; the partner's app subscribes
  (SupabaseService realtime, `PointingEvent`) and renders an **edge-glow
  presence** ("they're pointing at you"). This is the only receiver-side
  directional dependency. Dropping it = remove `reportPointing`, the
  `compass_bearings` table + realtime subscription, and the presence/edge-glow
  consumer. The core "point toward a contact" compass is unaffected.
- **Does anything depend on the RECEIVER's LIVE location?** Not for the static
  case — `Person.coordinate` is a saved address. The exception is
  **`Person.isDynamic`** (the planned "dynamic live location" mode), which would
  require the *other* user to share live location. For sender-side-only, drop
  `isDynamic`/dynamic-location and keep static saved addresses; then no receiver
  location is ever needed.

---

## 5. Assessment

**How tangled:** MODERATE. Pairing is reasonably *isolated* behind three seams —
`SupabaseService` (connections/redeem/discover/realtime/compass_bearings),
`PingManager` (send/receive/missed-sync), and `Person.pairedUserID` — plus a
cluster of pairing-only views (`ConnectView`, `PairAcceptView`,
`MutualMomentView`) and the deep-link (`AppLinks`). It is NOT smeared through the
animation/instrument layer at all (those take an emoji + style + a `Person` and
never touch pairing). The compass/direction layer is **already sender-side**.

**Removal size:** **MEDIUM** (leaning medium-large only because of the realtime
receive + presence backend, not the client logic).
- *Small/contained:* one send path (retire `sendPing(to:)`); recipient
  resolution in `sendThought` (swap `pairedUserID` → contact id); delete the
  pairing views + deep link; drop `connectedFriendID`/`reportPointing`/
  `compass_bearings`.
- *Larger / needs a decision:* what "send" MEANS without a paired account — i.e.
  how a thought reaches a contact who isn't a Supabase-linked partner (push by
  contact match? local-only symbolic send? account discovery by phone/contact
  hash?). That product decision drives the receive + realtime rework, which is
  the biggest piece.

**What breaks first:** the **send recipient resolution** in
`CompassView.sendThought` — `selectedPerson?.pairedUserID` becomes nil for every
contact, so remote delivery, realtime receive, missed-thought sync, and the
felt/caught/pointing presence (all keyed on a partner UUID) stop functioning the
instant pairing is removed. The **directional compass keeps working** (sender
location → contact's saved address), so the *aim* experience survives a pairing
removal; only *delivery/receipt* must be re-homed onto the new contact model.

**Suggested order for the pivot:** (1) add contact identity to `Person`; (2)
define the non-paired delivery mechanism; (3) collapse to the single `sendRemote`
path keyed on the new identity; (4) strip pairing UI + deep link + presence +
`compass_bearings`; (5) drop `isDynamic`/receiver-side location. Steps 1–3 are
the load-bearing ones; 4–5 are mostly deletions.
