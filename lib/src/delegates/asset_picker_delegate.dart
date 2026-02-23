// Copyright 2019 The FlutterCandies author. All rights reserved.
// Use of this source code is governed by an Apache license that can be found
// in the LICENSE file.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' hide Path;
import 'package:flutter/services.dart' show MethodCall;
import 'package:gallery_media_picker/gallery_media_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_picker_library/wechat_picker_library.dart'
    show buildTheme;

import '../constants/config.dart';
import '../constants/constants.dart'
    show androidPlatformPickerAssetIdPrefix, packageName;
import '../provider/asset_picker_provider.dart';
import '../widget/asset_picker.dart';
import '../widget/asset_picker_page_route.dart';
import 'asset_picker_builder_delegate.dart';

class AssetPickerDelegate {
  const AssetPickerDelegate();

  /// {@template wechat_assets_picker.delegates.AssetPickerDelegate.permissionCheck}
  /// Request the current [PermissionState] of required permissions.
  /// 请求所需权限的 [PermissionState]。
  ///
  /// Throws a [StateError] when the state is not [PermissionState.authorized]
  /// or [PermissionState.limited],
  /// which means the picker can not perform further actions.
  /// 当权限状态不是 [PermissionState.authorized] 或 [PermissionState.limited] 时，
  /// 将抛出 [StateError]，此时选择器无法执行其他操作。
  ///
  /// See also:
  ///  * [PermissionState] which defined all states of required permissions.
  /// {@endtemplate}
  Future<PermissionState> permissionCheck({
    PermissionRequestOption requestOption = const PermissionRequestOption(),
  }) async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend(
      requestOption: requestOption,
    );
    if (ps != PermissionState.authorized && ps != PermissionState.limited) {
      throw StateError('Permission state error with $ps.');
    }
    return ps;
  }

  /// {@template wechat_assets_picker.delegates.AssetPickerDelegate.pickAssets}
  /// Pick assets with the given [pickerConfig].
  /// 根据给定的 [pickerConfig] 选择资源。
  ///
  /// Set [useRootNavigator] to determine
  /// whether the picker route should use the root [Navigator].
  /// 使用 [useRootNavigator] 来控制选择器的路由是否使用最顶层的 [Navigator]。
  ///
  /// By extending the [AssetPickerPageRoute], users can customize the route
  /// and use it with the [pageRouteBuilder].
  /// 继承 [AssetPickerPageRoute] 可以自定义路由，
  /// 并且通过 [pageRouteBuilder] 进行使用。
  ///
  /// See also:
  ///  * [AssetPickerConfig] which holds all configurations for basic picking.
  ///  * [DefaultAssetPickerProvider] which is the default provider that
  ///    manages assets during the picking process.
  ///  * [DefaultAssetPickerBuilderDelegate] which is the default builder that
  ///    builds all widgets during the picking process.
  /// {@endtemplate}
  Future<List<AssetEntity>?> pickAssets(
    BuildContext context, {
    Key? key,
    AssetPickerConfig pickerConfig = const AssetPickerConfig(),
    PermissionRequestOption? permissionRequestOption,
    bool useRootNavigator = true,
    RouteSettings? pageRouteSettings,
    AssetPickerPageRouteBuilder<List<AssetEntity>>? pageRouteBuilder,
  }) async {
    if (_shouldUseAndroidPlatformPhotoPicker(pickerConfig)) {
      return _pickAssetsWithAndroidPlatformPhotoPicker(
        pickerConfig,
        context: context,
        useRootNavigator: useRootNavigator,
        pageRouteSettings: pageRouteSettings,
      );
    }

    permissionRequestOption ??= PermissionRequestOption(
      androidPermission: AndroidPermission(
        type: pickerConfig.requestType,
        mediaLocation: false,
      ),
    );
    final PermissionState ps = await permissionCheck(
      requestOption: permissionRequestOption,
    );
    final AssetPickerPageRoute<List<AssetEntity>> route =
        pageRouteBuilder?.call(const SizedBox.shrink()) ??
            AssetPickerPageRoute<List<AssetEntity>>(
              builder: (_) => const SizedBox.shrink(),
              settings: pageRouteSettings,
            );
    final DefaultAssetPickerProvider provider = DefaultAssetPickerProvider(
      maxAssets: pickerConfig.maxAssets,
      pageSize: pickerConfig.pageSize,
      pathThumbnailSize: pickerConfig.pathThumbnailSize,
      selectedAssets: pickerConfig.selectedAssets,
      requestType: pickerConfig.requestType,
      sortPathDelegate: pickerConfig.sortPathDelegate,
      filterOptions: pickerConfig.filterOptions,
      initializeDelayDuration: route.transitionDuration,
    );
    final picker = AssetPicker<AssetEntity, AssetPathEntity,
        DefaultAssetPickerBuilderDelegate>(
      key: key,
      permissionRequestOption: permissionRequestOption,
      builder: DefaultAssetPickerBuilderDelegate(
        provider: provider,
        initialPermission: ps,
        gridCount: pickerConfig.gridCount,
        pickerTheme: pickerConfig.pickerTheme,
        gridThumbnailSize: pickerConfig.gridThumbnailSize,
        previewThumbnailSize: pickerConfig.previewThumbnailSize,
        specialPickerType: pickerConfig.specialPickerType,
        specialItems: pickerConfig.specialItems,
        loadingIndicatorBuilder: pickerConfig.loadingIndicatorBuilder,
        selectPredicate: pickerConfig.selectPredicate,
        shouldRevertGrid: pickerConfig.shouldRevertGrid,
        limitedPermissionOverlayPredicate:
            pickerConfig.limitedPermissionOverlayPredicate,
        pathNameBuilder: pickerConfig.pathNameBuilder,
        assetsChangeCallback: pickerConfig.assetsChangeCallback,
        assetsChangeRefreshPredicate: pickerConfig.assetsChangeRefreshPredicate,
        textDelegate: pickerConfig.textDelegate,
        themeColor: pickerConfig.themeColor,
        locale: Localizations.maybeLocaleOf(context),
        shouldAutoplayPreview: pickerConfig.shouldAutoplayPreview,
        dragToSelect: pickerConfig.dragToSelect,
        enableLivePhoto: pickerConfig.enableLivePhoto,
      ),
    );
    final List<AssetEntity>? result = await Navigator.maybeOf(
      context,
      rootNavigator: useRootNavigator,
    )?.push<List<AssetEntity>>(
      pageRouteBuilder?.call(picker) ??
          AssetPickerPageRoute<List<AssetEntity>>(
            builder: (_) => picker,
            settings: pageRouteSettings,
          ),
    );
    return result;
  }

  /// Pick assets without a [BuildContext].
  ///
  /// This is only supported when Android platform picker mode is enabled.
  Future<List<AssetEntity>?> pickAssetsWithoutContext({
    AssetPickerConfig pickerConfig = const AssetPickerConfig(),
  }) async {
    if (_shouldUseAndroidPlatformPhotoPicker(pickerConfig)) {
      return _pickAssetsWithAndroidPlatformPhotoPicker(pickerConfig);
    }
    throw StateError(
      'pickAssetsWithoutContext requires Android platform picker mode.',
    );
  }

  bool _shouldUseAndroidPlatformPhotoPicker(AssetPickerConfig pickerConfig) {
    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        pickerConfig.androidUsePlatformPhotoPicker;
  }

  Future<List<AssetEntity>?> _pickAssetsWithAndroidPlatformPhotoPicker(
    AssetPickerConfig pickerConfig, {
    BuildContext? context,
    bool useRootNavigator = true,
    RouteSettings? pageRouteSettings,
  }) async {
    final requestType = pickerConfig.requestType;
    final maxAssets = pickerConfig.maxAssets;

    if (context != null) {
      try {
        final galleryPicked = await _pickWithGalleryMediaPicker(
          context: context,
          requestType: requestType,
          maxAssets: maxAssets,
          useRootNavigator: useRootNavigator,
          pageRouteSettings: pageRouteSettings,
        );
        if (galleryPicked == null) {
          return null;
        }
        return _toAssetEntities(
          pickedFiles: galleryPicked,
          requestType: requestType,
          maxAssets: maxAssets,
        );
      } on Object {
        // Fallback to file_picker when gallery picker cannot be used
        // (e.g., missing media permission in policy-safe builds).
      }
    }

    final filePicked = await _pickWithFilePicker(
      requestType: requestType,
      maxAssets: maxAssets,
    );
    if (filePicked == null || filePicked.isEmpty) {
      return null;
    }
    return _toAssetEntities(
      pickedFiles: filePicked,
      requestType: requestType,
      maxAssets: maxAssets,
    );
  }

  Future<List<_PickedFileData>?> _pickWithFilePicker({
    required RequestType requestType,
    required int maxAssets,
  }) async {
    final pickerResult = await FilePicker.platform.pickFiles(
      allowMultiple: maxAssets != 1,
      lockParentWindow: true,
      type: _resolveFilePickerType(requestType),
    );

    if (pickerResult == null || pickerResult.files.isEmpty) {
      return null;
    }

    final pickedFiles = <_PickedFileData>[];
    for (final picked in pickerResult.files) {
      final filePath = picked.path;
      if (filePath == null || filePath.isEmpty) {
        continue;
      }
      final fileName =
          picked.name.isNotEmpty ? picked.name : _fileNameFromPath(filePath);
      final extension = _fileExtension(fileName);
      pickedFiles.add(
        _PickedFileData(
          path: filePath,
          name: fileName,
          mimeType: _resolveMimeType(extension),
        ),
      );
    }

    if (pickedFiles.isEmpty) {
      return null;
    }
    return pickedFiles;
  }

  Future<List<_PickedFileData>?> _pickWithGalleryMediaPicker({
    required BuildContext context,
    required RequestType requestType,
    required int maxAssets,
    required bool useRootNavigator,
    RouteSettings? pageRouteSettings,
  }) async {
    final permissionState = await PhotoManager.requestPermissionExtend();
    if (permissionState != PermissionState.authorized &&
        permissionState != PermissionState.limited) {
      throw StateError(
        'gallery_media_picker requires authorized media permission.',
      );
    }

    final navigator = Navigator.maybeOf(
      context,
      rootNavigator: useRootNavigator,
    );
    if (navigator == null) {
      throw StateError('Navigator unavailable for gallery_media_picker.');
    }

    final selected = await navigator.push<List<PickedAssetModel>>(
      MaterialPageRoute<List<PickedAssetModel>>(
        builder: (_) => _GalleryMediaPickerFallbackPage(
          requestType: requestType,
          maxAssets: maxAssets,
        ),
        settings: pageRouteSettings,
      ),
    );
    if (selected == null || selected.isEmpty) {
      return null;
    }

    final pickedFiles = <_PickedFileData>[];
    for (final picked in selected) {
      final filePath = picked.path;
      if (filePath.isEmpty) {
        continue;
      }
      final fileName = (picked.title?.isNotEmpty ?? false)
          ? picked.title!
          : _fileNameFromPath(filePath);
      final extension = _fileExtension(fileName);
      pickedFiles.add(
        _PickedFileData(
          path: filePath,
          name: fileName,
          mimeType: _resolveMimeType(extension),
          width: picked.width,
          height: picked.height,
          explicitType: picked.type == PickedAssetType.video
              ? AssetType.video
              : AssetType.image,
        ),
      );
    }

    if (pickedFiles.isEmpty) {
      return null;
    }
    return pickedFiles;
  }

  List<AssetEntity> _toAssetEntities({
    required List<_PickedFileData> pickedFiles,
    required RequestType requestType,
    required int maxAssets,
  }) {
    final selectedFiles =
        maxAssets > 0 ? pickedFiles.take(maxAssets) : pickedFiles;
    final entities = <AssetEntity>[];
    for (final file in selectedFiles) {
      final filePath = file.path;
      if (filePath.isEmpty) {
        continue;
      }
      final fileName =
          file.name.isNotEmpty ? file.name : _fileNameFromPath(filePath);
      final extension = _fileExtension(fileName);
      final mimeType = file.mimeType ?? _resolveMimeType(extension);
      entities.add(
        AssetEntity(
          id: '$androidPlatformPickerAssetIdPrefix${Uri.encodeComponent(filePath)}',
          typeInt: _resolveAssetType(
            requestType: requestType,
            extension: extension,
            mimeType: mimeType,
            explicitType: file.explicitType,
          ).index,
          width: file.width,
          height: file.height,
          title: fileName,
          mimeType: mimeType,
        ),
      );
    }
    return entities;
  }

  FileType _resolveFilePickerType(RequestType requestType) {
    if (requestType == RequestType.image) {
      return FileType.image;
    }
    if (requestType == RequestType.video) {
      return FileType.video;
    }
    return FileType.media;
  }

  String _fileNameFromPath(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final separatorIndex = normalized.lastIndexOf('/');
    if (separatorIndex < 0 || separatorIndex + 1 >= normalized.length) {
      return filePath;
    }
    return normalized.substring(separatorIndex + 1);
  }

  String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex + 1 >= fileName.length) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  AssetType _resolveAssetType({
    required RequestType requestType,
    required String extension,
    String? mimeType,
    AssetType? explicitType,
  }) {
    if (explicitType != null) {
      return explicitType;
    }
    if (requestType == RequestType.image) {
      return AssetType.image;
    }
    if (requestType == RequestType.video) {
      return AssetType.video;
    }
    if (mimeType != null && mimeType.startsWith('video/')) {
      return AssetType.video;
    }
    if (_videoExtensions.contains(extension)) {
      return AssetType.video;
    }
    return AssetType.image;
  }

  String? _resolveMimeType(String extension) {
    if (extension.isEmpty) {
      return null;
    }
    if (_imageExtensions.contains(extension)) {
      if (extension == 'jpg') {
        return 'image/jpeg';
      }
      return 'image/$extension';
    }
    if (_videoExtensions.contains(extension)) {
      if (extension == 'mov') {
        return 'video/quicktime';
      }
      return 'video/$extension';
    }
    return null;
  }

  static const Set<String> _imageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
  };

  static const Set<String> _videoExtensions = <String>{
    'mp4',
    'mov',
    'm4v',
    'avi',
    'mkv',
    '3gp',
    'webm',
  };

  /// {@template wechat_assets_picker.delegates.AssetPickerDelegate.pickAssetsWithDelegate}
  /// Pick assets with the given [delegate].
  /// 根据给定的 [delegate] 选择资源。
  ///
  /// Set [useRootNavigator] to determine
  /// whether the picker route should use the root [Navigator].
  /// 使用 [useRootNavigator] 来控制选择器的路由是否使用最顶层的 [Navigator]。
  ///
  /// By extending the [AssetPickerPageRoute], users can customize the route
  /// and use it with the [pageRouteBuilder].
  /// 继承 [AssetPickerPageRoute] 可以自定义路由，
  /// 并且通过 [pageRouteBuilder] 进行使用。
  ///
  /// See also:
  ///  * [AssetPickerBuilderDelegate] for how to customize/override widgets
  ///    during the picking process.
  /// {@endtemplate}
  Future<List<Asset>?> pickAssetsWithDelegate<
      Asset,
      Path,
      PickerProvider extends AssetPickerProvider<Asset, Path>,
      Delegate extends AssetPickerBuilderDelegate<Asset, Path>>(
    BuildContext context, {
    required Delegate delegate,
    PermissionRequestOption permissionRequestOption =
        const PermissionRequestOption(),
    Key? key,
    bool useRootNavigator = true,
    RouteSettings? pageRouteSettings,
    AssetPickerPageRouteBuilder<List<Asset>>? pageRouteBuilder,
  }) async {
    await permissionCheck(requestOption: permissionRequestOption);
    final picker = AssetPicker<Asset, Path, Delegate>(
      key: key,
      permissionRequestOption: permissionRequestOption,
      builder: delegate,
    );
    final result = await Navigator.maybeOf(
      context,
      rootNavigator: useRootNavigator,
    )?.push(
      pageRouteBuilder?.call(picker) ??
          AssetPickerPageRoute<List<Asset>>(
            builder: (_) => picker,
            settings: pageRouteSettings,
          ),
    );
    return result;
  }

  /// {@template wechat_assets_picker.delegates.AssetPickerDelegate.registerObserve}
  /// Register observe callback with assets changes.
  /// 注册资源（图库）变化的监听回调
  /// {@endtemplate}
  void registerObserve([ValueChanged<MethodCall>? callback]) {
    if (callback == null) {
      return;
    }
    try {
      PhotoManager.addChangeCallback(callback);
      PhotoManager.startChangeNotify();
    } catch (e, s) {
      FlutterError.presentError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: packageName,
          silent: true,
        ),
      );
    }
  }

  /// {@template wechat_assets_picker.delegates.AssetPickerDelegate.unregisterObserve}
  /// Unregister the observation callback with assets changes.
  /// 取消注册资源（图库）变化的监听回调
  /// {@endtemplate}
  void unregisterObserve([ValueChanged<MethodCall>? callback]) {
    if (callback == null) {
      return;
    }
    try {
      PhotoManager.removeChangeCallback(callback);
      PhotoManager.stopChangeNotify();
    } catch (e, s) {
      FlutterError.presentError(
        FlutterErrorDetails(
          exception: e,
          stack: s,
          library: packageName,
          silent: true,
        ),
      );
    }
  }

  /// {@template wechat_assets_picker.delegates.AssetPickerDelegate.themeData}
  /// Build a [ThemeData] with the given [themeColor] for the picker.
  /// 为选择器构建基于 [themeColor] 的 [ThemeData]。
  ///
  /// If [themeColor] is null, the color will use the fallback
  /// [defaultThemeColorWeChat] which is the default color in the WeChat design.
  /// 如果 [themeColor] 为 null，主题色将回落使用 [defaultThemeColorWeChat]，
  /// 即微信设计中的绿色主题色。
  ///
  /// Set [light] to true if pickers require a light version of the theme.
  /// 设置 [light] 为 true 时可以获取浅色版本的主题。
  /// {@endtemplate}
  ThemeData themeData(Color? themeColor, {bool light = false}) {
    return buildTheme(themeColor, light: light);
  }
}

