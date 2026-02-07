# Recommendations -- View Specification

> Canonical UI/UX spec for the Recommendations view. References [design-system.md](./design-system.md) for shared tokens, patterns, and components.

---

## Purpose

The Recommendations view surfaces books, movies, music, articles, podcasts, and other items automatically extracted from newsletters. It transforms passive newsletter reading into an actionable personal discovery feed. This is the app's key differentiating feature.

---

## User Goals

1. **Discover what was recommended** -- see everything newsletters have suggested without re-reading newsletters.
2. **Filter by type** -- browse only books, only movies, etc. when in a specific mood or context.
3. **Track status** -- save items for later, mark as done, dismiss uninteresting ones.
4. **See social proof** -- know when multiple trusted sources recommend the same thing.
5. **Trace back to source** -- read the original context paragraph and navigate to the source newsletter.

---

## Data Source

- API: `GET /api/recommendations?type=&status=`
- WebSocket events: `new_recommendation`, `recommendation_updated`
- Model: `Recommendation` (id, type, title, creator, sourceNewsletterName, sourceDate, contextSnippet, status, duplicateCount, duplicateSources)

### Ordering

- **New items first** -- status=new at top, sorted by sourceDate descending
- **Saved items** -- status=saved below new, sorted by save date
- **Done/Dismissed** -- hidden by default (available via status filter)

### Filtering

Two filter axes:
1. **Type filter**: All, Books, Movies/TV, Music, Articles, Podcasts, Other
2. **Status filter**: New (default), Saved, Done, Dismissed, All

Both filters can be active simultaneously (e.g., "show me saved books").

---

## macOS Layout

### Three-Column NavigationSplitView

The Recommendations view uses the content column differently from email views. Instead of a list, it shows a card grid or a filterable list, depending on the number of items.

```
+----------+------------------------------+----------------------------+
|          | [Type Filter]                |                            |
| Sidebar  | All | Books | Movies | Music |                            |
| (glass)  | Articles | Podcasts | Other  |                            |
|          |------------------------------+                            |
|          | [Status: New v]              |  "The Innovator's Dilemma" |
| Action   |                              |  by Clayton Christensen    |
| Queue    | +---------------------------+|                            |
|   [3]    | | [Book] The Innovator's    ||  Type: Book                |
|          | | Dilemma                   ||  Status: [New]             |
| Reading  | | Clayton Christensen       ||                            |
| Queue    | | "Ben called it 'the best  ||  Context:                  |
|          | | explanation of modularity ||  "Ben called it 'the best  |
| > Recom. | | theory I've read'"        ||  explanation of modularity |
|          | | From Stratechery, Feb 7   ||  theory I've ever read.'   |
| Filtered | | [New] [Save] [Done] [X]   ||  It's a book that every    |
|          | +---------------------------+|  founder should read       |
| All In.  |                              |  at least twice."          |
|          | +---------------------------+|                            |
| -------- | | [Article] How Stripe      ||  Source: Stratechery       |
| Digest   | | Built Billing             ||  Date: February 7, 2026   |
|          | | by Patrick Collison       ||                            |
|          | | "A masterclass in..."     ||  Recommended by 3 sources  |
|          | | From Pragmatic Eng, Feb 6 ||  > Stratechery, Feb 7      |
|          | | [New] [Save] [Done] [X]   ||  > Pragmatic Eng, Feb 6    |
|          | +---------------------------+|  > Hacker Newsletter, Feb 5|
|          |                              |                            |
|          | +---------------------------+|  [Open source newsletter]  |
|          | | [Podcast] Acquired:       ||  [Open in browser]         |
|          | | Stripe Episode            ||                            |
|          | +---------------------------+|                            |
+----------+------------------------------+----------------------------+
  220pt          340pt                           flexible
```

### Content Column -- Recommendation List

**Type Filter Bar**

Positioned at the top of the content column as a horizontally scrolling row of pill buttons. Each pill shows the type icon and name.

```
Type filter layout:
[All] [Books] [Movies/TV] [Music] [Articles] [Podcasts] [Other]

Specification:
- Style: .glass button style pills
- Active pill: tinted with the type's color token (e.g., purple for Books)
- Icon: SF Symbol matching the type (book.fill, film.fill, etc.)
- Position: Sticky at top, below toolbar
- Scrollable horizontally if all pills don't fit
```

