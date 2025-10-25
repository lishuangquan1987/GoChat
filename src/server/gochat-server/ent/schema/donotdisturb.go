package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
)

// DoNotDisturb holds the schema definition for the DoNotDisturb entity.
type DoNotDisturb struct {
	ent.Schema
}

// Fields of the DoNotDisturb.
func (DoNotDisturb) Fields() []ent.Field {
	return []ent.Field{
		field.Int("id").
			Positive().
			Comment("主键ID"),
		field.Int("user_id").
			Positive().
			Comment("用户ID"),
		field.Int("target_user_id").
			Optional().
			Nillable().
			Comment("目标用户ID（私聊免打扰）"),
		field.Int("target_group_id").
			Optional().
			Nillable().
			Comment("目标群组ID（群聊免打扰）"),
		field.Bool("is_global").
			Default(false).
			Comment("是否全局免打扰"),
		field.Time("start_time").
			Optional().
			Nillable().
			Comment("免打扰开始时间（定时免打扰）"),
		field.Time("end_time").
			Optional().
			Nillable().
			Comment("免打扰结束时间（定时免打扰）"),
		field.Time("created_at").
			Default(time.Now).
			Comment("创建时间"),
		field.Time("updated_at").
			Default(time.Now).
			UpdateDefault(time.Now).
			Comment("更新时间"),
	}
}

// Edges of the DoNotDisturb.
func (DoNotDisturb) Edges() []ent.Edge {
	return nil
}

// Indexes of the DoNotDisturb.
func (DoNotDisturb) Indexes() []ent.Index {
	return []ent.Index{
		// 用户ID索引
		index.Fields("user_id"),
		// 用户+目标用户唯一索引
		index.Fields("user_id", "target_user_id").
			Unique(),
		// 用户+目标群组唯一索引
		index.Fields("user_id", "target_group_id").
			Unique(),
		// 全局免打扰唯一索引
		index.Fields("user_id", "is_global").
			Unique(),
	}
}