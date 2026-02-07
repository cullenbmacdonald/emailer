# Filtered -- View Specification

> Canonical UI/UX spec for the Filtered view. References [design-system.md](./design-system.md) for shared tokens, patterns, and components.

---

## Purpose

The Filtered view holds spam and marketing emails that were automatically removed by the AI. It exists to build trust in the system -- users can review what was filtered, rescue false positives, and train the classification model over time. It is deliberately low-priority and low-attention.

---

## User Goals

1. **Trust the system** -- verify that the AI is filtering correctly without needing to check constantly.
2. **Rescue false positives** -- quickly move misclassified emails to the correct queue (Action Queue, Reading Queue, or All Inboxes).
3. **Train the model** -- each rescue or confirmation sends a training signal to improve future classification.
4. **Ignore safely** -- items auto-delete after 14 days, so the user never needs to manually clean up.

---

## Data Source

- API: `GET /api/emails?view=filtered`
- WebSocket events: `new_email` (classification=filtered), `email_updated`, `email_archived`
- Model: `Email` with `classification == .filtered`

### Ordering

1. **Borderline items** (uncertain classifications) -- at top, sorted by arrival time. These are flagged by the AI as lower-confidence classifications. The Daily Digest surfaces the top 3 most uncertain for quick review.
2. **Standard filtered items** -- below borderline, sorted by arrival time (newest first).

### Auto-Deletion

Items auto-delete after 14 days. The server handles deletion; the client simply stops receiving them. A small info banner at the top of the view reminds users: "Items auto-delete after 14 days."

---

## macOS Layout

### Three-Column NavigationSplitView

```
+----------+---------------------+-------------------------------+
|          | [Account Filter]    |                               |
| Sidebar  |   All | Work | Pers |                               |
| (glass)  |---------------------+                               |
|          |                     |                               |
| Action   | +-- Info Banner ---+|                               |
| Queue    | | Items auto-delete ||  From: noreply@promo.com     |
|   [3]    | | after 14 days    ||  Subject: 50% off everything |
|          | +------------------+|  Date: Feb 7, 2:15 PM        |
| Reading  |                     |  Account: [green] Personal 1 |
| Queue    | NEEDS REVIEW (3)    |                               |
|          | [*] support@bank 2h |  Confidence: 68% (borderline)|
| Recom.   |   Your statement is |  Reason: "Marketing language |
|          |   Confidence: 68%   |  detected, but sender is in  |
| > Filter | [*] hello@saa.. 5h  |  your contacts"              |
|   [3]    |   Invitation to...  |                               |
|          |   Confidence: 72%   |  --------------------------   |
| All In.  |                     |                               |
|          | OTHER                |  [email body in WKWebView]   |
| -------- | [*] noreply@pr.. 1d |                               |
| Digest   |   50% off every...  |                               |
|          |   Confidence: 95%   |  --------------------------   |
|          | [*] deals@shop.. 2d |                               |
|          |   Weekly deals      |  [Not Spam]  [This IS Spam]  |
|          |   Confidence: 98%   |  [Move to Action Queue]      |
|          | [*] info@randn.. 3d |  [Move to Reading Queue]     |
|          |   You've been se... |                               |
|          |   Confidence: 91%   |                               |
+----------+---------------------+-------------------------------+
  220pt          340pt                    flexible
```

### Content Column

**Info Banner**

```
Specification:
- Position: Top of list, sticky (does not scroll away)
- Height: 28pt
- Background: Color.filtered at 10% opacity
- Icon: "info.circle" SF Symbol, Color.textTertiary
- Text: "Items auto-delete after 14 days" in .caption
- No glass effect
- Dismissable: No (always visible as a reminder)
```

**Section Headers**

When borderline items exist:

- **"NEEDS REVIEW (N)"** -- yellow-tinted section header indicating items the AI is least confident about. Count shown.
- **"OTHER"** -- standard filtered items the AI is confident about.

When there are no borderline items, no section headers are shown.

