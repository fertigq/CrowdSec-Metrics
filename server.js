import express from "express"
import { exec } from "child_process"
import dotenv from "dotenv"

dotenv.config()

const app = express()
const port = process.env.PORT || 3456
const host = process.env.HOST || "0.0.0.0"

app.use(express.static("public"))

app.get("/api/metrics", (req, res) => {
  Promise.all([execCommand("sudo cscli metrics"), execCommand("sudo docker exec crowdsec cscli metrics")])
    .then(([hostMetrics, dockerMetrics]) => {
      res.json({ host: hostMetrics, docker: dockerMetrics })
    })
    .catch((error) => {
      console.error(`Error fetching metrics: ${error}`)
      res.status(500).json({ error: "Failed to fetch metrics" })
    })
})

function execCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        reject(error)
      } else {
        resolve(stdout)
      }
    })
  })
}

app.listen(port, host, () => {
  console.log(`Server running on http://${host}:${port}`)
})

