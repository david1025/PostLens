import 'dart:math' as math;
import 'package:post_lens/core/utils/toast_utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

class ColorTool extends ConsumerStatefulWidget {
  const ColorTool({super.key});

  @override
  ConsumerState<ColorTool> createState() => _ColorToolState();
}

class _ColorToolState extends ConsumerState<ColorTool> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _hexController = TextEditingController();
  final TextEditingController _rgbController = TextEditingController();
  final TextEditingController _hslController = TextEditingController();
  final TextEditingController _cmykController = TextEditingController();

  Color _color = const Color(0xFFFF0000);
  HSVColor _hsv = const HSVColor.fromAHSV(1, 0, 1, 1);
  int? _selectedPresetIndex;
  String? _inputError;
  bool _suppressInputListener = false;

  static final List<Color> _presetColors = [
    const Color(0xFF000000),
    const Color(0xFFFFFFFF),
    const Color(0xFFEF4444),
    const Color(0xFFF97316),
    const Color(0xFFEAB308),
    const Color(0xFF22C55E),
    const Color(0xFF06B6D4),
    const Color(0xFF3B82F6),
    const Color(0xFF6366F1),
    const Color(0xFFA855F7),
    const Color(0xFFEC4899),
    const Color(0xFF64748B),
  ];

  @override
  void initState() {
    super.initState();
    _setColor(_color, updateInput: true);
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _hexController.dispose();
    _rgbController.dispose();
    _hslController.dispose();
    _cmykController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_suppressInputListener) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _inputError = null;
      });
      return;
    }
    final parsed = _ColorFormats.tryParse(text);
    if (parsed == null) {
      final t = ref.read(translationsProvider);
      setState(() {
        _inputError = t['cannot_parse_color'] ?? 'Cannot parse color format';
      });
      return;
    }
    _setColor(parsed, updateInput: false);
    setState(() {
      _inputError = null;
    });
  }

  void _setColor(Color color, {required bool updateInput}) {
    setState(() {
      _color = color;
      _hsv = HSVColor.fromColor(color);
      _selectedPresetIndex = _presetColors
          .indexWhere((c) => c.value == color.withAlpha(0xFF).value);
      _updateOutputs();
      if (updateInput) {
        _suppressInputListener = true;
        _inputController.text = _ColorFormats.toHex(color);
        _inputController.selection =
            TextSelection.collapsed(offset: _inputController.text.length);
        _suppressInputListener = false;
      }
    });
  }

  void _updateOutputs() {
    _hexController.text = _ColorFormats.toHex(_color);
    _rgbController.text = _ColorFormats.toRgb(_color);
    _hslController.text = _ColorFormats.toHsl(_color);
    _cmykController.text = _ColorFormats.toCmyk(_color);
  }

  void _onHueChanged(double hue) {
    final next = _hsv.withHue(hue).toColor();
    _setColor(next, updateInput: true);
  }

  void _onAlphaChanged(double alpha) {
    final next = _hsv.withAlpha(alpha).toColor();
    _setColor(next, updateInput: true);
  }

  void _onSaturationValueChanged(double saturation, double value) {
    final next = _hsv.withSaturation(saturation).withValue(value).toColor();
    _setColor(next, updateInput: true);
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final t = ref.read(translationsProvider);
    ToastUtils.showInfo(context, t['copied'] ?? 'Copied');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['color_palette_conversion'] ?? 'Color Palette / Multi-format Conversion',
      leftPane: LayoutBuilder(
        builder: (context, constraints) {
          Widget content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabeledInputField(
                label: t['input_color_support'] ?? 'Input color (supports HEX / RGB / HSL / CMYK)',
                controller: _inputController,
                hintText:
                    '#FF0000 / rgb(255,0,0) / hsl(0,100%,50%) / cmyk(0%,100%,100%,0%)',
                errorText: _inputError,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _SaturationValuePicker(
                              hsv: _hsv,
                              onChanged: _onSaturationValueChanged,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 130,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['preview'] ?? 'Preview',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Theme.of(context).dividerColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        color: _color,
                                      ),
                                    ),
                                  ),
                                ),
                                if (constraints.maxHeight >= 250) ...[
                                  const SizedBox(height: 10),
                                  _SmallValueText(_ColorFormats.toHex(_color)),
                                  const SizedBox(height: 4),
                                  _SmallValueText(_ColorFormats.toRgb(_color)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _HueSlider(value: _hsv.hue, onChanged: _onHueChanged),
                    const SizedBox(height: 10),
                    _AlphaSlider(
                        color: _hsv.toColor(),
                        value: _hsv.alpha,
                        onChanged: _onAlphaChanged),
                    const SizedBox(height: 12),
                    _PresetPalette(
                      label: t['preset_palette'] ?? 'Preset Palette',
                      colors: _presetColors,
                      selectedIndex: _selectedPresetIndex,
                      onTap: (c) => _setColor(c, updateInput: true),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (constraints.maxHeight < 350) {
            return SingleChildScrollView(
              child: SizedBox(
                height: 350,
                child: content,
              ),
            );
          }
          return content;
        },
      ),
      rightPane: SingleChildScrollView(
        child: Column(
          children: [
            _LabeledValueField(
              label: 'HEX',
              controller: _hexController,
              onCopy: () => _copy(_hexController.text),
            ),
            const SizedBox(height: 10),
            _LabeledValueField(
              label: 'RGB',
              controller: _rgbController,
              onCopy: () => _copy(_rgbController.text),
            ),
            const SizedBox(height: 10),
            _LabeledValueField(
              label: 'HSL',
              controller: _hslController,
              onCopy: () => _copy(_hslController.text),
            ),
            const SizedBox(height: 10),
            _LabeledValueField(
              label: 'CMYK',
              controller: _cmykController,
              onCopy: () => _copy(_cmykController.text),
            ),
          ],
        ),
      ),
      centerControls: Row(
        children: [
          IconButton(
            onPressed: () => _copy(_ColorFormats.toHex(_color)),
            icon: const Icon(Icons.content_copy),
            tooltip: t['copy_hex'] ?? 'Copy HEX',
          ),
          IconButton(
            onPressed: () =>
                _setColor(const Color(0xFFFF0000), updateInput: true),
            icon: const Icon(Icons.refresh),
            tooltip: t['reset'] ?? 'Reset',
          ),
        ],
      ),
    );
  }
}

