# MuMu模拟器海外版修改器

一个为国内版MuMu模拟器安卓设备添加海外版标记以去除广告的Flutter应用。

## 系统要求

- MuMu模拟器 V5.0+
- 开启`设备设置`->`其他`->`Root权限`
- 选择`设备设置`->`磁盘`->`磁盘共享`->`可写系统盘`

## 安装和使用

1. 从Releases下载apk
2. 安装到需要添加海外版标记去广告的MuMu模拟器安卓设备
3. 打开应用
4. 授予Root权限
5. 点击"修改文件"
6. 重启模拟器设备

## 注意事项

- 修改后需要重启模拟器设备才能生效
- 每次MuMu模拟器更新后需要重新修改
- 建议在测试环境中先行验证

## 工作原理

应用通过以下步骤修改`/system/build.prop`文件：

1. 检查Root权限：执行`su -c "id"`命令验证
2. 检查现有标记：搜索文件中是否已存在`ro.build.version.overseas=true`
3. 添加配置行：如果不存在则执行`echo "ro.build.version.overseas=true" >> /system/build.prop`

## 技术栈

- **框架**：Flutter 3.9.0+
- **语言**：Dart
- **UI**：Material Design 3
- **平台**：Android

## 许可证

GPLv3

## 贡献

欢迎提交Issues和Pull Requests！
