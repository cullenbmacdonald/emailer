# All Inboxes -- View Specification

> Canonical UI/UX spec for the All Inboxes view. References [design-system.md](./design-system.md) for shared tokens, patterns, and components.

---

## Purpose

All Inboxes is the traditional unified inbox view. It shows everything across all accounts, including transactional emails that do not appear in any other queue. It exists for search, reference, and the occasional "I just want to see everything" moment.

---

## User Goals

1. **Find anything** -- search across all email, all accounts, all time.
2. **See transactional email** -- receipts, shipping notifications, calendar confirmations that are auto-archived elsewhere.
3. **Verify classification** -- confirm an email ended up in the right queue by finding it here.
4. **Fall back to familiar** -- for moments when the queue model feels constraining, this is the traditional inbox escape hatch.

---

## Data Source

- API: `GET /api/v1/emails?view=all_inboxes`
- API (search): `GET /api/v1/search?q=`
- WebSocket events: All email events (new, updated, archived) since this view shows everything
- Model: `Email` (all classifications, including transactional)

### Ordering

- Sorted by `receivedAt` descending (newest first). No sections, no grouping.
- Includes all email regardless of classification: action_required, newsletter, filtered, transactional.
- Archived emails are included (this is a complete view).
- Each email shows its classification label so the user can see where else it appears.

### Filtering

Two filter axes:
1. **Account filter**: All, Work, Personal (same global filter as other views)
2. **Search**: Full-text search across subject, sender, body, labels

---

## macOS Layout

### Three-Column NavigationSplitView

```
+----------+---------------------+-------------------------------+
|          | [Search: _________] |                               |
| Sidebar  | [Account Filter]    |                               |
| (glass)  |   All | Work | Pers |                               |
|          |---------------------+                               |
|          |                     |  From: shipping@amazon.com    |
| Action   | [*] shipping@am 1h  |  To: you@personal.com        |
| Queue    |   Your package has  |  Subject: Your package has    |
|   [3]    |   [Transactional]   |    shipped                   |
|          |                     |  Date: Feb 7, 3:45 PM        |
| Reading  | [*] Jane Smith  2h  |  Account: [green] Personal 1 |
| Queue    |   Re: Q3 budget     |  Classification: Transactional|
|          |   [Action Required]  |                               |
| Recom.   |                     |  --------------------------   |
|          | [*] noreply@..  3h  |                               |
| Filtered |   50% off every...  |  [email body in WKWebView]   |
|          |   [Filtered]         |                               |
| > All In.|                     |                               |
|          | [*] ben@strat.. 5h  |                               |
| -------- |   The End of the... |                               |
| Digest   |   [Newsletter]      |                               |
|          |                     |                               |
|          | [*] calendar@g.. 8h |                               |
|          |   Event: Team stand |                               |
|          |   [Transactional]   |                               |
+----------+---------------------+-------------------------------+
  220pt          340pt                    flexible
```

### Content Column

**Search Bar**

Positioned at the top of the content column, always visible.

```
Specification:
- Position: Sticky at top, below toolbar
- Height: 36pt
- Style: Standard search field with magnifying glass icon
- Placeholder: "Search all email..."
- Keyboard trigger: "/" focuses the search field (when list has focus)
- Behavior: Search-as-you-type with 300ms debounce
- Results replace the email list below
- Clear button (X) restores the full list
- Search scope: subject, sender name, sender email, body text, labels
- No glass effect (this is a content control)
```

**Account Filter Control**

Below search bar. Same `AccountFilterControl` as other views.

**Email Rows**

Standard `EmailRow` from design-system.md with one additional element: a classification label badge.

```
All Inboxes Row (macOS, 64pt height):
+---------------------------------------------------------------+
| [dot]  shipping@amazon.com                          3:45 PM   |
|        Your package has shipped                               |
|        Tracking: 1Z999AA1012...           [Transactional]     |
+---------------------------------------------------------------+

| [dot]  Jane Smith                                    2:34 PM   |
|        Re: Q3 budget review                                    |
|        Can you sign off on...             [Action Required]    |
+---------------------------------------------------------------+
```

