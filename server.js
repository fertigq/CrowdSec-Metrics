const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const app = express();
const port = process.env.PORT || 3456;

// Serve static files from the 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// Utility function for safe command execution
function executeCommand(command, container = null) {
    return new Promise((resolve, reject) => {
        const fullCommand = container 
            ? `docker exec ${container} ${command}` 
            : command;
        
        exec(fullCommand, { timeout: 10000 }, (error, stdout, stderr) => {
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

// CrowdSec Metrics Route
app.get('/api/crowdsec-metrics', async (req, res) => {
    try {
        // Fetch local API decisions
        const decisionsResult = await executeCommand('cscli metrics show decisions', 'crowdsec');
        
        // Parse the metrics output
        const decisionLines = decisionsResult.output.split('\n')
            .slice(2, -3)  // Remove header and footer lines
            .map(line => {
                const parts = line.trim().split('|').map(p => p.trim());
                return {
                    reason: parts[0].replace('crowdsecurity/', ''),
                    origin: parts[1],
                    action: parts[2],
                    count: parseInt(parts[3])
                };
            })
            .filter(item => item.count > 0)
            .sort((a, b) => b.count - a.count)
            .slice(0, 10);  // Top 10 reasons

        // Prepare data for chart
        const metrics = {
            labels: decisionLines.map(d => d.reason),
            data: decisionLines.map(d => d.count),
            percentages: decisionLines.map(d => 
                ((d.count / decisionLines.reduce((sum, item) => sum + item.count, 0)) * 100).toFixed(2)
            )
        };

        res.json(metrics);
    } catch (error) {
        console.error('Error fetching CrowdSec metrics:', error);
        res.status(500).json({ 
            error: true, 
            message: 'Failed to retrieve CrowdSec metrics' 
        });
    }
});

// System Metrics Route (keeping previous implementation)
app.get('/api/system-metrics', async (req, res) => {
    try {
        const [uptimeResult, memoryResult, diskResult] = await Promise.all([
            executeCommand('uptime'),
            executeCommand('free -h'),
            executeCommand('df -h /')
        ]);
        
        // Parse uptime
        const uptimeMatch = uptimeResult.output.match(/up\s+(.+?),\s+\d+ users?,\s+load average:\s+(.+)/);
        
        // Parse memory
        const memoryLines = memoryResult.output.split('\n');
        const memoryInfo = memoryLines[1].split(/\s+/);
        
        // Parse disk
        const diskLine = diskResult.output.split('\n')[1].split(/\s+/);
        
        const metrics = {
            uptime: uptimeMatch ? uptimeMatch[1] : 'Unable to retrieve',
            loadAverage: uptimeMatch ? uptimeMatch[2] : 'Unable to retrieve',
            memory: {
                total: memoryInfo[1],
                used: memoryInfo[2],
                free: memoryInfo[3]
            },
            disk: {
                total: diskLine[1],
                used: diskLine[2],
                available: diskLine[3],
                usePercentage: diskLine[4]
            }
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
app.listen(port, '0.0.0.0', () => {
    console.log(`CrowdSec Metrics Dashboard running on http://0.0.0.0:${port}`);
});
