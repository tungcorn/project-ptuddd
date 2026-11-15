import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../songs/domain/song.dart';
import '../domain/app_user.dart';

/// One placement question (section 7.2: quick 5-question test).
class PlacementQuestion {
  const PlacementQuestion(this.level, this.prompt, this.options, this.answer);

  final String level;
  final String prompt;
  final List<String> options;
  final int answer;
}

/// Ordered from easy (A1) to hard (B2).
const placementQuestions = [
  PlacementQuestion('A1', '“Silent night, holy night” — “night” nghĩa là gì?',
      ['Ngày', 'Đêm', 'Buổi sáng', 'Mùa đông'], 1),
  PlacementQuestion('A1', 'Chọn từ đúng: “My Bonnie ___ over the ocean.”',
      ['lie', 'lies', 'lying', 'lain'], 1),
  PlacementQuestion('A2', '“Take me out to the ball game” có nghĩa gần nhất là:',
      ['Hãy đưa tôi đi xem trận bóng chày', 'Hãy mang quả bóng ra ngoài',
       'Tôi bị loại khỏi trận đấu', 'Trận bóng đã kết thúc'], 0),
  PlacementQuestion('B1', 'Chọn câu đúng ngữ pháp:',
      ['If I would know, I tell you.', 'If I knew, I would tell you.',
       'If I know, I would told you.', 'If I knowed, I will tell you.'], 1),
  PlacementQuestion('B2', '“I once was lost, but now am found” diễn tả điều gì?',
      ['Một người bị lạc đường đến nay vẫn lạc', 'Sự thay đổi từ lầm lạc sang được cứu rỗi',
       'Một người tìm thấy đồ vật bị mất', 'Lời xin lỗi vì đến muộn'], 1),
];

/// Maps the number of correct answers (0–5) to a CEFR level.
String levelForScore(int correct) {
  if (correct <= 1) return 'A1';
  if (correct == 2) return 'A2';
  if (correct <= 4) return 'B1';
  return 'B2';
}

class PlacementScreen extends ConsumerStatefulWidget {
  const PlacementScreen({super.key});

  @override
  ConsumerState<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends ConsumerState<PlacementScreen> {
  int _index = 0;
  int _correct = 0;
  int? _picked;
  String? _result;

  Future<void> _finish(String level) async {
    await ref.read(authRepositoryProvider).updateProfile(level: level);
    // Router redirects to /home once the level is set.
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    if (_result != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.emoji_events, size: 72, color: t.colorScheme.tertiary),
                const SizedBox(height: 12),
                Text('Bạn trả lời đúng $_correct/${placementQuestions.length} câu',
                    style: t.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Trình độ gợi ý: $_result',
                    key: const Key('placement-result'),
                    style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('placement-accept'),
                  onPressed: () => _finish(_result!),
                  child: const Text('Bắt đầu học'),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  for (final l in cefrLevels)
                    if (l != _result)
                      OutlinedButton(onPressed: () => _finish(l), child: Text('Chọn $l')),
                ]),
              ]),
            ),
          ),
        ),
      );
    }
    final q = placementQuestions[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text('Kiểm tra trình độ (${_index + 1}/${placementQuestions.length})'),
        actions: [
          TextButton(
            onPressed: () => _showManualPicker(context),
            child: const Text('Bỏ qua'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (user != null && user.displayName.isNotEmpty && _index == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Chào ${user.displayName}! Trả lời nhanh 5 câu để SingLearn gợi ý '
                  'bài hát phù hợp trình độ của bạn.',
                ),
              ),
            LinearProgressIndicator(value: (_index) / placementQuestions.length),
            const SizedBox(height: 20),
            Text(q.prompt, style: t.textTheme.titleMedium),
            const SizedBox(height: 16),
            for (var i = 0; i < q.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionTile(
                  text: q.options[i],
                  selected: _picked == i,
                  onTap: () => setState(() => _picked = i),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('placement-next'),
              onPressed: _picked == null
                  ? null
                  : () => setState(() {
                        if (_picked == q.answer) _correct++;
                        _picked = null;
                        if (_index + 1 >= placementQuestions.length) {
                          _result = levelForScore(_correct);
                        } else {
                          _index++;
                        }
                      }),
              child: Text(_index + 1 >= placementQuestions.length ? 'Xem kết quả' : 'Tiếp'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Chọn trình độ của bạn')),
          for (final l in cefrLevels)
            ListTile(
              title: Text(l),
              subtitle: Text(const {
                'A1': 'Mới bắt đầu',
                'A2': 'Sơ cấp',
                'B1': 'Trung cấp',
                'B2': 'Trung cao cấp',
              }[l]!),
              onTap: () {
                Navigator.pop(context);
                _finish(l);
              },
            ),
        ]),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: selected ? c.primaryContainer : c.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? c.primary : c.outline),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ]),
        ),
      ),
    );
  }
}

/// Recommended level for song suggestions: user level or A1.
String userLevel(AppUser? u) => u?.level ?? 'A1';