**Classification Label Badge**:

```
Specification:
- Shape: Capsule (small pill)
- Font: .caption2
- Position: Trailing edge of snippet line
- Colors:
  - Action Required: Color.accentColor background, white text
  - Newsletter: Color.newsletter background, white text
  - Transactional: Color.textTertiary background, white text
  - Filtered: Color.filtered background, white text
- Purpose: Shows at a glance where else this email appears
- Tap action (iOS): No action (informational only)
```

**No section headers**: All Inboxes is a flat chronological list. No grouping by classification, no date sections. The classification badge on each row provides context.

### Detail Column

Standard email detail view, identical to Action Queue's detail column. All toolbar actions are available (Reply, Reply All, Forward, Archive, Snooze, Move, Trash) regardless of classification.

```
+----------------------------------------------+
| [toolbar: Reply  Reply All  Forward          |
|           Archive  Snooze  Move  Trash]      |
|----------------------------------------------+
|                                              |
| From: shipping@amazon.com                    |
| To: you@personal.com                        |
| Subject: Your package has shipped            |
| Date: February 7, 2026 at 3:45 PM          |
| Account: [green dot] Personal 1             |
| Classification: Transactional                |
|                                              |
| [Labels: Transactional, Shipping]            |
|                                              |
| ============================================ |
|                                              |
| [WKWebView rendering email body]             |
|                                              |
+----------------------------------------------+
```

**Additional detail elements vs other views:**

| Element | Style | Notes |
|---------|-------|-------|
| Classification label | `.callout`, colored per type | Shows current classification |
| Labels | `.caption` pills, gray | Any labels applied (Transactional, Shipping, etc.) |
| "View in [Queue]" link | `.caption`, `Color.accentColor` | If classified as actionRequired or newsletter, link to jump to that queue with this item selected |

---

## iOS iPhone Layout

### Tab Bar Position

All Inboxes is accessed via the "More" tab (Tab 4). Within the More tab, it is the second item (after Filtered).

### List View

```
+-------------------------------------------+
|  All Inboxes                    [filter]  |
|  [Search: ___________________________]    |
|  [All] [Work] [Personal]                  |
|-------------------------------------------+
|                                           |
|  +---------------------------------------+|
|  |[*] shipping@amazon.com     3:45 PM   ||
|  |    Your package has shipped           ||
|  |    Tracking: 1Z999...  [Transaction.] ||
|  +---------------------------------------+|
|  |[*] Jane Smith              2:34 PM   ||
|  |    Re: Q3 budget review              ||
|  |    Can you sign off...  [Action Req.] ||
|  +---------------------------------------+|
|  |[*] noreply@promo.com      1:15 PM   ||
|  |    50% off everything                ||
|  |    Don't miss our...     [Filtered]   ||
|  +---------------------------------------+|
|                                           |
|-------------------------------------------+
| [Action] [Reading] [Recs] [More]          |
+-------------------------------------------+
```

**Search**: Standard iOS search bar at top. Tapping activates search mode with keyboard.

**Swipe actions**: Same as Action Queue (archive, snooze, trash, read/unread). The swipe actions apply regardless of classification -- the user has full control in All Inboxes.

**Long press context menu**:
- Reply
- Reply All
- Forward
- Archive
- Snooze
- Move to...
- Mark read/unread
- Trash

### Detail View (pushed via NavigationStack)

Same as Action Queue detail view but includes classification label. Full action set available.

---

## iOS iPad Layout

Three-column NavigationSplitView, same as macOS. Search bar in content column toolbar.

---

## Search

### Search Behavior

```
Specification:
- Activation: "/" key (macOS) or tap search bar (iOS)
- Search-as-you-type: 300ms debounce before API call
- Minimum query length: 2 characters
- API: GET /api/search?q={query}&account_id={filter}
- Results: Replace the email list with search results
- Each result shows: sender, subject, snippet with query
  terms highlighted, date, classification badge
- Clear search: restores the full chronological list
- Empty results: "No emails match '[query]'"
```

### Search Results Layout

Search results use the same `EmailRow` layout as the main list, with query term highlighting in the snippet text.

