import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/santri.dart';
import 'widgets.dart';

/// Daftar yang memuat halaman berikutnya otomatis saat digulir ke bawah.
///
/// Ganti [reloadKey] (misalnya saat filter berubah) untuk memuat ulang dari halaman 1.
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.reloadKey,
    required this.muat,
    required this.itemBuilder,
    required this.kosong,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96),
    this.separator = 10,
  });

  final Object? reloadKey;
  final Future<Halaman<T>> Function(int page) muat;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget kosong;

  /// Widget di atas daftar (ikut tergulir), misalnya ringkasan.
  final Widget? header;
  final EdgeInsets padding;
  final double separator;

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final _scroll = ScrollController();
  final List<T> _items = [];
  int _page = 0;
  bool _adaLagi = true;
  bool _loading = false;
  String? _error;
  int _versi = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _lanjut();
    });
    muatUlang();
  }

  @override
  void didUpdateWidget(covariant PagedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) muatUlang();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Muat ulang dari halaman pertama (dipanggil juga dari luar lewat GlobalKey).
  Future<void> muatUlang() async {
    final versi = ++_versi;
    setState(() {
      _items.clear();
      _page = 0;
      _adaLagi = true;
      _error = null;
      _loading = true;
    });
    await _ambil(1, versi);
  }

  Future<void> _lanjut() async {
    if (_loading || !_adaLagi) return;
    setState(() => _loading = true);
    await _ambil(_page + 1, _versi);
  }

  Future<void> _ambil(int page, int versi) async {
    try {
      final h = await widget.muat(page);
      if (!mounted || versi != _versi) return;
      setState(() {
        _items.addAll(h.items);
        _page = h.page;
        _adaLagi = h.adaLagi;
      });
    } on ApiException catch (e) {
      if (mounted && versi == _versi) setState(() => _error = e.message);
    } finally {
      if (mounted && versi == _versi) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) return ErrorView(message: _error!, onRetry: muatUlang);

    return RefreshIndicator(
      onRefresh: muatUlang,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: (widget.header == null ? 0 : 1) + (_items.isEmpty ? 1 : _items.length) + (_adaLagi && _items.isNotEmpty ? 1 : 0),
        itemBuilder: (context, i) {
          if (widget.header != null) {
            if (i == 0) return widget.header!;
            i--;
          }
          if (_items.isEmpty) return Padding(padding: const EdgeInsets.only(top: 48), child: widget.kosong);
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
            );
          }
          return Padding(
            padding: EdgeInsets.only(bottom: widget.separator),
            child: widget.itemBuilder(context, _items[i]),
          );
        },
      ),
    );
  }
}
