import express from "express"
import { exec } from "child_process"
import basicAuth from "express-basic-auth"
import rateLimit from "express-rate-limit"
import helmet from "helmet"
import dotenv from "dotenv"
import { fileURLToPath } from "url"
import { dirname, join } from "path"
import winston from "winston"

dotenv.config()

const __dirname = dirname(fileURLToPath(import.meta.url))

// Configure logger
const logger = winston.createLogger({
  level: "info",
  format: winston.format.json(),
  defaultMeta: { service: "crowdsec-metrics" },
  transports: [
    new winston.transports.File({ filename: "error.log", level: "error" }),
    new winston.transports.File({ filename: "combined.log" }),
  ],
})

if (process.env.NODE_ENV !== "production") {
  logger.add(
    new winston.transports.Console({
      format: winston.format.simple(),
    }),
  )
}

const app = express()

// Security middleware
app.use(helmet())

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
})
app.use(limiter)

// Basic authentication
app.use(
  basicAuth({
    users: { [process.env.ADMIN_USER]: process.env.ADMIN_PASS },
    challenge: true,
  }),
)

// Serve static files from the React app
app.use(express.static(join(__dirname, "build")))

// Secure command execution
const execCommand = (cmd) => {
  return new Promise((resolve, reject) => {
    exec(cmd, { timeout: 10000, maxBuffer: 1024 * 1024 }, (error, stdout, stderr) => {
      if (error) {
        logger.error(`Command execution error: ${error}`)
        reject(error)
      } else {
        resolve(stdout)
      }
    })
  })
}

// API endpoint for metrics
app.get("/api/metrics", async (req, res) => {
  try {
    const hostMetrics = await execCommand(process.env.HOST_METRICS_CMD)
    const dockerMetrics = await execCommand(process.env.DOCKER_METRICS_CMD)
    res.json({ host: hostMetrics, docker: dockerMetrics })
  } catch (error) {
    logger.error("Error fetching metrics", { error })
    res.status(500).json({ error: "Failed to fetch metrics" })
  }
})

// Catch-all route to return the React app
app.get("*", (req, res) => {
  res.sendFile(join(__dirname, "build", "index.html"))
})

const port = process.env.PORT || 3456;
const host = process.env.HOST || '0.0.0.0'; // Bind to all interfaces, but we'll restrict this with firewall rules

app.listen(port, host, () => {
  logger.info(`Server running on http://${host}:${port}`);
});