**Filtered Email Rows**

Variant of the standard `EmailRow` with additional classification metadata:

```
Filtered Row (macOS, 72pt height -- slightly taller than standard):
+---------------------------------------------------------------+
| [dot]  noreply@promo.com                            2:15 PM   |
|        50% off everything this weekend                         |
|        Don't miss our biggest sale of...                       |
|        Confidence: 95%                              [14d left] |
+---------------------------------------------------------------+

Borderline Row (macOS):
+---------------------------------------------------------------+
| [dot]  support@bank.com                              2 hours  |
|  !!    Your statement is ready                                |
|        Please review your January statement...                 |
|        Confidence: 68%                              [14d left] |
+---------------------------------------------------------------+
```

**Additional elements vs standard EmailRow:**

| Element | Style | Notes |
|---------|-------|-------|
| Confidence score | `.caption`, color varies | <80% = `Color.snooze` (amber), >=80% = `Color.filtered` (gray) |
| Days remaining | `.caption2`, `Color.textTertiary` | "14d left", "7d left", etc. |
| Borderline indicator | "!!" icon in `Color.snooze` | Shown only for items in NEEDS REVIEW section |
| Sender email | Shown in full (not name) | Filtered items often come from unfamiliar senders; showing full email helps identification |

### Detail Column

When a filtered email is selected, the detail column shows the email content plus classification reasoning and rescue actions.

```
+----------------------------------------------+
| [toolbar: Not Spam | Confirm Spam]           |
|----------------------------------------------+
|                                              |
| From: support@mybank.com                     |
| Subject: Your January statement is ready     |
| Date: February 7, 2026 at 2:15 PM          |
| Account: [green dot] Personal 1             |
|                                              |
| Classification: Filtered (Spam/Marketing)    |
| Confidence: 68%                              |
| Reason: "Marketing language detected, but    |
|   sender is in your contacts"                |
|                                              |
| ============================================ |
|                                              |
| [WKWebView rendering email body]             |
|                                              |
| ============================================ |
|                                              |
| Actions:                                     |
| [Not Spam - Move to Action Queue]            |
| [Not Spam - Move to Reading Queue]           |
| [Not Spam - Move to All Inboxes]             |
| [Confirm: This IS Spam]                      |
| [Delete Now]                                 |
|                                              |
+----------------------------------------------+
```

**Classification info section** (not glass, content area):

| Element | Style | Purpose |
|---------|-------|---------|
| Classification label | `.callout`, `Color.filtered` | "Filtered (Spam/Marketing)" |
| Confidence score | `.callout`, color varies by confidence | "Confidence: 68%" |
| AI reason | `.callout`, `Color.textSecondary` | Human-readable explanation of why it was filtered |

**Rescue actions** (prominent, this is the primary interaction):

| Button | Label | Icon | Shortcut | Action |
|--------|-------|------|----------|--------|
| Move to Action Queue | "Not Spam -- Move to Action Queue" | `tray.and.arrow.down` | `1` | Reclassify + move + train |
| Move to Reading Queue | "Not Spam -- Move to Reading Queue" | `book` | `2` | Reclassify + move + train |
| Move to All Inboxes | "Not Spam -- Move to All Inboxes" | `tray` | `3` | Reclassify + move + train |
| Confirm Spam | "This IS Spam" | `xmark.shield` | `C` | Confirm classification + train |
| Delete Now | "Delete Now" | `trash` | `#` | Permanent delete |

**Training signal**: Every rescue or confirmation action sends a training signal to the server. The API call includes the email ID, the user's decision, and the original classification. The server uses this to improve future classification. This is invisible to the user -- they just move email or confirm spam.

**Toolbar actions** (glass button style):

| Button | Icon | Shortcut | Action |
|--------|------|----------|--------|
| Not Spam | `arrow.uturn.left` | `N` | Opens rescue picker (which queue?) |
| Confirm Spam | `xmark.shield.fill` | `C` | Confirms classification |

