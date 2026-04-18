import 'package:flutter/foundation.dart';

/// Notifies when a tab is selected or data has changed (e.g. new violation).
/// Screens listen and auto-refresh when they become visible or data updates.
class RefreshNotifier extends ChangeNotifier {
  int _selectedTabIndex = 0;
  int _dataChangeCount = 0;

  int get selectedTabIndex => _selectedTabIndex;
  int get dataChangeCount => _dataChangeCount;

  void selectTab(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  /// Call when new violation is added or data changes (e.g. from Camera screen).
  void notifyDataChanged() {
    _dataChangeCount++;
    notifyListeners();
  }

  /// Returns true if this tab should refresh (tab just became visible or data changed).
  bool shouldRefresh(int myTabIndex, int lastSeenTab, int lastSeenDataCount) {
    final tabBecameVisible = _selectedTabIndex == myTabIndex && _selectedTabIndex != lastSeenTab;
    final dataChanged = _dataChangeCount != lastSeenDataCount;
    return tabBecameVisible || dataChanged;
  }
}
