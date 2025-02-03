import type React from "react"
import { useState, useEffect } from "react"
import { Bar } from "react-chartjs-2"
import { Chart as ChartJS, CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend } from "chart.js"

ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend)

interface Metrics {
  host: string
  docker: string
}

const App: React.FC = () => {
  const [metrics, setMetrics] = useState<Metrics | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchMetrics = async () => {
      try {
        const response = await fetch("/api/metrics")
        if (!response.ok) {
          throw new Error("Failed to fetch metrics")
        }
        const data = await response.json()
        setMetrics(data)
      } catch (err) {
        setError("Failed to fetch metrics")
        console.error(err)
      }
    }

    fetchMetrics()
    const interval = setInterval(fetchMetrics, 300000) // Update every 5 minutes

    return () => clearInterval(interval)
  }, [])

  const parseMetrics = (metricsString: string) => {
    const lines = metricsString.split("\n")
    const data = lines.slice(1).map((line) => {
      const [reason, , , count] = line.split("|").map((s) => s.trim())
      return { reason, count: Number.parseInt(count, 10) }
    })
    return data
  }

  const chartData = (metricsData: any[]) => ({
    labels: metricsData.map((d) => d.reason),
    datasets: [
      {
        label: "Count",
        data: metricsData.map((d) => d.count),
        backgroundColor: "rgba(75, 192, 192, 0.6)",
      },
    ],
  })

  const chartOptions = {
    responsive: true,
    plugins: {
      legend: {
        position: "top" as const,
        labels: {
          color: "#e0e0e0",
        },
      },
      title: {
        display: true,
        text: "CrowdSec Metrics",
        color: "#e0e0e0",
      },
    },
    scales: {
      x: {
        ticks: { color: "#e0e0e0" },
        grid: { color: "#333333" },
      },
      y: {
        ticks: { color: "#e0e0e0" },
        grid: { color: "#333333" },
      },
    },
  }

  if (error) {
    return <div className="error">{error}</div>
  }

  if (!metrics) {
    return <div className="loading">Loading...</div>
  }

  const hostData = parseMetrics(metrics.host)
  const dockerData = parseMetrics(metrics.docker)

  return (
    <div className="App">
      <h1>CrowdSec Metrics Dashboard</h1>
      <div className="chart-container">
        <h2>Host Metrics</h2>
        <Bar data={chartData(hostData)} options={chartOptions} />
      </div>
      <div className="chart-container">
        <h2>Docker Metrics</h2>
        <Bar data={chartData(dockerData)} options={chartOptions} />
      </div>
    </div>
  )
}

export default App

