import './style.css'

// ── Copy helper ───────────────────────────────────────────────
function attachCopy(btn, getText) {
  btn.addEventListener('click', () => {
    navigator.clipboard.writeText(getText().trim())
      .then(() => {
        btn.textContent = 'Copied!'
        btn.classList.add('copied')
        setTimeout(() => {
          btn.textContent = 'Copy'
          btn.classList.remove('copied')
        }, 2000)
      })
      .catch(() => {
        btn.textContent = 'Failed'
        setTimeout(() => { btn.textContent = 'Copy' }, 2000)
      })
  })
}

// ── Agent tabs (config section) ───────────────────────────────
const HTTP_CONFIG  = '{"mcpServers":{"portpeek":{"url":"http://localhost:27182"}}}'
const STDIO_CONFIG = '{"mcpServers":{"portpeek":{"command":"portpeek-mcp","args":["--stdio"]}}}'

const runStep   = document.getElementById('run-step')
const configCode = document.getElementById('config-code')

document.querySelectorAll('.agent-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.agent-tab').forEach(t => t.classList.remove('active'))
    tab.classList.add('active')
    const isStdio = tab.dataset.agent === 'stdio'
    configCode.textContent = isStdio ? STDIO_CONFIG : HTTP_CONFIG
    if (runStep) runStep.style.display = isStdio ? 'none' : ''
  })
})

// ── Config copy button ────────────────────────────────────────
const copyConfigBtn = document.getElementById('copy-config-btn')
if (copyConfigBtn && configCode) attachCopy(copyConfigBtn, () => configCode.textContent)

// ── Email form ────────────────────────────────────────────────
const emailForm  = document.getElementById('email-form')
const emailInput = document.getElementById('email-input')
const successMsg = document.getElementById('success-msg')

emailForm.addEventListener('submit', async (e) => {
  e.preventDefault()
  try {
    const res = await fetch('/api/notify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: emailInput.value }),
    })
    if (!res.ok) throw new Error('server error')
    emailForm.style.display = 'none'
    successMsg.classList.remove('hidden')
  } catch {
    // leave form intact; user can retry
  }
})
