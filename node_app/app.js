require('dotenv').config();
const express = require('express');
const path = require('path');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');

// Configuration
const { testConnection, initializeDatabase } = require('./config/database');
const { connectRedis } = require('./config/redis');

// Routes
const serviceRoutes = require('./routes/serviceRoutes');
const systemRoutes = require('./routes/systemRoutes');

// Middleware
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware - Configure CSP for inline scripts and styles
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'", "'unsafe-eval'"],
        scriptSrcAttr: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:'],
        connectSrc: ["'self'"],
        upgradeInsecureRequests: null, // Disable automatic HTTPS upgrade
      },
    },
    hsts: false, // Disable HSTS to allow HTTP access
  })
);

// CORS configuration
app.use(
  cors({
    origin: process.env.CORS_ORIGIN || '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  })
);

// Body parser middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging middleware
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined'));
}

// Serve static files from public directory
app.use(express.static(path.join(__dirname, 'public')));

// Serve HTML pages
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'index.html'));
});

app.get('/dashboard', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'index.html'));
});

app.get('/services-page', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'services.html'));
});

app.get('/team', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'team.html'));
});

// API Routes (prefixed with /api)
app.use('/api/services', serviceRoutes);
app.use('/api', systemRoutes);

// API Documentation endpoint
app.get('/api-docs', (req, res) => {
  res.json({
    name: 'API Health Dashboard - Documentation',
    version: '1.0.0',
    endpoints: [
      {
        method: 'GET',
        path: '/services',
        description: 'List all monitored services with current status (CACHED)',
        response: 'Array of services with status information',
      },
      {
        method: 'POST',
        path: '/services',
        description: 'Add a new service to monitor',
        body: {
          name: 'string (required)',
          url: 'string (required, valid HTTP/HTTPS URL)',
          check_interval: 'number (optional, default: 300 seconds)',
          expected_status: 'number (optional, default: 200)',
          timeout: 'number (optional, default: 5000 milliseconds)',
        },
      },
      {
        method: 'GET',
        path: '/services/:id',
        description: 'Get specific service details',
        response: 'Service object with current status',
      },
      {
        method: 'PUT',
        path: '/services/:id',
        description: 'Update an existing service',
        body: {
          name: 'string (optional)',
          url: 'string (optional)',
          check_interval: 'number (optional)',
          expected_status: 'number (optional)',
          timeout: 'number (optional)',
        },
      },
      {
        method: 'DELETE',
        path: '/services/:id',
        description: 'Remove a service from monitoring',
        response: 'Success confirmation',
      },
      {
        method: 'GET',
        path: '/services/:id/status',
        description: 'Get current status of specific service',
        response: 'Current health status (cached or fresh)',
      },
      {
        method: 'POST',
        path: '/services/:id/check-now',
        description: 'Force immediate health check (bypass cache)',
        response: 'Fresh health check result',
      },
      {
        method: 'GET',
        path: '/health',
        description: 'Application health check',
        response: 'System health status including database and Redis',
      },
      {
        method: 'GET',
        path: '/metrics',
        description: 'Basic metrics about checks performed',
        response: 'Statistics about total checks, success rate, etc.',
      },
      {
        method: 'POST',
        path: '/check-all',
        description: 'Trigger health checks for all services',
        response: 'Results of all health checks',
      },
    ],
  });
});

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

/**
 * Initialize application
 */
const initializeApp = async () => {
  try {
    console.log('🚀 Starting API Health Dashboard...');

    // Test MySQL connection
    const dbConnected = await testConnection();
    if (!dbConnected) {
      throw new Error('Failed to connect to MySQL database');
    }

    // Initialize database tables
    await initializeDatabase();

    // Connect to Redis
    const redisConnected = await connectRedis();
    if (!redisConnected) {
      console.warn('⚠️  Redis connection failed - caching will be disabled');
    }

    console.log('✅ Application initialized successfully');
  } catch (error) {
    console.error('❌ Application initialization failed:', error.message);
    process.exit(1);
  }
};

/**
 * Start server
 */
const startServer = async () => {
  await initializeApp();

  app.listen(PORT, () => {
    console.log(`\n🎯 API Health Dashboard is running`);
    console.log(`📍 Port: ${PORT}`);
    console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`📊 Metrics: http://localhost:${PORT}/metrics`);
    console.log(`💚 Health: http://localhost:${PORT}/health`);
    console.log(`📚 API Docs: http://localhost:${PORT}/api-docs`);
    console.log('\n✨ Ready to monitor your APIs!\n');
  });
};

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});

// Start the server
if (require.main === module) {
  startServer();
}

module.exports = app;
