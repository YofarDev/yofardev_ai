import 'package:flutter/material.dart';

class AppIconButton extends StatelessWidget {
  final Function() onPressed;
  final IconData icon;
  
  const AppIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 20,
        ),
      ),
    );
  }
}
