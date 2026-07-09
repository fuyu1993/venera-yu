part of 'settings_page.dart';

class DeveloperSettings extends StatefulWidget {
  const DeveloperSettings({super.key});

  @override
  State<DeveloperSettings> createState() => _DeveloperSettingsState();
}

class _DeveloperSettingsState extends State<DeveloperSettings> {
  int? _memFree;
  int? _memTotal;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final free = await MemoryInfo.getFreePhysicalMemorySize();
    final total = await MemoryInfo.getTotalPhysicalMemorySize();
    if (mounted) {
      setState(() {
        _memFree = free;
        _memTotal = total;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageCache = PaintingBinding.instance.imageCache;
    final memUsed = (_memTotal != null && _memFree != null)
        ? _memTotal! - _memFree!
        : null;

    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("开发者选项".tl)),
        _SettingPartTitle(title: "内存".tl, icon: TIcons.hard_disk_storage),
        _infoCard([
          _row("已用物理内存",
              memUsed == null ? "—" : bytesToReadableString(memUsed)),
          _row("总物理内存",
              _memTotal == null ? "—" : bytesToReadableString(_memTotal!)),
          _row("可用物理内存",
              _memFree == null ? "—" : bytesToReadableString(_memFree!)),
        ]),
        _SettingPartTitle(title: "图片缓存 (Flutter ImageCache)".tl, icon: TIcons.image),
        _infoCard([
          _row("解码占用", bytesToReadableString(imageCache.currentSizeBytes)),
          _row("缓存条目", "${imageCache.currentSize}"),
          _row("活跃图片", "${imageCache.liveImageCount}"),
          _row("上限字节", bytesToReadableString(imageCache.maximumSizeBytes)),
        ]),
        _SettingPartTitle(title: "磁盘图片缓存".tl, icon: TIcons.hard_disk_storage),
        _infoCard([
          _row("CacheManager 占用",
              bytesToReadableString(CacheManager().currentSize)),
          _row("路径", CacheManager.cachePath),
        ]),
        _SettingPartTitle(title: "网络请求日志".tl, icon: TIcons.https),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Button.normal(
              onPressed: () => setState(() => devNetLogs.clear()),
              child: Text("清空日志".tl),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 520,
            child: devNetLogs.isEmpty
                ? const Center(child: Text("暂无请求记录"))
                : ListView.builder(
                    reverse: true,
                    itemCount: devNetLogs.length,
                    itemBuilder: (context, index) {
                      final log = devNetLogs[devNetLogs.length - 1 - index];
                      return _netLogTile(log);
                    },
                  ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  Widget _infoCard(List<Widget> rows) {
    return SliverToBoxAdapter(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _netLogTile(DevNetLog log) {
    final statusColor = log.error != null
        ? Colors.red
        : (log.statusCode != null && log.statusCode! >= 400)
            ? Colors.orange
            : Colors.green;
    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "${log.method} ${log.statusCode ?? 'ERR'}",
          style: TextStyle(color: statusColor, fontSize: 12),
        ),
      ),
      title: Text(
        log.url,
        style: const TextStyle(fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "${log.durationMs == null ? '—' : '${log.durationMs}ms'}"
        "${log.error != null ? '  ${log.error}' : ''}",
        style: const TextStyle(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
