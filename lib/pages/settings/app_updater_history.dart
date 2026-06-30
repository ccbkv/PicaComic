import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pica_comic/base.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/request/clients/download_http_client.dart';
import 'package:pica_comic/request/config/api_endpoints.dart';
import 'package:pica_comic/services/logging/logger.dart';
import 'package:pica_comic/utils/date_time.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bean/dialog/dialog_helper.dart';
import 'app_updater.dart';

class AppUpdaterHistoryPage extends StatefulWidget {
  const AppUpdaterHistoryPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AppUpdaterHistoryPage> createState() => _AppUpdaterHistoryPageState();
}

class _AppUpdaterHistoryPageState extends State<AppUpdaterHistoryPage> {
  final DownloadHttpClient _downloadClient = DownloadHttpClient.instance;
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _currentPage = 0;
  List<_ReleaseHistoryItem> _releases = const [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadReleases();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadNextPage();
    }
  }

  Future<_ReleasePageResult> _fetchReleasePage(int page) async {
    final res = await _downloadClient
        .getPlain('${ApiEndpoints.appReleases}?per_page=$_pageSize&page=$page');
    if (res.error) {
      throw Exception(res.errorMessageWithoutNull);
    }

    final data = json.decode(res.data);
    if (data is! List) {
      throw Exception('无效的版本历史响应');
    }

    final rawItems = data.whereType<Map>().toList();
    final releases = rawItems
        .map((item) =>
            _ReleaseHistoryItem.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => !item.draft)
        .toList();

    return _ReleasePageResult(
      releases: releases,
      hasMore: rawItems.length >= _pageSize,
    );
  }

  Future<void> _loadReleases() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _hasMore = true;
        _errorMessage = null;
        _currentPage = 0;
      });
    }

    try {
      final result = await _fetchReleasePage(1);

      if (!mounted) {
        return;
      }

      setState(() {
        _releases = result.releases;
        _currentPage = result.releases.isEmpty ? 0 : 1;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (e) {
      KazumiLogger().e('Update history: load releases failed', error: e);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_loading || _loadingMore || !_hasMore) {
      return;
    }

    setState(() {
      _loadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await _fetchReleasePage(nextPage);
      if (!mounted) {
        return;
      }

      setState(() {
        _releases = [..._releases, ...result.releases];
        _currentPage = result.releases.isEmpty ? _currentPage : nextPage;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      KazumiLogger().e('Update history: load more releases failed', error: e);
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingMore = false;
      });
      KazumiDialog.showToast(message: '加载更多历史版本失败');
    }
  }

  List<InstallationType> _downloadableTypes(List<dynamic> assets) {
    final types = <InstallationType>[];

    void addIfAvailable(InstallationType type) {
      final asset = getUpdateAssetForType(assets, type);
      final url = getUpdateDownloadUrlFromAsset(asset);
      if (asset != null && url.isNotEmpty) {
        types.add(type);
      }
    }

    try {
      if (Platform.isWindows) {
        addIfAvailable(InstallationType.windowsMsix);
        addIfAvailable(InstallationType.windowsPortable);
      } else if (Platform.isMacOS) {
        addIfAvailable(InstallationType.macosDmg);
      } else if (Platform.isAndroid) {
        addIfAvailable(InstallationType.androidApk);
      }
    } catch (e) {
      KazumiLogger().w('Update history: detect downloadable types failed',
          error: e);
    }

    return types;
  }

  String _installationTypeDescription(InstallationType type) {
    switch (type) {
      case InstallationType.windowsMsix:
        return 'Windows MSIX 包';
      case InstallationType.windowsPortable:
        return 'Windows 便携版 (ZIP)';
      case InstallationType.linuxDeb:
        return 'Linux DEB 包';
      case InstallationType.linuxTar:
        return 'Linux TAR 包';
      case InstallationType.macosDmg:
        return 'macOS DMG 镜像';
      case InstallationType.androidApk:
        return 'Android APK';
      case InstallationType.ios:
        return 'iOS ipa';
      case InstallationType.unknown:
        return '未知安装类型';
    }
  }

  String _normalizeVersion(String version) {
    return version.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }

  bool _isCurrentVersion(String version) {
    return _normalizeVersion(version) == _normalizeVersion(appVersion);
  }

  String _summaryText(String body) {
    final lines = body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return '暂无更新说明';
    }
    return lines.first;
  }

  Future<void> _showReleaseDetails(_ReleaseHistoryItem release) async {
    final downloadableTypes = _downloadableTypes(release.assets);
    final releaseOnly = Platform.isLinux || Platform.isIOS;
    final description =
        release.description.isEmpty ? '暂无更新说明' : release.description;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final maxDialogHeight = MediaQuery.of(context).size.height * 0.6;
        return AlertDialog(
          title: Text('版本 ${release.version}'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: maxDialogHeight,
            ),
            child: Scrollbar(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(description),
                    if (release.publishedAt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '发布时间: ${formatDate(release.publishedAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (_isCurrentVersion(release.version) ||
                        release.prerelease) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_isCurrentVersion(release.version))
                            const _InfoChip(label: '当前版本'),
                          if (release.prerelease)
                            const _InfoChip(label: '预发布'),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (downloadableTypes.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '选择安装类型:',
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 8),
                            ...downloadableTypes.map(
                              (type) => Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      final updateInfo = UpdateInfo(
                                        version: release.version,
                                        description: description,
                                        downloadUrl: '',
                                        releaseNotes: release.htmlUrl,
                                        publishedAt: release.publishedAt,
                                        installationType: type,
                                        availableInstallationTypes:
                                            downloadableTypes,
                                        assets: release.assets,
                                      );
                                      AutoUpdater().downloadRelease(
                                          updateInfo, type);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.3),
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.download,
                                            size: 16,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _installationTypeDescription(type),
                                              style:
                                                  theme.textTheme.bodySmall,
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 12,
                                            color: theme.colorScheme.outline,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (releaseOnly || downloadableTypes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          releaseOnly
                              ? '当前平台请前往发布页选择对应安装包'
                              : '该版本没有适配当前平台的内置下载包，可通过“查看详情”前往发布页',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '关闭',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
            if (release.htmlUrl.isNotEmpty)
              TextButton(
                onPressed: () {
                  launchUrl(
                    Uri.parse(release.htmlUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text(releaseOnly ? '前往下载' : '查看详情'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text('加载历史版本失败'),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadReleases,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_releases.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadReleases,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(child: Text('暂无历史版本')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReleases,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _releases.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _releases.length) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (_hasMore) {
              return ListTile(
                title: const Center(child: Text('加载更多')),
                trailing: const Icon(Icons.expand_more),
                onTap: _loadNextPage,
              );
            }

            return ListTile(
              title: Text(
                '没有更多历史版本了',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }

          final release = _releases[index];
          final isCurrent = _isCurrentVersion(release.version);
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Icon(
              isCurrent ? Icons.check_circle_outline : Icons.history,
              color: isCurrent ? Theme.of(context).colorScheme.primary : null,
            ),
            title: Text(release.version),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('发布时间: ${formatDate(release.publishedAt)}'),
                  const SizedBox(height: 4),
                  Text(
                    _summaryText(release.description),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showReleaseDetails(release),
          );
        },
      ),
    );
  }

  Widget _buildEmbeddedBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text('加载历史版本失败'),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadReleases,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (_releases.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('暂无历史版本')),
      );
    }

    return Column(
      children: [
        ...List.generate(_releases.length, (index) {
          final release = _releases[index];
          final isCurrent = _isCurrentVersion(release.version);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Icon(
                  isCurrent ? Icons.check_circle_outline : Icons.history,
                  color:
                      isCurrent ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(release.version),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('发布时间: ${formatDate(release.publishedAt)}'),
                      const SizedBox(height: 4),
                      Text(
                        _summaryText(release.description),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _showReleaseDetails(release),
              ),
              if (index != _releases.length - 1) const Divider(height: 1),
            ],
          );
        }),
        const Divider(height: 1),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_hasMore)
          ListTile(
            title: const Center(child: Text('加载更多')),
            trailing: const Icon(Icons.expand_more),
            onTap: _loadNextPage,
          )
        else
          ListTile(
            title: Text(
              '没有更多历史版本了',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildEmbeddedBody();
    }

    return PopUpWidgetScaffold(
      title: '历史版本',
      tailing: [
        IconButton(
          tooltip: '刷新',
          onPressed: _loadReleases,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _buildBody(),
    );
  }
}

class _ReleaseHistoryItem {
  final String version;
  final String description;
  final String htmlUrl;
  final String publishedAt;
  final List<dynamic> assets;
  final bool prerelease;
  final bool draft;

  const _ReleaseHistoryItem({
    required this.version,
    required this.description,
    required this.htmlUrl,
    required this.publishedAt,
    required this.assets,
    required this.prerelease,
    required this.draft,
  });

  factory _ReleaseHistoryItem.fromJson(Map<String, dynamic> json) {
    return _ReleaseHistoryItem(
      version: (json['tag_name'] as String?) ?? '',
      description: (json['body'] as String?) ?? '',
      htmlUrl: (json['html_url'] as String?) ?? '',
      publishedAt: (json['published_at'] as String?) ?? '',
      assets: (json['assets'] as List?) ?? const [],
      prerelease: json['prerelease'] == true,
      draft: json['draft'] == true,
    );
  }
}

class _ReleasePageResult {
  final List<_ReleaseHistoryItem> releases;
  final bool hasMore;

  const _ReleasePageResult({
    required this.releases,
    required this.hasMore,
  });
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
