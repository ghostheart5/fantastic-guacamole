import 'package:fantastic_guacamole/domain/entities/flowmap_node.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlowmapScreen extends ConsumerWidget {
  const FlowmapScreen({super.key});

  static const String _featureReadPathFlag = 'flowmap_feature_read_path';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool useFeatureReadPath = ref.watch(
      featureFlagEnabledProvider(_featureReadPathFlag),
    );
    final AsyncValue<List<FlowmapNode>> legacyState = ref.watch(
      flowmapProvider,
    );
    final AsyncValue<List<FlowmapNode>> featureState = ref
        .watch(featureFlowmapGraphProvider)
        .whenData(
          (graph) =>
              graph.nodes
                  .map(
                    (node) => FlowmapNode(
                      id: node.id,
                      title: node.title,
                      description: node.description,
                      tags: node.tags,
                      createdAt: node.createdAt ?? DateTime.now(),
                    ),
                  )
                  .toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );

    final AsyncValue<List<FlowmapNode>> state =
        useFeatureReadPath && featureState.hasValue
        ? featureState
        : legacyState;

    return Scaffold(
      backgroundColor: const Color(0xFF0B111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B111C),
        elevation: 0,
        leading: SmartPressable(
          onTap: () => ref.read(appFlowProvider.notifier).toCoach(),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.neonCyan,
            size: 18,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.neonCyan, AppColors.neonViolet],
              ).createShader(bounds),
              child: const Text(
                'FLOWMAP',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
            ),
            const Text(
              'ADAPTIVE MAP CORE',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.neonCyan.withValues(alpha: 0.15),
        foregroundColor: AppColors.neonCyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.4)),
        ),
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.account_tree_outlined),
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.neonCyan,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(color: AppColors.recallRed, fontSize: 13),
          ),
        ),
        data: (nodes) => nodes.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _FlowSummaryStrip(nodes: nodes),
                  const SizedBox(height: 10),
                  ...nodes.map((FlowmapNode node) => _NodeCard(node: node)),
                ],
              ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _AddNodeSheet(
        onAdd: (title, description, tags) {
          ref
              .read(flowmapProvider.notifier)
              .addNode(
                title: title,
                description: description,
                tags: tags,
                refreshCoach: true,
                syncSoulMap: true,
                updateInsights: true,
                awardProgression: true,
              );
        },
      ),
    );
  }
}

class _NodeCard extends ConsumerWidget {
  const _NodeCard({required this.node});

