# CrowdSec Metrics Dashboard

A sleek, real-time dashboard for monitoring CrowdSec metrics across both host machines and Docker containers. Visualize your security data with easy-to-read graphs and alerts.

## ⚠️ Important Disclaimer

**PLEASE READ CAREFULLY BEFORE USING THIS SOFTWARE**

This software was developed with the assistance of AI tools:
- It has not undergone extensive professional security auditing
- Testing has been limited to basic functionality
- Use in production environments should be carefully considered

**By using this software, you acknowledge and accept that:**
- You use this software at your own risk
- The creators assume no liability for any damages or security issues
- No warranties or guarantees are provided, either express or implied

## 🚀 Features

- Real-time metrics visualization
- Host and Docker container monitoring
- Customizable dashboard layouts
- Alert configuration
- Data export capabilities
- Mobile-responsive design

## 📋 Prerequisites

- CrowdSec installed and running
- Node.js 16 or higher
- Docker (optional, for containerized deployment)
- Modern web browser
- Sudo privileges for installation

## 🛠️ Installation

### Standard Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/fertigq/CrowdSec-Metrics.git
   cd crowdsec-metrics-dashboard
   ```

2. Review and execute the installation script:
   ```bash
   cat install.sh  # Review the script first
   sudo ./install.sh
   ```

3. Configure the environment:
   ```bash
   sudo nano /opt/crowdsec-metrics/.env
   ```

4. Start the service:
   ```bash
   sudo systemctl restart crowdsec-metrics
   ```

### Docker Installation

```bash
docker pull yourusername/crowdsec-metrics-dashboard
docker run -d -p 3456:3456 \
  -v /path/to/config:/app/config \
  --name crowdsec-dashboard \
  yourusername/crowdsec-metrics-dashboard
```

## 🔒 Security Features

- Non-root user execution
- Network access restrictions
- Rate limiting
- Basic authentication
- Input validation
- Regular security updates

### Security Recommendations

1. Set up a reverse proxy with HTTPS
2. Use strong passwords for dashboard access
3. Regularly update the software
4. Monitor system logs
5. Restrict network access to trusted IPs

## ⚙️ Configuration

The dashboard can be configured through the `.env` file:

```ini
PORT=3456
AUTH_ENABLED=true
ADMIN_USERNAME=admin
ADMIN_PASSWORD=your-secure-password
LOG_LEVEL=info
METRICS_RETENTION_DAYS=30
```

## 🔍 Troubleshooting

### View Logs
```bash
sudo journalctl -u crowdsec-metrics
```

### Common Issues

1. Dashboard Not Loading
   - Check service status: `systemctl status crowdsec-metrics`
   - Verify port availability: `netstat -tulpn | grep 3456`
   - Check firewall settings

2. Authentication Issues
   - Verify credentials in .env file
   - Clear browser cache
   - Check logs for auth errors

3. No Metrics Showing
   - Confirm CrowdSec is running
   - Check API connectivity
   - Verify metrics collection service

## 📊 Usage Examples

1. Basic Monitoring
   ```bash
   http://your-server-ip:3456/dashboard
   ```

2. API Access
   ```bash
   curl -X GET http://your-server-ip:3456/api/metrics \
     -H "Authorization: Bearer your-token"
   ```
