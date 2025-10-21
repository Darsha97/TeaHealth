// // history_page.dart
// import 'dart:convert'; // <-- for base64Decode
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// import 'history_service.dart'; // assumes HistoryItem has `imageB64`

// class HistoryPage extends StatelessWidget {
//   const HistoryPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       return const Scaffold(
//         body: Center(child: Text('Please log in to see your scan history')),
//       );
//     }

//     final svc = HistoryService();

//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         centerTitle: true,
//         title: const Text('History', style: TextStyle(color: Colors.white)),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: Stack(
//         children: [
//           // Background gradient
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//           const Positioned(top: -60, right: -40, child: _DecorativeCircle(size: 180, opacity: 0.18)),
//           const Positioned(bottom: -50, left: -30, child: _DecorativeCircle(size: 240, opacity: 0.14)),

//           // Content
//           SafeArea(
//             child: StreamBuilder<List<HistoryItem>>(
//               stream: svc.streamScans(user.uid),
//               builder: (context, snap) {
//                 if (snap.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator(color: Colors.white));
//                 }
//                 if (snap.hasError) {
//                   return Center(
//                     child: Text(
//                       'Failed to load history:\n${snap.error}',
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   );
//                 }

//                 final items = snap.data ?? const [];
//                 if (items.isEmpty) {
//                   return const Center(
//                     child: Text(
//                       'No scans yet.\nScan a tea leaf to see results here.',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.white, fontSize: 16),
//                     ),
//                   );
//                 }

//                 return ListView.separated(
//                   padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//                   itemCount: items.length,
//                   separatorBuilder: (_, __) => const SizedBox(height: 12),
//                   itemBuilder: (context, i) {
//                     final it = items[i];
//                     final pct = it.confidence != null ? (it.confidence! * 100).round() : null;
//                     final color = it.label.toLowerCase().contains('healthy')
//                         ? Colors.green
//                         : Colors.redAccent;

