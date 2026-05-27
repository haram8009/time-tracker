import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsServiceProvider);
    final svc = ref.read(settingsServiceProvider.notifier);

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
        ],
      ),
    );
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
