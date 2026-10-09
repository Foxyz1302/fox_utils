import 'dart:math';

import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.gradient});

  final Widget text;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: text,
    );
  }
}

enum CornerSide { topLeft, topRight, bottomLeft, bottomRight }

class SingleScoopedCornerClipper extends CustomClipper<Path> {
  SingleScoopedCornerClipper({required this.radius, this.side = CornerSide.topRight});

  final double radius;
  final CornerSide side;

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Start at top-left
    path.moveTo(0, 0);

    switch (side) {
      case CornerSide.topRight:
        // Draw top edge to where the curve starts (right side)
        path.lineTo(w - radius, 0);
        // Concave arc
        path.arcToPoint(Offset(w, radius), radius: Radius.circular(radius), clockwise: false);
        // Draw remainder of edges
        path.lineTo(w, h);
        path.lineTo(0, h);
        break;

      case CornerSide.bottomRight:
        // Draw right edge to where the curve starts (bottom side)
        path.lineTo(w, h - radius);
        // Concave arc
        path.arcToPoint(Offset(w - radius, h), radius: Radius.circular(radius), clockwise: false);
        // Draw remainder of edges
        path.lineTo(0, h);
        break;

      case CornerSide.bottomLeft:
        // Draw bottom edge to where the curve starts (left side)
        path.lineTo(radius, h);
        // Concave arc
        path.arcToPoint(Offset(0, h - radius), radius: Radius.circular(radius), clockwise: false);
        // Draw remainder of edges
        path.lineTo(0, 0); // Already moved here, just closing path
        break;

      case CornerSide.topLeft:
        // Draw left edge to where the curve starts (top side)
        path.lineTo(0, radius);
        // Concave arc
        path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius), clockwise: false);
        // Draw remainder of edges
        path.lineTo(w, 0);
        path.lineTo(w, h);
        path.lineTo(0, h);
        break;
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(SingleScoopedCornerClipper oldClipper) => oldClipper.radius != radius || oldClipper.side != side;
}

extension IntBytesExtension on int {
  /// Converts to Kilobytes (1024 bytes)
  int get kb => this * 1024;

  /// Converts to Megabytes (1024 * 1024 bytes)
  int get mb => this * 1024 * 1024;

  /// Converts to Gigabytes (1024 * 1024 * 1024 bytes)
  int get gb => this * 1024 * 1024 * 1024;

  /// Converts to Terabytes (1024^4 bytes)
  int get tb => this * 1024 * 1024 * 1024 * 1024;
}

String formatBytes(int bytes, {int decimals = 2, bool useBinary = true}) {
  if (bytes <= 0) return "0 B";

  // Choose between binary (1024) or decimal (1000) base
  final base = useBinary ? 1024.0 : 1000.0;
  final units = useBinary
      ? ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB']
      : ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];

  final exp = (log(bytes) / log(base)).floor();
  final size = bytes / pow(base, exp);

  // Clamp the exponent to avoid index out of bounds
  final unitIndex = exp.clamp(0, units.length - 1);

  return '${size.toStringAsFixed(decimals)} ${units[unitIndex]}';
}

// Extension method for easier usage
extension BytesFormatter on int {
  String toReadableSize({int decimals = 2}) => formatBytes(this, decimals: decimals);
}

extension DateTimeExtension on DateTime {
  String timeAgo() {
    final diff = DateTime.now().difference(this);
    if (diff.inDays >= 1) return '${diff.inDays} days ago';
    if (diff.inHours >= 1) return '${diff.inHours} hours ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} minutes ago';
    return 'Just now';
  }

  String toSmartDateWithTime() {
    final now = DateTime.now();
    final diff = now.difference(this);

    // Helper for "14:30" format
    final clockTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    String datePart;

    // 1. Just now
    if (diff.inMinutes < 1) {
      datePart = 'just now';
    }
    // 2. Minute precision (up to 1 hour)
    else if (diff.inHours < 1) {
      datePart = '${diff.inMinutes}m ago';
    }
    // 3. Hour precision (up to 24 hours)
    else if (diff.inDays < 1) {
      datePart = '${diff.inHours}h ago';
    }
    // 4. Compact date (older than a day)
    else if (year == now.year) {
      datePart = '${_getMonth(month)} $day';
    } else {
      datePart = '${_getMonth(month)} $day, $year';
    }

    // Combine them: "5m ago at 14:30" or "Jan 2 at 07:11"
    return '$datePart at $clockTime';
  }

