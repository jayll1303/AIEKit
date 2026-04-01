# MLflow Server Setup

Detailed guide for deploying an MLflow tracking server, covering backend store options, artifact store configuration, Docker Compose deployment, and nginx reverse proxy for production access.

## Backend Store Options

The backend store holds experiment metadata (runs, parameters, metrics, tags).

### SQLite (Solo / Development)

```bash
# Simplest setup — single file database
mlflow server \
  --backend-store-uri sqlite:///mlflow.db \
  --default-artifact-root ./mlflow-artifacts \
  --host 0.0.0.0 \
  --port 5000
```

- **Pros**: Zero setup, single file, easy backup (`cp mlflow.db mlflow.db.bak`)
- **Cons**: No concurrent write access, not suitable for team use
- **When**: Local development, solo experiments, quick prototyping

### PostgreSQL (Team / Production)

```bash
# Requires a running PostgreSQL instance
mlflow server \
  --backend-store-uri postgresql://mlflow:password@localhost:5432/mlflow \
  --default-artifact-root s3://mlflow-artifacts/ \
  --host 0.0.0.0 \
  --port 5000
```

**PostgreSQL setup**:

```sql
-- Create database and user
CREATE USER mlflow WITH PASSWORD 'mlflow';
CREATE DATABASE mlflow OWNER mlflow;
GRANT ALL PRIVILEGES ON DATABASE mlflow TO mlflow;
```

- **Pros**: Concurrent access, ACID transactions, production-grade, easy backup with `pg_dump`
- **Cons**: Requires PostgreSQL infrastructure
- **When**: Team environments, production deployments, >100 runs

### MySQL (Alternative)

```bash
mlflow server \
  --backend-store-uri mysql+pymysql://mlflow:password@localhost:3306/mlflow \
  --default-artifact-root s3://mlflow-artifacts/ \
  --host 0.0.0.0 \
  --port 5000
```

Install driver: `pip install pymysql`

## Artifact Store Options

The artifact store holds large files (model checkpoints, datasets, plots).

### Local Filesystem

```bash
mlflow server \
  --backend-store-uri sqlite:///mlflow.db \
  --default-artifact-root ./mlflow-artifacts \
  --host 0.0.0.0 \
  --port 5000
```

- Artifacts stored in `./mlflow-artifacts/<experiment_id>/<run_id>/artifacts/`
- Simple backup: `rsync` or `tar` the directory
- Not suitable for distributed teams (no remote access to artifacts)

### S3-Compatible (MinIO, AWS S3)

```bash
# Set S3 credentials
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
export MLFLOW_S3_ENDPOINT_URL=http://localhost:9000  # For MinIO

mlflow server \
  --backend-store-uri postgresql://mlflow:mlflow@localhost:5432/mlflow \
  --default-artifact-root s3://mlflow-artifacts/ \
  --host 0.0.0.0 \
  --port 5000
```

**MinIO setup** (selfhosted S3):

```bash
# Run MinIO
docker run -d \
  --name minio \
  -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin \
  -e MINIO_ROOT_PASSWORD=minioadmin \
  -v minio-data:/data \
  minio/minio server /data --console-address ":9001"

# Create bucket
docker exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
docker exec minio mc mb local/mlflow-artifacts
```

- **Pros**: Scalable, remote access, versioning, lifecycle policies
- **Cons**: Requires S3-compatible storage infrastructure
- **When**: Team environments, large artifacts, production deployments

### Google Cloud Storage

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

mlflow server \
  --backend-store-uri postgresql://mlflow:mlflow@localhost:5432/mlflow \
  --default-artifact-root gs://mlflow-artifacts/ \
  --host 0.0.0.0 \
  --port 5000
```

Install: `pip install google-cloud-storage`

## Docker Compose — Full Production Stack

```yaml
# docker-compose.yml
services:
  mlflow:
    image: ghcr.io/mlflow/mlflow:v2.16.0
    command: >
      mlflow server
      --backend-store-uri postgresql://mlflow:mlflow@postgres:5432/mlflow
      --default-artifact-root s3://mlflow-artifacts/
      --host 0.0.0.0
      --port 5000
    ports:
      - "5000:5000"
    environment:
      - AWS_ACCESS_KEY_ID=minioadmin
      - AWS_SECRET_ACCESS_KEY=minioadmin
      - MLFLOW_S3_ENDPOINT_URL=http://minio:9000
    depends_on:
      postgres:
        condition: service_healthy
      minio:
        condition: service_started
    restart: unless-stopped

  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: mlflow
      POSTGRES_PASSWORD: mlflow
      POSTGRES_DB: mlflow
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U mlflow"]
      interval: 5s
      retries: 5
    restart: unless-stopped

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - miniodata:/data
    restart: unless-stopped

volumes:
  pgdata:
  miniodata:
```

### First-time setup

```bash
# Start the stack
docker compose up -d

# Wait for services to be healthy
docker compose ps

# Create the MinIO bucket
docker compose exec minio mc alias set local http://localhost:9000 minioadmin minioadmin
docker compose exec minio mc mb local/mlflow-artifacts

# Verify MLflow is running
curl http://localhost:5000/health
```

## Nginx Reverse Proxy

For production access with HTTPS and basic authentication.

### nginx.conf

```nginx
upstream mlflow {
    server 127.0.0.1:5000;
}

server {
    listen 443 ssl;
    server_name mlflow.your-domain.com;

    ssl_certificate /etc/letsencrypt/live/mlflow.your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mlflow.your-domain.com/privkey.pem;

    # Basic authentication
    auth_basic "MLflow Tracking";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://mlflow;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (for MLflow UI)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Increase upload size for artifacts
    client_max_body_size 500M;
}

server {
    listen 80;
    server_name mlflow.your-domain.com;
    return 301 https://$host$request_uri;
}
```

### Create htpasswd file

```bash
sudo apt-get install apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd mlflow-user
```

### Client configuration with auth

```python
import mlflow
import os

os.environ["MLFLOW_TRACKING_URI"] = "https://mlflow.your-domain.com"
os.environ["MLFLOW_TRACKING_USERNAME"] = "mlflow-user"
os.environ["MLFLOW_TRACKING_PASSWORD"] = "your-password"

mlflow.set_experiment("my-experiment")
```

## Backup Strategies

### PostgreSQL Backup

```bash
# Dump database
docker compose exec postgres pg_dump -U mlflow mlflow > mlflow_backup.sql

# Restore
docker compose exec -T postgres psql -U mlflow mlflow < mlflow_backup.sql
```

### MinIO / Artifact Backup

```bash
# Mirror artifacts to local directory
docker compose exec minio mc mirror local/mlflow-artifacts /backup/mlflow-artifacts

# Or use mc cp for specific experiments
docker compose exec minio mc cp --recursive local/mlflow-artifacts/1/ /backup/experiment-1/
```

### SQLite Backup

```bash
# Simple file copy (stop server first for consistency)
cp mlflow.db mlflow.db.bak

# Or use sqlite3 backup command (online backup)
sqlite3 mlflow.db ".backup mlflow_backup.db"
```
