import './style.css'

// ── Copy helper ───────────────────────────────────────────────
function attachCopy(btn, getText) {
  btn.addEventListener('click', () => {
    navigator.clipboard.writeText(getText().trim())
      .then(() => {
        btn.textContent = 'Copied!'
        btn.classList.add('copied')
        setTimeout(() => { btn.textContent = 'Copy'; btn.classList.remove('copied') }, 2000)
      })
      .catch(() => {
        btn.textContent = 'Failed'
        setTimeout(() => { btn.textContent = 'Copy' }, 2000)
      })
  })
}

// ── Install tabs ─────────────────────────────────────────────
document.querySelectorAll('.install-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.install-tab').forEach(t => {
      t.classList.remove('active')
      t.setAttribute('aria-selected', 'false')
    })
    document.querySelectorAll('.install-panel').forEach(p => p.classList.add('hidden'))
    tab.classList.add('active')
    tab.setAttribute('aria-selected', 'true')
    document.getElementById('tab-' + tab.dataset.tab)?.classList.remove('hidden')
  })
})

document.querySelectorAll('.copy-btn[data-copy]').forEach(btn => {
  attachCopy(btn, () => document.getElementById(btn.dataset.copy)?.textContent ?? '')
})

// ── Click to Install (.command file) ─────────────────────────
document.getElementById('click-install-btn')?.addEventListener('click', () => {
  const script = `#!/bin/bash
clear
echo "Installing portpeek-mcp..."
echo ""
if brew install adamorad/tap/portpeek-mcp && portpeek-mcp --install-launch-agent; then
  echo ""
  echo "Done! portpeek-mcp is installed and will start at login."
else
  echo ""
  echo "Something went wrong. Try the manual install at https://adamorad.github.io/portpeek/"
fi
echo ""
read -rp "Press Enter to close this window..."
`
  const blob = new Blob([script], { type: 'application/octet-stream' })
  const url  = URL.createObjectURL(blob)
  const a    = Object.assign(document.createElement('a'), { href: url, download: 'install-portpeek-mcp.command' })
  a.click()
  URL.revokeObjectURL(url)
})

// ── Config copy button ────────────────────────────────────────
const copyConfigBtn = document.getElementById('copy-config-btn')
const configCode    = document.getElementById('config-code')
if (copyConfigBtn && configCode) attachCopy(copyConfigBtn, () => configCode.textContent)

// ── Email form ────────────────────────────────────────────────
const emailForm  = document.getElementById('email-form')
const emailInput = document.getElementById('email-input')
const successMsg = document.getElementById('success-msg')
const errorMsg   = document.getElementById('error-msg')

emailForm?.addEventListener('submit', async (e) => {
  e.preventDefault()
  const email = emailInput.value.trim()
  const submitBtn = emailForm.querySelector('button[type="submit"]')
  submitBtn.disabled = true
  submitBtn.textContent = 'Sending…'
  errorMsg?.classList.add('hidden')

  try {
    const res = await fetch('https://formsubmit.co/ajax/adammor17@gmail.com', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ email, _subject: 'PortPeek waitlist signup', _captcha: 'false' }),
    })
    if (!res.ok) throw new Error('server error')
    emailForm.style.display = 'none'
    successMsg?.classList.remove('hidden')
  } catch {
    submitBtn.disabled = false
    submitBtn.textContent = 'Notify me'
    errorMsg?.classList.remove('hidden')
  }
})
