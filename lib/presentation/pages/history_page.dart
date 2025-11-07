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
import '../../core/localization/app_localizations.dart';
import 'home_page.dart';
import 'map_history_page.dart';
import 'profile_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // track which cards are expanded
  final Set<String> _expanded = {};
  final _svc = HistoryService();
  
  // Date search state
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSearchActive = false;

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        _isSearchActive = true;
        // If end date is before start date, clear it
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final initialDate = _endDate ?? _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _isSearchActive = true;
      });
    }
  }

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        final selectedDate = DateTime(picked.year, picked.month, picked.day);
        _startDate = selectedDate;
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _isSearchActive = true;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _isSearchActive = false;
    });
  }

  List<HistoryItem> _filterByDate(List<HistoryItem> items) {
    if (!_isSearchActive || (_startDate == null && _endDate == null)) {
      return items;
    }

    return items.where((item) {
      final itemDate = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      
      if (_startDate != null && _endDate != null) {
        // Date range search
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
        // Check if item date is within range (inclusive)
        return (itemDate.isAtSameMomentAs(start) || itemDate.isAfter(start)) &&
               (itemDate.isAtSameMomentAs(end) || itemDate.isBefore(end));
      } else if (_startDate != null) {
        // Single date or start date only
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        return itemDate.isAtSameMomentAs(start);
      } else if (_endDate != null) {
        // End date only - show all items up to and including end date
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
        return itemDate.isAtSameMomentAs(end) || itemDate.isBefore(end);
      }
      return true;
    }).toList();
  }

  Future<void> _deleteScan(HistoryItem it) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.deleteScan ?? 'Delete scan?');
          },
        ),
        content: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.permanentlyRemoveScan ?? 'This will permanently remove the scan from your history.');
          },
        ),
        actions: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(localizations?.cancel ?? 'Cancel'),
              );
            },
          ),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(localizations?.delete ?? 'Delete'),
              );
            },
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _svc.deleteScan(uid: user.uid, id: it.id);
      _expanded.remove(it.id);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations?.scanDeleted ?? 'Scan deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations?.deleteFailed ?? 'Delete failed'}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Scaffold(
            body: Center(child: Text(localizations?.pleaseLoginToSeeHistory ?? 'Please log in to see your scan history')),
          );
        },
      );
    }
    final svc = HistoryService();
  

    

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.history ?? 'History',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
                  final localizations = AppLocalizations.of(context);
                  return Center(
                    child: Text(
                      '${localizations?.failedToLoadHistory ?? 'Failed to load history'}:\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                // inside HistoryPage build():
 


                final items = (snap.data ?? const []);
                final filteredItems = _filterByDate(items);
                
                if (filteredItems.isEmpty) {
                  if (_isSearchActive) {
                    return _EmptySearchState(
                      onClear: _clearSearch,
                      onPickStart: _pickStartDate,
                      onPickEnd: _pickEndDate,
                      onPickSingle: _pickSingleDate,
                      startDate: _startDate,
                      endDate: _endDate,
                    );
                  }
                  return const _EmptyState();
                }

                // Group by local date (yyyy-mm-dd)
                final groups = _groupByDate(filteredItems);
                final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));

                return Column(
                  children: [
                    // Search bar
                    _DateSearchBar(
                      startDate: _startDate,
                      endDate: _endDate,
                      isActive: _isSearchActive,
                      onPickStart: _pickStartDate,
                      onPickEnd: _pickEndDate,
                      onPickSingle: _pickSingleDate,
                      onClear: _clearSearch,
                    ),
                    // History list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: dates.length,
                  itemBuilder: (context, gi) {
                    final dateKey = dates[gi];
                    final list = groups[dateKey]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DateHeader(text: _prettyDate(dateKey, context)),
                        const SizedBox(height: 6),
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
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final localizations = AppLocalizations.of(context);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BottomNavigationBar(
                backgroundColor: Colors.white,
                elevation: 12,
                selectedItemColor: Colors.green,
                unselectedItemColor: Colors.black54,
                type: BottomNavigationBarType.fixed,
                currentIndex: 1,
                items: [
                  BottomNavigationBarItem(icon: const Icon(Icons.home), label: localizations?.home ?? 'Home'),
                  BottomNavigationBarItem(icon: const Icon(Icons.history), label: localizations?.history ?? 'History'),
                  BottomNavigationBarItem(icon: const Icon(Icons.map), label: localizations?.map ?? 'Map'),
                  BottomNavigationBarItem(icon: const Icon(Icons.person), label: localizations?.profile ?? 'Profile'),
                ],
            onTap: (index) {
              final user = FirebaseAuth.instance.currentUser;
              if (index == 0) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              } else if (index == 2) {
                if (user != null) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => MapHistoryPage(uid: user.uid)),
                  );
                } else {
                  final localizations = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(localizations?.pleaseLoginToViewMap ?? 'Please log in to view map')),
                  );
                }
              } else if (index == 3) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              }
            },
              ),
            ),
          );
        },
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

  static String _prettyDate(String yyyyMmDd, BuildContext? context) {
    final parts = yyyyMmDd.split('-');
    final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yday = today.subtract(const Duration(days: 1));
    final dd = DateTime(d.year, d.month, d.day);
    final localizations = context != null ? AppLocalizations.of(context) : null;
    if (dd == today) return localizations?.today ?? 'Today';
    if (dd == yday) return localizations?.yesterday ?? 'Yesterday';
    return '${_month(dd.month, localizations)} ${dd.day}, ${dd.year}';
  }

  static String _month(int m, AppLocalizations? localizations) {
    if (localizations == null) {
      return ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
    }
    final months = [
      localizations.jan, localizations.feb, localizations.mar, localizations.apr,
      localizations.may, localizations.jun, localizations.jul, localizations.aug,
      localizations.sep, localizations.oct, localizations.nov, localizations.dec
    ];
    return months[m-1];
  }

  static String _formatWhen(DateTime dt, BuildContext? context) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final localizations = context != null ? AppLocalizations.of(context) : null;
    if (diff.inMinutes < 1) return localizations?.justNow ?? 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} ${localizations?.minAgo ?? 'min ago'}';
    if (diff.inDays < 1) return '${diff.inHours} ${localizations?.hrAgo ?? 'hr ago'}';
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
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_toggle_off,
                    size: 60,
                    color: Colors.green.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.noScansYet ?? 'No scans yet',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.scanTeaLeafToSeeResults ?? 'Scan a tea leaf to see results here.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.onClear,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPickSingle,
    this.startDate,
    this.endDate,
  });

  final VoidCallback onClear;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onPickSingle;
  final DateTime? startDate;
  final DateTime? endDate;

  String _formatDate(DateTime? date, BuildContext? context) {
    if (date == null) return '';
    final localizations = context != null ? AppLocalizations.of(context) : null;
    return '${_month(date.month, localizations)} ${date.day}, ${date.year}';
  }

  String _month(int m, AppLocalizations? localizations) {
    if (localizations == null) {
      return ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
    }
    final months = [
      localizations.jan, localizations.feb, localizations.mar, localizations.apr,
      localizations.may, localizations.jun, localizations.jul, localizations.aug,
      localizations.sep, localizations.oct, localizations.nov, localizations.dec
    ];
    return months[m-1];
  }

  @override
  Widget build(BuildContext context) {
    String dateRangeText = '';
    if (startDate != null && endDate != null) {
      if (startDate!.year == endDate!.year &&
          startDate!.month == endDate!.month &&
          startDate!.day == endDate!.day) {
        dateRangeText = _formatDate(startDate, context);
      } else {
        dateRangeText = '${_formatDate(startDate, context)} - ${_formatDate(endDate, context)}';
      }
    } else if (startDate != null) {
      final localizations = AppLocalizations.of(context);
      dateRangeText = '${localizations?.from ?? 'From'} ${_formatDate(startDate, context)}';
    } else if (endDate != null) {
      final localizations = AppLocalizations.of(context);
      dateRangeText = '${localizations?.until ?? 'Until'} ${_formatDate(endDate, context)}';
    }

    return Column(
      children: [
        _DateSearchBar(
          startDate: startDate,
          endDate: endDate,
          isActive: true,
          onPickStart: onPickStart,
          onPickEnd: onPickEnd,
          onPickSingle: onPickSingle,
          onClear: onClear,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Card(
                elevation: 8,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.95),
                        Colors.white.withOpacity(0.85),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search_off,
                          size: 60,
                          color: Colors.orange.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations?.noScansFound ?? 'No scans found',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                          );
                        },
                      ),
                      if (dateRangeText.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Date: $dateRangeText',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return ElevatedButton.icon(
                            onPressed: onClear,
                            icon: const Icon(Icons.clear, size: 18),
                            label: Text(localizations?.clearSearch ?? 'Clear search'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateSearchBar extends StatelessWidget {
  const _DateSearchBar({
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onPickSingle,
    required this.onClear,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onPickSingle;
  final VoidCallback onClear;

  String _formatDate(DateTime? date, BuildContext? context) {
    final localizations = context != null ? AppLocalizations.of(context) : null;
    if (date == null) return localizations?.select ?? 'Select';
    return '${_month(date.month, localizations)} ${date.day}, ${date.year}';
  }

  String _month(int m, AppLocalizations? localizations) {
    if (localizations == null) {
      return ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
    }
    final months = [
      localizations.jan, localizations.feb, localizations.mar, localizations.apr,
      localizations.may, localizations.jun, localizations.jul, localizations.aug,
      localizations.sep, localizations.oct, localizations.nov, localizations.dec
    ];
    return months[m-1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations?.searchByDate ?? 'Search by Date',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    );
                  },
                ),
              ),
              if (isActive)
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Single date button
              Expanded(
                child: _DateButton(
                  icon: Icons.event,
                  label: startDate != null && endDate != null &&
                      startDate!.year == endDate!.year &&
                      startDate!.month == endDate!.month &&
                      startDate!.day == endDate!.day
                      ? _formatDate(startDate, context)
                      : (AppLocalizations.of(context)?.date ?? 'Date'),
                  onPressed: onPickSingle,
                  isActive: startDate != null && endDate != null &&
                      startDate!.year == endDate!.year &&
                      startDate!.month == endDate!.month &&
                      startDate!.day == endDate!.day,
                ),
              ),
              const SizedBox(width: 8),
              // Start date button
              Expanded(
                child: _DateButton(
                  icon: Icons.arrow_forward,
                  label: _formatDate(startDate, context),
                  onPressed: onPickStart,
                  isActive: startDate != null,
                ),
              ),
              const SizedBox(width: 8),
              // End date button
              Expanded(
                child: _DateButton(
                  icon: Icons.arrow_back,
                  label: _formatDate(endDate, context),
                  onPressed: onPickEnd,
                  isActive: endDate != null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.3)
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? Colors.white.withOpacity(0.6)
                  : Colors.white.withOpacity(0.3),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section
            GestureDetector(
              onTap: onOpen,
              child: AspectRatio(
                aspectRatio: 3 / 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
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
                                  Container(
                                    color: Colors.grey.shade200,
                                    child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                                  ),
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                            ),
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    // Top-right confidence chip
                    if (pct != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _FrostedChip(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.speed_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '$pct%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  ),
                ),
              ),
            ),

            // Content section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          healthy ? Icons.eco : Icons.warning_amber_rounded,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Builder(
                              builder: (context) {
                                return Text(
                                  _HistoryPageState._formatWhen(it.createdAt, context),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Collapsible extra info
                  AnimatedCrossFade(
                    crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
                    firstChild: Padding(
                      padding: const EdgeInsets.only(top: 8),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 14, color: Colors.grey.shade700),
                                    const SizedBox(width: 6),
                                    Builder(
                                      builder: (context) {
                                        final localizations = AppLocalizations.of(context);
                                        return Text(
                                          '${localizations?.source ?? 'Source'}: ${it.source}',
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                if (pct != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.analytics_outlined, size: 14, color: Colors.grey.shade700),
                                      const SizedBox(width: 6),
                                      Builder(
                                        builder: (context) {
                                          final localizations = AppLocalizations.of(context);
                                          return Text(
                                            '${localizations?.confidence ?? 'Confidence'}: $pct%',
                                            style: TextStyle(
                                              color: Colors.grey.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),

                  // See more / See less button
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: onToggle,
                      icon: Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                      ),
                      label: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            expanded ? (localizations?.showLess ?? 'Show less') : (localizations?.showMore ?? 'Show more'),
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.place, size: 14, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new, size: 14, color: Colors.blue.shade700),
            ],
          ),
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
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(localizations?.scanDetail ?? 'Scan Detail');
          },
        ),
      ),
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
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text('${localizations?.scannedAt ?? 'Scanned at'}: ${_HistoryPageState._formatWhen(createdAt, context)}');
                  },
                ),
                if (confidencePct != null) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text('${localizations?.confidence ?? 'Confidence'}: $confidencePct%');
                    },
                  ),
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
