import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Optional photo for a report: take one with the camera or pick from the
/// gallery, preview it, and remove it again.
///
/// Images are resized and compressed on the phone before upload, so
/// photos stay well under the 5 MB limit in the Storage rules and upload
/// quickly on campus Wi-Fi.
class PhotoPickerField extends StatelessWidget {
  const PhotoPickerField({
    super.key,
    required this.photo,
    required this.onChanged,
    this.enabled = true,
  });

  final File? photo;
  final ValueChanged<File?> onChanged;
  final bool enabled;

  Future<void> _choose(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 70,
      );
      if (picked != null) onChanged(File(picked.path));
    } on PlatformException catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn\'t open the camera or gallery. '
            'Check the app\'s permissions in Settings.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return OutlinedButton.icon(
        onPressed: enabled ? () => _choose(context) : null,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add a photo (optional)'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            photo!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              _RoundAction(
                icon: Icons.edit_outlined,
                tooltip: 'Change photo',
                onPressed: enabled ? () => _choose(context) : null,
              ),
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.close,
                tooltip: 'Remove photo',
                onPressed: enabled ? () => onChanged(null) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Colors.black54,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}
