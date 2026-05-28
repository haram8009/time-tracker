import '../models/time_block.dart';

sealed class BlockOp {}

class InsertOp extends BlockOp {
  final TimeBlock block;
  InsertOp(this.block);
}

class UpdateOp extends BlockOp {
  final TimeBlock block;
  UpdateOp(this.block);
}

class DeleteOp extends BlockOp {
  final int id;
  DeleteOp(this.id);
}

/// Pure function: computes the DB operations needed to replace [newBlock]'s
/// time range within [existing] blocks for the same date.
///
/// Handles all overlap cases and same-category adjacency merging (ADR-0002).
List<BlockOp> applyBlockReplace(List<TimeBlock> existing, TimeBlock newBlock) {
  final ops = <BlockOp>[];
  TimeBlock? pendingRightPart; // right-part from a split (no DB id yet)

  // Step 1 — handle overlapping blocks
  for (final b in existing) {
    if (b.startMinute >= newBlock.endMinute || b.endMinute <= newBlock.startMinute) continue;

    final leftOverhang = b.startMinute < newBlock.startMinute;
    final rightOverhang = b.endMinute > newBlock.endMinute;

    if (leftOverhang && rightOverhang) {
      ops.add(UpdateOp(b.copyWith(endMinute: newBlock.startMinute)));
      pendingRightPart = TimeBlock(
        date: b.date,
        startMinute: newBlock.endMinute,
        endMinute: b.endMinute,
        categoryId: b.categoryId,
        note: b.note,
      );
    } else if (leftOverhang) {
      ops.add(UpdateOp(b.copyWith(endMinute: newBlock.startMinute)));
    } else if (rightOverhang) {
      ops.add(UpdateOp(b.copyWith(startMinute: newBlock.endMinute)));
    } else {
      ops.add(DeleteOp(b.id!));
    }
  }

  // Step 2 — build virtual post-overlap state for adjacency lookup
  final virtual = <TimeBlock>[
    for (final b in existing)
      if (b.startMinute >= newBlock.endMinute || b.endMinute <= newBlock.startMinute) b,
    for (final op in ops)
      if (op is UpdateOp) op.block,
    ?pendingRightPart,
  ];

  // Step 3 — find adjacent same-category blocks
  final prev = virtual
      .where((b) =>
          b.categoryId == newBlock.categoryId && b.endMinute == newBlock.startMinute)
      .firstOrNull;
  final next = virtual
      .where((b) =>
          b.categoryId == newBlock.categoryId && b.startMinute == newBlock.endMinute)
      .firstOrNull;

  if (prev != null && next != null) {
    // 3-way merge: extend prev to cover newBlock and next
    ops.add(UpdateOp(prev.copyWith(endMinute: next.endMinute)));
    if (next.id != null) ops.add(DeleteOp(next.id!));
    // If next is pendingRightPart (no id), it's absorbed — no insert needed
  } else if (prev != null) {
    ops.add(UpdateOp(prev.copyWith(endMinute: newBlock.endMinute)));
    if (pendingRightPart != null) ops.add(InsertOp(pendingRightPart));
  } else if (next != null) {
    if (next.id != null) {
      ops.add(UpdateOp(next.copyWith(startMinute: newBlock.startMinute)));
    } else {
      // next is pendingRightPart — insert it merged with newBlock range
      ops.add(InsertOp(next.copyWith(startMinute: newBlock.startMinute)));
    }
  } else {
    final toInsert = newBlock.id != null ? newBlock.copyWith(id: null) : newBlock;
    ops.add(InsertOp(toInsert));
    if (pendingRightPart != null) ops.add(InsertOp(pendingRightPart));
  }

  return ops;
}