  final FlowmapNode node;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? description = node.description;
    final List<_FlowField> fields = _parseFlowFields(description);
    final List<String> contextTags = node.tags
        .where((String tag) => !tag.startsWith('analytics:'))
        .toList(growable: false);
    final List<String> analyticsTags = node.tags
        .where((String tag) => tag.startsWith('analytics:'))
        .map((String tag) => tag.replaceFirst('analytics:', ''))
        .toList(growable: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 20,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: AppColors.neonCyan,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  if (fields.isEmpty)
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fields
                          .take(6)
                          .map(
                            (_FlowField field) => _FlowFieldRow(field: field),
                          )
                          .toList(growable: false),
                    ),
                ],
                if (contextTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: contextTags
                        .map((String tag) => _Tag(tag))
                        .toList(),
                  ),
                ],
                if (analyticsTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: analyticsTags
                        .map(
                          (String event) => _Tag(
                            'event:$event',
                            accent: AppColors.memoryAmber,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
          SmartPressable(
            onTap: () => ref.read(flowmapProvider.notifier).deleteNode(node.id),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.accent = AppColors.neonViolet});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.neonViolet,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 48,
            color: AppColors.neonCyan.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'NO FLOW NODES',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap + to create your first node',
            style: TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AddNodeSheet extends StatefulWidget {
  const _AddNodeSheet({required this.onAdd});

  final void Function(String title, String? description, List<String> tags)
  onAdd;

  @override
  State<_AddNodeSheet> createState() => _AddNodeSheetState();
}

class _AddNodeSheetState extends State<_AddNodeSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _triggerCtrl = TextEditingController();
  final _screenCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _useCaseCtrl = TextEditingController();
  final _repositoryCtrl = TextEditingController();
  final _dataSourceCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _outputCtrl = TextEditingController();
  final _savedDataCtrl = TextEditingController();
  final _errorsCtrl = TextEditingController();
  final _fallbackCtrl = TextEditingController();
  final _analyticsCtrl = TextEditingController();
  _FlowTemplate? _selectedTemplate;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _triggerCtrl.dispose();
    _screenCtrl.dispose();
    _providerCtrl.dispose();
    _useCaseCtrl.dispose();
    _repositoryCtrl.dispose();
    _dataSourceCtrl.dispose();
    _servicesCtrl.dispose();
    _outputCtrl.dispose();
    _savedDataCtrl.dispose();
    _errorsCtrl.dispose();
    _fallbackCtrl.dispose();
    _analyticsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final List<String> tags = _tagsCtrl.text
        .split(',')
        .map((String t) => t.trim())
        .where((String t) => t.isNotEmpty)
        .toList(growable: true);

    final String normalizedTitleTag = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalizedTitleTag.isNotEmpty &&
        !tags.contains('feature:$normalizedTitleTag')) {
      tags.add('feature:$normalizedTitleTag');
    }

    final String analyticsEvent = _analyticsCtrl.text.trim();
    if (analyticsEvent.isNotEmpty &&
        !tags.contains('analytics:$analyticsEvent')) {
      tags.add('analytics:$analyticsEvent');
    }

    final String structuredDescription = _buildStructuredDescription(
      overview: _descCtrl.text.trim(),
      trigger: _triggerCtrl.text.trim(),
      screen: _screenCtrl.text.trim(),
      provider: _providerCtrl.text.trim(),
      useCase: _useCaseCtrl.text.trim(),
      repository: _repositoryCtrl.text.trim(),
      dataSource: _dataSourceCtrl.text.trim(),
      services: _servicesCtrl.text.trim(),
      output: _outputCtrl.text.trim(),
      savedData: _savedDataCtrl.text.trim(),
      errors: _errorsCtrl.text.trim(),
      fallback: _fallbackCtrl.text.trim(),
      analyticsEvent: analyticsEvent,
    );

    widget.onAdd(
      title,
      structuredDescription.isEmpty ? null : structuredDescription,
      tags,
    );
    Navigator.of(context).pop();
  }

  void _applyTemplate(_FlowTemplate template) {
    _titleCtrl.text = template.feature;
    _descCtrl.text = template.overview;
    _triggerCtrl.text = template.trigger;
    _screenCtrl.text = template.screen;
    _providerCtrl.text = template.provider;
    _useCaseCtrl.text = template.useCase;
    _repositoryCtrl.text = template.repository;
    _dataSourceCtrl.text = template.dataSource;
    _servicesCtrl.text = template.services;
    _outputCtrl.text = template.output;
    _savedDataCtrl.text = template.savedData;
    _errorsCtrl.text = template.errors;
    _fallbackCtrl.text = template.fallback;
    _analyticsCtrl.text = template.analyticsEvent;
    _tagsCtrl.text = template.tags.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          mediaQuery.viewInsets.bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'CREATE FLOW BLUEPRINT',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neonCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<_FlowTemplate>(
                  initialValue: _selectedTemplate,
                  dropdownColor: const Color(0xFF0D1420),
                  decoration: InputDecoration(
                    hintText: 'Create from template (optional)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.neonCyan.withValues(alpha: 0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.neonCyan.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.neonCyan.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  items: _flowTemplates
                      .map(
                        (_FlowTemplate template) =>
                            DropdownMenuItem<_FlowTemplate>(
                              value: template,
                              child: Text(
                                template.feature,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (_FlowTemplate? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedTemplate = value);
                    _applyTemplate(value);
                  },
                ),
                const SizedBox(height: 10),
                _SheetField(controller: _titleCtrl, hint: 'Feature name *'),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _descCtrl,
                  hint: 'Overview / intent (optional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _triggerCtrl,
                  hint: 'Trigger (what starts flow)',
                ),
                const SizedBox(height: 10),
                _SheetField(controller: _screenCtrl, hint: 'Screen'),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _providerCtrl,
                  hint: 'Provider / Controller',
                ),
                const SizedBox(height: 10),
                _SheetField(controller: _useCaseCtrl, hint: 'Use Case'),
                const SizedBox(height: 10),
                _SheetField(controller: _repositoryCtrl, hint: 'Repository'),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _dataSourceCtrl,
                  hint: 'Data Source (Hive/Supabase/Firebase)',
                ),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _servicesCtrl,
                  hint: 'System Services (analytics/errors/notifs)',
                ),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _outputCtrl,
                  hint: 'Output (what user sees)',
                ),
                const SizedBox(height: 10),
                _SheetField(controller: _savedDataCtrl, hint: 'Saved Data'),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _errorsCtrl,
                  hint: 'Errors / failure points',
                ),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _fallbackCtrl,
                  hint: 'Fallback behavior',
                ),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _analyticsCtrl,
                  hint: 'Analytics event',
                ),
                const SizedBox(height: 10),
                _SheetField(
                  controller: _tagsCtrl,
                  hint: 'Tags - comma separated (optional)',
                ),
                const SizedBox(height: 16),
                SmartPressable(
                  onTap: _submit,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.neonCyan.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      'CREATE FLOW BLUEPRINT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.neonCyan,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildStructuredDescription({
    required String overview,
    required String trigger,
    required String screen,
    required String provider,
    required String useCase,
    required String repository,
    required String dataSource,
    required String services,
    required String output,
    required String savedData,
    required String errors,
    required String fallback,
    required String analyticsEvent,
  }) {
    final List<String> lines = <String>[];
    if (overview.isNotEmpty) {
      lines.add(overview);
      lines.add('');
    }
    void add(String label, String value) {
      if (value.isNotEmpty) {
        lines.add('$label: $value');
      }
    }

    add('Trigger', trigger);
    add('Screen', screen);
    add('Provider', provider);
    add('UseCase', useCase);
    add('Repository', repository);
    add('DataSource', dataSource);
    add('Services', services);
    add('Output', output);
    add('SavedData', savedData);
    add('Errors', errors);
    add('Fallback', fallback);
    add('AnalyticsEvent', analyticsEvent);

    return lines.join('\n');
  }
}