  String _getMonth(int month) {
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
  }

  String _getWeekday(int day) {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
  }
}

extension CompactDateTime on DateTime {
  String toCompactPostDate() {
    final now = DateTime.now();
    final difference = now.difference(this);

    // 1. Less than a minute: "Just now"
    if (difference.inMinutes < 1) {
      return 'now';
    }

    // 2. Less than an hour: "5m", "59m"
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    }

    // 3. Less than a day: "2h", "23h"
    if (difference.inDays < 1) {
      return '${difference.inHours}h';
    }

    // 4. Less than a week: "Mon", "Tue"
    if (difference.inDays < 7) {
      return _getWeekday(weekday);
    }

    // 5. This calendar year: "Mar 12"
    if (year == now.year) {
      return '${_getMonth(month)} $day';
    }

    // 6. Different year: "Mar 2024"
    return '${_getMonth(month)} $year';
  }

  // Helper for short weekdays
  String _getWeekday(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day - 1];
  }

  // Helper for short months
  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

extension TimeGradientColor on DateTime {
  Color toSkyColor(Color baseColor) {
    // Define the color transition for a full 24-hour cycle
    const skyline = LinearGradient(
      colors: [
        Color(0xFF0F172A), // 00:00 - Deep Night
        Color(0xFF334155), // 06:00 - Dawn
        Color(0xFF7DD3FC), // 12:00 - Noon
        Color(0xFFFB923C), // 18:00 - Sunset
        Color(0xFF0F172A), // 24:00 - Back to Night
      ],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    // Calculate the day's progress (0.0 to 1.0)
    final double dayProgress = (hour * 60 + minute) / (24 * 60);

    // Sample the color from the gradient
    final Color sampledColor = _sampleGradient(skyline, dayProgress);

    // Blend it subtly with your theme's surface color (15% intensity)
    return Color.lerp(baseColor, sampledColor, 0.15)!;
  }

  // Helper to interpolate color from a LinearGradient
  Color _sampleGradient(LinearGradient gradient, double t) {
    if (t <= 0) return gradient.colors.first;
    if (t >= 1) return gradient.colors.last;

    final int segmentCount = gradient.colors.length - 1;
    final double segmentValue = t * segmentCount;
    final int index = segmentValue.floor();
    final double weight = segmentValue - index;

    return Color.lerp(gradient.colors[index], gradient.colors[index + 1], weight)!;
  }
}

extension NullableProgress01 on ImageChunkEvent? {
  /// 0.0 → 1.0 while loading; null when unknown.
  double? get progress {
    final chunk = this;
    if (chunk == null) return null;

    final total = chunk.expectedTotalBytes;
    return (total != null && total > 0) ? (chunk.cumulativeBytesLoaded / total).clamp(0.0, 1.0) : null;
  }
}

extension ObjectExt<T> on T {
  R let<R>(R Function(T e) block) => block(this);
}

extension ColorUtils on Color {
  // ---------------------------------------------------------
  // 1. Brightness Manipulation (HSL Based)
  // ---------------------------------------------------------

  /// Darkens the color by a given [amount] (0.0 to 1.0).
  ///
  /// Defaults to 10% (0.1).
  /// Uses HSL calculation to preserve color hue.
  // Color darken([double amount = 0.1]) {
  //   assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');

  //   final hsl = HSLColor.fromColor(this);
  //   final newLightness = (hsl.lightness - amount).clamp(0.0, 1.0);

  //   return hsl.withLightness(newLightness).toColor();
  // }

  // /// Lightens the color by a given [amount] (0.0 to 1.0).
  // ///
  // /// Defaults to 10% (0.1).
  // /// Uses HSL calculation to preserve color hue.
  // Color lighten([double amount = 0.1]) {
  //   assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');

  //   final hsl = HSLColor.fromColor(this);
  //   final newLightness = (hsl.lightness + amount).clamp(0.0, 1.0);