---

## iOS iPhone Layout

### Tab Bar Position

Filtered is accessed via the "More" tab (Tab 4). It is not a primary tab because it is used infrequently. Within the More tab, it is the first item in the list.

### List View

```
+-------------------------------------------+
|  Filtered                       [filter]  |
|  Items auto-delete after 14 days          |
|-------------------------------------------+
|                                           |
|  NEEDS REVIEW (3)                         |
|  +---------------------------------------+|
|  |[*] support@bank.com        2 hrs ago  ||
|  | !! Your statement is ready            ||
|  |    Confidence: 68%          14d left   ||
|  +---------------------------------------+|
|  |[*] hello@saas.io           5 hrs ago  ||
|  | !! Invitation to collaborate          ||
|  |    Confidence: 72%          14d left   ||
|  +---------------------------------------+|
|                                           |
|  OTHER                                    |
|  +---------------------------------------+|
|  |[*] noreply@promo.com       1 day ago  ||
|  |    50% off everything                 ||
|  |    Confidence: 95%          13d left   ||
|  +---------------------------------------+|
|                                           |
|-------------------------------------------+
| [Action] [Reading] [Recs] [More]          |
+-------------------------------------------+
```

**Swipe actions**:

| Direction | Distance | Action | Color |
|-----------|----------|--------|-------|
| Right (full) | >160pt | Not Spam (opens rescue picker) | `Color.accentColor` |
| Left (short) | ~80pt | Confirm spam | `Color.filtered` |
| Left (full) | >160pt | Delete now | `Color.destructive` |

**Long press context menu**:
- Move to Action Queue
- Move to Reading Queue
- Move to All Inboxes
- Confirm as Spam
- Delete Now

### Detail View (pushed via NavigationStack)

```
+-------------------------------------------+
|  < Back                        [actions]  |
|-------------------------------------------+
|                                           |
|  From: support@mybank.com                 |
|  Subject: Your statement is ready         |
|  [green dot] Personal 1    Feb 7, 2:15PM |
|                                           |
|  Confidence: 68%                          |
|  Reason: Marketing language detected,     |
|  but sender is in your contacts           |
|                                           |
|  -----------------------------------------|
|                                           |
|  [email body rendered in WKWebView]       |
|                                           |
|-------------------------------------------+
|  [Not Spam]        [Confirm Spam]         |
+-------------------------------------------+
```

**Bottom action bar**: Two primary buttons.
- "Not Spam" -- opens an action sheet: "Move to Action Queue", "Move to Reading Queue", "Move to All Inboxes"
- "Confirm Spam" -- confirms classification with haptic feedback

---

## iOS iPad Layout

Uses the macOS three-column layout. Touch interactions match iPhone patterns. Classification info shown in detail column alongside email body.

---

## Component Specifications

### FilteredInfoBanner

```
Specification:
- Position: Sticky at top of list
- Height: 28pt
- Background: Color.filtered at 8% opacity
- Icon: "info.circle" SF Symbol, 14pt, Color.textTertiary
- Text: "Items auto-delete after 14 days" in .caption, Color.textTertiary
- Not dismissable
- No glass effect
```

### BorderlineIndicator

```
Specification:
- Icon: "exclamationmark.triangle.fill" SF Symbol
- Size: 14pt
- Color: Color.snooze (amber/purple -- signals "attention needed")
- Position: Leading edge of row, between account dot and sender name
- Accessibility label: "Borderline classification, may not be spam"
```

### ConfidenceLabel

```
Specification:
- Text: "Confidence: NN%"
- Font: .caption
- Color:
  - < 70%: Color.destructive (red -- very uncertain)
  - 70-79%: Color.snooze (purple -- somewhat uncertain)
  - 80-89%: Color.filtered (gray -- fairly confident)
  - >= 90%: Color.success (green -- highly confident)
- Position: Below snippet line in row, or in detail header
```

### DaysRemainingLabel

