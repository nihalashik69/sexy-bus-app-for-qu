import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'dart:convert';
import 'dart:async';
import 'driver_models.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  // WebSocket server URL - you can change this to your server
  static const String _serverUrl = 'ws://localhost:8080/ws';

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      if (_isConnected) return;

      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      
      // Listen to incoming messages
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      notifyListeners();

      debugPrint('WebSocket connected to $_serverUrl');
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      debugPrint('Received message: $data');
      
      // Handle different message types
      switch (data['type']) {
        case 'ping':
          _sendPong();
          break;
        case 'ack':
          debugPrint('Location data acknowledged');
          break;
        default:
          debugPrint('Unknown message type: ${data['type']}');
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  void _onError(error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('WebSocket connection closed');
    _isConnected = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    debugPrint('Scheduling reconnect attempt $_reconnectAttempts in ${_reconnectDelay.inSeconds} seconds');

    _reconnectTimer = Timer(_reconnectDelay, () {
      connect();
    });
  }

  void sendBusLocation(BusLocationData busData) {
    if (!_isConnected || _channel == null) {
      debugPrint('WebSocket not connected, cannot send location data');
      return;
    }

    try {
      final message = {
        'type': 'bus_location',
        'data': {
          'busId': busData.busId,
          'driverName': busData.driverName,
          'routeId': busData.routeId,
          'latitude': busData.latitude,
          'longitude': busData.longitude,
          'timestamp': busData.timestamp.toIso8601String(),
          'status': busData.status.toString().split('.').last,
        },
      };

      _channel!.sink.add(jsonEncode(message));
      debugPrint('Sent bus location: ${busData.busId}');
    } catch (e) {
      debugPrint('Error sending bus location: $e');
    }
  }

  void _sendPong() {
    if (!_isConnected || _channel == null) return;

    try {
      final message = {
        'type': 'pong',
        'timestamp': DateTime.now().toIso8601String(),
      };

      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Error sending pong: $e');
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    if (_channel != null) {
      await _channel!.sink.close(status.goingAway);
      _channel = null;
    }
    
    _isConnected = false;
    notifyListeners();
    debugPrint('WebSocket disconnected');
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

