import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/glass/glass_button.dart';
import '../../core/theme/app_theme.dart';
import '../player/video_player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  Future<void> _pickAndPlayFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                item: null, // Null indicates local file
                localFile: File(path),
                localTitle: result.files.single.name,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir arquivo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 40,
                    iconSize: 18,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Downloads',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: Column(
                children: [
                  const Icon(CupertinoIcons.cloud_download, size: 60, color: AppColors.textTertiary),
                  const SizedBox(height: 24),
                  const Text(
                    'Os downloads agora são feitos diretamente pelo seu navegador, e não mais dentro do app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textTertiary, height: 1.4, fontSize: 15),
                  ),
                  const SizedBox(height: 40),
                  GlassButton(
                    label: 'Abrir Arquivo Local',
                    icon: CupertinoIcons.folder,
                    style: GlassButtonStyle.filled,
                    onTap: () => _pickAndPlayFile(context),
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
