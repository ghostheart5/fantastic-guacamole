import 'package:fantastic_guacamole/core/utils/date_time_formats.dart';
import 'package:fantastic_guacamole/domain/entities/memory_entity.dart';
import 'package:fantastic_guacamole/state/app_state.dart';
import 'package:fantastic_guacamole/state/providers/memories_provider.dart';
import 'package:fantastic_guacamole/ui/constants/app_colors.dart';
import 'package:fantastic_guacamole/ui/layout/animated_system_background.dart';
import 'package:fantastic_guacamole/ui/widgets/smart_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key});

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  String _query = '';
  MemoryCategory? _selectedCategory;
  bool _showArchived = false;

  Future<void> _openCreateMemory() async {
    final _MemoryDraft? draft = await showModalBottomSheet<_MemoryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF07111D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _MemoryEditorSheet(),
    );
    if (draft == null) {
      return;
    }
    await ref
        .read(memoriesActionsProvider)
        .saveStructuredMemory(
          draft.text,
          category: draft.category,
          tags: draft.tags,
          metadata: draft.metadata,
        );
  }

  Future<void> _openEditMemory(MemoryEntity memory) async {
    final _MemoryDraft? draft = await showModalBottomSheet<_MemoryDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF07111D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MemoryEditorSheet(existing: memory),
    );
    if (draft == null) {
      return;
    }
    await ref
        .read(memoriesProvider.notifier)
        .updateMemory(
          memory.id,
          text: draft.text,
          category: draft.category,
          tags: draft.tags,
          metadata: draft.metadata,
          importance: draft.importance,
        );
  }

  @override
  Widget build(BuildContext context) {
    final MemorySummary summary = ref.watch(memorySummaryProvider);
    final List<MemoryEntity> searchResults = ref.watch(
      memorySearchProvider(_query),
    );
    final List<MemoryEntity> visible =
        searchResults
            .where(
              (MemoryEntity memory) =>
                  (_showArchived || !memory.isArchived) &&
                  (_selectedCategory == null ||
                      memory.category == _selectedCategory),
            )
            .toList(growable: false)
          ..sort((MemoryEntity a, MemoryEntity b) {
            if (a.starred != b.starred) {
              return a.starred ? -1 : 1;
            }
            final int importanceCompare = b.importance.compareTo(a.importance);
            if (importanceCompare != 0) {
              return importanceCompare;
            }
            return b.date.compareTo(a.date);
          });

    return AnimatedSystemBackground(
      backgroundAssetPath: 'assets/backgrounds/progression_bg.jpg',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.neonCyan,
          foregroundColor: const Color(0xFF041018),
          onPressed: _openCreateMemory,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text(
            'NEW MEMORY',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.7),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Row(
                  children: [
                    SmartPressable(
                      onTap: () =>
                          ref.read(appFlowProvider.notifier).toSmartCoach(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.neonCyan.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.neonCyan,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 3,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonViolet.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.neonViolet, AppColors.neonCyan],
                          ).createShader(bounds),
                          child: const Text(
                            'MEMORIES',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Text(
                          'WHAT YOU\'VE LIVED',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _MemorySummaryStrip(summary: summary),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: TextField(
                  onChanged: (String value) => setState(() => _query = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search memory context, tags, or metadata...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white38,
                    ),
                    filled: true,
                    fillColor: const Color(0xAA091427),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.neonViolet.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.neonCyan),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CategoryChip(
                              label: 'All',
                              selected: _selectedCategory == null,
                              onTap: () =>
                                  setState(() => _selectedCategory = null),
                            ),
                            const SizedBox(width: 8),
                            ...MemoryCategory.values.map(
                              (MemoryCategory category) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _CategoryChip(
                                  label: _categoryLabel(category),
                                  selected: _selectedCategory == category,
                                  onTap: () => setState(
                                    () => _selectedCategory = category,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ARCHIVED',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Switch.adaptive(
                          value: _showArchived,
                          onChanged: (bool value) =>
                              setState(() => _showArchived = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text(
                          'No memories match this context filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _MemoryCard(
                          memory: visible[i],
                          onToggleStar: () => ref
                              .read(memoriesProvider.notifier)
                              .toggleStar(visible[i].id),
                          onArchive: () => ref
                              .read(memoriesProvider.notifier)
                              .archive(visible[i].id),
                          onDelete: () => ref
                              .read(memoriesProvider.notifier)
                              .remove(visible[i].id),
                          onEdit: () => _openEditMemory(visible[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.onToggleStar,
    required this.onArchive,
    required this.onDelete,
    required this.onEdit,
  });

  final MemoryEntity memory;
  final VoidCallback onToggleStar;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String dateStr = DateTimeFormats.dateShort(memory.date);
    final Color categoryColor = _categoryColor(memory.category);
    final int importancePct = (memory.importance * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF050D1A),
        borderRadius: BorderRadius.circular(12),
        gradient: memory.isArchived
            ? const LinearGradient(
                colors: [Color(0x8808121F), Color(0x88060E18)],
              )
            : null,
        border: Border.all(
          color: memory.starred
              ? AppColors.memoryAmber.withValues(alpha: 0.4)
              : AppColors.neonViolet.withValues(alpha: 0.15),
        ),
        boxShadow: memory.starred
            ? [
                BoxShadow(
                  color: AppColors.memoryAmber.withValues(alpha: 0.08),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.neonViolet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dateStr,
                        style: const TextStyle(
                          color: AppColors.neonViolet,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _categoryLabel(memory.category).toUpperCase(),
                        style: TextStyle(
                          color: categoryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'IMP $importancePct%',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (memory.links.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${memory.links.length} LINKED',
                          style: const TextStyle(
                            color: AppColors.neonCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  memory.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: memory.importance.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                ),
                if (memory.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: memory.tags
                        .take(4)
                        .map(
                          (String tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              GestureDetector(
                onTap: onToggleStar,
                child: Icon(
                  memory.starred
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: memory.starred
                      ? AppColors.memoryAmber
                      : Colors.white24,
                  size: 22,
                ),
              ),
              const SizedBox(height: 6),
              PopupMenuButton<String>(
                color: const Color(0xFF0C1A2E),
                icon: const Icon(Icons.more_vert, color: Colors.white38),
                onSelected: (String action) {
                  if (action == 'archive') onArchive();
                  if (action == 'edit') onEdit();
                  if (action == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(
                    value: 'archive',
                    child: Text('Archive'),
                  ),
                  PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoryDraft {
  const _MemoryDraft({
    required this.text,
    required this.category,
    required this.tags,
    required this.metadata,
    required this.importance,
  });

  final String text;
  final MemoryCategory category;
  final List<String> tags;
  final Map<String, String> metadata;
  final double importance;
}

class _MemoryEditorSheet extends StatefulWidget {
  const _MemoryEditorSheet({this.existing});

  final MemoryEntity? existing;

  @override
  State<_MemoryEditorSheet> createState() => _MemoryEditorSheetState();
}

class _MemoryEditorSheetState extends State<_MemoryEditorSheet> {
  late final TextEditingController _textController;
  late final TextEditingController _tagsController;
  late final TextEditingController _metadataController;
  late MemoryCategory _category;
  late double _importance;

  @override
  void initState() {
    super.initState();
    final MemoryEntity? existing = widget.existing;
    _textController = TextEditingController(text: existing?.text ?? '');
    _tagsController = TextEditingController(
      text: existing?.tags.join(', ') ?? '',
    );
    _metadataController = TextEditingController(
      text: _serializeMetadata(existing?.metadata ?? const <String, String>{}),
    );
    _category = existing?.category ?? MemoryCategory.other;
    _importance = existing?.importance ?? 0.5;
  }

  @override
  void dispose() {
    _textController.dispose();
    _tagsController.dispose();
    _metadataController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        14 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Edit Memory' : 'Create Memory',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Memory text',
                labelStyle: TextStyle(color: Colors.white70),
                hintText:
                    'Capture preference, lesson, goal context, or insight...',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MemoryCategory>(
              initialValue: _category,
              dropdownColor: const Color(0xFF0C1A2E),
              decoration: const InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              items: MemoryCategory.values
                  .map(
                    (MemoryCategory value) => DropdownMenuItem<MemoryCategory>(
                      value: value,
                      child: Text(_categoryLabel(value)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (MemoryCategory? value) {
                if (value == null) return;
                setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'health, consistency, morning',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _metadataController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Metadata (key:value, comma-separated)',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'lifeArea:fitness, style:supportive',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Importance ${(_importance * 100).round()}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              value: _importance,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (double value) => setState(() => _importance = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final String text = _textController.text.trim();
                      if (text.isEmpty) {
                        return;
                      }
                      Navigator.of(context).pop(
                        _MemoryDraft(
                          text: text,
                          category: _category,
                          tags: _parseTags(_tagsController.text),
                          metadata: _parseMetadata(_metadataController.text),
                          importance: _importance,
                        ),
                      );
                    },
                    child: Text(isEditing ? 'Save' : 'Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _serializeMetadata(Map<String, String> metadata) {
    return metadata.entries
        .map((MapEntry<String, String> entry) => '${entry.key}:${entry.value}')
        .join(', ');
  }

  static List<String> _parseTags(String raw) {
    return raw
        .split(',')
        .map((String item) => item.trim().toLowerCase())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static Map<String, String> _parseMetadata(String raw) {
    final Map<String, String> data = <String, String>{};
    for (final String pair in raw.split(',')) {
      final String trimmed = pair.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final int divider = trimmed.indexOf(':');
      if (divider <= 0 || divider >= trimmed.length - 1) {
        continue;
      }
      final String key = trimmed.substring(0, divider).trim();
      final String value = trimmed.substring(divider + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        data[key] = value;
      }
    }
    return data;
  }
}

class _MemorySummaryStrip extends StatelessWidget {
  const _MemorySummaryStrip({required this.summary});

  final MemorySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(label: 'TOTAL', value: '${summary.total}'),
              _MetricPill(label: 'RECENT', value: '${summary.recent}'),
              _MetricPill(label: 'STARRED', value: '${summary.starred}'),
              _MetricPill(label: 'ARCHIVED', value: '${summary.archived}'),
            ],
          ),
          if (summary.topTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Top tags: ${summary.topTags.take(5).join(' · ')}",
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SmartPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonCyan.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.neonCyan.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.neonCyan : Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

String _categoryLabel(MemoryCategory category) {
  switch (category) {
    case MemoryCategory.userPreference:
      return 'Preference';
    case MemoryCategory.goal:
      return 'Goal';
    case MemoryCategory.habit:
      return 'Habit';
    case MemoryCategory.task:
      return 'Task';
    case MemoryCategory.journal:
      return 'Journal';
    case MemoryCategory.lifeArea:
      return 'Life Area';
    case MemoryCategory.coachingPreference:
      return 'Coaching';
    case MemoryCategory.value:
      return 'Value';
    case MemoryCategory.importantDate:
      return 'Important Date';
    case MemoryCategory.achievement:
      return 'Achievement';
    case MemoryCategory.insight:
      return 'Insight';
    case MemoryCategory.other:
      return 'Other';
  }
}

Color _categoryColor(MemoryCategory category) {
  switch (category) {
    case MemoryCategory.goal:
      return AppColors.neonCyan;
    case MemoryCategory.habit:
      return const Color(0xFF7AF7C4);
    case MemoryCategory.task:
      return AppColors.memoryAmber;
    case MemoryCategory.journal:
      return AppColors.neonViolet;
    case MemoryCategory.coachingPreference:
      return const Color(0xFF9AD5FF);
    case MemoryCategory.value:
      return const Color(0xFFFFD166);
    case MemoryCategory.importantDate:
      return const Color(0xFFFF8FA3);
    case MemoryCategory.achievement:
      return const Color(0xFF4BE6B0);
    case MemoryCategory.insight:
      return const Color(0xFF8CA0FF);
    case MemoryCategory.userPreference:
      return const Color(0xFFFFB86B);
    case MemoryCategory.lifeArea:
      return const Color(0xFFC2A1FF);
    case MemoryCategory.other:
      return Colors.white60;
  }
}
