import 'package:flutter/material.dart';

import 'script_snippets.dart';

class ScriptSnippetsOverlay extends StatefulWidget {
  final bool isPreRequest;
  final void Function(String code) onSelect;

  const ScriptSnippetsOverlay({
    super.key,
    required this.isPreRequest,
    required this.onSelect,
  });

  @override
  State<ScriptSnippetsOverlay> createState() => _ScriptSnippetsOverlayState();
}

class _ScriptSnippetsOverlayState extends State<ScriptSnippetsOverlay> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ScriptSnippet> _filteredSnippets() {
    final q = _searchController.text.trim().toLowerCase();

    Iterable<ScriptSnippet> items = builtInScriptSnippets.where((s) {
      if (widget.isPreRequest && s.testsOnly) return false;
      if (!widget.isPreRequest && s.preReqOnly) return false;
      return true;
    });

    if (q.isNotEmpty) {
      items = items.where((s) {
        return s.title.toLowerCase().contains(q) ||
            s.category.toLowerCase().contains(q) ||
            s.code.toLowerCase().contains(q);
      });
    }

    final uniq = <String, ScriptSnippet>{};
    for (final s in items) {
      final key =
          '${s.category.trim().toLowerCase()}::${s.title.trim().toLowerCase()}';
      uniq[key] ??= s;
    }
    return uniq.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredSnippets();
    final grouped = <String, List<ScriptSnippet>>{};
    for (final s in items) {
      final category = s.category.trim();
      final list = grouped.putIfAbsent(category, () => []);
      final t = s.title.trim().toLowerCase();
      if (!list.any((e) => e.title.trim().toLowerCase() == t)) list.add(s);
    }

    final preferredOrder = ['Tests', 'Workflows', 'Variables'];
    final categories = grouped.keys.toList(growable: false);
    categories.sort((a, b) {
      final ai = preferredOrder.indexOf(a);
      final bi = preferredOrder.indexOf(b);
      final aRank = ai == -1 ? 999 : ai;
      final bRank = bi == -1 ? 999 : bi;
      if (aRank != bRank) return aRank - bRank;
      return a.compareTo(b);
    });

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        height: 460,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search snippets',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 0),
                children: [
                  for (final category in categories) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    for (final s in (grouped[category] ?? const []))
                      _SnippetTile(
                        key: ValueKey('${s.category}::${s.title}'),
                        title: s.title,
                        onTap: () => widget.onSelect(s.code),
                      ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnippetTile extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _SnippetTile({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  State<_SnippetTile> createState() => _SnippetTileState();
}

class _SnippetTileState extends State<_SnippetTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? bgColor;
    if (_isHovered) {
      bgColor = theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: bgColor,
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }
}
