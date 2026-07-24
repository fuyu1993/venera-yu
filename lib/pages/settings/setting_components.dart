part of 'settings_page.dart';

/// Wraps a settings row with a thin bottom divider so that independent
/// setting elements are visually separated in the list.
/// In Cupertino mode the divider is skipped — [CupertinoListSection]
/// provides its own separators.
Widget _divided(BuildContext context, Widget child) {
  if (isCupertinoStyle()) return child;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      child,
      Divider(
        height: 1,
        thickness: 1,
        color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    ],
  );
}

class _SwitchSetting extends StatefulWidget {
  const _SwitchSetting({
    required this.title,
    required this.settingKey,
    this.onChanged,
    this.subtitle,
    this.comicId,
    this.comicSource,
    this.useDeviceSettings = false,
  });

  final String title;

  final String settingKey;

  final VoidCallback? onChanged;

  final String? subtitle;

  final String? comicId;

  final String? comicSource;

  final bool useDeviceSettings;

  @override
  State<_SwitchSetting> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends State<_SwitchSetting> {
  @override
  Widget build(BuildContext context) {
    var rawValue = widget.comicId != null
        ? appdata.settings.getReaderSetting(
            widget.comicId!,
            widget.comicSource!,
            widget.settingKey,
          )
        : widget.useDeviceSettings
        ? appdata.settings.getDeviceReaderSetting(widget.settingKey)
        : appdata.settings[widget.settingKey];

    // Coerce to bool defensively. Some settings keys (e.g. freshly added
    // toggles) may be missing from the persisted config, in which case the
    // value is null rather than a bool. Treat any non-bool value as `false`
    // instead of asserting, which would crash the whole settings page.
    final bool value = rawValue is bool ? rawValue : false;

    void handleChanged(bool newValue) {
      setState(() {
        if (widget.comicId != null) {
          appdata.settings.setReaderSetting(
            widget.comicId!,
            widget.comicSource!,
            widget.settingKey,
            newValue,
          );
        } else if (widget.useDeviceSettings) {
          appdata.settings.setDeviceReaderSetting(widget.settingKey, newValue);
        } else {
          appdata.settings[widget.settingKey] = newValue;
        }
      });
      appdata.saveData().then((_) {
        widget.onChanged?.call();
      });
    }

    if (isCupertinoStyle()) {
      return CupertinoListTile(
        title: Text(widget.title),
        subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
        trailing: CupertinoSwitch(
          value: value,
          onChanged: handleChanged,
        ),
      );
    }

    return _divided(
      context,
      ListTile(
        title: Text(widget.title),
        subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
        trailing: Switch(
          value: value,
          onChanged: handleChanged,
        ),
      ),
    );
  }
}

class SelectSetting extends StatelessWidget {
  const SelectSetting({
    super.key,
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
    this.comicId,
    this.comicSource,
    this.useDeviceSettings = false,
    this.divided = true,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  final String? comicId;

  final String? comicSource;

  final bool useDeviceSettings;

  final bool divided;

  @override
  Widget build(BuildContext context) {
    if (isCupertinoStyle()) {
      return _CupertinoSelectSetting(
        title: title,
        settingKey: settingKey,
        optionTranslation: optionTranslation,
        onChanged: onChanged,
        help: help,
        comicId: comicId,
        comicSource: comicSource,
        useDeviceSettings: useDeviceSettings,
      );
    }

    final child = SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 450) {
            return _DoubleLineSelectSettings(
              title: title,
              settingKey: settingKey,
              optionTranslation: optionTranslation,
              onChanged: onChanged,
              help: help,
              comicId: comicId,
              comicSource: comicSource,
              useDeviceSettings: useDeviceSettings,
            );
          } else {
            return _EndSelectorSelectSetting(
              title: title,
              settingKey: settingKey,
              optionTranslation: optionTranslation,
              onChanged: onChanged,
              help: help,
              comicId: comicId,
              comicSource: comicSource,
              useDeviceSettings: useDeviceSettings,
            );
          }
        },
      ),
    );
    return divided ? _divided(context, child) : child;
  }
}

