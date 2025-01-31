# 🛡️ CrowdSec Metrics Dashboard

A simple metrics dashboard that displays CrowdSec data from both your host machine and Docker container. Built to provide a straightforward alternative to more complex monitoring setups.

## 🎯 What This Is

This is an independent project that displays metrics from CrowdSec using native commands (`cscli` and `docker exec`). It's designed for users who:
- Run CrowdSec in Docker but have bouncers on their host machine
- Want to see metrics from both environments in one place
- Prefer a simple dashboard over setting up Grafana or other monitoring tools

This is NOT:
- An official CrowdSec product
- A replacement for CrowdSec's monitoring capabilities
- A comprehensive monitoring solution

## ⚙️ How It Works

The dashboard pulls metrics using:
- `cscli metrics` for host machine data
- `docker exec` commands for container data

No additional databases or complex setups required - it just reads and displays what CrowdSec already provides.

## 📋 Prerequisites

- CrowdSec installed (host, Docker, or both)
- Node.js 16+
- Basic familiarity with CrowdSec
- Sudo access (for host metrics)

## 🚀 Quick Start

1. Clone and enter the directory:
   ```bash
   git clone https://github.com/fertigq/crowdsec-metrics.git
   cd CrowdSec-Metrics
   ```

2. Set up configuration:
   ```bash
   cp example.env .env
   nano .env   # Add your settings
   ```

3. Start the dashboard:
   ```bash
   ./start.sh
   ```

4. Access at `http://your-ip:3456`

## ⚡ Configuration

Edit `.env` to set:
```bash
# Required
CROWDSEC_CONTAINER=your-crowdsec-container-name  # If using Docker
HOST_METRICS=true/false                         # Enable host metrics
DOCKER_METRICS=true/false                       # Enable Docker metrics

# Optional
PORT=3456                                       # Default port
REFRESH_INTERVAL=30                             # Seconds between updates
```

## 🔍 Troubleshooting

Common issues:

1. "Permission denied" for host metrics
   - Check sudo access
   - Verify cscli installation

2. Can't connect to Docker
   - Verify container name
   - Check Docker socket permissions

3. Dashboard shows no data
   - Confirm CrowdSec is running
   - Check logs: `tail -f logs/dashboard.log`

## 🔒 Security Notes

- The dashboard only reads metrics - it cannot modify your CrowdSec configuration
- Restrict dashboard access to trusted networks
- Use basic auth if exposed beyond localhost

## 🤝 Contributing

Issues and PRs welcome. Please:
1. Describe what you're trying to accomplish
2. Keep changes focused and simple
3. Test thoroughly

## 💌 Feedback

This is a work in progress. If you have suggestions or find bugs, please open an issue on GitHub.

## 🎨 Features

- Real-time metrics from both host and Docker
- Clean, simple interface
- Easy to set up and maintain
- Lightweight resource usage
- Mobile-friendly design

## 📊 What You Can Monitor

- Decisions and bouncers
- Top attacked IPs
- Alert trends
- Machine status
- Bouncer status

---
*🛡️ This is an independent project and is not affiliated with or endorsed by CrowdSec.*
