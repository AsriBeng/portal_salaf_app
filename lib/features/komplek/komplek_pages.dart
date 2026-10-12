import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/akses.dart';
import '../../models/komplek.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import 'komplek_forms.dart';
import 'komplek_repository.dart';

/// Lencana putra (biru) / putri (merah muda).
class GenderPill extends StatelessWidget {
  const GenderPill(this.gender, {super.key});

  final String gender;

  @override
  Widget build(BuildContext context) {
    return gender == 'P'
        ? const Pill(label: 'Putri', color: Color(0xFFBE185D), background: Color(0xFFFCE7F3))
        : const Pill(label: 'Putra', color: AppColors.biru, background: AppColors.biruMuda);
  }
}

/// Batang keterisian kamar.
class Keterisian extends StatelessWidget {
  const Keterisian({super.key, required this.terisi, required this.kapasitas});

  final int terisi;
  final int kapasitas;

  @override
  Widget build(BuildContext context) {
    final rasio = kapasitas == 0 ? 0.0 : (terisi / kapasitas).clamp(0.0, 1.0);
    final penuh = terisi >= kapasitas;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: rasio,
        minHeight: 8,
        backgroundColor: AppColors.hijauMuda,
        color: penuh ? AppColors.oranye : AppColors.hijau,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daftar komplek
// ---------------------------------------------------------------------------

class KomplekListPage extends ConsumerStatefulWidget {
  const KomplekListPage({super.key});

  @override
  ConsumerState<KomplekListPage> createState() => _KomplekListPageState();
}

class _KomplekListPageState extends ConsumerState<KomplekListPage> {
  String? _gender;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final daftar = ref.watch(komplekListProvider(_gender));

    return Scaffold(
      appBar: AppBar(title: const Text('Komplek & Kamar')),
      floatingActionButton: user.bisaKelolaKamar
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (await KomplekForm.buka(context) == true) {
                  ref.invalidate(komplekListProvider);
                  if (context.mounted) showPesan(context, 'Komplek berhasil ditambahkan.');
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Komplek'),
            )
          : null,
      body: Column(
        children: [
          if (user.isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _FilterGender(value: _gender, onChanged: (g) => setState(() => _gender = g)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(komplekListProvider(_gender).future),
              child: daftar.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(komplekListProvider)),
                data: (items) => items.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        EmptyView(
                          icon: Icons.apartment_rounded,
                          judul: 'Belum ada komplek',
                          isi: 'Tambahkan komplek terlebih dahulu, lalu isi kamar-kamarnya.',
                        ),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _KomplekCard(komplek: items[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterGender extends StatelessWidget {
  const _FilterGender({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (v, label) in [(null, 'Semua'), ('L', 'Putra'), ('P', 'Putri')]) ...[
          ChoiceChip(
            label: Text(label),
            selected: value == v,
            onSelected: (_) => onChanged(v),
            showCheckmark: false,
            selectedColor: AppColors.hijau,
            labelStyle: TextStyle(color: value == v ? Colors.white : AppColors.teks, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _KomplekCard extends StatelessWidget {
  const _KomplekCard({required this.komplek});

  final Komplek komplek;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/komplek/${komplek.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.hijauMuda, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.apartment_rounded, color: AppColors.hijau),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            komplek.nama,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GenderPill(komplek.gender),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${angka(komplek.jumlahKamar)} kamar · kapasitas ${angka(komplek.totalKapasitas)} santri',
                      style: text.bodySmall?.copyWith(color: AppColors.teks2),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.teks2),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail komplek (daftar kamar)
// ---------------------------------------------------------------------------

class KomplekDetailPage extends ConsumerWidget {
  const KomplekDetailPage({super.key, required this.id});

  final int id;

  Future<void> _hapus(BuildContext context, WidgetRef ref, Komplek komplek) async {
    final ok = await konfirmasi(
      context,
      judul: 'Hapus komplek?',
      isi: 'Komplek "${komplek.nama}" akan dihapus. Komplek yang masih memiliki kamar tidak dapat dihapus.',
      ya: 'Hapus',
      bahaya: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(komplekRepositoryProvider).hapusKomplek(komplek.id);
      ref.invalidate(komplekListProvider);
      if (context.mounted) {
        showPesan(context, 'Komplek dihapus.');
        context.kembali();
      }
    } on ApiException catch (e) {
      if (context.mounted) showPesan(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final detail = ref.watch(komplekDetailProvider(id));
    final komplek = detail.value;

    void segarkan() {
      ref.invalidate(komplekDetailProvider(id));
      ref.invalidate(komplekListProvider);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(komplek?.nama ?? 'Komplek'),
        actions: [
          if (komplek != null && user.bisaKelolaKamar)
            PopupMenuButton<String>(
              onSelected: (aksi) async {
                if (aksi == 'ubah') {
                  if (await KomplekForm.buka(context, komplek: komplek) == true) segarkan();
                } else if (context.mounted) {
                  _hapus(context, ref, komplek);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ubah', child: Text('Ubah komplek')),
                PopupMenuItem(value: 'hapus', child: Text('Hapus komplek')),
              ],
            ),
        ],
      ),
      floatingActionButton: komplek != null && user.bisaKelolaKamar
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (await KamarForm.buka(context, komplekId: komplek.id) == true) {
                  segarkan();
                  if (context.mounted) showPesan(context, 'Kamar berhasil ditambahkan.');
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Kamar'),
            )
          : null,
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: segarkan),
        data: (komplek) {
          final terisi = komplek.kamar.fold<int>(0, (s, k) => s + (k.terisi ?? 0));
          final kapasitas = komplek.kamar.fold<int>(0, (s, k) => s + k.kapasitas);

          return RefreshIndicator(
            onRefresh: () => ref.refresh(komplekDetailProvider(id).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GenderPill(komplek.gender),
                          const Spacer(),
                          Text(
                            '${angka(terisi)} / ${angka(kapasitas)} terisi',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Keterisian(terisi: terisi, kapasitas: kapasitas),
                      if (komplek.keterangan != null && komplek.keterangan!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(komplek.keterangan!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teks2)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (komplek.kamar.isEmpty)
                  const EmptyView(
                    icon: Icons.meeting_room_outlined,
                    judul: 'Belum ada kamar',
                    isi: 'Tambahkan kamar beserta kapasitasnya.',
                  )
                else
                  for (final kamar in komplek.kamar) ...[
                    _KamarTile(kamar: kamar),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KamarTile extends StatelessWidget {
  const _KamarTile({required this.kamar});

  final Kamar kamar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final terisi = kamar.terisi ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/kamar/${kamar.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.meeting_room_rounded, color: AppColors.hijau, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(kamar.nama, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                  if (kamar.penuh)
                    const Pill(label: 'Penuh', color: AppColors.oranye, background: AppColors.oranyeMuda)
                  else
                    Text('sisa ${kamar.sisa}', style: text.labelMedium?.copyWith(color: AppColors.hijau, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Keterisian(terisi: terisi, kapasitas: kamar.kapasitas),
              const SizedBox(height: 6),
              Text('$terisi dari ${kamar.kapasitas} santri', style: text.bodySmall?.copyWith(color: AppColors.teks2)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail kamar (daftar penghuni)
// ---------------------------------------------------------------------------

class KamarDetailPage extends ConsumerWidget {
  const KamarDetailPage({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final detail = ref.watch(kamarDetailProvider(id));
    final kamar = detail.value?.kamar;
    final headers = ref.read(apiClientProvider).authHeaders;

    void segarkan() {
      ref.invalidate(kamarDetailProvider(id));
      if (kamar != null) ref.invalidate(komplekDetailProvider(kamar.komplekId));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(kamar?.nama ?? 'Kamar'),
        actions: [
          if (kamar != null && user.bisaKelolaKamar)
            PopupMenuButton<String>(
              onSelected: (aksi) async {
                if (aksi == 'ubah') {
                  if (await KamarForm.buka(context, komplekId: kamar.komplekId, kamar: kamar) == true) segarkan();
                  return;
                }
                if (!context.mounted) return;
                final ok = await konfirmasi(
                  context,
                  judul: 'Hapus kamar?',
                  isi: 'Kamar "${kamar.nama}" akan dihapus. Kamar yang masih dihuni tidak dapat dihapus.',
                  ya: 'Hapus',
                  bahaya: true,
                );
                if (!ok) return;
                try {
                  await ref.read(komplekRepositoryProvider).hapusKamar(kamar.id);
                  ref.invalidate(komplekDetailProvider(kamar.komplekId));
                  if (context.mounted) {
                    showPesan(context, 'Kamar dihapus.');
                    context.kembali();
                  }
                } on ApiException catch (e) {
                  if (context.mounted) showPesan(context, e.message, error: true);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'ubah', child: Text('Ubah kamar')),
                PopupMenuItem(value: 'hapus', child: Text('Hapus kamar')),
              ],
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: segarkan),
        data: (d) {
          final text = Theme.of(context).textTheme;
          final terisi = d.kamar.terisi ?? d.penghuni.length;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(kamarDetailProvider(id).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.kamar.komplek?.nama ?? '', style: text.bodySmall?.copyWith(color: AppColors.teks2)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('$terisi', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text(' / ${d.kamar.kapasitas} santri', style: text.bodyMedium?.copyWith(color: AppColors.teks2)),
                          const Spacer(),
                          if (terisi >= d.kamar.kapasitas)
                            const Pill(label: 'Penuh', color: AppColors.oranye, background: AppColors.oranyeMuda)
                          else
                            Pill(label: 'Sisa ${d.kamar.kapasitas - terisi} tempat'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Keterisian(terisi: terisi, kapasitas: d.kamar.kapasitas),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Penghuni',
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                  child: d.penghuni.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                          child: Text(
                            'Belum ada santri di kamar ini. Penempatan kamar diatur dari data santri.',
                            style: text.bodyMedium?.copyWith(color: AppColors.teks2),
                          ),
                        )
                      : Column(
                          children: [
                            for (final s in d.penghuni)
                              ListTile(
                                onTap: () => context.push('/santri/${s.id}'),
                                leading: UserAvatar(inisial: s.inisial, fotoUrl: s.fotoUrl, headers: headers, size: 40),
                                title: Text(s.namaLengkap, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('NIS ${s.nis}'),
                                trailing: const Icon(Icons.chevron_right_rounded),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
