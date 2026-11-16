-- =====================================================================
--  DATABASE : gpm_beth_eden
--  Aplikasi : Portal Jemaat GEREJA BETH EDEN (GPM Tihulale)
--  Mesin    : MySQL 8.0+ / MariaDB 10.5+ (InnoDB, utf8mb4)
--
--  Skema ini menggantikan seluruh data yang sekarang disimpan di
--  localStorage (kunci "gpm_*") pada script.js.
--
--  Catatan desain:
--   * Kolom id memakai VARCHAR(32) agar ID lama dari browser
--     (hasil uid() di script.js) bisa diimpor tanpa diubah.
--   * Foto & PDF disimpan sebagai LONGTEXT berisi data-URL (base64),
--     persis seperti format di aplikasi sekarang.
--   * Nominal rupiah memakai BIGINT (tanpa desimal).
--   * Password TIDAK disimpan polos: kolom salt + hash (PBKDF2).
-- =====================================================================

CREATE DATABASE IF NOT EXISTS gpm_beth_eden
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gpm_beth_eden;

SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================================
-- 1. MASTER & PENGATURAN
-- =====================================================================

CREATE TABLE sektor (
  nama VARCHAR(50) NOT NULL,
  PRIMARY KEY (nama)
) ENGINE=InnoDB;

INSERT INTO sektor (nama) VALUES
  ('Sektor Sion'), ('Sektor Galelia'), ('Sektor Ebenhaezer'),
  ('Sektor Getsemany'), ('Sektor Tiberias'), ('Sektor Betlehem');

-- Pengaturan key-value (JSON): profil, rekening, nomorcfg, sentralcfg
CREATE TABLE pengaturan (
  kunci      VARCHAR(60) NOT NULL,
  nilai      JSON        NOT NULL,
  updated_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (kunci)
) ENGINE=InnoDB;

INSERT INTO pengaturan (kunci, nilai) VALUES
  ('rekening',   JSON_OBJECT('bank','Bank Rakyat Indonesia (BRI)','no','0000000000000000','an','Panitia Pembangunan Gereja Beth Eden')),
  ('nomorcfg',   JSON_OBJECT('kode','GPM/JMT-BE')),
  ('sentralcfg', JSON_OBJECT('kas',75,'sentral',25)),
  ('profil',     JSON_OBJECT());   -- sejarah, visi, misi, struktur, strukturMajelis, dst.

-- =====================================================================
-- 2. AKUN & KEAMANAN
-- =====================================================================

