const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

const app = express();
const port = process.env.PORT || 3456;
const host = process.env.HOST || '0.0.0.0';

// Serve static files from the 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// Function to safely execute commands without sudo
function safeExecuteCommand(command, callback) {
    exec(command, { timeout: 5000 }, (error, stdout, stderr) => {
        if (error) {
            console.error(`Command execution error: ${error}`);
            return callback(error, null);
        }
        callback(null, stdout);
    });
}

// Route to get host metrics
app.get('/api/host-metrics', (req, res) => {
    try {
        // Use a non-sudo method to get basic system metrics
        safeExecuteCommand('uptime', (err, result) => {
            if (err) {
                return res.status(500).json({ error: 'Could not retrieve host metrics' });
            }
            res.json({ hostMetrics: result.trim() });
        });
    } catch (error) {
        res.status(500).json({ error: 'Metrics retrieval failed' });
    }
});

// Route to get Docker metrics (if Docker is available)
app.get('/api/docker-metrics', (req, res) => {
    try {
        // Check Docker containers without sudo
        safeExecuteCommand('docker ps', (err, result) => {
            if (err) {
                return res.status(500).json({ error: 'Could not retrieve Docker metrics' });
            }
            res.json({ dockerContainers: result.trim().split('\n').slice(1) });
        });
    } catch (error) {
        res.status(500).json({ error: 'Docker metrics retrieval failed' });
    }
});

// Basic index route
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start the server
app.listen(port, host, () => {
    console.log(`Server running on http://${host}:${port}`);
});

// Optional: Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received. Shutting down gracefully');
    process.exit(0);
});
