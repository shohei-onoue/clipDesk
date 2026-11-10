import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Figma「icon_list」(273:987) のアイコン。assets/icons/ の SVG を単色で塗って表示する。
/// 名前の `Fill` つきは塗りつぶし版（選択中・現在地用）、なしは線画版。
enum AppIcons {
  upload('upload'),
  send('send'),
  systemUpdateAlt('system_update_alt'),
  menu('menu'),
  back('back'),
  attachFile('attach_file'),
  repeatOn('repeat_on'),
  photo('photo'),
  title('title'),
  delete('delete'),
  doneOutline('done_outline'),
  viewCozy('view_cozy'),
  logout('logout'),
  addCircle('add_circle'),
  addCircleFill('add_circle_fill'),
  calendarMonth('calendar_month'),
  calendarMonthFill('calendar_month_fill'),
  notifications('notifications'),
  notificationsFill('notifications_fill'),
  settings('settings'),
  settingsFill('settings_fill');

  const AppIcons(this.file);
  final String file;
  String get path => 'assets/icons/$file.svg';
}

/// アイコン1つ。[size] は論理ピクセル（Figma の元サイズは40）。
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 40, required this.color});

  final AppIcons icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        icon.path,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
