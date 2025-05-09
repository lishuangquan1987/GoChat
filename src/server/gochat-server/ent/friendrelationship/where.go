// Code generated by ent, DO NOT EDIT.

package friendrelationship

import (
	"gochat_server/ent/predicate"

	"entgo.io/ent/dialect/sql"
)

// ID filters vertices based on their ID field.
func ID(id int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldEQ(FieldID, id))
}

// IDEQ applies the EQ predicate on the ID field.
func IDEQ(id int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldEQ(FieldID, id))
}

// IDNEQ applies the NEQ predicate on the ID field.
func IDNEQ(id int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldNEQ(FieldID, id))
}

// IDIn applies the In predicate on the ID field.
func IDIn(ids ...int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldIn(FieldID, ids...))
}

// IDNotIn applies the NotIn predicate on the ID field.
func IDNotIn(ids ...int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldNotIn(FieldID, ids...))
}

// IDGT applies the GT predicate on the ID field.
func IDGT(id int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldGT(FieldID, id))
}

// IDGTE applies the GTE predicate on the ID field.
func IDGTE(id int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldGTE(FieldID, id))
}

// IDLT applies the LT predicate on the ID field.
func IDLT(id int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldLT(FieldID, id))
}

// IDLTE applies the LTE predicate on the ID field.
func IDLTE(id int) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldLTE(FieldID, id))
}

// UserId applies equality check predicate on the "userId" field. It's identical to UserIdEQ.
func UserId(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldEQ(FieldUserId, v))
}

// FriendId applies equality check predicate on the "friendId" field. It's identical to FriendIdEQ.
func FriendId(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldEQ(FieldFriendId, v))
}

// UserIdEQ applies the EQ predicate on the "userId" field.
func UserIdEQ(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldEQ(FieldUserId, v))
}

// UserIdNEQ applies the NEQ predicate on the "userId" field.
func UserIdNEQ(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldNEQ(FieldUserId, v))
}

// UserIdIn applies the In predicate on the "userId" field.
func UserIdIn(vs ...string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldIn(FieldUserId, vs...))
}

// UserIdNotIn applies the NotIn predicate on the "userId" field.
func UserIdNotIn(vs ...string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldNotIn(FieldUserId, vs...))
}

// UserIdGT applies the GT predicate on the "userId" field.
func UserIdGT(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldGT(FieldUserId, v))
}

// UserIdGTE applies the GTE predicate on the "userId" field.
func UserIdGTE(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldGTE(FieldUserId, v))
}

// UserIdLT applies the LT predicate on the "userId" field.
func UserIdLT(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldLT(FieldUserId, v))
}

// UserIdLTE applies the LTE predicate on the "userId" field.
func UserIdLTE(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldLTE(FieldUserId, v))
}

// UserIdContains applies the Contains predicate on the "userId" field.
func UserIdContains(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldContains(FieldUserId, v))
}

// UserIdHasPrefix applies the HasPrefix predicate on the "userId" field.
func UserIdHasPrefix(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldHasPrefix(FieldUserId, v))
}

// UserIdHasSuffix applies the HasSuffix predicate on the "userId" field.
func UserIdHasSuffix(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldHasSuffix(FieldUserId, v))
}

// UserIdEqualFold applies the EqualFold predicate on the "userId" field.
func UserIdEqualFold(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldEqualFold(FieldUserId, v))
}

// UserIdContainsFold applies the ContainsFold predicate on the "userId" field.
func UserIdContainsFold(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldContainsFold(FieldUserId, v))
}

// FriendIdEQ applies the EQ predicate on the "friendId" field.
func FriendIdEQ(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldEQ(FieldFriendId, v))
}

// FriendIdNEQ applies the NEQ predicate on the "friendId" field.
func FriendIdNEQ(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldNEQ(FieldFriendId, v))
}

// FriendIdIn applies the In predicate on the "friendId" field.
func FriendIdIn(vs ...string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldIn(FieldFriendId, vs...))
}

// FriendIdNotIn applies the NotIn predicate on the "friendId" field.
func FriendIdNotIn(vs ...string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldNotIn(FieldFriendId, vs...))
}

// FriendIdGT applies the GT predicate on the "friendId" field.
func FriendIdGT(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldGT(FieldFriendId, v))
}

// FriendIdGTE applies the GTE predicate on the "friendId" field.
func FriendIdGTE(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldGTE(FieldFriendId, v))
}

// FriendIdLT applies the LT predicate on the "friendId" field.
func FriendIdLT(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldLT(FieldFriendId, v))
}

// FriendIdLTE applies the LTE predicate on the "friendId" field.
func FriendIdLTE(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldLTE(FieldFriendId, v))
}

// FriendIdContains applies the Contains predicate on the "friendId" field.
func FriendIdContains(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldContains(FieldFriendId, v))
}

// FriendIdHasPrefix applies the HasPrefix predicate on the "friendId" field.
func FriendIdHasPrefix(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldHasPrefix(FieldFriendId, v))
}

// FriendIdHasSuffix applies the HasSuffix predicate on the "friendId" field.
func FriendIdHasSuffix(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldHasSuffix(FieldFriendId, v))
}

// FriendIdEqualFold applies the EqualFold predicate on the "friendId" field.
func FriendIdEqualFold(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldEqualFold(FieldFriendId, v))
}

// FriendIdContainsFold applies the ContainsFold predicate on the "friendId" field.
func FriendIdContainsFold(v string) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.FieldContainsFold(FieldFriendId, v))
}

// And groups predicates with the AND operator between them.
func And(predicates ...predicate.FriendRelationship) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.AndPredicates(predicates...))
}

// Or groups predicates with the OR operator between them.
func Or(predicates ...predicate.FriendRelationship) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.OrPredicates(predicates...))
}

// Not applies the not operator on the given predicate.
func Not(p predicate.FriendRelationship) predicate.FriendRelationship {
	return predicate.FriendRelationship(sql.NotPredicates(p))
}
