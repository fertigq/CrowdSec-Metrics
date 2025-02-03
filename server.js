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

// Function to safely execute commands
function safeExecuteCommand(command, callback) {
    exec(command, { timeout: 5000 }, (error, stdout, stderr) => {
        if (error) {
            console.error(`Command execution error: ${error}`);
            return callback(error, null);
        }
        callback(null, stdout);
    });
}

// Comprehensive metrics gathering
app.get('/api/metrics', async (req, res) => {
    try {
        // Host metrics
        const hostMetricsResult = await new Promise((resolve, reject) => {
            safeExecuteCommand('uptime', (err, result) => {
                if (err) reject(err);
                else resolve(result.trim());
            });
        });

        // Docker metrics
        const dockerMetricsResult = await new Promise((resolve, reject) => {
            safeExecuteCommand('docker ps', (err, result) => {
                if (err) reject(err);
                else resolve(result.trim().split('\n').slice(1));
            });
        });

        // CrowdSec metrics (if possible)
        const crowdSecMetrics = await new Promise((resolve) => {
            safeExecuteCommand('cscli metrics', (err, result) => {
                if (err) {
                    console.error('CrowdSec metrics retrieval failed');
                    resolve({ error: 'Could not retrieve CrowdSec metrics' });
                } else {
                    resolve(result.trim());
                }
            });
        });

        // Alerts (simulated for now)
        const alertsMetrics = await new Promise((resolve) => {
            safeExecuteCommand('cscli alerts list', (err, result) => {
                if (err) {
                    console.error('CrowdSec alerts retrieval failed');
                    resolve({ error: 'Could not retrieve alerts' });
                } else {
                    resolve(result.trim());
                }
            });
        });

        // Decisions (simulated for now)
        const decisionsMetrics = await new Promise((resolve) => {
            safeExecuteCommand('cscli decisions list', (err, result) => {
                if (err) {
                    console.error('CrowdSec decisions retrieval failed');
                    resolve({ error: 'Could not retrieve decisions' });
                } else {
                    resolve(result.trim());
                }
            });
        });

        res.json({
            host: JSON.stringify({ 
                'Load Average': hostMetricsResult.split('load average:')[1].trim(),
                'Uptime': hostMetricsResult.split(',')[0].trim()
            }),
            docker: JSON.stringify({
                'Total Containers': dockerMetricsResult.length,
                'Running Containers': dockerMetricsResult.filter(container => container.includes('Up')).length
            }),
            alerts: crowdSecMetrics,
            decisions: decisionsMetrics,
            bouncers: 'Bouncers information retrieval not implemented'
        });
    } catch (error) {
        console.error('Metrics retrieval failed:', error);
        res.status(500).json({ error: 'Could not retrieve metrics' });
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
