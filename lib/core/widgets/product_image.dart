import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Widget hiển thị ảnh sản phẩm: network image với emoji fallback.
/// Dùng ở mọi screen thay cho inline emoji code.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.emoji,
    this.size = 80,
    this.borderRadius = 12,
  });

  final String imageUrl;
  final String emoji;
  final double size;
  final double borderRadius;

  bool get _hasNetworkImage => imageUrl.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: AppColors.background,
        child: _hasNetworkImage ? _buildNetworkImage() : _buildEmoji(),
      ),
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => _buildEmoji(),
      errorWidget: (_, __, ___) => _buildEmoji(),
    );
  }

  Widget _buildEmoji() {
    return Center(
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}
