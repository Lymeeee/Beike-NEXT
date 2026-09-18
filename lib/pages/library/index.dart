import 'package:flutter/material.dart';

import '/services/library/service.dart';
import '/types/library.dart';
import '/utils/app_bar.dart';
import '/utils/haptic.dart';
import '/utils/page_mixins.dart';
import 'login.dart';
import 'psg_tab.dart';
import 'reservations_tab.dart';
import 'seat_tab.dart';

/// 图书馆：座位预约 / 我的预约 / 研修间
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with PageStateMixin, LoadingStateMixin {
  static const String _sessionKey = 'library_account_data';

  final LibraryService _service = LibraryService();
  bool _booting = true;

  @override
  void onServiceInit() {
    _service.addListener(_onLibraryServiceChanged);
    _boot();
  }

  @override
  void dispose() {
    _service.removeListener(_onLibraryServiceChanged);
    _service.dispose();
    super.dispose();
  }

  void _onLibraryServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _boot() async {
    try {
      final saved = serviceProvider.storeService
          .getConfig<LibzwSession>(_sessionKey, LibzwSession.fromJson);
      if (saved != null) {
        await _service.restore(saved);
        // token 可能被刷新过，回写持久化
        final session = _service.session;
        if (session != null && session != saved) {
          serviceProvider.storeService.putConfig(_sessionKey, session);
        }
      }
    } catch (_) {
      // 恢复失败按未登录处理
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  Future<void> _login() async {
    Haptics.medium();
    final session = await showLibzwLoginDialog(context);
    if (session == null || !mounted) return;
    _service.applySession(session);
    try {
      serviceProvider.storeService.putConfig(_sessionKey, session);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    Haptics.light();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出图书馆账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _service.applySession(null);
    try {
      serviceProvider.storeService.delConfig(_sessionKey);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: '图书馆',
        actions: [
          if (_service.isOnline)
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: '退出登录',
            ),
        ],
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : (_service.isOnline ? _buildTabs() : _buildLoginView()),
    );
  }

  Widget _buildTabs() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '选座', icon: Icon(Icons.event_seat)),
              Tab(text: '研修室', icon: Icon(Icons.meeting_room_outlined)),
              Tab(text: '我的预约', icon: Icon(Icons.list_alt)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SeatTab(service: _service),
                PsgTab(service: _service),
                ReservationsTab(service: _service),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 未登录视图：样式对齐教务账户页
  Widget _buildLoginView() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('本机登录状态', style: theme.textTheme.bodySmall),
                        Text(
                          '未登录',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              '登录方式',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(
                Icons.security,
                color: theme.colorScheme.primary,
                size: 32,
              ),
              title: const Text('统一身份认证登录'),
              subtitle: const Text('推荐方式，扫码登录图书馆选座系统'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Haptics.selection();
                _login();
              },
            ),
          ),
        ],
      ),
    );
  }
}
