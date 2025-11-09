package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

// User holds the schema definition for the User entity.
type User struct {
	ent.Schema
}

// Fields of the User.
func (User) Fields() []ent.Field {
	return []ent.Field{
		field.String("username").NotEmpty().Unique().Comment("用户名"),
		field.String("password").NotEmpty().Comment("密码"),
		field.String("nickname").NotEmpty().Comment("昵称"),
		field.Int("sex").Optional().Comment("性别: 0:男 1:女"),
		field.String("avatar").Optional().Comment("头像URL"),
		field.String("signature").Optional().Comment("个人签名"),
		field.String("region").Optional().Comment("地区/城市"),
		field.Time("birthday").Optional().Nillable().Comment("生日"),
		field.Time("lastSeen").Optional().Nillable().Comment("最后在线时间"),
		field.String("status").Optional().Default("online").Comment("在线状态: online/offline/busy/away"),
	}
}

// Edges of the User.
func (User) Edges() []ent.Edge {
	return nil
}

// Indexes of the User.
func (User) Indexes() []ent.Index {
	return []ent.Index{
		// 用户名索引（已通过Unique自动创建，这里显式声明以提高可读性）
		index.Fields("username").Unique(),
	}
}