/// Cupertino variant of [SelectSetting].
///
/// When the number of options is small (≤ 3) a
/// [CupertinoSlidingSegmentedControl] is shown inline.
/// For more options a [CupertinoListTile] with a chevron is used,
/// tapping it opens a [CupertinoActionSheet].
class _CupertinoSelectSetting extends StatefulWidget {
  const _CupertinoSelectSetting({
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
    this.comicId,
    this.comicSource,
    this.useDeviceSettings = false,
  });

  final String title;
  final String settingKey;
  final Map<String, String> optionTranslation;
  final VoidCallback? onChanged;
  final String? help;
  final String? comicId;
  final String? comicSource;
  final bool useDeviceSettings;

  @override
  State<_CupertinoSelectSetting> createState() =>
      _CupertinoSelectSettingState();
}

class _CupertinoSelectSettingState extends State<_CupertinoSelectSetting> {
  dynamic _getValue() {
    return widget.comicId != null
        ? appdata.settings.getReaderSetting(
            widget.comicId!,
            widget.comicSource!,
            widget.settingKey,
          )
        : widget.useDeviceSettings
            ? appdata.settings.getDeviceReaderSetting(widget.settingKey)
            : appdata.settings[widget.settingKey];
  }

  void _setValue(String value) {
    setState(() {
      if (widget.comicId != null) {
        appdata.settings.setReaderSetting(
          widget.comicId!,
          widget.comicSource!,
          widget.settingKey,
          value,
        );
      } else if (widget.useDeviceSettings) {
        appdata.settings.setDeviceReaderSetting(widget.settingKey, value);
      } else {
        appdata.settings[widget.settingKey] = value;
      }
    });
    appdata.saveData();
    widget.onChanged?.call();
  }