```
Specification:
- Text: "Nd left" (e.g., "14d left", "7d left", "1d left")
- Font: .caption2
- Color: Color.textTertiary (normal), Color.destructive (< 2 days)
- Position: Trailing edge of row, below timestamp
```

### RescuePicker

When the user chooses "Not Spam", a picker appears to select the destination queue.

```
macOS: Popover from toolbar button
+-----------------------------------+
|  Move to:                         |
|                                   |
|  [1] Action Queue                 |
|  [2] Reading Queue                |
|  [3] All Inboxes (Transactional)  |
|                                   |
+-----------------------------------+

iOS: Action sheet
+-----------------------------------+
|  This email is not spam.          |
|  Where should it go?              |
|                                   |
|  Move to Action Queue             |
|  Move to Reading Queue            |
|  Move to All Inboxes              |
|                                   |
|  Cancel                           |
+-----------------------------------+
```

---

## Keyboard Shortcuts (macOS)

| Key | Action | Notes |
|-----|--------|-------|
| `J` | Move selection down | |
| `K` | Move selection up | |
| `Enter` | Open selected in detail column | Shows email + classification info |
| `N` | Not Spam (opens rescue picker) | |
| `1` | Move to Action Queue (when picker open) | Also works directly: `N` then `1` |
| `2` | Move to Reading Queue (when picker open) | |
| `3` | Move to All Inboxes (when picker open) | |
| `C` | Confirm as spam | Training signal + remove from view |
| `#` | Delete now | Permanent delete |
| `Escape` | Close detail / dismiss picker | |

**Quick flow for reviewing borderline items:**
1. `J` to select first borderline item
2. `Enter` to see full email
3. `N` then `1`/`2`/`3` to rescue, or `C` to confirm spam
4. Auto-advance to next item
5. Repeat until NEEDS REVIEW section is empty

---

## Gestures (iOS)

| Gesture | Action |
|---------|--------|
| Tap row | Push to detail view |
| Swipe right (full) | Not Spam (opens rescue action sheet) |
| Swipe left (short) | Confirm spam |
| Swipe left (full) | Delete now |
| Long press | Context menu |
| Pull down | Refresh |

---

## States

### Empty State

```
Icon: "xmark.shield" SF Symbol, 48pt, Color.textTertiary
Title: "Nothing filtered"
Subtitle: "Spam and marketing emails will appear here for review.
  Items auto-delete after 14 days."
Tone: Neutral, informative
```

### Loading State

```
First load: Centered ProgressView with "Loading filtered items..."
Subsequent: Inline progress indicator
Show cached data immediately
```

### Error State

```
If cached data: Show cached data + OfflineBanner
If no cached data: Error view with retry
```

### Populated State

```
- Two sections when borderline items exist (NEEDS REVIEW + OTHER)
- Single flat list when no borderline items
- Info banner always visible at top
- Confidence scores and days remaining on every row
- Real-time updates via WebSocket
```

---

## Navigation Flow

### From Filtered to Other Views

- **Action Queue**: Rescuing an email as "needs response" moves it to Action Queue
- **Reading Queue**: Rescuing as "newsletter" moves it to Reading Queue
- **All Inboxes**: Rescuing as "not spam" with generic classification moves to All Inboxes
- **Daily Digest**: Digest surfaces top 3 borderline items; tapping navigates here

### Into Filtered from Other Views

- **Sidebar/Tab**: Cmd+4 or More tab -> Filtered
- **Daily Digest**: "These 3 might not be spam" section links here
- **Action Queue/Reading Queue**: Reclassifying an email as "spam" moves it here (rare)

---

## Account Filtering Behavior

Standard global account filter applies. When filtered to an account:
- Only filtered items from that account are shown
- Borderline and Other sections both respect the filter
- Badge count updates to reflect filtered count

---

## Real-Time Updates

### New Filtered Email

