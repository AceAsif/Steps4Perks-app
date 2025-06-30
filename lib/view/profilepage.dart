import 'package:flutter/material.dart';

class ProfilePageContent extends StatelessWidget {
  const ProfilePageContent({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.07,
            vertical: screenHeight * 0.04,
          ),
          child: Column(
            children: [
              // Profile avatar
              CircleAvatar(
                radius: screenWidth * 0.12,
                backgroundImage: AssetImage('assets/profile.png'),
                backgroundColor: Colors.transparent, // Optional fallback
              ),
              SizedBox(height: screenHeight * 0.02),

              // User name
              Text(
                'Asif',
                style: TextStyle(
                  fontSize: screenWidth * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Email
              Text(
                'asif@gmail.com',
                style: TextStyle(
                  fontSize: screenWidth * 0.045,
                  color: Colors.black87,
                ),
              ),

              SizedBox(height: screenHeight * 0.04),

              // Options
              _buildOptionTile(
                context,
                icon: Icons.star,
                label: 'Referral Boosters',
                onTap: () {},
              ),
              _buildOptionTile(
                context,
                icon: Icons.mail_outline,
                label: 'Contact Support',
                onTap: () {},
              ),
              _buildOptionTile(
                context,
                icon: Icons.info_outline,
                label: 'About Steps4Perks',
                onTap: () {},
              ),

                SizedBox(height: screenHeight * 0.025),

              // Logout button
              ElevatedButton(
                onPressed: () {
                  // TODO: Add logout logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      children: [
        ListTile(
          leading: Icon(icon, size: screenWidth * 0.07, color: Colors.black),
          title: Text(
            label,
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        Divider(thickness: 1),
      ],
    );
  }
}