//                     return Card(
//                       elevation: 8,
//                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                       clipBehavior: Clip.antiAlias,
//                       child: InkWell(
//                         onTap: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (_) => _ImagePreviewPage(
//                                 imageB64: it.imageB64,     // <-- pass base64
//                                 label: it.label,
//                                 confidencePct: pct,
//                                 createdAt: it.createdAt,
//                               ),
//                             ),
//                           );
//                         },
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             AspectRatio(
//                               aspectRatio: 4 / 3,
//                               child: it.imageB64.isNotEmpty
//                                   ? Image.memory(
//                                       base64Decode(it.imageB64),
//                                       fit: BoxFit.cover,
//                                       errorBuilder: (_, __, ___) =>
//                                           const Center(child: Icon(Icons.broken_image, size: 48)),
//                                     )
//                                   : const Center(child: Icon(Icons.broken_image, size: 48)),
//                             ),
//                             Padding(
//                               padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//                               child: Row(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   CircleAvatar(
//                                     radius: 18,
//                                     backgroundColor: color.withOpacity(0.15),
//                                     child: Icon(
//                                       it.label.toLowerCase().contains('healthy')
//                                           ? Icons.eco
//                                           : Icons.warning_amber_rounded,
//                                       color: color,
//                                       size: 20,
//                                     ),
//                                   ),
//                                   const SizedBox(width: 12),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           it.label,
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.w700,
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Text(
//                                           _formatWhen(it.createdAt),
//                                           style: TextStyle(color: Colors.grey.shade700),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                   if (pct != null)
//                                     Container(
//                                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//                                       decoration: BoxDecoration(
//                                         color: Colors.black.withOpacity(0.06),
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                       child: Text(
//                                         '$pct%',
//                                         style: const TextStyle(fontWeight: FontWeight.w700),
//                                       ),
//                                     ),
//                                   PopupMenuButton<String>(
//                                     onSelected: (v) async {
//                                       if (v == 'delete') {
//                                         await HistoryService().deleteScan(uid: user.uid, id: it.id);
//                                       }
//                                     },
//                                     itemBuilder: (_) => const [
//                                       PopupMenuItem(value: 'delete', child: Text('Delete')),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   static String _formatWhen(DateTime dt) {
//     final now = DateTime.now();
//     final diff = now.difference(dt);
//     if (diff.inMinutes < 1) return 'just now';
//     if (diff.inHours < 1) return '${diff.inMinutes} min ago';
//     if (diff.inDays < 1) return '${diff.inHours} hr ago';
//     return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
//   }

//   static String _two(int n) => n.toString().padLeft(2, '0');
// }

// class _DecorativeCircle extends StatelessWidget {
//   const _DecorativeCircle({required this.size, required this.opacity});
//   final double size;
//   final double opacity;

//   @override
//   Widget build(BuildContext context) {
//     return Opacity(
//       opacity: opacity,
//       child: Container(
//         width: size,
//         height: size,
//         decoration: const BoxDecoration(
//           shape: BoxShape.circle,
//           gradient: LinearGradient(
//             colors: [Colors.white, Colors.white70],
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _ImagePreviewPage extends StatelessWidget {
//   const _ImagePreviewPage({
//     required this.imageB64,          // <-- base64
//     required this.label,
//     required this.createdAt,
//     this.confidencePct,
//   });

//   final String imageB64;
//   final String label;
//   final int? confidencePct;
//   final DateTime createdAt;

//   @override
//   Widget build(BuildContext context) {
//     final color = label.toLowerCase().contains('healthy') ? Colors.green : Colors.redAccent;

//     return Scaffold(
//       appBar: AppBar(title: const Text('Scan Detail')),
//       body: ListView(
//         children: [
//           AspectRatio(
//             aspectRatio: 4 / 3,
//             child: imageB64.isNotEmpty
//                 ? Image.memory(
//                     base64Decode(imageB64),
//                     fit: BoxFit.cover,
//                     errorBuilder: (_, __, ___) =>
//                         const Center(child: Icon(Icons.broken_image, size: 48)),
//                   )
//                 : const Center(child: Icon(Icons.broken_image, size: 48)),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Chip(
//                   backgroundColor: color.withOpacity(0.12),
//                   avatar: Icon(
//                     label.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_amber_rounded,
//                     color: color,
//                     size: 18,
//                   ),
//                   label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
//                 ),
//                 const SizedBox(height: 8),
//                 Text('Scanned at: ${HistoryPage._formatWhen(createdAt)}'),
//                 if (confidencePct != null) ...[
//                   const SizedBox(height: 8),
//                   Text('Confidence: $confidencePct%'),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }





import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'history_service.dart';
import 'map_history_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // track which cards are expanded
  final Set<String> _expanded = {};
  final _svc = HistoryService();

  Future<void> _deleteScan(HistoryItem it) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete scan?'),
        content: const Text('This will permanently remove the scan from your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _svc.deleteScan(uid: user.uid, id: it.id);
      _expanded.remove(it.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to see your scan history')),
      );
    }
    final svc = HistoryService();
  

    

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
         
    actions: [
      IconButton(
        tooltip: 'Open map',
        icon: const Icon(Icons.map, color: Colors.white),
        onPressed: () {
          final uid = FirebaseAuth.instance.currentUser!.uid;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MapHistoryPage(uid: uid)),
          );
        },
      ),
      const SizedBox(width: 4),
    ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          const Positioned(top: -60, right: -40, child: _DecorativeCircle(size: 200, opacity: 0.18)),
          const Positioned(bottom: -50, left: -30, child: _DecorativeCircle(size: 260, opacity: 0.14)),

          SafeArea(
            child: StreamBuilder<List<HistoryItem>>(
              stream: svc.streamScans(user.uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load history:\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                // inside HistoryPage build():
 


                final items = (snap.data ?? const []);
                if (items.isEmpty) return const _EmptyState();

                // Group by local date (yyyy-mm-dd)
                final groups = _groupByDate(items);
                final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: dates.length,
                  itemBuilder: (context, gi) {
                    final dateKey = dates[gi];
                    final list = groups[dateKey]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DateHeader(text: _prettyDate(dateKey)),
                        const SizedBox(height: 8),
                        ...List.generate(list.length, (i) {
                          final it = list[i];
                          final expanded = _expanded.contains(it.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HistoryCard(
                              it: it,
                              expanded: expanded,
                              onToggle: () {
                                setState(() {
                                  if (expanded) {
                                    _expanded.remove(it.id);
                                  } else {
                                    _expanded.add(it.id);
                                  }
                                });
                              },
                              onOpen: () => _openDetail(context, it),
                              onDelete: () => _deleteScan(it), 
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, HistoryItem it) {
    final pct = it.confidence != null ? (it.confidence! * 100).round() : null;
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => _ImagePreviewPage(
          heroTag: 'scan_${it.id}',
          imageB64: it.imageB64,
          label: it.label,
          confidencePct: pct,
          createdAt: it.createdAt,
          geo: it.geo,
          locName: it.locName,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  static Map<String, List<HistoryItem>> _groupByDate(List<HistoryItem> items) {
    final map = <String, List<HistoryItem>>{};
    for (final it in items) {
      final d = it.createdAt;
      final key = '${d.year}-${_two(d.month)}-${_two(d.day)}';
      map.putIfAbsent(key, () => []).add(it);
    }
    return map;
  }

  static String _prettyDate(String yyyyMmDd) {
    final parts = yyyyMmDd.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yday = today.subtract(const Duration(days: 1));
    final dd = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == yday) return 'Yesterday';
    return '${_month(dd.month)} ${dd.day}, ${dd.year}';
  }

  static String _month(int m) =>
      ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];

  static String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.white, Colors.white70],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: Colors.white.withOpacity(0.12),
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off, size: 50, color: Colors.white),
              SizedBox(height: 10),
              Text('No scans yet',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              SizedBox(height: 6),
              Text('Scan a tea leaf to see results here.',
                  style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.it,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete, 
  });

  final HistoryItem it;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final pct = it.confidence != null ? (it.confidence! * 100).round() : null;
    final healthy = it.label.toLowerCase().contains('healthy');
    final color = healthy ? Colors.green : Colors.redAccent;

    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          GestureDetector(
            onTap: onOpen,
            child: AspectRatio(
              aspectRatio: 16 / 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'scan_${it.id}',
                    child: it.imageB64.isNotEmpty
                        ? Image.memory(
                            base64Decode(it.imageB64),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Icon(Icons.broken_image, size: 48)),
                          )
                        : const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                  // Top-right confidence chip
                  if (pct != null)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: _FrostedChip(
                        child: Row(
                          children: [
                            const Icon(Icons.speed_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('$pct%',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Title row + time (always visible)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(healthy ? Icons.eco : Icons.warning_amber_rounded, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _HistoryPageState._formatWhen(it.createdAt),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.delete, size: 20),
        onSelected: (v) {
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
              ],
            ),
          ),

          // Collapsible extra info
          AnimatedCrossFade(
            crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 180),
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (it.geo != null) ...[
                    _LocationPill(
                      title: it.locName ??
                          '${it.geo!.latitude.toStringAsFixed(5)}, ${it.geo!.longitude.toStringAsFixed(5)}',
                      onTap: () => _openMaps(it.geo!.latitude, it.geo!.longitude),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text('Source: ${it.source}',
                          style: TextStyle(color: Colors.grey.shade800, fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (pct != null)
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, size: 16, color: Colors.black54),
                        const SizedBox(width: 6),
                        Text('Confidence: $pct%',
                            style: TextStyle(color: Colors.grey.shade800, fontSize: 12.5)),
                      ],
                    ),
                ],
              ),
            ),
            secondChild: const SizedBox(height: 2),
          ),
           const SizedBox(height:1),

          // See more / See less
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical:1)),
              child: Text(expanded ? 'See less' : 'See more'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedChip extends StatelessWidget {
  const _FrostedChip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(color: Colors.grey.shade800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new, size: 16, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewPage extends StatelessWidget {
  const _ImagePreviewPage({
    required this.heroTag,
    required this.imageB64,
    required this.label,
    required this.createdAt,
    this.confidencePct,
    this.geo,
    this.locName,
  });

  final String heroTag;
  final String imageB64;
  final String label;
  final int? confidencePct;
  final DateTime createdAt;
  final GeoPoint? geo;
  final String? locName;

  @override
  Widget build(BuildContext context) {
    final color = label.toLowerCase().contains('healthy') ? Colors.green : Colors.redAccent;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Detail')),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Hero(
              tag: heroTag,
              child: imageB64.isNotEmpty
                  ? Image.memory(
                      base64Decode(imageB64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 48)),
                    )
                  : const Center(child: Icon(Icons.broken_image, size: 48)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  backgroundColor: color.withOpacity(0.12),
                  avatar: Icon(label.toLowerCase().contains('healthy') ? Icons.eco : Icons.warning_amber_rounded,
                      color: color, size: 18),
                  label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                Text('Scanned at: ${_HistoryPageState._formatWhen(createdAt)}'),
                if (confidencePct != null) ...[
                  const SizedBox(height: 8),
                  Text('Confidence: $confidencePct%'),
                ],
                if (geo != null) ...[
                  const SizedBox(height: 12),
                  _LocationPill(
                    title: locName ?? '${geo!.latitude.toStringAsFixed(5)}, ${geo!.longitude.toStringAsFixed(5)}',
                    onTap: () => _openMaps(geo!.latitude, geo!.longitude),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Launch Google Maps to the given lat/lng
Future<void> _openMaps(double lat, double lng) async {
  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  await launchUrl(url, mode: LaunchMode.externalApplication);
}
