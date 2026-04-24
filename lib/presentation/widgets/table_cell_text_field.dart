import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/environment_model.dart';
import '../providers/environment_provider.dart';
import '../providers/global_variables_provider.dart';
import '../providers/settings_provider.dart';
import '../../core/utils/toast_utils.dart';
import 'hover_overlay.dart';

class TableCellTextField extends ConsumerStatefulWidget {
  final String text;
  final String hint;
  final Function(String) onChanged;
  final bool readOnly;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  const TableCellTextField({
    super.key,
    required this.text,
    required this.hint,
    required this.onChanged,
    this.readOnly = false,
    this.controller,
    this.focusNode,
    this.onSubmitted,
    this.onEditingComplete,
  });

  @override
  ConsumerState<TableCellTextField> createState() => _TableCellTextFieldState();
}

class _EnvAwareTextEditingController extends TextEditingController {
  static final RegExp _tokenPattern = RegExp(r'\{\{([^{}]+)\}\}');

  _EnvAwareTextEditingController({super.text});

  Set<String> _envKeys = const {};

  void updateEnvKeys(Set<String> keys) {
    if (setEquals(_envKeys, keys)) return;
    _envKeys = Set<String>.from(keys);
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final raw = value.text;
    if (raw.isEmpty) {
      return TextSpan(style: style, text: raw);
    }

    final spans = <TextSpan>[];
    int start = 0;
    for (final match in _tokenPattern.allMatches(raw)) {
      if (match.start > start) {
        spans.add(
            TextSpan(text: raw.substring(start, match.start), style: style));
      }
      final tokenText = raw.substring(match.start, match.end);
      final tokenKey = (match.group(1) ?? '').trim();
      final isValid = _envKeys.contains(tokenKey);
      spans.add(
        TextSpan(
          text: tokenText,
          style: (style ?? const TextStyle()).copyWith(
            color: isValid ? const Color(0xFF2F6FEB) : const Color(0xFFD14343),
            backgroundColor:
                isValid ? const Color(0x1F2F6FEB) : const Color(0x1FD14343),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      start = match.end;
    }
    if (start < raw.length) {
      spans.add(TextSpan(text: raw.substring(start), style: style));
    }
    return TextSpan(style: style, children: spans);
  }
}

class _TableCellTextFieldState extends ConsumerState<TableCellTextField> {
  static final RegExp _envTriggerPattern =
      RegExp(r'(\{\{?)([A-Za-z0-9_\-$]*)$');
  static const String _variableHoverOverlayGroup =
      'request-pane-variable-hover';
  static const String _autocompleteOverlayGroup =
      'request-pane-env-autocomplete';

  late _EnvAwareTextEditingController _controller;
  late final FocusNode _fallbackFocusNode;
  final LayerLink _fieldLayerLink = LayerLink();
  final DropdownOverlayController _autocompleteDropdownOverlay =
      DropdownOverlayController(debugLabel: 'request-pane-autocomplete');
  final HoverOverlayController _missingVariableHoverOverlay =
      HoverOverlayController(debugLabel: 'request-pane-missing-variable-hover');
  List<_EnvSuggestion> _filteredEnvSuggestions = const [];
  int _replaceStart = -1;
  int _replaceEnd = -1;
  bool _syncingToExternalController = false;
  bool _syncingFromExternalController = false;
  Set<String> _pendingEnvKeys = const {};
  bool _envKeyUpdateScheduled = false;
  final TextEditingController _missingVariableValueController =
      TextEditingController();
  final FocusNode _missingVariableValueFocusNode = FocusNode();
  _MissingVariableCandidate? _hoveredMissingVariable;
  _VariableCreateTarget _variableCreateTarget = _VariableCreateTarget.global;
  bool _showAddToOptions = false;
  Offset _autocompleteOffset = const Offset(0, 34);
  Offset _missingVariableOffset = const Offset(0, 34);
  final HoverOverlayController _validVariableHoverOverlay =
      HoverOverlayController(debugLabel: 'request-pane-valid-variable-hover');
  _ValidVariableCandidate? _hoveredValidVariable;
  Offset _validVariableOffset = const Offset(0, 34);
  Timer? _hideValidVariableTimer;
  Timer? _hideMissingVariableTimer;

  @override
  void initState() {
    super.initState();
    _fallbackFocusNode = FocusNode();
    _controller = _EnvAwareTextEditingController(
      text: widget.controller?.text ?? widget.text,
    );
    _controller.addListener(_handleControllerChanged);
    widget.controller?.addListener(_handleExternalControllerChanged);
    _effectiveFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(TableCellTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNodeForWidget(oldWidget).removeListener(_handleFocusChanged);
      _effectiveFocusNode.addListener(_handleFocusChanged);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleExternalControllerChanged);
      widget.controller?.addListener(_handleExternalControllerChanged);
      if (widget.controller != null &&
          widget.controller!.value != _controller.value) {
        _syncingFromExternalController = true;
        _controller.value = widget.controller!.value;
        _syncingFromExternalController = false;
      }
    }
    if (widget.controller == null && widget.text != _controller.text) {
      final oldSelection = _controller.selection;
      _controller.text = widget.text;
      if (oldSelection.isValid &&
          oldSelection.baseOffset <= widget.text.length &&
          oldSelection.extentOffset <= widget.text.length) {
        _controller.selection = oldSelection;
      } else {
        _controller.selection =
            TextSelection.collapsed(offset: widget.text.length);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncEnvAutocomplete();
    });
  }

  @override
  void dispose() {
    _hideValidVariableTimer?.cancel();
    _hideMissingVariableTimer?.cancel();
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _fallbackFocusNode.dispose();
    widget.controller?.removeListener(_handleExternalControllerChanged);
    _controller.removeListener(_handleControllerChanged);
    _hideEnvAutocomplete();
    _hideMissingVariableOverlay(immediate: true);
    _hideValidVariableOverlay(immediate: true);
    _autocompleteDropdownOverlay.dispose();
    _missingVariableHoverOverlay.dispose();
    _validVariableHoverOverlay.dispose();
    _controller.dispose();
    _missingVariableValueController.dispose();
    _missingVariableValueFocusNode.dispose();
    super.dispose();
  }

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _fallbackFocusNode;

  FocusNode _focusNodeForWidget(TableCellTextField field) =>
      field.focusNode ?? _fallbackFocusNode;

  void _handleControllerChanged() {
    if (!_syncingFromExternalController && widget.controller != null) {
      if (widget.controller!.value != _controller.value) {
        _syncingToExternalController = true;
        widget.controller!.value = _controller.value;
        _syncingToExternalController = false;
      }
    }
    _hideMissingVariableOverlay(immediate: true);
    _hideValidVariableOverlay(immediate: true);
    _syncEnvAutocomplete();
  }

  void _handleExternalControllerChanged() {
    if (_syncingToExternalController || widget.controller == null) return;
    if (widget.controller!.value == _controller.value) return;
    _syncingFromExternalController = true;
    _controller.value = widget.controller!.value;
    _syncingFromExternalController = false;
    _hideMissingVariableOverlay(immediate: true);
    _hideValidVariableOverlay(immediate: true);
  }

  void _handleFocusChanged() {
    if (!_effectiveFocusNode.hasFocus) {
      _hideEnvAutocomplete();
      _hideMissingVariableOverlay();
      _hideValidVariableOverlay();
      return;
    }
    _syncEnvAutocomplete();
  }

  void _syncEnvAutocomplete() {
    if (!mounted || widget.readOnly) {
      _hideEnvAutocomplete();
      return;
    }
    if (!_effectiveFocusNode.hasFocus) {
      _hideEnvAutocomplete();
      return;
    }

    final selection = _controller.selection;
    if (!selection.isValid || selection.baseOffset < 0) {
      _hideEnvAutocomplete();
      return;
    }

    final cursor = selection.baseOffset;
    final text = _controller.text;
    if (cursor > text.length) {
      _hideEnvAutocomplete();
      return;
    }

    final textBeforeCursor = text.substring(0, cursor);
    final match = _envTriggerPattern.firstMatch(textBeforeCursor);
    if (match == null) {
      _hideEnvAutocomplete();
      return;
    }

    final query = (match.group(2) ?? '').toLowerCase();
    final options = _collectVariableSuggestions()
        .where((v) => query.isEmpty || v.key.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) {
        final aStarts = a.key.toLowerCase().startsWith(query);
        final bStarts = b.key.toLowerCase().startsWith(query);
        if (aStarts != bStarts) return aStarts ? -1 : 1;
        return a.key.compareTo(b.key);
      });

    if (options.isEmpty) {
      _hideEnvAutocomplete();
      return;
    }

    _replaceStart = match.start;
    _replaceEnd = cursor;
    _filteredEnvSuggestions = options;
    _autocompleteOffset = _calculatePopupOffset(
      _getCaretOffset(cursor),
      panelWidth: 220,
      verticalGap: 6,
    );
    _showOrUpdateEnvAutocomplete();
  }

  void _showOrUpdateEnvAutocomplete() {
    const panelWidth = 220.0;

    _autocompleteDropdownOverlay.showFollower(
      context: context,
      layerLink: _fieldLayerLink,
      offset: _autocompleteOffset,
      groupId: _autocompleteOverlayGroup,
      contentBuilder: (context, hide) => SizedBox(
        width: panelWidth,
        child: Material(
          elevation: 8,
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 150,
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: _filteredEnvSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _filteredEnvSuggestions[index];
                final isGlobal =
                    suggestion.source == _VariableSuggestionSource.global;
                final badgeColor = isGlobal ? Colors.blue : Colors.green;
                final badgeText = isGlobal ? 'G' : 'E';

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _insertEnvVariable(suggestion.key),
                  onTap: () => _insertEnvVariable(suggestion.key),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badgeText,
                              style: TextStyle(
                                  color: badgeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.key,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).textTheme.bodyMedium?.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                suggestion.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _hideEnvAutocomplete() {
    _autocompleteDropdownOverlay.hide();
  }

  void _insertEnvVariable(String key) {
    int start = _replaceStart;
    int end =
        _replaceEnd >= _replaceStart ? _replaceEnd : _controller.text.length;

    if (start < 0 || end < start) {
      final selection = _controller.selection;
      final cursor =
          selection.isValid ? selection.baseOffset : _controller.text.length;
      final safeCursor = cursor.clamp(0, _controller.text.length);
      final textBeforeCursor = _controller.text.substring(0, safeCursor);
      final match = _envTriggerPattern.firstMatch(textBeforeCursor);
      if (match == null) {
        _hideEnvAutocomplete();
        return;
      }
      start = match.start;
      end = safeCursor;
    }

    final replacement = '{{$key}}';
    final newText = _controller.text.replaceRange(start, end, replacement);
    final newCursorOffset = start + replacement.length;
    _effectiveFocusNode.requestFocus();
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.selection = TextSelection.collapsed(offset: newCursorOffset);
      }
    });
    widget.onChanged(newText);
    _replaceStart = -1;
    _replaceEnd = -1;
    _hideEnvAutocomplete();
  }

  TextStyle _effectiveTextStyle(BuildContext context) {
    return TextStyle(
      color: widget.readOnly
          ? Colors.grey
          : Theme.of(context).textTheme.bodyMedium!.color!,
      fontSize: 12,
      fontFamily: 'Consolas',
    );
  }

  TextPainter _buildTextPainter(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _effectiveTextStyle(context)),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    return painter;
  }

  Offset _getCaretOffset(int textOffset) {
    final safeOffset = textOffset.clamp(0, _controller.text.length);
    final painter = _buildTextPainter(_controller.text);
    final caretOffset =
        painter.getOffsetForCaret(TextPosition(offset: safeOffset), Rect.zero);
    return Offset(caretOffset.dx + 4, 30);
  }

  Offset _calculatePopupOffset(
    Offset desiredOffset, {
    required double panelWidth,
    required double verticalGap,
  }) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) {
      return desiredOffset + Offset(0, verticalGap);
    }
    final maxLeft = (renderBox.size.width - panelWidth).clamp(0.0, double.infinity);
    final left = desiredOffset.dx.clamp(0.0, maxLeft);
    return Offset(left, desiredOffset.dy + verticalGap);
  }

  _MissingVariableCandidate? _findMissingVariableAtLocalPosition(
      Offset localPosition) {
    final text = _controller.text;
    if (text.isEmpty) return null;

    final painter = _buildTextPainter(text);
    final adjustedDx = localPosition.dx - 4;
    final adjustedDy = localPosition.dy - 8;
    if (adjustedDx < 0 ||
        adjustedDy < 0 ||
        adjustedDx > painter.width + 2 ||
        adjustedDy > painter.height + 6) {
      return null;
    }
    final adjustedPosition = Offset(
      adjustedDx.clamp(0.0, painter.width),
      adjustedDy.clamp(0.0, painter.height),
    );
    final textPosition = painter.getPositionForOffset(adjustedPosition);
    final offset = textPosition.offset;

    for (final match in _EnvAwareTextEditingController._tokenPattern.allMatches(text)) {
      final tokenKey = (match.group(1) ?? '').trim();
      if (_pendingEnvKeys.contains(tokenKey)) continue;
      if (offset < match.start || offset > match.end) continue;

      final startOffset =
          painter.getOffsetForCaret(TextPosition(offset: match.start), Rect.zero);
      final endOffset =
          painter.getOffsetForCaret(TextPosition(offset: match.end), Rect.zero);
      return _MissingVariableCandidate(
        key: tokenKey,
        start: match.start,
        end: match.end,
        anchorOffset: Offset(startOffset.dx + 4, 30),
        tokenWidth: (endOffset.dx - startOffset.dx).abs(),
      );
    }

    return null;
  }

  _ValidVariableCandidate? _findValidVariableAtLocalPosition(
      Offset localPosition) {
    final text = _controller.text;
    if (text.isEmpty) return null;

    final painter = _buildTextPainter(text);
    final adjustedDx = localPosition.dx - 4;
    final adjustedDy = localPosition.dy - 8;
    if (adjustedDx < 0 ||
        adjustedDy < 0 ||
        adjustedDx > painter.width + 2 ||
        adjustedDy > painter.height + 6) {
      return null;
    }
    final adjustedPosition = Offset(
      adjustedDx.clamp(0.0, painter.width),
      adjustedDy.clamp(0.0, painter.height),
    );
    final textPosition = painter.getPositionForOffset(adjustedPosition);
    final offset = textPosition.offset;

    final suggestions = _collectVariableSuggestions();
    final suggestionsByKey = {for (final s in suggestions) s.key: s};

    for (final match
        in _EnvAwareTextEditingController._tokenPattern.allMatches(text)) {
      final tokenKey = (match.group(1) ?? '').trim();
      if (!_pendingEnvKeys.contains(tokenKey)) continue;
      if (offset < match.start || offset > match.end) continue;

      final suggestion = suggestionsByKey[tokenKey];
      if (suggestion == null) continue;

      final startOffset = painter.getOffsetForCaret(
          TextPosition(offset: match.start), Rect.zero);
      final endOffset = painter.getOffsetForCaret(
          TextPosition(offset: match.end), Rect.zero);
      return _ValidVariableCandidate(
        key: tokenKey,
        start: match.start,
        end: match.end,
        anchorOffset: Offset(startOffset.dx + 4, 30),
        tokenWidth: (endOffset.dx - startOffset.dx).abs(),
        value: suggestion.value,
        source: suggestion.source,
      );
    }

    return null;
  }

  void _handleMouseHover(PointerHoverEvent event) {
    if (widget.readOnly) return;
    final validCandidate =
        _findValidVariableAtLocalPosition(event.localPosition);
    if (validCandidate != null) {
      _hideMissingVariableOverlay();
      _showValidVariableOverlay(validCandidate);
      return;
    }
    final missingCandidate =
        _findMissingVariableAtLocalPosition(event.localPosition);
    if (missingCandidate != null) {
      _hideValidVariableOverlay();
      _showMissingVariableOverlay(missingCandidate);
      return;
    }
    _hideMissingVariableOverlay();
    _hideValidVariableOverlay();
  }

  void _handleMouseExit(PointerExitEvent event) {
    _scheduleHideMissingVariableOverlay();
    _scheduleHideValidVariableOverlay();
  }

  void _scheduleHideValidVariableOverlay() {
    _hideValidVariableTimer?.cancel();
    _hideValidVariableTimer = Timer(const Duration(milliseconds: 300), () {
      _hideValidVariableOverlay();
    });
  }

  void _cancelHideValidVariableOverlay() {
    _hideValidVariableTimer?.cancel();
  }

  void _scheduleHideMissingVariableOverlay() {
    _hideMissingVariableTimer?.cancel();
    _hideMissingVariableTimer = Timer(const Duration(milliseconds: 300), () {
      _hideMissingVariableOverlay();
    });
  }

  void _cancelHideMissingVariableOverlay() {
    _hideMissingVariableTimer?.cancel();
  }

  void _showMissingVariableOverlay(_MissingVariableCandidate candidate) {
    _cancelHideMissingVariableOverlay();
    final activeEnvironmentId = ref.read(activeEnvironmentIdProvider);
    _variableCreateTarget = activeEnvironmentId == null
        ? _VariableCreateTarget.global
        : _variableCreateTarget;

    if (_hoveredMissingVariable?.key != candidate.key) {
      _missingVariableValueController.clear();
      _showAddToOptions = false;
    }

    _hoveredMissingVariable = candidate;
    _missingVariableOffset = _calculatePopupOffset(
      Offset(candidate.anchorOffset.dx, candidate.anchorOffset.dy),
      panelWidth: 250,
      verticalGap: 2,
    );

    final hasActiveEnvironment = ref.read(activeEnvironmentIdProvider) != null;
    String activeEnvName = '';
    if (activeEnvironmentId != null) {
      final environments = ref.read(activeWorkspaceEnvironmentsProvider);
      try {
        activeEnvName = environments
            .firstWhere((e) => e.id == activeEnvironmentId)
            .name;
      } catch (_) {
      }
    }
    
    final t = ref.read(translationsProvider);

    _missingVariableHoverOverlay.show(
      context: context,
      layerLink: _fieldLayerLink,
      offset: _missingVariableOffset,
      groupId: _variableHoverOverlayGroup,
      hideOnExit: false,
      contentBuilder: (context, hide) => MouseRegion(
        onEnter: (_) => _cancelHideMissingVariableOverlay(),
        onExit: (_) => _hideMissingVariableOverlay(),
        child: HoverOverlayPanel(
          width: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hoveredMissingVariable == null
                    ? ''
                    : '${t['create_variable'] ?? 'Create'} {{${_hoveredMissingVariable!.key}}}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                height: 36,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _missingVariableValueController,
                  focusNode: _missingVariableValueFocusNode,
                  autofocus: false,
                  style: _effectiveTextStyle(context),
                  decoration: InputDecoration(
                    hintText: t['enter_value'] ?? 'Enter value',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _saveMissingVariable(),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  _showAddToOptions = !_showAddToOptions;
                  _missingVariableHoverOverlay.rebuild();
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _showAddToOptions
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 16,
                        color: Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t['add_to'] ?? 'Add to',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                      ),
                      const Spacer(),
                      if (_variableCreateTarget == _VariableCreateTarget.environment)
                        Text(
                          activeEnvName.isNotEmpty ? activeEnvName : (t['no_environment'] ?? 'No Environment'),
                          style: TextStyle(
                            fontSize: 11,
                            color: activeEnvName.isNotEmpty
                                ? Theme.of(context).hintColor
                                : Theme.of(context).disabledColor,
                          ),
                        )
                      else
                        Text(
                          t['global'] ?? 'Global',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                        ),
                    ],
                  ),
                ),
              ),
              if (_showAddToOptions) ...[
                const SizedBox(height: 4),
                _buildAddToOption(
                  t['global_variables'] ?? 'Global Variables',
                  _VariableCreateTarget.global,
                  Icons.public,
                ),
                if (hasActiveEnvironment) ...[
                  const SizedBox(height: 2),
                  _buildAddToOption(
                    t['current_environment'] ?? 'Current Environment',
                    _VariableCreateTarget.environment,
                    Icons.language,
                  ),
                ],
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveMissingVariable,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(t['create'] ?? 'Create', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddToOption(
    String label,
    _VariableCreateTarget target,
    IconData icon,
  ) {
    final isSelected = _variableCreateTarget == target;
    return InkWell(
      onTap: () {
        _variableCreateTarget = target;
        _showAddToOptions = false;
        _missingVariableHoverOverlay.rebuild();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : null,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).hintColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check,
                size: 14,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  void _hideMissingVariableOverlay({bool immediate = false}) {
    _hideMissingVariableTimer?.cancel();
    _hoveredMissingVariable = null;
    _missingVariableHoverOverlay.hide();
  }

  void _showValidVariableOverlay(_ValidVariableCandidate candidate) {
    _cancelHideValidVariableOverlay();
    _hoveredValidVariable = candidate;
    _validVariableOffset = _calculatePopupOffset(
      Offset(candidate.anchorOffset.dx, candidate.anchorOffset.dy),
      panelWidth: 250,
      verticalGap: 2,
    );

    final t = ref.read(translationsProvider);

    _validVariableHoverOverlay.show(
      context: context,
      layerLink: _fieldLayerLink,
      offset: _validVariableOffset,
      groupId: _variableHoverOverlayGroup,
      hideOnExit: false,
      contentBuilder: (context, hide) => MouseRegion(
        onEnter: (_) => _cancelHideValidVariableOverlay(),
        onExit: (_) => _hideValidVariableOverlay(),
        child: HoverOverlayPanel(
          width: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hoveredValidVariable == null
                    ? ''
                    : _hoveredValidVariable!.value.isEmpty
                        ? '(${t['empty'] ?? 'empty'})'
                        : _hoveredValidVariable!.value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    _hoveredValidVariable?.source ==
                            _VariableSuggestionSource.environment
                        ? Icons.public
                        : Icons.language,
                    size: 12,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hoveredValidVariable?.source ==
                            _VariableSuggestionSource.environment
                        ? t['environment'] ?? 'Environment'
                        : t['global_variables'] ?? 'Global Variables',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hideValidVariableOverlay({bool immediate = false}) {
    _hideValidVariableTimer?.cancel();
    _hoveredValidVariable = null;
    _validVariableHoverOverlay.hide();
  }

  Future<void> _saveMissingVariable() async {
    final candidate = _hoveredMissingVariable;
    if (candidate == null) return;
    final value = _missingVariableValueController.text;
    final t = ref.read(translationsProvider);
    if (value.isEmpty) {
      ToastUtils.showInfo(context, t['please_enter_value'] ?? 'Please enter a value');
      return;
    }

    if (_variableCreateTarget == _VariableCreateTarget.environment) {
      final activeEnvironmentId = ref.read(activeEnvironmentIdProvider);
      if (activeEnvironmentId == null) {
        ToastUtils.showInfo(context, 'No active environment selected');
        return;
      }
      final environments = ref.read(activeWorkspaceEnvironmentsProvider);
      EnvironmentModel? env;
      for (final item in environments) {
        if (item.id == activeEnvironmentId) {
          env = item;
          break;
        }
      }
      if (env == null) {
        ToastUtils.showInfo(context, 'No active environment selected');
        return;
      }
      final variables = [...env.variables];
      final index =
          variables.indexWhere((variable) => variable.key.trim() == candidate.key);
      final nextVariable = EnvironmentVariable(
        key: candidate.key,
        value: value,
        enabled: true,
      );
      if (index >= 0) {
        variables[index] = nextVariable;
      } else {
        variables.add(nextVariable);
      }
      await ref.read(environmentsProvider.notifier).updateEnvironment(
            env.copyWith(variables: variables),
          );
    } else {
      final globalVariables = [...ref.read(globalVariablesProvider)];
      final index = globalVariables
          .indexWhere((variable) => variable.key.trim() == candidate.key);
      final nextVariable = GlobalVariable(
        key: candidate.key,
        value: value,
        enabled: true,
      );
      if (index >= 0) {
        globalVariables[index] = nextVariable;
      } else {
        globalVariables.add(nextVariable);
      }
      await ref.read(globalVariablesProvider.notifier).setVariables(globalVariables);
    }

    ToastUtils.showSuccess(context, 'Variable created');
    _hideMissingVariableOverlay(immediate: true);
    _hideValidVariableOverlay(immediate: true);
  }

  void _scheduleEnvKeyRefresh(Set<String> envKeys) {
    if (setEquals(_pendingEnvKeys, envKeys) && _envKeyUpdateScheduled) return;
    _pendingEnvKeys = Set<String>.from(envKeys);
    if (_envKeyUpdateScheduled) return;
    _envKeyUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _envKeyUpdateScheduled = false;
      if (!mounted) return;
      _controller.updateEnvKeys(_pendingEnvKeys);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(globalVariablesProvider);
    ref.watch(activeEnvironmentIdProvider);
    ref.watch(activeWorkspaceEnvironmentsProvider);
    final envKeys = _collectAvailableVariableKeys();
    _scheduleEnvKeyRefresh(envKeys);

    return CompositedTransformTarget(
      link: _fieldLayerLink,
      child: MouseRegion(
        onHover: _handleMouseHover,
        onExit: _handleMouseExit,
        child: TextField(
          controller: _controller,
          focusNode: _effectiveFocusNode,
          onChanged: (value) {
            widget.onChanged(value);
            _syncEnvAutocomplete();
          },
          onTap: () {
            _hideMissingVariableOverlay(immediate: true);
            _hideValidVariableOverlay(immediate: true);
            _syncEnvAutocomplete();
          },
          readOnly: widget.readOnly,
          onSubmitted: (value) {
            widget.onSubmitted?.call(value);
            _hideEnvAutocomplete();
            _hideMissingVariableOverlay(immediate: true);
            _hideValidVariableOverlay(immediate: true);
          },
          onEditingComplete: () {
            widget.onEditingComplete?.call();
            _hideEnvAutocomplete();
            _hideMissingVariableOverlay(immediate: true);
            _hideValidVariableOverlay(immediate: true);
          },
          maxLines: 1,
          style: _effectiveTextStyle(context),
          decoration: InputDecoration(
            filled: false,
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: Theme.of(context).brightness == Brightness.dark
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    borderSide:
                        const BorderSide(color: Colors.grey, width: 1.0),
                  )
                : InputBorder.none,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ),
      ),
    );
  }

  Set<String> _collectAvailableVariableKeys() {
    return _collectVariableSuggestions().map((item) => item.key).toSet();
  }

  List<_EnvSuggestion> _collectVariableSuggestions() {
    final suggestionsByKey = <String, _EnvSuggestion>{};

    final globalVariables = ref.read(globalVariablesProvider);
    for (final variable in globalVariables) {
      if (!variable.enabled) continue;
      final key = variable.key.trim();
      if (key.isEmpty) continue;
      suggestionsByKey[key] = _EnvSuggestion(
        key: key,
        value: variable.value,
        type: 'default',
        source: _VariableSuggestionSource.global,
      );
    }

    final activeEnvironmentId = ref.read(activeEnvironmentIdProvider);
    if (activeEnvironmentId != null) {
      final environments = ref.read(activeWorkspaceEnvironmentsProvider);
      for (final env in environments) {
        if (env.id != activeEnvironmentId) continue;
        for (final variable in env.variables) {
          if (!variable.enabled) continue;
          final key = variable.key.trim();
          if (key.isEmpty) continue;
          suggestionsByKey[key] = _EnvSuggestion(
            key: key,
            value: variable.value,
            type: variable.type,
            source: _VariableSuggestionSource.environment,
          );
        }
        break;
      }
    }

    return suggestionsByKey.values.toList();
  }
}

enum _VariableSuggestionSource { global, environment }

enum _VariableCreateTarget { global, environment }

class _MissingVariableCandidate {
  final String key;
  final int start;
  final int end;
  final Offset anchorOffset;
  final double tokenWidth;

  const _MissingVariableCandidate({
    required this.key,
    required this.start,
    required this.end,
    required this.anchorOffset,
    required this.tokenWidth,
  });
}

class _ValidVariableCandidate {
  final String key;
  final int start;
  final int end;
  final Offset anchorOffset;
  final double tokenWidth;
  final String value;
  final _VariableSuggestionSource source;

  const _ValidVariableCandidate({
    required this.key,
    required this.start,
    required this.end,
    required this.anchorOffset,
    required this.tokenWidth,
    required this.value,
    required this.source,
  });
}

class _EnvSuggestion {
  final String key;
  final String value;
  final String type;
  final _VariableSuggestionSource source;

  const _EnvSuggestion({
    required this.key,
    required this.value,
    required this.type,
    required this.source,
  });
}
