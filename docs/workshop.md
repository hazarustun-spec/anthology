# Anthology — Workshop rehberi

Anthology, yapay zekâ araçlarının (Claude Code, Claude Desktop, Cursor, VS Code, Gemini CLI, Codex) içine yazdığı bir not uygulaması.
Sohbette "bunu Anthology'ye kaydet" diyorsun; not Mac'indeki uygulamaya düşüyor.

**Gerekenler:** macOS 26 (Tahoe) veya daha yenisi. Hesap, kayıt, sunucu yok.

## 1. Kur (1 dakika)

Terminal'i aç ve şunu yapıştır:

```bash
curl -fsSL https://raw.githubusercontent.com/hazarustun-spec/anthology/main/install.sh | sh
```

Betik son sürümü indirir, Apple imzasını kontrol eder, `Anthology.app`'i Uygulamalar klasörüne koyar ve açar.
Şifre sorarsa: Uygulamalar klasörüne yazma izni gerekiyordur, Mac şifreni gir.

## 2. Yapay zekânı bağla

Uygulama ilk açılışta kısa bir tanıtım gösterir. **"Yapay zekânı bağla"** sayfasında kullandığın aracın yanındaki **Bağlan**'a bas.
Sonradan: kenar çubuğunun altındaki **⚙ Bağlantılar** (ya da ⌘ + virgül).

- **Claude Code:** Bağlan'dan sonra açık Claude Code oturumunu kapatıp yeniden başlat.
- **Claude Desktop / Cowork:** Bağlan'a basınca Claude bir kez yeniden başlar.
- **Cursor, VS Code, Gemini CLI, Codex:** Bağlan'dan sonra o aracı yeniden başlat.

Claude Code kullanıyorsan alternatif olarak eklentiyi kurabilirsin (Claude Code içinde yaz):

```
/plugin marketplace add hazarustun-spec/anthology
/plugin install anthology@anthology
```

## 3. Dene

Claude Code'da bir proje klasöründe şunları yaz:

| Yaz | Ne olur |
|---|---|
| `Öğrenmek istediğim beceriler: SQL, sistem tasarımı. Bunu Anthology'ye kaydet.` | Claude yeni bir not açar; Anthology'de anında görünür. |
| `//m listeye Docker'ı da ekle` | Onay sormadan doğru nota ekler. |
| `//m! yarın Ali'yi ara` | Kelimesi kelimesine *Hızlı notlar*'a kaydedilir; modele hiç gitmez (sıfır token). |
| `Anthology'deki beceri listeme göre bana bir çalışma planı yap` | Claude notunu okuyup ona göre cevap verir. |

Uygulamada dikkat et:
- Her proje klasörü bir **konu** olur.
- Notun başında **"Claude Code düzenledi · 1 dk önce"** yazar; tıklayınca geçmiş ve **Geri al** çıkar.
- Satırların solundaki küçük ikon, o satırı hangi aracın yazdığını gösterir.
- <kbd>⌥</kbd><kbd>⌘</kbd><kbd>M</kbd>: her yerden hızlı not. <kbd>⌘</kbd><kbd>K</kbd>: tüm notlarda ara.

## Notlar nerede?

iCloud Drive › Anthology klasöründe düz Markdown (`.md`) dosyaları; iCloud Drive kapalıysa Mac'inde yerel olarak saklanır.
İstediğin editörle açabilirsin.
Yapay zekâ izin vermeden not silemez; her değişikliğin önceki hali saklanır.

## Sorun çözme

| Belirti | Çözüm |
|---|---|
| `macOS 26 or newer is required` | Anthology yalnızca macOS 26+ üzerinde çalışır. |
| Claude "Anthology aracı yok" diyor | Bağlan'dan sonra Claude Code oturumunu yeniden başlat. Claude Code'da `/mcp` yazıp `anthology`'nin bağlı olduğunu kontrol et. |
| Ayarlar'da **Güncelle** düğmesi var | Uygulama güncellenmiş; Güncelle'ye bas, aracı yeniden başlat. |
| Not görünmüyor | Anthology'yi bir kez açtığından emin ol (not klasörünü ilk açılışta o belirler), sonra aracı yeniden başlat. |

## Kaldırma

Anthology'yi Uygulamalar'dan çöpe at. Bağlantıları önce **⚙ Bağlantılar**'dan kesersen araçların yapılandırmaları da temizlenir.
Notların iCloud Drive › Anthology'de kalır.

Kaynak kodu ve sorular: https://github.com/hazarustun-spec/anthology
