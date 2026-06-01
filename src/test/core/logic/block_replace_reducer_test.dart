import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/core/logic/block_replace_reducer.dart';
import 'package:time_tracker/core/models/date_key.dart';
import 'package:time_tracker/core/models/time_block.dart';

final _date = DateKey(2026, 5, 27);

TimeBlock _block({
  required int start,
  required int end,
  required int cat,
  int? id,
}) =>
    TimeBlock(date: _date, startMinute: start, endMinute: end, categoryId: cat, id: id);

void main() {
  group('applyBlockReplace', () {
    test('no overlap → single InsertOp', () {
      final ops = applyBlockReplace([], _block(start: 20, end: 30, cat: 1));
      expect(ops, hasLength(1));
      expect(ops.first, isA<InsertOp>());
      final insert = ops.first as InsertOp;
      expect(insert.block.startMinute, 20);
      expect(insert.block.endMinute, 30);
    });

    test('left overhang → UpdateOp trim + InsertOp new', () {
      // A(0,20,BLUE) trimmed to (0,10,BLUE) when new block (10,20,RED) placed
      final existing = [_block(start: 0, end: 20, cat: 1, id: 1)];
      final ops = applyBlockReplace(existing, _block(start: 10, end: 20, cat: 2));

      final updates = ops.whereType<UpdateOp>().toList();
      final inserts = ops.whereType<InsertOp>().toList();
      final deletes = ops.whereType<DeleteOp>().toList();

      expect(deletes, isEmpty);
      expect(updates, hasLength(1));
      expect(updates.first.block.endMinute, 10);
      expect(inserts, hasLength(1));
      expect(inserts.first.block.startMinute, 10);
      expect(inserts.first.block.endMinute, 20);
    });

    test('right overhang → UpdateOp trim + InsertOp new', () {
      // A(10,30,BLUE) trimmed to (20,30,BLUE) when new block (10,20,RED) placed
      final existing = [_block(start: 10, end: 30, cat: 1, id: 1)];
      final ops = applyBlockReplace(existing, _block(start: 10, end: 20, cat: 2));

      final updates = ops.whereType<UpdateOp>().toList();
      final inserts = ops.whereType<InsertOp>().toList();

      expect(updates, hasLength(1));
      expect(updates.first.block.startMinute, 20);
      expect(inserts, hasLength(1));
      expect(inserts.first.block.startMinute, 10);
      expect(inserts.first.block.endMinute, 20);
    });

    test('both overhang (split) → UpdateOp left + InsertOp right + InsertOp new', () {
      // A(0,60,BLUE) split → left(0,20,BLUE) + right(40,60,BLUE) + new(20,40,RED)
      final existing = [_block(start: 0, end: 60, cat: 1, id: 1)];
      final ops = applyBlockReplace(existing, _block(start: 20, end: 40, cat: 2));

      expect(ops.whereType<DeleteOp>(), isEmpty);
      expect(ops.whereType<UpdateOp>(), hasLength(1));
      final update = ops.whereType<UpdateOp>().first;
      expect(update.block.endMinute, 20); // left part trimmed

      final inserts = ops.whereType<InsertOp>().toList();
      expect(inserts, hasLength(2));
      final newBlock = inserts.firstWhere((i) => i.block.categoryId == 2);
      final rightPart = inserts.firstWhere((i) => i.block.categoryId == 1);
      expect(newBlock.block.startMinute, 20);
      expect(newBlock.block.endMinute, 40);
      expect(rightPart.block.startMinute, 40);
      expect(rightPart.block.endMinute, 60);
    });

    test('3-way same-category merge → UpdateOp extends prev, right-part absorbed', () {
      // A(0,60,RED) split by B(20,40,RED) same category → merged back to A(0,60,RED)
      final existing = [_block(start: 0, end: 60, cat: 1, id: 1)];
      final ops = applyBlockReplace(existing, _block(start: 20, end: 40, cat: 1));

      expect(ops.whereType<DeleteOp>(), isEmpty);
      expect(ops.whereType<InsertOp>(), isEmpty);
      final updates = ops.whereType<UpdateOp>().toList();
      // Two UpdateOps on A: first trim to (0,20), then extend to (0,60)
      expect(updates.last.block.startMinute, 0);
      expect(updates.last.block.endMinute, 60);
    });

    test('fully covered block deleted', () {
      final existing = [_block(start: 10, end: 20, cat: 1, id: 1)];
      final ops = applyBlockReplace(existing, _block(start: 0, end: 30, cat: 2));

      expect(ops.whereType<DeleteOp>(), hasLength(1));
      expect(ops.whereType<InsertOp>(), hasLength(1));
      expect(ops.whereType<UpdateOp>(), isEmpty);
    });

    test('adjacent same-category left → extends prev, no insert', () {
      // P(0,20,RED) adjacent left to new B(20,30,RED) → merged to (0,30,RED)
      final existing = [_block(start: 0, end: 20, cat: 1, id: 1)];
      final ops = applyBlockReplace(existing, _block(start: 20, end: 30, cat: 1));

      expect(ops.whereType<InsertOp>(), isEmpty);
      expect(ops.whereType<DeleteOp>(), isEmpty);
      final updates = ops.whereType<UpdateOp>().toList();
      expect(updates, hasLength(1));
      expect(updates.first.block.startMinute, 0);
      expect(updates.first.block.endMinute, 30);
    });

    test('adjacent same-category right → extends next, no insert', () {
      // N(30,50,RED) adjacent right to new B(20,30,RED) → merged to (20,50,RED)
      final existing = [_block(start: 30, end: 50, cat: 1, id: 1)];
      final ops = applyBlockReplace(existing, _block(start: 20, end: 30, cat: 1));

      expect(ops.whereType<InsertOp>(), isEmpty);
      expect(ops.whereType<DeleteOp>(), isEmpty);
      final updates = ops.whereType<UpdateOp>().toList();
      expect(updates, hasLength(1));
      expect(updates.first.block.startMinute, 20);
      expect(updates.first.block.endMinute, 50);
    });
  });
}
