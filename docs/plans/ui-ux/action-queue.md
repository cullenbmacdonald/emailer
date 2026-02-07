# Action Queue -- View Specification

> Canonical UI/UX spec for the Action Queue view. References [design-system.md](./design-system.md) for shared tokens, patterns, and components.

---

## Purpose

The Action Queue surfaces every email that needs a response and enables rapid keyboard-driven triage. It is the primary working view on macOS and the default tab on iOS. Its goal is inbox-zero for actionable email -- every item is either replied to, snoozed, or archived.

---

## User Goals

1. **See everything that needs a response** -- no important email should ever be missing from this queue.
2. **Process quickly** -- J/K through items, reply or snooze, achieve zero.
3. **Snooze without guilt** -- defer freely; the system tracks snooze counts for gentle accountability.
4. **Filter by account** -- quickly scope to Work-only or Personal-only when batching.
5. **Trust the system** -- know that the AI has been aggressive (false positives acceptable) so nothing falls through.

---

## Data Source

- API: `GET /api/emails?view=action_queue`
- WebSocket events: `new_email` (classification=actionRequired), `snooze_return`, `email_updated`, `email_archived`
- Model: `Email` with `classification == .actionRequired`

### Ordering

The list is divided into two sections:

1. **Snoozed Returns** -- emails whose snooze timer has expired, sorted by return time (most recent return first). Visually distinct with purple left accent border.
2. **New Items** -- emails needing response, sorted by arrival time (newest first).

Within each section, the account filter applies. When filtered to a single account, only emails from that account appear in both sections.

---

## macOS Layout

### Three-Column NavigationSplitView

```
+----------+---------------------+-------------------------------+
|          | [Account Filter]    | [toolbar: Reply Archive       |
| Sidebar  |   All | Work | Pers |  Snooze Forward]              |
| (glass)  |---------------------+-------------------------------+
|          |                     |                               |
| > Action | RETURNING           | From: Jane Smith              |
|   Queue  | [*] Jane Smith  2m  | To: you@work.com             |
|   [3]    |   Re: Q3 budget     | Subject: Re: Q3 budget       |
|          |   Can you sign o... | Date: Feb 7, 2026, 2:34 PM   |
| Reading  |   snoozed 2x        | Account: [blue dot] Work     |
| Queue    |---------------------+                               |
|          | NEW                  | Hi,                           |
| Recom.   | [*] Bob Lee   1:22p |                               |
|          |   Project Falcon    | Can you sign off on the Q3    |
| Filtered |   What do you th... | budget before Friday? I've    |
|          |                     | attached the updated version  |
| All In.  | [*] Sarah M.  11:04a| with the changes we discussed.|
|          |   Dinner Saturday?  |                               |
| -------- |   Are you free t... | Thanks,                       |
| Digest   |                     | Jane                          |
|   NEW    |                     |                               |
|          |                     | [Reply] [Reply All] [Forward] |
+----------+---------------------+-------------------------------+
  220pt          340pt                    flexible
```

### Content Column Detail

**Section Headers**

When snoozed returns exist, the list shows two section headers:

- "RETURNING" -- gray uppercase `.caption` text with a purple left accent line. Items in this section have the SnoozeReturnIndicator.
- "NEW" -- gray uppercase `.caption` text. Standard email rows.

When there are no snoozed returns, no section headers are shown. The list is simply sorted by arrival time.

**Account Filter Control**

Positioned in the toolbar area of the content column. A glass-styled segmented control with three segments: All, Work (blue dot), Personal (green dot). See `AccountFilterControl` in design-system.md.

**Email Rows**

Standard `EmailRow` component from design-system.md. In the Action Queue, the following additional behaviors apply:

- **Snooze Return Indicator**: For items in the "RETURNING" section, a 2pt purple left border and a small "Returning" label in `Color.snooze` replaces the standard snippet line.
- **Snooze Count Badge**: Shown inline when `snoozeCount >= 2` (e.g., "snoozed 3x"). Position: trailing edge of the snippet line.
- **Unread emphasis**: Unread items use bold sender name and `.headline` weight subject. Read items use regular weight.

### Detail Column

When an email is selected (via J/K + Enter, or click), the detail column shows:

