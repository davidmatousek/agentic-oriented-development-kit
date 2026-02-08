# Local Development Environment - {{PROJECT_NAME}}

**Last Updated**: {{CURRENT_DATE}}
**Owner**: DevOps Agent

---

## Prerequisites

### Required Software
- **Docker Desktop**: Version {{VERSION}}+
- **Node.js**: Version {{VERSION}} (LTS recommended)
- **Git**: Version {{VERSION}}+

### Optional Software
- **VS Code**: Recommended IDE
- **Postman/Insomnia**: API testing

---

## Quick Start

```bash
# Clone repository
git clone {{REPOSITORY_URL}}
cd {{PROJECT_NAME}}

# Install dependencies
npm install

# Start development environment
docker-compose up -d

# Run database migrations
npm run migrate

# Start development servers
npm run dev
```

---

## Docker Compose Services

```yaml
# docker-compose.yml structure
services:
  frontend:
    # Frontend development server with hot reload
    ports: ["{{FRONTEND_PORT}}:{{FRONTEND_PORT}}"]

  backend:
    # Backend API server
    ports: ["{{BACKEND_PORT}}:{{BACKEND_PORT}}"]

  database:
    # PostgreSQL (or your database)
    ports: ["{{DATABASE_PORT}}:{{DATABASE_PORT}}"]
```

---

## Environment Variables

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

**Required Variables**:
```
DATABASE_URL=postgresql://localhost:{{DATABASE_PORT}}/{{PROJECT_NAME}}_dev
API_URL=http://localhost:{{BACKEND_PORT}}
FRONTEND_URL=http://localhost:{{FRONTEND_PORT}}
```

---

## Common Commands

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f [service-name]

# Rebuild after changes
docker-compose up --build

# Reset database
docker-compose down -v
docker-compose up -d
npm run migrate
```

---

## Troubleshooting

### Port Already in Use
```bash
# Find process using port
lsof -i :{{PORT}}

# Kill process
kill -9 <PID>
```

### Database Connection Failed
```bash
# Check database is running
docker-compose ps

# Check logs
docker-compose logs database

# Reset database
docker-compose down -v && docker-compose up -d
```

### Hot Reload Not Working
- Ensure volumes are mounted correctly in docker-compose.yml
- Check file watcher limits (Linux: `sudo sysctl fs.inotify.max_user_watches=524288`)

---

**Template Instructions**: Replace all `{{TEMPLATE_VARIABLES}}` with your actual configuration.