```
Search result row:
+---------------------------------------------------------------+
| [dot]  Jane Smith                                    Feb 5    |
|        Re: **Q3 budget** review                               |
|        ...updated the **Q3 budget** with...  [Action Req.]   |
+---------------------------------------------------------------+
```

Query terms are bolded in subject and snippet text.

### Search Scope

The server searches across:
- Subject line
- Sender name and email
- Email body (full text)
- Labels
- Account filter applies (search within filtered account)

---

## Component Specifications

### ClassificationBadge

```
Specification:
- Shape: Capsule (small pill)
- Height: 18pt
- Font: .caption2, semibold, white
- Padding: 4pt horizontal, 2pt vertical
- Background colors:
  - actionRequired: Color.accentColor
  - newsletter: Color.newsletter
  - transactional: Color.textTertiary (muted gray)
  - filtered: Color.filtered
- Position: Trailing edge of snippet line in email row
- Accessibility label: "Classification: [type name]"
- Truncation: On narrow screens, abbreviate:
  "Action Required" -> "Action"
  "Transactional" -> "Trans."
  "Newsletter" -> "News."
  "Filtered" -> "Filt."
```

### SearchBar

```
macOS Specification:
- Standard SwiftUI searchable modifier
- Position: Top of content column
- Always visible (not hidden behind scroll)
- Magnifying glass icon leading
- Clear button trailing (when has text)
- Keyboard focus: "/" from list view
- Escape: Clear search and return focus to list

iOS Specification:
- Standard UISearchBar behavior via .searchable modifier
- Pull down to reveal (standard iOS pattern)
- Cancel button appears when active
- Keyboard dismiss on scroll
```

### SearchHighlight

```
Specification:
- Query terms in search results are highlighted
- Style: Bold weight on matched terms (not background color)
- Applied to: subject line and snippet text
- Not applied to: sender name, date, classification badge
```

---

## Keyboard Shortcuts (macOS)

All standard email shortcuts from design-system.md apply. All Inboxes-specific:

| Key | Action | Notes |
|-----|--------|-------|
| `J` | Move selection down | |
| `K` | Move selection up | |
| `Enter` | Open selected in detail | |
| `/` | Focus search bar | Switches focus from list to search |
| `Escape` | Clear search / return to list | Context-dependent |
| `R` | Reply | |
| `A` | Reply all | |
| `F` | Forward | |
| `E` | Archive | |
| `S` | Snooze | Opens snooze picker |
| `M` | Move to... | Opens reclassify picker |
| `#` | Trash | |
| `U` | Toggle read/unread | |
| `V` | View in original queue | Navigate to the email's classified queue |

---

## Gestures (iOS)

Same gesture set as Action Queue. Full action availability regardless of classification.

| Gesture | Action |
|---------|--------|
| Tap row | Push to detail view |
| Swipe right (short) | Toggle read/unread |
| Swipe right (full) | Archive |
| Swipe left (short) | Snooze |
| Swipe left (full) | Trash |
| Long press | Context menu with all actions |
| Pull down | Refresh |
| Tap search | Activate search mode |

---

## States

### Empty State

```
Icon: "tray" SF Symbol, 48pt, Color.textTertiary
Title: "No emails"
Subtitle: "Your inbox is empty"
Tone: Neutral
Note: This state is extremely rare since All Inboxes shows everything
```

### Empty Search Results

```
Icon: "magnifyingglass" SF Symbol, 48pt, Color.textTertiary
Title: "No results"
Subtitle: "No emails match '[query]'"
Tone: Informative
Action: Suggest clearing search or trying different terms
```

### Loading State

```
First load: Centered ProgressView with "Loading emails..."
Subsequent: Inline progress in navigation bar
Search: Inline progress below search bar while searching
Show cached data immediately
```

### Error State

```
If cached data: Show cached data + OfflineBanner
If no cached data: Error view with retry
Search errors: Inline error below search bar with retry
```

### Populated State

```
- Flat chronological list of all emails
- Classification badges on every row
- Search bar at top
- Account filter active
- Real-time updates (all email events)
- Archived emails visible (dimmed styling)
```

---

