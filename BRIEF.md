# Product Brief: Personal Email Client

## Overview

A native email client for macOS and iOS (iPhone/iPad) that protects attention and prevents things from falling through the cracks. Designed for someone with an ADHD mind—lots of inputs, limited attention, high cost for forgotten commitments.

Three email accounts (two personal, one work) feed into a unified system. A Mac Mini running 24/7 serves as the AI processing hub using local models. Other devices sync decisions and summaries without reprocessing.

---

## Core Philosophy

- **Aggressive filtering**: Noise never reaches you. Important things never get lost.
- **Queues by intent**: Everything is sorted by what it asks of you—respond, read, or reference.
- **Snooze without guilt**: Defer freely, but the system keeps you honest.
- **Keyboard-first on Mac**: Power users navigate without touching the mouse.
- **Local AI processing**: Privacy-preserving, on-device intelligence via Mac Mini hub.

---

## Architecture Overview

### Processing Model

- **Mac Mini (always on)**: Primary AI processing hub
  - Pulls email from all three accounts via IMAP
  - Runs local AI models for classification, spam detection, recommendation extraction
  - Generates daily digests
  - Stores decisions/summaries in a sync layer

- **Other devices (MacBook, iPhone, iPad)**: Display and interaction only
  - Sync classification decisions and summaries from Mac Mini
  - Do not reprocess emails
  - Can override classifications (syncs back to hub)

### Sync Layer

A lightweight server or peer-to-peer sync mechanism for:
- Classification decisions (which queue each email belongs to)
- Extracted recommendations
- Snooze states and return times
- User overrides and training signals
- Daily digest content

### Data Flow

```
Email Provider (IMAP)
        ↓
   Mac Mini (AI Hub)
        ↓
   [Classification, Extraction, Digest Generation]
        ↓
   Sync Layer (decisions + summaries)
        ↓
   All Devices (display + interaction)
```

---

## Account Structure

- **Three accounts**: Two personal, one work
- **Unified by default**: All accounts feed into shared queues
- **Filterable anytime**: Toggle between All / Work / Personal / Individual accounts
- **Visual distinction**: Subtle color dot per account (e.g., blue=work, green=personal1, orange=personal2)
- **Smart replies**: Compose defaults to the account that received the email

---

## The Five Views

### 1. Action Queue

Emails that need a response.

**Classification (aggressive—false positives acceptable, false negatives are not):**
- Direct questions ("Can you...?", "What do you think?", "Are you available?")
- Requests where user is in To field (not CC)
- Mentions of deadlines, especially near-term
- Emails from people the user frequently replies to
- VIP senders (configurable): always flagged regardless of content

**Not flagged:**
- Auto-generated (shipping, receipts, calendar confirmations)
- CC'd emails with no direct address to user
- Marketing that slipped through spam filter
- Newsletters (routed to Reading Queue)

**Ordering:**
1. **Snoozed items returning** — top of list, visually distinct badge, sorted by return time
2. **New items needing response** — below snoozed, sorted by arrival time

**Snooze behavior:**
- Quick picker: 2 hours, tomorrow morning, next week, custom
- Returns to top of Action Queue at scheduled time
- Multi-snooze allowed; counter shown ("snoozed 3x") — no friction, just visibility

---

### 2. Reading Queue

Newsletters only. A calm, focused reading interface—more like a read-later app than an inbox.

**Behavior:**
- Newsletters auto-routed here, never appear in Action Queue
- Partially-read items sink to bottom, not nagging
- AI scans for recommendations on arrival (populates Recommendations view)

**UX:**
- Minimal chrome, comfortable reading typography
- Swipe to mark partially read, archive, or save for later

---

### 3. Recommendations

Automatically extracted from newsletters. **This is a key differentiating feature.**

**Extracted types:**
- 📚 Books
- 🎬 Movies & TV
- 🎵 Music
- 📄 Articles
- 🎙️ Podcasts
- 🛠️ Other (products, tools, restaurants, etc.)

**Each recommendation shows:**
- Title / author / artist
- Source: "From *Stratechery* — Jan 15"
- Context snippet: "Ben called it 'the best explanation of modularity theory I've read'"
- Status: New / Saved / Done / Dismissed

**Tap to expand:**
- Full paragraph from original newsletter
- Link to original email

**Duplicate handling:**
- Consolidated into single entry: "Recommended by 3 sources"
- Tap to see all contexts

**Manual additions:**
- User can add own recommendations
- Marked "Added by you" vs newsletter source

**Non-newsletter sources:**
- User can opt-in specific senders as "recommendation sources"
- Emails from those senders scanned same as newsletters

---

### 4. Filtered

Spam and marketing that was auto-removed.

**Behavior:**
- Never deleted immediately—reviewable
- Auto-deletes after 14 days
- Daily digest surfaces 3 most uncertain classifications for quick review

**Purpose:**
- Build trust in the system
- Rescue false positives easily
- Train the model over time

---

### 5. All Inboxes

Traditional unified inbox view for when you want it.

**Contains:**
- Everything, including transactional emails
- Transactional emails (receipts, shipping, calendar) are auto-archived with "Transactional" label
- Never appear in Action or Reading Queue
- Fully searchable

---

## Daily Digest

A dedicated view in the app. Generated at **6:00 AM** and **7:00 PM**. Viewable anytime—not a notification that disappears.

### 6:00 AM — Morning Planning

