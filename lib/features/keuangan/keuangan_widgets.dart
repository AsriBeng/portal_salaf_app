import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/keuangan.dart';
import '../../shared/rupiah_input.dart';
import '../../shared/widgets.dart';

String isoTanggal(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

class StatusTagihanPill extends StatelessWidget {
  const StatusTagihanPill(this.status, {super.key});

  final StatusTagihan status;

  @override
  Widget build(BuildContext context) => switch (status) {
        StatusTagihan.lunas => const Pill(label: 'Lunas'),
        StatusTagihan.dicicil => const Pill(label: 'Dicicil', color: AppColors.oranye, background: AppColors.oranyeMuda),
        StatusTagihan.belumBayar => const Pill(label: 'Belum bayar', color: AppColors.merah, background: AppColors.merahMuda),
      };
}

class StatusPembayaranPill extends StatelessWidget {
  const StatusPembayaranPill(this.status, {super.key});

  final StatusPembayaran status;

  @override
  Widget build(BuildContext context) => switch (status) {
        StatusPembayaran.disetujui => const Pill(label: 'Disetujui'),
        StatusPembayaran.menunggu => const Pill(label: 'Menunggu', color: AppColors.oranye, background: AppColors.oranyeMuda),
        StatusPembayaran.ditolak => const Pill(label: 'Ditolak', color: AppColors.merah, background: AppColors.merahMuda),
      };
}

/// Kartu tagihan di daftar.
class TagihanCard extends StatelessWidget {
  const TagihanCard({super.key, required this.tagihan, required this.onTap, this.tampilSantri = true});

  final Tagihan tagihan;
  final VoidCallback onTap;
  final bool tampilSantri;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = tagihan;
    final rasio = t.nominal == 0 ? 1.0 : (t.terbayar / t.nominal).clamp(0.0, 1.0);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tampilSantri && t.santri != null)
                          Text(
                            '${t.santri!.namaLengkap} · ${t.santri!.nis}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium?.copyWith(color: AppColors.teks2, fontWeight: FontWeight.w600),
                          ),
                        Text(t.judul, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusTagihanPill(t.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.lunas ? rupiah(t.nominal) : 'Sisa ${rupiah(t.sisa)}',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: t.lunas ? AppColors.hijau : AppColors.teks,
                      ),
                    ),
                  ),
                  if (t.jatuhTempo != null && !t.lunas)
                    Text(
                      'Jatuh tempo ${tanggal(t.jatuhTempo)}',
                      style: text.labelSmall?.copyWith(
                        color: t.lewatJatuhTempo ? AppColors.merah : AppColors.teks2,
                        fontWeight: t.lewatJatuhTempo ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                ],
              ),
              if (t.status == StatusTagihan.dicicil) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: rasio,
                    minHeight: 6,
                    backgroundColor: AppColors.oranyeMuda,
                    color: AppColors.oranye,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Terbayar ${rupiah(t.terbayar)} dari ${rupiah(t.nominal)}',
                  style: text.labelSmall?.copyWith(color: AppColors.teks2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris pembayaran di daftar.
class PembayaranCard extends StatelessWidget {
  const PembayaranCard({super.key, required this.pembayaran, required this.onTap});

  final Pembayaran pembayaran;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = pembayaran;
    final santri = p.tagihan?.santri;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: p.sumber == 'santri' ? AppColors.biruMuda : AppColors.hijauMuda,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  p.sumber == 'santri' ? Icons.receipt_rounded : Icons.payments_rounded,
                  color: p.sumber == 'santri' ? AppColors.biru : AppColors.hijau,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      santri?.namaLengkap ?? 'Santri',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${p.tagihan?.judul ?? 'Tagihan'} · ${tanggal(p.tanggalBayar)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: AppColors.teks2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(rupiah(p.nominal), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  StatusPembayaranPill(p.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Field nominal rupiah dengan pemisah ribuan otomatis.
class RupiahField extends StatelessWidget {
  const RupiahField({
    super.key,
    required this.controller,
    this.label = 'Nominal',
    this.maks,
    this.helper,
    this.errorServer,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final int? maks;
  final String? helper;
  final String? errorServer;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [RupiahInputFormatter()],
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        helperText: helper,
        helperMaxLines: 2,
      ),
      validator: (v) {
        final n = bacaRupiah(v ?? '');
        if (n == null || n < 1) return '$label wajib diisi.';
        if (maks != null && n > maks!) return 'Maksimal ${rupiah(maks)}.';
        return errorServer;
      },
    );
  }
}

/// Field tanggal dengan kalender.
class TanggalField extends StatelessWidget {
  const TanggalField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.wajib = true,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool wajib;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2015),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365)),
          helpText: label,
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: !wajib && value != null
              ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => onChanged(null))
              : null,
        ),
        child: Text(
          value == null ? 'Pilih tanggal' : DateFormat('d MMMM yyyy', 'id_ID').format(value!),
          style: TextStyle(color: value == null ? AppColors.teks2 : AppColors.teks),
        ),
      ),
    );
  }
}

/// Baris label-nilai sederhana.
class InfoBaris extends StatelessWidget {
  const InfoBaris(this.label, this.nilai, {super.key, this.tebal = false, this.warna});

  final String label;
  final String nilai;
  final bool tebal;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: text.bodyMedium?.copyWith(color: AppColors.teks2))),
          Expanded(
            child: Text(
              nilai,
              textAlign: TextAlign.right,
              style: text.bodyMedium?.copyWith(fontWeight: tebal ? FontWeight.w800 : FontWeight.w600, color: warna),
            ),
          ),
        ],
      ),
    );
  }
}
