# Add this function to your script
create_index_html() {
    cat > "${APP_DIR}/index.html" << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CrowdSec Metrics Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
        h1 { color: #333; }
        #metrics { white-space: pre-wrap; background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>CrowdSec Metrics Dashboard</h1>
    <div id="metrics">Loading metrics...</div>
    <script>
        function fetchMetrics() {
            fetch('/metrics')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('metrics').textContent = data.metrics;
                })
                .catch(error => {
                    document.getElementById('metrics').textContent = 'Error fetching metrics: ' + error;
                });
        }
        fetchMetrics();
        setInterval(fetchMetrics, 60000); // Refresh every minute
    </script>
</body>
</html>
EOL
    log_success "Created index.html"
}

# Call this function in your main installation function
create_index_html

