import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../billing/billing_engine.dart';

/// Tokens visuais do Coach Flow Profissional.
///
/// Direção: placar esportivo. Fundo frio e claro, azul-marinho como cor de
/// marca, números em Barlow Condensed (fonte de placar) e um único acento
/// amarelo "cronômetro", usado só na raia de progresso do mês.
class CF {
  static const ink = Color(0xFF0F2236);
  static const inkSoft = Color(0xFF1D3757);
  static const inkLine = Color(0xFF2E4A6E);
  static const blue = Color(0xFF2459C7);
  static const bg = Color(0xFFF2F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFDDE4EE);
  static const text = Color(0xFF0E1A2B);
  static const muted = Color(0xFF55657A);

  static const green = Color(0xFF0E7C55);
  static const greenBg = Color(0xFFE2F4EB);
  static const mint = Color(0xFF3DDC97);
  static const amber = Color(0xFF8F5300);
  static const amberBg = Color(0xFFFFF0D2);
  static const red = Color(0xFFB42330);
  static const redBg = Color(0xFFFCE7E8);
  static const violet = Color(0xFF5B3FB0);
  static const violetBg = Color(0xFFEEE9FB);
  static const grey = Color(0xFF6B7788);
  static const greyBg = Color(0xFFEDF0F4);

  /// Acento único: amarelo cronômetro.
  static const lap = Color(0xFFFFC23D);

  static const whatsapp = Color(0xFF1FA855);

  /// Desligado nos testes automáticos, que não têm internet para baixar fontes.
  static bool useGoogleFonts = true;

  static TextStyle _barlow({double? fontSize, FontWeight? fontWeight, Color? color, double? height}) =>
      useGoogleFonts
          ? GoogleFonts.barlow(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height)
          : TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height);

  static TextStyle _condensed({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    List<FontFeature>? fontFeatures,
  }) =>
      useGoogleFonts
          ? GoogleFonts.barlowCondensed(
              fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, fontFeatures: fontFeatures)
          : TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color, height: height, fontFeatures: fontFeatures);

  static TextStyle score(double size, {Color color = text, FontWeight weight = FontWeight.w700}) =>
      _condensed(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle body(double size,
          {Color color = text, FontWeight weight = FontWeight.w400, double? height}) =>
      _barlow(fontSize: size, fontWeight: weight, color: color, height: height);

  static (Color fg, Color bg) forStatus(BillStatus s) => switch (s) {
        BillStatus.paid => (green, greenBg),
        BillStatus.partial => (amber, amberBg),
        BillStatus.pending => (blue, const Color(0xFFE6EEFC)),
        BillStatus.overdue => (red, redBg),
        BillStatus.nothing => (grey, greyBg),
      };

  static (Color fg, Color bg) forOutcome(LessonOutcome o) => switch (o) {
        LessonOutcome.charged => (blue, const Color(0xFFE6EEFC)),
        LessonOutcome.makeUpCharged => (blue, const Color(0xFFE6EEFC)),
        LessonOutcome.cancelledCharged => (amber, amberBg),
        LessonOutcome.movedChargedHere => (amber, amberBg),
        LessonOutcome.cancelledWaived => (red, redBg),
        LessonOutcome.waived => (grey, greyBg),
        LessonOutcome.holiday => (grey, greyBg),
        LessonOutcome.movedOut => (amber, amberBg),
        LessonOutcome.makeUpNotCharged => (grey, greyBg),
        LessonOutcome.credit => (violet, violetBg),
      };

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        secondary: blue,
        surface: surface,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: bg,
    );
    final textTheme = (useGoogleFonts ? GoogleFonts.barlowTextTheme(base.textTheme) : base.textTheme).copyWith(
      headlineMedium: _barlow(fontWeight: FontWeight.w700, color: text),
      titleLarge: _barlow(fontWeight: FontWeight.w700, color: text),
      titleMedium: _barlow(fontWeight: FontWeight.w600, color: text),
      bodyMedium: _barlow(color: muted, fontSize: 15),
      bodyLarge: _barlow(color: text, fontSize: 16),
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFDCE4EF),
          disabledForegroundColor: const Color(0xFF718096),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: shape,
          textStyle: _barlow(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: surface,
          side: const BorderSide(color: line, width: 1.5),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: shape,
          textStyle: _barlow(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          textStyle: _barlow(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 2)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: line),
        labelStyle: _barlow(fontSize: 15, fontWeight: FontWeight.w600, color: text),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bg,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: _barlow(color: Colors.white, fontSize: 15),
        actionTextColor: lap,
        shape: shape,
      ),
      dividerTheme: const DividerThemeData(color: line, space: 1),
    );
  }
}

/// Selo de situação (Pago, Atrasado...).
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final BillStatus status;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = CF.forStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          switch (status) {
            BillStatus.paid => Icons.check_circle_rounded,
            BillStatus.overdue => Icons.error_rounded,
            BillStatus.partial => Icons.timelapse_rounded,
            _ => Icons.schedule_rounded,
          },
          size: 15,
          color: fg,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(status.label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: CF.body(13, color: fg, weight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// Raia de pista: mostra quanto do mês já foi recebido.
class LaneTrack extends StatelessWidget {
  const LaneTrack({super.key, required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double p = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return SizedBox(
        height: 26,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0, right: 0, top: 6,
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: CF.inkSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: CF.inkLine),
              ),
            ),
          ),
          // Marcas de raia a cada 25%.
          for (final f in const [0.25, 0.5, 0.75])
            Positioned(
              left: w * f - 1, top: 4,
              child: Container(width: 2, height: 18, color: CF.inkLine),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            left: 0, top: 6,
            width: (w * p).clamp(0.0, w).toDouble(),
            child: Container(
              height: 14,
              decoration: BoxDecoration(color: CF.mint, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            left: (w * p - 13).clamp(-2.0, w - 24).toDouble(),
            top: 0,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: CF.lap,
                shape: BoxShape.circle,
                border: Border.all(color: CF.ink, width: 3),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

const weekdayShort = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const weekdayLong = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

String ddmm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String routineText(StudentPlan p) {
  final days = p.weekdays.toList()..sort();
  if (days.isEmpty) return 'Sem dias fixos';
  final names = days.map((d) => weekdayShort[d - 1]).toList();
  final joined = names.length == 1
      ? names.first
      : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
  final times = days.map((d) => p.times[d]).whereType<String>().toSet();
  if (times.length == 1) return '$joined às ${times.first}';
  if (times.isEmpty) return joined;
  // Horários diferentes: "seg 07:00, qua 18:30".
  return days.map((d) => '${weekdayShort[d - 1]} ${p.times[d] ?? ''}'.trim()).join(', ');
}

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
