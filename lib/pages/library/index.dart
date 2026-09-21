import 'dart:async';

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

  LibzwSession? _readStored() => serviceProvider.storeService
      .getConfig<LibzwSession>(LibzwSession.storeKey, LibzwSession.fromJson);

  /// 短信登录手机号回写：仅更新手机号，保留已存的其他字段
  void _saveSmsPhone(String phone) {
    try {
      final stored = _readStored() ?? LibzwSession();
      serviceProvider.storeService.putConfig(
        LibzwSession.storeKey,
        stored.copyWith(lastSmsPhone: phone),
      );
    } catch (_) {}
  }

  Future<void> _boot() async {
    try {
      final saved = _readStored();
      if (saved != null) {
        final ok = await _service.restore(saved);
        // token 可能被刷新过，回写持久化
        final session = _service.session;
        if (session != null && session != saved) {
          serviceProvider.storeService.putConfig(LibzwSession.storeKey, session);
        }
        // 登录态就绪后留存一份预约缓存，供首页卡片离线展示
        if (ok) unawaited(_service.refreshResvCache());
      }
    } catch (_) {
      // 恢复失败按未登录处理
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  Future<void> _login() async {
    Haptics.medium();
    final session = await showLibzwLoginDialog(
      context,
      defaultSmsPhone: _readStored()?.lastSmsPhone,
      onUpdateSmsPhone: _saveSmsPhone,
    );
    if (session == null || !mounted) return;
    // 登录返回的会话不含手机号，从缓存补上后一起持久化
    final merged = session.copyWith(lastSmsPhone: _readStored()?.lastSmsPhone);
    _service.applySession(merged);
    try {
      serviceProvider.storeService.putConfig(LibzwSession.storeKey, merged);
    } catch (_) {}
    unawaited(_service.refreshResvCache());
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
    // 缓存属于账号数据，退出时一并清除
    _service.clearResvCache();
    try {
      // 退出登录保留手机号（与教务一致），下次登录框仍预填
      final phone = _readStored()?.lastSmsPhone;
      if (phone != null) {
        serviceProvider.storeService.putConfig(
          LibzwSession.storeKey,
          LibzwSession(lastSmsPhone: phone),
        );
      } else {
        serviceProvider.storeService.delConfig(LibzwSession.storeKey);
      }
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
            child: Text('登录方式', style: theme.textTheme.headlineSmall),
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
              subtitle: const Text('使用北京科技大学SSO系统'),
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
