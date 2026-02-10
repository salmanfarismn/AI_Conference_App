import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= 640;
  }
  
  static double contentWidth(BuildContext context) {
    // On mobile, take full width minus padding. On desktop, max 700px or 50%
    return isMobile(context) ? MediaQuery.of(context).size.width : 700;
  }
}
