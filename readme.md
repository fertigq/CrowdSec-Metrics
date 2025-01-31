# 🛡️ **CrowdSec Metrics Dashboard**

A lightweight metrics visualization tool for CrowdSec installations that adds a touch of humor to your monitoring experience. It works with both host and Docker deployments.

## 🎯 **Project Purpose**

**Designed for CrowdSec users who need:**

- A combined view of host and Docker metrics without the overhead
- A quick, straightforward health check using simple monitoring tools

**Not designed for:**

- Enterprise-scale monitoring
- Long-term metric storage
- Replacing CrowdSec's native tools

## ⚙️ **Technical Overview**

Pulls metrics directly via:

1. `cscli metrics` for host installations
2. `docker exec` commands for containerized instances

No persistent data is stored, dependencies are kept to a minimum, and the resource footprint is very light.

## 📋 **Requirements**

- An operational CrowdSec instance (host or Docker)
- Node.js 16.x+
- Sudo access for host metrics collection
- Docker CLI for container metrics

## 🚀 **Deployment Guide**

```bash
# Clone repository
git clone https://github.com/yourusername/crowdsec-metrics-dashboard.git
cd crowdsec-metrics-dashboard

# Edit the installation script to bind to your specific IP
sed -i 's/HOST=0.0.0.0/HOST=YOURSERVERIP/' install.sh

# Review and run the installation script
cat install.sh
sudo ./install.sh

# Set permissions if needed
chmod +x *.sh

# Configure environment
cp example.env .env
nano .env  # Set your parameters

# Ensure the HOST is set to your IP
HOST=YOURSERVERIP

# Update the firewall rules to only allow access from your local network
sudo ufw allow from 10.10.10.0/24 to any port 3456 proto tcp

# Restart the service
sudo systemctl restart crowdsec-metrics
```

Access the dashboard at: `http://YOURSERVERIP:3456`

## ⚡ **Configuration Options**

Edit the `.env` file:

```env
CROWDSEC_CONTAINER=your_container_name  # Docker only
HOST_METRICS=true                       # Enable host metrics
DOCKER_METRICS=false                    # Toggle Docker metrics
PORT=3456                               # Web interface port
REFRESH_INTERVAL=30                     # Update frequency in seconds
```

## 📊 **Key Features**

- Real-time metric aggregation
- Cross-environment data correlation
- Mobile-responsive design
- Minimal CPU/memory usage
- Optional simple authentication support

## 🔒 **Security Advisory**

**Critical Considerations:**

- Runs with the same privileges as CrowdSec
- Exposes CrowdSec metric data via a web interface
- Requires sudo for host metric collection

**Recommended Practices:**

- Restrict access to trusted networks
- Use a reverse proxy with HTTPS
- Regularly review update logs
- Never run as the root user

## ⚠️ **Precautionary Warning**

- **No warranties whatsoever**

Tested only on my Ubuntu Server LTS.

**Production Use:** Not recommended for mission-critical systems. If deploying in sensitive environments, please:

1. Implement network isolation
2. Monitor resource usage closely

## 🔍 **Troubleshooting Guide**

| **Symptom**              | **Checks**                                                                                                                                                                           |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **No host metrics**      | Run `sudo cscli metrics` to verify that metrics are being collected. Also, check bouncer registration with `sudo cscli bouncers list`.                                               |
| **Docker connection issues** | Run `sudo docker exec crowdsec cscli bouncers list` to confirm connectivity. Also, check metrics directly with `sudo docker exec crowdsec cscli metrics`.                       |
| **Blank dashboard**      | 1. Inspect the browser console for JavaScript errors.<br>2. Verify your configuration settings.<br>3. View logs with `sudo tail -f logs/dashboard.log`.<br>4. Run `sudo cscli alerts list` to see if alerts are being generated. |

## 🤝 **Contribution Guidelines**

Contributions are welcome from developers of all experience levels. Please feel free to submit improvements, bug fixes, or suggestions.

## 📜 **Credits & Recognition**

**Essential Dependencies:**

- [CrowdSec](https://crowdsec.net/) – The core security platform
- The Node.js ecosystem – For the runtime environment

**Development Acknowledgement:**

This project is a work in progress. I'm still learning to code, so it will be far from perfect, especially since it’s powered by caffeine and mostly ChatGPT.

---

*This independent tool is not affiliated with CrowdSec. Use at your own risk.* 
