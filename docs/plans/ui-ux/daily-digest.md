# Daily Digest -- View Specification

> Canonical UI/UX spec for the Daily Digest view. References [design-system.md](./design-system.md) for shared tokens, patterns, and components.

---

## Purpose

The Daily Digest is a generated summary view, produced at 6:00 AM (morning planning) and 7:00 PM (end of day review). It is the primary notification surface for the app -- a predictable, scheduled overview that replaces per-email notifications. Viewable anytime as a persistent view, not an ephemeral notification.

---

## User Goals

1. **Morning planning** -- understand what awaits: how many emails need response, what's returning from snooze, what newsletters arrived, any borderline filtered items worth checking.
2. **Evening review** -- see what was accomplished today, what's still pending, gentle nudges on multi-snoozed items.
3. **Discover notable transactional events** -- packages arriving, large charges, without having to check All Inboxes.
4. **Review borderline classifications** -- quick yes/no on the 3 most uncertain filtered items.
5. **Feel in control** -- the digest creates a rhythm: check in at 6am, check in at 7pm, otherwise ignore email.

---

## Data Source

- API: `GET /api/digest/latest` (returns most recent digest)
- API: `GET /api/digest/{id}` (returns specific digest)
- WebSocket events: `digest_available` (new digest generated)
- Model: `DailyDigest` (generatedAt, digestType, actionQueueCount, snoozedReturningToday, readingQueueCount, borderlineItems, notableTransactional, sentCount, archivedCount, multiSnoozeNudges)

### Timing

- **Morning digest**: Generated at 6:00 AM local time
- **Evening digest**: Generated at 7:00 PM local time
- **Persistence**: Always viewable. The app shows the most recent digest by default. Previous digests are accessible via a date picker.

### Notification

- When a new digest is generated, a local notification is delivered:
  - Title: "Morning Digest" or "Evening Digest"
  - Body: "N emails need your response" (morning) or "You handled N emails today" (evening)
  - Action: Opens the app to the Digest view
- These are the ONLY scheduled notifications the app sends (apart from snooze returns and optional VIP breakthrough)

---

## macOS Layout

### Sidebar Position

The Daily Digest appears as the last item in the sidebar, separated from the five main views by a divider. When a fresh digest is available and unread, a "NEW" indicator appears.

```
Sidebar:
  Action Queue  [3]
  Reading Queue
  Recommendations
  Filtered  [2]
  All Inboxes
  ----
  Daily Digest  NEW
```

### Three-Column View

The Digest uses only two columns effectively. The content column shows the digest content (there is no list-detail pattern). The detail column can show email detail if the user taps an actionable item within the digest.

```
+----------+----------------------------------------------+
|          |                                              |
| Sidebar  |  Morning Digest                              |
| (glass)  |  February 7, 2026 -- 6:00 AM                |
|          |                                              |
| Action   |  ============================================|
| Queue    |                                              |
|   [3]    |  ACTION QUEUE                                |
|          |  3 emails need your response                 |
| Reading  |  > View Action Queue                         |
| Queue    |                                              |
|          |  ============================================|
| Recom.   |                                              |
|          |  RETURNING TODAY                              |
| Filtered |  These snoozed emails return today:           |
|   [2]    |                                              |
| All In.  |  [*] Re: Q3 budget (Jane Smith)    9:00 AM   |
|          |      snoozed 2x                              |
| -------- |  [*] Project Falcon (Bob Lee)     2:00 PM    |
| > Digest |                                              |
|   NEW    |  ============================================|
|          |                                              |
|          |  READING QUEUE                                |
|          |  4 newsletters waiting                       |
|          |  > View Reading Queue                         |
|          |                                              |
|          |  ============================================|
|          |                                              |
|          |  MIGHT NOT BE SPAM                            |
|          |  These 3 might be worth checking:             |
|          |                                              |
|          |  [*] support@bank.com                         |
|          |      "Your January statement is ready"        |
|          |      Confidence: 68%                          |
|          |      [Not Spam] [Spam]                        |
|          |                                              |
|          |  [*] hello@saas.io                            |
|          |      "Invitation to collaborate"              |
|          |      Confidence: 72%                          |
|          |      [Not Spam] [Spam]                        |
|          |                                              |
|          |  [*] newsletter@new.co                        |
|          |      "Welcome to our newsletter"              |
|          |      Confidence: 75%                          |
|          |      [Not Spam] [Spam]                        |
|          |                                              |
|          |  ============================================|
|          |                                              |
|          |  NOTABLE                                      |
|          |  2 packages arriving today                    |
|          |  You were charged $847 by United Airlines     |
|          |                                              |
|          |  ============================================|
|          |                                              |
|          |  [< Previous Digest]  [Date: Feb 7 v]        |
|          |                                              |
+----------+----------------------------------------------+
  220pt                   flexible
```

