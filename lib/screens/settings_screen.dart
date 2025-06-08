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
        content: Text(success ? '연결 성공!' : '연결 실패!'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('설정 초기화'),
        content: Text('모든 설정을 기본값으로 되돌리시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('확인'),
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
        SnackBar(content: Text('설정이 초기화되었습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('서버 설정'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetSettings,
          ),
        ],
      ),
      body: Consumer<SettingsModel>(
        builder: (context, settings, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '서버 연결 설정',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 20),

                // 서버 주소
                TextField(
                  controller: _serverAddressController,
                  decoration: InputDecoration(
                    labelText: '서버 주소',
                    hintText: 'localhost 또는 IP 주소',
                    border: OutlineInputBorder(),
                    helperText: '예: 192.168.1.100',
                    errorText: _validationErrors['server_address'],
                  ),
                  onChanged: (value) {
                    try {
                      settings.updateServerAddress(value);
                      setState(() {
                        _validationErrors.remove('server_address');
                      });
                    } catch (e) {
                      setState(() {
                        _validationErrors['server_address'] =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                ),
                SizedBox(height: 16),

                // 포트 번호
                TextField(
                  controller: _serverPortController,
                  decoration: InputDecoration(
                    labelText: '포트 번호',
                    hintText: '3000',
                    border: OutlineInputBorder(),
                    helperText: '1-65535 범위의 숫자',
                    errorText: _validationErrors['server_port'],
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    try {
                      settings.updateServerPort(value);
                      setState(() {
                        _validationErrors.remove('server_port');
                      });
                    } catch (e) {
                      setState(() {
                        _validationErrors['server_port'] =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
                ),
                SizedBox(height: 16),

                // 프로토콜 선택
                Row(
                  children: [
                    Text('프로토콜: '),
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

                // DNS 서버
                TextField(
                  controller: _dnsServerController,
                  decoration: InputDecoration(
                    labelText: 'DNS 서버',
                    hintText: '8.8.8.8',
                    border: OutlineInputBorder(),
                    helperText: 'DNS 서버 IP 주소',
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

                // 타임아웃
                TextField(
                  controller: _timeoutController,
                  decoration: InputDecoration(
                    labelText: '타임아웃 (초)',
                    hintText: '30',
                    border: OutlineInputBorder(),
                    helperText: '5-300초 범위',
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
                          _validationErrors['timeout'] = '숫자를 입력하세요';
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

                // 현재 설정 표시
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
                        '현재 API URL:',
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

                // 연결 테스트 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_isTestingConnection || _validationErrors.isNotEmpty)
                            ? null
                            : _testConnection,
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
                              Text('연결 테스트 중...'),
                            ],
                          )
                        : Text('연결 테스트'),
                  ),
                ),

                Spacer(),

                Center(
                  child: Text(
                    '설정은 자동으로 저장됩니다',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
