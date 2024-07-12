import 'package:flutter/material.dart';

import '../../../res/app_constants.dart';
import 'scaled_avatar_item.dart';

class Clothes extends StatelessWidget {
  final String name;
  const Clothes({
    super.key,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final Cloth cloth =
        clothesList.firstWhere((Cloth element) => element.name == name);
    return ScaledAvatarItem(
      path: cloth.path,
      itemX: cloth.x,
      itemY: cloth.y,
      opacity: cloth.opacity,
    );
  }

  List<Cloth> get clothesList => <Cloth>[
        Cloth(
          name: 'sunglasses',
          path: 'assets/avatar/accessories/sunglasses.png',
          x: AppConstants().sunglassesX,
          y: AppConstants().sunglassesY,
          opacity: 0.9,
        ),

        //  Cloth(
        //       name: 'pants',
        //       path: 'assets/clothes/pants.png',
        //       x: 0,
        //       y: 0,
        //     ),
        //     Cloth(
        //       name: 'shoes',
        //       path: 'assets/clothes/shoes.png',
        //       x: 0,
        //       y: 0,
        //     ),
      ];
}

class Cloth {
  String name;
  String path;
  double x;
  double y;
  double opacity;
  Cloth({
    required this.name,
    required this.path,
    required this.x,
    required this.y,
    this.opacity = 1,
  });
}
