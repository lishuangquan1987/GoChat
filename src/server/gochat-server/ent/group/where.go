// Code generated by ent, DO NOT EDIT.

package group

import (
	"gochat_server/ent/predicate"

	"entgo.io/ent/dialect/sql"
)

// ID filters vertices based on their ID field.
func ID(id int) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldID, id))
}

// IDEQ applies the EQ predicate on the ID field.
func IDEQ(id int) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldID, id))
}

// IDNEQ applies the NEQ predicate on the ID field.
func IDNEQ(id int) predicate.Group {
	return predicate.Group(sql.FieldNEQ(FieldID, id))
}

// IDIn applies the In predicate on the ID field.
func IDIn(ids ...int) predicate.Group {
	return predicate.Group(sql.FieldIn(FieldID, ids...))
}

// IDNotIn applies the NotIn predicate on the ID field.
func IDNotIn(ids ...int) predicate.Group {
	return predicate.Group(sql.FieldNotIn(FieldID, ids...))
}

// IDGT applies the GT predicate on the ID field.
func IDGT(id int) predicate.Group {
	return predicate.Group(sql.FieldGT(FieldID, id))
}

// IDGTE applies the GTE predicate on the ID field.
func IDGTE(id int) predicate.Group {
	return predicate.Group(sql.FieldGTE(FieldID, id))
}

// IDLT applies the LT predicate on the ID field.
func IDLT(id int) predicate.Group {
	return predicate.Group(sql.FieldLT(FieldID, id))
}

// IDLTE applies the LTE predicate on the ID field.
func IDLTE(id int) predicate.Group {
	return predicate.Group(sql.FieldLTE(FieldID, id))
}

// GroupId applies equality check predicate on the "groupId" field. It's identical to GroupIdEQ.
func GroupId(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldGroupId, v))
}

// GroupName applies equality check predicate on the "groupName" field. It's identical to GroupNameEQ.
func GroupName(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldGroupName, v))
}

// OwnerId applies equality check predicate on the "ownerId" field. It's identical to OwnerIdEQ.
func OwnerId(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldOwnerId, v))
}

// CreateUserId applies equality check predicate on the "createUserId" field. It's identical to CreateUserIdEQ.
func CreateUserId(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldCreateUserId, v))
}

// CreateTime applies equality check predicate on the "createTime" field. It's identical to CreateTimeEQ.
func CreateTime(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldCreateTime, v))
}

// GroupIdEQ applies the EQ predicate on the "groupId" field.
func GroupIdEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldGroupId, v))
}

// GroupIdNEQ applies the NEQ predicate on the "groupId" field.
func GroupIdNEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldNEQ(FieldGroupId, v))
}

// GroupIdIn applies the In predicate on the "groupId" field.
func GroupIdIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldIn(FieldGroupId, vs...))
}

// GroupIdNotIn applies the NotIn predicate on the "groupId" field.
func GroupIdNotIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldNotIn(FieldGroupId, vs...))
}

// GroupIdGT applies the GT predicate on the "groupId" field.
func GroupIdGT(v string) predicate.Group {
	return predicate.Group(sql.FieldGT(FieldGroupId, v))
}

// GroupIdGTE applies the GTE predicate on the "groupId" field.
func GroupIdGTE(v string) predicate.Group {
	return predicate.Group(sql.FieldGTE(FieldGroupId, v))
}

// GroupIdLT applies the LT predicate on the "groupId" field.
func GroupIdLT(v string) predicate.Group {
	return predicate.Group(sql.FieldLT(FieldGroupId, v))
}

// GroupIdLTE applies the LTE predicate on the "groupId" field.
func GroupIdLTE(v string) predicate.Group {
	return predicate.Group(sql.FieldLTE(FieldGroupId, v))
}

// GroupIdContains applies the Contains predicate on the "groupId" field.
func GroupIdContains(v string) predicate.Group {
	return predicate.Group(sql.FieldContains(FieldGroupId, v))
}

// GroupIdHasPrefix applies the HasPrefix predicate on the "groupId" field.
func GroupIdHasPrefix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasPrefix(FieldGroupId, v))
}

// GroupIdHasSuffix applies the HasSuffix predicate on the "groupId" field.
func GroupIdHasSuffix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasSuffix(FieldGroupId, v))
}

// GroupIdEqualFold applies the EqualFold predicate on the "groupId" field.
func GroupIdEqualFold(v string) predicate.Group {
	return predicate.Group(sql.FieldEqualFold(FieldGroupId, v))
}

// GroupIdContainsFold applies the ContainsFold predicate on the "groupId" field.
func GroupIdContainsFold(v string) predicate.Group {
	return predicate.Group(sql.FieldContainsFold(FieldGroupId, v))
}

// GroupNameEQ applies the EQ predicate on the "groupName" field.
func GroupNameEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldGroupName, v))
}

// GroupNameNEQ applies the NEQ predicate on the "groupName" field.
func GroupNameNEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldNEQ(FieldGroupName, v))
}

