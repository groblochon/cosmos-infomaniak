# Deployment Guide for Cosmos-Infomaniak

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Steps](#deployment-steps)
4. [Configuration](#configuration)
5. [Monitoring & Verification](#monitoring--verification)
6. [Troubleshooting](#troubleshooting)
7. [Rollback Procedures](#rollback-procedures)
8. [Support & Resources](#support--resources)

---

## Overview

This guide provides comprehensive instructions for deploying the Cosmos-Infomaniak project. The deployment process covers environment setup, configuration management, service deployment, and post-deployment verification.

### Deployment Environments
- **Development**: Local development environment
- **Staging**: Pre-production testing environment
- **Production**: Live production environment

---

## Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu 20.04 LTS or later recommended), macOS, or Windows with WSL2
- **CPU**: Minimum 2 cores, 4 cores recommended
- **RAM**: Minimum 4GB, 8GB recommended
- **Storage**: Minimum 10GB free space
- **Network**: Stable internet connection with appropriate firewall rules

### Required Software
- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 1.29 or later
- **Git**: Version 2.30 or later
- **Node.js**: Version 16.x or later (if required by project)
- **Python**: Version 3.8 or later (if required by project)
- **kubectl**: Version 1.20 or later (for Kubernetes deployments)

### Access Requirements
- GitHub repository access
- Infomaniak cloud credentials/API keys
- SSH keys for server access
- Required environment variables and secrets (see [Configuration](#configuration))

### Installation Commands

**Ubuntu/Debian:**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.0.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Git
sudo apt-get update && sudo apt-get install -y git
```

**macOS:**
```bash
# Using Homebrew
brew install docker docker-compose git
```

---

## Deployment Steps

### Step 1: Clone the Repository

```bash
git clone https://github.com/groblochon/cosmos-infomaniak.git
cd cosmos-infomaniak
```

### Step 2: Prepare Environment Variables

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your specific configuration
nano .env
```

Required environment variables:
- `ENVIRONMENT`: Set to `staging` or `production`
- `API_KEY`: Infomaniak API credentials
- `DATABASE_URL`: Database connection string
- `LOG_LEVEL`: Logging level (debug, info, warn, error)
- Additional service-specific variables (see Configuration section)

### Step 3: Build Docker Images

```bash
# Build all services
docker-compose build

# Or build specific service
docker-compose build service-name

# Optional: Push to registry
docker tag cosmos-infomaniak:latest your-registry/cosmos-infomaniak:latest
docker push your-registry/cosmos-infomaniak:latest
```

### Step 4: Database Migration

```bash
# Run database migrations
docker-compose run --rm app npm run migrate
# or for Python
docker-compose run --rm app python manage.py migrate

# Verify migration status
docker-compose run --rm app npm run migrate:status
```

### Step 5: Deploy Services

**Using Docker Compose:**
```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d service-name

# Check service status
docker-compose ps

# View logs
docker-compose logs -f service-name
```

**Using Kubernetes (if applicable):**
```bash
# Apply configuration
kubectl apply -f k8s/

# Check deployment status
kubectl rollout status deployment/cosmos-infomaniak

# Verify pods
kubectl get pods
```

### Step 6: Health Checks

```bash
# Check service health
curl http://localhost:3000/health
# Expected response: {"status": "healthy"}

# Check all services
docker-compose ps

# Verify database connectivity
docker-compose exec app npm run check:db
```

---

## Configuration

### Environment Variables

```env
# Application
ENVIRONMENT=production
APP_NAME=cosmos-infomaniak
APP_PORT=3000
APP_HOST=0.0.0.0

# Database
DATABASE_HOST=db.infomaniak.com
DATABASE_PORT=5432
DATABASE_USER=cosmos_user
DATABASE_PASSWORD=secure_password
DATABASE_NAME=cosmos_db

# API Configuration
INFOMANIAK_API_KEY=your-api-key-here
INFOMANIAK_API_SECRET=your-api-secret-here
INFOMANIAK_API_ENDPOINT=https://api.infomaniak.com/v1

# Logging & Monitoring
LOG_LEVEL=info
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id

# Security
JWT_SECRET=your-jwt-secret-key
CORS_ORIGIN=https://yourdomain.com

# Redis (if used for caching)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis_password

# Email Configuration
SMTP_HOST=smtp.infomaniak.com
SMTP_PORT=587
SMTP_USER=your-email@domain.com
SMTP_PASSWORD=your-email-password
```

### Secrets Management

**Using Docker Secrets (Production):**
```bash
# Create secrets
echo "your-secret-value" | docker secret create db_password -

# Reference in docker-compose.yml
secrets:
  db_password:
    external: true
```

**Using environment files:**
```bash
# Create separate .env files for each environment
.env.development
.env.staging
.env.production

# Load specific environment
docker-compose --env-file .env.production up -d
```

### Service Configuration Files

- `docker-compose.yml`: Main service orchestration
- `docker-compose.override.yml`: Development overrides
- `docker-compose.prod.yml`: Production-specific configuration
- `k8s/`: Kubernetes manifests (if applicable)

---

## Monitoring & Verification

### Health Checks

```bash
# Application health
curl -X GET http://localhost:3000/health

# Database connectivity
docker-compose exec app npm run check:db

# Service dependencies
docker-compose exec app npm run check:services
```

### Logging

```bash
# View application logs
docker-compose logs app

# View logs with timestamps
docker-compose logs --timestamps app

# Stream logs in real-time
docker-compose logs -f app

# View logs for specific time range
docker-compose logs --since 10m app
```

### Performance Monitoring

```bash
# Check container resource usage
docker stats

# Monitor system resources
docker-compose stats

# Review memory consumption
free -h

# Check disk usage
df -h
```

### Log Aggregation

Logs are typically aggregated in:
- `/var/log/cosmos-infomaniak/` (container logs)
- Sentry dashboard (error tracking)
- ELK Stack or similar (if configured)

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Service Won't Start

**Symptom**: Docker container exits immediately after starting

**Diagnosis:**
```bash
# Check logs
docker-compose logs app

# Check exit code
docker-compose ps
```

**Solutions:**
- Verify all environment variables are set correctly
- Check database connectivity
- Ensure all required ports are available
- Validate configuration files for syntax errors

**Example fix:**
```bash
# Validate environment variables
env | grep DATABASE
env | grep API

# Test database connection
nc -zv $DATABASE_HOST $DATABASE_PORT
```

#### 2. Database Connection Issues

**Symptom**: "Connection refused" or "Cannot connect to database"

**Diagnosis:**
```bash
# Check database service
docker-compose ps db

# Test connection
docker-compose exec app psql -h $DATABASE_HOST -U $DATABASE_USER -d $DATABASE_NAME -c "SELECT 1"
```

**Solutions:**
```bash
# Verify database credentials
echo $DATABASE_HOST $DATABASE_PORT $DATABASE_USER $DATABASE_NAME

# Check if database service is running
docker-compose up -d db

# Wait for database to be ready
docker-compose exec db pg_isready -U $DATABASE_USER

# Run migrations again
docker-compose run --rm app npm run migrate
```

#### 3. Port Already in Use

**Symptom**: "Address already in use" error

**Diagnosis:**
```bash
# Find process using port
lsof -i :3000
netstat -tulpn | grep 3000
```

**Solutions:**
```bash
# Stop conflicting service
docker-compose down

# Or use different port
PORT=3001 docker-compose up -d

# Or kill the process
kill -9 <PID>
```

#### 4. Memory Issues

**Symptom**: "Out of memory" errors, container killed

**Diagnosis:**
```bash
# Check memory usage
docker stats

# Check swap usage
free -h
```

**Solutions:**
```bash
# Increase Docker memory allocation
# Edit /etc/docker/daemon.json:
{
  "memory": "4g",
  "memory-swap": "4g"
}

# Restart Docker daemon
sudo systemctl restart docker

# Or adjust in docker-compose.yml
services:
  app:
    mem_limit: 2g
    memswap_limit: 2g
```

#### 5. Network Connectivity Issues

**Symptom**: Services can't communicate with each other

**Diagnosis:**
```bash
# Check network
docker network ls
docker network inspect cosmos_default

# Test connectivity between containers
docker-compose exec app ping db
```

**Solutions:**
```bash
# Rebuild network
docker-compose down
docker network prune
docker-compose up -d

# Check service DNS names
docker-compose exec app nslookup db
```

#### 6. Permission Denied Errors

**Symptom**: "Permission denied" when accessing files or sockets

**Diagnosis:**
```bash
# Check file permissions
ls -la docker.sock
ls -la /var/run/docker.sock
```

**Solutions:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Fix file permissions
sudo chown $USER:$USER docker.sock

# Or use sudo
sudo docker-compose up -d
```

#### 7. API Key/Authentication Issues

**Symptom**: "Unauthorized" or "Invalid credentials" errors

**Diagnosis:**
```bash
# Verify API key
echo $INFOMANIAK_API_KEY

# Test API connection
curl -H "Authorization: Bearer $INFOMANIAK_API_KEY" \
  https://api.infomaniak.com/v1/status
```

**Solutions:**
```bash
# Regenerate API keys in Infomaniak dashboard
# Update .env file
INFOMANIAK_API_KEY=new-key-here

# Restart services
docker-compose restart
```

#### 8. Disk Space Issues

**Symptom**: "No space left on device" errors

**Diagnosis:**
```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df
```

**Solutions:**
```bash
# Clean up Docker resources
docker system prune -a

# Remove old images
docker rmi $(docker images -q -f "dangling=true")

# Remove stopped containers
docker container prune

# Check and clear logs
docker exec <container> sh -c 'truncate -s 0 /var/log/*'
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Set debug environment variable
export LOG_LEVEL=debug

# Restart services
docker-compose restart

# Follow logs
docker-compose logs -f app
```

### Support Commands

```bash
# Get system information
docker version
docker info

# List all running containers
docker ps -a

# Show container configuration
docker inspect container-name

# Execute commands in container for debugging
docker-compose exec app bash
docker-compose exec app npm run debug

# Generate diagnostic bundle
docker-compose logs > diagnostic.log
docker stats --no-stream >> diagnostic.log
docker ps -a >> diagnostic.log
```

---

## Rollback Procedures

### Rollback to Previous Version

**Identify Previous Version:**
```bash
# Check image history
docker images | grep cosmos

# Check deployment history
git log --oneline

# Check Docker Compose history
git log --oneline docker-compose.yml
```

**Rollback Steps:**
```bash
# Stop current services
docker-compose down

# Checkout previous version
git checkout <previous-commit-hash>

# Rebuild images
docker-compose build

# Restart services
docker-compose up -d

# Run migrations (if needed)
docker-compose run --rm app npm run migrate
```

**Verify Rollback:**
```bash
# Check service status
docker-compose ps

# Verify functionality
curl http://localhost:3000/health

# Check logs for errors
docker-compose logs app
```

**Rollback Database (if necessary):**
```bash
# Stop services
docker-compose down

# Restore from backup
docker-compose run --rm db pg_restore -U $DATABASE_USER -d $DATABASE_NAME < backup.sql

# Restart services
docker-compose up -d
```

### Backup Before Deployment

```bash
# Backup database
docker-compose exec db pg_dump -U $DATABASE_USER $DATABASE_NAME > backup-$(date +%Y%m%d-%H%M%S).sql

# Backup configuration
cp .env .env.backup-$(date +%Y%m%d-%H%M%S)

# Backup entire data directory
tar -czf data-backup-$(date +%Y%m%d-%H%M%S).tar.gz ./data/
```

---

## Support & Resources

### Getting Help

1. **Check the Troubleshooting Section**: Most common issues are documented above
2. **Review Logs**: Always check application and system logs first
3. **GitHub Issues**: Search existing issues or create a new one
4. **Documentation**: Check README.md and other documentation files

### Useful Commands Reference

```bash
# Deployment
docker-compose up -d
docker-compose down
docker-compose build
docker-compose restart

# Debugging
docker-compose logs -f
docker-compose exec app bash
docker ps
docker stats

# Database
docker-compose run --rm app npm run migrate
docker-compose exec db psql -U user -d database

# Cleanup
docker system prune
docker rmi image-name
docker volume prune
```

### Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Infomaniak API Documentation](https://developer.infomaniak.com/)

### Contact & Escalation

For issues or questions:
1. Review this deployment guide
2. Check GitHub Issues
3. Contact the development team
4. Open an issue with detailed logs and system information

---

## Checklist for Production Deployment

- [ ] All prerequisites installed and verified
- [ ] Environment variables configured for production
- [ ] Database migrations completed successfully
- [ ] Database backups created
- [ ] Security credentials rotated
- [ ] SSL/TLS certificates installed
- [ ] Health checks passing
- [ ] Monitoring and logging configured
- [ ] Rollback plan documented and tested
- [ ] Load testing completed (if applicable)
- [ ] Team notified of deployment
- [ ] Deployment window scheduled
- [ ] Post-deployment verification plan ready
- [ ] On-call support assigned

---

**Last Updated**: 2025-12-28

**Document Version**: 1.0

For questions or updates to this guide, please open an issue or submit a pull request.
