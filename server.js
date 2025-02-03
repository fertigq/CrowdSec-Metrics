const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const dotenv = require('dotenv');

const app = express();
const port = process.env.PORT || 3456;

// Load environment variables
dotenv.config();

// Serve static files from the 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// Root route to serve index.html
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

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

// Comprehensive system metrics gathering
app.get('/api/system-metrics', async (req, res) => {
    try {
        // Uptime and Load Average
        const uptimeResult = await executeCommand('uptime');
        
        // CPU Usage
        const cpuResult = await executeCommand('top -bn1 | grep "Cpu(s)"');
        
        // Memory Usage
        const memoryResult = await executeCommand('free -h');
        
        // Disk Usage
        const diskResult = await executeCommand('df -h /');
        
        // Network Connections
        const networkResult = await executeCommand('ss -tuln');

        // Detailed system information
        const systemInfoResult = await executeCommand('uname -a');

        // Parse uptime result more robustly
        const uptimeMatch = uptimeResult.output.match(/up\s+(.+?),\s+load average:\s+(.+)/);
        
        const metrics = {
            uptime: uptimeMatch ? uptimeMatch[1] : 'Unable to retrieve',
            loadAverage: uptimeMatch ? uptimeMatch[2] : 'Unable to retrieve',
            cpu: cpuResult.output || 'Unable to retrieve CPU usage',
            memory: memoryResult.output || 'Unable to retrieve memory info',
            disk: diskResult.output || 'Unable to retrieve disk usage',
            network: networkResult.output || 'Unable to retrieve network connections',
            systemInfo: systemInfoResult.output || 'Unable to retrieve system info'
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

// CrowdSec Metrics
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
                    reason: parts[0],
                    count: parseInt(parts[parts.length - 1])
                };
            });

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

// Docker Metrics
app.get('/api/docker-metrics', async (req, res) => {
    try {
        const containersResult = await executeCommand('docker ps');
        res.json({ 
            containers: containersResult.output 
        });
    } catch (error) {
        console.error('Error fetching Docker metrics:', error);
        res.status(500).json({ 
            error: true, 
            message: 'Failed to retrieve Docker metrics' 
        });
    }
});

// Start the server
app.listen(port, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${port}`);
});