// GroupNameIn applies the In predicate on the "groupName" field.
func GroupNameIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldIn(FieldGroupName, vs...))
}

// GroupNameNotIn applies the NotIn predicate on the "groupName" field.
func GroupNameNotIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldNotIn(FieldGroupName, vs...))
}

// GroupNameGT applies the GT predicate on the "groupName" field.
func GroupNameGT(v string) predicate.Group {
	return predicate.Group(sql.FieldGT(FieldGroupName, v))
}

// GroupNameGTE applies the GTE predicate on the "groupName" field.
func GroupNameGTE(v string) predicate.Group {
	return predicate.Group(sql.FieldGTE(FieldGroupName, v))
}

// GroupNameLT applies the LT predicate on the "groupName" field.
func GroupNameLT(v string) predicate.Group {
	return predicate.Group(sql.FieldLT(FieldGroupName, v))
}

// GroupNameLTE applies the LTE predicate on the "groupName" field.
func GroupNameLTE(v string) predicate.Group {
	return predicate.Group(sql.FieldLTE(FieldGroupName, v))
}

// GroupNameContains applies the Contains predicate on the "groupName" field.
func GroupNameContains(v string) predicate.Group {
	return predicate.Group(sql.FieldContains(FieldGroupName, v))
}

// GroupNameHasPrefix applies the HasPrefix predicate on the "groupName" field.
func GroupNameHasPrefix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasPrefix(FieldGroupName, v))
}

// GroupNameHasSuffix applies the HasSuffix predicate on the "groupName" field.
func GroupNameHasSuffix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasSuffix(FieldGroupName, v))
}

// GroupNameEqualFold applies the EqualFold predicate on the "groupName" field.
func GroupNameEqualFold(v string) predicate.Group {
	return predicate.Group(sql.FieldEqualFold(FieldGroupName, v))
}

// GroupNameContainsFold applies the ContainsFold predicate on the "groupName" field.
func GroupNameContainsFold(v string) predicate.Group {
	return predicate.Group(sql.FieldContainsFold(FieldGroupName, v))
}

// OwnerIdEQ applies the EQ predicate on the "ownerId" field.
func OwnerIdEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldOwnerId, v))
}

// OwnerIdNEQ applies the NEQ predicate on the "ownerId" field.
func OwnerIdNEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldNEQ(FieldOwnerId, v))
}

// OwnerIdIn applies the In predicate on the "ownerId" field.
func OwnerIdIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldIn(FieldOwnerId, vs...))
}

// OwnerIdNotIn applies the NotIn predicate on the "ownerId" field.
func OwnerIdNotIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldNotIn(FieldOwnerId, vs...))
}

// OwnerIdGT applies the GT predicate on the "ownerId" field.
func OwnerIdGT(v string) predicate.Group {
	return predicate.Group(sql.FieldGT(FieldOwnerId, v))
}

// OwnerIdGTE applies the GTE predicate on the "ownerId" field.
func OwnerIdGTE(v string) predicate.Group {
	return predicate.Group(sql.FieldGTE(FieldOwnerId, v))
}

// OwnerIdLT applies the LT predicate on the "ownerId" field.
func OwnerIdLT(v string) predicate.Group {
	return predicate.Group(sql.FieldLT(FieldOwnerId, v))
}

// OwnerIdLTE applies the LTE predicate on the "ownerId" field.
func OwnerIdLTE(v string) predicate.Group {
	return predicate.Group(sql.FieldLTE(FieldOwnerId, v))
}

// OwnerIdContains applies the Contains predicate on the "ownerId" field.
func OwnerIdContains(v string) predicate.Group {
	return predicate.Group(sql.FieldContains(FieldOwnerId, v))
}

// OwnerIdHasPrefix applies the HasPrefix predicate on the "ownerId" field.
func OwnerIdHasPrefix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasPrefix(FieldOwnerId, v))
}

// OwnerIdHasSuffix applies the HasSuffix predicate on the "ownerId" field.
func OwnerIdHasSuffix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasSuffix(FieldOwnerId, v))
}

// OwnerIdEqualFold applies the EqualFold predicate on the "ownerId" field.
func OwnerIdEqualFold(v string) predicate.Group {
	return predicate.Group(sql.FieldEqualFold(FieldOwnerId, v))
}

// OwnerIdContainsFold applies the ContainsFold predicate on the "ownerId" field.
func OwnerIdContainsFold(v string) predicate.Group {
	return predicate.Group(sql.FieldContainsFold(FieldOwnerId, v))
}

// CreateUserIdEQ applies the EQ predicate on the "createUserId" field.
func CreateUserIdEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldCreateUserId, v))
}

// CreateUserIdNEQ applies the NEQ predicate on the "createUserId" field.
func CreateUserIdNEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldNEQ(FieldCreateUserId, v))
}

// CreateUserIdIn applies the In predicate on the "createUserId" field.
func CreateUserIdIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldIn(FieldCreateUserId, vs...))
}

// CreateUserIdNotIn applies the NotIn predicate on the "createUserId" field.
func CreateUserIdNotIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldNotIn(FieldCreateUserId, vs...))
}