```
+----------------------------------------------+
| [toolbar: Reply  Reply All  Forward          |
|           Archive  Snooze  Move  Trash]      |
|----------------------------------------------+
|                                              |
| From: Jane Smith <jane@company.com>          |
| To: you@work.com                             |
| Subject: Re: Q3 budget review               |
| Date: February 7, 2026 at 2:34 PM           |
| Account: [blue dot] Work                    |
|                                              |
| [snoozed 2x badge, if applicable]           |
|                                              |
| ------------------------------------------- |
|                                              |
| [WKWebView rendering email HTML body]        |
|                                              |
| ------------------------------------------- |
|                                              |
| [quoted previous messages, collapsed by      |
|  default, tap to expand]                     |
|                                              |
+----------------------------------------------+
```

**Toolbar actions** (glass button style within a `GlassEffectContainer`):

| Button | Icon | Shortcut | Action |
|--------|------|----------|--------|
| Reply | `arrowshape.turn.up.left.fill` | `R` | Opens compose window pre-filled with reply context |
| Reply All | `arrowshape.turn.up.left.2.fill` | `A` | Reply all |
| Forward | `arrowshape.turn.up.right.fill` | `F` | Forward |
| Archive | `archivebox.fill` | `E` | Archive with undo toast |
| Snooze | `clock.fill` | `S` | Opens SnoozePicker popover |
| Move | `folder.fill` | `M` | Opens reclassify picker |
| Trash | `trash.fill` | `#` | Move to trash |

The toolbar uses `.glassEffect(.regular)`. Buttons use `.glass` button style.

**Email header** (not glass, this is content):

- From, To, Subject, Date displayed with standard typography
- Account indicated by colored dot + account name
- Snooze count badge if applicable
- Attachment list if `hasAttachments`

**Email body**:

- Rendered in WKWebView
- Sandboxed (no JavaScript, no external resource loading beyond images)
- System-appropriate light/dark mode CSS injected
- Quoted replies collapsed by default with "Show quoted text" toggle

**No detail selected state**: When no email is selected, the detail column shows an empty state with the icon `envelope.open` and text "Select an email to read it."

---

## iOS iPhone Layout

### Tab Bar Position

Action Queue is Tab 1 (leftmost). Icon: `tray.and.arrow.down.fill`. Badge shows unread count.

### List View

```
+-------------------------------------------+
|  Action Queue                   [filter]  |
|  [All] [Work] [Personal]                  |
|-------------------------------------------+
|                                           |
|  RETURNING                                |
|  +---------------------------------------+|
|  |[*] Jane Smith              2 min ago  ||
|  |    Re: Q3 budget review               ||
|  |    Can you sign off on...   snz 2x    ||
|  +---------------------------------------+|
|                                           |
|  NEW                                      |
|  +---------------------------------------+|
|  |[*] Bob Lee                  1:22 PM   ||
|  |    Project Falcon update              ||
|  |    What do you think ab...            ||
|  +---------------------------------------+|
|  |[*] Sarah M.                11:04 AM   ||
|  |    Dinner Saturday?                   ||
|  |    Are you free tomorrow...           ||
|  +---------------------------------------+|
|                                           |
|-------------------------------------------+
| [Action] [Reading] [Recs] [More]          |
+-------------------------------------------+
```

**Account filter**: Scrolling horizontal pill bar below the navigation title. Pills use `.glass` button style. Active pill tinted with account color.

**Swipe actions**:

| Direction | Distance | Action | Color |
|-----------|----------|--------|-------|
| Right (short) | ~80pt | Toggle read/unread | `Color.accentColor` |
| Right (full) | >160pt | Archive | `Color.success` |
| Left (short) | ~80pt | Snooze (opens picker) | `Color.snooze` |
| Left (full) | >160pt | Trash | `Color.destructive` |

**Pull to refresh**: Standard `RefreshControl`. Fetches latest from API.

**Long press context menu**:
- Reply
- Reply All
- Forward
- Snooze...
- Archive
- Move to...
- Mark read/unread

### Detail View (pushed via NavigationStack)

```
+-------------------------------------------+
|  < Back    Re: Q3 budget      [actions]   |
|-------------------------------------------+
|                                           |
|  From: Jane Smith                         |
|  To: you@work.com                         |
|  [blue dot] Work    Feb 7, 2:34 PM       |
|  [snoozed 2x]                            |
|                                           |
|  -----------------------------------------|
|                                           |
|  [email body rendered in WKWebView]       |
|                                           |
|  -----------------------------------------|
|                                           |
|  [Show quoted text]                       |
|                                           |
|-------------------------------------------+
|  [Reply]  [Reply All]  [Forward]          |
+-------------------------------------------+
```

