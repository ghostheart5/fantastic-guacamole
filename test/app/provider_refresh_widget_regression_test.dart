import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _sourceProvider = NotifierProvider<_Source, int>(_Source.new);
final _derivedProvider = Provider<int>((ref) => ref.watch(_sourceProvider) * 2);
final _dependentProvider = Provider<int>(
  (ref) => ref.watch(_derivedProvider) + 1,
);

class _Source extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

void main() {
  testWidgets(
    'remounting a dirty provider graph does not refresh its scope during build',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final show = ValueNotifier<bool>(true);
      addTearDown(show.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (context, visible, child) => visible
                  ? Consumer(
                      builder: (context, ref, child) {
                        final derived = ref.watch(_derivedProvider);
                        final dependent = ref.watch(_dependentProvider);
                        return Text('$derived/$dependent');
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );
      expect(find.text('0/1'), findsOneWidget);
      show.value = false;
      await tester.pump();
      await tester.pump();
      container.read(_sourceProvider.notifier).increment();
      await tester.pump();
      await tester.pump();
      show.value = true;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('2/3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
