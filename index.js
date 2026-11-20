import express from "express"
import os from "os"
import path from "path"
import { fileURLToPath } from "url"

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const app = express()
const PORT = process.env.PORT ?? 8080

app.use(express.static(path.join(__dirname, "public")))

app.get("/api/hello", (req, res) => {
    res.json({ msg: "Hello from the server!" })
})

app.get("/api/status", (req, res) => {
    res.json({
        host: os.hostname(),
        node: process.version,
        platform: `${os.platform()} ${os.arch()}`,
        uptime: Math.floor(process.uptime()),
        memMB: Math.round(process.memoryUsage().rss / 1024 / 1024),
        time: new Date().toISOString(),
    })
})

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`)
})