import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../../core/theme/app_theme.dart';

class TrackSelectorSheet extends StatefulWidget {
  const TrackSelectorSheet({super.key, required this.player});
  
  final Player player;

  static void show(BuildContext context, Player player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TrackSelectorSheet(player: player),
    );
  }

  @override
  State<TrackSelectorSheet> createState() => _TrackSelectorSheetState();
}

class _TrackSelectorSheetState extends State<TrackSelectorSheet> {
  int _currentTab = 0; // 0 = Áudio, 1 = Legendas

  @override
  Widget build(BuildContext context) {
    final tracks = widget.player.state.tracks;
    final currentTrack = widget.player.state.track;

    final audioTracks = tracks.audio;
    final subtitleTracks = tracks.subtitle;
    
    final currentAudio = currentTrack.audio;
    final currentSubtitle = currentTrack.subtitle;

    final hasAudio = audioTracks.length > 1; // Se tiver só 1, nem tem opção real
    final hasSubtitles = subtitleTracks.isNotEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: AppColors.background.withOpacity(0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _currentTab == 0 ? AppColors.accent : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Áudio',
                                style: TextStyle(
                                  color: _currentTab == 0 ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _currentTab == 1 ? AppColors.accent : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Legendas',
                                style: TextStyle(
                                  color: _currentTab == 1 ? Colors.white : Colors.white54,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 8),

                // Lista de opções
                Flexible(
                  child: SafeArea(
                    bottom: true,
                    top: false,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      shrinkWrap: true,
                      children: _currentTab == 0
                          ? _buildAudioTracks(audioTracks, currentAudio)
                          : _buildSubtitleTracks(subtitleTracks, currentSubtitle),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAudioTracks(List<AudioTrack> tracks, AudioTrack current) {
    if (tracks.isEmpty) {
      return [const _EmptyState(text: 'Nenhuma faixa de áudio alternativo encontrada.')];
    }
    
    return tracks.map((track) {
      final isSelected = track == current;
      String label = track.title ?? track.language ?? track.id;
      if (label == 'auto' || label == 'no') label = 'Padrão / Original';
      
      return _TrackTile(
        title: label.toUpperCase(),
        isSelected: isSelected,
        onTap: () {
          widget.player.setAudioTrack(track);
          setState(() {});
          Navigator.of(context).pop();
        },
      );
    }).toList();
  }

  List<Widget> _buildSubtitleTracks(List<SubtitleTrack> tracks, SubtitleTrack current) {
    if (tracks.isEmpty) {
      return [const _EmptyState(text: 'Nenhuma legenda encontrada neste vídeo.')];
    }

    return tracks.map((track) {
      final isSelected = track == current;
      String label = track.title ?? track.language ?? track.id;
      if (label == 'no') label = 'Desativado';
      if (label == 'auto') label = 'Automático';
      
      return _TrackTile(
        title: label.toUpperCase(),
        isSelected: isSelected,
        onTap: () {
          widget.player.setSubtitleTrack(track);
          setState(() {});
          Navigator.of(context).pop();
        },
      );
    }).toList();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 15),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected) const Icon(CupertinoIcons.checkmark_alt, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
