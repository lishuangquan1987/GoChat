# Ent 表实体生成指南

## 概述

本项目使用 [Ent](https://entgo.io/) 作为 ORM 框架。Ent 是一个强大的实体框架，用于构建和维护大型数据模型。

## 目录结构

```
ent/
├── schema/              # Schema 定义文件（手动编写）
│   ├── user.go
│   ├── message.go
│   └── ...
├── generate.go         # 生成指令文件
├── ent.go              # 生成的客户端代码
├── client.go           # 生成的客户端代码
└── [entity]/           # 每个实体生成的代码目录
    ├── [entity].go
    ├── [entity]_create.go
    ├── [entity]_query.go
    └── ...
```

## 生成步骤

### 方法一：使用 go generate（推荐）

在项目根目录（`src/server/gochat-server`）执行：

```bash
go generate ./ent
```

这会执行 `ent/generate.go` 文件中的 `//go:generate` 指令。

### 方法二：直接运行 ent 命令

```bash
go run -mod=mod entgo.io/ent/cmd/ent generate ./ent/schema
```

### 方法三：使用 ent CLI（如果已全局安装）

```bash
ent generate ./ent/schema
```

## 定义新的 Schema

### 1. 创建 Schema 文件

在 `ent/schema/` 目录下创建新的 Go 文件，例如 `product.go`：

```go
package schema

import (
    "entgo.io/ent"
    "entgo.io/ent/schema/field"
    "entgo.io/ent/schema/index"
)

// Product 产品实体
type Product struct {
    ent.Schema
}

// Fields 定义字段
func (Product) Fields() []ent.Field {
    return []ent.Field{
        field.String("name").NotEmpty().Comment("产品名称"),
        field.String("description").Optional().Comment("产品描述"),
        field.Float("price").Comment("价格"),
        field.Int("stock").Default(0).Comment("库存数量"),
        field.Time("createdAt").Default(time.Now).Comment("创建时间"),
        field.Time("updatedAt").Default(time.Now).UpdateDefault(time.Now).Comment("更新时间"),
    }
}

// Edges 定义关系（外键等）
func (Product) Edges() []ent.Edge {
    return []ent.Edge{
        // 示例：产品属于一个分类
        // edge.To("category", Category.Type).Unique().Required(),
    }
}

// Indexes 定义索引
func (Product) Indexes() []ent.Index {
    return []ent.Index{
        index.Fields("name").Unique(), // 唯一索引
        index.Fields("price"),         // 普通索引
    }
}
```

### 2. 运行生成命令

```bash
go generate ./ent
```

### 3. 使用生成的代码

```go
import "gochat_server/ent"

// 创建客户端
client := ent.NewClient(driver)

// 创建产品
product, err := client.Product.
    Create().
    SetName("iPhone 15").
    SetPrice(9999.99).
    SetStock(100).
    Save(ctx)

// 查询产品
products, err := client.Product.
    Query().
    Where(product.PriceGT(1000)).
    All(ctx)

// 更新产品
err := client.Product.
    UpdateOneID(product.ID).
    SetStock(50).
    Save(ctx)

// 删除产品
err := client.Product.
    DeleteOneID(product.ID).
    Exec(ctx)
```

## 常用字段类型

### 基础类型

```go
field.String("name")           // 字符串
field.Int("age")               // 整数
field.Float("price")           // 浮点数
field.Bool("isActive")          // 布尔值
field.Time("createdAt")         // 时间
field.Bytes("data")             // 字节数组
field.JSON("metadata", map[string]interface{}{}) // JSON
```

### 字段选项

```go
field.String("name").
    NotEmpty()                  // 非空
    Unique()                    // 唯一
    Optional()                  // 可选
    Default("default")          // 默认值
    Comment("字段说明")         // 注释
    MaxLen(100)                 // 最大长度
    MinLen(1)                   // 最小长度
    Nillable()                  // 允许 nil
    Immutable()                 // 不可变
    Sensitive()                 // 敏感字段（日志中隐藏）
```

### 时间字段

```go
field.Time("createdAt").
    Default(time.Now)          // 创建时默认值
    UpdateDefault(time.Now)     // 更新时默认值
    Nillable()                  // 允许 nil
```

### 枚举字段

```go
field.Enum("status").
    Values("pending", "active", "inactive").
    Default("pending")
```

## 定义关系（Edges）

### 一对一关系

```go
// User 有一个 Profile
func (User) Edges() []ent.Edge {
    return []ent.Edge{
        edge.To("profile", Profile.Type).Unique(),
    }
}

// Profile 属于一个 User
func (Profile) Edges() []ent.Edge {
    return []ent.Edge{
        edge.From("user", User.Type).Ref("profile").Unique().Required(),
    }
}
```

### 一对多关系

```go
// User 有多个 Posts
func (User) Edges() []ent.Edge {
    return []ent.Edge{
        edge.To("posts", Post.Type),
    }
}

// Post 属于一个 User
func (Post) Edges() []ent.Edge {
    return []ent.Edge{
        edge.From("user", User.Type).Ref("posts").Unique().Required(),
    }
}
```

### 多对多关系

```go
// User 和 Group 多对多
func (User) Edges() []ent.Edge {
    return []ent.Edge{
        edge.To("groups", Group.Type),
    }
}

func (Group) Edges() []ent.Edge {
    return []ent.Edge{
        edge.From("users", User.Type).Ref("groups"),
    }
}
```

## 索引

```go
func (User) Indexes() []ent.Index {
    return []ent.Index{
        // 单字段唯一索引
        index.Fields("email").Unique(),
        
        // 多字段组合索引
        index.Fields("name", "age"),
        
        // 唯一组合索引
        index.Fields("username", "domain").Unique(),
    }
}
```

## 完整示例

查看项目中的现有 Schema 文件作为参考：

- `ent/schema/user.go` - 用户实体
- `ent/schema/message.go` - 消息实体
- `ent/schema/group.go` - 群组实体
- `ent/schema/friendrelationship.go` - 好友关系实体

## 注意事项

1. **Schema 文件位置**：所有 Schema 定义必须在 `ent/schema/` 目录下
2. **包名**：Schema 文件必须使用 `package schema`
3. **生成后不要手动编辑**：`ent/` 目录下除了 `schema/` 和 `generate.go` 外的所有文件都是自动生成的，不要手动修改
4. **数据库迁移**：修改 Schema 后，需要：
   - 运行 `go generate ./ent` 生成代码
   - 程序启动时会自动使用 Ent 的 `Schema.Create()` 方法同步数据库结构
   - 无需手动运行迁移，Ent 会自动处理表结构的创建和更新
5. **字段命名**：Ent 会自动将驼峰命名转换为下划线命名（如 `lastSeen` → `last_seen`）

## 常见问题

### Q: 生成后如何应用数据库变更？

A: 本项目使用 Ent 的自动迁移功能。修改 Schema 后只需要：
1. 运行 `go generate ./ent` 重新生成 Ent 代码
2. 重启服务器，程序启动时会自动调用 `services.RunEntMigrations()` 同步数据库结构
3. Ent 会自动检测 Schema 变化并更新数据库表结构

**注意**：Ent 的自动迁移只会添加新的表和字段，不会删除已存在的字段。如果需要删除字段，需要手动执行 SQL 或使用 Ent 的迁移工具。

### Q: 如何查看生成的 SQL？

A: Ent 支持生成迁移 SQL 文件，可以使用：
```go
import "gochat_server/ent/migrate"

// 生成 SQL 到文件
migrate.WriteTo(ctx, client.Schema, w)
```

### Q: 如何添加验证器？

A: 在 Schema 中使用 `Validate()` 方法：
```go
func (User) Fields() []ent.Field {
    return []ent.Field{
        field.String("email").
            Validate(func(s string) error {
                if !strings.Contains(s, "@") {
                    return fmt.Errorf("invalid email")
                }
                return nil
            }),
    }
}
```

## 参考资源

- [Ent 官方文档](https://entgo.io/docs/getting-started)
- [Ent Schema 定义](https://entgo.io/docs/schema-definition)
- [Ent 关系定义](https://entgo.io/docs/schema-edges)
- [Ent 索引定义](https://entgo.io/docs/schema-indexes)

