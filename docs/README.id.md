# Windows Printer Sharing Fix — Bahasa Indonesia

<p align="center">
  <img src="assets/hero-v2.png" alt="Windows Printer Sharing Fix" width="100%">
</p>

<p align="center"><a href="../README.md">English</a> · <strong>Bahasa Indonesia</strong></p>

Windows Printer Sharing Fix adalah TUI PowerShell berbasis **diagnosis dulu** untuk menangani masalah printer sharing Windows tanpa langsung menerapkan banyak tweak atau menurunkan keamanan sebagai langkah awal.

Tool memeriksa lapisan masalah yang sebenarnya — Print Spooler, profil jaringan, SMB/RPC, Windows Protected Print, Point and Print, driver printer, atau kompatibilitas perangkat lama — lalu menyediakan perbaikan sekecil mungkin yang relevan.

Tool ini cocok untuk troubleshooting kasus printer sharing yang kadang muncul bersama error seperti `0x0000011b`, `0x00000709`, atau `0x00000bc4`, tetapi kode error tidak pernah dianggap sebagai bukti tunggal bahwa satu tweak tertentu pasti benar.

> **Versi stable:** TUI Windows PowerShell yang dijalankan melalui `FixPrinter.bat`. Frontend OpenTUI masih eksperimen dan tidak termasuk release stable.

## Mulai cepat

1. Buka [release terbaru](https://github.com/man612/Windows-Printer-Sharing-Fix/releases/latest).
2. Download `Windows-Printer-Sharing-Fix-vX.Y.Z.zip`, lalu extract.
3. Double-click `FixPrinter.bat`.
4. Izinkan UAC Administrator.
5. Pilih **Diagnosis PC ini** terlebih dahulu.
6. Gunakan Perbaikan Aman, Lanjutan, atau Legacy hanya jika hasil diagnosis memang mengarah ke sana.

Tidak perlu installer. Baseline kompatibilitasnya adalah Windows PowerShell 5.1.

## Cara kerja v4

```text
Diagnosis
   |
Cari lapisan masalah yang gagal
   |
Pilih perbaikan paling kecil yang relevan
   |
Verifikasi printer / koneksi
   |
Restore perubahan terkelola jika perlu
```

### Perbaikan Aman

Tidak boleh menurunkan proteksi keamanan printer/jaringan. Contohnya restart Spooler, membersihkan antrean macet dengan konfirmasi, mengaktifkan rule File and Printer Sharing hanya untuk Private/Domain, mengubah satu profil jaringan yang dipilih ke Private, dan menjalankan service Network Discovery.

### Perbaikan Kompatibilitas

Untuk kasus yang sudah punya bukti diagnosis, misalnya fallback RPC Named Pipes, Point and Print sementara untuk satu percobaan koneksi, pemeriksaan Windows Protected Print, atau reset satu koneksi printer jaringan.

### Kompatibilitas Legacy

Pilihan terakhir untuk perangkat lama yang benar-benar membutuhkan SMB1 client, insecure guest SMB, atau LAN Manager lama. Tindakan berisiko membutuhkan konfirmasi eksplisit.

Tool sengaja tidak mengotomatisasi remote logon dengan password kosong.

## Data lokal dan privasi

Mulai v4.0.2, preference bahasa, log, dan snapshot restore disimpan di:

```text
%LOCALAPPDATA%\WindowsPrinterSharingFix\
├── backups\
├── logs\
├── exports\
└── language.cfg
```

Repo Git tidak lagi menjadi dirty hanya karena bahasa diganti atau tool dijalankan. Preference dan backup v4 lama dari folder repo akan dimigrasikan jika memungkinkan.

Tidak ada telemetry atau upload laporan otomatis. Test UNC hanya mengakses host/printer yang memang kamu minta untuk diuji.

## Dokumentasi

- [Quick Start](QUICKSTART.md)
- [Arsitektur](ARCHITECTURE.md)
- [JSON diagnosis terstruktur](DIAGNOSTIC-JSON.md)
- [Schema JSON diagnosis](diagnosis.schema.json)
- [Klasifikasi event PrintService](PRINTSERVICE-EVENTS.md)
- [Bukti sumber kebijakan printer](POLICY-SOURCES.md)
- [Klasifikasi driver printer](DRIVER-CLASSIFICATION.md)
- [Korelasi lapisan troubleshooting](CORRELATION.md)
- [Diagnosis SMB/RPC modern](MODERN-SMB-RPC.md)
- [Integritas dan provenance release](RELEASE-INTEGRITY.md)
- [Verifikasi test page terpandu](TEST-PAGE-VERIFICATION.md)
- [Contoh diagnosis yang sudah disanitasi](examples/README.md)
- [Test Matrix](TEST-MATRIX.md)
- [Hasil pengujian nyata](REAL-WORLD-RESULTS.md)
- [Security Policy](../SECURITY.md)
- [Panduan kontribusi](../CONTRIBUTING.md)
- [Roadmap](../ROADMAP.md)
- [Changelog](../CHANGELOG.md)

## Kontribusi dan bantuan

Bug report, hasil pengujian kompatibilitas, dokumentasi, dan PR yang fokus sangat terbuka. Setelah menjalankan Diagnosis, menu **Alat dan Log** dapat mengekspor diagnosis terakhir sebagai JSON sanitized. Tetap periksa file sebelum dibagikan publik.

Gunakan [Issue Forms](https://github.com/man612/Windows-Printer-Sharing-Fix/issues/new/choose) untuk bug/kompatibilitas dan [Discussions](https://github.com/man612/Windows-Printer-Sharing-Fix/discussions) untuk pertanyaan atau berbagi setup yang berhasil.

Jika tool ini berguna, star di GitHub membantu pengguna Windows lain menemukannya.

Kembali ke [README English](../README.md).
