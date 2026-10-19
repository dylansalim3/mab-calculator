import 'package:flutter/material.dart';

String colorHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Simple HSV colour picker: three sliders, live preview and hex code.
class ColorPickerDialog extends StatefulWidget {
  const ColorPickerDialog({super.key, required this.initial});

  final Color initial;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> on,
  ) {
    return Row(
      children: [
        SizedBox(width: 96, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            semanticFormatterCallback: (v) => '$label ${v.round()}',
            onChanged: on,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      title: const Text('Pick a color'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: double.infinity,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                colorHex(color),
                style: TextStyle(
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _slider(
              'Hue',
              _hsv.hue,
              360,
              (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            _slider(
              'Saturation',
              _hsv.saturation * 100,
              100,
              (v) => setState(() => _hsv = _hsv.withSaturation(v / 100)),
            ),
            _slider(
              'Brightness',
              _hsv.value * 100,
              100,
              (v) => setState(() => _hsv = _hsv.withValue(v / 100)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, color),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
