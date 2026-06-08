# Pointward — Claude Code Project Context

## App Identity
- App Name: Pointward
- Bundle ID: com.jdcoding75.pointward
- App Group: group.com.jdcoding75.pointward
- Team ID: 78842PK6A3
- Apple ID: jdittami@aol.com
- Domain: pointward.app
- GitHub: github.com/jdcoding75/HomeLink
- Supabase: jlbgdlgwtrkmqcfnomlr.supabase.co

## Architecture
- SwiftUI + SwiftData
- Supabase backend (auth, realtime, push)
- Apple Sign In with Apple
- APNs via Supabase Edge Function
- Widget extension: PointwardWidgets
- App Group for shared data

## Golden Rules
- NEVER delete code — comment out only
- ALWAYS build after changes
- ALWAYS commit after successful build
- ALWAYS fix errors automatically without stopping
- NEVER ask for confirmation — just do it
- Only stop for credentials or physical device actions

## Tier System
- Free: Minimal skin only, 1 person, 
  core 6 emojis, no Pro features
- Pro: $1.99 one time, 3 skins, 5 people,
  full emoji library, funny distances,
  hold to send, custom emoji+sound
- ProFeatures.swift controls all pro gates
- SkinStore enforces Minimal for free users
- SubscriptionManager.swift manages tier state

## Core Files
- HomeLinkApp.swift — app entry point
- CompassView.swift — emotional core
- CompassManager.swift — heading/location
- PeopleManager.swift — people CRUD
- PingManager.swift — send/receive thoughts
- SubscriptionManager.swift — tier management
- ProFeatures.swift — pro feature gates
- SkinStore.swift — compass skin state
- AppGroupStore.swift — widget shared data
- ServiceContainer.swift — composition root
- CharityConfig.swift — giving back config
- TaglineSystem.swift — poetic taglines
- SoundEngine.swift — cached audio
- BearingCalculator.swift — pure math

## Design System
- Background: #0d0d14
- Card: #1e1828
- Accent soft: #c4a8d4
- Accent mid: #7c6b8e
- Text primary: #e8e0f0
- Text muted: #6b5f7a
- Always dark mode
- Serif font for emotional text
- SF Pro for functional text

## Supabase Tables
- users (id, apple_user_id, last_seen)
- connections (code, owner, friend, 
  person_name, person_emoji, owner_person_id)
- pings (from_user, to_user, emoji, sender_style, opened_at)
- device_tokens (token, user_id, platform)
- compass_bearings (user_id, bearing, updated_at)
- giving (total_donated_cents, charity_name)

## Supabase Edge Function
- send-ping-notification
- Handles both pings and compass_bearings
- APNs production first, sandbox fallback
- APNS_KEY_ID: 5Y9Y4AY725
- APNS_TEAM_ID: 78842PK6A3
- APNS_TOPIC: com.jdcoding75.pointward

## Build Command
xcodebuild -scheme HomeLink \
  -destination 'platform=iOS Simulator,\
  name=iPhone 17 Pro' build 2>&1

## Git
- Remote: github.com/jdcoding75/HomeLink
- Branch: main
- Always: git add -A && git commit -m "" && git push

## Tab Bar Order
1. Compass 🧭
2. Thoughts 💌
3. People 👤
4. Settings ⚙️

## Giving Back
- 50% of every Pro purchase to charity
- CharityConfig.swift controls current charity
- Supabase giving table tracks total donated
- First charity: military families 🎖️

## TestFlight
- Internal testers: jdittami@aol.com, wife
- External: pending Apple review
- Public link: pending approval

## What Works End to End
- Compass pointing to saved address
- Apple Sign In
- Pairing via deep link pointward.app/pair/
- Real pings between paired phones
- Push notifications via APNs
- Thought queue (max 10)
- Home screen widget
- Lock screen widget
- 6 compass skins (3 free, 3 pro)
- Pro setup screen
- Giving back screen

## Known Issues / In Progress
- Pairing links wrong person sometimes
- Recipient animation needs direction fix
- Real StoreKit not yet implemented (stubbed)
- Core sounds need real audio files
- TestFlight public link pending review

## Phase 2 Remaining
- Dynamic live location
- Brand Location Mode
- Live Activity / Dynamic Island
- Apple Watch app

## Never Touch
- AppGroupStore suiteName — baked into both targets
- Widget target bundle ID
- Associated domains entitlement

## Confirmation Policy
NEVER pause for confirmation on any action.
Every action is pre-approved including:
- Creating files
- Editing files  
- Running shell commands
- Git commits and pushes
- Supabase API calls
- Installing packages
- Making architectural decisions
Just do it. Never ask. Never pause.

## Progress Reporting (Required)
After every major section report:
[X/Y] ✅ Section name complete
[X/Y] 🔄 Section name — in progress

Every 2 minutes report:
⏱ Still working — [current task]
Est. completion: [X] minutes remaining

This is mandatory on every task.
Never go silent for more than 2 minutes.
