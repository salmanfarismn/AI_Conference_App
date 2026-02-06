
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

class GlassNavbar extends StatelessWidget implements PreferredSizeWidget {
  final Future<void> Function() onLogout;
  final String userName;

  const GlassNavbar({
    super.key,
    required this.onLogout,
    this.userName = 'User',
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // Increased blur
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0E1C).withOpacity(0.5), // Lighter (lower opacity)
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Section: Main Identity
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main Logo
                    SvgPicture.asset(
                      'assets/images/uccicon26.svg',
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 16),
                    // Title
                    const Text(
                      'UCC ICON 2026',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),

                // Right Section: Affiliations & Actions
                 Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     // TCS Logo (Partner) - White
                    SvgPicture.asset(
                      'assets/images/TCS-logo-white.svg',
                      height: 95, 
                      fit: BoxFit.contain,
                       colorFilter: const ColorFilter.mode(
                        Colors.white, 
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 24),

                     // Motto Emblem (College/Institution)
                    Image.asset(
                      'assets/images/motto-emblem.png',
                      height: 40,
                       fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 24),
                    
                    // Vertical Separator for Logout
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    const SizedBox(width: 16),

                     // Logout
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                      onPressed: onLogout,
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ],
            ),

          ),
        ),
      ),
    );
  }


  @override
  Size get preferredSize => const Size.fromHeight(80);
}