class _FlowSummaryStrip extends StatelessWidget {
  const _FlowSummaryStrip({required this.nodes});

  final List<FlowmapNode> nodes;

  @override
  Widget build(BuildContext context) {
    final int connected = nodes
        .where((FlowmapNode node) => node.connectedTo.isNotEmpty)
        .length;
    final int withAnalytics = nodes
        .where(
          (FlowmapNode node) =>
              node.tags.any((String tag) => tag.startsWith('analytics:')),
        )
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF081321),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.18)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryPill(label: 'NODES', value: '${nodes.length}'),
          _SummaryPill(label: 'CONNECTED', value: '$connected'),
          _SummaryPill(label: 'WITH EVENTS', value: '$withAnalytics'),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FlowField {
  const _FlowField({required this.key, required this.value});

  final String key;
  final String value;
}

class _FlowFieldRow extends StatelessWidget {
  const _FlowFieldRow({required this.field});

  final _FlowField field;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${field.key}: ',
              style: const TextStyle(
                color: AppColors.neonCyan,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: field.value,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowTemplate {
  const _FlowTemplate({
    required this.feature,
    required this.overview,
    required this.trigger,
    required this.screen,
    required this.provider,
    required this.useCase,
    required this.repository,
    required this.dataSource,
    required this.services,
    required this.output,
    required this.savedData,
    required this.errors,
    required this.fallback,
    required this.analyticsEvent,
    this.tags = const <String>[],
  });

  final String feature;
  final String overview;
  final String trigger;
  final String screen;
  final String provider;
  final String useCase;
  final String repository;
  final String dataSource;
  final String services;
  final String output;
  final String savedData;
  final String errors;
  final String fallback;
  final String analyticsEvent;
  final List<String> tags;
}

const List<_FlowTemplate> _flowTemplates = <_FlowTemplate>[
  _FlowTemplate(
    feature: 'Smart Coach',
    overview:
        'Turn user prompts into grounded coaching output with context and memory.',
    trigger: 'User submits coaching message',
    screen: 'SmartCoachScreen',
    provider: 'smartCoachScreenModelProvider / coachQueryController',
    useCase: 'intent detection + context build + coaching response',
    repository: 'tasks/goals/memory/log repositories',
    dataSource: 'Hive local + synced remote state',
    services: 'analytics, error capture, optional voice output',
    output: 'Coach advice + next action on Smart Coach UI',
    savedData: 'coach query/response context',
    errors: 'AI failure, partial context failure',
    fallback: 'Deterministic coaching guidance with reduced context',
    analyticsEvent: 'smart_coach_requested',
    tags: <String>['coach', 'ai', 'context'],
  ),
  _FlowTemplate(
    feature: 'SI Console',
    overview:
        'Convert natural language system queries into ranked, actionable analysis.',
    trigger: 'User submits SI query',
    screen: 'SIConsoleScreen',
    provider: 'siConsoleScreenModelProvider',
    useCase: 'intent detection + priority + recommendation generation',
    repository: 'tasks/goals/habits/timeline/memory repositories',
    dataSource: 'Hive local + sync state',
    services: 'analytics, diagnostics',
    output: 'Priority analysis and next actions',
    savedData: 'query history and response summary',
    errors: 'query parse failure, context load failure',
    fallback: 'Constrained deterministic summary',
    analyticsEvent: 'si_console_query_submitted',
    tags: <String>['si', 'console', 'analysis'],
  ),
  _FlowTemplate(
    feature: 'Task Completion',
    overview: 'Execute task mutation and side effects without blocking UX.',
    trigger: 'User taps complete task',
    screen: 'TaskScreen / PlanScreen',
    provider: 'taskActionsProvider',
    useCase: 'complete task + side effects',
    repository: 'task repository',
    dataSource: 'Hive local + sync pipeline',
    services: 'analytics, timeline, logs, notification',
    output: 'Task marked complete + score/progression update',
    savedData: 'task state, timeline/log entries, learning memory',
    errors: 'task missing, side-effect write failures',
    fallback: 'Core mutation succeeds; side effects are best-effort',
    analyticsEvent: 'task_completed',
    tags: <String>['tasks', 'progression', 'timeline'],
  ),
  _FlowTemplate(
    feature: 'Memory Engine',
    overview:
        'Capture structured memory for contextual coach/SI personalization.',
    trigger: 'User writes memory or feature emits memory-worthy event',
    screen: 'MemoriesScreen',
    provider: 'memoriesProvider / memorySummaryProvider',
    useCase: 'capture + classify + link + recall memory',
    repository: 'memory repository',
    dataSource: 'local persisted store',
    services: 'analytics/diagnostics where available',
    output: 'Structured memories searchable by category/tags',
    savedData: 'memory records with category/tags/importance/links/metadata',
    errors: 'malformed stored memory, write failure',
    fallback: 'best-effort parse and continue with available memory',
    analyticsEvent: 'memory_created',
    tags: <String>['memory', 'context', 'personalization'],
  ),
  _FlowTemplate(
    feature: 'Offline Sync',
    overview:
        'Replay queued offline operations when connectivity is available.',
    trigger: 'Connectivity returns or manual sync requested',
    screen: 'Sync status surfaces',
    provider: 'sync provider/queue service',
    useCase: 'replay queued operations and reconcile',
    repository: 'offline queue + feature repositories',
    dataSource: 'local queue + remote API/Supabase',
    services: 'connectivity, analytics, diagnostics',
    output: 'Sync state update and queue drain status',
    savedData: 'queue metadata and reconciliation state',
    errors: 'timeout, remote validation failure, conflicts',
    fallback: 'retain queue and retry later',
    analyticsEvent: 'sync_started',
    tags: <String>['sync', 'offline', 'reliability'],
  ),
];

List<_FlowField> _parseFlowFields(String? description) {
  if (description == null || description.trim().isEmpty) {
    return const <_FlowField>[];
  }
  final List<_FlowField> fields = <_FlowField>[];
  for (final String raw in description.split('\n')) {
    final String line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    final int split = line.indexOf(':');
    if (split <= 0 || split >= line.length - 1) {
      continue;
    }
    final String key = line.substring(0, split).trim();
    final String value = line.substring(split + 1).trim();
    if (key.isNotEmpty && value.isNotEmpty) {
      fields.add(_FlowField(key: key, value: value));
    }
  }
  return fields;
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
