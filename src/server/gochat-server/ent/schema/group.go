package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
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