**Status Filter**

Below the type filter, a simple dropdown or segmented control:

```
Status filter:
[New] [Saved] [Done] [Dismissed] [All]

Default: New (shows new recommendations waiting for user action)
Specification:
- Style: Segmented picker or dropdown menu
- Compact: "New" with a count badge (e.g., "New (12)")
- Not glass (inline content control)
```

**Recommendation Cards**

Each recommendation is displayed as a card in the content column. Cards are the primary interaction surface.

```
Recommendation Card (macOS, ~120pt height):
+----------------------------------------------------------+
| [Type Icon]  Title of the Recommendation                 |
|   (colored)  by Creator Name                             |
|                                                          |
|   "Context quote from the newsletter that                |
|    mentioned this recommendation..."                     |
|                                                          |
|   From Stratechery -- Feb 7    [Rec'd by 3 sources]     |
|                                                          |
|   [Save]   [Done]   [Dismiss]                           |
+----------------------------------------------------------+

Card specification:
- Background: system grouped background (NOT glass)
- Corner radius: 12pt
- Padding: space-lg (16pt)
- Shadow: subtle drop shadow (0.5pt blur, 5% opacity)
- Border: none (light mode), 1pt separator color (dark mode)
- Selected state: accent-colored left border (3pt)
```

**Card elements:**

| Element | Style | Notes |
|---------|-------|-------|
| Type icon | SF Symbol, 20pt, type color | Leading, top-aligned |
| Title | `.headline`, `Color.textPrimary` | Bold |
| Creator | `.subheadline`, `Color.textSecondary` | Author, director, artist |
| Context snippet | `.callout`, `Color.textSecondary`, italic | Max 2 lines, truncated |
| Source + date | `.caption`, `Color.textTertiary` | "From [source] -- [date]" |
| Duplicate badge | `.caption`, `Color.accentColor` | "Rec'd by N sources" |
| Action buttons | `.caption`, pill-shaped | Save (accent), Done (success), Dismiss (gray) |

**Action buttons behavior:**

| Button | Label | Icon | Keyboard | Result |
|--------|-------|------|----------|--------|
| Save | "Save" | `bookmark.fill` | `S` | Status -> saved, card moves to Saved section |
| Done | "Done" | `checkmark.circle.fill` | `D` | Status -> done, card animates out |
| Dismiss | Dismiss (X) | `xmark` | `X` | Status -> dismissed, card animates out |

When an action button is tapped, the status change is optimistic (immediate UI update) with a background API call. Undo toast appears for 5 seconds.

### Detail Column -- Recommendation Detail

When a recommendation card is selected (click or J/K + Enter), the detail column shows the full context.

```
+----------------------------------------------+
| [toolbar: Save  Done  Dismiss  Open Source]  |
|----------------------------------------------+
|                                              |
|  [Type Icon, large, colored]                 |
|                                              |
|  Title of the Recommendation                 |
|  by Creator Name                             |
|                                              |
|  Type: Book                                  |
|  Status: New                                 |
|                                              |
|  ============================================|
|                                              |
|  Context                                     |
|                                              |
|  "Ben called it 'the best explanation of     |
|  modularity theory I've ever read.' It's     |
|  a book that every founder should read       |
|  at least twice. Christensen's framework     |
|  explains why great companies fail when      |
|  facing disruptive innovation."              |
|                                              |
|  ============================================|
|                                              |
|  Source: Stratechery                          |
|  Date: February 7, 2026                      |
|  [Open source newsletter]                    |
|                                              |
|  ============================================|
|                                              |
|  Also recommended by:                        |
|                                              |
|  > Pragmatic Engineer -- February 6, 2026    |
|  "Gergely mentioned it as essential reading  |
|   for engineering managers..."               |
|                                              |
|  > Hacker Newsletter -- February 5, 2026    |
|  "This week's top pick in the business       |
|   section..."                                |
|                                              |
|  ============================================|
|                                              |
|  [Save]   [Done]   [Dismiss]                |
|                                              |
+----------------------------------------------+
```

**Detail sections:**

