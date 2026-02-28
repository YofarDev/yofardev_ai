import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../res/app_colors.dart';
import '../../res/app_constants.dart';

class PickerButtons extends StatelessWidget {
  final Function(File? file) onImageSelected;

  const PickerButtons({super.key, required this.onImageSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!kIsWeb)
          _GlassmorphicIconButton(
            icon: Icons.image_outlined,
            onPressed: _onGalleryPickerButtonPressed,
          ),
        const SizedBox(width: 8),
        _GlassmorphicIconButton(
          icon: Icons.camera_alt_outlined,
          onPressed: _onTakePhotoButtonPressed,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _onTakePhotoButtonPressed() async {
    await ImagePicker()
        .pickImage(
          source: ImageSource.camera,
          imageQuality: 75,
          maxWidth: AppConstants.pickedImageMaxWidth,
          maxHeight: AppConstants.pickedImageMaxHeight,
        )
        .then((XFile? photo) {
          _onImageSelected(photo);
        });
  }

  void _onGalleryPickerButtonPressed() async {
    final ImagePicker picker = ImagePicker();
    await picker
        .pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
          maxWidth: AppConstants.pickedImageMaxWidth,
          maxHeight: AppConstants.pickedImageMaxHeight,
        )
        .then((XFile? photo) {
          _onImageSelected(photo);
        });
  }

  void _onImageSelected(XFile? file) async {
    if (file == null) {
      onImageSelected(null);
      return;
    }
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = path.basename(file.path);
    final File savedImage = File('${appDir.path}/$fileName');
    await File(file.path).copy(savedImage.path);
    onImageSelected(savedImage);
  }
}

class _GlassmorphicIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassmorphicIconButton({required this.icon, required this.onPressed});

  @override
  State<_GlassmorphicIconButton> createState() =>
      _GlassmorphicIconButtonState();
}

class _GlassmorphicIconButtonState extends State<_GlassmorphicIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.glassSurface.withValues(alpha: _isPressed ? 0.2 : 0.1),
              AppColors.glassSurface.withValues(
                alpha: _isPressed ? 0.15 : 0.05,
              ),
            ],
          ),
          border: Border.all(
            color: AppColors.glassBorder.withValues(
              alpha: _isPressed ? 0.5 : 0.3,
            ),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: _isPressed
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: _isPressed ? 12 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(
          widget.icon,
          size: 22,
          color: _isPressed
              ? AppColors.primary
              : AppColors.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
