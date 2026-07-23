import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/utils/init.dart';
import 'package:venera/utils/io.dart';

class Appdata with Init {
  Appdata._create();

  final Settings settings = Settings._create();

  /// Search history entries with source tracking.
  /// Each entry stores both the search text and the comic source used.
  List<Map<String, String>> _searchHistoryWithSource = [];

  /// Legacy search history for backward compatibility.
  List<String> get searchHistory => _searchHistoryWithSource
      .map((e) => e['text'] ?? '')
      .where((e) => e.isNotEmpty)
      .toList();

  set searchHistory(List<String> value) {
    // Convert legacy format to new format with 'unknown' source
    _searchHistoryWithSource = value
        .map((text) => {'text': text, 'source': 'unknown'})
        .toList();
  }

  /// Add a search keyword with its source.
  void addSearchHistory(String keyword, {String source = 'unknown'}) {
    if (keyword.trim().isEmpty) return;
    // Remove duplicate
    _searchHistoryWithSource.removeWhere((e) => e['text'] == keyword);
    // Insert at beginning
    _searchHistoryWithSource.insert(0, {'text': keyword, 'source': source});
    // Limit to 50 entries
    if (_searchHistoryWithSource.length > 50) {
      _searchHistoryWithSource.removeLast();
    }
    saveData();
  }

  /// Get search history with source information.
  List<Map<String, String>> get searchHistoryWithSource => _searchHistoryWithSource;

  bool _isSavingData = false;

  Future<void> saveData([bool sync = true]) async {
    while (_isSavingData) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    _isSavingData = true;
    try {
      var futures = <Future>[];
      var json = toJson();
      var data = jsonEncode(json);
      var file = File(FilePath.join(App.dataPath, 'appdata.json'));
      futures.add(file.writeAsString(data));

      var disableSyncFields = json["settings"]["disableSyncFields"] as String;
      if (disableSyncFields.isNotEmpty) {
        var json4sync = jsonDecode(data);
        List<String> customDisableSync = splitField(disableSyncFields);
        for (var field in customDisableSync) {
          json4sync["settings"].remove(field);
        }
        var data4sync = jsonEncode(json4sync);
        var file4sync = File(FilePath.join(App.dataPath, 'syncdata.json'));
        futures.add(file4sync.writeAsString(data4sync));
      }

      await Future.wait(futures);
    } finally {
      _isSavingData = false;
    }
    if (sync) {
      DataSync().uploadData();
    }
  }

  void removeSearchHistory(String keyword) {
    _searchHistoryWithSource.removeWhere((e) => e['text'] == keyword);
    saveData();
  }

  void clearSearchHistory() {
    _searchHistoryWithSource.clear();
    saveData();
  }

  Map<String, dynamic> toJson() {
    return {'settings': settings._data, 'searchHistory': _searchHistoryWithSource};
  }

  List<String> splitField(String merged) {
    return merged
        .split(',')
        .map((field) => field.trim())
        .where((field) => field.isNotEmpty)
        .toList();
  }

  /// Following fields are related to device-specific data and should not be synced.
  static const _disableSync = [
    "proxy",
    "authorizationRequired",
    "customImageProcessing",
    "webdav",
    "disableSyncFields",
    "deviceId",
  ];

  /// Sync data from another device
  void syncData(Map<String, dynamic> data) {
    if (data['settings'] is Map) {
      var settings = data['settings'] as Map<String, dynamic>;

      List<String> customDisableSync = splitField(
        this.settings["disableSyncFields"] as String,
      );

      for (var key in settings.keys) {
        if (!_disableSync.contains(key) && !customDisableSync.contains(key)) {
          this.settings[key] = settings[key];
        }
      }
    }
    // Handle search history with backward compatibility
    final rawHistory = data['searchHistory'];
    if (rawHistory is List) {
      _searchHistoryWithSource = [];
      for (final item in rawHistory) {
        if (item is String) {
          // Legacy format: just a string
          _searchHistoryWithSource.add({'text': item, 'source': 'unknown'});
        } else if (item is Map) {
          // New format: map with text and source
          _searchHistoryWithSource.add({
            'text': item['text']?.toString() ?? '',
            'source': item['source']?.toString() ?? 'unknown',
          });
        }
      }
    }
    saveData();
  }

  var implicitData = <String, dynamic>{};

  void writeImplicitData() async {
    while (_isSavingData) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
    _isSavingData = true;
    try {
      var file = File(FilePath.join(App.dataPath, 'implicitData.json'));
      await file.writeAsString(jsonEncode(implicitData));
    } finally {
      _isSavingData = false;
    }
  }

