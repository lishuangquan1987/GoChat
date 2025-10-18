# GoChat 服务器配置说明

## Config.json 配置文件

所有服务器配置都在 `Config.json` 文件中管理。

### 配置项说明

```json
{
    "DBType": "postgres",
    "ConnectionString": "host=localhost port=5432 user=postgres dbname=gochat password=123456 sslmode=disable",
    "MinIO": {
        "Endpoint": "localhost:9000",
        "AccessKey": "minioadmin",
        "SecretKey": "minioadmin",
        "BucketName": "gochat",
        "UseSSL": false
    },
    "Server": {
        "Port": "8080"
    }
}
```

### 数据库配置

- **DBType**: 数据库类型，目前支持 `postgres`、`mysql`、`sqlite3`
- **ConnectionString**: 数据库连接字符串
  - PostgreSQL 格式: `host=localhost port=5432 user=postgres dbname=gochat password=123456 sslmode=disable`
  - MySQL 格式: `user:password@tcp(localhost:3306)/gochat?charset=utf8mb4&parseTime=True&loc=Local`
  - SQLite 格式: `file:gochat.db?cache=shared&mode=rwc`

#### PostgreSQL 连接参数说明
- `host`: 数据库服务器地址
- `port`: 数据库端口（默认 5432）
- `user`: 数据库用户名
- `dbname`: 数据库名称
- `password`: 数据库密码
- `sslmode`: SSL 模式
  - `disable`: 不使用 SSL（本地开发推荐）
  - `require`: 必须使用 SSL
  - `verify-ca`: 验证 CA 证书
  - `verify-full`: 完全验证

### MinIO 配置

- **Endpoint**: MinIO 服务地址和端口
  - 本地开发: `localhost:9000`
  - 生产环境: `minio.example.com:9000`
- **AccessKey**: MinIO 访问密钥（默认: minioadmin）
- **SecretKey**: MinIO 密钥（默认: minioadmin）
- **BucketName**: 存储桶名称（默认: gochat）
- **UseSSL**: 是否使用 HTTPS
  - `false`: HTTP（本地开发推荐）
  - `true`: HTTPS（生产环境推荐）

### 服务器配置

- **Port**: HTTP 服务器监听端口（默认: 8080）

## 环境配置

### 开发环境

```json
{
    "DBType": "postgres",
    "ConnectionString": "host=localhost port=5432 user=postgres dbname=gochat password=123456 sslmode=disable",
    "MinIO": {
        "Endpoint": "localhost:9000",
        "AccessKey": "minioadmin",
        "SecretKey": "minioadmin",
        "BucketName": "gochat",
        "UseSSL": false
    },
    "Server": {
        "Port": "8080"
    }
}
```

### 生产环境示例

```json
{
    "DBType": "postgres",
    "ConnectionString": "host=db.example.com port=5432 user=gochat_user dbname=gochat_prod password=your_secure_password sslmode=require",
    "MinIO": {
        "Endpoint": "minio.example.com:9000",
        "AccessKey": "your_access_key",
        "SecretKey": "your_secret_key",
        "BucketName": "gochat-prod",
        "UseSSL": true
    },
    "Server": {
        "Port": "8080"
    }
}
```

## 启动前准备

### 1. 安装 PostgreSQL

```bash
# Windows (使用 Chocolatey)
choco install postgresql

# macOS (使用 Homebrew)
brew install postgresql

# Linux (Ubuntu/Debian)
sudo apt-get install postgresql
```

### 2. 创建数据库

```sql
-- 连接到 PostgreSQL
psql -U postgres

-- 创建数据库
CREATE DATABASE gochat;

-- 创建用户（可选）
CREATE USER gochat_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE gochat TO gochat_user;
```

### 3. 安装 MinIO

```bash
# Windows (使用 Chocolatey)
choco install minio

# macOS (使用 Homebrew)
brew install minio/stable/minio

# Linux
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
```

### 4. 启动 MinIO

```bash
# 设置数据目录
mkdir -p ~/minio/data

# 启动 MinIO
minio server ~/minio/data --console-address ":9001"

# 默认访问地址: http://localhost:9000
# 默认控制台: http://localhost:9001
# 默认用户名: minioadmin
# 默认密码: minioadmin
```

## 启动服务器

```bash
cd src/server/gochat-server

# 编译
go build -o gochat-server main.go

# 运行
./gochat-server  # Linux/macOS
gochat-server.exe  # Windows
```

## 常见问题

### 1. 数据库连接失败

**错误**: `pq: SSL is not enabled on the server`

**解决**: 在连接字符串中添加 `sslmode=disable`

### 2. MinIO 连接失败

**错误**: `MinIO initialization failed`

**解决**: 
- 确保 MinIO 服务已启动
- 检查 Endpoint 地址是否正确
- 检查 AccessKey 和 SecretKey 是否正确

### 3. 端口被占用

**错误**: `bind: address already in use`

**解决**: 
- 修改 Config.json 中的 Port 配置
- 或者停止占用该端口的其他程序

## 安全建议

1. **生产环境**:
   - 使用强密码
   - 启用 SSL/TLS
   - 限制数据库访问 IP
   - 定期备份数据

2. **MinIO**:
   - 修改默认的 AccessKey 和 SecretKey
   - 启用 HTTPS
   - 配置访问策略

3. **数据库**:
   - 使用专用数据库用户
   - 限制用户权限
   - 启用 SSL 连接
   - 定期更新密码
