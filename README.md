# Custom Mem0 MCP Server

A production-ready custom [Mem0](https://mem0.ai/) implementation with [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) support, allowing AI agents and applications to maintain persistent memories.

## 🚀 What This Project Does

This project provides a **custom memory service** that:

- **Persistent Memory Management**: Store, retrieve, update, and delete memories for users and AI agents
- **MCP Integration**: Exposes memory operations as MCP tools and resources for seamless integration with AI agents
- **Multiple Backend Support**: Choose between Neo4j (graph-based) or Qdrant (vector-based) for memory storage
- **Production Ready**: Containerized with Docker, health checks, proper logging, and graceful shutdown
- **Development Friendly**: Hot reload, comprehensive testing, and debugging tools

### Core Features

- 🧠 **Memory Operations**: Add, search, update, delete memories
- 🔗 **Graph Relationships**: Neo4j backend for complex memory relationships
- 🎯 **Vector Search**: Qdrant backend for semantic similarity search
- 🤖 **MCP Protocol**: Standardized interface for AI agent integration
- 🐳 **Containerized**: Docker setup for development and production
- 🔍 **Health Monitoring**: Built-in health checks and status endpoints
- 🛡️ **Security**: Non-root containers, proper error handling
- 📊 **Observability**: Structured logging and monitoring

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MCP Client    │    │  FastAPI App    │    │  Memory Backend │
│   (AI Agent)    │◄──►│  (MCP Server)   │◄──►│ (Neo4j/Qdrant) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  Vector Store   │
                       │   (pgvector)    │
                       └─────────────────┘
```

## 🛠️ Quick Start

### Prerequisites

- **Docker & Docker Compose**: For containerized deployment
- **uv**: Fast Python package manager ([install guide](https://docs.astral.sh/uv/getting-started/installation/))
- **Python 3.13+**: Required version specified in pyproject.toml
- **Node.js**: For MCP inspector tool (optional)

### Development Setup

1. **Clone and Setup**
   ```bash
   git clone <your-repo>
   cd custom-mem0
   make dev-setup
   ```

2. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Start Development Environment**
   ```bash
   make up-dev
   ```

4. **Access the Service**
   - **API**: http://localhost:8888
   - **Health Check**: http://localhost:8888/health
   - **Neo4j Browser**: http://localhost:8474 (user: neo4j, password: mem0graph)
   - **PostgreSQL**: localhost:8432 (user: postgres, password: postgres)

## 🚀 Production Deployment

### Automated Production Deployment

1. **Full Production Setup**
   ```bash
   make deploy-prod
   ```
   This command:
   - Creates pre-deployment backups
   - Builds production images
   - Deploys services with health checks
   - Validates deployment
   - Sets up monitoring cron jobs

2. **Manual Production Setup**
   ```bash
   make prod-setup
   make up
   make health
   ```

3. **Monitor Health**
   ```bash
   make health
   make status
   ```

### Environment Considerations

- Use strong passwords for databases
- Set proper OpenAI API keys
- Configure appropriate resource limits
- Set up monitoring and alerting
- Regular backups with `make backup`

### Health Monitoring

- Health endpoint: `/health`
- Container health checks included
- Graceful shutdown handling
- Structured logging for observability

## 💾 Backup & Recovery

### Production Backup Strategy

The system includes comprehensive backup functionality for production environments:

#### Backup Types

1. **Application-Aware Backups**
   - PostgreSQL: Uses `pg_dump` for consistent database snapshots
   - Neo4j: Database dumps using Neo4j admin tools
   - History: File-level backup of SQLite history database

2. **Automated Backup Process**
   ```bash
   make backup-automated    # Full backup with validation and cleanup
   make backup              # Manual backup
   make backup-validate     # Verify backup integrity
   make backup-monitor      # Check backup health
   ```

#### Backup Commands

```bash
# Create backups
make backup                          # All databases
make backup-postgres                 # PostgreSQL only
make backup-neo4j                   # Neo4j only
make backup-history                 # History database only

# Manage backups
make backup-list                    # List all backups
make backup-validate               # Check backup integrity
make backup-cleanup                # Remove old backups (30+ days)
make backup-monitor                # Health monitoring

# Restore from backups
make restore-postgres BACKUP_FILE=postgres_20241225_120000.sql.gz
make restore-neo4j BACKUP_FILE=neo4j_20241225_120000.tar.gz
```

#### Backup Monitoring

The system includes automated backup monitoring:

- **Health Checks**: Validates backup age, size, and integrity
- **Alerting**: Email and webhook notifications for backup issues
- **Disk Space**: Monitors available storage for backups
- **Automated Cleanup**: Removes backups older than 30 days

#### Production Backup Schedule

Set up automated backups with cron:

```bash
# Daily backup at 2 AM
0 2 * * * cd /path/to/custom-mem0 && make backup-automated >> logs/backup.log 2>&1

# Backup monitoring every 6 hours
0 */6 * * * cd /path/to/custom-mem0 && make backup-monitor >> logs/monitor.log 2>&1
```

#### Cloud Backup Integration

Upload backups to cloud storage:

```bash
make backup-to-cloud    # Requires AWS CLI configuration
```

Configure AWS CLI:
```bash
aws configure
# Enter your AWS credentials and region
```

#### Backup Storage Structure

```
backups/
├── postgres/
│   ├── postgres_20241225_120000.sql.gz
│   └── postgres_20241225_140000.sql.gz
├── neo4j/
│   ├── neo4j_20241225_120000.tar.gz
│   └── neo4j_20241225_140000.tar.gz
└── history/
    ├── history_20241225_120000.tar.gz
    └── history_20241225_140000.tar.gz
```

#### Disaster Recovery

1. **Full System Recovery**
   ```bash
   # Stop services
   make down
   
   # List available backups
   make backup-list
   
   # Restore databases
   make restore-postgres BACKUP_FILE=postgres_YYYYMMDD_HHMMSS.sql.gz
   make restore-neo4j BACKUP_FILE=neo4j_YYYYMMDD_HHMMSS.tar.gz
   
   # Start services
   make up
   make health
   ```

2. **Point-in-Time Recovery**
   - Backups are timestamped for specific recovery points
   - Choose the backup closest to your desired recovery time
   - PostgreSQL dumps include complete schema and data

#### Backup Best Practices

- **Regular Testing**: Regularly test backup restoration procedures
- **Multiple Locations**: Store backups in multiple locations (local + cloud)
- **Monitoring**: Use backup monitoring to catch issues early
- **Documentation**: Keep recovery procedures documented and accessible
- **Security**: Encrypt backups containing sensitive data

## 📋 Available Commands

Run `make help` to see all available commands:

```bash
make help                # Show all commands
make up                  # Start production environment
make up-dev              # Start development with hot reload
make down                # Stop all services
make logs                # View container logs
make health              # Check service health
make test                # Run tests
make mcp-inspect         # Debug MCP protocol
make backup              # Backup data volumes
```

## 🔧 Configuration

### Environment Variables

Key configuration options in `.env`:

```bash
# Backend Selection
BACKEND="neo4j"  # or "qdrant"

# OpenAI Configuration
OPENAI_API_KEY="your-api-key"
OPENAI_MODEL="gpt-4o-mini"
OPENAI_EMBEDDING_MODEL="text-embedding-3-small"

# Neo4j Configuration
NEO4J_IP="neo4j:7687"
NEO4J_USERNAME="neo4j"
NEO4J_PASSWORD="mem0graph"

# PostgreSQL (Vector Store)
POSTGRES_HOST="postgres"
POSTGRES_PORT=5432
POSTGRES_USER="postgres"
POSTGRES_PASSWORD="password"

# FastAPI Configuration
FASTAPI_HOST="localhost"
FASTAPI_PORT=8000
MEMORY_LOG_LEVEL="info"
```

### Backend Options

#### Neo4j Backend
- **Best for**: Complex relationships, graph queries, knowledge graphs
- **Features**: APOC plugins, relationship traversal, graph algorithms
- **Vector Store**: pgvector for embeddings

#### Qdrant Backend  
- **Best for**: Pure vector similarity search, simple deployments
- **Features**: High-performance vector search, filtering, collections
- **Vector Store**: Built-in Qdrant vectors

## 🤖 MCP Integration

### Available Tools

- `add_memory`: Store new memories
- `search_memories`: Find memories by similarity
- `update_memory`: Modify existing memories  
- `delete_memory`: Remove specific memories
- `delete_all_memories`: Clear all memories for a user/agent

### Available Resources

- `memories://{user_id}/{agent_id}/{limit}`: Retrieve all memories

### Example Usage

```python
# Add a memory
await memory_client.add_memory(
    data="User prefers dark mode interface",
    user_id="user123",
    agent_id="assistant"
)

# Search memories
results = await memory_client.search_memories(
    query="interface preferences",
    user_id="user123"
)
```

## 🧪 Testing & Development

### Running Tests
```bash
make test                # Run all tests
make lint                # Check code style
make format              # Format code
make check               # Run all checks
```

### Debugging
```bash
make logs SERVICE=mem0   # View specific service logs
make shell               # Access container shell
make db-shell            # Access PostgreSQL
make neo4j-shell         # Access Neo4j
make mcp-inspect         # Debug MCP protocol
```

### Development Features
- **Hot Reload**: Code changes automatically restart the server
- **Volume Mounting**: Live code editing without rebuilds
- **Debug Logging**: Detailed logs for development
- **MCP Inspector**: Visual debugging of MCP protocol

## 🚀 Production Deployment

### Docker Production
```bash
make prod-setup
make up
make health
```

### Environment Considerations
- Use strong passwords for databases
- Set proper OpenAI API keys
- Configure appropriate resource limits
- Set up monitoring and alerting
- Regular backups with `make backup`

### Health Monitoring
- Health endpoint: `/health`
- Container health checks included
- Graceful shutdown handling
- Structured logging for observability

## 🔒 Security

- **Non-root containers**: All services run as non-root users
- **Environment isolation**: Proper Docker networking
- **Secret management**: Environment-based configuration
- **Input validation**: Pydantic models for API validation
- **Error handling**: Graceful error responses

## 📚 API Documentation

When running, visit:
- **Swagger UI**: http://localhost:8888/docs
- **ReDoc**: http://localhost:8888/redoc
- **OpenAPI JSON**: http://localhost:8888/openapi.json

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make check`
5. Submit a pull request

## 📄 License

[Your License Here]

## 🆘 Troubleshooting

### Common Issues

**Service won't start**
```bash
make logs                # Check logs
make health              # Check health status
```

**Database connection issues**
```bash
make status              # Check container status
make db-shell            # Test database access
```

**Memory operations failing**
```bash
make mcp-inspect         # Debug MCP protocol
curl http://localhost:8888/health  # Check API health
```

### Getting Help

- Check logs with `make logs`
- Use MCP inspector with `make mcp-inspect`
- Review health status with `make health`
- Access container shell with `make shell`

---

**Built with ❤️ using Mem0, MCP, FastAPI, and Docker**