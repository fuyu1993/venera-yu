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
    final remoteEnabled = appdata.settings['enableRemoteLibrary'] == true;
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("实验室".tl)),
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
        _SettingPartTitle(
          title: "远程书库".tl,
          icon: LucideIcons.globe,
        ),
        _SwitchSetting(
          title: "开启远程书库".tl,
          settingKey: "enableRemoteLibrary",
          subtitle: "在底部标签栏新增「远程书库」，可直接阅读远程 WebDAV 网盘中的漫画".tl,
          onChanged: () => setState(() {}),
        ).toSliver(),
        if (remoteEnabled)
          _CallbackSetting(
            title: "远程书库 WebDAV 设置".tl,
            subtitle: "配置远程网盘的地址、账号与根目录".tl,
            actionTitle: "设置".tl,
            callback: () {
              showDialog(
                context: context,
                builder: (_) => const _RemoteWebDavSetting(),
              );
            },
          ).toSliver(),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _RemoteWebDavSetting extends StatefulWidget {
  const _RemoteWebDavSetting();

  @override
  State<_RemoteWebDavSetting> createState() => _RemoteWebDavSettingState();
}

class _RemoteWebDavSettingState extends State<_RemoteWebDavSetting> {
  String url = "";
  String user = "";
  String pass = "";
  String root = "/";

  bool _testing = false;

  @override
  void initState() {
    super.initState();
    if (appdata.settings[RemoteWebDav.configKey] is! List) {
      appdata.settings[RemoteWebDav.configKey] = [];
    }
    var configs = appdata.settings[RemoteWebDav.configKey] as List;
    if (configs.whereType<String>().length == 3) {
      url = configs[0];
      user = configs[1];
      pass = configs[2];
    }
    var r = appdata.settings[RemoteWebDav.rootKey];
    if (r is String && r.isNotEmpty) {
      root = r;
    }
  }

  void _save() {
    root = root.trim();
    if (root.isEmpty) root = '/';
    if (!root.startsWith('/')) root = '/$root';
    appdata.settings[RemoteWebDav.configKey] = [url.trim(), user.trim(), pass];
    appdata.settings[RemoteWebDav.rootKey] = root;
    appdata.saveData();
    context.showMessage(message: "Saved".tl);
    Navigator.of(context).pop();
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      var client = newClient(
        url.trim(),
        user: user.trim(),
        password: pass,
        adapter: RHttpAdapter(),
      );
      var testRoot = root.trim();
      if (testRoot.isEmpty) testRoot = '/';
      if (!testRoot.startsWith('/')) testRoot = '/$testRoot';
      await client.readDir(testRoot);
      if (mounted) context.showMessage(message: "Connection success".tl);
    } catch (e) {
      if (mounted) {
        context.showMessage(message: "${"Connection failed".tl}: $e");
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: "Remote Library WebDAV".tl,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL 输入框
          TextField(
            decoration: InputDecoration(
              labelText: "URL".tl,
              hintText: "http://host:5244/dav/".tl,
              prefixIcon: const Icon(LucideIcons.link, size: 18),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            controller: TextEditingController(text: url),
            onChanged: (v) => url = v,
          ),
          const SizedBox(height: 16),
          // 用户名输入框
          TextField(
            decoration: InputDecoration(
              labelText: "Username".tl,
              prefixIcon: const Icon(LucideIcons.user, size: 18),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            controller: TextEditingController(text: user),
            onChanged: (v) => user = v,
          ),
          const SizedBox(height: 16),
          // 密码输入框
          TextField(
            decoration: InputDecoration(
              labelText: "Password".tl,
              prefixIcon: const Icon(LucideIcons.lock, size: 18),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            controller: TextEditingController(text: pass),
            onChanged: (v) => pass = v,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          // 根路径输入框
          TextField(
            decoration: InputDecoration(
              labelText: "Root Path".tl,
              hintText: "/  or  /comics".tl,
              prefixIcon: const Icon(LucideIcons.folder, size: 18),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            controller: TextEditingController(text: root),
            onChanged: (v) => root = v,
          ),
          const SizedBox(height: 8),
          // 提示文本
          Text(
            "设置远程书库的根目录路径，例如 /comics".tl,
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.outline,
            ),
          ),
        ],
      ),
      actions: [
        FilledButton.tonal(
          onPressed: _testing ? null : _test,
          child: _testing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text("Test Connection".tl),
        ),
        FilledButton(
          onPressed: _save,
          child: Text("Save".tl),
        ),
      ],
    );
  }
}
