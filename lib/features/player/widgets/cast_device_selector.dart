import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../data/models/cast_device.dart';
import '../../../data/services/cast_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/haptics.dart';

class CastDeviceSelector extends StatefulWidget {
  final Function(CastDevice) onDeviceSelected;
  
  const CastDeviceSelector({super.key, required this.onDeviceSelected});

  static void show(BuildContext context, {required Function(CastDevice) onDeviceSelected}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CastDeviceSelector(onDeviceSelected: onDeviceSelected),
    );
  }

  @override
  State<CastDeviceSelector> createState() => _CastDeviceSelectorState();
}

class _CastDeviceSelectorState extends State<CastDeviceSelector> {
  @override
  void initState() {
    super.initState();
    CastService.instance.startDiscovery();
  }

  @override
  void dispose() {
    CastService.instance.stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24).withOpacity(0.65),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(CupertinoIcons.tv, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Transmitir para',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              
              // Device List
              Flexible(
                child: AnimatedBuilder(
                  animation: CastService.instance,
                  builder: (context, _) {
                    final devices = CastService.instance.devices;
                    
                    if (devices.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(48.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CupertinoActivityIndicator(color: Colors.white, radius: 14),
                            const SizedBox(height: 16),
                            Text(
                              'Procurando Smart TVs...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              CupertinoIcons.tv, 
                              color: Colors.white, 
                              size: 24
                            ),
                          ),
                          title: Text(
                            device.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            device.typeName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                            ),
                          ),
                          onTap: () {
                            Haptics.light();
                            Navigator.pop(context);
                            widget.onDeviceSelected(device);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
