# Design System: Shared Tokens, Patterns, and Components

> Canonical reference for all UI/UX specs. Every view-level spec in this directory references this file for shared values. If a token, pattern, or component is used across multiple views, it belongs here.

---

## Table of Contents

1. [Design Philosophy](#1-design-philosophy)
2. [Color System](#2-color-system)
3. [Typography Scale](#3-typography-scale)
4. [Spacing Scale](#4-spacing-scale)
5. [Liquid Glass Application](#5-liquid-glass-application)
6. [Shared Components](#6-shared-components)
7. [Navigation Architecture](#7-navigation-architecture)
8. [Keyboard System (macOS)](#8-keyboard-system-macos)
9. [Gesture System (iOS)](#9-gesture-system-ios)
10. [State Patterns](#10-state-patterns)
11. [Accessibility](#11-accessibility)
12. [Animation and Motion](#12-animation-and-motion)
13. [App Icon](#13-app-icon)

---

## 1. Design Philosophy

### Core Principles

1. **Content over chrome.** Glass navigation recedes; emails, newsletters, and recommendations are the visual focus.
2. **No complexity.** Five views plus digest. No settings labyrinths, no feature sprawl.
3. **Keyboard-first on Mac, touch-first on iOS.** Every action works with both, but optimize for the primary modality on each platform.
4. **Respect attention.** ADHD-friendly design: no badge counts on Reading Queue, no per-email notifications, digest-only alerts, predictable patterns.
5. **Trust through transparency.** Filtered view exists so the user can verify the AI. Classification overrides are always one action away.

### Design Language

Apple Liquid Glass (introduced WWDC 2025). Translucent materials for navigation chrome that reflect and refract their surroundings. Content areas remain opaque and high-contrast for readability.

---

## 2. Color System

### Account Colors

These are the primary semantic colors. They appear as dots, tints, and filter indicators.

| Account | Color Name | Light Mode Hex | Dark Mode Hex | SwiftUI Token |
|---------|-----------|----------------|---------------|---------------|
| Work | Blue | `#3B82F6` | `#60A5FA` | `Color.accountWork` |
| Personal 1 | Green | `#22C55E` | `#4ADE80` | `Color.accountPersonal1` |
| Personal 2 | Orange | `#F97316` | `#FB923C` | `Color.accountPersonal2` |

### Semantic Colors

| Purpose | Token | Light | Dark | Usage |
|---------|-------|-------|------|-------|
| Primary Text | `Color.textPrimary` | `.primary` | `.primary` | Email subjects, recommendation titles |
| Secondary Text | `Color.textSecondary` | `.secondary` | `.secondary` | Sender names, dates, snippets |
| Tertiary Text | `Color.textTertiary` | `.tertiary` | `.tertiary` | Metadata, counters |
| Accent | `Color.accentColor` | System blue | System blue | Interactive elements, selected states |
| Destructive | `Color.destructive` | System red | System red | Delete, permanent actions |
| Snooze | `Color.snooze` | `#8B5CF6` (purple) | `#A78BFA` | Snooze badges, returning items |
| Newsletter | `Color.newsletter` | `#06B6D4` (cyan) | `#22D3EE` | Reading Queue indicators |
| Filtered | `Color.filtered` | `#6B7280` (gray) | `#9CA3AF` | Filtered/spam indicators |
| Success | `Color.success` | `#22C55E` | `#4ADE80` | Archive confirmation, inbox zero |

### Recommendation Type Colors

| Type | Icon | Color Token |
|------|------|-------------|
| Book | `book.fill` | `Color.recBook` (#8B5CF6 purple) |
| Movie/TV | `film.fill` | `Color.recMovie` (#EF4444 red) |
| Music | `music.note` | `Color.recMusic` (#EC4899 pink) |
| Article | `doc.text.fill` | `Color.recArticle` (#3B82F6 blue) |
| Podcast | `mic.fill` | `Color.recPodcast` (#F97316 orange) |
| Other | `star.fill` | `Color.recOther` (#6B7280 gray) |

### Background Colors

| Context | Light | Dark |
|---------|-------|------|
| Window background | System default | System default |
| Content area | `.background` | `.background` |
| Grouped section | `.secondarySystemBackground` | `.secondarySystemBackground` |
| Selected row (macOS) | Accent with 15% opacity | Accent with 20% opacity |
| Hover row (macOS) | `.quaternarySystemFill` | `.quaternarySystemFill` |

---

## 3. Typography Scale

Use the system Dynamic Type scale. No custom fonts. The system font adapts to Liquid Glass contexts and accessibility settings automatically.

### Text Styles

| Token | SwiftUI Style | Weight | Usage |
|-------|--------------|--------|-------|
| `largeTitle` | `.largeTitle` | Bold | Digest section headers (iOS) |
| `title` | `.title` | Bold | View titles in navigation |
| `title2` | `.title2` | Semibold | Section headers |
| `title3` | `.title3` | Semibold | Card titles, email subject (detail) |
| `headline` | `.headline` | Semibold | Email subject (list row) |
| `subheadline` | `.subheadline` | Regular | Sender name, date in list |
| `body` | `.body` | Regular | Email body text, recommendation context |
| `callout` | `.callout` | Regular | Secondary information, labels |
| `caption` | `.caption` | Regular | Timestamps, metadata, badge text |
| `caption2` | `.caption2` | Regular | Tertiary metadata |

### Newsletter Reader Typography

The Reading Queue detail view uses a distinct reader typography for comfortable long-form reading:

| Element | Style | Line Spacing |
|---------|-------|-------------|
| Newsletter title | `.title2` bold | Default |
| Newsletter body | `.body` at 17pt effective size | 1.6x line height |
| Pull quotes | `.title3` italic | 1.4x |
| Source attribution | `.caption` | Default |

The newsletter reader content renders via WKWebView with injected CSS. The CSS should use:
- `font: -apple-system-body` (maps to San Francisco)
- `font-size: 17px` (comfortable reading size)
- `line-height: 1.6`
- `max-width: 680px` (optimal reading width)
- `margin: 0 auto` (centered content)
- `padding: 24px` horizontal on macOS, `16px` on iOS

---

## 4. Spacing Scale

Based on a 4pt grid. All spacing values are multiples of 4.

| Token | Value | Usage |
|-------|-------|-------|
| `space-xs` | 4pt | Icon-to-text gap, tight padding |
| `space-sm` | 8pt | List row internal padding, compact gaps |
| `space-md` | 12pt | Standard element spacing |
| `space-lg` | 16pt | Section padding, card margins |
| `space-xl` | 20pt | Between major sections |
| `space-2xl` | 24pt | Large section gaps, reader margins (macOS) |
| `space-3xl` | 32pt | View-level padding |
| `space-4xl` | 48pt | Empty state vertical spacing |

### List Row Dimensions

| Element | macOS | iOS |
|---------|-------|-----|
| Row height (email list) | 64pt | 72pt |
| Row horizontal padding | 12pt | 16pt |
| Row vertical padding | 8pt | 10pt |
| Account dot diameter | 8pt | 10pt |
| Snooze badge height | 20pt | 22pt |

### Column Widths (macOS NavigationSplitView)

| Column | Min | Ideal | Max |
|--------|-----|-------|-----|
| Sidebar | 180pt | 220pt | 260pt |
| Content (email list) | 280pt | 340pt | 420pt |
| Detail | 400pt | flexible | flexible |

---

## 5. Liquid Glass Application

### Elements That Receive Glass

These elements use `.glassEffect()` or equivalent glass material:

| Element | Glass Variant | Tinting |
|---------|--------------|---------|
| macOS sidebar | `.regular` | Account color tint when filtered to single account |
| macOS toolbar | `.regular` | None (neutral) |
| iOS tab bar | `.regular` | None |
| iOS navigation bar | `.regular` | None |
| Snooze time picker | `.regular` | Purple tint (`Color.snooze`) |
| Command palette overlay | `.regular` | None |
| Account filter segmented control | `.regular` | Active segment tinted with account color |
| Floating action buttons (iOS) | `.glass` button style | Context-dependent |
| Toolbar action buttons | `.glass` button style | None |

### Elements That Do NOT Receive Glass

| Element | Reason |
|---------|--------|
| Email list rows | Content, not chrome |
| Email body / HTML rendering | Content |
| Newsletter reader content | Content |
| Recommendation cards | Content |
| Digest sections content | Content |
| Compose text area | Content |
| Search results | Content |
| Empty state illustrations | Content |

### Glass Effect Containers

Use `GlassEffectContainer` to group glass elements that should morph together:

1. **Toolbar action group**: Reply, Archive, Snooze buttons in the detail view toolbar morph as a connected group.
2. **Snooze picker**: The time preset buttons morph within a shared container, expanding from the snooze button.
3. **Account filter**: The segmented control for All / Work / Personal morphs between states.

### Platform-Specific Glass Behavior

**macOS:**
- Sidebar uses glass with `.regular` variant
- Toolbar is standard macOS glass toolbar
- No touch-responsive glass effects (mouse/keyboard only)

**iOS:**
- Tab bar uses glass with `.regular` variant
- Navigation bar uses glass
- Touch-responsive: glass buttons scale on press, show touch-point illumination
- Tab bar minimizes on scroll down (`TabBarMinimizeBehavior.onScrollDown`)

---

## 6. Shared Components

### AccountDot

A small colored circle indicating which email account a message belongs to.

```
Specification:
- Shape: Circle
- Size: 8pt (macOS), 10pt (iOS)
- Color: Account color from token table
- Position: Leading edge of email row, vertically centered
- Accessibility label: "[Account name] account"
```

### BadgeView

A pill-shaped badge showing a count.

```
Specification:
- Shape: Capsule (fully rounded rect)
- Height: 20pt (macOS), 22pt (iOS)
- Min width: equal to height (for single digit)
- Background: Semantic color based on context:
    - Action Queue count: Color.accentColor
    - Snooze return count: Color.snooze
    - Filtered uncertain count: Color.filtered
- Text: .caption2, white, bold
- Position: Trailing edge of sidebar row
- Content: Number only, no text
- Behavior: Hidden when count is 0
- Reading Queue: NO badge (ADHD-friendly decision from brief)
```

### SnoozeCountBadge

Shows how many times an email has been snoozed ("snoozed 3x").

```
Specification:
- Shape: Capsule
- Background: Color.snooze at 15% opacity
- Text: "snoozed Nx" in .caption2, Color.snooze
- Position: Below subject line in email row, or in email detail header
- Visibility: Only shown when snoozeCount >= 2
```

### SnoozePicker

A popover/sheet for selecting snooze time. Appears when user presses S (macOS) or taps snooze button (iOS).

```
Layout (macOS - popover from toolbar button):
+-----------------------------------+
|  Snooze until...                  |
|                                   |
|  [2 hours]     [Tomorrow 9am]     |
|  [Next week]   [Custom...]        |
|                                   |
|  Custom: [_________________]      |
|  (type: "3d", "fri 2pm", etc.)   |
+-----------------------------------+

Layout (iOS - bottom sheet, .medium detent):
+-----------------------------------+
|  --- (drag handle) ---            |
|                                   |
|  Snooze until...                  |
|                                   |
|  [ 2 hours        >]             |
|  [ Tomorrow 9am   >]             |
|  [ Next week      >]             |
|  [ Custom...      >]             |
|                                   |
+-----------------------------------+

Glass application:
- macOS: Popover uses .glassEffect() on the background
- iOS: Sheet uses standard system sheet presentation
- Preset buttons: .glass button style

Keyboard interaction (macOS):
- S opens picker
- 1/2/3/4 selects preset
- Tab moves to custom field
- Enter confirms custom time
- Escape dismisses

States:
- Default: Show 4 presets + custom field
- Custom selected: Focus moves to text input field
- Confirming: Brief "Snoozed until [time]" confirmation text before dismiss
```

### AccountFilterControl

Segmented control for filtering by account.

```
macOS: Placed in the toolbar area, compact segmented picker
iOS: Placed below navigation title, or as a scrolling horizontal pill bar

Segments:
- All (no color tint)
- Work (blue dot + "Work")
- Personal (green dot + "Personal")
  Note: "Personal" combines both personal accounts by default
- Optionally: individual account names when tapping Personal again

Glass application:
- macOS: Segmented control with .glassEffect()
- iOS: Scrolling pill buttons with .glass button style

Keyboard shortcuts (macOS):
- Cmd+Shift+1: Work only
- Cmd+Shift+2: Personal only
- Cmd+Shift+3: All accounts

State:
- Active segment highlighted with account color tint on glass
- Count updates per-filter to show how many items in current view
```

### CommandPalette (macOS Only)

Floating overlay for fuzzy-search command execution. Inspired by Superhuman's Cmd+K.

```
Layout:
+-------------------------------------------+
|  > [search field________________________] |
|                                           |
|  Actions                                  |
|  > Reply                           R      |
|  > Archive                         E      |
|  > Snooze...                       S      |
|  > Forward                         F      |
|                                           |
|  Navigation                               |
|  > Action Queue                 Cmd+1     |
|  > Reading Queue                Cmd+2     |
|  > Recommendations              Cmd+3     |
|                                           |
|  Account Filter                           |
|  > Work only                Cmd+Shift+1   |
|  > Personal only            Cmd+Shift+2   |
|  > All accounts             Cmd+Shift+3   |
+-------------------------------------------+

Specification:
- Trigger: Cmd+K
- Position: Centered horizontally, top third of window vertically
- Width: 480pt
- Max height: 400pt (scrollable)
- Background: .glassEffect(.regular)
- Dismiss: Escape, click outside, or execute a command
- Search: Fuzzy match on command names
- Teaching: Show keyboard shortcut on trailing edge of each row
           so users learn shortcuts as they search
- Selection: Arrow keys to navigate, Enter to execute
- Grouping: Actions, Navigation, Account Filter sections
- Animation: Fade in + slight scale from 0.95 to 1.0
```

### OfflineBanner

Shown when the app cannot reach the Go server.

```
Specification:
- Position: Top of content area, below toolbar
- Height: 32pt
- Background: Color.destructive at 10% opacity
- Icon: "wifi.slash" SF Symbol
- Text: "Server unreachable -- showing cached data"
- Font: .caption, Color.destructive
- Behavior: Auto-dismisses when connection restored
- Animation: Slide down from top, slide up to dismiss
```

### UndoToast

Shown after reversible actions (archive, snooze, reclassify).

```
Specification:
- Position: Bottom center of content area, 16pt from bottom
- Shape: Capsule
- Background: .glassEffect(.regular) on macOS,
              system material on iOS
- Text: "[Action] completed" + "Undo" button
- Duration: 5 seconds, then fade out
- Interaction: Tap "Undo" to reverse action
- Keyboard: Cmd+Z triggers undo while toast is visible
- Animation: Slide up, fade in; slide down, fade out on dismiss
```

### EmptyStateView

Shown when a view has zero items.

```
Specification:
- Layout: Vertically centered in content area
- Icon: Large SF Symbol, 48pt, Color.textTertiary
- Title: .title2, Color.textPrimary
- Subtitle: .body, Color.textSecondary
- Max width: 320pt (text wraps within)
- No glass effect (this is content)

Per-view content:
- Action Queue: icon "checkmark.circle",
  title "All caught up", subtitle "No emails need your response"
- Reading Queue: icon "book.closed",
  title "Nothing to read", subtitle "Newsletters will appear here"
- Recommendations: icon "star.circle",
  title "No recommendations yet", subtitle "As you read newsletters,
  recommendations will be extracted automatically"
- Filtered: icon "xmark.shield",
  title "Nothing filtered", subtitle "Spam and marketing
  will appear here for review"
- All Inboxes: icon "tray",
  title "No emails", subtitle "Your inbox is empty"
- Digest: icon "sun.horizon",
  title "No digest yet", subtitle "Your first digest
  will be generated at 6:00 AM"
```

### EmailRow

The standard email list row used in Action Queue, Reading Queue, Filtered, and All Inboxes. The most frequently seen component.

```
macOS Layout (64pt height):
+---------------------------------------------------------------+
| [dot] [sender avatar/initials]  Sender Name        2:34 PM   |
|       Subject line of the email - truncated if lo...          |
|       First line of snippet text in secondary col...  [snz 3x]|
+---------------------------------------------------------------+

iOS Layout (72pt height):
+---------------------------------------------------------------+
| [dot]  Sender Name                              2:34 PM  >   |
|        Subject line of the email - truncated...               |
|        Snippet text here in secondary...          [snz 3x]   |
+---------------------------------------------------------------+

Elements:
- Account dot: leading, vertically centered (AccountDot component)
- Sender: .headline weight, textPrimary (unread) or textSecondary (read)
- Subject: .subheadline, textPrimary
- Snippet: .caption, textSecondary, max 1 line
- Timestamp: .caption, textTertiary, trailing
- Snooze badge: SnoozeCountBadge, shown only if snoozeCount >= 2
- Unread indicator: sender text is bold when unread
- Attachment indicator: paperclip icon if hasAttachments
- Snoozed-return indicator: Purple left border (2pt) + "Returning"
  label when item is a snooze return at top of Action Queue

No glass effect. This is a content row.

States:
- Unread: Bold sender name, slightly brighter overall
- Read: Regular weight sender name, slightly dimmer
- Selected (macOS): Accent background highlight
- Hover (macOS): Subtle quaternary fill
- Swiped (iOS): Reveals action buttons
- Snooze return: Purple left accent border
```

---

## 7. Navigation Architecture

### macOS: Three-Column NavigationSplitView

```
+----------+------------------+----------------------------+
|          |                  |                            |
| Sidebar  | Content Column   | Detail Column              |
| (glass)  | (email list /    | (email body /              |
|          |  rec grid /      |  newsletter reader /       |
|          |  digest)         |  rec detail)               |
|          |                  |                            |
| Cmd+1-5  |  J/K navigate    |  R reply, S snooze,       |
| +Digest  |  Enter open      |  E archive                |
|          |                  |                            |
+----------+------------------+----------------------------+
    220pt        340pt              flexible
```

**Sidebar contents (top to bottom):**
1. Action Queue -- with badge count
2. Reading Queue -- no badge (intentional)
3. Recommendations -- no badge
4. Filtered -- badge only for uncertain items (from digest)
5. All Inboxes -- no badge
6. --- separator ---
7. Daily Digest -- "NEW" indicator when fresh digest available

**Sidebar behavior:**
- Glass material (`.glassEffect(.regular)`)
- Cmd+1 through Cmd+5 switch views
- Cmd+D opens Daily Digest
- Selected row uses accent highlight within glass
- Account filter control appears at bottom of sidebar or in toolbar

### iOS iPhone: TabView + NavigationStack

```
+-------------------------------------------+
|  < Back    Action Queue       [filter]    |
|-------------------------------------------+
|                                           |
|  [email list rows]                        |
|  [scrollable content]                     |
|                                           |
|-------------------------------------------+
| [Action] [Reading] [Recs] [More]          |
+-------------------------------------------+
     Tab bar (glass, minimizes on scroll)
```

**Tab bar items:**
1. Action Queue (icon: `tray.and.arrow.down.fill`)
2. Reading Queue (icon: `book.fill`)
3. Recommendations (icon: `star.fill`)
4. More (icon: `ellipsis.circle.fill`) -- contains Filtered, All Inboxes, Digest

**Rationale for "More" tab:** The brief specifies 5 views + digest but iOS tab bars work best with 4-5 items. Action Queue, Reading Queue, and Recommendations are daily-use views. Filtered, All Inboxes, and Digest are accessed less frequently and group naturally under "More."

**Tab bar behavior:**
- Glass material (`.glassEffect(.regular)`)
- Minimizes on scroll down (`TabBarMinimizeBehavior.onScrollDown`)
- Reappears on scroll up or tap on status bar
- No badge on Reading Queue tab
- Badge count on Action Queue tab only

**Navigation within each tab:**
- `NavigationStack` per tab
- Tapping an email pushes the detail view
- Back button returns to list
- Account filter as scrolling horizontal pill bar below nav title

### iOS iPad: NavigationSplitView (Two or Three Column)

```
Regular width (portrait):
+-----------------+------------------------------+
|                 |                              |
| Sidebar (glass) | Content + Detail             |
| Same as macOS   | (list or reader, adaptive)   |
|                 |                              |
+-----------------+------------------------------+

Full width (landscape):
+-----------+------------------+----------------------------+
|           |                  |                            |
| Sidebar   | Content Column   | Detail Column              |
| (glass)   |                  |                            |
|           |                  |                            |
+-----------+------------------+----------------------------+
```

**iPad uses the same sidebar as macOS** (all 5 views + digest) rather than the tab bar. This provides consistency for users who use both Mac and iPad. Keyboard shortcuts work when a hardware keyboard is connected.

---

## 8. Keyboard System (macOS)

### Global Shortcuts (work from anywhere)

| Key | Action | Context |
|-----|--------|---------|
| `Cmd+1` | Switch to Action Queue | Global |
| `Cmd+2` | Switch to Reading Queue | Global |
| `Cmd+3` | Switch to Recommendations | Global |
| `Cmd+4` | Switch to Filtered | Global |
| `Cmd+5` | Switch to All Inboxes | Global |
| `Cmd+D` | Switch to Daily Digest | Global |
| `Cmd+Shift+1` | Filter: Work only | Global |
| `Cmd+Shift+2` | Filter: Personal only | Global |
| `Cmd+Shift+3` | Filter: All accounts | Global |
| `Cmd+K` | Open command palette | Global |
| `Cmd+N` | New compose window | Global |
| `/` | Focus search field | Global (when not in text field) |
| `Cmd+Z` | Undo last action | Global (when undo toast visible) |

### List Navigation Shortcuts (when email list has focus)

| Key | Action |
|-----|--------|
| `J` | Move selection down |
| `K` | Move selection up |
| `Enter` | Open selected email in detail column |
| `Escape` | Clear selection / return to list focus |
| `Space` | Preview selected (quick look style) |

### Email Action Shortcuts (when email is selected or open)

| Key | Action |
|-----|--------|
| `R` | Reply |
| `A` | Reply all |
| `F` | Forward |
| `E` | Archive (with undo toast) |
| `S` | Snooze (opens picker) |
| `#` | Move to trash |
| `U` | Toggle read/unread |
| `M` | Move to... (opens reclassify picker) |
| `V` | Open in All Inboxes (cross-reference) |

### Compose Shortcuts

| Key | Action |
|-----|--------|
| `Cmd+Enter` | Send email |
| `Cmd+Shift+D` | Save as draft |
| `Escape` | Close compose (prompts if unsaved) |
| `Tab` | Move between To/CC/Subject/Body fields |

### Recommendation Shortcuts (when in Recommendations view)

| Key | Action |
|-----|--------|
| `J` / `K` | Navigate between recommendations |
| `S` | Save recommendation |
| `D` | Mark as done |
| `X` | Dismiss recommendation |
| `Enter` | Expand recommendation detail |
| `O` | Open source newsletter |

### Focus Management

Focus flows: Sidebar -> Content Column -> Detail Column. Tab moves focus forward, Shift+Tab moves backward. Within a column, J/K navigate items. Enter moves focus to the next column with the selected item. Escape returns focus to the previous column.

When the command palette is open, it captures all keyboard input. Escape dismisses it and restores previous focus.

When the snooze picker is open, number keys select presets. Escape dismisses.

---

## 9. Gesture System (iOS)

### List Gestures

| Gesture | Action | Context |
|---------|--------|---------|
| Tap | Open email / recommendation | All list views |
| Swipe right (short) | Mark read/unread | Email lists |
| Swipe right (long) | Archive | Email lists |
| Swipe left (short) | Snooze | Action Queue |
| Swipe left (long) | Delete / Dismiss | All lists |
| Long press | Context menu (Reply, Forward, Snooze, Archive, Move) | Email lists |
| Pull down | Refresh | All lists |

### Detail View Gestures

| Gesture | Action |
|---------|--------|
| Swipe from left edge | Go back to list |
| Swipe up/down | Scroll content |
| Pinch | Zoom email content (within WKWebView) |

### Reading Queue Gestures

| Gesture | Action |
|---------|--------|
| Tap | Open newsletter in reader |
| Swipe right (short) | Mark as partially read |
| Swipe right (long) | Archive |
| In reader: swipe left/right | Previous/next newsletter |

### Recommendation Gestures

| Gesture | Action |
|---------|--------|
| Tap | Expand recommendation detail |
| Swipe right | Save |
| Swipe left | Dismiss |
| Long press | Context menu (Save, Done, Dismiss, Open Source) |

### Tab Bar

- Tab bar hides on scroll down, reappears on scroll up
- Tap active tab to scroll to top of list
- Long press tab for quick actions (e.g., long press Action Queue tab for "Mark all read")

---

## 10. State Patterns

Every view implements these four states. Transitions between states should be smooth.

### Loading State

```
- First load: Centered ProgressView with ".loading" label
- Subsequent loads: Subtle inline indicator (e.g., navigation bar progress)
- Pull-to-refresh (iOS): Standard RefreshControl
- Never block the entire UI -- show cached data with a loading indicator
```

### Empty State

```
- Centered EmptyStateView component (see section 6)
- Each view has unique icon, title, and subtitle
- No interactive elements in empty state (action is to wait for new emails)
- Empty state should feel rewarding in Action Queue ("All caught up")
  and neutral in other views
```

### Error State

```
- Inline error banner (similar to OfflineBanner)
- Shows error message + "Retry" button
- Does NOT replace existing cached content
- If both offline and have cached data: show cached data + offline banner
- If offline and no cached data: show error state with retry
```

### Populated State

```
- The normal operational state
- List views show rows
- Detail view shows content
- Toolbar actions are enabled
- Real-time updates flow in via WebSocket
```

### Transitioning Between States

```
Loading -> Populated: Fade in content
Loading -> Empty: Fade in empty state
Loading -> Error: Slide down error banner
Populated -> Loading (refresh): Keep content visible, add subtle indicator
Populated -> Error: Slide down error banner, keep content visible
Any -> Offline: Slide down offline banner, keep whatever content is visible
```

---

## 11. Accessibility

### VoiceOver

- Every interactive element has an accessibility label
- Email rows: "[Unread] Email from [sender] about [subject], received [relative time], [account name] account"
- Account dots: "[Account name] account" as accessibility label
- Snooze badges: "Snoozed [N] times" as accessibility label
- Badge counts: "[N] items" as accessibility value on sidebar rows
- Recommendation cards: "[Type]: [Title] by [Creator], from [Source], status: [Status]"

### Dynamic Type

- All text uses system text styles (no hardcoded font sizes)
- Layout adapts to larger text sizes:
  - Email rows increase height to accommodate larger text
  - Two-line layout may become three-line at accessibility sizes
  - Recommendation cards stack vertically at larger sizes

### Reduced Transparency

- Glass effects increase frosting (automatic with system `.glassEffect()`)
- Account dots increase size slightly and add a thin border for visibility
- Color alone is never the sole indicator -- always paired with text or icons

### Increased Contrast

- Glass gets more opaque borders (automatic)
- Selected row gets stronger contrast highlight
- Text colors shift to pure black/white

### Reduced Motion

- All transitions become instant (no animation)
- Glass specular highlights are static
- List insertions/removals are instant, not animated
- Command palette appears/disappears instantly

### Color Blindness

- Account identification uses both color dots AND position/label
  (sidebar always shows account name next to dot)
- Recommendation types use both color AND icon
- Status states use both color AND text label
- Snooze uses purple color AND "snoozed" text

### Keyboard Navigation (macOS)

- Full keyboard access: Tab moves between major areas
- All interactive elements are focusable
- Focus ring visible on all focusable elements
- J/K navigation in lists is in addition to arrow keys (arrow keys always work)

---

## 12. Animation and Motion

### Principles

- Motion is fast and purposeful -- it conveys state change, not decoration
- Every animation should feel faster than thought (per Superhuman principle)
- Respect Reduced Motion accessibility setting for all animations

### Standard Durations

| Type | Duration | Curve |
|------|----------|-------|
| Quick feedback (button press) | 0.15s | `.easeOut` |
| View transition | 0.25s | `.easeInOut` |
| Sheet presentation | 0.3s | `.spring(response: 0.3)` |
| Toast appearance | 0.2s | `.easeOut` |
| Toast dismissal | 0.3s | `.easeIn` |
| Command palette open | 0.2s | `.spring(response: 0.2)` |

### Specific Animations

**Email archive (swipe or keyboard):**
- Row slides out to trailing edge
- Remaining rows slide up to fill gap
- Undo toast slides up from bottom

**Snooze return appearing:**
- New row slides down from top of list
- Purple accent border fades in
- Subtle scale from 1.02 to 1.0

**View switching (sidebar):**
- Content column crossfades between views
- No lateral sliding (views are not spatially adjacent)

**Command palette:**
- Backdrop dims to 40% black
- Palette fades in + scales from 0.95 to 1.0
- Dismiss: reverse

**Glass interactions (iOS):**
- Button press: scale to 0.95, slight brightness increase
- Release: spring back to 1.0
- Tab bar: slide down to minimize, slide up to restore

---

## 13. App Icon

### Design Direction

The app icon follows the iOS 26 / macOS Tahoe Liquid Glass icon style: translucent material with a light or dark tint, appearing transparent and integrated with the system.

### Concept

A stylized mail tray or queue symbol rendered in glass. The icon communicates "email" while also suggesting organization (queues/stacks rather than a single envelope).

### Specifications

- Uses Liquid Glass material with a subtle blue-to-purple gradient tint
- Features a simplified tray icon with layered queue lines suggesting multiple sorted queues
- Works in both light and dark system tints
- No text in the icon
- Should feel modern, translucent, and native to the Tahoe/iOS 26 icon grid

### Sizes Required

- macOS: 1024x1024 (source), rendered at 512x512, 256x256, 128x128, 64x64, 32x32, 16x16
- iOS: 1024x1024 (source), system handles scaling
- Both platforms: single 1024x1024 asset with the new glass rendering applied by the system

---

## Referenced By

All view specs in this directory reference this design system:
- [Action Queue](./action-queue.md)
- [Reading Queue](./reading-queue.md)
- [Recommendations](./recommendations.md)
- [Filtered](./filtered.md)
- [All Inboxes](./all-inboxes.md)
- [Daily Digest](./daily-digest.md)
