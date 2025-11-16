/**
 * Dashboard Page JavaScript
 * Handles real-time monitoring and display of API services
 */

// Polling configuration
const POLL_INTERVAL = 30000; // 30 seconds
let pollTimer = null;

/**
 * Initialize dashboard on page load
 */
document.addEventListener('DOMContentLoaded', () => {
  loadDashboard();
  startPolling();
});

/**
 * Load complete dashboard data
 */
async function loadDashboard() {
  showLoadingIndicator(true);

  try {
    // Load metrics and services in parallel
    await Promise.all([loadMetrics(), loadServices()]);
  } catch (error) {
    console.error('Dashboard load error:', error);
    showNotification('Failed to load dashboard', 'error');
  } finally {
    showLoadingIndicator(false);
  }
}

/**
 * Load and display metrics
 */
async function loadMetrics() {
  try {
    const response = await apiCall('/api/metrics');
    const metrics = response.data;

    // Update metric cards
    document.getElementById('totalServices').textContent = formatNumber(
      metrics.total_services
    );

    // Calculate healthy/unhealthy from success rate
    const totalChecks = metrics.total_checks || 0;
    const healthyChecks = metrics.healthy_checks || 0;
    const unhealthyChecks = metrics.unhealthy_checks || 0;

    document.getElementById('healthyServices').textContent =
      formatNumber(healthyChecks);
    document.getElementById('unhealthyServices').textContent =
      formatNumber(unhealthyChecks);
    document.getElementById('successRate').textContent = metrics.success_rate
      ? `${metrics.success_rate}%`
      : '0%';
  } catch (error) {
    console.error('Metrics load error:', error);
    // Set default values on error
    [
      'totalServices',
      'healthyServices',
      'unhealthyServices',
      'successRate',
    ].forEach((id) => {
      const el = document.getElementById(id);
      if (el) el.textContent = '0';
    });
  }
}

/**
 * Load and display services
 */
async function loadServices() {
  const loadingState = document.getElementById('loadingState');
  const emptyState = document.getElementById('emptyState');
  const servicesGrid = document.getElementById('servicesGrid');

  try {
    // Show loading
    loadingState.style.display = 'block';
    emptyState.style.display = 'none';
    servicesGrid.style.display = 'none';

    const response = await apiCall('/api/services');
    const services = response.data || [];

    // Hide loading
    loadingState.style.display = 'none';

    if (services.length === 0) {
      emptyState.style.display = 'block';
      return;
    }

    // Render services
    servicesGrid.style.display = 'grid';
    servicesGrid.innerHTML = services
      .map((service) => renderServiceCard(service))
      .join('');
  } catch (error) {
    console.error('Services load error:', error);
    loadingState.style.display = 'none';
    showError(servicesGrid, 'Failed to load services');
    servicesGrid.style.display = 'block';
  }
}

/**
 * Render a service card
 * @param {object} service - Service data
 * @returns {string} HTML for service card
 */
function renderServiceCard(service) {
  const status = service.current_status || 'healthy';
  const statusBadge = getStatusBadge(status);
  const lastCheck = formatDate(service.last_check);

  return `
    <div class="service-card">
      <div class="service-card-header">
        <div>
          <h3 class="service-name">${escapeHtml(service.name)}</h3>
          <p class="service-url">${escapeHtml(service.url)}</p>
        </div>
        ${statusBadge}
      </div>

      <div class="service-stats">
        <div class="stat-item">
          <span class="stat-label">Check Interval</span>
          <span class="stat-value">${service.check_interval}s</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Expected Status</span>
          <span class="stat-value">${service.expected_status}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Timeout</span>
          <span class="stat-value">${formatResponseTime(service.timeout)}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Last Checked</span>
          <span class="stat-value">${lastCheck}</span>
        </div>
      </div>

      <div class="service-actions">
        <button class="btn btn-small btn-secondary" onclick="checkServiceNow(${
          service.id
        })">
          🔄 Check Now
        </button>
        <a href="/services-page" class="btn btn-small btn-secondary">
          ✏️ Manage
        </a>
      </div>
    </div>
  `;
}

/**
 * Force immediate health check for a service
 * @param {number} serviceId - Service ID
 */
async function checkServiceNow(serviceId) {
  try {
    showNotification('Checking service...', 'info');

    const response = await apiCall(`/api/services/${serviceId}/check-now`, {
      method: 'POST',
    });

    showNotification('Health check completed!', 'success');

    // Reload dashboard to show updated status
    await loadDashboard();
  } catch (error) {
    console.error('Check service error:', error);
    showNotification('Health check failed', 'error');
  }
}

/**
 * Refresh entire dashboard
 */
async function refreshDashboard() {
  showNotification('Refreshing dashboard...', 'info');
  await loadDashboard();
  showNotification('Dashboard refreshed!', 'success');
}

/**
 * Start automatic polling
 */
function startPolling() {
  // Clear existing timer if any
  if (pollTimer) {
    clearInterval(pollTimer);
  }

  // Poll every 30 seconds
  pollTimer = setInterval(async () => {
    console.log('Auto-refreshing dashboard...');
    await loadDashboard();
  }, POLL_INTERVAL);
}

/**
 * Stop automatic polling
 */
function stopPolling() {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
}

/**
 * Show/hide loading indicator
 * @param {boolean} show - Whether to show indicator
 */
function showLoadingIndicator(show) {
  const indicator = document.getElementById('loadingIndicator');
  if (indicator) {
    indicator.style.display = show ? 'block' : 'none';
  }
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
  stopPolling();
});
