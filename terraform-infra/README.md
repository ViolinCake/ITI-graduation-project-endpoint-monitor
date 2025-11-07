# 🎯 API Health Dashboard

A production-ready Node.js application for monitoring external API endpoints with full CRUD operations, MySQL persistence, Redis caching, and a beautiful vanilla JavaScript frontend.

## 🚀 Features

### Backend

- ✅ **Full CRUD Operations** - Create, Read, Update, Delete services
- 💾 **MySQL Database** - Persistent storage of service configurations and health check history
- ⚡ **Redis Caching** - Fast response times with intelligent cache management
- 🔄 **Automatic Health Checks** - Configurable intervals for each service
- 📊 **Metrics & Analytics** - Track success rates and performance
- 🐳 **Docker Ready** - Full containerization with docker-compose
- ☸️ **Kubernetes Ready** - Cloud-native architecture
- 🔒 **Production Security** - Helmet, CORS, input validation

### Frontend

- 🎨 **Modern UI** - Clean, responsive vanilla JavaScript interface
- 📱 **Mobile Responsive** - Works perfectly on all devices
- 🔄 **Real-time Updates** - Auto-refresh every 30 seconds
- 👥 **Team Page** - Professional team member showcase
- 🎯 **Dashboard** - Live monitoring with status indicators
- ⚙️ **Service Management** - Easy-to-use CRUD interface
- 🎭 **No Frameworks** - Pure HTML, CSS, and JavaScript

## 📋 Prerequisites

- Node.js 18 or higher
- MySQL 8.0
- Redis 7.x
- Docker & Docker Compose (optional)

## 🛠️ Installation

### Option 1: Local Development

1. **Clone and install dependencies:**

```bash
npm install
```

2. **Configure environment:**

```bash
cp .env.example .env
# Edit .env with your database credentials
```

3. **Start MySQL and Redis** (or use Docker)

4. **Run the application:**

```bash
npm start
# or for development with auto-reload
npm run dev
```

### Option 2: Docker (Recommended)

```bash
# Start all services (MySQL, Redis, App)
docker-compose up -d

# View logs
docker-compose logs -f app

# Stop all services
docker-compose down
```

The application will be available at:

- **Frontend**: http://localhost:3000
- **Dashboard**: http://localhost:3000/
- **Services**: http://localhost:3000/services-page
- **Team**: http://localhost:3000/team
- **API**: http://localhost:3000/api

## 🌐 Application Pages

### 1. Dashboard (`/`)

- Real-time service status overview
- Health metrics and statistics
- Service cards with current status
- Auto-refresh every 30 seconds
- Quick actions for each service

### 2. Services Management (`/services-page`)

- Complete service listing in table format
- Add new services with validation
- Edit existing service configurations
- Delete services with confirmation
- View detailed service status

### 3. Team Page (`/team`)

- Professional team member showcase
- 5 team members with roles and bios
- Contact information (email, GitHub)
- Responsive card layout

## 📡 API Endpoints

### Service Management

| Method | Endpoint | Description |
| --- | --- | --- |
| `GET` | `/services` | List all services with status (cached) |
| `POST` | `/services` | Add new service to monitor |
| `GET` | `/services/:id` | Get specific service details |
| `PUT` | `/services/:id` | Update existing service |
| `DELETE` | `/services/:id` | Remove service |
| `GET` | `/services/:id/status` | Get current service status |
| `POST` | `/services/:id/check-now` | Force immediate health check |

### System Endpoints

| Method | Endpoint     | Description              |
| ------ | ------------ | ------------------------ |
| `GET`  | `/health`    | Application health check |
| `GET`  | `/metrics`   | Dashboard metrics        |
| `POST` | `/check-all` | Check all services now   |
| `GET`  | `/api-docs`  | API documentation        |

## 💡 Usage Examples

### Create a Service

```bash
curl -X POST http://localhost:3000/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "GitHub API",
    "url": "https://api.github.com",
    "check_interval": 60,
    "expected_status": 200,
    "timeout": 5000
  }'
```

