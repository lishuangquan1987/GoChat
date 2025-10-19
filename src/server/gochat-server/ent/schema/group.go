package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

// Group holds the schema definition for the Group entity.
type Group struct {
	ent.Schema
}

// Fields of the Group.
func (Group) Fields() []ent.Field {
	return []ent.Field{
		field.String("groupId").NotEmpty().Unique().Comment("群组ID,由群创建的时候产生"),
		field.String("groupName").NotEmpty().Comment("群组名称"),
		field.Int("ownerId").Comment("群主ID"),
		field.Int("createUserId").Comment("创建者ID"),
		field.Time("createTime").Default(time.Now).Comment("群组创建时间"),
		field.JSON("members", []int{}).Comment("群组成员ID列表"),
	}
}

// Edges of the Group.
func (Group) Edges() []ent.Edge {
	return nil
}

// Indexes of the Group.
func (Group) Indexes() []ent.Index {
	return []ent.Index{
		// 群组ID索引（已通过Unique自动创建，这里显式声明以提高可读性）
		index.Fields("groupId").Unique(),
		// 群主ID索引，用于查询用户创建的群组
		index.Fields("ownerId"),
		// 创建者ID索引，用于查询用户创建的群组
		index.Fields("createUserId"),
		// 创建时间索引，用于按时间排序群组
		index.Fields("createTime"),
	}
}
