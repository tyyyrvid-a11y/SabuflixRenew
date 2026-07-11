import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/my_list_store.dart';
import '../../data/services/tmdb_service.dart';
import '../details/details_screen.dart';
import '../home/widgets/poster_card.dart';

/// Backed by [MyListStore]: titles saved from the details screen (via the
/// + button) show up here, persisted across app restarts.
class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  final _service = TmdbService();
  final _myList = MyListStore.instance;

  @override
  void initState() {
    super.initState();
    _myList.ensureLoaded(_service);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Minha Lista',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6),
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _myList,
                builder: (context, _) {
                  if (!_myList.isLoaded) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                  }
                  final items = _myList.items;
                  if (items.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Sua lista está vazia.\nToque em "+" em qualquer título para adicionar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textTertiary, height: 1.4),
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.52,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return PosterCard(
                        item: item,
                        width: double.infinity,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