### Update a Service

```bash
curl -X PUT http://localhost:3000/services/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "GitHub API v2",
    "check_interval": 120
  }'
```

### Get Service Status

```bash
curl http://localhost:3000/services/1/status
```

### Force Health Check

```bash
curl -X POST http://localhost:3000/services/1/check-now
```

### Delete a Service

```bash
curl -X DELETE http://localhost:3000/services/1
```

## 🗄️ Database Schema

### Services Table

```sql
CREATE TABLE services (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  url VARCHAR(500) NOT NULL,
  check_interval INT DEFAULT 300,
  expected_status INT DEFAULT 200,
  timeout INT DEFAULT 5000,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Health Checks Table

```sql
CREATE TABLE health_checks (
  id INT AUTO_INCREMENT PRIMARY KEY,
  service_id INT,
  status_code INT,
  response_time FLOAT,
  is_healthy BOOLEAN,
  error_message TEXT,
  checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (service_id) REFERENCES services(id)
);
```

## 📦 Redis Cache Structure

- `service_status:{id}` - Individual service status (TTL: check_interval)
- `service_list` - Cached list of all services (TTL: 60s)
- `service_metrics` - Dashboard metrics (TTL: 60s)

## 🔧 Configuration

### Environment Variables

| Variable      | Description       | Default              |
| ------------- | ----------------- | -------------------- |
| `PORT`        | Application port  | 3000                 |
| `NODE_ENV`    | Environment       | development          |
| `DB_HOST`     | MySQL host        | localhost            |
| `DB_USER`     | MySQL user        | root                 |
| `DB_PASSWORD` | MySQL password    | -                    |
| `DB_NAME`     | Database name     | api_health_dashboard |
| `REDIS_HOST`  | Redis host        | localhost            |
| `REDIS_PORT`  | Redis port        | 6379                 |
| `CACHE_TTL`   | Default cache TTL | 300                  |

## 🏗️ Project Structure

```
.
├── app.js                      # Main application file
├── config/
│   ├── database.js            # MySQL configuration
│   └── redis.js               # Redis configuration
├── models/
│   ├── serviceModel.js        # Service data model
│   └── healthCheckModel.js    # Health check data model
├── services/
│   └── healthCheckService.js  # Health check business logic
├── routes/
│   ├── serviceRoutes.js       # Service endpoints
│   └── systemRoutes.js        # System endpoints
├── middleware/
│   ├── validation.js          # Request validation
│   └── errorHandler.js        # Error handling
├── Dockerfile                 # Container definition
├── docker-compose.yml         # Multi-container setup
└── package.json               # Dependencies
```

## 🚢 Deployment

### Docker

```bash
docker build -t api-health-dashboard .
docker run -p 3000:3000 \
  -e DB_HOST=your-mysql-host \
  -e REDIS_HOST=your-redis-host \
  api-health-dashboard
```

### Kubernetes

Deploy using the provided Kubernetes manifests (create deployment.yaml and service.yaml for your cluster).

## 🧪 Testing

```bash
# Test health endpoint
curl http://localhost:3000/health

# Test metrics
curl http://localhost:3000/metrics

# View API documentation
curl http://localhost:3000/api-docs
```

## 🔐 Security Features

- **Helmet.js** - Security headers
- **CORS** - Cross-origin resource sharing
- **Input Validation** - Joi schema validation
- **SQL Injection Prevention** - Parameterized queries
- **Non-root Docker User** - Container security
- **Environment Variables** - No hardcoded secrets

## 📊 Monitoring

The application provides:

- Real-time health status of all monitored services
- Historical health check data
- Success/failure metrics
- Response time tracking
- Application health endpoint for orchestrators

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

ISC

## 👨‍💻 Author

Created for graduation project - DevOps Pipeline Integration

---

**Built with ❤️ using Node.js, Express, MySQL, and Redis**
