# Reading Queue -- View Specification

> Canonical UI/UX spec for the Reading Queue view. References [design-system.md](./design-system.md) for shared tokens, patterns, and components.

---

## Purpose

The Reading Queue provides a calm, reader-app-like interface for newsletters. It separates newsletter consumption from inbox anxiety, presenting newsletters as content to enjoy rather than items to process. Think Instapaper or Pocket, not Gmail.

---

## User Goals

1. **Read newsletters at leisure** -- no urgency, no badge pressure, no notification anxiety.
2. **Comfortable reading experience** -- generous typography, minimal chrome, focused content.
3. **Sequential consumption** -- move through newsletters one at a time without returning to the list.
4. **Track reading progress** -- partially read items sink to the bottom rather than nagging.
5. **Know recommendations are being captured** -- AI scans newsletters on arrival and populates the Recommendations view automatically.

---

## Data Source

- API: `GET /api/emails?view=reading_queue`
- WebSocket events: `new_email` (classification=newsletter), `email_updated`, `email_archived`
- Model: `Email` with `classification == .newsletter`

### Ordering

1. **Unread newsletters** -- sorted by arrival time, newest first.
2. **Partially read newsletters** -- sinks to bottom of list, sorted by last read time (most recently touched first).
3. **No section headers** -- the transition between unread and partially read is a subtle visual shift (read items have dimmer styling), not a hard section break. This keeps the reading experience low-pressure.

---

## macOS Layout

### Three-Column NavigationSplitView

```
+----------+---------------------+-------------------------------+
|          | [Account Filter]    |                               |
| Sidebar  |   All | Work | Pers |                               |
| (glass)  |---------------------+                               |
|          |                     |  Stratechery                  |
| Action   | Stratechery   Today |  by Ben Thompson              |
| Queue    |   The End of the    |  February 7, 2026             |
|   [3]    |   Beginning         |                               |
|          |                     |  --------------------------   |
| > Read.  | Hacker Newsletter   |                               |
|   Queue  |   Issue #847     Yd |  [newsletter body rendered    |
|          |   This week's top   |   in reader-optimized         |
| Recom.   |   links...          |   WKWebView with comfortable  |
|          |                     |   typography, 680px max       |
| Filtered | Dense Discovery  2d |   width, 1.6 line height]     |
|          |   Books, Movies,    |                               |
| All In.  |   Music we loved... |                               |
|          |                     |                               |
| -------- | The Pragmatic Eng 3d|  --------------------------   |
| Digest   |   How Stripe built  |                               |
|          |   its billing...    |  Source: Stratechery           |
|          |                     |  [Open original email]        |
+----------+---------------------+-------------------------------+
  220pt          340pt                    flexible
```

### Content Column (Newsletter List)

**Newsletter rows** are a variant of the standard `EmailRow` with reading-specific modifications:

```
macOS Newsletter Row (64pt height):
+---------------------------------------------------------------+
| [dot]  Stratechery                                    Today   |
|        The End of the Beginning                               |
|        This week I want to revisit a theme...                 |
+---------------------------------------------------------------+

Partially read variant (dimmer):
+---------------------------------------------------------------+
| [dot]  Hacker Newsletter                             2 days   |
|        Issue #847                                             |
|        This week's top links and discussion...     [50% read] |
+---------------------------------------------------------------+
```

**Differences from standard EmailRow in Reading Queue:**

- **No snooze badges** -- newsletters are not snoozable (no urgency model)
- **No bold/unread distinction** -- the reading queue is inherently casual; visual difference between read/unread is subtle (opacity change, not bold/regular weight)
- **Reading progress indicator** (optional): For partially-read newsletters, a small progress bar or percentage at the trailing edge of the snippet line
- **Source name as primary text**: The newsletter name (e.g., "Stratechery") is the primary identifier, not the sender email. Displayed in `.headline` weight.
- **Recommendation extraction badge**: If recommendations were extracted from this newsletter, show a small star icon + count (e.g., star with "3") at trailing edge. Tapping navigates to Recommendations filtered by this source.

**No section headers**: Unlike Action Queue, Reading Queue does not use section headers. Unread items appear at top, partially read items sink to bottom, but there is no visible divider. This keeps the experience low-pressure.

**No badge count in sidebar**: The Reading Queue sidebar row does NOT show a badge count. This is a deliberate ADHD-friendly decision from the product brief. Newsletters should never create anxiety.

### Detail Column -- Newsletter Reader

The detail column transforms into a reader view optimized for long-form content. This is the most important differentiating UX element of the Reading Queue.