  @override
  Future<void> doInit() async {
    var dataPath = (await getApplicationSupportDirectory()).path;
    var file = File(FilePath.join(dataPath, 'appdata.json'));
    if (!await file.exists()) {
      return;
    }
    try {
      var json = jsonDecode(await file.readAsString());
      for (var key in (json['settings'] as Map<String, dynamic>).keys) {
        if (json['settings'][key] != null) {
          settings[key] = json['settings'][key];
        }
      }
      // Handle search history with backward compatibility
      final rawHistory = json['searchHistory'];
      if (rawHistory is List) {
        _searchHistoryWithSource = [];
        for (final item in rawHistory) {
          if (item is String) {
            // Legacy format: just a string
            _searchHistoryWithSource.add({'text': item, 'source': 'unknown'});
          } else if (item is Map) {
            // New format: map with text and source
            _searchHistoryWithSource.add({
              'text': item['text']?.toString() ?? '',
              'source': item['source']?.toString() ?? 'unknown',
            });
          }
        }
      }
    } catch (e) {
      Log.error("Appdata", "Failed to load appdata", e);
      Log.info("Appdata", "Resetting appdata");
      file.deleteIgnoreError();
    }
    if ((settings["deviceId"] as String).isEmpty) {
      settings._data["deviceId"] = const Uuid().v4();
      await saveData(false);
    }
    try {
      var implicitDataFile = File(FilePath.join(dataPath, 'implicitData.json'));
      if (await implicitDataFile.exists()) {
        implicitData = jsonDecode(await implicitDataFile.readAsString());
      }
    } catch (e) {
      Log.error("Appdata", "Failed to load implicit data", e);
      Log.info("Appdata", "Resetting implicit data");
      var implicitDataFile = File(FilePath.join(dataPath, 'implicitData.json'));
      implicitDataFile.deleteIgnoreError();
    }
  }
}

final appdata = Appdata._create();

class Settings with ChangeNotifier {
  Settings._create();

  final _data = <String, dynamic>{
    'comicDisplayMode': 'detailed', // detailed, brief
    'comicTileScale': 1.00, // 0.75-1.25
    'color': 'system', // red, pink, purple, green, orange, blue
    'theme_mode': 'system', // light, dark, system
    'amoledDark': false, // AMOLED pure black in dark mode
    'uiDensity': 'standard', // compact, standard, comfortable
    'uiStyle': 'system', // system, cupertino, material
    'newFavoriteAddTo': 'end', // start, end
    'moveFavoriteAfterRead': 'none', // none, end, start
    'proxy': 'system', // direct, system, proxy string
    'explore_pages': [],
    'categories': [],
    'favorites': [],
    'searchSources': null,
    'showFavoriteStatusOnTile': true,
    'showHistoryStatusOnTile': false,
    'blockedWords': [],
    'blockedCommentWords': [],
    'defaultSearchTarget': null,
    'autoPageTurningInterval': 5, // in seconds
    'readerMode': 'galleryLeftToRight', // values of [ReaderMode]
    'readerScreenPicNumberForLandscape': 1, // 1 - 5
    'readerScreenPicNumberForPortrait': 1, // 1 - 5
    'enableTapToTurnPages': true,
    'reverseTapToTurnPages': false,
    'enablePageAnimation': true,
    'language': 'system', // system, zh-CN, zh-TW, en-US
    'cacheSize': 2048, // in MB
    'downloadThreads': 5,
    'enableLongPressToZoom': true,
    'longPressZoomPosition': "press", // press, center
    'checkUpdateOnStart': false,
    'limitImageWidth': true,
    'webdav': [], // empty means not configured
    "disableSyncFields": "", // "field1, field2, ..."
    'dataVersion': 0,
    'quickFavorite': null,
    'enableTurnPageByVolumeKey': true,
    'enableClockAndBatteryInfoInReader': true,
    'quickCollectImage': 'No', // No, DoubleTap, Swipe
    'authorizationRequired': false,
    'onClickFavorite': 'viewDetail', // viewDetail, read
    'enableDnsOverrides': false,
    'dnsOverrides': {},
    'enableCustomImageProcessing': false,
    'customImageProcessing': defaultCustomImageProcessing,
    'sni': true,
    'autoAddLanguageFilter': 'none', // none, chinese, english, japanese
    'comicSourceListUrl': _defaultSourceListUrl,
    'preloadImageCount': 4,
    'followUpdatesFolder': null,
    'initialPage': '0',
    'customTabs': [
      {'id': 'home', 'visible': true, 'order': 0},
      {'id': 'favorites', 'visible': true, 'order': 1},
      {'id': 'explore', 'visible': true, 'order': 2},
      {'id': 'categories', 'visible': true, 'order': 3},
    ],
    'comicListDisplayMode': 'paging', // paging, continuous
    'showPageNumberInReader': true,
    'showSingleImageOnFirstPage': false,
    'enableDoubleTapToZoom': true,
    'reverseChapterOrder': false,
    'showSystemStatusBar': false,
    'comicSpecificSettings': <String, Map<String, dynamic>>{},
    'deviceSpecificSettings': <String, Map<String, dynamic>>{},
    'deviceId': '',
    'ignoreBadCertificate': false,
    'lab_hideThumbnails': false,
    'lab_developerMode': false,
    'enableRemoteLibrary': false, // lab: add "Remote Library" tab
    'remoteLibraryViewMode': 'grid', // grid, list
    'readerScrollSpeed': 1.0, // 0.5 - 3.0
    'localFavoritesFirst': true,
    'autoCloseFavoritePanel': false,
    'showChapterComments': true, // show chapter comments in reader
    'showChapterCommentsAtEnd':
        false, // show chapter comments at end of chapter
  };

