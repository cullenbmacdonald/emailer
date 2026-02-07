# Email Protocols, Authentication, and Client Architecture Brainstorm

> Research notes for building a native email client connecting to Gmail, iCloud Mail, and Microsoft 365/Outlook via IMAP/SMTP.

---

> **⚠️ Architecture Update**: This document was written before the final architecture was decided. IMAP/SMTP handling is now done by the **Go server** using `go-imap` v2 (not Swift libraries like MailCore2 or SwiftMail). The protocol knowledge, provider-specific details (Gmail extensions, OAuth2 flows, IMAP IDLE behavior), MIME parsing considerations, and security recommendations in this document remain fully valid — but references to Swift IMAP/SMTP libraries should be read as historical research. See `go-server-architecture.md` for the current IMAP implementation design.

---

## Table of Contents

1. [IMAP Protocol Deep Dive](#1-imap-protocol-deep-dive)
2. [Authentication](#2-authentication)
3. [SMTP for Sending](#3-smtp-for-sending)
4. [Swift IMAP/SMTP Libraries](#4-swift-imapsmtp-libraries)
5. [Gmail-Specific Considerations](#5-gmail-specific-considerations)
6. [Email Parsing](#6-email-parsing)
7. [Performance and Reliability](#7-performance-and-reliability)
8. [Privacy and Security](#8-privacy-and-security)

---

## 1. IMAP Protocol Deep Dive

### 1.1 IMAP IDLE for Push Notifications vs Polling

**IMAP IDLE (RFC 2177)** is the standard mechanism for real-time email notifications over IMAP. Instead of the client repeatedly asking "any new mail?" (polling), the client opens a connection, issues the IDLE command, and the server pushes notifications when new messages arrive or flags change.

**How IDLE works:**
1. Client opens an IMAP connection and SELECTs a mailbox.
2. Client sends `IDLE` command.
3. Server responds with `+ idling` (continuation).
4. Server sends untagged `EXISTS`, `EXPUNGE`, or `FETCH` responses as changes occur.
5. Client sends `DONE` to terminate IDLE.
6. Client must reissue IDLE at least every 29 minutes (RFC requirement) to avoid server-side inactivity timeouts.

**Critical implementation details:**
- The 29-minute reissue is a maximum. In practice, reissue every 10-15 minutes because some NATs, firewalls, and load balancers silently drop idle TCP connections after shorter periods.
- IDLE only monitors ONE mailbox per connection. To monitor Inbox, Sent, and Drafts simultaneously, you need three separate IMAP connections in IDLE mode.
- Not all IMAP servers support IDLE. Check the CAPABILITY response for "IDLE". Gmail, iCloud, and Microsoft 365 all support IDLE.
- When IDLE is interrupted (network drop, server timeout), the client must detect the broken connection and re-establish it promptly.

**Polling as fallback:**
- If IDLE is not supported (rare for our target providers), fall back to polling with NOOP commands every 1-5 minutes.
- NOOP resets the server's inactivity timer and triggers any pending untagged responses.
- Polling interval should be configurable per-account.

**Recommendation for our architecture:**
- On the Mac Mini (always-on daemon), use IDLE on the INBOX for each account. This gives near-instant notification of new mail.
- Use a secondary polling mechanism (every 2-5 minutes) for non-INBOX folders like Sent, Drafts, and any custom folders that need monitoring.
- Implement a watchdog timer that detects stale IDLE connections and re-establishes them. If no server activity (including keepalive responses) is seen within 15 minutes, tear down and reconnect.

### 1.2 IMAP CONDSTORE and QRESYNC for Efficient Sync

These are defined in **RFC 7162** and are essential for building a performant email client that handles reconnections gracefully.

**CONDSTORE (Conditional Store):**
- Adds a `MODSEQ` (modification sequence) value to every message and to the mailbox itself.
- The client records the highest MODSEQ it has seen. On reconnection, it can issue `FETCH 1:* (FLAGS) (CHANGEDSINCE <last_known_modseq>)` to retrieve only messages whose flags have changed since the last sync.
- Without CONDSTORE, the client must fetch ALL flags for ALL messages to detect changes, which is extremely wasteful for large mailboxes.
- Gmail supports CONDSTORE but NOT QRESYNC.

**QRESYNC (Quick Resynchronization):**
- Builds on CONDSTORE. When SELECTing a mailbox, the client provides its last known UIDVALIDITY and highest MODSEQ.
- The server responds with all flag changes AND all expunged UIDs since that point, in a single round trip.
- Without QRESYNC, detecting expunged (deleted) messages requires the client to compare its full local UID list against the server's, which is expensive.
- iCloud Mail supports QRESYNC. Gmail does not. Microsoft 365/Exchange support varies.

**Recommendation:**
- Always check CAPABILITY for CONDSTORE and QRESYNC support.
- Use QRESYNC when available (iCloud). Fall back to CONDSTORE-only sync for Gmail.
- For providers with neither, implement a full UID-based reconciliation (fetch all UIDs, compare with local cache, identify additions and deletions).
- Store the HIGHESTMODSEQ and UIDVALIDITY per-mailbox in the local database. If UIDVALIDITY changes, the entire local cache for that mailbox must be invalidated and re-synced from scratch.

### 1.3 Handling Large Mailboxes Efficiently

A typical user might have 10,000-100,000+ messages in their inbox (especially Gmail users who archive everything). Strategies:

**Envelope-first fetching:**
- On initial sync, fetch only envelope data (From, To, Subject, Date, Message-ID, flags) and message structure (BODYSTRUCTURE).
- Do NOT fetch full message bodies up front. Fetch bodies on-demand when the user opens a message, or pre-fetch recent messages (last 30 days) in the background.

**UID-based pagination:**
- IMAP UIDs are monotonically increasing. Fetch the newest messages first by requesting a UID range from the highest known UID downward.
- Example: `UID FETCH 50000:* (ENVELOPE FLAGS)` gets the newest batch, then `UID FETCH 49900:49999 (ENVELOPE FLAGS)` for the next page.

**BODYSTRUCTURE before BODY:**
- Fetch BODYSTRUCTURE first to understand the message's MIME layout (which parts are text, HTML, attachments).
- Then selectively fetch only the parts needed: `BODY[1]` for the text part, `BODY[2]` for HTML, skip large attachments unless explicitly requested.

**Partial fetches:**
- IMAP supports `BODY[]<start.length>` for partial fetches. Use this for large messages or attachments to implement progressive loading.

**Server-side search:**
- Instead of downloading everything for local search, leverage IMAP SEARCH for server-side filtering.
- Combine with local full-text indexing (SQLite FTS5 or Spotlight integration) for messages already cached.

### 1.4 Folder/Label Mapping

This is one of the trickiest parts of multi-provider email client development.

**Standard IMAP model:**
- IMAP uses a hierarchical folder model. A message exists in exactly one folder (mailbox). Moving a message between folders creates a copy in the destination and deletes the original (COPY + STORE \Deleted + EXPUNGE).
- Special-use folders are identified by attributes: `\Inbox`, `\Sent`, `\Drafts`, `\Trash`, `\Junk`, `\Archive` (RFC 6154, SPECIAL-USE extension).

**Gmail's label model:**
- Gmail does NOT use folders internally. It uses labels. A single message can have multiple labels simultaneously.
- Gmail maps labels to IMAP "folders" via its XLIST / SPECIAL-USE extension.
- The `[Gmail]/All Mail` folder contains every message. Other "folders" like Inbox, Sent, Starred are just views filtered by label.
- Deleting a message from a Gmail IMAP "folder" just removes that label. The message remains in All Mail. To truly delete, move to `[Gmail]/Trash`.
- Archiving in Gmail means removing the `\Inbox` label. Via IMAP, this is done by moving the message out of INBOX (or storing the \Deleted flag and expunging from INBOX).

**iCloud Mail:**
- Standard IMAP folder model. Folders are listed with a hierarchy delimiter (usually ".").
- Special-use attributes are supported for identifying Sent, Trash, Drafts, Junk, Archive.

**Microsoft 365 / Outlook:**
- Also standard IMAP folder model with some quirks.
- Folder hierarchy delimiter is typically "/".
- Special-use folders are identified by SPECIAL-USE attributes.
- The "Focused Inbox" feature is NOT accessible via IMAP. Only available through the Microsoft Graph API.

**Recommendation:**
- Build an abstraction layer that maps provider-specific folder structures to a normalized model:
  - Inbox, Sent, Drafts, Trash, Junk/Spam, Archive, and "Other" (custom folders/labels).
- For Gmail, use X-GM-LABELS FETCH attribute to retrieve all labels for a message, not just the "folder" it appears in.
- Display Gmail labels as tags in the UI, not as folders.
- Use LIST command with SPECIAL-USE to auto-detect standard folders rather than hardcoding names.

### 1.5 IMAP Search Capabilities

**Standard IMAP SEARCH (RFC 3501):**
- Supports searching by: FROM, TO, CC, BCC, SUBJECT, BODY, TEXT (headers + body), DATE ranges (BEFORE, ON, SINCE, SENTBEFORE, SENTON, SENTSINCE), FLAGS (SEEN, FLAGGED, DELETED, etc.), SIZE (LARGER, SMALLER), and combinations with AND/OR/NOT.
- Returns a list of message sequence numbers (or UIDs with UID SEARCH).
- Limitations: no full-text relevance ranking, no snippet generation, limited to one mailbox at a time.

**IMAP SORT and THREAD extensions (RFC 5256):**
- SORT: server-side sorting by date, from, subject, size, etc. Avoids downloading all envelopes for client-side sorting.
- THREAD: server-side threading by References/In-Reply-To headers. Useful for conversation view.
- Gmail does NOT support SORT or THREAD. iCloud supports SORT. Microsoft 365 support varies.

**Gmail-specific search (X-GM-RAW):**
- Gmail extends IMAP SEARCH with `X-GM-RAW` which accepts the full Gmail web search syntax.
- Example: `UID SEARCH X-GM-RAW "from:alice has:attachment larger:5M"`.
- This is extremely powerful and covers natural language queries, date ranges, label filters, attachment filters, and more.
- Only works with Gmail.

**Recommendation:**
- Implement a two-tier search strategy:
  1. **Local search** using SQLite FTS5 on cached messages for instant results.
  2. **Server-side search** for messages not yet cached, using the provider's IMAP SEARCH (or X-GM-RAW for Gmail).
- For Gmail accounts, prefer X-GM-RAW for server-side search since it is far more capable than standard IMAP SEARCH.
- Build the local full-text index incrementally as messages are cached.

---

## 2. Authentication

### 2.1 OAuth2 for Gmail

**Current status (as of 2025-2026):**
- Google has fully deprecated "Less Secure Apps" (basic username/password auth) for all accounts.
- App-specific passwords still work for personal Google accounts that have 2FA enabled, but OAuth2 is the recommended and more robust approach.
- For Google Workspace accounts, admins may have disabled app passwords entirely, making OAuth2 the only option.

**OAuth2 XOAUTH2 mechanism:**
- Gmail IMAP/SMTP uses the SASL XOAUTH2 mechanism for authentication.
- The client obtains an OAuth2 access token through the standard Google OAuth2 flow, then encodes it in the XOAUTH2 format and sends it via the IMAP AUTHENTICATE command.
- XOAUTH2 format: `base64("user=" + email + "\x01auth=Bearer " + access_token + "\x01\x01")`

**OAuth2 setup for a desktop/native app:**
1. Register the app in Google Cloud Console as a "Desktop application" OAuth client.
2. Implement the authorization code flow with PKCE (Proof Key for Code Exchange).
3. The user is redirected to Google's consent screen in a browser. After granting permission, Google redirects to a localhost URL or a custom URI scheme with an authorization code.
4. The app exchanges the authorization code for an access token and a refresh token.
5. Access tokens expire after 1 hour. Use the refresh token to obtain new access tokens without user interaction.
6. Required scopes: `https://mail.google.com/` for full IMAP/SMTP access.

**Important considerations:**
- The OAuth client will be in "Testing" mode initially, limited to 100 test users. For broader distribution, you need to go through Google's verification process.
- For a personal email client used by one person, "Testing" mode is sufficient. Just add your Google accounts as test users.
- Store refresh tokens securely (see Keychain section below).

### 2.2 OAuth2 for Microsoft 365 / Outlook

**Current status:**
- Microsoft is enforcing Modern Authentication (OAuth2) for all Exchange Online / Microsoft 365 connections. Basic auth has been deprecated.
- Outlook.com (consumer) also supports OAuth2 for IMAP/SMTP.

**OAuth2 setup:**
1. Register the app in Microsoft Entra ID (formerly Azure AD) portal.
2. For personal/consumer Outlook.com accounts, register under "Personal Microsoft accounts" (or "Accounts in any organizational directory and personal Microsoft accounts").
3. For work/school Microsoft 365 accounts, the app may need admin consent depending on the tenant's policies.
4. Implement the authorization code flow with PKCE.
5. Scope: `https://outlook.office365.com/.default` for IMAP/SMTP access. Specific scopes include `https://outlook.office365.com/IMAP.AccessAsUser.All` and `https://outlook.office365.com/SMTP.Send`.
6. The access token is used via SASL XOAUTH2, same mechanism as Gmail.

**Key differences from Google:**
- Microsoft access tokens can be longer-lived (configurable by tenant admin).
- Refresh tokens for Microsoft can last up to 90 days by default, but get extended with each use (sliding window).
- Multi-tenant app registration requires careful scope configuration.

### 2.3 App-Specific Passwords for iCloud

**Current status:**
- iCloud Mail uses app-specific passwords for third-party app access. There is no public OAuth2 flow for iCloud Mail IMAP.
- Apple requires two-factor authentication to be enabled on the Apple Account before app-specific passwords can be generated.

**Setup:**
1. User goes to appleid.apple.com, signs in, navigates to "Sign-In and Security" > "App-Specific Passwords".
2. Generates a password with a descriptive label (e.g., "Email Client - Mac Mini").
3. The generated password is used as the IMAP/SMTP password.

**iCloud IMAP/SMTP settings:**
- IMAP server: `imap.mail.me.com`, port 993, SSL/TLS.
- SMTP server: `smtp.mail.me.com`, port 587, STARTTLS.
- Username: full iCloud email address (e.g., `user@icloud.com` or `user@me.com`).
- Password: the app-specific password.
- Authentication method: standard PLAIN or LOGIN (not XOAUTH2).

**Limitations:**
- App-specific passwords do not expire automatically, but the user can revoke them at any time from appleid.apple.com.
- If the user changes their Apple Account password, all app-specific passwords are revoked.
- No programmatic way to detect revocation; the IMAP connection will simply fail with an authentication error.

### 2.4 Token Refresh Handling for a 24/7 Daemon

The Mac Mini daemon runs continuously and must maintain authenticated IMAP connections around the clock. Token management is critical.

**Access token refresh strategy:**
- OAuth2 access tokens typically expire in 1 hour (Google) or 1 hour (Microsoft default).
- The daemon should refresh the access token proactively, approximately 5-10 minutes before expiration, rather than waiting for an auth failure.
- On each refresh, store the new access token and its expiration time.
- If a refresh fails, implement exponential backoff retry (1s, 2s, 4s, 8s..., max 5 minutes).

**Refresh token lifecycle:**
- Google refresh tokens do not expire unless the user revokes access, changes their password, or the token is unused for 6 months. For a continuously-running daemon, this means they effectively never expire.
- Microsoft refresh tokens last up to 90 days but are extended with each use (sliding window). As long as the daemon refreshes regularly, they will not expire.
- If a refresh token is invalidated (user revoked access, password changed), the daemon must:
  1. Detect the failure (HTTP 400 with `invalid_grant` error).
  2. Notify the user that re-authentication is needed.
  3. Pause sync for that account until the user completes the OAuth flow again.

**Token rotation:**
- Some OAuth2 providers issue a new refresh token with each access token refresh (refresh token rotation).
- Always store the most recent refresh token. If you receive a new one, overwrite the old one.

**Handling iCloud app-password expiry:**
- Since iCloud uses static passwords, there is no automatic refresh.
- Detect authentication failures on IMAP connection attempts.
- Notify the user to generate a new app-specific password if the existing one is revoked.

### 2.5 Securely Storing Credentials on macOS (Keychain)

**macOS Keychain Services** is the proper mechanism for storing secrets on macOS.

**What to store:**
- OAuth2 refresh tokens (for Gmail and Microsoft 365).
- OAuth2 access tokens and expiration timestamps (can also be stored in memory, but Keychain is fine).
- iCloud app-specific password.

**Implementation approach:**
- Use the `Security` framework's Keychain Services API directly, or use a wrapper library like `KeychainAccess` for a more ergonomic Swift API.
- Store each credential as a "generic password" keychain item with:
  - `kSecAttrService`: a unique identifier like `"com.yourapp.emailclient"`.
  - `kSecAttrAccount`: the email address or account identifier.
  - `kSecValueData`: the secret (token or password), encoded as UTF-8 Data.
  - `kSecAttrAccessible`: use `kSecAttrAccessibleAfterFirstUnlock` so the daemon can access credentials after the Mac Mini boots up and the user logs in once (even if the screen is locked afterwards). This is critical for a 24/7 daemon.

**Access control:**
- Keychain items are scoped to the app that created them by default (app sandboxing / code signing).
- For a daemon running as a LaunchAgent or LaunchDaemon, ensure the correct user context. A LaunchAgent (per-user) is preferred because it runs in the user's login session and has access to the user's keychain. A LaunchDaemon (system-wide) would need a different keychain approach.

**Recommended library:**
- `KeychainAccess` (github.com/kishikawakatsumi/KeychainAccess) provides a clean Swift API and is well-maintained.
- Alternatively, `swift-security` (github.com/dm-zharov/swift-security) is a newer, more modern Swift framework for Keychain access.

---

## 3. SMTP for Sending

### 3.1 SMTP Authentication Per Account

Each email account needs its own SMTP configuration for sending:

**Gmail:**
- Server: `smtp.gmail.com`, port 587 (STARTTLS) or 465 (implicit TLS).
- Authentication: XOAUTH2 (same access token as IMAP).
- Important: Use port 587 with STARTTLS for broad compatibility. Port 465 with implicit TLS is also supported and arguably simpler (no STARTTLS upgrade step).

**iCloud:**
- Server: `smtp.mail.me.com`, port 587, STARTTLS.
- Authentication: PLAIN or LOGIN with app-specific password.

**Microsoft 365:**
- Server: `smtp.office365.com`, port 587, STARTTLS.
- Authentication: XOAUTH2 (same access token used for IMAP).
- Note: The SMTP scope must be explicitly requested during OAuth (`SMTP.Send`).

**Implementation:**
- Maintain a separate SMTP client configuration per account.
- When composing a reply, automatically select the SMTP configuration matching the account that received the original email.
- For new compose, default to a user-configurable "primary" account, with a dropdown to switch.

### 3.2 Handling "Send From" for Multi-Account

**From header:**
- The `From:` header must match a valid email address for the SMTP server being used. Gmail will reject or rewrite the From header if it does not match a configured "Send mail as" address.
- Each account's SMTP connection should only be used to send mail with a From address belonging to that account.

**Reply-To considerations:**
- For replies, always use the account that received the original message as the sending account. Match by checking which account's IMAP mailbox contained the original email.
- Populate the `In-Reply-To` and `References` headers correctly for threading.

**UI implications:**
- Show a "From" selector in the compose window, defaulting to the appropriate account.
- Color-code or badge the "From" selector to match the account color dots described in the BRIEF.

### 3.3 Draft Sync Between Devices

**IMAP Drafts folder:**
- Save drafts by APPENDing the message to the Drafts folder on the IMAP server with the `\Draft` flag.
- Use the `Message-ID` header to identify the same draft across saves (update in place by deleting the old version and appending the new one).
- Set a `X-Draft-ID` or similar custom header to track draft identity across revisions, since Message-ID may change.

**Auto-save strategy:**
- Auto-save to the server every 30-60 seconds while composing.
- Also save locally for instant recovery if the IMAP append fails.
- On send, delete the draft from the Drafts folder.

**Cross-device considerations:**
- Since drafts are stored in the IMAP Drafts folder, they will be visible on all devices connected to the same account.
- The Mac Mini daemon should sync the Drafts folder and make draft metadata available to other devices through the sync layer.
- When a user opens a draft on a different device, fetch the full message body from IMAP.

### 3.4 Sent Mail Sync Back to IMAP

**The problem:**
- When you send an email via SMTP, the message is delivered to recipients but is NOT automatically stored in the Sent folder on IMAP. The client is responsible for saving a copy.

**Gmail exception:**
- Gmail automatically saves a copy of sent messages to `[Gmail]/Sent Mail` if the message was sent through `smtp.gmail.com` using an authenticated session. You do NOT need to manually APPEND to the Sent folder for Gmail. In fact, doing so will create duplicates.

**iCloud and Microsoft 365:**
- These providers do NOT automatically save sent messages. After successful SMTP submission, the client must APPEND the sent message to the Sent folder on the IMAP server.
- Use the `\Seen` flag when appending to avoid the sent message showing as unread.

**Implementation:**
```
func sendAndStore(message: MIMEMessage, account: Account) async throws {
    // 1. Send via SMTP
    try await smtpClient.send(message)

    // 2. Store in Sent folder (skip for Gmail)
    if account.provider != .gmail {
        let sentFolder = account.specialFolders.sent
        try await imapClient.append(message, to: sentFolder, flags: [.seen])
    }
}
```

---

## 4. Swift IMAP/SMTP Libraries

### 4.1 Library Comparison Matrix

| Feature | MailCore2 | SwiftNIO IMAP | SwiftMail (Cocoanetics) | MimeFoundation + MailFoundation |
|---|---|---|---|---|
| **Language** | Obj-C (Swift bridge) | Pure Swift | Pure Swift | Pure Swift |
| **IMAP Support** | Full | Parser/encoder only | Yes (core ops) | Yes (full) |
| **SMTP Support** | Full | No | Yes | Yes |
| **POP3 Support** | Yes | No | No | Yes |
| **MIME Parsing** | Built-in | No | Basic | Full (MimeKit port) |
| **Async/Await** | No (callback-based) | Yes (SwiftNIO) | Yes (actor-based) | Yes |
| **SwiftPM** | Partial (branch only) | Yes | Yes | Yes |
| **IDLE Support** | Yes | Encoding only | Unknown | Yes |
| **OAuth2/XOAUTH2** | Yes | N/A | Yes (PLAIN, LOGIN) | Yes |
| **Gmail Extensions** | Some | Parser support | No | Unknown |
| **Platform** | macOS, iOS | macOS, iOS, Linux | macOS, iOS, Linux | macOS, iOS, Linux |
| **Maintenance** | Low (last major: 2020) | Low (Apple, sporadic) | Active (new, 2025) | Active (new, 2025) |
| **Maturity** | High (10+ years) | Medium | Low (new) | Low (new) |
| **Dependencies** | libetpan, OpenSSL, etc. | SwiftNIO, swift-nio-ssl | SwiftNIO | SwiftNIO |

### 4.2 MailCore2

**Pros:**
- The most battle-tested IMAP/SMTP library for Apple platforms. Used by Spark, Airmail, and many other email clients.
- Comprehensive feature set: IMAP, SMTP, POP3, MIME parsing, HTML rendering helpers.
- Handles most edge cases in real-world email.

**Cons:**
- Written in Objective-C/C++ with a Swift bridge. Not idiomatic Swift.
- Callback-based API, no native async/await support. Requires wrapping in continuations.
- Complex build process with many C dependencies (libetpan, tidy-html5, ctemplate, ICU, OpenSSL).
- SPM support is problematic; must point to the master branch rather than a tagged release.
- Maintenance has slowed significantly. Many open issues on GitHub without resolution.
- The underlying libetpan library has its own quirks and limitations.

**Verdict:** Proven but aging. If stability and completeness are paramount and you are willing to deal with the Obj-C bridge and build complexity, it works. But for a new project in 2025-2026, consider newer alternatives.

### 4.3 SwiftNIO IMAP (Apple)

**Pros:**
- Built by Apple on top of SwiftNIO. Pure Swift, excellent type safety.
- Comprehensive IMAP4rev1 parser and encoder with support for 20+ extension RFCs.
- Non-blocking, high-performance networking via SwiftNIO.

**Cons:**
- It is a protocol parser/encoder, NOT a ready-to-use IMAP client. You must build the connection management, state machine, command pipelining, and business logic yourself.
- No SMTP support.
- No MIME parsing.
- Still marked as not production-ready.
- Sparse documentation and examples.

**Verdict:** A solid foundation if you want to build a custom IMAP client from scratch with full control. Significant engineering effort required. Best suited as a building block, not a drop-in solution.

### 4.4 SwiftMail (Cocoanetics)

**Pros:**
- Released in March 2025. Built on top of Apple's SwiftNIO framework.
- Modern Swift with actor-based concurrency and async/await API.
- Supports both IMAP and SMTP.
- Easy-to-use API: `IMAPServer` and `SMTPServer` actors.
- Good logging and debugging support (OSLog integration).
- Includes CLI demo tools for testing.

**Cons:**
- Very new, limited production usage.
- Feature set is still evolving. Does not yet support all IMAP extensions (IDLE, CONDSTORE, QRESYNC status unknown).
- MIME handling is basic compared to MailCore2 or MimeFoundation.
- Smaller community and fewer contributors.

**Verdict:** Most promising option for a new Swift project. Modern API design, but may need contributions or extensions for advanced features. Good starting point to evaluate.

### 4.5 MimeFoundation + MailFoundation (Miguel de Icaza)

**Pros:**
- Port of the .NET MimeKit/MailKit libraries to Swift, by Miguel de Icaza (notable in the open-source community).
- MimeFoundation provides comprehensive MIME parsing: S/MIME, DKIM, full internationalization, stream-based processing.
- MailFoundation provides IMAP, POP3, and SMTP protocol implementations.
- Async/await support.
- RFC 5322 compliant.

**Cons:**
- New project (2025). Production readiness is unproven.
- Porting from .NET means the API may not feel fully "Swift-native" in all places.
- Community and ecosystem are still forming.

**Verdict:** Very promising due to MimeKit's proven design and comprehensive feature set. The MIME parsing in MimeFoundation is likely the best option available in Swift. Worth evaluating seriously, especially paired with MailFoundation for the protocol layer.

### 4.6 Other Options

**libcurl-based approach:**
- libcurl supports IMAP and SMTP. Could use Swift bindings.
- Very low-level. You would need to handle all IMAP state management, MIME parsing, etc.
- Not recommended unless you have a very specific reason.

**Apple's built-in frameworks:**
- Apple does NOT provide a public IMAP or SMTP framework.
- `MessageUI` (MFMailComposeViewController) is for delegating to the system mail app, not for direct protocol access.
- `Network.framework` provides TCP/TLS connections but no email protocol support.
- There are no private/undocumented frameworks worth relying on.

### 4.7 Recommended Approach

**Primary recommendation: SwiftMail or MimeFoundation+MailFoundation as the protocol/MIME layer, supplemented as needed.**

The specific recommendation depends on priorities:

1. **If fastest time-to-working-prototype matters:** Start with SwiftMail for IMAP/SMTP connectivity. Use MimeFoundation for MIME parsing (it is more comprehensive). This gives you a modern Swift stack with async/await throughout.

2. **If maximum IMAP feature completeness matters:** Evaluate MailFoundation (MimeKit port) first, since the original MailKit is the gold standard for .NET email. If MailFoundation covers IDLE, CONDSTORE, and XOAUTH2, it may be the single best choice.

3. **Fallback plan:** If the newer libraries prove too immature, MailCore2 remains the proven fallback, accepting the Obj-C bridge tax.

4. **Hybrid approach:** Use SwiftNIO IMAP as the low-level protocol layer and build a custom client on top. Use MimeFoundation for all MIME parsing. This is the most work but gives the most control and the cleanest architecture long-term.

---

## 5. Gmail-Specific Considerations

### 5.1 Gmail IMAP Extensions

Gmail extends standard IMAP with several proprietary attributes:

**X-GM-MSGID:**
- A unique 64-bit message identifier that is stable across IMAP sessions and matches the hex ID used in the Gmail web interface and Gmail API.
- Useful for correlating IMAP messages with Gmail API resources or web URLs.
- Fetch via: `UID FETCH <uid> (X-GM-MSGID)`.

**X-GM-THRID:**
- Gmail's thread ID (conversation ID). All messages in the same conversation share the same X-GM-THRID.
- Useful for building conversation view without relying on References/In-Reply-To header parsing.
- Fetch via: `UID FETCH <uid> (X-GM-THRID)`.

**X-GM-LABELS:**
- Returns all Gmail labels applied to a message.
- Can also SET labels via STORE: `UID STORE <uid> +X-GM-LABELS (label1 "label with spaces")`.
- Essential for understanding Gmail's true organization (since IMAP "folders" are a limited view).

**X-GM-RAW:**
- Extends IMAP SEARCH to accept Gmail's full search syntax.
- Examples:
  - `UID SEARCH X-GM-RAW "from:alice@example.com has:attachment"`.
  - `UID SEARCH X-GM-RAW "newer_than:7d is:unread"`.
  - `UID SEARCH X-GM-RAW "label:important -label:read"`.
- Far more powerful than standard IMAP SEARCH for Gmail accounts.

### 5.2 Gmail Categories vs IMAP Folders

**The problem:**
- Gmail's inbox categories (Primary, Social, Promotions, Updates, Forums) are NOT accessible as IMAP folders.
- These categories are applied by Gmail's ML-based classification system and are only visible in the Gmail web/mobile interface and the Gmail API.
- Via IMAP, all categorized messages simply appear in INBOX.

**Workaround with labels:**
- Users can create Gmail filters that apply labels based on category, but this requires user-side setup.
- Our app could guide users to create these filters, or we could detect categories by implementing our own classification (which we are already doing for the Action Queue / Reading Queue / Filtered views).

**Practical implication:**
- Since our app has its own AI-based classification system (per the BRIEF), Gmail's categories are largely irrelevant. We will classify messages ourselves.
- We should still expose Gmail labels in the UI for users who rely on them for organization.

### 5.3 Gmail API as an Alternative to IMAP

The Gmail API (REST-based) is a fundamentally different approach:

**Advantages over IMAP:**
- Native label support (no folder abstraction mismatch).
- Native thread support (conversations are first-class objects).
- Server-side full-text search with Gmail's search syntax.
- History API: efficiently retrieve all changes since a given history ID (similar to QRESYNC but more capable).
- Push notifications via Google Cloud Pub/Sub (more efficient than IMAP IDLE).
- Better rate limiting semantics (quota units vs. connection limits).
- Batch API for multiple operations in a single HTTP request.
- Access to Gmail categories.

**Disadvantages:**
- Requires internet connectivity (no offline protocol support built in; IMAP at least gives you a TCP stream to work with).
- More complex authentication setup (same OAuth2, but additional Google Cloud Console configuration for Pub/Sub).
- Google Cloud Pub/Sub for push notifications requires a webhook endpoint or a Google Cloud subscription, which adds infrastructure.
- Quotas: 1 billion quota units/day (generous), 250 units/user/second. Different operations cost different amounts of quota.
- Only works for Gmail. You still need IMAP for iCloud and Microsoft 365, meaning two code paths.

**Recommendation:**
- Start with IMAP for all three providers. A unified IMAP code path is simpler to build and maintain.
- Consider adding Gmail API support later as an optional enhancement, specifically for features IMAP cannot provide (categories, History API for efficient sync, Pub/Sub for push).
- The Gmail API's History endpoint could replace CONDSTORE/QRESYNC-based sync for Gmail, which is notable since Gmail does not support QRESYNC.

### 5.4 Gmail Rate Limiting and Quotas

**IMAP limits:**
- Maximum 15 simultaneous IMAP connections per account.
- Bandwidth: 2500 MB download / day via IMAP.
- Connection frequency: if you open too many connections too quickly, Gmail may temporarily block with "Too many simultaneous connections" error.

**Gmail API limits:**
- 1,000,000,000 quota units / day.
- 250 quota units / user / second.
- Common operation costs: messages.get = 5 units, messages.list = 5 units, messages.send = 100 units.
- Effectively unlimited for a personal client with 3 accounts.

**SMTP limits (for sending via smtp.gmail.com):**
- Personal Gmail: 500 emails / day.
- Google Workspace: 2,000 emails / day.
- These limits are more than sufficient for personal use.

---

## 6. Email Parsing

### 6.1 MIME Parsing in Swift

MIME (Multipurpose Internet Mail Extensions) defines the format of email messages. Parsing MIME correctly is notoriously difficult due to decades of broken implementations sending malformed messages.

**Available Swift libraries for MIME parsing:**

1. **MimeFoundation** (Port of MimeKit): The most comprehensive option. Handles S/MIME, DKIM, internationalization, stream-based processing. Async/await support. This is the recommended choice.

2. **MimeParser** (github.com/miximka/MimeParser): Lightweight parser following RFC 822, RFC 2045, RFC 2046. Good for basic needs but less robust with malformed messages.

3. **MimeEmailParser** (github.com/igorrendulic/MimeEmailParser): Focused on email address parsing and validation per RFC 5322 and RFC 2047.

4. **MailCore2's built-in parser**: Comprehensive but tied to the MailCore2 Obj-C ecosystem.

### 6.2 Handling Multipart Messages

Email messages are structured as MIME trees. Common structures:

**Simple text email:**
```
Content-Type: text/plain
```

**HTML email with plain text fallback:**
```
Content-Type: multipart/alternative
  ├── text/plain (fallback)
  └── text/html (preferred)
```

**Email with attachments:**
```
Content-Type: multipart/mixed
  ├── multipart/alternative
  │   ├── text/plain
  │   └── text/html
  ├── application/pdf (attachment)
  └── image/png (attachment)
```

**Email with inline images in HTML:**
```
Content-Type: multipart/mixed
  ├── multipart/related
  │   ├── multipart/alternative
  │   │   ├── text/plain
  │   │   └── text/html (references cid:image1)
  │   └── image/png (Content-ID: <image1>)
  └── application/pdf (attachment)
```

**Implementation strategy:**
- Walk the MIME tree recursively.
- For `multipart/alternative`, prefer `text/html` over `text/plain` for display, but keep `text/plain` for search indexing and AI classification.
- For `multipart/related`, resolve `cid:` references in HTML to inline images.
- For `multipart/mixed`, separate body parts from attachment parts.
- For each attachment, store: filename, MIME type, size, Content-ID (if inline), and a reference to fetch the actual data on demand (do not download all attachments by default).

### 6.3 Extracting Plain Text vs HTML

**For display:**
- Use HTML rendering (WKWebView or SwiftUI WebView) for HTML messages. Strip or sandbox potentially dangerous elements (scripts, forms, external resources).
- Fall back to plain text rendering if no HTML part exists.

**For AI classification and search:**
- Always extract plain text, even from HTML messages.
- Convert HTML to plain text by stripping tags, decoding entities, and normalizing whitespace.
- For AI classification (newsletter detection, action item detection), plain text is preferred as it strips marketing formatting noise.

**For the Reading Queue (newsletter view):**
- Use the HTML version for rich rendering with a reader-mode-style stylesheet.
- Consider using a CSS reset/normalization to ensure consistent typography across different newsletter formats.

### 6.4 Handling Attachments

**Storage strategy:**
- Do NOT download attachments automatically during sync. Only fetch metadata (filename, size, MIME type) from BODYSTRUCTURE.
- Download attachment content on demand when the user clicks to view/save.
- Cache downloaded attachments locally with an LRU (least recently used) eviction policy.

**Inline vs. regular attachments:**
- Inline attachments (Content-Disposition: inline, or referenced by Content-ID in HTML) should be fetched when rendering the email body.
- Regular attachments (Content-Disposition: attachment) should only be fetched on user request.

**Size considerations:**
- Maximum email size is typically 25 MB (Gmail limit) or 35 MB (Microsoft 365 encoded size).
- Large attachments should be streamed rather than loaded entirely into memory.
- Use IMAP partial fetch (`BODY[]<offset.size>`) for progressive download of large attachments.

### 6.5 Character Encoding Issues

Email is a minefield of character encoding problems:

**Common encodings encountered:**
- UTF-8 (modern standard, most common).
- ISO-8859-1 / Latin-1 (older Western European).
- Windows-1252 (Microsoft's superset of Latin-1, extremely common in practice).
- ISO-2022-JP, Shift_JIS, EUC-JP (Japanese).
- GB2312, GBK, Big5 (Chinese).
- KOI8-R (Russian).

**Header encoding (RFC 2047):**
- Non-ASCII characters in headers (Subject, From, etc.) are encoded as `=?charset?encoding?text?=`.
- Example: `=?UTF-8?B?8J+Yig==?=` is a base64-encoded UTF-8 emoji.
- `B` = Base64 encoding, `Q` = Quoted-Printable encoding.

**Body encoding:**
- Content-Transfer-Encoding header specifies how the body is encoded: `7bit`, `8bit`, `quoted-printable`, `base64`, `binary`.
- The charset parameter on Content-Type specifies the character set: `Content-Type: text/plain; charset=UTF-8`.

**Common pitfalls:**
- Many emails claim charset=us-ascii but actually contain UTF-8 or Windows-1252.
- Some emails have no charset specified at all.
- Mismatched charset declarations and actual content are extremely common.
- MimeFoundation (MimeKit port) handles most of these edge cases well, as MimeKit was designed specifically to handle real-world broken email.

**Recommendation:**
- Use a robust MIME parsing library (MimeFoundation) that handles encoding detection and fallback.
- Implement a charset detection fallback: if declared charset fails to decode, try UTF-8, then Windows-1252, then ISO-8859-1.
- For the AI classification pipeline, normalize all text to UTF-8 after decoding.

### 6.6 Dealing with Broken/Malformed Emails

Real-world email is messy. Expect to encounter:

- Missing or incorrect Content-Type headers.
- Broken MIME boundaries (boundary string in header does not match body).
- Truncated messages.
- Invalid date formats in Date header (dozens of non-standard formats in the wild).
- Nested messages (message/rfc822) within messages.
- Emails with thousands of MIME parts (mailing list digests).
- HTML with unclosed tags, broken entities, mixed encodings.
- Headers with invalid RFC 2047 encoded words.
- Lines exceeding the 998-character limit specified by RFC 5322.

**Strategy:**
- Use a battle-tested MIME parser (MimeFoundation or MailCore2) that has been hardened against these issues.
- Implement graceful degradation: if parsing fails for a message, still display the raw text and flag it for manual review rather than crashing or silently dropping it.
- Log parsing errors for diagnosis but do not block sync.
- For date parsing, use a cascading parser that tries RFC 5322 format first, then common non-standard formats (dozens of patterns exist).

---

## 7. Performance and Reliability

### 7.1 Connection Pooling for Multiple Accounts

**Connection architecture for 3 accounts:**

Each account needs:
- 1 IMAP connection in IDLE mode for INBOX monitoring.
- 1 IMAP connection for on-demand operations (fetch, search, flag changes, folder sync).
- 1 SMTP connection (can be established on demand when sending, does not need to be persistent).

Total persistent connections: 6 IMAP connections (2 per account).

**Pool management:**
- For each account, maintain a minimum of 2 IMAP connections (1 IDLE + 1 worker).
- The worker connection can be used for various operations: fetching message bodies, syncing folders, performing searches.
- If multiple operations need to run concurrently for the same account, temporarily open additional connections (up to the provider's limit, respecting Gmail's 15-connection ceiling).
- Implement connection reuse: after completing an operation, return the connection to the pool rather than closing it.
- Set a maximum pool size of 5 connections per account (well within Gmail's 15-connection limit, leaving room for other devices).

**Connection lifecycle:**
- Open connections lazily on first use.
- Keep connections alive with periodic NOOP commands (every 5 minutes) when not in IDLE mode.
- Detect dead connections via TCP keepalive and/or failed operations.
- Re-establish failed connections with exponential backoff.

### 7.2 Handling Network Interruptions Gracefully

The Mac Mini is always on, but network can be intermittent.

**Detection:**
- Monitor IMAP connection health via TCP keepalive.
- Treat any failed IMAP command as a potential network issue.
- Use `NWPathMonitor` (Network.framework) to detect network state changes (connected, disconnected, path changes).

**Recovery strategy:**
1. On connection loss, mark the account as "disconnected" in the sync state.
2. Retry connection with exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s, 60s, then every 60s.
3. On reconnection:
   - If QRESYNC is supported: SELECT with QRESYNC parameters for efficient resync.
   - If only CONDSTORE: fetch changes since last known MODSEQ.
   - Otherwise: do a full UID reconciliation.
4. Resume IDLE on INBOX after reconnection.

**Idempotency:**
- All sync operations should be idempotent. If a sync is interrupted mid-way, restarting it should not cause duplicates or data loss.
- Use UIDs (not sequence numbers) for all operations, as sequence numbers can change between sessions.

**Offline queue:**
- If the user composes or takes actions (archive, snooze, flag) while disconnected, queue these operations locally.
- Execute queued operations in order when the connection is restored.
- Handle conflicts: if a message was modified on the server while offline, the server's state wins for flag changes, but user's explicit actions (archive, delete) take priority.

### 7.3 Caching Strategy for Offline Access

**Tiered caching approach:**

**Tier 1: Metadata (always cached)**
- Envelope data: From, To, Subject, Date, Message-ID, flags.
- BODYSTRUCTURE (MIME structure without content).
- Gmail-specific: X-GM-MSGID, X-GM-THRID, X-GM-LABELS.
- Classification decisions (which queue the message belongs to).
- Storage: SQLite database with FTS5 for full-text search.

**Tier 2: Message bodies (cached on view + recent messages)**
- Plain text and HTML body parts.
- Pre-fetch the last 30 days of message bodies in the background.
- Cache indefinitely once fetched (subject to storage limits).
- Storage: SQLite (for smaller messages) or filesystem (for larger messages), with references in the SQLite metadata DB.

**Tier 3: Attachments (cached on demand)**
- Only downloaded when the user explicitly views or saves an attachment.
- LRU eviction when cache exceeds a configurable size limit (e.g., 5 GB per account).
- Storage: filesystem with references in the SQLite DB.

**Database design:**
- One SQLite database per account (simplifies account removal and avoids contention).
- Tables: `messages` (metadata + body cache), `folders` (folder list and sync state), `attachments` (metadata + cache path), `sync_state` (per-folder UIDVALIDITY, HIGHESTMODSEQ, last sync time).
- Use SQLite WAL mode for concurrent reads during sync.

### 7.4 Incremental Sync Approaches

**Initial sync (first time connecting an account):**
1. LIST all folders, identify special-use folders.
2. SELECT INBOX, fetch envelope data for all messages (or the most recent N thousand if the mailbox is very large).
3. Repeat for other important folders (Sent, Drafts, Archive).
4. Fetch message bodies for the last 30 days in the background.
5. Build local search index.

**Ongoing sync (daemon running):**
1. IDLE on INBOX detects new messages immediately. Fetch envelope + body for new messages.
2. Every 2-5 minutes, poll non-INBOX folders for changes (NOOP to trigger pending responses, or SEARCH for recent messages).
3. Use CONDSTORE (CHANGEDSINCE) to detect flag changes without re-fetching everything.
4. Periodically (every 15-30 minutes), do a full UID reconciliation for each folder to catch any missed deletions.

**Reconnection sync (after network interruption or daemon restart):**
1. If QRESYNC is available: SELECT with QRESYNC to get all changes + expunges in one round trip.
2. If CONDSTORE only: FETCH FLAGS for all messages CHANGEDSINCE the last known MODSEQ, then do UID reconciliation for expunges.
3. If neither: full UID fetch and comparison with local cache.

### 7.5 Storage Expectations

**Typical email volumes:**
- Average user: ~50-100 emails/day.
- Heavy user (work): ~200-500 emails/day.
- Average mailbox: ~8,000-50,000 messages.
- Power user mailbox: 100,000+ messages.

**Storage per message (approximate):**
- Metadata only (envelope, flags): ~1 KB per message.
- Text/HTML body: ~5-50 KB per message (average ~15 KB).
- Attachments: highly variable. Average ~100 KB per message that has attachments (many messages have none).

**Total storage estimates for the Mac Mini cache:**
- 50,000 messages across 3 accounts, metadata only: ~50 MB.
- 50,000 messages with bodies cached: ~750 MB - 1.5 GB.
- With attachment cache (selective, LRU): +1-10 GB depending on usage.
- SQLite FTS5 index: ~20-30% of the text content size.

**Total expected:** 2-5 GB for a comprehensive cache. A Mac Mini with even a 256 GB drive has more than enough space. Set a configurable maximum (default 10 GB) with LRU eviction for attachments and old message bodies.

---

## 8. Privacy and Security

### 8.1 TLS Requirements

**All connections must use TLS:**
- IMAP: port 993 with implicit TLS (preferred) or port 143 with STARTTLS upgrade.
- SMTP: port 465 with implicit TLS or port 587 with STARTTLS upgrade.
- Never fall back to unencrypted connections. If TLS negotiation fails, the connection should fail rather than downgrade.

**TLS version:**
- Require TLS 1.2 as minimum. Prefer TLS 1.3 when available.
- All major email providers (Gmail, iCloud, Microsoft 365) support TLS 1.2 and 1.3.
- Use SwiftNIO SSL or Apple's `Network.framework` TLS support, both of which default to modern TLS versions.

**Certificate validation:**
- Always validate server certificates against the system trust store.
- Do NOT implement custom certificate trust exceptions or "accept any certificate" options.

### 8.2 Certificate Pinning Considerations

**Should we pin certificates?**

Certificate pinning adds security by ensuring the client only trusts specific certificates or public keys for a given server, protecting against compromised CAs or MITM attacks.

**Arguments for pinning:**
- Protects against nation-state MITM attacks on email connections.
- Prevents corporate network proxies from intercepting email traffic.

**Arguments against pinning:**
- Gmail, iCloud, and Microsoft rotate certificates regularly. Pinning to a specific certificate will break when the certificate rotates.
- Pinning to a public key (SPKI pinning) is more durable but still requires updates when the provider rotates keys.
- If pins become stale, the email client completely stops working until an update is deployed.
- For a personal email client used by one person, the threat model does not typically justify the maintenance burden.

**Recommendation:**
- Do NOT implement certificate pinning for this project. The maintenance burden outweighs the security benefit for a personal email client.
- Rely on the system trust store and TLS certificate validation, which is sufficient for the threat model.
- If certificate pinning is desired later, implement SPKI pinning with a backup pin and an update mechanism.

### 8.3 Local Encryption of Email Cache

**The threat model:**
- The Mac Mini is a physical device. If it is stolen or compromised, the email cache (SQLite database, cached attachments) could be accessed.
- macOS FileVault (full-disk encryption) provides the first line of defense. Ensure it is enabled on the Mac Mini.

**Application-level encryption:**

Option 1: **SQLCipher (recommended)**
- Drop-in replacement for SQLite that provides transparent 256-bit AES encryption.
- The encryption key can be derived from the user's macOS Keychain (stored there on first launch).
- Performance overhead is minimal (~5-15% for reads/writes).
- Protects the email database even if FileVault is not enabled or the disk is accessed from another OS.

Option 2: **File-level encryption for attachments**
- Use `CryptoKit` (Apple's framework) to encrypt attachment files on disk.
- Key management through the Keychain.
- Decrypt on the fly when the user views an attachment.

Option 3: **Rely solely on FileVault**
- Simplest approach. If FileVault is enabled (it is by default on modern macOS), all data at rest is encrypted.
- No application-level encryption needed.
- Risk: if the Mac Mini is running and unlocked, the disk is decrypted and accessible.

**Recommendation:**
- Enable FileVault as the baseline.
- Use SQLCipher for the email database for defense in depth.
- Encrypt attachment files using CryptoKit with a Keychain-stored key.
- This provides protection even if someone gains access to the running Mac Mini.

### 8.4 Tracking Pixel Blocking

**What tracking pixels are:**
- Invisible 1x1 pixel images embedded in HTML emails. When loaded, they phone home to the sender's server, revealing:
  - That the email was opened.
  - When it was opened.
  - The recipient's IP address (and approximate location).
  - Device/OS information from the HTTP User-Agent.

**Common tracking pixel patterns:**
- `<img src="https://tracker.example.com/pixel/abc123" width="1" height="1">`.
- Images with unique URLs per recipient.
- Redirecting image URLs (the URL itself does the tracking, the image is irrelevant).
- Some trackers use CSS background images instead of `<img>` tags.

**Blocking strategy:**

1. **Block all external images by default** in HTML email rendering.
   - Display a "Load images" button per email.
   - Users can whitelist specific senders to always load images.

2. **Proxy external images** through a local relay (more sophisticated):
   - Strip query parameters and unique identifiers from image URLs.
   - Cache images locally so repeat opens do not trigger additional tracking.
   - Anonymize the request (strip User-Agent, use a generic one).
   - This is what Apple Mail's "Protect Mail Activity" feature does (though Apple routes through their servers).

3. **Detect and strip known tracking pixels:**
   - Maintain a blocklist of known tracking domains (Mailchimp, SendGrid, HubSpot, etc.).
   - Remove 1x1 pixel images or images with tracking-associated URL patterns.
   - This is heuristic and will not catch all trackers.

**Recommendation:**
- Implement option 1 (block all external images by default) as the baseline. It is simple and effective.
- Add option 3 (known tracker detection) as an enhancement to strip tracking pixels from the HTML before rendering, allowing the rest of the images to load.
- Option 2 (proxying) can be added later for users who want images but not tracking.

### 8.5 External Image Loading Policies

**Three-tier policy:**

1. **Never load** (most private): All external resources blocked. Plain text rendering or HTML with inline-only content. Best for the Filtered (spam) view.

2. **Load on request** (default): External images blocked until the user clicks "Load Images." Per-sender whitelisting available. Recommended default for Action Queue.

3. **Always load from trusted senders**: External images loaded automatically for contacts in the user's address book or whitelisted senders. Convenient for the Reading Queue (newsletters from trusted sources).

**Implementation:**
- Intercept all resource loading in the WKWebView (or equivalent) used for HTML email rendering.
- Use `WKURLSchemeHandler` or `WKNavigationDelegate` to intercept and block/allow external requests.
- Replace blocked images with a placeholder (e.g., a light gray box with an image icon).
- Store per-sender image loading preferences in the local database.

**Beyond images:**
- Block all external CSS loading (some emails link to external stylesheets that can track).
- Block all JavaScript execution in email rendering (always, no exceptions).
- Block form submissions from within email HTML.
- Block all iframes and embedded content.
- Basically, treat email HTML as untrusted content and render it in a heavily sandboxed web view.

---

## Appendix A: Provider Configuration Reference

### Gmail
| Setting | Value |
|---|---|
| IMAP Server | `imap.gmail.com` |
| IMAP Port | 993 (TLS) |
| SMTP Server | `smtp.gmail.com` |
| SMTP Port | 587 (STARTTLS) or 465 (TLS) |
| Auth | OAuth2 / XOAUTH2 |
| IDLE | Supported |
| CONDSTORE | Supported |
| QRESYNC | Not supported |
| SORT/THREAD | Not supported |
| Extensions | X-GM-MSGID, X-GM-THRID, X-GM-LABELS, X-GM-RAW |
| Max IMAP Connections | 15 per account |
| IMAP Bandwidth | 2500 MB/day download |
| Sent Mail Auto-Save | Yes (do NOT manually APPEND) |

### iCloud Mail
| Setting | Value |
|---|---|
| IMAP Server | `imap.mail.me.com` |
| IMAP Port | 993 (TLS) |
| SMTP Server | `smtp.mail.me.com` |
| SMTP Port | 587 (STARTTLS) |
| Auth | App-Specific Password (PLAIN/LOGIN) |
| IDLE | Supported |
| CONDSTORE | Supported |
| QRESYNC | Supported |
| SORT | Supported |
| THREAD | Unknown |
| Extensions | SPECIAL-USE |
| Sent Mail Auto-Save | No (must APPEND manually) |

### Microsoft 365 / Outlook
| Setting | Value |
|---|---|
| IMAP Server | `outlook.office365.com` |
| IMAP Port | 993 (TLS) |
| SMTP Server | `smtp.office365.com` |
| SMTP Port | 587 (STARTTLS) |
| Auth | OAuth2 / XOAUTH2 |
| IDLE | Supported |
| CONDSTORE | Varies by server |
| QRESYNC | Varies by server |
| Focused Inbox | Not available via IMAP (Graph API only) |
| Max IMAP Connections | ~20 per account |
| Sent Mail Auto-Save | No (must APPEND manually) |

---

## Appendix B: Key RFCs and Standards

| RFC | Title | Relevance |
|---|---|---|
| RFC 3501 | IMAP4rev1 | Core IMAP protocol |
| RFC 2177 | IMAP4 IDLE | Push notifications |
| RFC 7162 | CONDSTORE / QRESYNC | Efficient sync |
| RFC 6154 | IMAP LIST SPECIAL-USE | Folder identification |
| RFC 5256 | IMAP SORT and THREAD | Server-side sorting/threading |
| RFC 4959 | IMAP SASL-IR | Initial auth response (perf) |
| RFC 4315 | IMAP UIDPLUS | UID-based operations |
| RFC 5322 | Internet Message Format | Email message format |
| RFC 2045-2049 | MIME | Multipart messages, encodings |
| RFC 2047 | MIME Encoded Words | Non-ASCII in headers |
| RFC 6749 | OAuth 2.0 | Authorization framework |
| RFC 7636 | PKCE for OAuth | Secure native app auth |
| RFC 5321 | SMTP | Sending email |
| RFC 3207 | SMTP STARTTLS | Encryption for SMTP |

---

## Appendix C: Open Questions and Decisions Needed

1. **IMAP library choice**: Evaluate SwiftMail and MimeFoundation+MailFoundation hands-on before committing. Build a small proof-of-concept that connects to all three accounts, fetches recent messages, and sends a test email.

2. **Gmail API vs IMAP**: Start with IMAP for uniformity. Revisit Gmail API if IMAP sync performance with Gmail is insufficient (especially around detecting expunged messages without QRESYNC).

3. **Daemon architecture**: LaunchAgent (per-user, recommended) vs LaunchDaemon (system-level). LaunchAgent is simpler because it runs in the user's session and has Keychain access.

4. **Database**: SQLite with SQLCipher is the recommended starting point. Consider SwiftData/Core Data if the sync layer to other devices benefits from Apple's built-in sync primitives (CloudKit integration), but this adds complexity.

5. **HTML rendering engine**: WKWebView in a heavily sandboxed configuration vs. custom HTML-to-attributed-string rendering (more control but much more work). WKWebView is recommended for V1.

6. **OAuth2 library**: Use Apple's AuthenticationServices framework (ASWebAuthenticationSession) for the OAuth2 browser-based authorization flow. For token management, build a lightweight wrapper around URLSession for token exchange and refresh, or evaluate a library like OAuthSwift.

7. **Connection management concurrency model**: Swift concurrency (actors) is a natural fit. Each IMAP account connection could be an actor, serializing commands to avoid protocol-level conflicts. The IDLE connection would be a separate long-running task.
