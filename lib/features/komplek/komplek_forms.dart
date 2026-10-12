import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../models/komplek.dart';
import '../../shared/ui.dart';
import '../auth/auth_controller.dart';
import 'komplek_repository.dart';

/// Pilihan putra/putri (dipakai admin).
class PilihGender extends StatelessWidget {
  const PilihGender({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'L', label: Text('Putra'), icon: Icon(Icons.male_rounded)),
        ButtonSegment(value: 'P', label: Text('Putri'), icon: Icon(Icons.female_rounded)),
      ],
      selected: {?value},
      emptySelectionAllowed: true,
      onSelectionChanged: (s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
    );
  }
}

/// Form tambah / ubah komplek. Mengembalikan true jika tersimpan.
class KomplekForm extends ConsumerStatefulWidget {
  const KomplekForm({super.key, this.komplek});

  final Komplek? komplek;

  static Future<bool?> buka(BuildContext context, {Komplek? komplek}) => bukaSheet<bool>(
        context,
        judul: komplek == null ? 'Tambah komplek' : 'Ubah komplek',
        child: KomplekForm(komplek: komplek),
      );

  @override
  ConsumerState<KomplekForm> createState() => _KomplekFormState();
}

class _KomplekFormState extends ConsumerState<KomplekForm> {
  final _form = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.komplek?.nama);
  late final _keterangan = TextEditingController(text: widget.komplek?.keterangan);
  String? _gender;
  bool _loading = false;
  Map<String, List<String>> _errors = const {};

  @override
  void dispose() {
    _nama.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _errors = const {});
    if (!_form.currentState!.validate()) return;

    final admin = ref.read(authControllerProvider).value?.isAdmin ?? false;
    if (widget.komplek == null && admin && _gender == null) {
      showPesan(context, 'Pilih komplek putra atau putri.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(komplekRepositoryProvider).simpanKomplek(
            id: widget.komplek?.id,
            nama: _nama.text.trim(),
            keterangan: _keterangan.text.trim(),
            gender: widget.komplek == null && admin ? _gender : null,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      _form.currentState!.validate();
      if (e.errors.isEmpty) showPesan(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(authControllerProvider).value?.isAdmin ?? false;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.komplek == null && admin) ...[
            PilihGender(value: _gender, onChanged: (g) => setState(() => _gender = g)),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _nama,
            autofocus: widget.komplek == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama komplek', prefixIcon: Icon(Icons.apartment_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama komplek wajib diisi.' : _errors['nama']?.first,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _keterangan,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(labelText: 'Keterangan (opsional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),
          TombolSimpan(loading: _loading, onPressed: _simpan),
        ],
      ),
    );
  }
}

/// Form tambah / ubah kamar. Mengembalikan true jika tersimpan.
class KamarForm extends ConsumerStatefulWidget {
  const KamarForm({super.key, required this.komplekId, this.kamar});

  final int komplekId;
  final Kamar? kamar;

  static Future<bool?> buka(BuildContext context, {required int komplekId, Kamar? kamar}) => bukaSheet<bool>(
        context,
        judul: kamar == null ? 'Tambah kamar' : 'Ubah kamar',
        child: KamarForm(komplekId: komplekId, kamar: kamar),
      );

  @override
  ConsumerState<KamarForm> createState() => _KamarFormState();
}

class _KamarFormState extends ConsumerState<KamarForm> {
  final _form = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.kamar?.nama);
  late final _kapasitas = TextEditingController(text: widget.kamar?.kapasitas.toString());
  bool _loading = false;
  Map<String, List<String>> _errors = const {};

  @override
  void dispose() {
    _nama.dispose();
    _kapasitas.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    setState(() => _errors = const {});
    if (!_form.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ref.read(komplekRepositoryProvider).simpanKamar(
            id: widget.kamar?.id,
            komplekId: widget.komplekId,
            nama: _nama.text.trim(),
            kapasitas: int.parse(_kapasitas.text),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      _form.currentState!.validate();
      if (e.errors.isEmpty) showPesan(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nama,
            autofocus: widget.kamar == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama kamar',
              hintText: 'contoh: Kamar 1 / Al-Fatih',
              prefixIcon: Icon(Icons.meeting_room_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama kamar wajib diisi.' : _errors['nama']?.first,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _kapasitas,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Kapasitas',
              suffixText: 'santri',
              prefixIcon: Icon(Icons.people_outline_rounded),
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1) return 'Kapasitas minimal 1.';
              return _errors['kapasitas']?.first;
            },
          ),
          const SizedBox(height: 20),
          TombolSimpan(loading: _loading, onPressed: _simpan),
        ],
      ),
    );
  }
}
