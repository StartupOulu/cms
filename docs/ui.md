# UI design guide

Visual and interaction guidance for the CMS. Complements `AGENTS.md`,
which covers the frontend tech constraints.

## Who we're designing for

The primary user is a non-technical editor with limited exposure to
content tools, low motivation to learn another SaaS, and potentially
weeks between visits. The secondary audience is occasional contributors
from mixed backgrounds. Design for the first user; the second is
well-served if the first is.

## Principles

- **Hide the machinery.** Nothing in the UI mentions `commit`,
  `branch`, `repo`, `build`, `Jekyll`, or `front matter`. Drafts vs.
  published is the deepest level of abstraction the user should see.
- **Autosave, always.** A Save button that can be forgotten is a bug.
  The only button that can lose work is "Remove from site", and it
  confirms.
- **One primary action per screen.** The scary-important button is the
  only prominent one. Peer buttons compete for attention and invite
  mistakes.
- **Familiar metaphors beat correct ones.** Model on Google Docs or
  Apple Notes, not admin panels. List → click → edit → it's on the
  site.
- **Self-evident every session.** Users return weeks later with no
  memory. The current screen teaches itself. No onboarding tooltips,
  no shortcuts-as-primary.
- **Errors in the user's language.** `Couldn't publish right now — we'll
  try again in a minute` — never a stack trace or git error.
- **Obvious always wins.** When a decision splits between clever and
  obvious, pick obvious.

## UI language

The CMS UI is bilingual. Content is English-only (see
`Content model` in AGENTS.md).

- Default locale: `fi`. User-switchable; the choice persists per user.
- Toggle lives in the account menu. Asymmetric labels: "In English"
  when in Finnish, "Suomeksi" when in English. No flags.
- Every user-facing string lives in both `config/locales/fi.yml` and
  `config/locales/en.yml`. Both files updated in the same commit. No
  English-only strings leaking to Finnish sessions.
- `rails-i18n` is an accepted carve-out from the minimal-gems rule.
  Hand-translating `ActiveRecord` validation messages, date/number
  formats, and pluralization is clearly worse than adopting a
  Rails-core-adjacent gem.
- The editor is a custom block-based markdown editor (see
  `The editor` below), so all editor chrome lives in the same `fi.yml`
  / `en.yml` catalogs. No third-party editor whose language needs
  separate handling.

## Visual direction

Inspired by [coolors.co](https://coolors.co): white background,
near-black text, one saturated blue accent, minimal chrome, content
dominates UI.

### Palette

Define once as CSS custom properties in `:root`, reference everywhere.
Use `oklch()` for all colors.

- Background: white.
- Text: near-black for body, mid-gray for secondary/meta labels.
- Accent: blue. One hue. Used only for the primary button and links.
- Semantic: red (destructive), green (success), amber (warning). Muted,
  surface-only.
- Borders: one very light gray, reused everywhere.

No gradients. No tints. **No dark mode for M1–M3.** Revisit only if a
real user asks.

### Typography

- System font stack: `-apple-system, BlinkMacSystemFont, "Segoe UI",
  Roboto, sans-serif`. Same family in chrome and editor.
- Base body size 16px, line-height ~1.55.
- Four sizes: body, small (labels/meta), H2 (section heading), H1
  (post title in editor). No H3/H4 needed at this scope.
- Weights: regular (400) for body, medium (500) for buttons and
  labels, semibold (600) for titles.

### Surfaces

No shadows. Borders and whitespace carry all hierarchy. Shadows read
as "designed UI"; borders read as "simple tool".

### Layout

- Centered column, max-width ~720px for the editor canvas.
- Post list and listings can be wider.
- Generous vertical spacing — Notion density, not Jira density.

### Header

Wordmark on the left. Account menu on the right. Thin border-bottom
or whitespace separator. Nothing else.

**Wordmark.** Displays `StartupOulu CMS` for the StartupOulu
deployment. The string is a configuration value (`cms.name` or
similar), not a hardcoded constant — see "Generalize from day one"
in `AGENTS.md`. The wordmark is **not translated**: `StartupOulu CMS`
renders the same in both Finnish and English UI. It's a product
name, not a UI string.

**Navigation items:**

- M1–M3: empty. The Posts list is the home page; no nav item is
  needed to find it.
- M4+: `Posts` and `Events` become peer top-nav items (left side,
  after the wordmark). They're equally important; neither is a
  sub-page of the other.
- **Active indicator:** the nav item corresponding to the current
  section gets a 2px bottom-border in the accent blue. Same color as
  the input focus ring, so the visual vocabulary is consistent.

**Account menu.**

- Trigger: the signed-in user's display name as plain text, followed
  by a small chevron (e.g. `Maria ▾`). No avatar, no initials, no
  icon-only trigger. Users will need a `display_name` field.
- Items:
  - Language toggle: a single self-referential link. Clicking it
    switches locale in one click. Label: `In English` when the UI is
    in Finnish, `Suomeksi` when it's in English.
  - `Sign out`.
- M1 stops there. No profile page, no preferences screen, no
  settings.
- M4+ adds `Edit profile` as a menu item — lets the user change at
  least their display name. The M1 single admin sets their display
  name during `bin/setup`. From M4 onward, display name is captured
  during account creation (invite-accept or admin-creation flow) and
  editable afterwards in the profile edit screen.

### Buttons

- **Primary**: solid blue, white text, 6px radius, 10–12px vertical
  padding. One per screen.
- **Secondary**: text-only, blue text, no border.
- **Destructive**: red fill when promoted (confirmation screen), red
  text-only when demoted (in a `...` menu).

### Inputs

- Light gray border, 8px radius, blue focus ring.
- Labels above the field. Never placeholder-as-label.
- Error state: red border + red helper text below.

### Icons

Sparingly. Text labels always win. When icons are necessary, use
small monochrome inline SVGs from a curated set.

### Mobile

The CMS should be *usable* on a phone — an editor should be able to
fix a typo from the couch. It does not need to be *polished* for
mobile.

- Layouts reflow with simple container queries and sensible
  min-widths; no separate mobile design.
- Editor is desktop-first. Block editor should be *usable* on mobile
  (you can tap into a paragraph, type, add a new block) — don't
  invest in phone-only polish.
- Header and post list should be comfortable on a narrow viewport.
  The post-editing flow is acceptable if it's "works, a bit cramped".
- Mobile is a checkpoint ("can I fix a typo?"), not a design
  target ("can I write a long post from my phone?").

## Interaction patterns

### Autosave

- Debounce ~1s after last keystroke plus save on blur.
- Feedback text in the editor header:
  - English: `Saving…` → `Saved a moment ago`
  - Finnish: `Tallennetaan…` → `Tallennettu hetki sitten`
- Silent retry on transient failure. Surface a small banner only if
  retries exhaust.
- Never block typing.

### Publish

- Button shows `Publishing…` with a subtle spinner during the
  operation.
- On success: full-page transition to a confirmation screen with
  **View on site** as the single primary action and **Back to posts**
  as a secondary text link.
- On failure: inline error in the editor with a single **Try again**
  button. Technical detail hidden behind a "More info" disclosure.
- **Button state when there's nothing to publish.** On a published
  post with no pending edits (`published_blocks == blocks` — see
  AGENTS.md `Data model notes`), the `Update` button is
  **disabled**, not hidden. A disabled control is more obvious than
  a missing one — users don't wonder where the button went.

### Preview

- Opens in a new tab.
- Rebuilds on click — no "stale" indicator. Simple beats clever.

### Unpublish vs. delete

- **Unpublish** lives in the `...` menu on a published post. Removes
  the post from the site, keeps it in the CMS. Confirmation copy:
  `This removes the post from the site. You can publish it again
  later.`
- **Delete draft** lives in the `...` menu on a draft (a post that
  has never been published). Permanently removes the draft from the
  CMS. No trash, no undo. Confirmation copy: `This permanently
  deletes the draft.`
- Deleting a previously-published post is not in scope for M1 —
  unpublish first, then it behaves like a draft and can be deleted
  from there.

### Errors

- User-language copy. Work-is-saved reassurance first, action second.
- Top-of-page banner for system issues. Inline next to the field for
  validation. Never modal.
- Example: `Your work is saved. Couldn't publish right now — try again
  in a minute.`

### Image upload (M2)

- **Drop/paste behavior.** Drag-and-drop an image file onto the
  editor, or paste an image from the clipboard, to insert a new
  image block at the current position. The block shows a light-gray
  placeholder with a small spinner while the upload runs. Typing in
  other blocks continues freely — upload never blocks the editor.
- **On success.** Placeholder swaps for the image inline. Autosave
  picks up the change on next debounce.
- **On failure.** Placeholder shows a retry affordance with copy in
  the user's language: `Couldn't upload — try again`. Single click to
  retry. No modal.
