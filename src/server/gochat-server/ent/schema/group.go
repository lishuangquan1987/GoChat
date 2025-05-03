package schema

import (
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
		field.String("groupId").NotEmpty().Comment("群组ID,由群创建的时候产生"),
		field.String("groupName").NotEmpty().Comment("群组名称"),
		field.String("ownerId").NotEmpty().Comment("群主ID"),
		field.String("createUserId").NotEmpty().Comment("创建者ID"),
		field.String("createTime").NotEmpty().Comment("群组创建时间"),
		field.Strings("members").Comment("群组成员ID"),
	}
}

// Edges of the Group.
func (Group) Edges() []ent.Edge {
	return nil
}
