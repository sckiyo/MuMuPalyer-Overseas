import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MuMu海外版修改器',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const BuildPropModifierPage(),
    );
  }
}

class BuildPropModifierPage extends StatefulWidget {
  const BuildPropModifierPage({super.key});

  @override
  State<BuildPropModifierPage> createState() => _BuildPropModifierPageState();
}

class _BuildPropModifierPageState extends State<BuildPropModifierPage> {
  bool _isRooted = false;
  bool _isChecking = false;
  bool _isModifying = false;
  bool _isModified = false;
  String _statusMessage = '等待检查Root权限...';
  final shell = Shell();

  @override
  void initState() {
    super.initState();
    _checkRootAccess();
  }

  Future<void> _checkRootAccess() async {
    setState(() {
      _isChecking = true;
      _statusMessage = '正在检查Root权限...';
    });

    try {
      // 尝试执行su命令来检查root权限
      final result = await shell.run('su -c "id"');
      if (result.isNotEmpty &&
          result.first.stdout.toString().contains('uid=0')) {
        setState(() {
          _isRooted = true;
          _statusMessage = 'Root权限检查成功！';
        });
        await _checkCurrentStatus();
      } else {
        setState(() {
          _isRooted = false;
          _statusMessage = '未获得Root权限，请先获取Root权限';
        });
      }
    } catch (e) {
      setState(() {
        _isRooted = false;
        _statusMessage = '检查Root权限失败：$e';
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _checkCurrentStatus() async {
    try {
      // 首先检查/system/build.prop文件是否存在
      final fileCheck = await shell.run(
        'su -c "test -f /system/build.prop && echo exists || echo notfound"',
      );
      if (fileCheck.isEmpty ||
          !fileCheck.first.stdout.toString().contains('exists')) {
        setState(() {
          _isModified = false;
          _statusMessage = 'build.prop文件不存在或无法访问';
        });
        return;
      }

      // 检查是否包含海外版标记
      final result = await shell.run(
        'su -c "grep -q ro.build.version.overseas=true /system/build.prop && echo found || echo notfound"',
      );

      if (result.isNotEmpty &&
          result.first.stdout.toString().trim() == 'found') {
        setState(() {
          _isModified = true;
          _statusMessage = 'build.prop已包含海外版标记';
        });
      } else {
        // 再检查是否包含其他形式的标记
        final anyOverseas = await shell.run(
          'su -c "grep -q ro.build.version.overseas /system/build.prop && echo found || echo notfound"',
        );
        if (anyOverseas.isNotEmpty &&
            anyOverseas.first.stdout.toString().trim() == 'found') {
          setState(() {
            _isModified = false;
            _statusMessage = 'build.prop包含海外版标记但值不正确';
          });
        } else {
          setState(() {
            _isModified = false;
            _statusMessage = 'build.prop未包含海外版标记';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isModified = false;
        _statusMessage = 'build.prop文件状态检查失败：${e.toString()}';
      });
    }
  }

  Future<void> _modifyBuildProp() async {
    if (!_isRooted) {
      _showSnackBar('请先获取Root权限', isError: true);
      return;
    }

    setState(() {
      _isModifying = true;
      _statusMessage = '正在修改build.prop文件...';
    });

    try {
      // 检查/system分区是否可写
      setState(() {
        _statusMessage = '检查文件系统权限...';
      });

      final mountCheck = await shell.run('su -c "mount | grep \'/system\'"');
      final systemInfo = mountCheck.isNotEmpty
          ? mountCheck.first.stdout.toString()
          : '';

      if (systemInfo.contains('ro,')) {
        // 尝试重新挂载为可写
        setState(() {
          _statusMessage = '尝试重新挂载/system为可写模式...';
        });

        try {
          await shell.run('su -c "mount -o remount,rw /system"');
        } catch (remountError) {
          setState(() {
            _statusMessage = '无法重新挂载/system为可写模式';
          });
          _showSnackBar(
            '错误：/system分区只读，无法修改。请确保在MuMu设置中启用"可写系统盘"',
            isError: true,
          );
          return;
        }
      }

      // 检查是否已经存在ro.build.version.overseas=true
      setState(() {
        _statusMessage = '检查现有配置...';
      });

      final checkResult = await shell.run(
        'su -c "grep -q ro.build.version.overseas=true /system/build.prop && echo found || echo notfound"',
      );

      if (checkResult.isNotEmpty &&
          checkResult.first.stdout.toString().trim() == 'found') {
        setState(() {
          _isModified = true;
          _statusMessage = 'build.prop已包含海外版标记，无需重复添加';
        });
        _showSnackBar('文件已包含海外版标记！');
        return;
      }

      // 检查是否有其他形式的overseas标记，如果有则先删除
      final hasOtherOverseas = await shell.run(
        'su -c "grep -q ro.build.version.overseas /system/build.prop && echo found || echo notfound"',
      );
      if (hasOtherOverseas.isNotEmpty &&
          hasOtherOverseas.first.stdout.toString().trim() == 'found') {
        setState(() {
          _statusMessage = '移除旧的overseas标记...';
        });
        await shell.run(
          'su -c "sed -i \'/ro.build.version.overseas/d\' /system/build.prop"',
        );
      }

      // 创建备份
      setState(() {
        _statusMessage = '创建备份文件...';
      });
      await shell.run(
        'su -c "cp /system/build.prop /system/build.prop.backup"',
      );

      // 添加新的行到文件末尾
      setState(() {
        _statusMessage = '添加海外版标记...';
      });
      await shell.run(
        'su -c "echo \'ro.build.version.overseas=true\' >> /system/build.prop"',
      );

      // 验证修改是否成功
      final verifyResult = await shell.run(
        'su -c "grep -q ro.build.version.overseas=true /system/build.prop && echo success || echo failed"',
      );
      if (verifyResult.isEmpty ||
          verifyResult.first.stdout.toString().trim() != 'success') {
        throw Exception('验证修改失败，标记可能未正确添加');
      }

      setState(() {
        _isModified = true;
        _statusMessage = '成功添加海外版标记到build.prop！';
      });

      _showSnackBar('修改完成！请重启设备使更改生效。');
    } catch (e) {
      setState(() {
        _statusMessage = '修改失败：${e.toString()}';
      });
      _showSnackBar('修改失败：${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isModifying = false;
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MuMu海外版修改器',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 状态卡片
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      _isRooted
                          ? (_isModified ? Icons.check_circle : Icons.security)
                          : Icons.error,
                      size: 64,
                      color: _isRooted
                          ? (_isModified ? Colors.green : Colors.orange)
                          : Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Root权限状态',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRooted ? '已获取Root权限' : '未获取Root权限',
                      style: TextStyle(
                        color: _isRooted ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 状态消息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isChecking ? null : _checkRootAccess,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_isChecking ? '检查中...' : '重新检查'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_isRooted && !_isModifying && !_isModified)
                        ? _modifyBuildProp
                        : null,
                    icon: _isModifying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isModified ? Icons.check : Icons.edit),
                    label: Text(
                      _isModifying
                          ? '修改中...'
                          : _isModified
                          ? '已修改'
                          : '修改文件',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isModified ? Colors.green : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 说明文字
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Text(
                        '重要提示',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 需要Root权限并在"设备设置""磁盘"中选择"可写系统盘"\n'
                    '• 修改后需要重启设备\n'
                    '• 此操作会在/system/build.prop文件末尾添加：ro.build.version.overseas=true',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
