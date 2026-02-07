# UI/UX Designer Agent Memory

## Project Overview

Email client for macOS + iOS. Three accounts (blue=work, green=personal1, orange=personal2). Five views + digest. ADHD-friendly, keyboard-first on Mac, touch-first on iOS. Liquid Glass design language (macOS Tahoe / iOS 26).

## Completed Specs

All UI/UX specs are written to `/docs/plans/ui-ux/`:
- `design-system.md` -- shared tokens, components, patterns (pre-existing, comprehensive)
- `action-queue.md` -- keyboard triage, snooze returns, inbox zero
- `reading-queue.md` -- calm reader-app feel, no badge, no snooze
- `recommendations.md` -- card-based, type+status filters, duplicate consolidation
- `filtered.md` -- confidence scores, borderline section, rescue flow, 14-day auto-delete
- `all-inboxes.md` -- flat chrono list, classification badges, search, escape hatch
- `daily-digest.md` -- 6am/7pm sections, inline borderline review, snooze nudges

## Key Design Decisions

1. **Glass only on navigation chrome** -- sidebar, toolbars, tab bars, buttons. Never on content (email rows, cards, reader body).
2. **No badge on Reading Queue** -- ADHD-friendly, newsletters should not create anxiety.
3. **Filtered badge shows only borderline count** -- not total filtered, to avoid noise.
4. **No reply/snooze shortcuts in Reading Queue** -- reinforces "not an inbox" mental model.
5. **Recommendations use cards, not list rows** -- "browse and discover" not "process and triage."
6. **Digest does not respect account filter** -- always shows full picture for planning.
7. **Sequential reading in Reading Queue** -- E archives and advances, N/P navigates, like a podcast app.
8. **iOS tabs: Action, Reading, Recs, More** -- More contains Filtered, All Inboxes, Digest.
9. **iPad uses sidebar (like macOS), not tab bar** -- consistency for Mac+iPad users.

## Architecture Constraints

- Thin SwiftUI clients consume Go backend REST API + WebSocket
- Models: Email, Recommendation, DailyDigest, Account, SnoozeState
- EmailClientKit shared Swift package for networking, models, cache
- Separate macOS and iOS app targets (not multiplatform)
- WKWebView for email HTML rendering (sandboxed, injected CSS)

## Patterns to Remember

- Every view: empty, loading, error, populated states
- Optimistic updates with undo toast (5 seconds)
- Account filter is global (AppState.accountFilter), persists across views
- macOS: NavigationSplitView (3 columns), keyboard shortcuts via onKeyPress + Commands
- iOS iPhone: TabView + NavigationStack per tab
- iOS iPad: NavigationSplitView (matches macOS)
- Glass button style for toolbar/nav actions, GlassEffectContainer for morphing groups
