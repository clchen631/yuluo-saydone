class AppStrings {
  AppStrings._();

  static const appName = '语落SayDone';

  // Pool names
  static const dailyPool = '日常待办';
  static const lightPool = '轻任务';
  static const longtermPool = '长期目标';

  // Home page
  static const todayTodo = '今日待办';
  static const yesterdayIncomplete = '昨日未完成';
  static const lightTasks = '轻任务';
  static const longTermGoals = '长期目标';
  static const tomorrowTodo = '明日待办';
  static const tomorrowEmpty = '明天暂无安排';
  static const refreshRandom = '刷新';

  // Empty states
  static const emptyDaily = '暂无待办，创建一条吧';
  static const emptyLight = '轻任务池空空如也，去添加一条吧';
  static const emptyLongterm = '还没有长期目标，设定一个吧';
  static const emptyCompleted = '暂无已完成任务';
  static const emptyRecycleBin = '回收站是空的';

  // Actions
  static const selectMode = '选择';
  static const selectAll = '全选';
  static const delete = '删除';
  static const moveToPool = '移动到';
  static const moveToToday = '一键移至今天';
  static const moveBackToPool = '移回日常待办';

  // Mic
  static const micHint = '输入任务...';
  static const networkOffline = '当前未联网';
  static const sttFailed = '未识别到内容';
  static const inputInvalid = '请输入有效内容';
  static const noOpHint = '未识别到任务内容';

  // Settings
  static const settings = '设置';
  static const apiKey = 'API Key';
  static const testConnection = '测试连接';
  static const dayBoundary = '日分界时间';
  static const remindTime = '未完成任务提醒时间';
  static const recycleDays = '回收站保留天数';
  static const exportData = '数据导出';
  static const importData = '数据导入';
  static const developerMode = '开发者模式';
  static const about = '关于';
  static const restoreDefault = '恢复默认';

  // Completed / Recycle
  static const completedTasks = '已完成任务';
  static const recycleBin = '回收站';
  static const undoComplete = '撤销完成';

  // Tabs
  static const tabHome = '首页';
  static const tabPools = '池';
  static const tabProfile = '我';

  // Confirmation
  static const mergeImport = '合并';
  static const replaceImport = '替换';
  static const importStrategyTitle = '导入数据方式';
  static const cancel = '取消';
  static const confirm = '确认';
}
