import 'package:flutter/material.dart';
import 'package:flutter_project/wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> introData = [
    {
      "title": "Discover something new",
      "subtitle": "Special new arrivals just for you",
      "image": "assets/images/ws_img1.jpeg",
    },
    {
      "title": "Update trendy outfit",
      "subtitle": "Favorite brands and hottest trends",
      "image": "assets/images/ws_img2.webp",
    },
    {
      "title": "Explore your true style",
      "subtitle": "Relax and let us bring the style to you",
      "image": "assets/images/ws_img3.webp",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: introData.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    const SizedBox(height: 80),
                    Text(
                      introData[index]["title"]!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      introData[index]["subtitle"]!,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      height: 350,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                          image: AssetImage(introData[index]["image"]!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              introData.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: _currentPage == index ? 12 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      _currentPage == index
                          ? const Color.fromARGB(255, 255, 255, 255)
                          : Colors.white54,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('onboarding_seen', true);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                );
              },
              child: const Text("Shopping now"),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
      backgroundColor: const Color.fromARGB(255, 134, 104, 104),
    );
  }
}
