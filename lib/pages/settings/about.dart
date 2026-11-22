part of 'settings_page.dart';

/// About page ported from Pica Comic's "About & help" page. It keeps PicaComic's
/// actions (license, history, codeberg switch, project links) but renders them
/// with Pica Comic's `_SettingsPageView` / `_SettingsSection` / `_SettingsGroup`
/// layout — a full page with its own `SmoothCustomScrollView` + `Appbar` — so
/// the UI matches Pica Comic.
class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  @override
  Widget build(BuildContext context) {
    return _SettingsPageView(
      title: "关于与帮助".tl,
      description: "版本信息、帮助与疑难解答".tl,
      onBack: widget.onBack,
      intro: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: const Image(
              width: 64,
              height: 64,
              image: AssetImage("images/app_icon_no_bg.png"),
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pica Comic · V$appVersion",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Pica Comic 是一个 Fork 自 Pica Comic和参考VeneraX并在原版基础上进行维护与增强，免费开源的多平台漫画阅读应用。".tl,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_platformIcon != null) ...[
                      _platformIcon!,
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _platformName,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      sections: [
        _SettingsSection(
          title: "版本与更新".tl,
          common: true,
          children: [
            ListTile(
              title: Text("检查更新".tl),
              trailing: Button.filled(
                child: Text("检查".tl),
                onPressed: () => findUpdate(context),
              ),
            ),
            SwitchListTile(
              title: Text("启动时检查更新".tl),
              value: appdata.settings[2] == "1",
              onChanged: (value) {
                setState(() => appdata.settings[2] = value ? "1" : "0");
                appdata.updateSettings();
              },
            ),
            if (!PlatformUtils.isOhos)
              SwitchListTile(
                title: Text("切换至codeberg更新漫画源和更新".tl),
                subtitle: const Text("关闭可切换回github"),
                value: appdata.settings[105] == "1",
                onChanged: (value) {
                  setState(() => appdata.settings[105] = value ? "1" : "0");
                  appdata.updateSettings();
                },
              ),
          ],
        ),
        _SettingsSection(
          title: "帮助".tl,
          common: true,
          children: [
            ListTile(
              title: Text("使用方法".tl),
              subtitle: Text("主要功能怎么用".tl),
              trailing: const Icon(Icons.menu_book_outlined),
              onTap: () => GuidePage.open(context),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text("开源许可证"),
              subtitle: const Text("查看所有开源许可证"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => App.globalTo(() => const AboutLicensePage()),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("历史版本"),
              subtitle: const Text("查看历史版本更新"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showPopUpWidget(
                App.globalContext!,
                const AppUpdaterHistoryPage(),
              ),
            ),
            ListTile(
             leading: const Icon(Icons.code),
              title: Text("项目地址".tl),
              subtitle: Text("ccbkv/PicaComic".tl),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => AppUrlLauncher.launchExternalUrl(kProjectRepoUrl),
            ),
            ListTile(
              leading: const Icon(Icons.comment_outlined),
              title: Text("问题反馈 (Github)".tl),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => AppUrlLauncher.launchExternalUrl(kProjectIssuesUrl),
            ),
            ListTile(
              title: Text("用户协议与免责声明".tl),
              trailing: const Icon(Icons.info_outline),
              onTap: () => showDisclaimerDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.telegram),
              title: Text("加入群组群聊".tl),
              trailing: const Icon(Icons.open_in_new),
              onTap: _launchGroup,
            ),
          ],
        ),
        _SettingsSection(
          title: '诊断与调试',
          common: true,
          children: [
            ListTile(
              title: Text('应用日志'),
              subtitle: Text('搜索、筛选和导出运行日志'),
              leading: Icon(Icons.receipt_long_outlined),
              onTap: () => context.to(() => const LogsPage()),
            ),
            ListTile(
              title: const Text('Debug'),
              subtitle: const Text('高级排查工具'),
              leading: Icon(Icons.code),
              onTap: () => context.to(
                () => Scaffold(
                  appBar: Appbar(
                    title: const Text('Debug'),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  body: const DebugPage(),
                ),
              ),
            ),
          ],
        ),        
      ],
    );
  }
}




/// Mirrors Pica Comic's `_SettingsSection` data holder.
class _SettingsSection {
  const _SettingsSection({
    required this.title,
    required this.children,
    this.common = false,
  });

  final String title;
  final bool common;
  final List<Widget> children;
}

/// Mirrors Pica Comic's `_SettingsPageView`: a full page with an optional header
/// and a `SmoothCustomScrollView` rendering title, description, intro and the
/// common sections. Adapted to PicaComic's `Appbar` / `SmoothCustomScrollView`.
class _SettingsPageView extends StatelessWidget {
  const _SettingsPageView({
    required this.title,
    required this.sections,
    this.description,
    this.intro,
    this.showHeader = true,
    this.onBack,
  });

  final String title;
  final String? description;
  final List<_SettingsSection> sections;
  final Widget? intro;
  final bool showHeader;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildView(context, constraints.maxWidth),
  );

  Widget _buildView(BuildContext context, double width) {
    final colors = context.colorScheme;
    final wide = width >= 700;
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(fontSize: 14);
    final body = SmoothCustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 32 : 20,
                  12,
                  wide ? 32 : 20,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (intro != null) ...[intro!, const SizedBox(height: 24)],
                    for (final item in sections.where((i) => i.common))
                      _SettingsGroup(title: item.title, children: item.children),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return Theme(
      data: theme.copyWith(
        canvasColor: colors.surface,
        scaffoldBackgroundColor: colors.surface,
        listTileTheme: theme.listTileTheme.copyWith(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          minTileHeight: 60,
          titleTextStyle: titleStyle,
          subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
          iconColor: colors.onSurfaceVariant,
        ),
        dividerTheme: theme.dividerTheme.copyWith(
          space: 1,
          thickness: 0.6,
          color: colors.outlineVariant,
        ),
      ),
      child: Material(
        color: colors.surface,
        child: Column(
          children: [
            if (showHeader)
              Appbar(
                title: Text(
                  "设置".tl,
                  style: const TextStyle(fontSize: 14),
                ),
                leading: onBack == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: onBack,
                      ),
                backgroundColor: colors.surface,
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Mirrors Pica Comic's `_SettingsGroup`: a titled, rounded card with dividers.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({this.title, required this.children, this.columns = 1});

  final String? title;
  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 9),
              child: Text(
                title!,
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ),
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.65),
                width: 0.7,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i += columns) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  if (columns == 1 || i + 1 == children.length)
                    children[i]
                  else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: children[i]),
                          const VerticalDivider(width: 1, thickness: 0.6),
                          Expanded(child: children[i + 1]),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
