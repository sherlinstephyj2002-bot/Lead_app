import 'dart:math';
import 'package:flutter/material.dart';

class CaptchaWidget extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<bool>? onValidationChanged;

  const CaptchaWidget({
    super.key,
    required this.controller,
    this.onValidationChanged,
  });

  @override
  State<CaptchaWidget> createState() => CaptchaWidgetState();
}

class CaptchaWidgetState extends State<CaptchaWidget> {
  late String _captchaCode;

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (widget.onValidationChanged != null) {
      widget.onValidationChanged!(validate());
    }
  }

  void _refreshCaptcha() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final rand = Random();
    setState(() {
      _captchaCode = List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
    });
    widget.controller.clear();
  }

  bool validate() {
    return widget.controller.text.trim().toUpperCase() == _captchaCode.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF5B4CF0);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Security Verification *',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            Text(
              'Case-insensitive',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // CAPTCHA Display Box with noise background
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _CaptchaPainter(_captchaCode, isDark: isDark),
                  child: Container(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: primaryColor, size: 20),
                onPressed: _refreshCaptcha,
                tooltip: 'Refresh CAPTCHA',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        TextFormField(
          controller: widget.controller,
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: titleColor, letterSpacing: 2),
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Enter 5-character code above',
            hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8), letterSpacing: 0),
            prefixIcon: const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF64748B)),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444))),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the verification code.';
            }
            if (value.trim().toUpperCase() != _captchaCode.toUpperCase()) {
              return 'Incorrect verification code. Please try again.';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class _CaptchaPainter extends CustomPainter {
  final String code;
  final bool isDark;

  _CaptchaPainter(this.code, {required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(code.hashCode);

    // Draw background security lines
    final linePaint = Paint()
      ..color = (isDark ? Colors.indigo.shade400 : Colors.indigo.shade200).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 4; i++) {
      final p1 = Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height);
      final p2 = Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height);
      canvas.drawLine(p1, p2, linePaint);
    }

    // Draw characters with subtle rotation & color shift
    final double letterSpacing = size.width / (code.length + 1);
    for (int i = 0; i < code.length; i++) {
      final textSpan = TextSpan(
        text: code[i],
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.indigo.shade200 : const Color(0xFF4338CA),
          letterSpacing: 2,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final x = (i + 0.6) * letterSpacing;
      final y = (size.height - textPainter.height) / 2;

      canvas.save();
      canvas.translate(x, y + textPainter.height / 2);
      final angle = (rand.nextDouble() - 0.5) * 0.3; // Small random tilt
      canvas.rotate(angle);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CaptchaPainter oldDelegate) => oldDelegate.code != code;
}
