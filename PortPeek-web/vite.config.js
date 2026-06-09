import { defineConfig } from 'vite'
import fs from 'fs'
import path from 'path'

const emailsFile = path.resolve('emails.txt')

export default defineConfig({
  // Set VITE_BASE=/<repo-name>/ in CI for project pages, or VITE_BASE=/ for custom domains.
  base: process.env.VITE_BASE ?? '/',
  plugins: [
    {
      name: 'email-collector',
      configureServer(server) {
        server.middlewares.use('/api/notify', async (req, res) => {
          if (req.method !== 'POST') {
            res.writeHead(405).end()
            return
          }
          let body = ''
          req.on('data', chunk => (body += chunk))
          req.on('end', () => {
            try {
              const { email } = JSON.parse(body)
              if (email && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
                fs.appendFileSync(emailsFile, email + '\n')
                res.writeHead(200, { 'Content-Type': 'application/json' }).end(JSON.stringify({ ok: true }))
              } else {
                res.writeHead(400).end(JSON.stringify({ error: 'invalid email' }))
              }
            } catch {
              res.writeHead(400).end(JSON.stringify({ error: 'bad request' }))
            }
          })
        })
      }
    }
  ]
})