class _SmallValueText extends StatelessWidget {
  final String text;

  const _SmallValueText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PresetPalette extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final int? selectedIndex;
  final ValueChanged<Color> onTap;

  const _PresetPalette({
    required this.label,
    required this.colors,
    this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < colors.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PresetSwatch(
                      color: colors[i],
                      selected: selectedIndex == i,
                      onTap: () => onTap(colors[i]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PresetSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }
}

class _HueSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _HueSlider({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GradientSlider(
      label: 'Hue',
      value: value,
      min: 0,
      max: 360,
      gradient: const LinearGradient(
        colors: [
          Color(0xFFFF0000),
          Color(0xFFFFFF00),
          Color(0xFF00FF00),
          Color(0xFF00FFFF),
          Color(0xFF0000FF),
          Color(0xFFFF00FF),
          Color(0xFFFF0000),
        ],
      ),
      onChanged: onChanged,
    );
  }
}

class _AlphaSlider extends StatelessWidget {
  final Color color;
  final double value;
  final ValueChanged<double> onChanged;

  const _AlphaSlider({
    required this.color,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final opaque = color.withAlpha(0xFF);
    return _GradientSlider(
      label: 'Alpha',
      value: value,
      min: 0,
      max: 1,
      gradient: LinearGradient(
        colors: [
          opaque.withOpacity(0),
          opaque.withOpacity(1),
        ],
      ),
      onChanged: onChanged,
    );
  }
}

class _GradientSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Gradient gradient;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.gradient,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        SizedBox(
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      decoration: BoxDecoration(gradient: gradient),
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 10,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SaturationValuePicker extends StatelessWidget {
  final HSVColor hsv;
  final void Function(double saturation, double value) onChanged;

  const _SaturationValuePicker({
    required this.hsv,
    required this.onChanged,
  });

  void _update(Offset localPos, Size size) {
    final s = (localPos.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - localPos.dy / size.height).clamp(0.0, 1.0);
    onChanged(s, v);
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final thumbX = hsv.saturation * size.width;
        final thumbY = (1 - hsv.value) * size.height;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _update(d.localPosition, size),
          onPanUpdate: (d) => _update(d.localPosition, size),
          onTapDown: (d) => _update(d.localPosition, size),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          hueColor,
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: (thumbX - 8).clamp(0.0, math.max(0.0, size.width - 16)),
                  top: (thumbY - 8).clamp(0.0, math.max(0.0, size.height - 16)),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LabeledInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? errorText;

  const _LabeledInputField({
    required this.label,
    required this.controller,
    this.hintText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: errorText == null
                      ? Theme.of(context).dividerColor
                      : Theme.of(context).colorScheme.error),
              borderRadius: BorderRadius.circular(6),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: errorText == null
                    ? null
                    : Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.error,
                      ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(
                fontSize: 11, color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _LabeledValueField extends ConsumerWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onCopy;

  const _LabeledValueField({
    required this.label,
    required this.controller,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onCopy,
              icon: const Icon(Icons.content_copy, size: 18),
              tooltip: t['copy'] ?? 'Copy',
            ),
          ],
        ),
        SizedBox(
          height: 42,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
              color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            ),
            child: TextField(
              controller: controller,
              readOnly: true,
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorFormats {
  static Color? tryParse(String input) {
    final s = input.trim().toLowerCase();
    if (s.isEmpty) return null;

    final hex = _tryParseHex(s);
    if (hex != null) return hex;

    final rgb = _tryParseRgb(s);
    if (rgb != null) return rgb;

    final hsl = _tryParseHsl(s);
    if (hsl != null) return hsl;

    final cmyk = _tryParseCmyk(s);
    if (cmyk != null) return cmyk;

    return null;
  }

  static String toHex(Color c) {
    final a = c.alpha;
    final r = c.red.toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = c.green.toRadixString(16).padLeft(2, '0').toUpperCase();
    final b = c.blue.toRadixString(16).padLeft(2, '0').toUpperCase();
    if (a == 0xFF) return '#$r$g$b';
    final aa = a.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$aa$r$g$b';
  }

  static String toRgb(Color c) {
    if (c.alpha == 0xFF) {
      return 'rgb(${c.red}, ${c.green}, ${c.blue})';
    }
    final a = (c.alpha / 255)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return 'rgba(${c.red}, ${c.green}, ${c.blue}, $a)';
  }

  static String toHsl(Color c) {
    final hsl = HSLColor.fromColor(c);
    final h = hsl.hue.isNaN ? 0 : hsl.hue;
    final s = (hsl.saturation * 100).round();
    final l = (hsl.lightness * 100).round();
    if (c.alpha == 0xFF) {
      return 'hsl(${h.round()}, $s%, $l%)';
    }
    final a = (c.alpha / 255)
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return 'hsla(${h.round()}, $s%, $l%, $a)';
  }

  static String toCmyk(Color c) {
    final r = c.red / 255;
    final g = c.green / 255;
    final b = c.blue / 255;
    final k = 1 - math.max(r, math.max(g, b));
    double cyan;
    double magenta;
    double yellow;
    if (k >= 1) {
      cyan = 0;
      magenta = 0;
      yellow = 0;
    } else {
      cyan = (1 - r - k) / (1 - k);
      magenta = (1 - g - k) / (1 - k);
      yellow = (1 - b - k) / (1 - k);
    }
    final cp = (cyan * 100).round();
    final mp = (magenta * 100).round();
    final yp = (yellow * 100).round();
    final kp = (k * 100).round();
    return 'cmyk($cp%, $mp%, $yp%, $kp%)';
  }

  static Color? _tryParseHex(String s) {
    var v = s;
    if (v.startsWith('0x')) v = v.substring(2);
    if (v.startsWith('#')) v = v.substring(1);
    v = v.replaceAll(RegExp(r'\s+'), '');

    if (!RegExp(r'^[0-9a-f]+$').hasMatch(v)) return null;

    if (v.length == 3) {
      final r = v[0] * 2;
      final g = v[1] * 2;
      final b = v[2] * 2;
      return Color(int.parse('FF$r$g$b', radix: 16));
    }
    if (v.length == 4) {
      final a = v[0] * 2;
      final r = v[1] * 2;
      final g = v[2] * 2;
      final b = v[3] * 2;
      return Color(int.parse('$a$r$g$b', radix: 16));
    }
    if (v.length == 6) {
      return Color(int.parse('FF$v', radix: 16));
    }
    if (v.length == 8) {
      return Color(int.parse(v, radix: 16));
    }
    return null;
  }

  static Color? _tryParseRgb(String s) {
    final rgbFn = RegExp(r'^rgba?\((.+)\)$').firstMatch(s);
    if (rgbFn != null) {
      final parts = rgbFn.group(1)!.split(',').map((e) => e.trim()).toList();
      if (parts.length < 3) return null;
      final r = _parseRgbChannel(parts[0]);
      final g = _parseRgbChannel(parts[1]);
      final b = _parseRgbChannel(parts[2]);
      if (r == null || g == null || b == null) return null;
      var a = 1.0;
      if (parts.length >= 4) {
        final alpha = _parseAlpha(parts[3]);
        if (alpha == null) return null;
        a = alpha;
      }
      return Color.fromARGB((a * 255).round().clamp(0, 255), r, g, b);
    }

    final plain = s.replaceAll(RegExp(r'\s+'), '');
    final parts = plain.split(',');
    if (parts.length == 3 || parts.length == 4) {
      final r = int.tryParse(parts[0]);
      final g = int.tryParse(parts[1]);
      final b = int.tryParse(parts[2]);
      if (r == null || g == null || b == null) return null;
      var a = 1.0;
      if (parts.length == 4) {
        final alpha = _parseAlpha(parts[3]);
        if (alpha == null) return null;
        a = alpha;
      }
      return Color.fromARGB((a * 255).round().clamp(0, 255), r.clamp(0, 255),
          g.clamp(0, 255), b.clamp(0, 255));
    }
    return null;
  }

  static int? _parseRgbChannel(String s) {
    if (s.endsWith('%')) {
      final p = double.tryParse(s.substring(0, s.length - 1));
      if (p == null) return null;
      return (255 * (p / 100)).round().clamp(0, 255);
    }
    final v = double.tryParse(s);
    if (v == null) return null;
    return v.round().clamp(0, 255);
  }

  static double? _parseAlpha(String s) {
    if (s.endsWith('%')) {
      final p = double.tryParse(s.substring(0, s.length - 1));
      if (p == null) return null;
      return (p / 100).clamp(0.0, 1.0);
    }
    final v = double.tryParse(s);
    if (v == null) return null;
    if (v > 1) {
      return (v / 255).clamp(0.0, 1.0);
    }
    return v.clamp(0.0, 1.0);
  }

  static Color? _tryParseHsl(String s) {
    final m = RegExp(r'^hsla?\((.+)\)$').firstMatch(s);
    if (m == null) return null;
    final parts = m.group(1)!.split(',').map((e) => e.trim()).toList();
    if (parts.length < 3) return null;

    final h = _parseAngle(parts[0]);
    final sat = _parsePercent01(parts[1]);
    final lig = _parsePercent01(parts[2]);
    if (h == null || sat == null || lig == null) return null;
    var a = 1.0;
    if (parts.length >= 4) {
      final alpha = _parseAlpha(parts[3]);
      if (alpha == null) return null;
      a = alpha;
    }
    return HSLColor.fromAHSL(a, h, sat, lig).toColor();
  }

  static double? _parseAngle(String s) {
    var v = s.trim();
    v = v.replaceAll('deg', '');
    final d = double.tryParse(v);
    if (d == null) return null;
    final n = d % 360;
    return n < 0 ? n + 360 : n;
  }

  static double? _parsePercent01(String s) {
    final v = s.trim();
    if (!v.endsWith('%')) return null;
    final p = double.tryParse(v.substring(0, v.length - 1));
    if (p == null) return null;
    return (p / 100).clamp(0.0, 1.0);
  }

  static Color? _tryParseCmyk(String s) {
    final m = RegExp(r'^cmyk\((.+)\)$').firstMatch(s);
    if (m == null) return null;
    final parts = m.group(1)!.split(',').map((e) => e.trim()).toList();
    if (parts.length != 4) return null;
    final c = _parsePercentOr01(parts[0]);
    final m1 = _parsePercentOr01(parts[1]);
    final y = _parsePercentOr01(parts[2]);
    final k = _parsePercentOr01(parts[3]);
    if (c == null || m1 == null || y == null || k == null) return null;
    final r = (255 * (1 - c) * (1 - k)).round().clamp(0, 255);
    final g = (255 * (1 - m1) * (1 - k)).round().clamp(0, 255);
    final b = (255 * (1 - y) * (1 - k)).round().clamp(0, 255);
    return Color.fromARGB(0xFF, r, g, b);
  }

  static double? _parsePercentOr01(String s) {
    final v = s.trim();
    if (v.endsWith('%')) {
      final p = double.tryParse(v.substring(0, v.length - 1));
      if (p == null) return null;
      return (p / 100).clamp(0.0, 1.0);
    }
    final d = double.tryParse(v);
    if (d == null) return null;
    if (d > 1) return (d / 100).clamp(0.0, 1.0);
    return d.clamp(0.0, 1.0);
  }
}
