import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../logic/avatar/avatar_cubit.dart';
import '../../../logic/avatar/avatar_state.dart';
import '../../../utils/app_utils.dart';

class ScaledAvatarItem extends StatefulWidget {
  final String path;
  final double itemX;
  final double itemY;
  final bool display;
  final double opacity;

  const ScaledAvatarItem({
    super.key,
    required this.path,
    required this.itemX,
    required this.itemY,
    this.display = true,
    this.opacity = 1,
  });

  @override
  _ScaledAvatarItemState createState() => _ScaledAvatarItemState();
}

class _ScaledAvatarItemState extends State<ScaledAvatarItem> {
  double? _itemOriginalHeight;
  double? _itemOriginalWidth;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() async {
    final ByteData baseImg = await rootBundle.load(widget.path);
    final ui.Image decodedBaseImage =
        await decodeImageFromList(baseImg.buffer.asUint8List());
    setState(() {
      _itemOriginalHeight = decodedBaseImage.height.toDouble();
      _itemOriginalWidth = decodedBaseImage.width.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarCubit, AvatarState>(
      builder: (BuildContext context, AvatarState state) {
        if (state.status != AvatarStatus.ready ||
            _itemOriginalHeight == null ||
            _itemOriginalWidth == null) return Container();
        return Positioned(
          left: widget.itemX * state.scaleFactor,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              AppUtils().getInvertedY(
                itemY: widget.itemY,
                itemHeight: _itemOriginalHeight!,
                scaleFactor: state.scaleFactor,
                baseOriginalHeight: state.baseOriginalHeight,
              ),
          child: widget.display
              ? Image.asset(
                  widget.path,
                  fit: BoxFit.cover,
                  width: _itemOriginalWidth! * state.scaleFactor,
                  height: _itemOriginalHeight! * state.scaleFactor,
                  opacity: AlwaysStoppedAnimation<double>(widget.opacity),
                )
              : Container(),
        );
      },
    );
  }
}
