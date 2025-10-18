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