  //   return hsl.withLightness(newLightness).toColor();
  // }

  // ---------------------------------------------------------
  // 2. Opacity & Color Mixing
  // ---------------------------------------------------------

  /// Returns a new color with the specified opacity.
  /// Shortcut for `withOpacity`.
  Color withOpacityValue(double opacity) {
    return withOpacity(opacity);
  }

  /// Blends this color with another color.
  ///
  /// [amount] defines how much of [color] to mix in (0.0 to 1.0).
  /// 0.0 results in the original color, 1.0 results in the input color.
  Color mix(Color color, [double amount = 0.5]) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');

    return Color.lerp(this, color, amount)!;
  }

  // ---------------------------------------------------------
  // 3. Color Properties & Conversion
  // ---------------------------------------------------------

  /// Returns the color as a Hex string (e.g. "#FF0000").
  /// Includes alpha channel if [includeAlpha] is true.
  String toHexString({bool includeAlpha = false}) {
    if (includeAlpha) {
      return '#${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    }
    return '#${value.toRadixString(16).substring(2).padLeft(6, '0').toUpperCase()}';
  }

  /// Calculates the relative luminance.
  /// Useful for determining if the color is "light" or "dark".
  bool get isDark => computeLuminance() < 0.5;

  bool get isLight => !isDark;

  /// Returns a contrasting text color (Black or White)
  /// suitable for reading on top of this color.
  Color get contrastingColor => isDark ? Colors.white : Colors.black;
}

/// Optional: Extension on String to parse Hex colors easily.
extension StringColorUtils on String {
  /// Parses a hex string to a Color.
  /// Supports formats: "FF0000", "#FF0000", "0xFF0000", "#FFFF0000".
  Color toColor() {
    var hexColor = replaceAll('#', '').replaceAll('0x', '');

    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Add full opacity if alpha is missing
    }

    return Color(int.parse(hexColor, radix: 16));
  }
}

enum Side { top, left, bottom, right }

extension NumBorderRadiusExtension on num {
  /// Creates a circular radius where specific sides are flattened (radius = 0).
  ///
  /// Example:
  /// ```
  /// // A pill shape flattened on the left side
  /// Container(
  ///   decoration: BoxDecoration(
  ///     borderRadius: 50.circularExcept({Side.left}),
  ///     color: Colors.blue,
  ///   ),
  /// )
  /// ```
  BorderRadius circularExcept(Set<Side> excludedSides) {
    final double r = toDouble();

    // If a side is in the exclusion set, its corners become 0.
    // Otherwise, they take the radius [r].

    // Top-Left is affected by Top OR Left
    final tl = (excludedSides.contains(Side.top) || excludedSides.contains(Side.left)) ? 0.0 : r;

    // Top-Right is affected by Top OR Right
    final tr = (excludedSides.contains(Side.top) || excludedSides.contains(Side.right)) ? 0.0 : r;

    // Bottom-Left is affected by Bottom OR Left
    final bl = (excludedSides.contains(Side.bottom) || excludedSides.contains(Side.left)) ? 0.0 : r;

    // Bottom-Right is affected by Bottom OR Right
    final br = (excludedSides.contains(Side.bottom) || excludedSides.contains(Side.right)) ? 0.0 : r;

    return BorderRadius.only(
      topLeft: Radius.circular(tl),
      topRight: Radius.circular(tr),
      bottomLeft: Radius.circular(bl),
      bottomRight: Radius.circular(br),
    );
  }

  BorderRadius get circular {
    return BorderRadius.circular(this.toDouble());
  }
}

// Optional: Extension on BorderRadius itself if you want to modify an existing one
extension BorderRadiusModifier on BorderRadius {
  BorderRadius exclude(Set<Side> sides) {
    return copyWith(
      topLeft: sides.contains(Side.top) || sides.contains(Side.left) ? Radius.zero : topLeft,
      topRight: sides.contains(Side.top) || sides.contains(Side.right) ? Radius.zero : topRight,
      bottomLeft: sides.contains(Side.bottom) || sides.contains(Side.left) ? Radius.zero : bottomLeft,
      bottomRight: sides.contains(Side.bottom) || sides.contains(Side.right) ? Radius.zero : bottomRight,
    );
  }
}
