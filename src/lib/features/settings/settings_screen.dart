import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/models/category.dart';
import '../../core/services/settings_service.dart';
import '../analytics/analytics_view_model.dart';

const _kColorOptions = [
  '#EF5350',
  '#FF7043',
  '#FFA726',
  '#FFEE58',
  '#66BB6A',
  '#26A69A',
  '#26C6DA',
  '#42A5F5',
  '#5C6BC0',
  '#AB47BC',
  '#EC407A',
  '#78909C',
];

Color _hexToColor(String hex) {
  final code = hex.replaceFirst('#', '');
  return Color(int.parse('FF$code', radix: 16));
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);
    final svc = ref.read(settingsServiceProvider.notifier);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    final analytics = ref.read(analyticsViewModelProvider.notifier);
    final threshold = ref.watch(analyticsViewModelProvider).heatmapThreshold;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('설정'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('스마트 알림'),
            subtitle: const Text('3시간 이상 기록 공백 감지 시 알림'),
            value: settings.enabled,
            onChanged: (v) => svc.setEnabled(v),
          ),
          const Divider(),
          _TimePickerTile(
            label: '취침 시작',
            minuteFromMidnight: settings.sleepStartMinute,
            onChanged: (m) => svc.setSleepStart(m),
            enabled: settings.enabled,
          ),
          _TimePickerTile(
            label: '기상 시간',
            minuteFromMidnight: settings.sleepEndMinute,
            onChanged: (m) => svc.setSleepEnd(m),
            enabled: settings.enabled,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '분석',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          ListTile(
            title: const Text('히트맵 최소 기록 수'),
            subtitle: Text('$threshold개 미만이면 히트맵 대신 안내 문구 표시'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: threshold > 1
                      ? () => analytics.setHeatmapThreshold(threshold - 1)
                      : null,
                ),
                Text('$threshold', style: const TextStyle(fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: threshold < 30
                      ? () => analytics.setHeatmapThreshold(threshold + 1)
                      : null,
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '카테고리 관리',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          categoriesAsync.when(
            data: (categories) => _CategoryList(categories: categories),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListTile(title: Text('오류: $e')),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final List<Category> categories;

  const _CategoryList({required this.categories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(categoryStoreProvider);

    return Column(
      children: [
        ...categories.map((cat) {
          return ListTile(
            leading: CircleAvatar(
              radius: 12,
              backgroundColor: _hexToColor(cat.colorHex),
            ),
            title: Text(cat.name),
            trailing: cat.isPreset
                ? const Text('기본',
                    style: TextStyle(fontSize: 12, color: Colors.grey))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showCategoryForm(
                          context,
                          store,
                          existing: cat,
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, size: 20),
                        onPressed: () =>
                            _confirmDelete(context, store, cat),
                      ),
                    ],
                  ),
          );
        }),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('카테고리 추가'),
          onTap: () => _showCategoryForm(context, store),
        ),
      ],
    );
  }

  Future<void> _showCategoryForm(
    BuildContext context,
    CategoryStore store, {
    Category? existing,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _CategoryFormDialog(store: store, existing: existing),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryStore store,
    Category cat,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text('"${cat.name}" 카테고리를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && cat.id != null) {
      await store.delete(cat.id!);
    }
  }
}

class _CategoryFormDialog extends StatefulWidget {
  final CategoryStore store;
  final Category? existing;

  const _CategoryFormDialog({required this.store, this.existing});

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _nameCtrl;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.existing?.name ?? '');
    _selectedColor =
        widget.existing?.colorHex ?? _kColorOptions.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? '카테고리 수정' : '카테고리 추가'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '예: 독서',
            ),
            autofocus: true,
            maxLength: 12,
          ),
          const SizedBox(height: 12),
          const Text('색상', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kColorOptions.map((hex) {
              final selected = hex == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hexToColor(hex),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(
                            color: Colors.black87,
                            width: 2.5,
                          )
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          size: 16, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? '저장' : '추가'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    if (widget.existing != null) {
      await widget.store.update(
        widget.existing!.copyWith(
          name: name,
          colorHex: _selectedColor,
        ),
      );
    } else {
      await widget.store.insert(
        Category(name: name, colorHex: _selectedColor),
      );
    }
    if (mounted) Navigator.pop(context);
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final int minuteFromMidnight;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const _TimePickerTile({
    required this.label,
    required this.minuteFromMidnight,
    required this.onChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final h = minuteFromMidnight ~/ 60;
    final m = minuteFromMidnight % 60;
    final timeStr =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    return ListTile(
      title: Text(label),
      trailing: Text(
        timeStr,
        style: TextStyle(
          fontSize: 16,
          color: enabled ? null : Theme.of(context).disabledColor,
        ),
      ),
      enabled: enabled,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: h, minute: m),
        );
        if (picked != null) {
          onChanged(picked.hour * 60 + picked.minute);
        }
      },
    );
  }
}
