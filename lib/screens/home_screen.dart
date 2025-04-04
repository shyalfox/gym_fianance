import 'package:flutter/material.dart';
import 'gym_homepage.dart';
import 'finance_homepage.dart';
import '../widgets/custom_card.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(title: const Text('Gym & Finance'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomCard(
              title: 'Gym',
              icon: Icons.fitness_center,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GymHomePage()),
                );
              },
            ),
            const SizedBox(height: 20),
            CustomCard(
              title: 'Finance',
              icon: Icons.account_balance_wallet_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FinanceHomePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await authService.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                  // ignore: empty_catches
                } catch (e) {}
              },
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }
}
