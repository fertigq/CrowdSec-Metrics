const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const dotenv = require('dotenv');

const app = express();
const port = process.env.PORT || 3456;

// Serve static files from the 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// Utility function for safe command execution
function executeCommand(command) {
    return new Promise((resolve, reject) => {
        exec(command, { timeout: 5000 }, (error, stdout, stderr) => {
            if (error) {
                console.error(`Command execution error: ${error}`);
                resolve({ error: true, message: error.message });
                return;
            }
            resolve({ 
                error: false, 
                output: stdout.trim() 
            });
        });
    });
}

// System Metrics Route
app.get('/api/system-metrics', async (req, res) => {
    try {
        const uptimeResult = await executeCommand('uptime');
        
        // More robust parsing of uptime
        const uptimeMatch = uptimeResult.output.match(/up\s+(.+?),\s+load average:\s+(.+)/);
        
        const metrics = {
            uptime: uptimeMatch ? uptimeMatch[1] : 'Unable to retrieve',
            loadAverage: uptimeMatch ? uptimeMatch[2] : 'Unable to retrieve'
        };

        res.json(metrics);
    } catch (error) {
        console.error('Error gathering system metrics:', error);
        res.status(500).json({ 
            error: true, 
            message: 'Failed to retrieve system metrics' 
        });
    }
});

// CrowdSec Metrics Route
app.get('/api/crowdsec-metrics', async (req, res) => {
    try {
        // Execute cscli metrics command
        const metricsResult = await executeCommand('docker exec crowdsec cscli metrics');
        
        // Parse the metrics to extract decision counts
        const decisionLines = metricsResult.output.split('\n')
            .filter(line => line.includes('crowdsecurity/'))
            .map(line => {
                const parts = line.trim().split(/\s+/);
                return {
                    reason: parts[0].replace('crowdsecurity/', ''),
                    count: parseInt(parts[parts.length - 1])
                };
            })
            .filter(item => item.count > 0)
            .sort((a, b) => b.count - a.count)
            .slice(0, 10); // Top 10 reasons

        // Prepare data for chart
        const labels = decisionLines.map(d => d.reason);
        const data = decisionLines.map(d => d.count);

        res.json({ labels, data });
    } catch (error) {
        console.error('Error fetching CrowdSec metrics:', error);
        res.status(500).json({ 
            error: true, 
            message: 'Failed to retrieve CrowdSec metrics' 
        });
    }
});

// Start the server
app.listen(port, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${port}`);
});
