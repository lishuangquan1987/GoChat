// Code generated by ent, DO NOT EDIT.

package ent

import (
	"context"
	"gochat_server/ent/groupchatrecord"
	"gochat_server/ent/predicate"

	"entgo.io/ent/dialect/sql"
	"entgo.io/ent/dialect/sql/sqlgraph"
	"entgo.io/ent/schema/field"
)

// GroupChatRecordDelete is the builder for deleting a GroupChatRecord entity.
type GroupChatRecordDelete struct {
	config
	hooks    []Hook
	mutation *GroupChatRecordMutation
}

// Where appends a list predicates to the GroupChatRecordDelete builder.
func (gcrd *GroupChatRecordDelete) Where(ps ...predicate.GroupChatRecord) *GroupChatRecordDelete {
	gcrd.mutation.Where(ps...)
	return gcrd
}

// Exec executes the deletion query and returns how many vertices were deleted.
func (gcrd *GroupChatRecordDelete) Exec(ctx context.Context) (int, error) {
	return withHooks(ctx, gcrd.sqlExec, gcrd.mutation, gcrd.hooks)
}

// ExecX is like Exec, but panics if an error occurs.
func (gcrd *GroupChatRecordDelete) ExecX(ctx context.Context) int {
	n, err := gcrd.Exec(ctx)
	if err != nil {
		panic(err)
	}
	return n
}

func (gcrd *GroupChatRecordDelete) sqlExec(ctx context.Context) (int, error) {
	_spec := sqlgraph.NewDeleteSpec(groupchatrecord.Table, sqlgraph.NewFieldSpec(groupchatrecord.FieldID, field.TypeInt))
	if ps := gcrd.mutation.predicates; len(ps) > 0 {
		_spec.Predicate = func(selector *sql.Selector) {
			for i := range ps {
				ps[i](selector)
			}
		}
	}
	affected, err := sqlgraph.DeleteNodes(ctx, gcrd.driver, _spec)
	if err != nil && sqlgraph.IsConstraintError(err) {
		err = &ConstraintError{msg: err.Error(), wrap: err}
	}
	gcrd.mutation.done = true
	return affected, err
}

// GroupChatRecordDeleteOne is the builder for deleting a single GroupChatRecord entity.
type GroupChatRecordDeleteOne struct {
	gcrd *GroupChatRecordDelete
}

// Where appends a list predicates to the GroupChatRecordDelete builder.
func (gcrdo *GroupChatRecordDeleteOne) Where(ps ...predicate.GroupChatRecord) *GroupChatRecordDeleteOne {
	gcrdo.gcrd.mutation.Where(ps...)
	return gcrdo
}

// Exec executes the deletion query.
func (gcrdo *GroupChatRecordDeleteOne) Exec(ctx context.Context) error {
	n, err := gcrdo.gcrd.Exec(ctx)
	switch {
	case err != nil:
		return err
	case n == 0:
		return &NotFoundError{groupchatrecord.Label}
	default:
		return nil
	}
}

// ExecX is like Exec, but panics if an error occurs.
func (gcrdo *GroupChatRecordDeleteOne) ExecX(ctx context.Context) {
	if err := gcrdo.Exec(ctx); err != nil {
		panic(err)
	}
}