- **Size/type limits (default — adjust before M2 ships):** jpg, png,
  webp. Max 10 MB per image. Files exceeding the limit produce an
  inline error next to the cursor — the upload never starts.
- **URL transition.** Before publish, images are served by Active
  Storage (`/rails/active_storage/...`). On publish the `PublishService`
  rewrites image `src` attributes to their final website-repo paths
  (see the image-path convention in `AGENTS.md`). Draft preview and
  final published post show the same image, different URLs — this
  is accepted.

### Shortcuts

- `Cmd/Ctrl+S` works redundantly with autosave. Shows the `Saved`
  acknowledgment because users reflex-hit it.
- No `Cmd+Enter` to publish. Too dangerous.

### Confirmations

- Only for destructive or slow+costly actions.
- Copy describes the consequence: `This removes the post from the
  site.` — not "Are you sure?"
- Confirmation button uses the specific verb (`Remove from site`),
  never `Confirm` or `OK`.

## Per-screen primary actions

### Home / post list

- Primary: open an existing post (the row is the affordance).
- Secondary: `Write a new post` — present, not competing.
- Empty state: single large `Start your first post` button.
- No admin sidebar, no Settings area, no Users/Media navigation.
- Default sort: `published_at` descending. Drafts (no `published_at`)
  sit above published posts, sorted by `updated_at` descending within
  the draft group, so in-progress work is always on top.