```
+----------------------------------------------+
| [toolbar: Archive  Open Original  Share]     |
|----------------------------------------------+
|                                              |
|  Stratechery                                 |
|  by Ben Thompson                             |
|  February 7, 2026                            |
|                                              |
|  ============================================|
|                                              |
|  [Reader-optimized WKWebView]                |
|                                              |
|  The newsletter body is rendered with:       |
|  - San Francisco system font at 17px        |
|  - 1.6 line height for readability          |
|  - 680px max-width, centered                |
|  - Generous horizontal padding (24px)       |
|  - Light/dark mode appropriate colors       |
|  - No distracting newsletter chrome         |
|    (headers, footers, share buttons          |
|     stripped or minimized)                   |
|                                              |
|  ============================================|
|                                              |
|  Recommendations extracted:                  |
|  [Book icon] "The Innovator's Dilemma"       |
|  [Article icon] "How Stripe Built..."        |
|  (links to Recommendations view)             |
|                                              |
|  ============================================|
|                                              |
|  Source: Stratechery                          |
|  Original: [Open in All Inboxes]             |
|                                              |
+----------------------------------------------+
```

**Reader typography** (CSS injected into WKWebView):

```css
body {
  font: -apple-system-body;
  font-size: 17px;
  line-height: 1.6;
  max-width: 680px;
  margin: 0 auto;
  padding: 0 24px;
  color: var(--text-primary);
  background: var(--background);
}

h1, h2, h3 {
  line-height: 1.3;
  margin-top: 1.5em;
}

img {
  max-width: 100%;
  height: auto;
  border-radius: 8px;
}

a {
  color: var(--accent);
}

blockquote {
  border-left: 3px solid var(--accent);
  margin-left: 0;
  padding-left: 16px;
  color: var(--text-secondary);
  font-style: italic;
}
```

**Newsletter chrome stripping**: The server sanitizes newsletter HTML before sending to the client. Common newsletter elements to strip or de-emphasize:
- Unsubscribe footers
- Social media share buttons
- "View in browser" links
- Tracking pixels (already removed server-side)
- Redundant header images/logos (keep one at top)

**Toolbar actions** (glass button style):

| Button | Icon | Shortcut | Action |
|--------|------|----------|--------|
| Archive | `archivebox.fill` | `E` | Archive newsletter, move to next |
| Open Original | `envelope.fill` | `O` | Navigate to this email in All Inboxes |
| Share | `square.and.arrow.up` | -- | System share sheet |

Note: No Reply, Reply All, or Forward in the Reading Queue toolbar. Newsletters do not require responses. If the user needs to forward a newsletter, they can use the command palette or open the original email.

**Extracted recommendations footer**: Below the newsletter content, show any recommendations the AI extracted from this newsletter. Each recommendation is a compact row (type icon + title + creator). Tapping navigates to the Recommendations view filtered to this source. This creates a natural bridge between reading and browsing recommendations.

**Sequential reading mode**: On macOS, after archiving the current newsletter (`E`), the detail column automatically loads the next unread newsletter. This enables a flow where the user reads, archives, reads, archives without returning to the list. J/K in the list column cycles through newsletters and updates the reader. This mirrors the sequential consumption pattern identified in the existing-clients-analysis research.

---

## iOS iPhone Layout

### Tab Bar Position

Reading Queue is Tab 2. Icon: `book.fill`. No badge count (deliberate).

### List View

```
+-------------------------------------------+
|  Reading Queue                  [filter]  |
|  [All] [Work] [Personal]                  |
|-------------------------------------------+
|                                           |
|  +---------------------------------------+|
|  |[*] Stratechery                 Today  ||
|  |    The End of the Beginning           ||
|  |    This week I want to revisit...     ||
|  +---------------------------------------+|
|  |[*] Hacker Newsletter         Yester.  ||
|  |    Issue #847                         ||
|  |    This week's top links...           ||
|  +---------------------------------------+|
|  |[*] Dense Discovery           2 days   ||
|  |    Books, Movies, Music               ||
|  |    Things we loved this week...       ||
|  +---------------------------------------+|
|                                           |
|-------------------------------------------+
| [Action] [Reading] [Recs] [More]          |
+-------------------------------------------+
```

**Swipe actions** (reduced set compared to Action Queue -- no snooze for newsletters):

| Direction | Distance | Action | Color |
|-----------|----------|--------|-------|
| Right (short) | ~80pt | Mark as partially read | `Color.newsletter` |
| Right (full) | >160pt | Archive | `Color.success` |
| Left (full) | >160pt | Delete | `Color.destructive` |

**Long press context menu**:
- Archive
- Open Original
- Share
- Mark as partially read
- Delete