**Bottom action bar**: Uses `tabViewBottomAccessory` or a sticky bottom bar. Three primary actions: Reply, Reply All, Forward. These are glass-styled buttons.

**Navigation bar trailing actions** (condensed into menu or individual buttons):
- Archive (icon only)
- Snooze (icon only)
- More (ellipsis) -> Move to, Trash, Mark unread

---

## iOS iPad Layout

Uses the same three-column `NavigationSplitView` as macOS when in landscape. In portrait, uses a two-column layout with the sidebar as an overlay.

**Key differences from macOS:**
- Touch interactions instead of keyboard (but keyboard shortcuts work with hardware keyboard)
- Swipe gestures on list rows (same as iPhone)
- Toolbar buttons are slightly larger touch targets (44pt minimum)
- Account filter uses the same horizontal pill bar as iPhone

---

## Component Specifications

### SnoozeReturnBanner

Displayed at the top of the Action Queue list when there are snoozed items returning.

```
Specification:
- Position: Section header above returning items
- Text: "RETURNING" in .caption, uppercase, Color.textTertiary
- Left accent: 2pt vertical line in Color.snooze
- No glass (content area)
```

### SnoozeReturnRow (variant of EmailRow)

An email row for items returning from snooze.

```
Specification:
- Inherits all properties of EmailRow
- Left border: 2pt solid Color.snooze
- Additional label: "Returning" in .caption2, Color.snooze,
  positioned below the snippet line
- SnoozeCountBadge shown inline if snoozeCount >= 2
- Background: Color.snooze at 5% opacity (very subtle highlight)
```

### InboxZeroState

Shown when the Action Queue is empty. This is the most rewarding empty state.

```
Specification:
- Icon: "checkmark.circle" SF Symbol, 48pt, Color.success
- Title: "All caught up" in .title2, Color.textPrimary
- Subtitle: "No emails need your response" in .body, Color.textSecondary
- Centered vertically in content column
- Celebratory but calm (no confetti, no animation -- just clean)
- Optional: show count of emails handled today if available from digest
  "You handled 12 emails today" in .caption, Color.textTertiary
```

---

## Keyboard Shortcuts (macOS)

All shortcuts from design-system.md Section 8 apply. Action Queue-specific behavior:

| Key | Action | Notes |
|-----|--------|-------|
| `J` | Move selection down | Wraps across section boundaries (Returning -> New) |
| `K` | Move selection up | |
| `Enter` | Open selected in detail column | Loads full email body |
| `R` | Reply to selected/open email | Opens compose window |
| `A` | Reply all | |
| `F` | Forward | |
| `E` | Archive | Optimistic removal + undo toast |
| `S` | Snooze | Opens SnoozePicker popover anchored to selected row |
| `#` | Trash | |
| `U` | Toggle read/unread | |
| `M` | Move to... | Opens classification picker: Reading Queue, Filtered, All |
| `Escape` | Clear selection / close detail | |
| `Space` | Quick preview without moving focus to detail | |

**After archive/snooze**: Selection automatically moves to the next item in the list. If the last item is acted upon, selection moves to the previous item. If the queue becomes empty, show InboxZeroState.

**Snooze picker keyboard flow**:
1. Press `S` to open
2. Press `1` for 2 hours, `2` for Tomorrow 9am, `3` for Next week, `4` for Custom
3. In custom mode: type natural language time, press `Enter` to confirm
4. `Escape` to cancel

---

## Gestures (iOS)

All gestures from design-system.md Section 9 apply. Action Queue-specific:

| Gesture | Action |
|---------|--------|
| Tap row | Push to detail view |
| Swipe right (short) | Toggle read/unread |
| Swipe right (full) | Archive with undo toast |
| Swipe left (short) | Open snooze picker sheet |
| Swipe left (full) | Move to trash |
| Long press | Context menu with all actions |
| Pull down | Refresh from API |
| In detail: swipe left edge | Go back to list |

---

## States

### Empty State

```
Icon: "checkmark.circle" (Color.success)
Title: "All caught up"
Subtitle: "No emails need your response"
Behavior: This is the reward state. User should feel good seeing it.
Additional (optional): "You handled N emails today" from daily stats
```

### Loading State

```
First load: Centered ProgressView with "Loading action queue..."
Subsequent: Inline progress bar in navigation bar area
Pull-to-refresh: Standard RefreshControl (iOS)
Show cached data immediately, update in background
```

### Error State