1. WebSocket delivers `new_email` with `classification=filtered`
2. Email inserts at appropriate position (borderline vs other)
3. If borderline, inserts in NEEDS REVIEW section
4. Row animates in
5. Sidebar badge updates (shows uncertain count only)

### Email Rescued (reclassified)

1. User actions rescue (N+1/2/3)
2. Optimistic removal: row animates out
3. API call: `POST /api/emails/{id}/reclassify`
4. Email appears in destination queue via WebSocket event
5. Training signal sent automatically
6. Undo toast appears for 5 seconds

### Email Auto-Deleted (14 days expired)

1. Server removes email
2. WebSocket delivers `email_archived` event (or similar)
3. Row animates out silently
4. No notification to user

---

## Sidebar Badge Behavior

The Filtered view sidebar row shows a badge, but only for borderline/uncertain items:

```
Specification:
- Badge shows count of items in NEEDS REVIEW section only
- Does NOT show total filtered count (would be noisy)
- Color: Color.filtered (gray) -- deliberately muted
- Hidden when NEEDS REVIEW count is 0
- Example: "3" if there are 3 borderline items to review
```

This badge draws just enough attention to prompt occasional review without creating inbox-like anxiety.

---

## Design Tokens Referenced

| Token | Usage in this view |
|-------|--------------------|
| `Color.filtered` (#6B7280) | Confidence labels (high), sidebar badge, section styling |
| `Color.snooze` (#8B5CF6) | Borderline indicator, medium confidence |
| `Color.destructive` | Low confidence, delete action |
| `Color.success` | High confidence indicator |
| `Color.accentColor` | Rescue action (swipe right) |
| `.headline` | Sender email in row |
| `.subheadline` | Subject line |
| `.caption` | Confidence score, info banner |
| `.caption2` | Days remaining |
| `space-sm` (8pt) | Row internal padding |
| Row height | 72pt (both platforms -- taller due to extra metadata line) |

---

## Accessibility

- VoiceOver: Rows announced as "Filtered email from [sender], [subject], confidence [N] percent, [N] days until auto-delete, [borderline if applicable]"
- NEEDS REVIEW section: "Needs review, [N] items that may not be spam"
- Rescue actions: "Move to Action Queue, this email is not spam", etc.
- Confirm spam: "Confirm this email is spam"
- Info banner: "Items in this view auto-delete after 14 days"
- Confidence colors are always paired with the percentage text (not color-only)

---

## Design Decisions and Rationale

### Why Show Confidence Scores

Confidence scores build trust in the AI system. When a user sees "Confidence: 95%" next to obvious spam, they learn the system is working. When they see "Confidence: 68%" next to something that might not be spam, they understand why the system is uncertain. Transparency breeds trust.

### Why Borderline Section

Surfacing uncertain classifications reduces the work of reviewing filtered items. Instead of scanning the entire list, the user only needs to review the NEEDS REVIEW section. The Daily Digest further narrows this to the top 3 most uncertain items.

### Why Auto-Delete After 14 Days

Without auto-deletion, the Filtered view would grow indefinitely, creating a maintenance burden that the ADHD-targeted user will never address. Two weeks is long enough to catch any false positives through daily digest reviews, short enough that the list stays manageable.

### Why Not a Badge for Total Count

Showing "247 filtered" in the sidebar would create false urgency. The badge shows only borderline items -- the ones that actually deserve attention. This respects the user's attention while still surfacing important review opportunities.

### Why Muted Badge Color

The Filtered badge uses gray (Color.filtered) rather than the accent color used by Action Queue. This communicates "optional review" rather than "urgent action." The visual hierarchy is: Action Queue (blue, urgent) > Filtered (gray, optional) > Reading Queue (no badge, leisure).

---

## Referenced By

- [Design System](./design-system.md) -- shared tokens and components
- [Action Queue](./action-queue.md) -- rescued items can move here
- [Reading Queue](./reading-queue.md) -- rescued newsletters move here
- [Daily Digest](./daily-digest.md) -- digest surfaces top 3 borderline items
