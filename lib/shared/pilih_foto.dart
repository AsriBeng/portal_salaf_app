import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import 'ui.dart';

/// Hasil pilihan foto profil: foto baru, atau permintaan menghapus foto.
sealed class PilihanFoto {
  const PilihanFoto();
}

class FotoBaru extends PilihanFoto {
  const FotoBaru(this.file);

  final UploadFile file;
}

class HapusFoto extends PilihanFoto {
  const HapusFoto();
}

/// Lembar pilihan: kamera, galeri, atau hapus foto. Foto dikecilkan (maks. 800 px) sebelum diunggah.
Future<PilihanFoto?> pilihFotoProfil(BuildContext context, {required bool adaFoto}) async {
  final pilihan = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(children: [
        if (!kIsWeb)
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Ambil dari kamera'),
            onTap: () => Navigator.pop(context, 'kamera'),
          ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Pilih dari galeri'),
          onTap: () => Navigator.pop(context, 'galeri'),
        ),
        if (adaFoto)
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: AppColors.merah),
            title: const Text('Hapus foto', style: TextStyle(color: AppColors.merah)),
            onTap: () => Navigator.pop(context, 'hapus'),
          ),
      ]),
    ),
  );
  if (pilihan == null) return null;
  if (pilihan == 'hapus') return const HapusFoto();

  UploadFile? file;
  if (kIsWeb) {
    final f = await FilePicker.pickFile(type: FileType.image);
    if (f != null) file = UploadFile(f.name, await f.readAsBytes());
  } else {
    final x = await ImagePicker().pickImage(
      source: pilihan == 'kamera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (x != null) file = UploadFile(x.name, await x.readAsBytes());
  }
  if (file == null) return null;

  if (file.bytes.length > 2 * 1024 * 1024) {
    if (context.mounted) showPesan(context, 'Ukuran foto maksimal 2 MB.', error: true);
    return null;
  }
  return FotoBaru(file);
}
