import express from "express";
import { exec } from "child_process";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

// Load environment variables
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = process.env.PORT || 3456;
const host = process.env.HOST || "0.0.0.0";

// Middleware for basic security
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  next();
});

// Serve static files
app.use(express.static(path.join(__dirname, "public")));

function execCommand(command) {
  return new Promise((resolve, reject) => {
    exec(command, { timeout: 10000 }, (error, stdout, stderr) => {
      if (error) {
        console.error(`Error executing command: ${command}`, error);
        reject(new Error(`Command execution failed: ${error.message}`));
        return;
      }
      if (stderr) {
        console.warn(`Command warning: ${stderr}`);
      }
      resolve(stdout);
    });
  });
}

app.get("/api/metrics", async (req, res) => {
  try {
    const [hostMetrics, dockerMetrics] = await Promise.all([
      execCommand("sudo cscli metrics").catch(error => {
        console.error("Host metrics failed:", error);
        return "Error fetching host metrics";
      }),
      execCommand("sudo docker exec crowdsec cscli metrics").catch(error => {
        console.error("Docker metrics failed:", error);
        return "Error fetching docker metrics";
      })
    ]);

    res.json({ 
      host: hostMetrics, 
      docker: dockerMetrics,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error("Metrics endpoint error:", error);
    res.status(500).json({ 
      error: "Failed to fetch metrics",
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Catch-all route for SPA
app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    error: "Internal Server Error",
    message: process.env.NODE_ENV === 'production' ? 'Something went wrong' : err.message
  });
});

// Start server with error handling
const server = app.listen(port, host, () => {
  console.log(`Server running on http://${host}:${port}`);
}).on('error', (error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
