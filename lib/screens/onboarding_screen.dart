import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/onboarding1.jpg",
      "title": "Grow Your Earnings",
      "body": "Get matched with nearby customers looking for your skills.",
    },
    {
      "image": "assets/images/onboarding2.jpg",
      "title": "Work On Your Schedule",
      "body": "Accept the jobs you want, when you want.",
    },
    {
      "image": "assets/images/onboarding3.jpg",
      "title": "Join Trusted Fixers",
      "body": "Deliver great service and build your reputation.",
    },
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    final targetWidthPx = (mq.size.width * mq.devicePixelRatio).round();
    for (var item in onboardingData) {
      final provider = ResizeImage(
        AssetImage(item["image"]!),
        width: targetWidthPx,
      );
      precacheImage(provider, context);
    }
  }

  void nextPage() {
    if (currentPage < onboardingData.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF212121),
        body: PageView.builder(
          controller: _controller,
          itemCount: onboardingData.length,
          onPageChanged: (index) => setState(() => currentPage = index),
          itemBuilder: (context, index) {
            final item = onboardingData[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.transparent, Color(0xFF212121)],
                          stops: [0.1, 0.9],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Builder(
                        builder: (context) {
                          final mq = MediaQuery.of(context);
                          final targetWidthPx =
                              (mq.size.width * mq.devicePixelRatio).round();
                          return Image(
                            image: ResizeImage(
                              AssetImage(item["image"]!),
                              width: targetWidthPx,
                            ),
                            height: mq.size.height * 0.55,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                            gaplessPlayback: true,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 80,
                      right: 20,
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 50,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Spacer(flex: 1),
                        Column(
                          children: [
                            Text(
                              item["title"]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item["body"]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(flex: 2),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                onboardingData.length,
                                (dotIndex) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: currentPage == dotIndex ? 20 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: currentPage == dotIndex
                                        ? const Color(0xFFF1592A)
                                        : const Color(0xFFDEDEDE),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: nextPage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1592A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  index == onboardingData.length - 1
                                      ? 'Get Started'
                                      : 'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