### Detail View -- Newsletter Reader (pushed via NavigationStack)

```
+-------------------------------------------+
|  < Back                        [actions]  |
|-------------------------------------------+
|                                           |
|  Stratechery                              |
|  by Ben Thompson                          |
|  February 7, 2026                         |
|                                           |
|  -----------------------------------------|
|                                           |
|  [Reader-optimized WKWebView]             |
|  - System font at 17px                   |
|  - 1.6 line height                       |
|  - 16px horizontal padding (iOS)         |
|  - Full width, no max-width constraint   |
|    (phone screens are narrow enough)     |
|                                           |
|  -----------------------------------------|
|                                           |
|  Extracted recommendations (3):           |
|  [Book] The Innovator's Dilemma           |
|  [Article] How Stripe Built Billing       |
|  [Podcast] Acquired: Stripe              |
|                                           |
|-------------------------------------------+
|  [Archive]     [Share]                    |
+-------------------------------------------+
```

**iOS reader CSS differences from macOS:**
- `padding: 0 16px` (narrower margins for phone)
- No `max-width` constraint (phone screen is already narrow)
- Touch-friendly link target sizes (minimum 44pt tap targets)

**Bottom action bar**: Archive and Share buttons. Glass-styled.

**Swipe between newsletters**: In the reader detail view, swiping left/right navigates to the previous/next newsletter without returning to the list. This enables sequential reading on mobile.

---

## iOS iPad Layout

Uses the macOS three-column layout when in landscape. In portrait, the sidebar overlays the content area. The reader column is the primary focus, taking the most screen real estate.

The reader CSS on iPad uses:
- `max-width: 680px` (same as macOS)
- `padding: 0 24px` (same as macOS)
- Full-width when in compact width (portrait with sidebar visible)

---

## Component Specifications

### NewsletterRow (variant of EmailRow)

```
Specification:
- Inherits EmailRow base layout
- Primary text: Newsletter source name (not sender email) in .headline
- Secondary text: Newsletter subject/title in .subheadline
- Snippet: First line of content in .caption, Color.textSecondary
- No bold/regular distinction for read/unread
  (instead: unread rows have full opacity, read rows have 0.7 opacity)
- No snooze-related badges
- Recommendation badge: small star icon + count at trailing edge
  if recommendations were extracted from this newsletter
- Reading progress: thin progress bar at bottom of row for
  partially-read newsletters (optional, can be omitted in v1)
- Account dot: standard AccountDot component
- Timestamp: relative time in .caption
```

### NewsletterReaderView

The reader view for the detail column.

```
Specification:
- Header: Newsletter name (.title2, bold),
  author (.subheadline, Color.textSecondary),
  date (.caption, Color.textTertiary)
- Divider: 1pt line, Color.separator
- Body: WKWebView with reader CSS injected
- Footer: Extracted recommendations list (if any)
- Source attribution: "Source: [newsletter name]" with
  link to view in All Inboxes
- No glass effects anywhere (this is pure content)
- Background: system window background (not glass)
```

### RecommendationExtractionFooter

Shown below the newsletter content when recommendations were extracted.

```
Specification:
- Section header: "Recommendations extracted" in .caption, uppercase
- List of recommendations:
  - Each row: [type icon] [title] by [creator]
  - Type icon colored per recommendation type color tokens
  - Tapping a recommendation navigates to Recommendations view
    with that item selected
- Compact layout: no cards, just a simple list
- Max 5 items shown. If more: "View all N recommendations" link
```

---

## Keyboard Shortcuts (macOS)

| Key | Action | Notes |
|-----|--------|-------|
| `J` | Move selection down in newsletter list | |
| `K` | Move selection up | |
| `Enter` | Open selected in reader column | Loads newsletter body |
| `E` | Archive current newsletter | Auto-advances to next |
| `O` | Open original email in All Inboxes | Switches view |
| `N` / `P` | Next / Previous newsletter while in reader | Sequential reading |
| `Escape` | Return focus to list column | |
| `Space` | Scroll reader content down one page | Reader has focus |
| `Shift+Space` | Scroll reader content up one page | |

Note: No `R` (Reply), `S` (Snooze), or `F` (Forward) shortcuts in Reading Queue context. These actions are irrelevant for newsletter reading and removing them reinforces the "this is not an inbox" feeling.

---

## Gestures (iOS)

| Gesture | Action |
|---------|--------|
| Tap row | Push to reader view |
| Swipe right (short) | Mark partially read |
| Swipe right (full) | Archive |
| Swipe left (full) | Delete |
| Long press | Context menu |
| Pull down | Refresh |
| In reader: swipe left/right | Next/previous newsletter |
| In reader: scroll | Read content |