1. **Header**: Type icon (large), title, creator, type label, status badge
2. **Primary context**: The full paragraph from the source newsletter that mentioned this recommendation. Not truncated.
3. **Source attribution**: Newsletter name, date, link to open the source newsletter in Reading Queue
4. **Duplicate sources** (if duplicateCount > 1): Each additional source with its context snippet. This is powerful social proof -- "3 newsletters I trust all recommended this."
5. **Action buttons**: Same Save/Done/Dismiss buttons as the card, but larger.

**Toolbar actions** (glass button style):

| Button | Icon | Shortcut | Action |
|--------|------|----------|--------|
| Save | `bookmark.fill` | `S` | Save recommendation |
| Done | `checkmark.circle.fill` | `D` | Mark as done |
| Dismiss | `xmark.circle.fill` | `X` | Dismiss |
| Open Source | `newspaper.fill` | `O` | Navigate to source newsletter |

---

## iOS iPhone Layout

### Tab Bar Position

Recommendations is Tab 3. Icon: `star.fill`. No badge count.

### List View

```
+-------------------------------------------+
|  Recommendations                          |
|  [All][Books][Movies][Music][Art][Pod]     |
|  [Status: New v]                          |
|-------------------------------------------+
|                                           |
|  +---------------------------------------+|
|  | [Book] The Innovator's Dilemma        ||
|  | Clayton Christensen                   ||
|  | "Ben called it 'the best..."          ||
|  | Stratechery, Feb 7   Rec'd by 3       ||
|  +---------------------------------------+|
|                                           |
|  +---------------------------------------+|
|  | [Article] How Stripe Built Billing    ||
|  | Patrick Collison                      ||
|  | "A masterclass in systems..."         ||
|  | Pragmatic Engineer, Feb 6             ||
|  +---------------------------------------+|
|                                           |
|  +---------------------------------------+|
|  | [Podcast] Acquired: Stripe            ||
|  | Ben Gilbert & David Rosenthal         ||
|  | "The definitive history of..."        ||
|  | Hacker Newsletter, Feb 5              ||
|  +---------------------------------------+|
|                                           |
|-------------------------------------------+
| [Action] [Reading] [Recs] [More]          |
+-------------------------------------------+
```

**Type filter**: Horizontally scrolling pill bar below nav title. Same glass pills as macOS.

**Status filter**: Dropdown in navigation bar trailing position, or inline below type filter.

**Swipe actions**:

| Direction | Distance | Action | Color |
|-----------|----------|--------|-------|
| Right (short) | ~80pt | Save | `Color.accentColor` |
| Left (short) | ~80pt | Dismiss | `Color.filtered` |
| Left (full) | >160pt | Mark done | `Color.success` |

**Long press context menu**:
- Save
- Mark as Done
- Dismiss
- Open Source Newsletter
- Share

### Detail View (pushed via NavigationStack)

```
+-------------------------------------------+
|  < Back                        [actions]  |
|-------------------------------------------+
|                                           |
|  [Book icon, large, purple]              |
|                                           |
|  The Innovator's Dilemma                  |
|  by Clayton Christensen                   |
|                                           |
|  Status: New                              |
|                                           |
|  -----------------------------------------|
|                                           |
|  Context                                  |
|  "Ben called it 'the best explanation     |
|  of modularity theory I've ever read.'    |
|  It's a book that every founder should    |
|  read at least twice."                    |
|                                           |
|  Source: Stratechery                       |
|  February 7, 2026                         |
|                                           |
|  -----------------------------------------|
|                                           |
|  Also recommended by:                     |
|  Pragmatic Engineer -- Feb 6              |
|  "Gergely mentioned it as essential..."   |
|                                           |
|  Hacker Newsletter -- Feb 5              |
|  "This week's top pick..."               |
|                                           |
|-------------------------------------------+
|  [Save]     [Done]     [Dismiss]          |
+-------------------------------------------+
```

**Bottom action bar**: Save, Done, Dismiss buttons. Glass-styled.

---

## iOS iPad Layout

Uses the macOS three-column layout. The card list in the content column adapts to wider widths by showing cards at a comfortable reading width. Detail column shows the full recommendation detail.

---

## Component Specifications

### RecommendationCard