## Navigation Flow

### From All Inboxes to Other Views

- **Action Queue**: Via `V` key or "View in Action Queue" link, navigates to Action Queue with this email selected (if it's classified as actionRequired)
- **Reading Queue**: Same for newsletters
- **Filtered**: Same for filtered items
- **Compose/Reply**: Standard compose flow

### Into All Inboxes from Other Views

- **Sidebar/Tab**: Cmd+5 or More tab -> All Inboxes
- **Other views**: "Open in All Inboxes" or `V` key from any email in any view
- **Reading Queue**: "Open original email" in newsletter reader
- **Daily Digest**: "Notable transactional" items link here
- **Search results**: Command palette search results can navigate here

---

## Account Filtering Behavior

Standard global account filter. All Inboxes is where account filtering is most useful since it shows the largest volume of email. When filtered:

- Only emails from the selected account(s) appear
- Search is scoped to the filtered account(s)
- Classification badges still show on all rows

---

## Real-Time Updates

### All Email Events

Since All Inboxes shows everything, it reacts to all WebSocket events:

1. **new_email**: Insert at top of list (any classification)
2. **email_updated**: Update row in place (classification change, read state)
3. **email_archived**: Row remains visible but styling dims slightly
4. **snooze_return**: Update the email's row (no special styling in this view)

### Search Updates

When the user is actively searching:
- New emails matching the query appear in results
- This is handled by re-running the search query periodically (every 30 seconds) or on WebSocket events

---

## Design Tokens Referenced

| Token | Usage in this view |
|-------|--------------------|
| `Color.accentColor` | Action Required classification badge |
| `Color.newsletter` (#06B6D4) | Newsletter classification badge |
| `Color.filtered` (#6B7280) | Filtered classification badge |
| `Color.textTertiary` | Transactional classification badge, search metadata |
| `Color.textPrimary` | Subject, sender |
| `Color.textSecondary` | Snippet, read state |
| `.headline` | Unread subject weight |
| `.subheadline` | Read subject weight |
| `.caption` | Timestamp, labels |
| `.caption2` | Classification badge text |
| `space-sm` (8pt) | Row padding |
| Row height | 64pt macOS, 72pt iOS |

---

## Accessibility

- VoiceOver: Rows announced same as standard EmailRow plus "Classification: [type]"
- Search bar: "Search all email" as accessibility label
- Search results: "N results for [query]"
- Classification badges: "[Classification type]" as accessibility label
- "View in [queue]" link: "View this email in [queue name]"
- All standard email action accessibility labels apply

---

## Design Decisions and Rationale

### Why No Section Headers or Grouping

All Inboxes is the "escape hatch" view. It should feel like a traditional inbox -- simple, chronological, comprehensive. Grouping by classification would duplicate the functionality of the other views. Grouping by date adds complexity without value. The classification badge on each row provides enough context.

### Why Show Archived Emails

Users come to All Inboxes to find things. Hiding archived emails defeats this purpose. Archived emails are shown with slightly dimmed styling but are fully accessible. This is similar to Gmail's "All Mail" view.

### Why No Sidebar Badge

All Inboxes does not show a badge count in the sidebar. It would always be a large number (all email) and would create meaningless anxiety. The badge hierarchy is: Action Queue (important) > Filtered uncertain (optional) > everything else (no badge).

### Why Full Action Set

Unlike Reading Queue (no reply/snooze) or Recommendations (no email actions), All Inboxes provides every email action. This is the view where the user has full control. If the queue model miscategorized something, the user can fix it from here.

### Why Classification Badges

The classification badge answers the question "where else does this email appear?" Without it, the user cannot distinguish between an email they need to respond to (Action Queue) and a shipping notification (Transactional). The badge also builds trust by making classification decisions visible.

---

## Referenced By

- [Design System](./design-system.md) -- shared tokens and components
- [Action Queue](./action-queue.md) -- "View in All Inboxes" links here
- [Reading Queue](./reading-queue.md) -- "Open original email" links here
- [Filtered](./filtered.md) -- rescued items visible here
- [Daily Digest](./daily-digest.md) -- notable transactional items link here
