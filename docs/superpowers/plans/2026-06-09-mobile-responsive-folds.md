# Mobile Responsive Folds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Both fold1 and fold2 of the PortPeek landing page fit correctly within any mobile viewport (320px–430px wide, 580px–900px tall) with no overflow, clipping, or missing elements.

**Architecture:** Pure CSS changes to the single media query block in `style.css`. On mobile, fold1 becomes exactly `100dvh` tall with the app screenshot expanding/shrinking to fill whatever vertical space the fixed-height elements leave behind (flex fill pattern). Fold2 stays `min-height: 100dvh` but uses tighter spacing so its content fits on short screens.

**Tech Stack:** Vanilla CSS, Vite (build only).

---

## File Structure

- Modify: `PortPeek-web/src/style.css` — the `@media (max-width: 640px)` block and the `.fold1`, `.app-window-wrap`, `.app-screenshot` base rules.

---

### Task 1: Make fold1 fill exactly the viewport and let the screenshot flex

The screenshot is a fixed `min(140px, 38vw)` wide today, which means it's also a fixed height (~175px on 375px screen). On a 580px tall phone that leaves no room for everything else. Instead, the screenshot should fill whatever vertical space is left after the text and form are laid out.

**Files:**
- Modify: `PortPeek-web/src/style.css`

- [ ] **Step 1: Replace the entire `@media (max-width: 640px)` block**

Find this block (around line 543):

```css
@media (max-width: 640px) {
  .fold1          { min-height: 100svh; justify-content: flex-start; padding-bottom: 0; }
  .fold1-inner    { padding-top: 44px; gap: 14px; flex: 1; }
  .app-screenshot { width: min(140px, 38vw); }
  h1              { font-size: 1.75rem; }
  .tagline        { font-size: 0.9rem; }
  .email-form     { flex-direction: column; align-items: stretch; }
  .email-form input  { width: 100%; min-height: 44px; }
  .email-form button { width: 100%; min-height: 44px; }
  .scroll-indicator { padding: 20px 16px; margin-top: auto; }
  .fold2-inner    { padding: 0 20px; gap: 20px; }
  .fold2-headline { font-size: 1.25rem; }
  .step-card      { padding: 16px; }
  .copy-btn       { min-height: 44px; padding: 10px 16px; }
  .install-tab    { padding: 12px 0; min-height: 44px; }
}
```

Replace with:

```css
@media (max-width: 640px) {
  /* ── Fold 1: exact viewport height, screenshot fills leftover space ── */
  .fold1 {
    height: 100dvh;
    overflow: hidden;
    justify-content: space-between;
    padding: 0 20px 0;
  }

  .fold1-inner {
    padding-top: 40px;
    gap: 10px;
    flex: 1;
    min-height: 0;
    width: 100%;
  }

  h1 { font-size: clamp(1.5rem, 6.5vw, 2rem); }

  .tagline { font-size: clamp(0.82rem, 3.2vw, 0.95rem); }

  .hero-cta { gap: 10px; }

  .coming-soon-badge { font-size: 11.5px; }

  .email-form { flex-direction: column; align-items: stretch; }
  .email-form input  { width: 100%; min-height: 44px; }
  .email-form button { width: 100%; min-height: 44px; }

  /* Screenshot: fills whatever space remains after text/form */
  .app-window-wrap {
    flex: 1;
    min-height: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    padding: 4px 0;
  }

  .app-screenshot {
    height: 100%;
    width: auto;
    max-width: min(180px, 42vw);
    object-fit: contain;
  }

  .compat-strip { font-size: 10.5px; }

  .scroll-indicator { padding: 16px 16px; flex-shrink: 0; }

  /* ── Fold 2: tighter spacing ── */
  .fold2 { min-height: 100dvh; padding: 48px 0 40px; }
  .fold2-inner    { padding: 0 20px; gap: 16px; }
  .fold2-headline { font-size: 1.2rem; }
  .fold2-sub      { font-size: 13.5px; }
  .setup-steps    { gap: 10px; }
  .step-card      { padding: 14px; gap: 10px; }
  .copy-btn       { min-height: 44px; padding: 10px 14px; }
  .install-tab    { padding: 12px 0; min-height: 44px; }
  .tool-pill      { font-size: 11px; padding: 4px 10px; }
  .fold2-credit-img { width: 80px; }
}
```

- [ ] **Step 2: Build and verify no errors**

```bash
cd PortPeek-web && npm run build
```

Expected: `✓ built in XXms`

- [ ] **Step 3: Commit**

```bash
git add PortPeek-web/src/style.css
git commit -m "fix: fluid mobile layout — screenshot fills leftover space in fold1"
```

- [ ] **Step 4: Merge to main and push**

```bash
git checkout main && git merge fix/mobile-fluid-layout --no-edit && git push origin main
```