---

## States

### Empty State

```
Icon: "book.closed" SF Symbol, 48pt, Color.textTertiary
Title: "Nothing to read"
Subtitle: "Newsletters will appear here as they arrive"
Tone: Neutral, not rewarding (unlike Action Queue's "All caught up")
```

### Loading State

```
First load: Centered ProgressView with "Loading newsletters..."
Subsequent: Subtle inline indicator
Show cached newsletters immediately, update in background
```

### Error State

```
If cached data exists: Show cached newsletters + OfflineBanner
If no cached data: Error view with "Cannot reach server" and Retry
```

### Populated State

```
- List of newsletters, unread first, partially read below
- First unread newsletter auto-loaded in reader (macOS)
- No urgency indicators (no badges, no bold counts)
- Real-time updates: new newsletters insert at top
```

---

## Navigation Flow

### From Reading Queue to Other Views

- **Recommendations**: Tapping extracted recommendations in the reader footer navigates to Recommendations view
- **All Inboxes**: "Open original" button navigates to All Inboxes with this email selected
- **Action Queue**: If user reclassifies newsletter as "needs response" (via command palette), moves to Action Queue

### Into Reading Queue from Other Views

- **Sidebar/Tab**: Cmd+2 or tab tap
- **Daily Digest**: "N newsletters arrived today" links to Reading Queue
- **Action Queue**: Reclassifying an action email as "newsletter" moves it here
- **Recommendations**: "Source: Stratechery" link on a recommendation card navigates here with that newsletter selected

---

## Account Filtering Behavior

Same global account filter as other views. When filtered:
- Only newsletters received by the selected account(s) appear
- Filter persists across view switches
- Most users will likely leave this on "All" since newsletters go to personal accounts

---

## Real-Time Updates

### New Newsletter Arrives

1. WebSocket delivers `new_email` event with `classification=newsletter`
2. Newsletter inserts at top of list (sorted by `receivedAt`)
3. Row animates in
4. No badge count update (no badge on Reading Queue)
5. No notification delivered (newsletters never notify)

### Newsletter Archived

1. Row animates out
2. If reading in sequential mode, reader advances to next newsletter
3. Undo toast appears

---

## Design Tokens Referenced

| Token | Usage in this view |
|-------|--------------------|
| `Color.newsletter` (#06B6D4 cyan) | Reading progress indicator, mark-partially-read swipe |
| `Color.textPrimary` | Newsletter name, subject |
| `Color.textSecondary` | Author, snippet, read state |
| `Color.textTertiary` | Dates, metadata |
| Reader typography | 17px body, 1.6 line height, 680px max-width |
| `space-2xl` (24pt) | Reader horizontal padding (macOS) |
| `space-lg` (16pt) | Reader horizontal padding (iOS) |
| Row height | 64pt macOS, 72pt iOS |

---

## Accessibility

- VoiceOver: Newsletter rows announced as "Newsletter from [source name], [subject], [relative time], [read status]"
- Reader view: WKWebView content should be accessible via VoiceOver with proper heading hierarchy
- Reading progress announced: "50 percent read" if progress tracking is implemented
- No badge anxiety: VoiceOver does NOT announce a count for Reading Queue in sidebar
- Extracted recommendations footer: Each item announced as "[type]: [title] by [creator]"

---

## Design Decisions and Rationale

### Why No Badge Count

The product brief explicitly states: no badge counts on Reading Queue. This is an ADHD-friendly decision. Badge counts on newsletter queues create low-grade anxiety about "falling behind." Newsletters are optional reading -- they should never feel like obligations.

### Why No Snooze

Snooze implies urgency and deferred obligation. Newsletters have neither. The metaphor is a reading stack on a nightstand, not a to-do list. Partially-read items simply sink to the bottom and wait patiently.

### Why No Reply/Forward Shortcuts

Removing email-action shortcuts (R, F, A) from the Reading Queue reinforces the mental model that this is a reading app, not an inbox. If the user genuinely needs to forward a newsletter, the command palette (Cmd+K) or "Open Original" provides a path.

### Why Sequential Reading

Research from newsletter-focused tools (Meco, Stoop) shows that the best newsletter UIs support moving through items one at a time. Our sequential mode (E to archive and advance, N/P to navigate) enables a flow state where the user reads through their newsletter stack without context-switching to the list view.

---

## Referenced By

- [Design System](./design-system.md) -- shared tokens and components
- [Recommendations](./recommendations.md) -- recommendations extracted from newsletters link back here
- [Daily Digest](./daily-digest.md) -- digest surfaces newsletter arrival count
