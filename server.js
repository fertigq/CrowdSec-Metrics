const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const dotenv = require('dotenv');

const app = express();
const port = process.env.PORT || 3456;

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

// Start the server
app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});
