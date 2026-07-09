part of 'settings_page.dart';

class LabSettings extends StatefulWidget {
  const LabSettings({super.key});

  @override
  State<LabSettings> createState() => _LabSettingsState();
}

class _LabSettingsState extends State<LabSettings> {
  @override
  Widget build(BuildContext context) {
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
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