- Action Queue count (by account or combined, user preference)
- Snoozed items returning today
- Reading Queue count
- Borderline filtered items: "These 3 might not be spam—worth a glance?"
- Notable transactional: packages arriving, large charges

### 7:00 PM — End of Day

- What's still in Action Queue
- What you handled today (sent count, archived count)
- Newsletters that arrived today
- Gentle nudge on items snoozed multiple times

---

## Keyboard Shortcuts (macOS)

| Shortcut | Action |
|----------|--------|
| `Cmd+1` | Action Queue |
| `Cmd+2` | Reading Queue |
| `Cmd+3` | Recommendations |
| `Cmd+4` | Filtered |
| `Cmd+5` | All Inboxes |
| `Cmd+D` | Daily Digest |
| `Cmd+Shift+1` | Filter: Work only |
| `Cmd+Shift+2` | Filter: Personal only |
| `Cmd+Shift+3` | Filter: All accounts |
| `J` | Navigate down |
| `K` | Navigate up |
| `Enter` | Open selected email |
| `R` | Reply |
| `S` | Snooze (opens picker) |
| `E` | Archive |
| `Cmd+Enter` | Send |

---

## Transactional Email Handling

Receipts, shipping notifications, calendar confirmations.

**Behavior:**
- Auto-archived immediately with "Transactional" label
- Never appear in Action Queue or Reading Queue
- Visible in All Inboxes
- Fully searchable: "show me shipping notifications from last week"

**Digest integration:**
- Notable items surfaced: "2 packages arriving today", "You were charged $847 by United Airlines"

---

## AI Classification Details

### Training Period

First two weeks: more aggressive surfacing of borderline cases in digest. User feedback trains the model, then it quiets down.

### Signals for "Needs Response" (Action Queue)

- Question marks in body directed at recipient
- Phrases: "can you", "could you", "would you", "let me know", "what do you think", "are you available"
- Deadlines mentioned (especially within 7 days)
- User in To field (not CC)
- High reply frequency with sender historically
- VIP sender list (user-configurable)

### Signals for Newsletter (Reading Queue)

- "Unsubscribe" link present
- Sender is known newsletter domain
- Bulk sending headers
- No direct question to recipient
- Format matches newsletter patterns (header image, multiple sections, footer links)

### Signals for Spam/Marketing (Filtered)

- Known spam patterns
- Marketing language without newsletter substance
- Sender not in contacts
- Unsubscribe link + promotional content
- Low sender reputation

### Signals for Transactional (Auto-archive)

- Order confirmations
- Shipping notifications
- Calendar invites (already accepted)
- Password resets
- Two-factor codes
- Receipt patterns

### Recommendation Extraction

Scan newsletter body for:
- Book titles (often italicized or quoted, followed by author name)
- Movie/TV mentions (often with year, streaming platform, or review language)
- Music (artist + album/song, or "listening to")
- Article links with editorial context ("great piece on...", "worth reading")
- Podcast mentions ("episode of...", "interview with...")

Store with:
- Extracted title/name
- Type (book, movie, etc.)
- Source newsletter and date
- Context paragraph
- Confidence score (for duplicate matching)

---

## What This App Does NOT Do

- **No AI-written replies**: User writes their own emails, usually a few sentences
- **No aggressive notifications**: Digest at 6am/7pm + snoozed returns. Otherwise, check when you want.
- **No complexity**: Five views + digest. That's it.

---

## Platform Details

- **Native Swift/SwiftUI** for macOS and iOS
- **Shared codebase** where possible (data models, business logic)
- **Platform-specific UI** optimized for each device
- **Local AI on Mac Mini**: Core ML or similar for classification models
- **Sync layer**: TBD—could be CloudKit, custom server, or peer-to-peer

---

## Future Considerations (Not in Scope Now)

This email client is designed as the first module of a larger personal OS. The patterns established here—queues by intent, aggressive triage, snooze with visibility, recommendations as first-class objects, daily digest—should be built as extensible primitives.

Future modules may include:
- Calendar integration: "What should you prepare for?" and "You have 90 free minutes—here's what you could do"
- Tasks/Reminders: Single trusted list with same queue/snooze/digest logic
- Projects & Hobbies: A home for ideas with gentle nudges to engage
- People: "Who have you been meaning to reach out to?"

**For now**: Build the email client. Make it great. Keep the architecture extensible.

---

## Success Criteria

1. **Nothing important forgotten**: Action Queue catches everything that needs a response
2. **Newsletters actually read**: Reading Queue creates a calm space separate from inbox anxiety
3. **Recommendations not lost**: Books, movies, articles extracted and accessible when needed
4. **Spam invisible**: Filtered folder exists for trust, but rarely needed
5. **Keyboard flow on Mac**: Power user can process email without touching mouse
6. **Trust the system**: Aggressive enough to be useful, transparent enough to verify

---

## Open Questions for Implementation

1. **Sync layer technology**: CloudKit vs custom server vs peer-to-peer?
2. **Local AI models**: Which models for classification? Fine-tuned or prompted?
3. **IMAP handling**: Direct connection or intermediary service?
4. **Recommendation export**: Build integrations (Goodreads, Pocket, etc.) or start with copy/paste?
5. **VIP configuration**: How does user designate VIP senders? Per-account or global?
6. **Snooze picker UX**: Preset times, smart suggestions based on calendar, or simple fixed options?