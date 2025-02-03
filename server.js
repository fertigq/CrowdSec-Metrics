const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const dotenv = require('dotenv');
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

// System Metrics Route
app.get('/api/system-metrics', async (req, res) => {
    try {
        // More comprehensive system metrics
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

// CrowdSec Metrics Route
app.get('/api/crowdsec-metrics', async (req, res) => {
    try {
        // More comprehensive metrics retrieval
        const metricsCommands = [
            { command: 'cscli metrics', container: 'crowdsec' },
            { command: 'cscli decisions list --output json', container: 'crowdsec' }
        ];

        const results = await Promise.all(
            metricsCommands.map(cmd => executeCommand(cmd.command, cmd.container))
        );

        // Parse metrics
        let metrics = { 
            overallBlocks: 0,
            topDecisions: [],
            decisionDetails: []
        };

        // Parse overall metrics
        const metricsOutput = results[0].output || '';
        const decisionListOutput = results[1].output || '[]';

        // Extract overall block counts from metrics
        const blockLines = metricsOutput.split('\n')
            .filter(line => line.includes('crowdsecurity/') && line.includes('block'));
        
        blockLines.forEach(line => {
            const parts = line.trim().split(/\s+/);
            const reason = parts[0].replace('crowdsecurity/', '');
            const count = parseInt(parts[parts.length - 1]);
            
            metrics.overallBlocks += count;
            metrics.topDecisions.push({ 
                reason, 
                count,
                percentage: 0 // Will calculate later
            });
        });

        // Sort and trim top decisions
        metrics.topDecisions.sort((a, b) => b.count - a.count);
        metrics.topDecisions = metrics.topDecisions.slice(0, 5);

        // Calculate percentages
        const totalBlocks = metrics.topDecisions.reduce((sum, decision) => sum + decision.count, 0);
        metrics.topDecisions.forEach(decision => {
            decision.percentage = ((decision.count / totalBlocks) * 100).toFixed(2);
        });

        // Parse detailed decisions
        try {
            const decisions = JSON.parse(decisionListOutput);
            metrics.decisionDetails = decisions.map(dec => ({
                ip: dec.ip,
                reason: dec.type,
                duration: dec.duration,
                country: dec.country || 'Unknown'
            })).slice(0, 10);  // Limit to top 10
        } catch (parseError) {
            console.error('Error parsing decisions:', parseError);
        }

        // Prepare data for chart
        const chartData = {
            labels: metrics.topDecisions.map(d => d.reason),
            data: metrics.topDecisions.map(d => d.count),
            percentages: metrics.topDecisions.map(d => d.percentage)
        };

        res.json(chartData);
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
    console.log(`CrowdSec Metrics Dashboard running on http://0.0.0.0:${port}`);
});
