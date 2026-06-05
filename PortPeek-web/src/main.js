import './style.css'

// ── Terminal animation ────────────────────────────────────────
const LINES = [
  { text: '$ claude "start a dev server on 3000"', cls: 't-cmd' },
  { text: '  checking ports via PortPeek...',       cls: 't-dim' },
  { text: '→ get_available_port(preferred: 3000)',  cls: 't-out' },
  { text: '← { port: 3001, reserved: true }',       cls: 't-in'  },
  { text: '  starting server on 3001...',            cls: 't-dim' },
  { text: '✓ http://localhost:3001',                 cls: 't-ok'  },
]

const CHAR_MS    = 40
const LINE_PAUSE = 200

const terminalLines  = document.getElementById('terminal-lines')
const terminalCursor = document.getElementById('terminal-cursor')

let animationId = 0

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

async function runTerminal() {
  const id = ++animationId
  terminalLines.innerHTML = ''
  terminalCursor.style.display = ''

  for (const { text, cls } of LINES) {
    const span = document.createElement('span')
    span.className = cls
    terminalLines.appendChild(span)
    terminalLines.appendChild(document.createTextNode('\n'))

    for (const char of text) {
      if (animationId !== id) return
      span.textContent += char
      await sleep(CHAR_MS)
    }
    if (animationId !== id) return
    await sleep(LINE_PAUSE)
  }

  if (animationId === id) terminalCursor.style.display = 'none'
}

function resetTerminal() {
  animationId++
  terminalLines.innerHTML = ''
  terminalCursor.style.display = ''
}

let wasVisible = false

const observer = new IntersectionObserver(
  ([entry]) => {
    if (entry.isIntersecting && !wasVisible) {
      wasVisible = true
      runTerminal()
    } else if (!entry.isIntersecting && wasVisible) {
      wasVisible = false
      resetTerminal()
    }
  },
  { threshold: 0.3 }
)

observer.observe(document.getElementById('terminal'))

// ── Copy button ───────────────────────────────────────────────
const copyBtn  = document.getElementById('copy-btn')
const configEl = document.getElementById('config-code')

copyBtn.addEventListener('click', () => {
  navigator.clipboard.writeText(configEl.textContent.trim())
    .then(() => {
      copyBtn.textContent = 'Copied!'
      copyBtn.classList.add('copied')
      setTimeout(() => {
        copyBtn.textContent = 'Copy'
        copyBtn.classList.remove('copied')
      }, 2000)
    })
    .catch(() => {
      copyBtn.textContent = 'Failed'
      setTimeout(() => { copyBtn.textContent = 'Copy' }, 2000)
    })
})

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