// CreateUserIdGT applies the GT predicate on the "createUserId" field.
func CreateUserIdGT(v string) predicate.Group {
	return predicate.Group(sql.FieldGT(FieldCreateUserId, v))
}

// CreateUserIdGTE applies the GTE predicate on the "createUserId" field.
func CreateUserIdGTE(v string) predicate.Group {
	return predicate.Group(sql.FieldGTE(FieldCreateUserId, v))
}

// CreateUserIdLT applies the LT predicate on the "createUserId" field.
func CreateUserIdLT(v string) predicate.Group {
	return predicate.Group(sql.FieldLT(FieldCreateUserId, v))
}

// CreateUserIdLTE applies the LTE predicate on the "createUserId" field.
func CreateUserIdLTE(v string) predicate.Group {
	return predicate.Group(sql.FieldLTE(FieldCreateUserId, v))
}

// CreateUserIdContains applies the Contains predicate on the "createUserId" field.
func CreateUserIdContains(v string) predicate.Group {
	return predicate.Group(sql.FieldContains(FieldCreateUserId, v))
}

// CreateUserIdHasPrefix applies the HasPrefix predicate on the "createUserId" field.
func CreateUserIdHasPrefix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasPrefix(FieldCreateUserId, v))
}

// CreateUserIdHasSuffix applies the HasSuffix predicate on the "createUserId" field.
func CreateUserIdHasSuffix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasSuffix(FieldCreateUserId, v))
}

// CreateUserIdEqualFold applies the EqualFold predicate on the "createUserId" field.
func CreateUserIdEqualFold(v string) predicate.Group {
	return predicate.Group(sql.FieldEqualFold(FieldCreateUserId, v))
}

// CreateUserIdContainsFold applies the ContainsFold predicate on the "createUserId" field.
func CreateUserIdContainsFold(v string) predicate.Group {
	return predicate.Group(sql.FieldContainsFold(FieldCreateUserId, v))
}

// CreateTimeEQ applies the EQ predicate on the "createTime" field.
func CreateTimeEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldEQ(FieldCreateTime, v))
}

// CreateTimeNEQ applies the NEQ predicate on the "createTime" field.
func CreateTimeNEQ(v string) predicate.Group {
	return predicate.Group(sql.FieldNEQ(FieldCreateTime, v))
}

// CreateTimeIn applies the In predicate on the "createTime" field.
func CreateTimeIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldIn(FieldCreateTime, vs...))
}

// CreateTimeNotIn applies the NotIn predicate on the "createTime" field.
func CreateTimeNotIn(vs ...string) predicate.Group {
	return predicate.Group(sql.FieldNotIn(FieldCreateTime, vs...))
}

// CreateTimeGT applies the GT predicate on the "createTime" field.
func CreateTimeGT(v string) predicate.Group {
	return predicate.Group(sql.FieldGT(FieldCreateTime, v))
}

// CreateTimeGTE applies the GTE predicate on the "createTime" field.
func CreateTimeGTE(v string) predicate.Group {
	return predicate.Group(sql.FieldGTE(FieldCreateTime, v))
}

// CreateTimeLT applies the LT predicate on the "createTime" field.
func CreateTimeLT(v string) predicate.Group {
	return predicate.Group(sql.FieldLT(FieldCreateTime, v))
}

// CreateTimeLTE applies the LTE predicate on the "createTime" field.
func CreateTimeLTE(v string) predicate.Group {
	return predicate.Group(sql.FieldLTE(FieldCreateTime, v))
}

// CreateTimeContains applies the Contains predicate on the "createTime" field.
func CreateTimeContains(v string) predicate.Group {
	return predicate.Group(sql.FieldContains(FieldCreateTime, v))
}

// CreateTimeHasPrefix applies the HasPrefix predicate on the "createTime" field.
func CreateTimeHasPrefix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasPrefix(FieldCreateTime, v))
}

// CreateTimeHasSuffix applies the HasSuffix predicate on the "createTime" field.
func CreateTimeHasSuffix(v string) predicate.Group {
	return predicate.Group(sql.FieldHasSuffix(FieldCreateTime, v))
}

// CreateTimeEqualFold applies the EqualFold predicate on the "createTime" field.
func CreateTimeEqualFold(v string) predicate.Group {
	return predicate.Group(sql.FieldEqualFold(FieldCreateTime, v))
}

// CreateTimeContainsFold applies the ContainsFold predicate on the "createTime" field.
func CreateTimeContainsFold(v string) predicate.Group {
	return predicate.Group(sql.FieldContainsFold(FieldCreateTime, v))
}

// And groups predicates with the AND operator between them.
func And(predicates ...predicate.Group) predicate.Group {
	return predicate.Group(sql.AndPredicates(predicates...))
}

// Or groups predicates with the OR operator between them.
func Or(predicates ...predicate.Group) predicate.Group {
	return predicate.Group(sql.OrPredicates(predicates...))
}

// Not applies the not operator on the given predicate.
func Not(p predicate.Group) predicate.Group {
	return predicate.Group(sql.NotPredicates(p))
}
