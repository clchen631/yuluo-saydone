import 'package:flutter/cupertino.dart';

/// 主题数据：浅色/深色的所有语义色
class AppThemeData {
  final Color background;
  final Color surface;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color text;
  final Color textSecondary;
  final Color separator;
  final Color separatorStrong;
  final Color destructive;
  final Color destructiveDark;
  final Color white;
  final Color star;
  final Color sectionCardBg;
  final Color taskCardBg;
  final Color toastBg;

  const AppThemeData({
    required this.background,
    required this.surface,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.text,
    required this.textSecondary,
    required this.separator,
    required this.separatorStrong,
    required this.destructive,
    required this.destructiveDark,
    required this.white,
    required this.star,
    required this.sectionCardBg,
    required this.taskCardBg,
    required this.toastBg,
  });
}

/// 浅色主题
const lightTheme = AppThemeData(
  background:      Color(0xFFFEF6E4),
  surface:         Color(0xFFFFEACC),
  primary:         Color(0xFF5EC8FF),
  primaryDark:     Color(0xFF38A0E6),
  primaryLight:    Color(0xFFB0DDFF),
  text:            Color(0xFF1C1F2E),
  textSecondary:   Color(0xFF7A8296),
  separator:       Color(0xFFFFE0B8),
  separatorStrong: Color(0xFFFFD4A0),
  destructive:     Color(0xFFDA8084),
  destructiveDark: Color(0xFFB56569),
  white:           Color(0xFFFFFFFF),
  star:            Color(0xFFE0A830),
  sectionCardBg:   Color(0xFFFFFEFC),
  taskCardBg:      Color(0xFFFFFEFC),
  toastBg:         Color(0xCC2C2C2E),
);

/// 深色主题
const darkTheme = AppThemeData(
  background:      Color(0xFF1A1C24),
  surface:         Color(0xFF252730),
  primary:         Color(0xFF459CCE),
  primaryDark:     Color(0xFF38A0E6),
  primaryLight:    Color(0xFFB0DDFF),
  text:            Color(0xFFE8E9EE),
  textSecondary:   Color(0xFF8B8D97),
  separator:       Color(0xFF2E303A),
  separatorStrong: Color(0xFF383A46),
  destructive:     Color(0xFFE89094),
  destructiveDark: Color(0xFFB56569),
  white:           Color(0xFFFFFFFF),
  star:            Color(0xFFE0A830),
  sectionCardBg:   Color(0xFF2A2B34),
  taskCardBg:      Color(0xFF2A2B34),
  toastBg:         Color(0xE0383A46),
);

/// 通过 InheritedWidget 向子树提供当前主题数据
class AppTheme extends InheritedWidget {
  final AppThemeData data;

  const AppTheme({super.key, required this.data, required super.child});

  static AppThemeData of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    assert(result != null, 'No AppTheme found in context');
    return result!.data;
  }

  @override
  bool updateShouldNotify(covariant AppTheme oldWidget) => data != oldWidget.data;
}

/// CupertinoTheme 配置（浅色）
final appTheme = CupertinoThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: lightTheme.background,
  primaryColor: lightTheme.primary,
  barBackgroundColor: lightTheme.surface,
);

/// CupertinoTheme 配置（深色）
final appDarkTheme = CupertinoThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: darkTheme.background,
  primaryColor: darkTheme.primary,
  barBackgroundColor: darkTheme.surface,
);