- Drafts are visually distinct: muted title color, a small `Draft`
  label at the right of the row. A subtle divider separates the draft
  group from published posts below. No separate tabs or filters in
  M1.

### Editor

- Primary: **Publish** (or **Update** when the post is already
  published). One button.
- No `Save` button — autosave handles it.
- Preview: secondary text link.
- Unpublish: `...` menu.

**Editor layout, top to bottom:**

1. **Title** — separate input at the top, styled as large H1. Not
   part of the block editor body. Used for the Jekyll front matter
   `title:` and for generating the slug.
2. **Slug / URL preview** — small, muted text directly under the
   title, showing the full published URL as a preview (e.g.
   `startupoulu.com/blog/my-first-post`). Auto-generated from the
   title; click to edit.
    - Before first publish: edits are silent.
    - After publish: editing the slug changes the post's URL. Surface
      a quiet warning at edit time: `Changing the web address means
      old links to this post will stop working.` Don't block the
      edit.
3. **Body** — the block editor (see `The editor` section below).
4. **Excerpt / summary** — optional single-line input below the body.
   Label it plainly (`Summary`), note it's optional. Used for the
   listing page on the live site; never required to publish.

Nothing else in the editor chrome for M1. No tags, no publish date
picker, no author field (author comes from the signed-in user).
Additional metadata gets added only when a concrete need shows up.

## The editor

A custom block-based markdown editor. Each block is one markdown
primitive. Blocks are stored as a JSON array in SQLite; on publish
they serialize to markdown. The block JSON is the source of truth on
re-edit — the committed markdown is a published projection.

### Block types (v1)

