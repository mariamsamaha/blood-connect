import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() {
                    isLastPage = index == 2; // last page index
                  });
                },
                children: [
                  buildPage(
                    image: Icons.bloodtype,
                    title: 'Welcome to Blood Connect',
                    subtitle:
                        'Connect donors and recipients in real-time, anytime.',
                  ),
                  buildPage(
                    image: Icons.location_on,
                    title: 'Find Nearby Donors',
                    subtitle:
                        'Get notified instantly when blood is needed near you.',
                  ),
                  buildPage(
                    image: Icons.chat,
                    title: 'Request & Donate',
                    subtitle:
                        'Send requests, chat with donors, and save lives.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      3,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width:
                            _controller.hasClients &&
                                _controller.page?.round() == index
                            ? 24
                            : 8,
                        decoration: BoxDecoration(
                          color:
                              _controller.hasClients &&
                                  _controller.page?.round() == index
                              ? Colors.red
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _controller.jumpToPage(2),
                    child: const Text('SKIP'),
                  ),
                  isLastPage
                      ? ElevatedButton(
                          onPressed: () {
                            context.pushReplacement(
                              '/signup',
                            ); // your next screen
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('DONE'),
                        )
                      : ElevatedButton(
                          onPressed: () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('NEXT'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildPage({
    required IconData image,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(image, size: 120, color: Colors.red),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
