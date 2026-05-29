import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/category_store.dart';
import '../../core/models/category.dart';
import '../../core/services/category_manager.dart';
import '../../core/services/appearance_service.dart';
import '../../core/services/settings_service.dart';
import '../analytics/analytics_view_model.dart';
import '../../core/models/time_block_style.dart';
import '../../core/theme/app_theme.dart';

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

Future<void> _confirmRestoreDefaults(
  BuildContext context,
  CategoryStore store,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('기본 카테고리 복원'),
      content: const Text('숨긴 기본 카테고리(수면, 업무 등)를 다시 표시합니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('복원'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await store.restoreDefaults();
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);
    final svc = ref.read(settingsServiceProvider.notifier);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final blockStyle = ref.watch(appearanceServiceProvider);
    final appearanceSvc = ref.read(appearanceServiceProvider.notifier);
    final themeMode = ref.watch(themeModeServiceProvider);
    final themeModeSvc = ref.read(themeModeServiceProvider.notifier);

    final analytics = ref.read(analyticsViewModelProvider.notifier);
    final threshold = ref.watch(analyticsViewModelProvider).heatmapThreshold;

    return Scaffold(
      appBar: AppBar(
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
          const Divider(indent: 16, endIndent: 16),
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
          const Divider(indent: 16, endIndent: 16),
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
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '외관',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _ThemeModeToggle(
              value: themeMode,
              onChanged: themeModeSvc.setThemeMode,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _BlockStylePicker(
              value: blockStyle,
              onChanged: appearanceSvc.setBlockStyle,
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
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
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('기본 카테고리 복원'),
            subtitle: const Text('숨긴 기본 카테고리를 다시 표시합니다'),
            onTap: () => _confirmRestoreDefaults(
              context,
              ref.read(categoryStoreProvider),
            ),
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
            trailing: Row(
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
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDelete(context, ref, cat),
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
    WidgetRef ref,
    Category cat,
  ) async {
    if (cat.id == null) return;

    final manager = ref.read(categoryManagerProvider);
    final count = await manager.countByCategory(cat.id!);

    if (!context.mounted) return;

    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${cat.name}"을(를) 삭제합니다.'),
            if (count > 0) ...[
              const SizedBox(height: 8),
              Text(
                '이 카테고리로 기록된 시간 블록이 $count개 있습니다.',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, _DeleteChoice.withRecords),
            child: const Text(
              '기록도 삭제',
              style: TextStyle(color: Colors.red),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _DeleteChoice.keepRecords),
            child: const Text('기록 보존'),
          ),
        ],
      ),
    );

    if (choice != null) {
      await manager.deleteCategory(
        cat.id!,
        keepRecords: choice == _DeleteChoice.keepRecords,
      );
    }
  }
}

enum _DeleteChoice { withRecords, keepRecords }

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
                            color: Theme.of(context).colorScheme.primary,
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

class _BlockStylePicker extends StatelessWidget {
  final TimeBlockStyle value;
  final ValueChanged<TimeBlockStyle> onChanged;

  const _BlockStylePicker({required this.value, required this.onChanged});

  static const _options = [
    (TimeBlockStyle.tintBar, '틴트 + 바'),
    (TimeBlockStyle.card, '카드'),
    (TimeBlockStyle.roundedTint, '둥근 틴트'),
    (TimeBlockStyle.liquidGlass, 'Glass'),
  ];

  static const _previewColors = [
    Color(0xFF4ECDC4),
    Color(0xFFFF6B6B),
    Color(0xFF5856D6),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 106,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _options.length,
        separatorBuilder: (context, i) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (style, label) = _options[i];
          final selected = value == style;
          return GestureDetector(
            onTap: () => onChanged(style),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 80,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? primary : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(7, 8, 7, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _MiniBlock(
                            style: style,
                            color: _previewColors[0],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          flex: 2,
                          child: _MiniBlock(
                            style: style,
                            color: _previewColors[1],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? primary : const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniBlock extends StatelessWidget {
  final TimeBlockStyle style;
  final Color color;

  const _MiniBlock({required this.style, required this.color});

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case TimeBlockStyle.tintBar:
        return Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
            border: Border(left: BorderSide(color: color, width: 2)),
          ),
        );
      case TimeBlockStyle.card:
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      case TimeBlockStyle.roundedTint:
        return Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      case TimeBlockStyle.liquidGlass:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final gradient = isDark
            ? AppTheme.ambientGradientDark
            : AppTheme.ambientGradientLight;
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _ThemeModeToggle extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeToggle({required this.value, required this.onChanged});

  static const _options = [
    (ThemeMode.system, '시스템'),
    (ThemeMode.light, '라이트'),
    (ThemeMode.dark, '다크'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final activeBg = isDark ? Colors.white : Colors.black;
    final activeText = isDark ? Colors.black : Colors.white;
    final inactiveText = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: _options.map((opt) {
          final (mode, label) = opt;
          final selected = value == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: selected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? activeText : inactiveText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
