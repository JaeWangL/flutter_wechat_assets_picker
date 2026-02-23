// Copyright 2019 The FlutterCandies author. All rights reserved.
// Use of this source code is governed by an Apache license that can be found
// in the LICENSE file.

import 'package:photo_manager/photo_manager.dart' show ThumbnailSize;

const packageName = 'wechat_assets_picker';

const int defaultAssetsPerPage = 80;
const int defaultMaxAssetsCount = 9;

/// Internal prefix for synthetic [AssetEntity.id] values produced by Android
/// platform picker mode.
///
/// The suffix is a URI-encoded absolute file path. These IDs are temporary
/// implementation details and should not be persisted or sent to external
/// systems.
const String androidPlatformPickerAssetIdPrefix =
    'wap_android_platform_picker:';

const defaultAssetGridPreviewSize = ThumbnailSize.square(200);
const defaultPathThumbnailSize = ThumbnailSize.square(80);