```
Specification:
- Shape: RoundedRectangle, cornerRadius 12pt
- Background: .secondarySystemGroupedBackground (NOT glass)
- Padding: space-lg (16pt) all sides
- Shadow: subtle (offset: 0, blur: 2, opacity: 0.08) light mode only
- Border: 1pt Color.separator in dark mode only

Layout:
- Leading: Type icon (SF Symbol, 20pt, type color, top-aligned)
- Body (16pt leading inset from icon):
  - Title: .headline, Color.textPrimary
  - Creator: .subheadline, Color.textSecondary
  - Context: .callout, Color.textSecondary, italic, max 2 lines
  - Footer row: Source + date (.caption, Color.textTertiary)
    + duplicate badge (.caption, Color.accentColor)
- Trailing: Action buttons row (only on macOS; iOS uses swipe)

States:
- Default: Standard card appearance
- Selected (macOS): 3pt accent-colored left border
- Hover (macOS): Slight background brightness increase
- Status change animating: Card fades/slides out
```

### TypeFilterPill

```
Specification:
- Shape: Capsule
- Style: .glass button style
- Content: [type icon] [type name]
- Active: Tinted with type color, filled appearance
- Inactive: Neutral glass, unfilled
- Size: Fits content, minimum 44pt height (iOS touch target)
- Layout: Horizontal scroll, leading-aligned
```

### StatusFilterPicker

```
Specification:
- Style: Menu button (macOS) or picker (iOS)
- Options: New, Saved, Done, Dismissed, All
- Default selection: New
- Badge: Show count next to "New" option (e.g., "New (12)")
- Position: Below type filter bar
```

### DuplicateSourcesList

```
Specification:
- Header: "Also recommended by:" in .caption, uppercase
- Each source:
  - Newsletter name: .subheadline, Color.textPrimary
  - Date: .caption, Color.textTertiary
  - Context snippet: .callout, Color.textSecondary, italic
  - Separator: 1pt line between sources
- Position: In detail view, below primary context
- Collapsible: If more than 3 sources, show first 3 + "Show N more"
```

---

## Keyboard Shortcuts (macOS)

| Key | Action | Notes |
|-----|--------|-------|
| `J` | Move selection down in card list | |
| `K` | Move selection up | |
| `Enter` | Open selected recommendation in detail | |
| `S` | Save recommendation | Status -> saved |
| `D` | Mark as done | Status -> done |
| `X` | Dismiss recommendation | Status -> dismissed |
| `O` | Open source newsletter | Navigate to Reading Queue |
| `Escape` | Return focus to list / close detail | |
| `1`-`7` | Quick type filter | 1=All, 2=Books, 3=Movies, 4=Music, 5=Articles, 6=Podcasts, 7=Other |
| `Cmd+Z` | Undo last status change | While undo toast visible |

Note: `R`, `A`, `F`, `E` are intentionally not mapped in this view. These are email actions and do not apply to recommendations.

---

## Gestures (iOS)

| Gesture | Action |
|---------|--------|
| Tap card | Push to detail view |
| Swipe right (short) | Save |
| Swipe left (short) | Dismiss |
| Swipe left (full) | Mark done |
| Long press | Context menu (Save, Done, Dismiss, Open Source, Share) |
| Pull down | Refresh |
| In detail: swipe from left edge | Go back to list |

---

## States

### Empty State

```
Icon: "star.circle" SF Symbol, 48pt, Color.textTertiary
Title: "No recommendations yet"
Subtitle: "As you read newsletters, recommendations for books,
  movies, music, articles, and podcasts will be extracted
  automatically"
Tone: Informative, setting expectations
```

### Empty State (filtered)

When filters result in no matches:

```
Icon: "line.3.horizontal.decrease.circle" SF Symbol
Title: "No [type] recommendations"
Subtitle: "Try a different filter or check back after
  reading more newsletters"
```

### Loading State

```
First load: Centered ProgressView with "Loading recommendations..."
Subsequent: Subtle inline indicator
Show cached recommendations immediately, update in background
```

### Error State

```
If cached data exists: Show cached data + OfflineBanner
If no cached data: Error view with retry button
```

### Populated State

```
- Cards displayed in scrollable list
- Type and status filters active
- First card auto-selected on macOS
- Real-time updates: new recommendations insert at top
```

---

## Navigation Flow

### From Recommendations to Other Views

