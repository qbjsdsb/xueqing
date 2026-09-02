class AppFailure {
  const AppFailure({required this.title, required this.message});

  const AppFailure.bootstrap()
    : title = '工程启动失败',
      message = '工程配置无法加载，请检查构建参数后重试。';

  final String title;
  final String message;
}