  operator [](String key) {
    return _data[key];
  }

  operator []=(String key, dynamic value) {
    _data[key] = value;
    if (key != "dataVersion") {
      notifyListeners();
    }
  }

  void setEnabledComicSpecificSettings(
    String comicId,
    String sourceKey,
    bool enabled,
  ) {
    setReaderSetting(comicId, sourceKey, "enabled", enabled);
  }

  bool isComicSpecificSettingsEnabled(String? comicId, String? sourceKey) {
    if (comicId == null || sourceKey == null) {
      return false;
    }
    return _data['comicSpecificSettings']["$comicId@$sourceKey"]?["enabled"] ==
        true;
  }

  dynamic getReaderSetting(String comicId, String sourceKey, String key) {
    if (isComicSpecificSettingsEnabled(comicId, sourceKey)) {
      var comicValue =
          _data['comicSpecificSettings']["$comicId@$sourceKey"]?[key];
      if (comicValue != null) {
        return comicValue;
      }
    }
    return getDeviceReaderSetting(key);
  }

  void setReaderSetting(
    String comicId,
    String sourceKey,
    String key,
    dynamic value,
  ) {
    (_data['comicSpecificSettings'] as Map<String, dynamic>).putIfAbsent(
      "$comicId@$sourceKey",
      () => <String, dynamic>{},
    )[key] = value;
    notifyListeners();
  }

  void resetComicReaderSettings(String key) {
    (_data['comicSpecificSettings'] as Map).remove(key);
    notifyListeners();
  }

  void setEnabledDeviceSpecificSettings(bool enabled) {
    setDeviceReaderSetting("enabled", enabled);
  }

  bool isDeviceSpecificSettingsEnabled() {
    var deviceId = _data['deviceId'] as String;
    if (deviceId.isEmpty) {
      return false;
    }
    return _data['deviceSpecificSettings'][deviceId]?["enabled"] == true;
  }

  dynamic getDeviceReaderSetting(String key) {
    if (!isDeviceSpecificSettingsEnabled()) {
      return _data[key];
    }
    var deviceId = _data['deviceId'] as String;
    return _data['deviceSpecificSettings'][deviceId]?[key] ?? _data[key];
  }

  void setDeviceReaderSetting(String key, dynamic value) {
    var deviceId = _getOrCreateDeviceId();
    (_data['deviceSpecificSettings'] as Map<String, dynamic>).putIfAbsent(
      deviceId,
      () => <String, dynamic>{},
    )[key] = value;
    notifyListeners();
  }

  void resetDeviceReaderSettings() {
    var deviceId = _data['deviceId'] as String;
    if (deviceId.isEmpty) {
      return;
    }
    (_data['deviceSpecificSettings'] as Map).remove(deviceId);
    notifyListeners();
  }

  String _getOrCreateDeviceId() {
    var deviceId = _data['deviceId'] as String;
    if (deviceId.isNotEmpty) {
      return deviceId;
    }
    var id = const Uuid().v4();
    _data['deviceId'] = id;
    return id;
  }

  @override
  String toString() {
    return _data.toString();
  }
}

const defaultCustomImageProcessing = '''
/**
 * Process an image
 * @param image {ArrayBuffer} - The image to process
 * @param cid {string} - The comic ID
 * @param eid {string} - The episode ID
 * @param page {number} - The page number
 * @param sourceKey {string} - The source key
 * @returns {Promise<ArrayBuffer> | {image: Promise<ArrayBuffer>, onCancel: () => void}} - The processed image
 */
async function processImage(image, cid, eid, page, sourceKey) {
    let futureImage = new Promise((resolve, reject) => {
        resolve(image);
    });
    return futureImage;
}
''';

const _defaultSourceListUrl =
    "https://raw.githubusercontent.com/fuyu1993/venera-configs-mine/main/index.json";