class _PickedFileData {
  const _PickedFileData({
    required this.path,
    required this.name,
    this.mimeType,
    this.width = 0,
    this.height = 0,
    this.explicitType,
  });

  final String path;
  final String name;
  final String? mimeType;
  final int width;
  final int height;
  final AssetType? explicitType;
}

class _GalleryMediaPickerFallbackPage extends StatefulWidget {
  const _GalleryMediaPickerFallbackPage({
    required this.requestType,
    required this.maxAssets,
  });

  final RequestType requestType;
  final int maxAssets;

  @override
  State<_GalleryMediaPickerFallbackPage> createState() =>
      _GalleryMediaPickerFallbackPageState();
}

class _GalleryMediaPickerFallbackPageState
    extends State<_GalleryMediaPickerFallbackPage> {
  static const int _unboundedMaxAssets = 999;

  List<PickedAssetModel> _selected = const <PickedAssetModel>[];
  bool _isClosing = false;

  bool get _isSinglePick => widget.maxAssets == 1;

  GalleryMediaType get _mediaType {
    if (widget.requestType == RequestType.image) {
      return GalleryMediaType.onlyImages;
    }
    if (widget.requestType == RequestType.video) {
      return GalleryMediaType.onlyVideos;
    }
    return GalleryMediaType.all;
  }

  void _onSelectionChanged(List<PickedAssetModel> selected) {
    setState(() {
      _selected = selected;
    });
    if (_isSinglePick && selected.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isClosing) {
          return;
        }
        _close(<PickedAssetModel>[selected.first]);
      });
    }
  }

  void _close([List<PickedAssetModel>? result]) {
    if (_isClosing) {
      return;
    }
    _isClosing = true;
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    if (route == null) {
      navigator.pop(result);
      return;
    }
    navigator.removeRoute(route, result);
  }

  @override
  Widget build(BuildContext context) {
    final isDoneEnabled = _selected.isNotEmpty;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: GalleryMediaPicker(
          pathList: _onSelectionChanged,
          appBarLeadingWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextButton(
                onPressed: () => _close(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: isDoneEnabled ? () => _close(_selected) : null,
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: isDoneEnabled ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ],
          ),
          mediaPickerParams: MediaPickerParamsModel(
            singlePick: _isSinglePick,
            maxPickImages:
                widget.maxAssets > 0 ? widget.maxAssets : _unboundedMaxAssets,
            mediaType: _mediaType,
            appBarHeight: 56,
            appBarColor: Colors.black,
            gridViewBgColor: Colors.black,
            albumTextColor: Colors.white,
            albumSelectTextColor: Colors.white,
            albumSelectIconColor: Colors.white,
            albumDropDownBgColor: Colors.black,
            selectedAssetBgColor: Colors.white24,
            selectedCheckColor: Colors.white,
            selectedCheckBgColor: Colors.black54,
            selectedAlbumBgColor: Colors.white24,
            selectedAlbumTextColor: Colors.white,
            thumbnailBgColor: Colors.black12,
          ),
        ),
      ),
    );
  }
}
