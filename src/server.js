import express from "express"
import { exec } from "child_process"
import dotenv from "dotenv"

dotenv.config()

const app = express()
const port = process.env.PORT || 3456
const host = process.env.HOST || "0.0.0.0"

app.use(express.static("public"))

app.get("/api/metrics", (req, res) => {
  exec("sudo cscli metrics", (error, stdout, stderr) => {
    if (error) {
      console.error(`exec error: ${error}`)
      return res.status(500).json({ error: "Failed to fetch metrics" })
    }
    res.json({ metrics: stdout })
  })
})

app.listen(port, host, () => {
  console.log(`Server running on http://${host}:${port}`)
})

