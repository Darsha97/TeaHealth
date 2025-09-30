// import 'package:flutter/material.dart';
// import 'package:teascan_app/presentation/pages/login_page.dart';
// import 'home_page.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 20),
//     )..repeat(reverse: true); // loop back-and-forth

//     Future.delayed(const Duration(seconds: 3), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const LoginPage()),
//       );
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             AnimatedBuilder(
//               animation: _controller,
//               builder: (context, child) {
//                 return ShaderMask(
//                   shaderCallback: (bounds) {
//                     return LinearGradient(
//                       colors: [Colors.green, Colors.white, Colors.green],
//                       stops: [
//                         0.0,
//                         _controller.value,
//                         1.0,
//                       ],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ).createShader(bounds);
//                   },
//                   child: Icon(Icons.eco, size: 80, color: Colors.green),
//                 );
//               },
//             ),
//             const SizedBox(height: 16),
//             const Text('TeaHealth',
//                 style: TextStyle(
//                     fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
//             const SizedBox(height: 8),
//             const Text(
//               'Your Tea Companion',
//               textAlign: TextAlign.center,
//               style: TextStyle(fontSize: 16, color: Colors.black87),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }




import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:teascan_app/presentation/pages/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<Offset> _titleSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _titleSlide = Tween<Offset>(begin: const Offset(0, .15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Soft floating blob
  Widget _blob(Color color, double size, Offset offset, double opacity) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          final t = _controller.value;
          final dx = 8 * math.sin(t * 2 * math.pi);
          final dy = 6 * math.cos(t * 2 * math.pi);
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: opacity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [color.withOpacity(.8), color.withOpacity(.3)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1db954), Color(0xFF128a3a)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative blobs
          _blob(Colors.white, 220, const Offset(-40, -30), 0.18),
          _blob(Colors.white, 180, const Offset(260, 80), 0.14),
          _blob(Colors.white, 260, const Offset(-70, 520), 0.12),

          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing leaf
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final t = _controller.value;
                        final scale = 1 + 0.06 * math.sin(t * 2 * math.pi);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft glow ring
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(.25),
                                    blurRadius: 42,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: scale,
                              child: ShaderMask(
                                shaderCallback: (r) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFFE3F8E9)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(r),
                                blendMode: BlendMode.srcATop,
                                child: const CircleAvatar(
                                  radius: 46,
                                  backgroundColor: Colors.white24,
                                  child: Icon(Icons.eco, size: 48, color: Colors.green),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // Title with slight slide + fade
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _fadeIn,
                        child: ShaderMask(
                          shaderCallback: (r) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFE9FFE9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(r),
                          blendMode: BlendMode.srcATop,
                          child: Text(
                            'TeaHealth',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Text(
                      'Your Tea Companion',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Thin progress line
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (_, __) {
                          return LinearProgressIndicator(
                            minHeight: 6,
                            value: (_controller.value * .7) + .3, // avoid looking empty
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom subtle watermark leaf
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: .8,
              child: Text(
                'Loading TeaHealth...',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(.9),
                  letterSpacing: .4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
