import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cast/cast.dart' as google_cast;
import '../models/cast_device.dart';

class CastService extends ChangeNotifier {
  static final CastService instance = CastService._();
  CastService._();

  final List<CastDevice> _devices = [];
  List<CastDevice> get devices => _devices;

  CastDevice? _currentDevice;
  CastDevice? get currentDevice => _currentDevice;

  bool _isCasting = false;
  bool get isCasting => _isCasting;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  // Google Cast Session
  google_cast.CastSession? _castSession;
  StreamSubscription? _castStateSub;
  StreamSubscription? _castMediaSub;

  // DLNA state
  Timer? _dlnaPositionTimer;
  String? _dlnaControlUrl;

  bool _isDiscovering = false;

  void startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _devices.clear();
    notifyListeners();

    _discoverChromecasts();
    _discoverDLNA();
  }

  void stopDiscovery() {
    _isDiscovering = false;
  }

  Future<void> _discoverChromecasts() async {
    try {
      final googleCastDevices = await google_cast.CastDiscoveryService().search();
      for (var gcDevice in googleCastDevices) {
        if (!_isDiscovering) return;
        final device = CastDevice(
          id: gcDevice.name,
          name: gcDevice.name,
          host: gcDevice.host,
          type: CastDeviceType.chromecast,
          originalDevice: gcDevice,
        );
        if (!_devices.any((d) => d.id == device.id)) {
          _devices.add(device);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Erro buscando Chromecast: $e');
    }
  }

  Future<void> _discoverDLNA() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final multicastAddress = InternetAddress('239.255.255.250');
      const multicastPort = 1900;

      const searchMessage = 'M-SEARCH * HTTP/1.1\r\n'
          'Host: 239.255.255.250:1900\r\n'
          'Man: "ssdp:discover"\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
          'MX: 3\r\n\r\n';

      socket.send(utf8.encode(searchMessage), multicastAddress, multicastPort);

      socket.listen((RawSocketEvent event) async {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            final response = utf8.decode(datagram.data);
            final lines = response.split('\r\n');
            String? location;
            
            for (var line in lines) {
              if (line.toLowerCase().startsWith('location:')) {
                location = line.substring(9).trim();
                break;
              }
            }

            if (location != null && _isDiscovering) {
              await _parseDLNADevice(location);
            }
          }
        }
      });

      // Stop DLNA discovery after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        socket.close();
      });
    } catch (e) {
      debugPrint('Erro buscando DLNA: $e');
    }
  }

  Future<void> _parseDLNADevice(String locationUrl) async {
    try {
      final uri = Uri.parse(locationUrl);
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(uri);
      final response = await request.close();
      final xmlString = await response.transform(utf8.decoder).join();
      
      final nameMatch = RegExp(r'<friendlyName>(.*?)</friendlyName>').firstMatch(xmlString);
      final controlUrlMatch = RegExp(r'<serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>.*?<controlURL>(.*?)</controlURL>', dotAll: true).firstMatch(xmlString);

      if (nameMatch != null && controlUrlMatch != null) {
        final name = nameMatch.group(1) ?? 'Smart TV';
        String controlUrlPath = controlUrlMatch.group(1) ?? '';
        
        if (!controlUrlPath.startsWith('/')) {
          controlUrlPath = '/$controlUrlPath';
        }
        
        final controlUrl = '${uri.scheme}://${uri.authority}$controlUrlPath';

        final device = CastDevice(
          id: locationUrl,
          name: name,
          host: uri.host,
          type: CastDeviceType.dlna,
          originalDevice: controlUrl, // Guarda a URL de controle
        );

        if (!_devices.any((d) => d.id == device.id)) {
          _devices.add(device);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Erro fazendo parse do DLNA: $e');
    }
  }

  Future<void> connectAndPlay(CastDevice device, String mediaUrl, String title) async {
    _currentDevice = device;
    _isCasting = true;
    notifyListeners();

    if (device.type == CastDeviceType.chromecast) {
      await _playChromecast(device.originalDevice as google_cast.CastDevice, mediaUrl, title);
    } else if (device.type == CastDeviceType.dlna) {
      _dlnaControlUrl = device.originalDevice as String;
      await _playDLNA(_dlnaControlUrl!, mediaUrl, title);
    }
  }

  Future<void> _playChromecast(google_cast.CastDevice gcDevice, String mediaUrl, String title) async {
    _castSession = await google_cast.CastSessionManager().startSession(gcDevice);
    
    _castStateSub = _castSession?.stateStream.listen((state) {
      if (state == google_cast.CastSessionState.connected) {
        _castSession?.sendMessage(google_cast.CastSession.kNamespaceMedia, {
          'type': 'LOAD',
          'autoPlay': true,
          'media': {
            'contentId': mediaUrl,
            'streamType': 'BUFFERED',
            'contentType': 'video/mp4',
            'metadata': {
              'metadataType': 0,
              'title': title,
            }
          },
        });
      }
    });

    _castMediaSub = _castSession?.messageStream.listen((message) {
      if (message['namespace'] == google_cast.CastSession.kNamespaceMedia) {
        final payload = message['payload'];
        if (payload != null && payload['status'] != null) {
          final statusList = payload['status'] as List;
          if (statusList.isNotEmpty) {
            final status = statusList[0];
            final state = status['playerState'];
            _isPlaying = state == 'PLAYING' || state == 'BUFFERING';
            if (status['currentTime'] != null) {
              _position = Duration(seconds: (status['currentTime'] as num).toInt());
            }
            if (status['media'] != null && status['media']['duration'] != null) {
              _duration = Duration(seconds: (status['media']['duration'] as num).toInt());
            }
            notifyListeners();
          }
        }
      }
    });
  }

  Future<void> _playDLNA(String controlUrl, String mediaUrl, String title) async {
    final uri = Uri.parse(controlUrl);
    
    const setAvTransportBody = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <CurrentURI>__MEDIA_URL__</CurrentURI>
      <CurrentURIMetaData></CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>''';

    final body = setAvTransportBody.replaceAll('__MEDIA_URL__', mediaUrl);
    
    await _sendSOAP(uri, 'urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI', body);
    await _sendDLNACommand('Play');
    
    _isPlaying = true;
    _dlnaPositionTimer?.cancel();
    _dlnaPositionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _position += const Duration(seconds: 1); // Simples aproximação, um app real faria polling GetPositionInfo
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _sendDLNACommand(String action) async {
    if (_dlnaControlUrl == null) return;
    final uri = Uri.parse(_dlnaControlUrl!);
    final body = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:$action xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Speed>1</Speed>
    </u:$action>
  </s:Body>
</s:Envelope>''';
    await _sendSOAP(uri, 'urn:schemas-upnp-org:service:AVTransport:1#$action', body);
  }

  Future<void> _sendSOAP(Uri uri, String soapAction, String body) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('SOAPACTION', '"$soapAction"');
      request.headers.set('Content-Type', 'text/xml; charset="utf-8"');
      request.write(body);
      await request.close();
    } catch (e) {
      debugPrint('Erro SOAP: $e');
    }
  }

  void togglePlay() {
    if (!_isCasting) return;
    
    _isPlaying = !_isPlaying;
    if (_currentDevice?.type == CastDeviceType.chromecast) {
      if (_castSession != null) {
        // Envia toggle via Chromecast
        _castSession?.sendMessage(google_cast.CastSession.kNamespaceMedia, {
          'type': _isPlaying ? 'PLAY' : 'PAUSE',
        });
      }
    } else if (_currentDevice?.type == CastDeviceType.dlna) {
      _sendDLNACommand(_isPlaying ? 'Play' : 'Pause');
    }
    notifyListeners();
  }

  void stop() {
    _isCasting = false;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    
    if (_currentDevice?.type == CastDeviceType.chromecast) {
      _castSession?.close();
      _castSession = null;
      _castStateSub?.cancel();
      _castMediaSub?.cancel();
    } else if (_currentDevice?.type == CastDeviceType.dlna) {
      _sendDLNACommand('Stop');
      _dlnaPositionTimer?.cancel();
    }
    
    _currentDevice = null;
    notifyListeners();
  }

  void seek(Duration newPosition) {
    if (!_isCasting) return;
    
    _position = newPosition;
    notifyListeners();

    if (_currentDevice?.type == CastDeviceType.chromecast) {
      _castSession?.sendMessage(google_cast.CastSession.kNamespaceMedia, {
        'type': 'SEEK',
        'currentTime': newPosition.inSeconds,
      });
    } else if (_currentDevice?.type == CastDeviceType.dlna) {
      // Seek no DLNA usa o comando Seek com formato HH:MM:SS
      final uri = Uri.parse(_dlnaControlUrl!);
      final h = newPosition.inHours.toString().padLeft(2, '0');
      final m = newPosition.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = newPosition.inSeconds.remainder(60).toString().padLeft(2, '0');
      final target = '$h:$m:$s';

      final body = '''<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Unit>REL_TIME</Unit>
      <Target>$target</Target>
    </u:Seek>
  </s:Body>
</s:Envelope>''';
      _sendSOAP(uri, 'urn:schemas-upnp-org:service:AVTransport:1#Seek', body);
    }
  }
}