CREATE TABLE users (
  id             VARCHAR(32)  NOT NULL,
  nama           VARCHAR(120) NOT NULL,
  username       VARCHAR(20)  NOT NULL,
  email          VARCHAR(150) NOT NULL,
  role           ENUM('admin','bendahara','ketua','sekretaris','adminsektor') NOT NULL,
  sektor         VARCHAR(50)  NULL,                       -- hanya untuk adminsektor
  status         ENUM('aktif','menunggu','nonaktif') NOT NULL DEFAULT 'menunggu',
  finance_access TINYINT(1)   NOT NULL DEFAULT 0,         -- akses Keuangan untuk Ketua
  salt           VARCHAR(64)  NOT NULL,
  hash           VARCHAR(128) NOT NULL,
  question       VARCHAR(150) NOT NULL,                   -- pertanyaan keamanan
  answer_hash    VARCHAR(128) NOT NULL,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_username (username),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_role (role, status),
  CONSTRAINT fk_users_sektor FOREIGN KEY (sektor) REFERENCES sektor (nama) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Pembatasan percobaan login (5x gagal -> kunci 60 detik), versi server
CREATE TABLE login_attempt (
  id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  identitas VARCHAR(150) NOT NULL,
  ip        VARCHAR(45)  NULL,
  berhasil  TINYINT(1)   NOT NULL DEFAULT 0,
  waktu     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_login_identitas (identitas, waktu)
) ENGINE=InnoDB;

CREATE TABLE auditlog (
  id        VARCHAR(32)  NOT NULL,
  waktu     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_nama VARCHAR(200) NOT NULL,                        -- "Nama (Peran)"
  aksi      VARCHAR(40)  NOT NULL,
  modul     VARCHAR(80)  NOT NULL,
  detail    TEXT         NULL,
  PRIMARY KEY (id),
  KEY idx_audit_waktu (waktu),
  KEY idx_audit_modul (modul, aksi)
) ENGINE=InnoDB;

-- =====================================================================
-- 3. KONTEN PUBLIK (beranda)
-- =====================================================================

CREATE TABLE agenda (
  id        VARCHAR(32)  NOT NULL,
  judul     VARCHAR(200) NOT NULL,
  kategori  VARCHAR(40)  NOT NULL,        -- Jadwal Ibadah / Hari Besar / Pembangunan / Pelayanan / Pengumuman
  waktu     VARCHAR(120) NOT NULL,        -- teks bebas, mis. "Minggu, 09.00 WIT"
  deskripsi TEXT         NULL,
  foto      LONGTEXT     NULL,
  urut      INT          NOT NULL DEFAULT 0,
  created_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE agenda_sektor (
  id         VARCHAR(32)  NOT NULL,
  judul      VARCHAR(200) NOT NULL,
  sektor     VARCHAR(50)  NULL,
  kategori   VARCHAR(40)  NOT NULL,
  waktu      VARCHAR(120) NOT NULL,
  deskripsi  TEXT         NULL,
  foto       LONGTEXT     NULL,
  tayang     ENUM('Ya','Tidak') NOT NULL DEFAULT 'Ya',
  status     ENUM('Draft','Menunggu','Disetujui','Ditolak') NOT NULL DEFAULT 'Draft',
  oleh       VARCHAR(120) NULL,           -- pembuat
  dibuat     DATE         NULL,
  oleh2      VARCHAR(120) NULL,           -- yang menyetujui/menolak
  tgl_setuju DATE         NULL,
  alasan     VARCHAR(300) NULL,
  PRIMARY KEY (id),
  KEY idx_agsek_status (status, tayang),
  CONSTRAINT fk_agsek_sektor FOREIGN KEY (sektor) REFERENCES sektor (nama) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE renungan (
  id      VARCHAR(32)  NOT NULL,
  tanggal DATE         NOT NULL,
  judul   VARCHAR(200) NOT NULL,
  ayat    VARCHAR(150) NOT NULL,
  teks    TEXT         NULL,              -- isi ayat
  isi     MEDIUMTEXT   NULL,
  doa     TEXT         NULL,
  penulis VARCHAR(120) NULL,
  PRIMARY KEY (id),
  KEY idx_renungan_tgl (tanggal)
) ENGINE=InnoDB;

CREATE TABLE warta (
  id         VARCHAR(32)  NOT NULL,
  tanggal    DATE         NOT NULL,
  judul      VARCHAR(200) NOT NULL,
  bacaan     VARCHAR(150) NULL,
  ibadah     TEXT         NULL,
  pengumuman TEXT         NULL,
  syukur     TEXT         NULL,
  kolekte    BIGINT UNSIGNED NULL,
  penulis    VARCHAR(120) NULL,
  PRIMARY KEY (id),
  KEY idx_warta_tgl (tanggal)
) ENGINE=InnoDB;

CREATE TABLE buletin (
  id        VARCHAR(32)  NOT NULL,
  tanggal   DATE         NOT NULL,
  judul     VARCHAR(150) NOT NULL,        -- edisi / periode
  deskripsi TEXT         NULL,
  status    ENUM('Terbit','Draf') NOT NULL DEFAULT 'Terbit',
  berkas    VARCHAR(255) NULL,            -- nama file PDF
  pdf       LONGTEXT     NOT NULL,        -- data-URL PDF (maks. 2 MB)
  PRIMARY KEY (id),
  KEY idx_buletin_status (status, tanggal)
) ENGINE=InnoDB;

CREATE TABLE foto_beranda (
  id   VARCHAR(32) NOT NULL,
  foto LONGTEXT    NOT NULL,
  ket  VARCHAR(255) NULL,
  urut INT         NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE foto_bangun (
  id   VARCHAR(32) NOT NULL,
  foto LONGTEXT    NOT NULL,
  ket  VARCHAR(255) NULL,
  urut INT         NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE panitia (
  id      VARCHAR(32)  NOT NULL,
  jabatan VARCHAR(120) NOT NULL,
  nama    VARCHAR(150) NOT NULL,
  urut    INT          NOT NULL DEFAULT 0,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE ibadah (
  id         VARCHAR(32)  NOT NULL,
  tanggal    DATE         NOT NULL,
  jam        TIME         NULL,
  tempat     VARCHAR(80)  NULL,
  tempat_lain VARCHAR(120) NULL,
  jenis      VARCHAR(60)  NOT NULL,       -- Tunas, Wadah Pelayanan Perempuan, ...
  unit       VARCHAR(80)  NULL,
  tema       VARCHAR(200) NULL,
  pelayan    VARCHAR(150) NULL,
  ket        TEXT         NULL,
  PRIMARY KEY (id),
  KEY idx_ibadah_tgl (tanggal, jam),
  KEY idx_ibadah_jenis (jenis)
) ENGINE=InnoDB;

-- =====================================================================
-- 4. DATA WARGA & SEKTOR
-- =====================================================================

CREATE TABLE warga (
  id         VARCHAR(32)  NOT NULL,
  nama       VARCHAR(150) NOT NULL,
  sektor     VARCHAR(50)  NOT NULL,
  kategori   ENUM('Kepala Keluarga','Istri','Janda','Duda','Pemuda','Anak') NOT NULL DEFAULT 'Kepala Keluarga',
  status     ENUM('Aktif','Pindah','Meninggal') NOT NULL DEFAULT 'Aktif',
  tgl_lahir  DATE         NULL,
  telp       VARCHAR(30)  NULL,
  alamat     TEXT         NULL,
  -- persetujuan Admin Utama atas input Admin Sektor
  apv        ENUM('Menunggu','Disetujui','Ditolak') NULL,
  apv_oleh   VARCHAR(120) NULL,
  apv_tgl    DATE         NULL,
  apv_alasan VARCHAR(300) NULL,
  oleh       VARCHAR(120) NULL,           -- pengisi (Admin Sektor)
  -- jejak perpindahan sektor
  pindah_dari VARCHAR(50) NULL,
  tgl_pindah  DATE        NULL,
  pindah_oleh VARCHAR(120) NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_warga_sektor (sektor, status),
  KEY idx_warga_nama (nama),
  KEY idx_warga_apv (apv),
  CONSTRAINT fk_warga_sektor FOREIGN KEY (sektor) REFERENCES sektor (nama) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pengajuan_pindah (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  warga_id     VARCHAR(32)  NOT NULL,
  dari         VARCHAR(50)  NOT NULL,
  tujuan       VARCHAR(50)  NOT NULL,
  alasan_pindah VARCHAR(300) NULL,
  oleh         VARCHAR(120) NOT NULL,
  tgl          DATE         NOT NULL,
  status       ENUM('Menunggu','Disetujui','Ditolak') NOT NULL DEFAULT 'Menunggu',
  alasan_tolak VARCHAR(300) NULL,
  PRIMARY KEY (id),
  KEY idx_pindah_status (status),
  CONSTRAINT fk_pindah_warga  FOREIGN KEY (warga_id) REFERENCES warga (id) ON DELETE CASCADE,
  CONSTRAINT fk_pindah_dari   FOREIGN KEY (dari)   REFERENCES sektor (nama) ON UPDATE CASCADE,
  CONSTRAINT fk_pindah_tujuan FOREIGN KEY (tujuan) REFERENCES sektor (nama) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE jurnal_sektor (
  id       VARCHAR(32) NOT NULL,
  sektor   VARCHAR(50) NOT NULL,
  tanggal  DATE        NOT NULL,
  aksi     ENUM('Baru','Diubah','Pindah Masuk','Pindah Keluar') NOT NULL,
  nama     VARCHAR(150) NOT NULL,
  lapor    TINYINT(1)  NOT NULL DEFAULT 0,
  lawan    VARCHAR(50) NULL,              -- sektor asal/tujuan
  warga_id VARCHAR(32) NULL,
  oleh     VARCHAR(120) NULL,
  PRIMARY KEY (id),
  KEY idx_jurnal_belum (sektor, lapor),
  CONSTRAINT fk_jurnal_sektor FOREIGN KEY (sektor) REFERENCES sektor (nama) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE laporan_sektor (
  id            VARCHAR(32) NOT NULL,
  sektor        VARCHAR(50) NOT NULL,
  oleh          VARCHAR(150) NULL,
  tanggal       DATE        NOT NULL,
  dibuat        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  catatan       TEXT        NULL,
  status        ENUM('Terkirim','Diterima') NOT NULL DEFAULT 'Terkirim',
  auto          TINYINT(1)  NOT NULL DEFAULT 0,   -- dibuat otomatis oleh sistem
  diterima_oleh VARCHAR(120) NULL,
  tgl_terima    DATE        NULL,
  PRIMARY KEY (id),
  KEY idx_lapsek_status (status, sektor),
  CONSTRAINT fk_lapsek_sektor FOREIGN KEY (sektor) REFERENCES sektor (nama) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE laporan_sektor_item (
  id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  laporan_id VARCHAR(32) NOT NULL,
  aksi      VARCHAR(20) NOT NULL,
  nama      VARCHAR(150) NOT NULL,
  lawan     VARCHAR(50) NULL,
  tanggal   DATE        NULL,
  warga_id  VARCHAR(32) NULL,
  sektor    VARCHAR(50) NULL,
  PRIMARY KEY (id),
  KEY idx_lapitem_laporan (laporan_id),
  CONSTRAINT fk_lapitem_laporan FOREIGN KEY (laporan_id) REFERENCES laporan_sektor (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE radar_sektor (
  sektor       VARCHAR(50) NOT NULL,
  kondisi      ENUM('Kondusif','Butuh Pendampingan','Intervensi Ketua Majelis Jemaat') NULL,
  isu          VARCHAR(300) NULL,
  tgl          DATE        NULL,
  status       ENUM('Menunggu','Disetujui','Ditolak') NULL,
  oleh         VARCHAR(120) NULL,
  setuju_oleh  VARCHAR(120) NULL,
  tgl_setuju   DATE        NULL,
  PRIMARY KEY (sektor),
  CONSTRAINT fk_radar_sektor FOREIGN KEY (sektor) REFERENCES sektor (nama) ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pastoral (
  id       VARCHAR(32)  NOT NULL,
  tanggal  DATE         NOT NULL,
  nama     VARCHAR(150) NOT NULL,         -- warga / keluarga yang dilayani
  sektor   VARCHAR(50)  NOT NULL,
  jenis    VARCHAR(60)  NOT NULL,         -- Kunjungan Rumah, Kedukaan, dst.
  catatan  MEDIUMTEXT   NOT NULL,
  tindak   TEXT         NULL,
  status   ENUM('Perlu Tindak Lanjut','Dalam Pendampingan','Selesai') NOT NULL DEFAULT 'Perlu Tindak Lanjut',
  oleh     VARCHAR(120) NULL,
  dibuat   DATE         NULL,
  PRIMARY KEY (id),
  KEY idx_pastoral_sektor (sektor, tanggal),
  KEY idx_pastoral_status (status)
) ENGINE=InnoDB;

-- =====================================================================
-- 5. SEKRETARIAT
-- =====================================================================

CREATE TABLE surat (
  id         VARCHAR(32)  NOT NULL,
  nomor      VARCHAR(80)  NOT NULL,
  nourut     INT UNSIGNED NULL,           -- penomoran otomatis
  nojenis    VARCHAR(10)  NULL,           -- SML / SKL
  notahun    SMALLINT UNSIGNED NULL,
  tanggal    DATE         NOT NULL,
  jenis      ENUM('Surat Masuk','Surat Keluar') NOT NULL,
  pihak      VARCHAR(200) NOT NULL,       -- pengirim / tujuan
  diterima   VARCHAR(120) NULL,
  kategori   VARCHAR(60)  NULL,
  perihal    VARCHAR(255) NULL,
  lampiran   VARCHAR(120) NULL,
  isi        MEDIUMTEXT   NULL,
  ket        TEXT         NULL,
  pdf        LONGTEXT     NULL,
  pdf_nama   VARCHAR(255) NULL,
  -- persetujuan Ketua
  status     ENUM('Menunggu','Disetujui','Ditolak') NOT NULL DEFAULT 'Menunggu',
  oleh       VARCHAR(120) NULL,
  tgl_setuju DATE         NULL,
  -- disposisi (surat masuk)
  disp_tujuan    VARCHAR(80)  NULL,
  disp_instruksi TEXT         NULL,
  disp_tenggat   DATE         NULL,
  disp_status    ENUM('Baru','Diproses','Selesai') NULL,
  disp_oleh      VARCHAR(120) NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_surat_nomor (nomor),
  KEY idx_surat_tgl (tanggal),
  KEY idx_surat_jenis (jenis, status),
  KEY idx_surat_nomorurut (nojenis, notahun, nourut)
) ENGINE=InnoDB;

CREATE TABLE sk (
  id         VARCHAR(32)  NOT NULL,
  nomor      VARCHAR(80)  NOT NULL,
  nourut     INT UNSIGNED NULL,
  nojenis    VARCHAR(10)  NULL,           -- SK
  notahun    SMALLINT UNSIGNED NULL,
  jenis      ENUM('Pengangkatan Panitia','Pengangkatan Pelayan') NOT NULL,
  nama       VARCHAR(200) NOT NULL,
  menimbang  TEXT NULL,
  mengingat  TEXT NULL,
  anggota    TEXT NULL,                   -- satu baris: Jabatan | Nama
  masa       VARCHAR(150) NULL,
  tanggal    DATE         NOT NULL,
  tempat     VARCHAR(100) NULL,
  sekretaris VARCHAR(120) NULL,
  status     VARCHAR(30)  NOT NULL DEFAULT 'Diterbitkan',
  oleh       VARCHAR(120) NULL,
  tgl_terbit DATE         NULL,
  tgl_revisi DATE         NULL,
  tgl_ttd    DATE         NULL,
  catatan    TEXT         NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sk_nomor (nomor),
  KEY idx_sk_tgl (tanggal)
) ENGINE=InnoDB;

CREATE TABLE register_jemaat (
  id       VARCHAR(32)  NOT NULL,
  jenis    ENUM('Baptis','Sidi','Pernikahan','Kematian') NOT NULL,
  regurut  INT UNSIGNED NOT NULL,
  noreg    VARCHAR(20)  NOT NULL,         -- BAP-001, SID-001, NIK-001, KMT-001
  nama     VARCHAR(150) NOT NULL,         -- (pernikahan: mempelai pria)
  nama2    VARCHAR(150) NULL,             -- mempelai wanita
  tgl_lahir DATE        NULL,
  tanggal  DATE         NOT NULL,
  tempat   VARCHAR(150) NULL,
  pelayan  VARCHAR(150) NULL,
  ayah     VARCHAR(150) NULL,
  ibu      VARCHAR(150) NULL,
  ayah_p   VARCHAR(150) NULL,
  ibu_p    VARCHAR(150) NULL,
  ayah_w   VARCHAR(150) NULL,
  ibu_w    VARCHAR(150) NULL,
  saksi1   VARCHAR(150) NULL,
  saksi2   VARCHAR(150) NULL,
  saksi_p1 VARCHAR(150) NULL,
  saksi_p2 VARCHAR(150) NULL,
  saksi_w1 VARCHAR(150) NULL,
  saksi_w2 VARCHAR(150) NULL,
  usia     SMALLINT UNSIGNED NULL,        -- khusus kematian
  ket      VARCHAR(300) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_register_noreg (jenis, regurut),
  KEY idx_register_tgl (tanggal),
  KEY idx_register_nama (nama)
) ENGINE=InnoDB;

CREATE TABLE mutasi (
  id      VARCHAR(32)  NOT NULL,
  tanggal DATE         NOT NULL,
  nama    VARCHAR(150) NOT NULL,
  jenis   ENUM('Pindah Masuk','Pindah Keluar') NOT NULL,
  sektor  VARCHAR(50)  NULL,
  asal    VARCHAR(150) NULL,              -- asal / tujuan jemaat
  alasan  VARCHAR(300) NULL,
  PRIMARY KEY (id),
  KEY idx_mutasi_tgl (tanggal),
  CONSTRAINT fk_mutasi_sektor FOREIGN KEY (sektor) REFERENCES sektor (nama) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE notulen (
  id       VARCHAR(32)  NOT NULL,
  jenis    VARCHAR(60)  NOT NULL,         -- Sidang Jemaat / Rapat Majelis Jemaat / Rapat Ketua Majelis Jemaat
  judul    VARCHAR(200) NOT NULL,
  tanggal  DATE         NOT NULL,
  tempat   VARCHAR(150) NULL,
  pimpinan VARCHAR(150) NULL,
  notulis  VARCHAR(150) NULL,
  peserta  TEXT         NULL,
  agenda   TEXT         NULL,
  isi      MEDIUMTEXT   NULL,
  PRIMARY KEY (id),
  KEY idx_notulen_tgl (tanggal)
) ENGINE=InnoDB;

CREATE TABLE notulen_keputusan (
  id         VARCHAR(32) NOT NULL,
  notulen_id VARCHAR(32) NOT NULL,
  teks       TEXT        NOT NULL,
  pj         VARCHAR(150) NULL,
  target     DATE        NULL,
  status     ENUM('Belum','Berjalan','Selesai') NOT NULL DEFAULT 'Belum',
  urut       INT         NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_kep_notulen (notulen_id),
  KEY idx_kep_status (status, target),
  CONSTRAINT fk_kep_notulen FOREIGN KEY (notulen_id) REFERENCES notulen (id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE program (
  id       VARCHAR(32)  NOT NULL,
  tahun    SMALLINT UNSIGNED NOT NULL,
  unit     VARCHAR(80)  NOT NULL,         -- seksi / komisi / sektor
  nama     VARCHAR(200) NOT NULL,
  target   VARCHAR(255) NULL,
  capaian  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  status   ENUM('Direncanakan','Berjalan','Selesai','Tertunda') NOT NULL DEFAULT 'Direncanakan',
  anggaran BIGINT UNSIGNED NOT NULL DEFAULT 0,
  hasil    TEXT         NULL,
  PRIMARY KEY (id),
  KEY idx_program_tahun (tahun, unit),
  CONSTRAINT chk_program_capaian CHECK (capaian BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE TABLE pelkes_meta (
  tahun       SMALLINT UNSIGNED NOT NULL,
  pendahuluan TEXT NULL,
  evaluasi    TEXT NULL,
  ketua       VARCHAR(150) NULL,
  sekretaris  VARCHAR(150) NULL,
  PRIMARY KEY (tahun)
) ENGINE=InnoDB;

-- =====================================================================
-- 6. KEUANGAN (Bendahara)
-- =====================================================================

CREATE TABLE penerimaan (
  id      VARCHAR(32)  NOT NULL,
  tanggal DATE         NOT NULL,
  uraian  VARCHAR(200) NOT NULL,
  metode  ENUM('Tunai','Transfer Bank') NOT NULL DEFAULT 'Tunai',
  jumlah  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY idx_penerimaan_tgl (tanggal),
  CONSTRAINT chk_penerimaan_jumlah CHECK (jumlah > 0)
) ENGINE=InnoDB;

CREATE TABLE persepuluhan (
  id      VARCHAR(32)  NOT NULL,
  tanggal DATE         NOT NULL,
  sektor  VARCHAR(50)  NOT NULL,
  jumlah  BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  KEY idx_persepuluhan_tgl (tanggal, sektor),
  CONSTRAINT fk_persepuluhan_sektor FOREIGN KEY (sektor) REFERENCES sektor (nama) ON UPDATE CASCADE,
  CONSTRAINT chk_persepuluhan_jumlah CHECK (jumlah > 0)
) ENGINE=InnoDB;

CREATE TABLE pagu_apbj (
  tahun  SMALLINT UNSIGNED NOT NULL,
  seksi  VARCHAR(80)  NOT NULL,           -- PTPU, PIPK, POS, PKK, Wadah Perempuan, Koinonia, Operasional ...
  jumlah BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (tahun, seksi)
) ENGINE=InnoDB;

CREATE TABLE disposisi (                  -- E-Disposisi / UUDP pencairan dana
  id        VARCHAR(32)  NOT NULL,
  no        VARCHAR(20)  NULL,            -- UUDP-2601
  tanggal   DATE         NOT NULL,
  seksi     VARCHAR(80)  NOT NULL,
  kegiatan  VARCHAR(255) NOT NULL,
  pengaju   VARCHAR(150) NULL,
  jumlah    BIGINT UNSIGNED NOT NULL,
  status    ENUM('Menunggu','Disetujui','Ditolak','Dicairkan') NOT NULL DEFAULT 'Menunggu',
  oleh      VARCHAR(120) NULL,            -- Ketua yang memutuskan
  tgl_putus DATE         NULL,
  alasan    VARCHAR(300) NULL,
  tgl_cair  DATE         NULL,
  PRIMARY KEY (id),
  KEY idx_disposisi_status (status),
  KEY idx_disposisi_tgl (tanggal)
) ENGINE=InnoDB;

CREATE TABLE pengeluaran (
  id       VARCHAR(32)  NOT NULL,
  tanggal  DATE         NOT NULL,
  seksi    VARCHAR(80)  NOT NULL,
  kategori VARCHAR(60)  NOT NULL,         -- Insentif Pelayan, Operasional Gedung, ...
  uraian   VARCHAR(255) NOT NULL,
  jumlah   BIGINT UNSIGNED NOT NULL,
  disp_id  VARCHAR(32)  NULL,             -- bila berasal dari pencairan e-disposisi
  PRIMARY KEY (id),
  KEY idx_pengeluaran_tgl (tanggal),
  KEY idx_pengeluaran_seksi (seksi, tanggal),
  CONSTRAINT fk_pengeluaran_disp FOREIGN KEY (disp_id) REFERENCES disposisi (id) ON DELETE SET NULL,
  CONSTRAINT chk_pengeluaran_jumlah CHECK (jumlah > 0)
) ENGINE=InnoDB;

CREATE TABLE setoran (                    -- setoran sentralisasi ke Sinode
  id      VARCHAR(32)  NOT NULL,
  tanggal DATE         NOT NULL,
  periode VARCHAR(60)  NOT NULL,
  bank    VARCHAR(150) NOT NULL,
  jumlah  BIGINT UNSIGNED NOT NULL,
  bukti   LONGTEXT     NULL,              -- foto bukti transfer (data-URL)
  PRIMARY KEY (id),
  KEY idx_setoran_tgl (tanggal),
  CONSTRAINT chk_setoran_jumlah CHECK (jumlah > 0)
) ENGINE=InnoDB;

CREATE TABLE darurat (                    -- Dana Tanggap Darurat
  id       VARCHAR(32)  NOT NULL,
  tanggal  DATE         NOT NULL,
  jenis    ENUM('Diakonial','Sumbangan Kedukaan','Penanggulangan Bencana','Bantuan Kemanusiaan') NOT NULL,
  penerima VARCHAR(200) NOT NULL,
  jumlah   BIGINT UNSIGNED NOT NULL,
  ket      TEXT         NULL,
  PRIMARY KEY (id),
  KEY idx_darurat_tgl (tanggal, jenis),
  CONSTRAINT chk_darurat_jumlah CHECK (jumlah > 0)
) ENGINE=InnoDB;

CREATE TABLE uang (                       -- buku kas umum (modul Keuangan Ketua)
  id         VARCHAR(32)  NOT NULL,
  tanggal    DATE         NOT NULL,
  uraian     VARCHAR(255) NOT NULL,
  jenis      ENUM('Pemasukan','Pengeluaran') NOT NULL,
  jumlah     BIGINT UNSIGNED NOT NULL,
  program_id VARCHAR(32)  NULL,           -- tautan realisasi program Pelkes
  PRIMARY KEY (id),
  KEY idx_uang_tgl (tanggal, jenis),
  CONSTRAINT fk_uang_program FOREIGN KEY (program_id) REFERENCES program (id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE saldo_publik (               -- ringkasan saldo yang diterbitkan ke beranda
  id          VARCHAR(32) NOT NULL,
  tipe        ENUM('minggu','bulan','tahun') NOT NULL,
  label       VARCHAR(80) NOT NULL,
  dari        DATE        NOT NULL,
  sampai      DATE        NOT NULL,
  kolekte     BIGINT      NOT NULL DEFAULT 0,
  persepuluhan BIGINT     NOT NULL DEFAULT 0,
  belanja     BIGINT      NOT NULL DEFAULT 0,
  setoran     BIGINT      NOT NULL DEFAULT 0,
  darurat     BIGINT      NOT NULL DEFAULT 0,
  masuk       BIGINT      NOT NULL DEFAULT 0,
  keluar      BIGINT      NOT NULL DEFAULT 0,
  selisih     BIGINT      NOT NULL DEFAULT 0,
  saldo_akhir BIGINT      NOT NULL DEFAULT 0,
  status      ENUM('Terbit','Draf') NOT NULL DEFAULT 'Terbit',
  tanggal     DATE        NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_saldo_periode (tipe, dari, sampai),
  KEY idx_saldo_status (status, tipe)
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- 7. VIEW LAPORAN
-- =====================================================================

-- Jumlah warga aktif per sektor
CREATE OR REPLACE VIEW v_warga_aktif_sektor AS
SELECT s.nama AS sektor, COUNT(w.id) AS warga_aktif
FROM sektor s
LEFT JOIN warga w ON w.sektor = s.nama AND w.status = 'Aktif'
GROUP BY s.nama;

-- Realisasi belanja vs pagu APBJ per seksi per tahun
CREATE OR REPLACE VIEW v_realisasi_pagu AS
SELECT p.tahun, p.seksi, p.jumlah AS pagu,
       COALESCE(SUM(e.jumlah), 0) AS terpakai,
       p.jumlah - COALESCE(SUM(e.jumlah), 0) AS sisa
FROM pagu_apbj p
LEFT JOIN pengeluaran e ON e.seksi = p.seksi AND YEAR(e.tanggal) = p.tahun
GROUP BY p.tahun, p.seksi, p.jumlah;

-- Posisi kas per tahun (sama dengan rumus kasPos di script.js)
CREATE OR REPLACE VIEW v_posisi_kas AS
SELECT t.tahun,
       t.penerimaan, t.persepuluhan, t.pengeluaran, t.setoran, t.darurat,
       (t.penerimaan + t.persepuluhan - t.pengeluaran - t.setoran - t.darurat) AS saldo
FROM (
  SELECT y.tahun,
    (SELECT COALESCE(SUM(jumlah),0) FROM penerimaan  WHERE YEAR(tanggal) = y.tahun) AS penerimaan,
    (SELECT COALESCE(SUM(jumlah),0) FROM persepuluhan WHERE YEAR(tanggal) = y.tahun) AS persepuluhan,
    (SELECT COALESCE(SUM(jumlah),0) FROM pengeluaran WHERE YEAR(tanggal) = y.tahun) AS pengeluaran,
    (SELECT COALESCE(SUM(jumlah),0) FROM setoran     WHERE YEAR(tanggal) = y.tahun) AS setoran,
    (SELECT COALESCE(SUM(jumlah),0) FROM darurat     WHERE YEAR(tanggal) = y.tahun) AS darurat
  FROM (
    SELECT YEAR(tanggal) AS tahun FROM penerimaan
    UNION SELECT YEAR(tanggal) FROM persepuluhan
    UNION SELECT YEAR(tanggal) FROM pengeluaran
    UNION SELECT YEAR(tanggal) FROM setoran
    UNION SELECT YEAR(tanggal) FROM darurat
  ) y
) t;

-- Matriks keputusan rapat yang lewat target
CREATE OR REPLACE VIEW v_keputusan_terlambat AS
SELECT n.tanggal AS tgl_rapat, n.jenis AS rapat, n.judul, k.teks, k.pj, k.target, k.status
FROM notulen_keputusan k
JOIN notulen n ON n.id = k.notulen_id
WHERE k.status <> 'Selesai' AND k.target IS NOT NULL AND k.target < CURRENT_DATE();

-- Antrean pengesahan Ketua: UUDP menunggu
CREATE OR REPLACE VIEW v_antrean_uudp AS
SELECT id, no, tanggal, seksi, kegiatan, pengaju, jumlah
FROM disposisi WHERE status = 'Menunggu';

-- =====================================================================
-- Selesai. Akun Admin pertama dibuat lewat aplikasi (menu Daftar):
-- akun pertama otomatis menjadi Admin dan hash password dibuat aman.
-- =====================================================================