### Digest Content Layout

The digest is a vertically scrollable, section-based view. Each section has a clear header and actionable content. The layout feels like a dashboard or daily briefing, not an email list.

**Section order for Morning Digest (6:00 AM):**

1. **Action Queue Summary**
2. **Returning Today** (snoozed items returning)
3. **Reading Queue Summary**
4. **Might Not Be Spam** (borderline filtered items)
5. **Notable Transactional** (packages, charges)

**Section order for Evening Digest (7:00 PM):**

1. **Today's Stats** (sent count, archived count)
2. **Still Pending** (what's left in Action Queue)
3. **Newsletters Today** (what arrived)
4. **Snooze Nudges** (items snoozed multiple times)
5. **Notable Transactional** (packages, charges)

---

## Digest Sections -- Detailed Specifications

### Section: Action Queue Summary

```
+-------------------------------------------------+
| ACTION QUEUE                                    |
|                                                 |
| [count icon] 3 emails need your response        |
|                                                 |
| By account:                                     |
| [blue dot] Work: 2                              |
| [green dot] Personal: 1                         |
|                                                 |
| > View Action Queue                             |
+-------------------------------------------------+

Specification:
- Header: "ACTION QUEUE" in .caption, uppercase, Color.textTertiary
- Count: Large number + text in .title3, Color.textPrimary
- Account breakdown: Optional, shown if user has items in multiple accounts
  .caption per-account rows with AccountDot
- CTA link: "View Action Queue" in .callout, Color.accentColor
  Tapping navigates to Action Queue (Cmd+1)
- Background: No glass (content area)
- Divider: 1pt separator below section
```

### Section: Returning Today

```
+-------------------------------------------------+
| RETURNING TODAY                                 |
|                                                 |
| These snoozed emails return today:              |
|                                                 |
| [purple dot] Re: Q3 budget (Jane Smith)         |
|              Returns at 9:00 AM    snoozed 2x   |
|                                                 |
| [purple dot] Project Falcon (Bob Lee)           |
|              Returns at 2:00 PM                 |
|                                                 |
+-------------------------------------------------+

Specification:
- Header: "RETURNING TODAY" in .caption, uppercase
- Subtitle: "These snoozed emails return today:" in .callout
- Each item:
  - Purple dot (Color.snooze) as leading indicator
  - Subject + sender in .subheadline
  - Return time in .caption, Color.textTertiary
  - Snooze count badge if snoozeCount >= 2
  - Tappable: navigates to Action Queue with this item selected
- Empty state: Section hidden if no items returning today
```

### Section: Reading Queue Summary

```
+-------------------------------------------------+
| READING QUEUE                                   |
|                                                 |
| 4 newsletters waiting                           |
|                                                 |
| > View Reading Queue                             |
+-------------------------------------------------+

Specification:
- Header: "READING QUEUE" in .caption, uppercase
- Count: Number + "newsletters waiting" in .callout
- CTA: "View Reading Queue" link, Color.accentColor
- Tone: Casual, no urgency ("waiting" not "unread")
- Section hidden if count is 0
```

### Section: Might Not Be Spam (Borderline Items)

```
+-------------------------------------------------+
| MIGHT NOT BE SPAM                               |
|                                                 |
| These 3 might be worth checking:                |
|                                                 |
| [!] support@bank.com                            |
|     "Your January statement is ready"           |
|     Confidence: 68%                             |
|     [Not Spam]  [Spam]                          |
|                                                 |
| [!] hello@saas.io                               |
|     "Invitation to collaborate"                 |
|     Confidence: 72%                             |
|     [Not Spam]  [Spam]                          |
|                                                 |
| [!] newsletter@newco.com                        |
|     "Welcome to our newsletter"                 |
|     Confidence: 75%                             |
|     [Not Spam]  [Spam]                          |
|                                                 |
+-------------------------------------------------+

Specification:
- Header: "MIGHT NOT BE SPAM" in .caption, uppercase
- Subtitle: "These N might be worth checking:" in .callout
- Max 3 items (the most uncertain classifications)
- Each item:
  - Borderline indicator icon (!)
  - Sender email in .subheadline
  - Subject in .callout, Color.textSecondary, quoted
  - Confidence score (ConfidenceLabel component)
  - Inline action buttons: [Not Spam] [Spam]
    - "Not Spam": Opens rescue picker (Action Queue, Reading Queue, All Inboxes)
    - "Spam": Confirms classification, sends training signal
  - After action: item fades out with checkmark confirmation
- Glass: Action buttons use .glass button style (these are interactive chrome)
- Section hidden if no borderline items
- During training period (first 2 weeks): may show more items
```

### Section: Notable Transactional

```
+-------------------------------------------------+
| NOTABLE                                         |
|                                                 |
| [package icon] 2 packages arriving today        |
| [dollar icon] You were charged $847 by          |
|               United Airlines                   |
|                                                 |
+-------------------------------------------------+

Specification:
- Header: "NOTABLE" in .caption, uppercase
- Each item:
  - Icon: contextual SF Symbol
    - Package: "shippingbox.fill"
    - Charge: "creditcard.fill"
    - Calendar: "calendar"
  - Text: displayText from TransactionalHighlight in .callout
  - Tappable: navigates to All Inboxes with the source email selected
- Section hidden if no notable items
```

### Section: Today's Stats (Evening Only)

```
+-------------------------------------------------+
| TODAY                                           |
|                                                 |
| [checkmark] You handled 12 emails today         |
|                                                 |
| Sent: 5    Archived: 7                          |
|                                                 |
+-------------------------------------------------+

Specification:
- Header: "TODAY" in .caption, uppercase
- Primary stat: "You handled N emails today" in .title3
  N = sentCount + archivedCount
- Breakdown: "Sent: N  Archived: N" in .callout, Color.textSecondary
- Icon: "checkmark.circle.fill" in Color.success
- Tone: Celebratory, acknowledging work done
- Section only in evening digest
```

### Section: Still Pending (Evening Only)

```
+-------------------------------------------------+
| STILL PENDING                                   |
|                                                 |
| 2 emails still need your response               |
|                                                 |
| > View Action Queue                             |
+-------------------------------------------------+

Specification:
- Same as Action Queue Summary but reframed for evening context
- Tone: Informational, not pressuring
- "still need" not "waiting for" -- no guilt
- Section hidden if Action Queue is empty
```

### Section: Newsletters Today (Evening Only)

```
+-------------------------------------------------+
| NEWSLETTERS TODAY                               |
|                                                 |
| 3 newsletters arrived today:                    |
| - Stratechery: "The End of the Beginning"       |
| - Hacker Newsletter: "Issue #847"               |
| - Pragmatic Engineer: "How Stripe Built..."     |
|                                                 |
| > View Reading Queue                             |
+-------------------------------------------------+

Specification:
- Header: "NEWSLETTERS TODAY" in .caption, uppercase
- List of newsletter names + subjects in .callout
- Each tappable: navigates to Reading Queue with that newsletter selected
- CTA: "View Reading Queue" link
- Section hidden if no newsletters arrived today
```

### Section: Snooze Nudges (Evening Only)

```
+-------------------------------------------------+
| GENTLE NUDGE                                    |
|                                                 |
| These have been snoozed multiple times:          |
|                                                 |
| [!] "Tax documents needed" (accountant@...)     |
|     Snoozed 4 times over 12 days                |
|     [Reply Now]  [Snooze Again]                 |
|                                                 |
| [!] "Quarterly review" (manager@...)            |
|     Snoozed 3 times over 8 days                 |
|     [Reply Now]  [Snooze Again]                 |
|                                                 |
+-------------------------------------------------+

Specification:
- Header: "GENTLE NUDGE" in .caption, uppercase
- Subtitle: "These have been snoozed multiple times:" in .callout
- Each item:
  - Subject in .subheadline (quoted)
  - Sender in .caption
  - Snooze stats: "Snoozed N times over N days" in .caption, Color.snooze
  - Inline actions: [Reply Now] [Snooze Again]
    - "Reply Now": navigates to Action Queue with this item selected
      and opens compose
    - "Snooze Again": opens SnoozePicker inline
  - Action buttons use .glass button style
- Section hidden if no multi-snoozed items
- Tone: Gentle, not judgmental. "Nudge" not "overdue"
- Only shown in evening digest
- Only includes items snoozed 3+ times
```

---

## iOS iPhone Layout

### Tab Bar Position

Daily Digest is accessed via the "More" tab (Tab 4). Within More, it appears below Filtered and All Inboxes. Alternatively, tapping a digest notification deep-links directly to this view.

### Full-Screen Scrollable View

On iPhone, the digest is a full-screen scrollable view. No list-detail split.

```
+-------------------------------------------+
|  Morning Digest                           |
|  February 7, 2026                         |
|-------------------------------------------+
|                                           |
|  ACTION QUEUE                             |
|  3 emails need your response              |
|  [blue] Work: 2  [green] Personal: 1     |
|  [View Action Queue >]                    |
|                                           |
|  -----------------------------------------|
|                                           |
|  RETURNING TODAY                          |
|  [*] Re: Q3 budget (Jane) at 9:00 AM     |
|      snoozed 2x                          |
|  [*] Project Falcon (Bob) at 2:00 PM     |
|                                           |
|  -----------------------------------------|
|                                           |
|  READING QUEUE                            |
|  4 newsletters waiting                    |
|  [View Reading Queue >]                   |
|                                           |
|  -----------------------------------------|
|                                           |
|  MIGHT NOT BE SPAM                        |
|  [!] support@bank.com                     |
|      "Your statement is ready"            |
|      68% confidence                       |
|      [Not Spam]  [Spam]                   |
|                                           |
|  [!] hello@saas.io                        |
|      "Invitation to collaborate"          |
|      72% confidence                       |
|      [Not Spam]  [Spam]                   |
|                                           |
|  -----------------------------------------|
|                                           |
|  NOTABLE                                  |
|  [box] 2 packages arriving today          |
|  [card] Charged $847 by United Airlines   |
|                                           |
|  -----------------------------------------|
|                                           |
|  [< Previous]          [Feb 7, 2026 v]   |
|                                           |
|-------------------------------------------+
| [Action] [Reading] [Recs] [More]          |
+-------------------------------------------+
```

**Touch interactions within digest:**

- Tap "View Action Queue" -> navigates to Action Queue tab
- Tap a returning item -> navigates to Action Queue with that item selected
- Tap "Not Spam" / "Spam" buttons on borderline items -> inline action with confirmation
- Tap notable transactional item -> navigates to All Inboxes with that email selected
- Tap newsletter name (evening) -> navigates to Reading Queue with that newsletter selected
- Tap "Reply Now" on snooze nudge -> navigates to Action Queue with compose

---

## iOS iPad Layout

Uses a two-column layout: sidebar + full-width digest content. The digest content scrolls vertically. Tapping actionable items either navigates within the sidebar or pushes a detail view.

---

## Component Specifications

### DigestSectionHeader

```
Specification:
- Text: Section title in .caption, uppercase, Color.textTertiary
- Leading accent: 2pt colored line (optional, per section)
  - Action Queue sections: Color.accentColor
  - Snooze sections: Color.snooze
  - Filtered sections: Color.filtered
  - Newsletter sections: Color.newsletter
  - Notable sections: Color.textTertiary
- Bottom padding: space-sm (8pt)
- No glass (content)
```

### DigestStatCard

Used for the primary stats (Action Queue count, Today's handled count).

```
Specification:
- Layout: Icon + large number + description text
- Icon: SF Symbol, 24pt, contextual color
- Number: .title2, bold, Color.textPrimary
- Description: .callout, Color.textSecondary
- Background: .secondarySystemGroupedBackground
- Corner radius: 12pt
- Padding: space-lg (16pt)
- No glass (content card)
```

### DigestActionableItem

Used for returning items, borderline items, and snooze nudges.

```
Specification:
- Layout: Leading indicator + content + trailing action
- Leading: Colored dot or icon (snooze purple, borderline amber, etc.)
- Content:
  - Subject: .subheadline, Color.textPrimary
  - Sender/context: .caption, Color.textSecondary
  - Metadata: .caption, Color.textTertiary
- Trailing: Inline action buttons (.glass button style)
- Tappable: navigates to relevant view
- Separator: 1pt line between items
```

### DigestDatePicker

```
Specification:
- Position: Bottom of digest content
- Layout: [< Previous]  [Date: Feb 7, 2026 v]
- Previous button: navigates to prior digest
- Date picker: dropdown/popover showing available digest dates
- Style: .caption, Color.accentColor for links
- No glass (content control)
```

### DigestNewIndicator

Shown in the sidebar when a fresh digest is available.

```
Specification:
- Text: "NEW" in .caption2, bold
- Color: Color.accentColor
- Shape: No background, just text (or small dot)
- Position: Trailing edge of "Daily Digest" sidebar row
- Behavior: Disappears after user views the digest
- Animation: Subtle pulse (respects Reduced Motion)
```

---

## Keyboard Shortcuts (macOS)

| Key | Action | Notes |
|-----|--------|-------|
| `Cmd+D` | Navigate to Daily Digest | Global shortcut |
| `J` | Scroll down within digest | |
| `K` | Scroll up within digest | |
| `Enter` | Activate focused actionable item | Navigate to relevant view |
| `1` / `2` / `3` | Quick action on borderline items | Not Spam -> Queue 1/2/3 |
| `C` | Confirm spam on focused borderline item | |
| `Escape` | Return focus to sidebar | |

**Tab navigation within digest:**
- Tab moves focus between actionable items (returning items, borderline items, snooze nudges, CTA links)
- Enter activates the focused item
- Shift+Tab moves backward

---

## Gestures (iOS)

| Gesture | Action |
|---------|--------|
| Scroll | Navigate digest content |
| Tap CTA link | Navigate to relevant view |
| Tap actionable item | Navigate or perform inline action |
| Tap Not Spam / Spam | Inline classification action |
| Swipe from left edge | Go back (if navigated here from notification) |
| Pull down | Refresh (check for newer digest) |

---

## States

### Empty State (No Digest Yet)

```
Icon: "sun.horizon" SF Symbol, 48pt, Color.textTertiary
Title: "No digest yet"
Subtitle: "Your first digest will be generated at 6:00 AM"
Tone: Expectant, patient
Note: Only shown before the very first digest is generated
```

### Loading State

```
First load: Centered ProgressView with "Loading digest..."
Subsequent: Inline progress
```

### Error State

```
If cached digest: Show cached digest + OfflineBanner
If no cached digest: Error view with retry
"Cannot load digest. Showing last available digest."
```

### Populated -- Morning Digest

```
Sections in order:
1. Action Queue Summary (always shown, even if count is 0)
2. Returning Today (hidden if empty)
3. Reading Queue Summary (always shown)
4. Might Not Be Spam (hidden if no borderline items)
5. Notable Transactional (hidden if nothing notable)
```

### Populated -- Evening Digest

```
Sections in order:
1. Today's Stats (always shown)
2. Still Pending (hidden if Action Queue empty)
3. Newsletters Today (hidden if none arrived)
4. Snooze Nudges (hidden if no multi-snoozed items)
5. Notable Transactional (hidden if nothing notable)
```

---

## Navigation Flow

### From Digest to Other Views

The digest is a hub that links to every other view:

| Element | Destination |
|---------|-------------|
| "View Action Queue" CTA | Action Queue |
| Returning item tap | Action Queue, item selected |
| "View Reading Queue" CTA | Reading Queue |
| Newsletter name (evening) | Reading Queue, newsletter selected |
| Borderline item "Not Spam" | Filtered view rescue flow |
| Notable transactional item | All Inboxes, email selected |
| Snooze nudge "Reply Now" | Action Queue, item selected + compose |
| Borderline item tap | Filtered view, item selected |

### Into Digest from Other Views

- **Sidebar/Tab**: Cmd+D or More tab -> Daily Digest
- **Notification**: Tapping the 6am/7pm notification deep-links here
- **Any time**: User can check the digest whenever they want; it persists

---

## Notification Integration

### Digest Notifications

```
Morning (6:00 AM):
- Title: "Morning Digest"
- Body: "3 emails need your response. 2 returning from snooze."
- Category: digest
- Action: Opens app to Digest view

Evening (7:00 PM):
- Title: "Evening Digest"
- Body: "You handled 12 emails today. 2 still pending."
- Category: digest
- Action: Opens app to Digest view
```

**Notification scheduling:**
- Scheduled by the server or by the client based on digest generation time
- Delivered as local notifications (not push) since the server generates digest content
- Respects system Do Not Disturb and Focus modes
- No sound by default (ADHD-friendly)

---

## Training Period Behavior (First 2 Weeks)

During the first two weeks after setup, the AI classification is still learning. The digest adapts:

- **Borderline section expanded**: May show up to 5 items instead of 3
- **Additional prompt**: "The AI is still learning your preferences. Your feedback helps it improve."
- **Feedback acknowledgment**: After confirming/rescuing items, show "Thanks! This helps the AI learn."
- **After 2 weeks**: Borderline section returns to max 3 items, training prompts disappear

---

## Account Filtering Behavior

The digest shows information across all accounts by default. Account-specific breakdowns are shown within sections (e.g., "Work: 2, Personal: 1" in Action Queue Summary).

The global account filter does NOT apply to the digest view. The digest always shows the complete picture across all accounts. This is intentional -- the digest is a planning/review tool that requires the full context.

---

## Real-Time Updates

### New Digest Available

1. WebSocket delivers `digest_available` event
2. If user is viewing the digest, content updates in place
3. If user is in another view, "NEW" indicator appears on sidebar/More tab
4. Local notification delivered

### Inline Actions (borderline item rescue/confirm)

1. User taps "Not Spam" or "Spam" on a borderline item
2. Optimistic update: item fades out with confirmation feedback
3. API call fires (reclassify or confirm)
4. The borderline item count in the section updates
5. Training signal sent to server

---

## Design Tokens Referenced

| Token | Usage in this view |
|-------|--------------------|
| `Color.accentColor` | Action Queue section accent, CTA links, "NEW" indicator |
| `Color.snooze` (#8B5CF6) | Returning items, snooze nudge section accent |
| `Color.newsletter` (#06B6D4) | Reading Queue section accent |
| `Color.filtered` (#6B7280) | Borderline section accent, confidence labels |
| `Color.success` (#22C55E) | Today's stats icon, handled count |
| `Color.textPrimary` | Section content, counts |
| `Color.textSecondary` | Descriptions, sender names |
| `Color.textTertiary` | Section headers, metadata |
| `.title2` | Large stat numbers |
| `.title3` | Primary counts |
| `.callout` | Section descriptions, item text |
| `.caption` | Section headers, metadata |
| `space-lg` (16pt) | Section padding |
| `space-xl` (20pt) | Between sections |

---

## Accessibility

- VoiceOver: Digest is navigated section by section
  - Each section header announced: "Action Queue section"
  - Stats announced: "3 emails need your response"
  - Actionable items announced with full context and available actions
  - "Not Spam" button: "Mark as not spam and move to inbox"
  - "Spam" button: "Confirm this is spam"
- Tab key: Moves between actionable items (returning items, borderline items, CTAs)
- Reduced Motion: No pulse animation on NEW indicator
- Dynamic Type: All sections adapt to larger text sizes; stat cards stack vertically at accessibility sizes

---

## Design Decisions and Rationale

### Why Two Digests Per Day

Two fixed times (6am, 7pm) create a predictable rhythm. The ADHD mind benefits from routine over reactivity. Morning digest enables planning; evening digest enables reflection. More frequent digests would undermine the "check when you want" philosophy. Less frequent would miss the evening review that catches things before they slip.

### Why Persistent (Not Ephemeral)

Unlike notification-based digests that disappear after reading, this is a persistent view. Users can return to it throughout the day. The morning digest is useful at 6am and again at 10am when they finally sit down. The evening digest is useful at 7pm and again the next morning if they missed it.

### Why No Account Filter on Digest

The digest is a holistic planning/review tool. Filtering to a single account would give an incomplete picture. Instead, account breakdowns are shown within sections. This lets the user see "Work: 2, Personal: 1" at a glance without needing to toggle filters.

### Why Max 3 Borderline Items

Showing all borderline items would turn the digest into a second Filtered view. Three items is the sweet spot: enough to catch the most important false positives, few enough that the review takes under 30 seconds. During the training period, this expands to 5.

### Why Inline Actions on Borderline Items

Forcing the user to navigate to the Filtered view to rescue items adds friction. Inline "Not Spam" / "Spam" buttons let the user make quick decisions within the digest flow. This is the primary mechanism for training the AI during the first two weeks.

### Why "Gentle Nudge" Not "Overdue"

The snooze nudge section uses deliberately non-judgmental language. "Gentle Nudge" and "snoozed N times" are factual. "Overdue" or "You've been avoiding this" would create guilt and anxiety, which is antithetical to the ADHD-friendly design philosophy. The system provides visibility without judgment.

---

## Referenced By

- [Design System](./design-system.md) -- shared tokens and components
- [Action Queue](./action-queue.md) -- digest links to Action Queue
- [Reading Queue](./reading-queue.md) -- digest shows newsletter counts
- [Filtered](./filtered.md) -- digest surfaces borderline items
- [All Inboxes](./all-inboxes.md) -- notable transactional items link here
- [Recommendations](./recommendations.md) -- future: digest could surface new recommendation counts