- **Reading Queue**: "Open source newsletter" navigates to Reading Queue with the source newsletter selected in the reader
- **All Inboxes**: If the source email needs to be viewed in full context
- **External**: Future consideration -- deep links to Goodreads, Letterboxd, Spotify, etc.

### Into Recommendations from Other Views

- **Sidebar/Tab**: Cmd+3 or tab tap
- **Reading Queue**: Tapping extracted recommendations in the newsletter reader footer navigates here
- **Daily Digest**: "N new recommendations today" links here

---

## Account Filtering Behavior

Account filtering is less relevant for Recommendations since they are extracted from newsletters (which are typically received on personal accounts). However, the global account filter still applies:

- When filtered to an account, only recommendations extracted from newsletters received by that account are shown
- This is a secondary use case -- most users will browse recommendations with "All" selected

---

## Real-Time Updates

### New Recommendation Extracted

1. WebSocket delivers `new_recommendation` event
2. If current filter matches (type + status), card inserts at top of list
3. Card animates in (slides down from top)

### Recommendation Status Changed (by user on another device)

1. WebSocket delivers `recommendation_updated` event
2. Card updates in place or moves to appropriate section
3. If filtered out by current status filter, card animates out

---

## Design Tokens Referenced

| Token | Usage in this view |
|-------|--------------------|
| `Color.recBook` (#8B5CF6) | Book type icon and active filter pill tint |
| `Color.recMovie` (#EF4444) | Movie/TV type icon |
| `Color.recMusic` (#EC4899) | Music type icon |
| `Color.recArticle` (#3B82F6) | Article type icon |
| `Color.recPodcast` (#F97316) | Podcast type icon |
| `Color.recOther` (#6B7280) | Other type icon |
| `Color.accentColor` | Save action, selected card border, duplicate badge |
| `Color.success` | Done action |
| `Color.filtered` | Dismiss action |
| `.headline` | Card title |
| `.subheadline` | Creator name |
| `.callout` | Context snippet |
| `.caption` | Source, date, metadata |
| `space-lg` (16pt) | Card padding |
| Card corner radius | 12pt |

---

## Accessibility

- VoiceOver: Cards announced as "[Type]: [Title] by [Creator], from [Source], status: [Status], [recommended by N sources if duplicate]"
- Type filter pills: Each announced as "Filter by [type], [active/inactive]"
- Status filter: Announced as "Show [status] recommendations"
- Action buttons: "Save recommendation", "Mark as done", "Dismiss recommendation"
- Duplicate sources section: "Also recommended by N sources" as section header
- Each source: "[Newsletter name], [date], [context quote]"

---

## Design Decisions and Rationale

### Why Cards Instead of List Rows

Recommendations are not emails. They are discovery items with visual anchors (type icons), context snippets, and multi-source attribution. Cards communicate "browse and discover" while list rows communicate "process and triage." The metaphor should be a bookshelf or media library, not an inbox.

### Why Type Colors

Each recommendation type has a distinct color so users can quickly scan the list and identify content types visually. This is inspired by Letterboxd (movies = visual, Goodreads = books) where type-specific visual language makes browsing faster.

### Why Duplicate Consolidation

When three trusted newsletter authors all recommend the same book, that signal is much stronger than a single mention. Consolidating duplicates with "Recommended by 3 sources" creates social proof from trusted human curators. Each source's context paragraph is preserved so the user can read why different authors recommend the same item.

### Why No Account Filter Emphasis

Recommendations are derived from newsletters, which are typically received on personal accounts. The account filter is technically available but is a secondary concern. The primary filter axes are type and status.

---

## Future Considerations (Not in Scope for v1)

- **Visual anchors**: Fetch book covers, movie posters, album art from external APIs (Open Library, TMDB, Spotify). Currently, type icons serve as visual anchors.
- **Export integrations**: Save to Goodreads "Want to Read", add to Letterboxd watchlist, save article to Pocket.
- **Manual additions**: User adds their own recommendations (marked "Added by you").
- **Search within recommendations**: Filter by title, creator, source.

---

## Referenced By

- [Design System](./design-system.md) -- shared tokens and components
- [Reading Queue](./reading-queue.md) -- recommendations extracted from newsletters link both directions
- [Daily Digest](./daily-digest.md) -- digest mentions new recommendation counts
