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

// ── Command sets per agent type ───────────────────────────────
const CMDS = {
  http: {
    brew:     'brew install adamorad/tap/portpeek-mcp && portpeek-mcp --install-launch-agent',
    download: 'curl -Lo portpeek-mcp.zip https://github.com/adamorad/portpeek/releases/latest/download/portpeek-mcp-macos-arm64.zip && unzip portpeek-mcp.zip && mv portpeek-mcp /usr/local/bin/ && portpeek-mcp --install-launch-agent',
    clone:    'git clone https://github.com/adamorad/portpeek && cd portpeek/mcp-server && swift build -c release && cp .build/release/portpeek-mcp /usr/local/bin/ && portpeek-mcp --install-launch-agent',
    config:   '{"mcpServers":{"portpeek":{"url":"http://localhost:27182"}}}',
  },
  stdio: {
    brew:     'brew install adamorad/tap/portpeek-mcp',
    download: 'curl -Lo portpeek-mcp.zip https://github.com/adamorad/portpeek/releases/latest/download/portpeek-mcp-macos-arm64.zip && unzip portpeek-mcp.zip && mv portpeek-mcp /usr/local/bin/',
    clone:    'git clone https://github.com/adamorad/portpeek && cd portpeek/mcp-server && swift build -c release && cp .build/release/portpeek-mcp /usr/local/bin/',
    config:   '{"mcpServers":{"portpeek":{"command":"portpeek-mcp","args":["--stdio"]}}}',
  },
}

const IDS = { brew: 'brew-cmd', download: 'download-cmd', clone: 'clone-cmd' }

function applyAgent(agent) {
  const cmds = CMDS[agent]
  Object.entries(IDS).forEach(([tab, id]) => {
    const el = document.getElementById(id)
    if (el) el.textContent = cmds[tab]
  })
  const cfg = document.getElementById('config-code')
  if (cfg) cfg.textContent = cmds.config
}

// ── Install tabs ─────────────────────────────────────────────
document.querySelectorAll('.install-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.install-tab').forEach(t => t.classList.remove('active'))
    document.querySelectorAll('.install-panel').forEach(p => p.classList.add('hidden'))
    tab.classList.add('active')
    document.getElementById('tab-' + tab.dataset.tab)?.classList.remove('hidden')
  })
})

document.querySelectorAll('.copy-btn[data-copy]').forEach(btn => {
  attachCopy(btn, () => document.getElementById(btn.dataset.copy)?.textContent ?? '')
})

// ── Agent tabs ────────────────────────────────────────────────
document.querySelectorAll('.agent-tab').forEach(tab => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.agent-tab').forEach(t => t.classList.remove('active'))
    tab.classList.add('active')
    applyAgent(tab.dataset.agent)
  })
})

const copyConfigBtn = document.getElementById('copy-config-btn')
const configCode    = document.getElementById('config-code')
if (copyConfigBtn && configCode) attachCopy(copyConfigBtn, () => configCode.textContent)

// ── Email form ────────────────────────────────────────────────
const emailForm  = document.getElementById('email-form')
const emailInput = document.getElementById('email-input')
const successMsg = document.getElementById('success-msg')

emailForm.addEventListener('submit', async (e) => {
  e.preventDefault()
  const email = emailInput.value
  emailForm.style.display = 'none'
  successMsg.classList.remove('hidden')
  fetch('https://formsubmit.co/ajax/adammor17@gmail.com', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ email, _subject: 'PortPeek waitlist signup', _captcha: 'false' }),
  }).catch(() => {})
})
