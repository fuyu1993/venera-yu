import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/utils/translations.dart';

/// A unified toolbar for comic list pages: Sort + Filter + View Mode.
///
/// Provides a consistent row of toolbar actions that can be embedded in
/// any comic listing page (favorites, local comics, etc.).
class ComicsToolbar extends StatelessWidget {
  const ComicsToolbar({
    super.key,
    this.onSortTap,
    this.sortTooltip,
    this.sortActive = false,
    this.onFilterTap,
    this.filterTooltip,
    this.filterActive = false,
    this.onSearchTap,
    this.searchActive = false,
  });

  /// Called when the sort button is tapped.
  final VoidCallback? onSortTap;

  /// Tooltip for the sort button.
  final String? sortTooltip;

  /// Whether the sort is non-default (shows highlight).
  final bool sortActive;

  /// Called when the filter button is tapped.
  final VoidCallback? onFilterTap;

  /// Tooltip for the filter button.
  final String? filterTooltip;

  /// Whether a filter is active (shows highlight).
  final bool filterActive;

  /// Called when the search button is tapped.
  final VoidCallback? onSearchTap;

  /// Whether search mode is active.
  final bool searchActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Sort
          if (onSortTap != null)
            _ToolbarButton(
              icon: LucideIcons.arrow_down_up,
              tooltip: sortTooltip ?? 'Sort'.tl,
              isActive: sortActive,
              onTap: onSortTap!,
            ),
          // Filter
          if (onFilterTap != null)
            _ToolbarButton(
              icon: LucideIcons.funnel,
              tooltip: filterTooltip ?? 'Filter'.tl,
              isActive: filterActive,
              onTap: onFilterTap!,
            ),
          const Spacer(),
          // View mode toggle
          _ViewModeToggle(),
          // Search
          if (onSearchTap != null)
            _ToolbarButton(
              icon: LucideIcons.search,
              tooltip: 'Search'.tl,
              isActive: searchActive,
              onTap: onSearchTap!,
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        color: isActive ? cs.primary : null,
        onPressed: onTap,
      ),
    );
  }
}

/// Toggle between 'brief' and 'detailed' comic display modes.
class _ViewModeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDetailed = appdata.settings['comicDisplayMode'] == 'detailed';

    return Tooltip(
      message: 'View Mode'.tl,
      child: IconButton(
        icon: Icon(
          isDetailed ? LucideIcons.layout_list : LucideIcons.layout_grid,
        ),
        color: cs.onSurfaceVariant,
        onPressed: () {
          final newMode = isDetailed ? 'brief' : 'detailed';
          appdata.settings['comicDisplayMode'] = newMode;
          appdata.saveData();
          App.setViewMode(newMode);
        },
      ),
    );
  }
}
