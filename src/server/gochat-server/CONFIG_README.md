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

#### PostgreSQL 配置

**连接字符串格式**: `host=localhost port=5432 user=postgres dbname=gochat password=123456 sslmode=disable`

**连接参数说明**:
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

**示例配置**:
```json
{
    "DBType": "postgres",
    "ConnectionString": "host=localhost port=5432 user=postgres dbname=gochat password=123456 sslmode=disable"
}
```

#### MySQL 配置

**连接字符串格式**: `user:password@tcp(host:port)/dbname?charset=utf8mb4&parseTime=True&loc=Local`

**连接参数说明**:
- `user`: 数据库用户名
- `password`: 数据库密码
- `host`: 数据库服务器地址（默认 localhost）
- `port`: 数据库端口（默认 3306）
- `dbname`: 数据库名称
- `charset`: 字符集（推荐 utf8mb4，支持完整的 UTF-8 字符）
- `parseTime`: 是否解析时间字段（必须为 True）
- `loc`: 时区设置（推荐 Local 或 Asia/Shanghai）

**常用连接参数**:
- `timeout`: 连接超时时间（如 `10s`）
- `readTimeout`: 读取超时时间（如 `30s`）
- `writeTimeout`: 写入超时时间（如 `30s`）
- `collation`: 排序规则（如 `utf8mb4_unicode_ci`）

**示例配置**:
```json
{
    "DBType": "mysql",
    "ConnectionString": "root:123456@tcp(localhost:3306)/gochat?charset=utf8mb4&parseTime=True&loc=Local"
}
```

**生产环境示例**:
```json
{
    "DBType": "mysql",
    "ConnectionString": "gochat_user:secure_password@tcp(db.example.com:3306)/gochat_prod?charset=utf8mb4&parseTime=True&loc=Asia%2FShanghai&timeout=10s&readTimeout=30s&writeTimeout=30s"
}
```

#### SQLite 配置

**连接字符串格式**: `file:gochat.db?cache=shared&mode=rwc`

**连接参数说明**:
- `file`: 数据库文件路径
- `cache`: 缓存模式（shared 表示共享缓存）
- `mode`: 文件模式（rwc 表示读写创建）

**示例配置**:
```json
{
    "DBType": "sqlite3",
    "ConnectionString": "file:gochat.db?cache=shared&mode=rwc"
}
```

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

### 1. 安装数据库

#### PostgreSQL

```bash
# Windows (使用 Chocolatey)
choco install postgresql

# macOS (使用 Homebrew)
brew install postgresql

# Linux (Ubuntu/Debian)
sudo apt-get install postgresql
```

#### MySQL

```bash
# Windows (使用 Chocolatey)
choco install mysql

# macOS (使用 Homebrew)
brew install mysql

# Linux (Ubuntu/Debian)
sudo apt-get install mysql-server
```

### 2. 创建数据库

#### PostgreSQL

```sql
-- 连接到 PostgreSQL
psql -U postgres

-- 创建数据库
CREATE DATABASE gochat;

-- 创建用户（可选）
CREATE USER gochat_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE gochat TO gochat_user;
```

#### MySQL

```sql
-- 连接到 MySQL
mysql -u root -p

-- 创建数据库
CREATE DATABASE gochat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 创建用户（可选）
CREATE USER 'gochat_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON gochat.* TO 'gochat_user'@'localhost';
FLUSH PRIVILEGES;
```

**注意**: MySQL 数据库必须使用 `utf8mb4` 字符集，以支持完整的 UTF-8 字符（包括 emoji）。

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

#### PostgreSQL

**错误**: `pq: SSL is not enabled on the server`

**解决**: 在连接字符串中添加 `sslmode=disable`

#### MySQL

**错误**: `Access denied for user`

**解决**: 
- 检查用户名和密码是否正确
- 确认用户是否有访问数据库的权限
- 检查用户是否允许从当前主机连接（`'user'@'localhost'` vs `'user'@'%'`）

**错误**: `Unknown charset 'utf8mb4'`

**解决**: 确保 MySQL 版本 >= 5.5.3，或者使用 `charset=utf8`

**错误**: `this authentication plugin is not supported`

**解决**: 在连接字符串中添加 `allowOldPasswords=true`，或者更新 MySQL 用户密码使用新的认证方式

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
   - 启用 SSL 连接（PostgreSQL/MySQL）
   - 定期更新密码
   - MySQL: 使用 `utf8mb4` 字符集以确保完整 UTF-8 支持