| Block | Markdown output |
|---|---|
| Heading (H2) | `## text` |
| Heading (H3) | `### text` |
| Paragraph | `text` |
| Unordered list | `- item` per child |
| Ordered list | `1. item` per child |
| Image | `![alt](url)` — `alt` only; no caption in v1 |

**Out of v1, easy to add later:** quote (`> …`), code block
(``` ``` ```).

**Out of scope entirely:** tables, callouts, columns, embeds beyond
inline images. YAGNI until a real post needs them.

### Inline formatting

**None in v1.** No bold, no italic, no inline links. Paragraphs are
plain text.

- Rationale: inline formatting inside a block requires real
  `contenteditable` handling (selection, paste, IME, undo), which is
  a genuine engineering project. Skipping it makes v1 shippable and
  avoids shipping half-baked rich text.
- URLs in paragraph text render as plain text on the site in v1 —
  not clickable. Auto-linking is deferred; revisit when users
  complain. If/when added, it's a short regex pass in the block →
  markdown serializer that wraps detected URLs with kramdown
  autolink syntax (`<https://…>`).
- Inline formatting (bold, italic, explicit link text like
  `[foo](url)`) will come back when users request it. At that point,
  decide: hand-roll it or adopt a substrate (Editor.js, Tiptap).
  Don't pre-build for it.

### Interactions

- **Typing.** Click into a block, type. Enter at the end of a block
  creates a new empty paragraph below the current one.
- **Changing a block's type.** At the start of an empty block, `/`
  opens a small menu (`/heading`, `/list`, `/image`). For
  discoverability, also provide a `+` button between blocks that
  shows the same menu.
- **Paste.** Paste from any source is coerced to plain text. Line
  breaks become paragraph separators. Formatting from Word / Docs /
  web pages is stripped. Document this behavior in-app so users
  aren't surprised.
- **Backspace** at the start of a block merges it into the previous
  block's type. Backspace on an empty list item demotes it to a
  paragraph.
- **Lists are flat in v1.** No nested lists, no indentation via Tab.
  Nesting adds real interaction complexity; defer until a post needs
  it.
- **Block reordering.** Not in v1. Users cut and repaste. Revisit
  when a user complains.
- **Keyboard shortcuts.** Only the redundant `Cmd/Ctrl+S` (covered
  above). No formatting shortcuts, since there's no formatting.
- **Undo.** Browser-native within a single block's text. Cross-block
  undo is deferred; autosave covers the realistic recovery need.

### After publish

- Primary: `View on site`.
- Secondary: `Back to posts` (text link).
- No modal — full-page confirmation screen at its own URL
  (e.g. `/posts/:id/published`). The URL survives refresh and the
  back button so the user isn't confused if they reload. No
  auto-redirect — the user leaves by clicking.

### Sign-in

- Primary: `Sign in`.
- Email + password only. No `Forgot password` link, no `Remember me`
  checkbox. The CMS has no email-sending capability yet, so password
  reset is an operator task (Rails console) rather than a UI flow.
- Password auth for M1 (single admin user). Magic-link is a candidate
  for M4 when multiple editors arrive — but that depends on adding
  email sending first.
- **Session**: 14-day rolling cookie (refreshed on each request).
  Users who touch the CMS weekly shouldn't have to sign in every
  time. A browser-session cookie (Rails default) would make the tool
  feel hostile to casual use.

## Explicitly out of scope

- Dark mode (M1–M3)
- Delete of previously-published posts (M1 — unpublish first, then
  delete from drafts)
- Scheduled publishing
- Keyboard shortcuts as primary interactions
- Tooltips as a way to explain features
- Onboarding flows
- Per-post language selector (content is English-only)
- Forgot-password / password-reset UI (no email sending yet;
  operator resets via Rails console)
- Polished mobile layouts (mobile must be usable, not refined)
- Tags, categories, and multi-author attribution in the editor (no
  concrete need yet)
- Inline formatting in paragraphs (bold, italic, links) — deferred
  until users request it; see `The editor` above
- Block reordering — deferred; users cut and repaste
- Tables, callouts, columns, and any non-v1 block types