  void _showHelp() {
    if (widget.help == null) return;
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text("Help".tl),
          content: Text(widget.help!),
          actions: [
            CupertinoDialogAction(
              child: Text("OK".tl),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _showActionSheet() {
    final value = _getValue();
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text(widget.title),
          actions: widget.optionTranslation.entries.map((entry) {
            return CupertinoActionSheetAction(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.value),
                  if (entry.key == value) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      CupertinoIcons.check_mark,
                      size: 18,
                    ),
                  ],
                ],
              ),
              onPressed: () {
                Navigator.pop(context, entry.key);
              },
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            child: Text("Cancel".tl),
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    ).then((selectedKey) {
      if (selectedKey != null) {
        _setValue(selectedKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _getValue();
    final options = widget.optionTranslation;
    final useSegmented = options.length <= 3;

    if (useSegmented) {
      // Few options → inline segmented control
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                  ),
                  if (widget.help != null) ...[
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: _showHelp,
                      child: Text(
                        "Help".tl,
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: value,
              children: {
                for (final entry in options.entries)
                  entry.key: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              },
              onValueChanged: (newValue) {
                if (newValue != null) _setValue(newValue);
              },
            ),
          ],
        ),
      );
    }

    // Many options → chevron tile that opens an action sheet
    return CupertinoListTile(
      title: Text(widget.title),
      additionalInfo: Text(options[value] ?? "None".tl),
      trailing: const CupertinoListTileChevron(),
      onTap: _showActionSheet,
    );
  }
}

class _DoubleLineSelectSettings extends StatefulWidget {
  const _DoubleLineSelectSettings({
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
    this.comicId,
    this.comicSource,
    this.useDeviceSettings = false,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  final String? comicId;

  final String? comicSource;

  final bool useDeviceSettings;

  @override
  State<_DoubleLineSelectSettings> createState() =>
      _DoubleLineSelectSettingsState();
}

class _DoubleLineSelectSettingsState extends State<_DoubleLineSelectSettings> {
  @override
  Widget build(BuildContext context) {
    var value = widget.comicId != null
        ? appdata.settings.getReaderSetting(
            widget.comicId!,
            widget.comicSource!,
            widget.settingKey,
          )
        : widget.useDeviceSettings
        ? appdata.settings.getDeviceReaderSetting(widget.settingKey)
        : appdata.settings[widget.settingKey];

    return ListTile(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Row(
          children: [
            Text(widget.title, style: ts.s16),
            const SizedBox(width: 4),
            if (widget.help != null)
              Button.icon(
              size: 18,
              icon: const Icon(LucideIcons.circle_question_mark),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return ContentDialog(
                      title: "Help".tl,
                      content: Text(
                        widget.help!,
                      ).paddingHorizontal(16).fixWidth(double.infinity),
                      actions: [
                        Button.filled(
                          onPressed: context.pop,
                          child: Text("OK".tl),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      subtitle: Text(widget.optionTranslation[value] ?? "None".tl),
      trailing: const Icon(LucideIcons.arrow_down),
      onTap: () {
        var renderBox = context.findRenderObject() as RenderBox;
        var offset = renderBox.localToGlobal(Offset.zero);
        var size = renderBox.size;
        var rect = offset & size;
        showMenu(
          elevation: 3,
          color: context.brightness == Brightness.light
              ? const Color(0xFFF6F6F6)
              : const Color(0xFF1E1E1E),
          context: context,
          position: RelativeRect.fromRect(
            rect,
            Offset.zero & MediaQuery.of(context).size,
          ),
          items: widget.optionTranslation.keys
              .map(
                (key) => PopupMenuItem(
                  value: key,
                  height: App.isMobile ? 46 : 40,
                  child: Text(widget.optionTranslation[key]!),
                ),
              )
              .toList(),
        ).then((value) {
          if (value != null) {
            setState(() {
              if (widget.comicId != null) {
                appdata.settings.setReaderSetting(
                  widget.comicId!,
                  widget.comicSource!,
                  widget.settingKey,
                  value,
                );
              } else if (widget.useDeviceSettings) {
                appdata.settings.setDeviceReaderSetting(
                  widget.settingKey,
                  value,
                );
              } else {
                appdata.settings[widget.settingKey] = value;
              }
            });
            appdata.saveData();
            widget.onChanged?.call();
          }
        });
      },
    );
  }
}

class _EndSelectorSelectSetting extends StatefulWidget {
  const _EndSelectorSelectSetting({
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
    this.comicId,
    this.comicSource,
    this.useDeviceSettings = false,
  });

  final String title;

  final String settingKey;

  final Map<String, String> optionTranslation;

  final VoidCallback? onChanged;

  final String? help;

  final String? comicId;

  final String? comicSource;

  final bool useDeviceSettings;

  @override
  State<_EndSelectorSelectSetting> createState() =>
      _EndSelectorSelectSettingState();
}

class _EndSelectorSelectSettingState extends State<_EndSelectorSelectSetting> {
  @override
  Widget build(BuildContext context) {
    var options = widget.optionTranslation;
    var value = widget.comicId != null
        ? appdata.settings.getReaderSetting(
            widget.comicId!,
            widget.comicSource!,
            widget.settingKey,
          )
        : widget.useDeviceSettings
        ? appdata.settings.getDeviceReaderSetting(widget.settingKey)
        : appdata.settings[widget.settingKey];
    return ListTile(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Row(
          children: [
            Text(widget.title, style: ts.s16),
            const SizedBox(width: 4),
            if (widget.help != null)
              Button.icon(
              size: 18,
              icon: const Icon(LucideIcons.circle_question_mark),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return ContentDialog(
                      title: "Help".tl,
                      content: Text(
                        widget.help!,
                      ).paddingHorizontal(16).fixWidth(double.infinity),
                      actions: [
                        Button.filled(
                          onPressed: context.pop,
                          child: Text("OK".tl),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      trailing: Select(
        current: options[value],
        values: options.values.toList(),
        minWidth: 64,
        onTap: (index) {
          setState(() {
            var value = options.keys.elementAt(index);
            if (widget.comicId != null) {
              appdata.settings.setReaderSetting(
                widget.comicId!,
                widget.comicSource!,
                widget.settingKey,
                value,
              );
            } else if (widget.useDeviceSettings) {
              appdata.settings.setDeviceReaderSetting(widget.settingKey, value);
            } else {
              appdata.settings[widget.settingKey] = value;
            }
          });
          appdata.saveData();
          widget.onChanged?.call();
        },
      ),
    );
  }
}

class _SliderSetting extends StatefulWidget {
  const _SliderSetting({
    required this.title,
    required this.settingsIndex,
    required this.interval,
    required this.min,
    required this.max,
    this.onChanged,
    this.comicId,
    this.comicSource,
    this.useDeviceSettings = false,
  });

  final String title;

  final String settingsIndex;

  final double interval;

  final double min;

  final double max;

  final VoidCallback? onChanged;

  final String? comicId;

  final String? comicSource;

  final bool useDeviceSettings;

  @override
  State<_SliderSetting> createState() => _SliderSettingState();
}

class _SliderSettingState extends State<_SliderSetting> {
  @override
  Widget build(BuildContext context) {
    var value =
        (widget.comicId != null
                ? appdata.settings.getReaderSetting(
                    widget.comicId!,
                    widget.comicSource!,
                    widget.settingsIndex,
                  )
                : widget.useDeviceSettings
                ? appdata.settings.getDeviceReaderSetting(widget.settingsIndex)
                : appdata.settings[widget.settingsIndex])
            .toDouble();

    void handleChanged(double newValue) {
      final dynamic stored =
          newValue.toInt() == newValue ? newValue.toInt() : newValue;
      setState(() {
        if (widget.comicId != null) {
          appdata.settings.setReaderSetting(
            widget.comicId!,
            widget.comicSource!,
            widget.settingsIndex,
            stored,
          );
        } else if (widget.useDeviceSettings) {
          appdata.settings.setDeviceReaderSetting(
            widget.settingsIndex,
            stored,
          );
        } else {
          appdata.settings[widget.settingsIndex] = stored;
        }
        appdata.saveData();
      });
      widget.onChanged?.call();
    }

    if (isCupertinoStyle()) {
      final divisions = ((widget.max - widget.min) / widget.interval).toInt();
      final displayValue = value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: CupertinoTheme.of(context).textTheme.textStyle,
                  ),
                ),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            CupertinoSlider(
              value: value,
              min: widget.min,
              max: widget.max,
              divisions: divisions,
              onChanged: handleChanged,
            ),
          ],
        ),
      );
    }

    return _divided(
      context,
      ListTile(
        title: Text(widget.title, softWrap: true, maxLines: 2),
        trailing: Text(value.toString(), style: ts.s12),
        subtitle: Slider(
          value: value,
          onChanged: handleChanged,
          divisions: ((widget.max - widget.min) / widget.interval).toInt(),
          min: widget.min,
          max: widget.max,
        ),
      ),
    );
  }
}

class _PopupWindowSetting extends StatelessWidget {
  const _PopupWindowSetting({required this.title, required this.builder});

  final Widget Function() builder;

  final String title;

  @override
  Widget build(BuildContext context) {
    if (isCupertinoStyle()) {
      return CupertinoListTile(
        title: Text(title),
        trailing: const CupertinoListTileChevron(),
        onTap: () {
          showPopUpWidget(App.rootContext, builder());
        },
      );
    }

    return _divided(
      context,
      ListTile(
        title: Text(title),
        trailing: const Icon(LucideIcons.arrow_right),
        onTap: () {
          showPopUpWidget(App.rootContext, builder());
        },
      ),
    );
  }
}

class _MultiPagesFilter extends StatefulWidget {
  const _MultiPagesFilter({
    required this.title,
    required this.settingsIndex,
    required this.pages,
  });

  final String title;

  final String settingsIndex;

  // key - name
  final Map<String, String> pages;

  @override
  State<_MultiPagesFilter> createState() => _MultiPagesFilterState();
}

class _MultiPagesFilterState extends State<_MultiPagesFilter> {
  late List<String> keys;

  @override
  void initState() {
    keys = List.from(appdata.settings[widget.settingsIndex]);
    keys.remove("");
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    Future.microtask(() {
      updateSetting();
    });
  }

  var scrollController = ScrollController();
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    var tiles = keys.map((e) => buildItem(e)).toList();

    // Derive the ReorderableBuilder key from the SET of keys (order-independent).
    // When an item is added/removed, the set changes -> the builder remounts and
    // re-initializes its internal entities with fresh 0..n-1 order ids, keeping
    // them in sync with `keys`. A pure reorder only changes order, not the set,
    // so the key stays stable and the drag animation is preserved.
    final sortedKeys = [...keys]..sort();
    final reorderWidgetKey = ValueKey(
      '${keys.length}:${sortedKeys.join('\u0000')}',
    );

    var view = ReorderableBuilder<String>(
      key: reorderWidgetKey,
      scrollController: scrollController,
      longPressDelay: App.isDesktop
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 500),
      dragChildBoxDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
            spreadRadius: 2,
          ),
        ],
      ),
      onReorder: (reorderFunc) {
        try {
          final reordered = reorderFunc(keys);
          setState(() {
            keys = List.from(reordered);
          });
        } catch (e) {
          // Safety net: if the package ever computes out-of-range indices
          // (e.g. its internal entity list got out of sync with `keys`),
          // keep the current order instead of crashing the app.
          Log.error('reorder failed', e.toString());
        }
      },
      children: tiles,
      builder: (children) {
        return GridView(
          key: _key,
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisExtent: 48,
          ),
          children: children,
        );
      },
    );

    return PopUpWidgetScaffold(
      title: widget.title,
      tailing: [
        if (keys.length < widget.pages.length)
          TextButton.icon(
            label: Text("Add".tl),
            icon: const Icon(LucideIcons.plus),
            onPressed: showAddDialog,
          ),
      ],
      body: view,
    );
  }

  Widget buildItem(String key) {
    Widget removeButton = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        onPressed: () {
          setState(() {
            keys.remove(key);
          });
        },
        icon: const Icon(LucideIcons.trash),
      ),
    );

    // Wrap in a transparent Material so the ListTile always has its own
    // Material ancestor to paint its background / ink splashes on. Without
    // this, the ReorderableBuilder's `dragChildBoxDecoration` (which has a
    // background color) wraps the bare ListTile in a DecoratedBox during drag
    // and hides those effects (Flutter framework warning).
    return Material(
      key: Key(key),
      type: MaterialType.transparency,
      child: ListTile(
        title: Text(widget.pages[key] ?? "${"(Invalid)".tl} $key"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [removeButton, const Icon(LucideIcons.grip_vertical)],
        ),
      ),
    );
  }

  void showAddDialog() {
    var canAdd = <String, String>{};
    widget.pages.forEach((key, value) {
      if (!keys.contains(key)) {
        canAdd[key] = value;
      }
    });
    var selected = <String>[];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: "Add".tl,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: canAdd.entries
                    .map(
                      (e) => CheckboxListTile(
                        value: selected.contains(e.key),
                        title: Text(e.value),
                        key: Key(e.key),
                        onChanged: (value) {
                          setState(() {
                            if (value!) {
                              selected.add(e.key);
                            } else {
                              selected.remove(e.key);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              actions: [
                if (selected.length < canAdd.length)
                  TextButton(
                    child: Text("Select All".tl),
                    onPressed: () {
                      setState(() {
                        selected = canAdd.keys.toList();
                      });
                    },
                  )
                else
                  TextButton(
                    child: Text("Deselect All".tl),
                    onPressed: () {
                      setState(() {
                        selected.clear();
                      });
                    },
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: selected.isNotEmpty
                      ? () {
                          this.setState(() {
                            keys.addAll(selected);
                          });
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text("Add".tl),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void updateSetting() {
    appdata.settings[widget.settingsIndex] = keys;
    appdata.saveData();
  }
}

class _CallbackSetting extends StatelessWidget {
  const _CallbackSetting({
    required this.title,
    required this.callback,
    required this.actionTitle,
    this.subtitle,
    this.subtitleStyle,
  });

  final String title;

  final String? subtitle;

  final TextStyle? subtitleStyle;

  final VoidCallback callback;

  final String actionTitle;

  @override
  Widget build(BuildContext context) {
    if (isCupertinoStyle()) {
      return CupertinoListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: callback,
          child: Text(actionTitle),
        ),
        onTap: callback,
      );
    }

    return _divided(
      context,
      ListTile(
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!, style: subtitleStyle),
        trailing: Button.normal(
          onPressed: callback,
          child: Text(actionTitle),
        ).fixHeight(28),
        onTap: callback,
      ),
    );
  }
}

class _SettingPartTitle extends StatelessWidget {
  const _SettingPartTitle({required this.title, required this.icon});

  final String title;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (isCupertinoStyle()) {
      // Cupertino section headers use a simple label style,
      // similar to the iOS Settings app.
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, top: 24, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  letterSpacing: -0.08,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(title, style: ts.s18),
          ],
        ),
      ),
    );
  }
}
