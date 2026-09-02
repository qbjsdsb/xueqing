import 'package:flutter/material.dart';

class BootstrapPage extends StatelessWidget {
  const BootstrapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '学情闭环',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '机构教学协作与学生成长闭环系统',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.architecture_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Foundation v0.3',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '当前完成产品、架构、权限、数据模型与运行风险评审。这里仍是源码占位，不代表完整 Flutter 工程已经初始化。',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 20),
                          const _FoundationItem(
                            icon: Icons.verified_user_outlined,
                            title: '权限先于页面',
                            description: '机构、成员、角色、师生关系与数据库层 RLS 共同决定访问范围。',
                          ),
                          const _FoundationItem(
                            icon: Icons.timeline_rounded,
                            title: '下一步驱动闭环',
                            description: '证据、干预、验证、事件历史与主行动共同形成连续学情。',
                          ),
                          const _FoundationItem(
                            icon: Icons.cloud_done_outlined,
                            title: '云端事实源，输入不白填',
                            description: '正式数据以云端为准，同时为网络失败保留可恢复的临时草稿。',
                          ),
                          const _FoundationItem(
                            icon: Icons.speed_rounded,
                            title: 'V1 只做核心四入口',
                            description: '今日、学生、课程、学情；家校与报告在后续版本进入。',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '开发阶段仅使用虚构数据。真实学生信息必须等安全、权限、备份和网络门槛通过后再接入。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoundationItem extends StatelessWidget {
  const _FoundationItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
