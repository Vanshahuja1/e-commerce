import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: Colors.red.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get in Touch',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re here to help you with any questions or concerns',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Contact Information Cards
            _buildContactCard(
              icon: Icons.phone,
              title: 'Phone',
              subtitle: '011-23263939',
              color: Colors.green,
              onTap: () => _launchPhone('01123263939'),
            ),

            const SizedBox(height: 16),

            _buildContactCard(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'support@kanwarji.com',
              color: Colors.blue,
              onTap: () => _launchEmail('support@kanwarji.com'),
            ),

            const SizedBox(height: 16),

            _buildContactCard(
              icon: Icons.location_on,
              title: 'Address',
              subtitle:
                  '1972-73, main road, near parathey wali gali, Chandni Chowk, New Delhi, Delhi 110006',
              color: Colors.orange,
              onTap: () => _launchMaps(),
            ),

            const SizedBox(height: 16),

            // Company Info Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.red.shade400),
                      const SizedBox(width: 12),
                      const Text(
                        'About Kanwarji',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kanwarji is your trusted partner for authentic, handcrafted food products that celebrate the rich taste of Indian tradition. We bring you the finest quality snacks and sweets, lovingly prepared using time-honored recipes and the purest ingredients.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Social Media Section ✅ Fixed Brackets Here
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.share, color: Colors.red.shade400),
                      const SizedBox(width: 12),
                      const Text(
                        'Follow Us',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialButton(
                        icon: Icons.facebook,
                        label: 'Facebook',
                        onTap: () {
                          Navigator.pushNamed(context, '/contact-us');
                        },
                      ),
                      _buildSocialButton(
                        icon: Icons.camera_alt,
                        label: 'Instagram',
                        onTap: () => _launchSocial(
                            'https://www.instagram.com/kanwarji_1850'),
                      ),
                      _buildSocialButton(
                        icon: Icons.play_circle_fill,
                        label: 'YouTube',
                        onTap: () {
                          Navigator.pushNamed(context, '/contact-us');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        onTap: onTap,
        trailing: onTap != null
            ? Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400)
            : null,
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.red.shade400, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final url = 'tel:$phone';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchEmail(String email) async {
    final url = 'mailto:$email?subject=Support Inquiry';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchMaps() async {
    final url = 'https://maps.app.goo.gl/VrjW16Z2P2ZsDCKT7';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _launchSocial(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
