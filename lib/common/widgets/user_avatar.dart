import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;
  final double radius;
  final VoidCallback? onTap;
  final bool showEditIcon;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.username = "User",
    this.radius = 20,
    this.onTap,
    this.showEditIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.teal.shade100,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null
          ? Text(
        (username.isNotEmpty ? username[0] : "A").toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.teal,
          fontSize: radius * 0.8,
        ),
      )
          : null,
    );

    if (!showEditIcon) return avatar;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          avatar,
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            child: const Icon(Icons.edit, color: Colors.white, size: 20),
          )
        ],
      ),
    );
  }
}