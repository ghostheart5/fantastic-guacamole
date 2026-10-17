import 'package:fantastic_guacamole/domain/entities/goal_entity.dart';
import 'package:fantastic_guacamole/domain/entities/task_entity.dart';
import 'package:fantastic_guacamole/features/tasks/widgets/task_edit_dialog.dart';
import 'package:fantastic_guacamole/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _titleKey = Key('timeline-task-title-field');
const _priorityKey = Key('timeline-task-priority-field');
const _goalKey = Key('timeline-task-goal-field');
const _durationKey = Key('timeline-task-duration-field');
const _deadlineKey = Key('timeline-task-deadline-field');
const _scheduleKey = Key('timeline-task-schedule-field');
const _devicePixelRatio = 2.5;
const _logicalHeight = 432.0;
const _statusBarHeight = 24.0;
// A representative landscape IME, not a measured native keyboard height.
const _keyboardHeight = 220.0;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fonts = FontLoader('Inter');
    for (final asset in <String>[
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-Medium.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ]) {
      fonts.addFont(rootBundle.load(asset));
    }
    await fonts.load();
  });

  testWidgets(
    'landscape keyboard leaves fields reachable and Save returns the edited draft',
    (tester) async {
      final task = _task();
      final original = task.toJson();
      final results = <TaskEditDraft?>[];
      // Full Moto display: 2460x1080 physical pixels at DPR 2.5.
      await _pumpHarness(tester, task, results, logicalWidth: 984);
      await _openEditor(tester);
      _showKeyboardInset(tester);
      await tester.pumpAndSettle();

      final title = find.byKey(_titleKey);
      await _reachControl(tester, title);
      expect(_editable(tester, _titleKey).focusNode.hasFocus, isTrue);
      await tester.enterText(title, '  Changed landscape task  ');
      await tester.pumpAndSettle();
      await _reachControl(tester, title);
      expect(
        _editable(tester, _titleKey).controller.text,
        '  Changed landscape task  ',
      );

      final priority = find.byKey(_priorityKey);
      await _reachControl(tester, priority);
      expect(tester.state<FormFieldState<int>>(priority).value, 3);
      await tester.tap(priority);
      await tester.pumpAndSettle();
      final highest = find.text('5 \u00b7 highest').last;
      await tester.ensureVisible(highest);
      await tester.pumpAndSettle();
      await tester.tap(highest);
      await tester.pumpAndSettle();
      expect(tester.state<FormFieldState<int>>(priority).value, 5);

      await _reachControl(tester, find.byKey(_goalKey));
      expect(
        tester.state<FormFieldState<String?>>(find.byKey(_goalKey)).value,
        task.goalId,
      );
      final duration = find.byKey(_durationKey);
      await _reachControl(tester, duration);
      await tester.enterText(duration, '45');
      await tester.pumpAndSettle();
      await _reachControl(tester, duration);
      expect(_editable(tester, _durationKey).controller.text, '45');
      expect(tester.testTextInput.isVisible, isTrue);
      await _reachControl(tester, find.byKey(_deadlineKey));
      await _reachControl(tester, find.byKey(_scheduleKey));
      _expectActionsReachable(tester);
      _expectKeyboardInset(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(results, hasLength(1));
      final draft = results.single!;
      expect(draft.title, 'Changed landscape task');
      expect(draft.description, task.description);
      expect(draft.priority, 5);
      expect(draft.estimatedDuration, const Duration(minutes: 45));
      expect(draft.scheduledFor, task.scheduledFor);
      expect(draft.dueDate, task.dueDate);
      expect(draft.goalId, task.goalId);
      // This helper returns a draft; no persistence adapter is involved.
      expect(task.toJson(), original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landscape keyboard preserves validation and Cancel discards edits on reopen',
    (tester) async {
      final task = _task();
      final original = task.toJson();
      final results = <TaskEditDraft?>[];
      // Also cover the 2340px app window after the native side navigation area.
      await _pumpHarness(tester, task, results, logicalWidth: 936);
      await _openEditor(tester);
      _showKeyboardInset(tester);
      await tester.pumpAndSettle();

      final title = find.byKey(_titleKey);
      await _reachControl(tester, title);
      await tester.enterText(title, '   ');
      await tester.pumpAndSettle();
      _expectActionsReachable(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a task title.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(results, isEmpty);
      await _reachControl(tester, title);
      await tester.enterText(title, 'UNSAVED LANDSCAPE DRAFT');
      await tester.pumpAndSettle();

      final duration = find.byKey(_durationKey);
      await _reachControl(tester, duration);
      await tester.enterText(duration, '0');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Use 1 to 1440 minutes.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(results, isEmpty);
      await _reachControl(tester, duration);
      await tester.enterText(duration, '60');
      await tester.pumpAndSettle();
      await _reachControl(tester, find.byKey(_scheduleKey));
      _expectActionsReachable(tester);
      _expectKeyboardInset(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(results, hasLength(1));
      expect(results.single, isNull);
      expect(task.toJson(), original);

      await _openEditor(tester);
      _expectKeyboardInset(tester);
      await _reachControl(tester, title);
      expect(_editable(tester, _titleKey).controller.text, task.title);
      expect(find.text('UNSAVED LANDSCAPE DRAFT'), findsNothing);
      await _reachControl(tester, find.byKey(_priorityKey));
      expect(
        tester.state<FormFieldState<int>>(find.byKey(_priorityKey)).value,
        3,
      );
      await _reachControl(tester, duration);
      expect(_editable(tester, _durationKey).controller.text, '30');
      await _reachControl(tester, find.byKey(_scheduleKey));
      _expectActionsReachable(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(results, hasLength(2));
      expect(results.every((result) => result == null), isTrue);
      expect(task.toJson(), original);
      expect(tester.takeException(), isNull);
    },
  );
}

TaskEntity _task() => TaskEntity(
  id: 'landscape-draft-fixture',
  title: 'Original landscape task',
  description: 'Synthetic context',
  createdAt: DateTime(2026, 10, 16),
  priority: 3,
  estimatedDuration: const Duration(minutes: 30),
  scheduledFor: DateTime(2026, 10, 16, 21, 36),
  dueDate: DateTime(2026, 10, 17),
  goalId: 'landscape-goal-fixture',
);

Future<void> _pumpHarness(
  WidgetTester tester,
  TaskEntity task,
  List<TaskEditDraft?> results, {
  required double logicalWidth,
}) async {
  tester.view.physicalSize = Size(
    logicalWidth * _devicePixelRatio,
    _logicalHeight * _devicePixelRatio,
  );
  tester.view.devicePixelRatio = _devicePixelRatio;
  // Exercise the route's real SafeArea, including the top system obstruction.
  tester.view.padding = const FakeViewPadding(
    top: _statusBarHeight * _devicePixelRatio,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBarHeight * _devicePixelRatio,
  );
  tester.view.viewInsets = const FakeViewPadding();
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                results.add(
                  await showTaskEditDialog(
                    context: context,
                    editable: task,
                    goals: <GoalEntity>[
                      GoalEntity(
                        id: task.goalId!,
                        title: 'Linked goal',
                        createdAt: task.createdAt,
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open task editor'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Open task editor'));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

void _showKeyboardInset(WidgetTester tester) {
  // Change metrics after autofocus, rather than starting with a smaller screen.
  tester.view.viewInsets = const FakeViewPadding(
    bottom: _keyboardHeight * _devicePixelRatio,
  );
}

void _expectKeyboardInset(WidgetTester tester) {
  expect(
    tester.view.viewInsets.bottom / tester.view.devicePixelRatio,
    _keyboardHeight,
  );
}

EditableText _editable(WidgetTester tester, Key fieldKey) =>
    tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(fieldKey),
        matching: find.byType(EditableText),
      ),
    );

Future<void> _reachControl(WidgetTester tester, Finder control) async {
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  _expectKeyboardInset(tester);
  final box = tester.renderObject<RenderBox>(control);
  final viewport = RenderAbstractViewport.of(box);
  final viewportBox = viewport as RenderBox;
  expect(
    viewportBox.size.height,
    greaterThan(0),
    reason: 'A form built inside a zero-height viewport is still unusable.',
  );
  final children = <RenderObject>[];
  viewport.visitChildren(children.add);
  expect(children, hasLength(1));
  final clip = viewport.describeApproximatePaintClip(children.single);
  expect(
    clip,
    isNotNull,
    reason: 'The overflowing form must retain its actual viewport clip.',
  );
  expect(box.size.width, greaterThan(0));
  expect(box.size.height, greaterThan(0));
  final bounds = MatrixUtils.transformRect(
    box.getTransformTo(viewport),
    Offset.zero & box.size,
  );
  _expectContained(bounds, clip!);
  _expectAboveKeyboard(tester, control);
  expect(control.hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

void _expectActionsReachable(WidgetTester tester) {
  for (final action in <Finder>[
    find.widgetWithText(TextButton, 'Cancel'),
    find.widgetWithText(FilledButton, 'Save'),
  ]) {
    _expectAboveKeyboard(tester, action);
    expect(action.hitTestable(), findsOneWidget);
  }
}

void _expectAboveKeyboard(WidgetTester tester, Finder control) {
  final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  _expectContained(
    tester.getRect(control),
    Rect.fromLTWH(
      0,
      _statusBarHeight,
      logicalSize.width,
      logicalSize.height - _keyboardHeight - _statusBarHeight,
    ),
  );
}

void _expectContained(Rect control, Rect visible) {
  expect(control.left, greaterThanOrEqualTo(visible.left - 0.01));
  expect(control.top, greaterThanOrEqualTo(visible.top - 0.01));
  expect(control.right, lessThanOrEqualTo(visible.right + 0.01));
  expect(control.bottom, lessThanOrEqualTo(visible.bottom + 0.01));
}
