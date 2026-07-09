part of 'settings_page.dart';

class LabSettings extends StatefulWidget {
  const LabSettings({super.key});

  @override
  State<LabSettings> createState() => _LabSettingsState();
}

class _LabSettingsState extends State<LabSettings> {
  @override
  Widget build(BuildContext context) {
    final devMode = appdata.settings['lab_developerMode'] == true;
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("实验室".tl)),
        _SettingPartTitle(
          title: "实验性功能".tl,
          icon: Icons.science_outlined,
        ),
        _SwitchSetting(
          title: "隐藏漫画缩略图".tl,
          settingKey: "lab_hideThumbnails",
          subtitle: "隐藏所有漫画封面图片，使用占位图标代替".tl,
        ).toSliver(),
        _SwitchSetting(
          title: "开发者模式".tl,
          settingKey: "lab_developerMode",
          subtitle: "显示额外的开发者选项和调试信息".tl,
          onChanged: () => setState(() {}),
        ).toSliver(),
        if (devMode)
          _CallbackSetting(
            title: "开发者选项".tl,
            subtitle: "网络日志 / 内存 / 缓存统计".tl,
            actionTitle: "打开".tl,
            callback: () => context.to(() => const DeveloperSettings()),
          ).toSliver(),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
