import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings_model.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverAddressController = TextEditingController();
  final _serverPortController = TextEditingController();
  final _dnsServerController = TextEditingController();
  final _timeoutController = TextEditingController();

  bool _isTestingConnection = false;
  Map<String, String> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentSettings();
    });
  }

  void _loadCurrentSettings() {
    final settings = Provider.of<SettingsModel>(context, listen: false);
    _serverAddressController.text = settings.serverAddress;
    _serverPortController.text = settings.serverPort;
    _dnsServerController.text = settings.dnsServer;
    _timeoutController.text = settings.timeout.toString();
  }

  @override
  void dispose() {
    _serverAddressController.dispose();
    _serverPortController.dispose();
    _dnsServerController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  void _validateAndUpdate() {
    final settings = Provider.of<SettingsModel>(context, listen: false);
    setState(() {
      _validationErrors = settings.validateSettings();
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    final settings = Provider.of<SettingsModel>(context, listen: false);
    final success = await settings.testConnection();

    setState(() {
      _isTestingConnection = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '接続成功！' : '接続失敗！'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('設定初期化'),
        content: Text('すべての設定をデフォルトに戻しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('確認'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final settings = Provider.of<SettingsModel>(context, listen: false);
      await settings.resetToDefaults();
      _loadCurrentSettings();
      setState(() {
        _validationErrors.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('設定が初期化されました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('サーバー設定'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetSettings,
          ),
        ],
      ),
      body: Consumer<SettingsModel>(
        builder: (context, settings, child) {
          print('DEBUG: Consumer rebuild, baseUrl: ${settings.baseUrl}');
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'サーバー接続設定',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 20),

                // サーバーアドレス
                TextField(
                  controller: _serverAddressController,
                  decoration: InputDecoration(
                    labelText: 'サーバーアドレス',
                    hintText: 'localhost または IPアドレス',
                    border: OutlineInputBorder(),
                    helperText: '例: 192.168.1.100',
                    errorText: _validationErrors['server_address'],
                  ),
                  onChanged: (value) {
                    print('DEBUG: Server address changed to: $value');
                    // 실시간으로 모델만 업데이트 (저장은 하지 않음)
                    settings.setServerAddressTemporary(value);
                    setState(() {
                      _validationErrors.remove('server_address');
                    });
                  },
                  onEditingComplete: () async {
                    // 편집 완료 시에만 검증하고 저장
                    try {
                      await settings.saveServerAddress();
                      print('DEBUG: Server address saved permanently');
                    } catch (e) {
                      print('DEBUG: Error saving server address: $e');
                      setState(() {
                        _validationErrors['server_address'] =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                ),
                SizedBox(height: 16),

                // ポート番号
                TextField(
                  controller: _serverPortController,
                  decoration: InputDecoration(
                    labelText: 'ポート番号',
                    hintText: '3000',
                    border: OutlineInputBorder(),
                    helperText: '1-65535 の範囲の数字',
                    errorText: _validationErrors['server_port'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    // 실시간으로 모델만 업데이트
                    settings.setServerPortTemporary(value);
                    setState(() {
                      _validationErrors.remove('server_port');
                    });
                  },
                  onEditingComplete: () async {
                    // 편집 완료 시 검증하고 저장
                    try {
                      await settings.saveServerPort();
                    } catch (e) {
                      setState(() {
                        _validationErrors['server_port'] =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                ),
                SizedBox(height: 16),

                // プロトコル選択
                Row(
                  children: [
                    Text('プロトコル: '),
                    Radio<String>(
                      value: 'http',
                      groupValue: settings.protocol,
                      onChanged: (value) {
                        if (value != null) {
                          settings.updateProtocol(value);
                        }
                      },
                    ),
                    Text('HTTP'),
                    Radio<String>(
                      value: 'https',
                      groupValue: settings.protocol,
                      onChanged: (value) {
                        if (value != null) {
                          settings.updateProtocol(value);
                        }
                      },
                    ),
                    Text('HTTPS'),
                  ],
                ),
                SizedBox(height: 16),

                // DNSサーバー
                TextField(
                  controller: _dnsServerController,
                  decoration: InputDecoration(
                    labelText: 'DNSサーバー',
                    hintText: '8.8.8.8',
                    border: OutlineInputBorder(),
                    helperText: 'DNSサーバーのIPアドレス',
                    errorText: _validationErrors['dns_server'],
                  ),
                  onChanged: (value) {
                    try {
                      settings.updateDnsServer(value);
                      setState(() {
                        _validationErrors.remove('dns_server');
                      });
                    } catch (e) {
                      setState(() {
                        _validationErrors['dns_server'] =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                ),
                SizedBox(height: 16),

                // タイムアウト
                TextField(
                  controller: _timeoutController,
                  decoration: InputDecoration(
                    labelText: 'タイムアウト（秒）',
                    hintText: '30',
                    border: OutlineInputBorder(),
                    helperText: '5～300秒の範囲',
                    errorText: _validationErrors['timeout'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    try {
                      final timeout = int.tryParse(value);
                      if (timeout != null) {
                        settings.updateTimeout(timeout);
                        setState(() {
                          _validationErrors.remove('timeout');
                        });
                      } else {
                        setState(() {
                          _validationErrors['timeout'] = '数字を入力してください';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        _validationErrors['timeout'] =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                ),
                SizedBox(height: 24),

                // 現在の設定表示
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '現在のAPI URL:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        settings.baseUrl,
                        style: TextStyle(
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // 接続テストボタン
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isTestingConnection ? null : _testConnection,
                    child: _isTestingConnection
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('接続テスト中...'),
                            ],
                          )
                        : Text('接続テスト'),
                  ),
                ),

                // 키보드가 올라와도 충분한 여백 확보
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 50),
              ],
            ),
          );
        },
      ),
    );
  }
}