```
If cached data exists: Show cached data + OfflineBanner at top
If no cached data: Show error view with "Cannot reach server"
  icon and "Retry" button
Error banner: slides down from top, does not replace content
```

### Populated State

```
Normal operation:
- Two sections (RETURNING + NEW) when snooze returns exist
- Single flat list when no snooze returns
- Real-time updates via WebSocket (new emails insert, archived remove)
- Account filter active in toolbar
- First item auto-selected on macOS (detail column populated)
```

---

## Navigation Flow

### From Action Queue to Other Views

- **Compose/Reply**: Opens separate compose window (macOS) or pushes compose view (iOS)
- **Move to Reading Queue**: Via `M` key or context menu, reclassifies email as newsletter
- **Move to Filtered**: Via `M` key or context menu, reclassifies as filtered
- **View in All Inboxes**: Via `V` key, navigates to All Inboxes and selects this email
- **Daily Digest**: Digest surfaces Action Queue count and snoozed returns; tapping items navigates here

### Into Action Queue from Other Views

- **Sidebar/Tab**: Cmd+1 or tab tap
- **Daily Digest**: Tapping on action items or snooze nudges navigates to this queue with the item selected
- **Snooze return notification**: Deep links to this queue with the returning item selected and scrolled to
- **Filtered rescue**: Reclassifying a filtered email as "needs response" moves it here

---

## Account Filtering Behavior

When the account filter is active:

- Both sections (RETURNING and NEW) are filtered to show only emails from the selected account(s)
- The badge count in the sidebar updates to reflect the filtered count
- The account filter persists when switching between views and returning
- Cmd+Shift+1/2/3 (macOS) or pill tap (iOS) toggles the filter
- The filter state is stored in `AppState.accountFilter` and applies globally

When filtering to "Personal", both personal accounts are included. To filter to a single personal account, the user can tap the Personal pill again or use the command palette to select a specific account.

---

## Real-Time Updates

### New Email Arrives (classified as actionRequired)

1. WebSocket delivers `new_email` event
2. Email inserts at the appropriate position in the NEW section (sorted by `receivedAt`)
3. Row animates in (slides down from top of NEW section)
4. Sidebar badge count increments
5. If the user is currently viewing a different queue, no interruption occurs

### Snooze Timer Expires

1. WebSocket delivers `snooze_return` event
2. Email inserts at top of RETURNING section
3. Row animates in with purple accent border
4. Sidebar badge count increments
5. iOS: Local notification delivered (configurable)

### Email Archived/Snoozed by User

1. User presses E/S or swipes
2. Optimistic removal: row animates out immediately
3. API call fires in background
4. If API call fails: row animates back in, error toast shown
5. Selection moves to next item
6. Undo toast appears at bottom for 5 seconds

### Classification Changed (remotely)

1. WebSocket delivers `email_updated` event
2. If email was reclassified away from `actionRequired`, remove from list
3. If email was reclassified to `actionRequired`, insert into list

---

## Design Tokens Referenced

All tokens from design-system.md apply. Action Queue-specific usage:

| Token | Usage in this view |
|-------|--------------------|
| `Color.snooze` (#8B5CF6) | Snooze return border, snooze badge, snooze picker tint |
| `Color.success` (#22C55E) | Empty state "All caught up" icon |
| `Color.accentColor` | Selected row, Action Queue badge, swipe-right action |
| `Color.destructive` | Trash swipe action |
| `Color.accountWork/Personal1/Personal2` | Account dots on rows, filter pills |
| `.headline` | Unread email subject weight |
| `.subheadline` | Read email subject weight |
| `.caption` | Section headers, timestamps |
| `space-sm` (8pt) | Row internal padding |
| `space-lg` (16pt) | iOS row horizontal padding |
| Row height | 64pt macOS, 72pt iOS |

---

## Accessibility

- VoiceOver: Each row announced as "[Unread] [Returning from snooze] Email from [sender] about [subject], received [relative time], [account name] account, [snoozed N times]"
- Snooze return section header announced as "Returning from snooze, N items"
- Empty state announced as "All caught up. No emails need your response."
- All toolbar actions have accessibility labels
- Swipe actions have accessibility hints describing their function
- The snooze picker preset buttons are labeled with their full time description (e.g., "Snooze for 2 hours" not just "2h")

---

## Referenced By

- [Design System](./design-system.md) -- shared tokens and components
- [Daily Digest](./daily-digest.md) -- digest surfaces Action Queue counts and snooze nudges
- [Filtered](./filtered.md) -- rescued items can move to Action Queue
