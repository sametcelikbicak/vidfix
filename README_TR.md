# vidfix

[![Stars](https://img.shields.io/github/stars/sametcelikbicak/vidfix?style=social)](https://github.com/sametcelikbicak/vidfix)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-11%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![Linux](https://img.shields.io/badge/Linux-x86_64%2Farm64-lightgrey.svg)](https://www.kernel.org/)

Videonun neden oynatılmadığını teşhis eder ve tek komutla düzeltir.

**🇬🇧 English: [README.md](README.md)**

```
$ vidfix check kamera_xavc.mp4
File      : kamera_xavc.mp4
Duration  : 00:00:04.00
Video     : h264 (High 4:2:2) 3840x2160 yuv422p10le 59.94fps 201860kb/s
Audio     : pcm_s16be
Hardware  : decoder cannot handle this file (software fallback)
Problems  :
  - 4:2:2/4:4:4 chroma - hardware decoders rarely support it
  - 10-bit colour depth - older GPUs cannot decode it
  - 2160p/59.94fps - too heavy for software decoding to keep up
Suggestion: vidfix "kamera_xavc.mp4" --preset 1080p
```

> Not: Araç çıktıları İngilizcedir; bu dosya yalnızca açıklamaları Türkçe içerir.

---

## Problem

Ses akar ama görüntü donar. Bu bir oynatıcı hatası değil; codec desteği eksikliği — ve çok belirgin bir kalıbı var:

| Belirti | Sebep |
| --- | --- |
| Ses akar, görüntü donar | Çözücü yetişemiyor. 4K 10-bit 4:2:2 yazılımda eski CPU'da ~15 fps |
| Görüntü siyah, ses normal | Donanım çözücü chroma veya bit derinliği profilini reddetti |
| "Codec desteklenmiyor" hatası | Codec H.264 / HEVC / VP9 / AV1 değil |

Tetikleyen genelde kamera formatları: Sony XAVC S, Canon XAVC, Panasonic AVCHD-Pro ve birçok drone/telefon çıkışı **10-bit 4:2:2** (`yuv422p10le`) üretir. Neredeyse tüm dizüstü GPU'ları — ve tüm tüketici oynatıcılar — sadece 8-bit 4:2:0 (`yuv420p`) çözer. Oynatıcı yazılıma düştüğünde görüntü donar, ses akmaya devam eder.

## Çözüm

`vidfix` dosyayı herkesin oynatabileceği profile çevirir: **H.264, 8-bit, 4:2:0, AAC**. Kaynak dosya asla değiştirilmez.

```
kamera_xavc.mp4   (h264 High 4:2:2 10-bit, 3840x2160, 269 Mbps)
        |
        |  vidfix kamera_xavc.mp4
        v
kamera_xavc_fixed.mp4   (h264 High 4:2:0 8-bit, 1920x1080, 12 Mbps, AAC)
        |
        v
   her yerde oynar: VLC, QuickTime, tarayıcılar, telefonlar, TV
```

## Kurulum

```bash
# tek komut (önerilen)
curl -fsSL https://raw.githubusercontent.com/sametcelikbicak/vidfix/v1.0.0/install.sh | bash

# ya da Homebrew ile
brew tap sametcelikbicak/tap https://github.com/sametcelikbicak/homebrew-tap
brew trust sametcelikbicak/tap      # Homebrew üçüncü taraf tap'ları güvenilir işaretlemeyi şart koşuyor
brew install vidfix

# ya da elle
git clone https://github.com/sametcelikbicak/vidfix
install -m 0755 vidfix/bin/vidfix ~/.local/bin/vidfix
```

Gerekenler: **ffmpeg** (`brew install ffmpeg` / `sudo apt install ffmpeg`) ve macOS 11+ ya da Linux.

## Kullanım

### Önce teşhis

```bash
vidfix check film.mp4        # neden oynatılmıyor?
vidfix check ./videolar/     # klasördeki tüm videoları kontrol et
```

Dosya sağlıklıysa çıkış kodu `0`, sorun varsa `1` — scriptlerde kullanılabilir.

### Dönüştür

```bash
vidfix film.mp4                      # -> film_fixed.mp4 (varsayılan 1080p)
vidfix ./videolar                    # klasördeki tüm videolar
vidfix film.mp4 --preset 2160p       # 4K kalır ama 8-bit 4:2:0 olur
```

Kaynak dosya **asla** değiştirilmez. Çıktı kaynağın yanına `<ad>_fixed.mp4` olarak yazılır.

### Seçenekler

| Seçenek | Varsayılan | Anlamı |
| --- | --- | --- |
| `--preset 720p\|1080p\|2160p` | `1080p` | Çıktı çözünürlüğü |
| `--bitrate 20M` | preset'e göre | Video bitrate (donanım kodlayıcılar) |
| `--out <dosya.mp4>` | `<ad>_fixed.mp4` | Tek dosya için çıktı yolu |
| `--out-dir <klasör>` | kaynak klasör | Çıktının yazılacağı yer |
| `--force` | kapalı | Var olan çıktıyı üzerine yaz |
| `--dry-run` | kapalı | ffmpeg komutunu göster, kodlama yapma |
| `--no-hw` | kapalı | Yazılımsal kodlama (libx264) zorla |

## Karar nasıl veriliyor?

`vidfix check` akışın gerçek özelliklerini ffmpeg ile okuyup şunları işaretler:

- **4:2:2 / 4:4:4 chroma** — donanım çözücüler neredeyse hiç desteklemez
- **10-bit derinlik** — eski GPU'lar desteklemez
- **4K + 30 fps üstü** — yazılım çözmede ağır
- **olağandışı codec** — H.264 / HEVC / VP9 / AV1 / MPEG-4 dışı her şey
- **video akışı yok** — bozuk konteyner

Ardından donanım çözmesini **gerçekten dener** (bir kare VideoToolbox, VA-API veya CUDA üzerinden), yani tahmin değil ölçüm yapar.

Dönüştürmede en uygun kodlayıcıyı seçer: macOS'ta VideoToolbox, NVIDIA'da NVENC, yoksa yazılımsal `libx264`.

## Örnekler

```bash
# tüm kamera kartı, 4K kaliteyi koru
vidfix /Volumes/SDCARD/DCIM --preset 2160p --bitrate 40M

# başka diske toplu çıktı, önceki çalışmayı ez
vidfix ./cekimler --out-dir ~/Movies/fixed --force

# ne çalışacak tam olarak gör
vidfix film.mp4 --dry-run
```

## Proje yapısı

```
bin/vidfix         ana CLI (POSIX bash, macOS + Linux)
install.sh         sha256 doğrulamalı curl | bash kurulumu
tests/run.sh       uçtan uca test paketi, fixture'ları kendisi üretir
```

## Geliştirme

```bash
./tests/run.sh
```

Test paketi ffmpeg ile sentetik fixture'lar üretir ve 24 doğrulama yapar: teşhis, dönüştürme, çıktı formatı, kaynak dosyanın bütünlüğü, klasör modu, dry run, CLI sözleşmesi ve kurulumun sha256 doğrulaması.

CI aynı paketi macOS ve Linux'ta çalıştırır; ayrıca her `v*` etiketinde tarball ve checksum'u yayınlayan bir release iş akışı vardır.

## Sorun giderme

**`ffmpeg not found`** — ffmpeg kurun: `brew install ffmpeg` veya `sudo apt install ffmpeg`.

**Dönüştürdükten sonra da donuyor** — makine 1080p için bile çok yavaş olabilir. `--preset 720p` deneyin; donanım kodlayıcı bozuk dosya ürettiyse `--no-hw` kullanın.

**Dönüştürme çok yavaş** — beklenen. 4K 10-bit kaynaklar önce yazılımda çözülmek zorunda, eski CPU'da yaklaşık 0.2–0.5x gerçek zaman. Daha küçük `--preset` çözmeyi hızlandırmaz, sadece kodlamayı.

## Lisans

MIT — bkz. [LICENSE](LICENSE).
