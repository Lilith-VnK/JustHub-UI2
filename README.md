# JustHub UI 2

**JustHub UI** adalah framework antarmuka (UI library) modular untuk Roblox yang ditulis murni dalam **Luau**. Satu file, tanpa dependensi, dengan 17 tema bawaan, sistem konfigurasi JSON, lokalisasi, kontrol berbasis role, undo/redo, dan 12 komponen UI siap pakai.

| | |
|---|---|
| Versi | 2.1.0 |
| Bahasa | Luau (Roblox) |
| Berkas inti | `JustHub2.lua` (4.861 baris) |
| Tema bawaan | 17 |
| Komponen | 12 |
| Bahasa UI | Indonesia (`id`), Inggris (`en`) |

> Catatan: pustaka ini ditujukan untuk lingkungan Roblox yang Anda kelola sendiri atau yang mengizinkannya. Patuhi Ketentuan Layanan Roblox dan aturan game yang Anda gunakan.

---

## Daftar Isi

1. [Fitur](#fitur)
2. [Isi Repositori](#isi-repositori)
3. [Arsitektur Modul](#arsitektur-modul)
4. [Persyaratan](#persyaratan)
5. [Instalasi](#instalasi)
6. [Mulai Cepat](#mulai-cepat)
7. [Referensi API](#referensi-api)
   - [Objek JustHub](#objek-justhub)
   - [Window](#window)
   - [Tab dan Section](#tab-dan-section)
   - [Komponen](#komponen)
   - [Notifikasi](#notifikasi)
   - [Tema](#tema)
   - [Lokalisasi](#lokalisasi)
   - [Konfigurasi](#konfigurasi)
   - [Role dan Permission](#role-dan-permission)
   - [Undo/Redo dan State](#undoredo-dan-state)
   - [Suara](#suara)
8. [Design Token](#design-token)
9. [Contoh Lanjutan](#contoh-lanjutan)
10. [Troubleshooting](#troubleshooting)
11. [Batasan dan Catatan Keamanan](#batasan-dan-catatan-keamanan)
12. [Changelog](#changelog)

---

## Fitur

- **Satu file, tanpa dependensi** — cukup `loadstring` dari URL raw GitHub.
- **Jendela lengkap** — drag, resize, minimize, maximize, lock posisi, sidebar, dan kotak pencarian kontrol.
- **12 komponen** — Button, Toggle, Slider, Label, TextBox, Dropdown, Multi Dropdown, Color Picker, Script Box, Keybind, Menu, dan Config Manager.
- **17 tema bawaan** — dari `Darker`, `Dark`, `Light`, `Neon`, `Cyber`, `Galaxy`, hingga `Pastel`, ditambah tema kustom dan animasi *chroma* (warna berputar).
- **Sistem konfigurasi** — simpan/muat/hapus profil dalam JSON dengan skema berversi (v4) dan migrasi otomatis dari skema lama.
- **Lokalisasi** — kamus `en` dan `id` bawaan; bisa mendaftarkan bahasa sendiri.
- **Role / permission** — kontrol dapat disembunyikan berdasarkan rank role pengguna (`guest`, `member`, `moderator`, `admin` atau role kustom).
- **Undo / redo** — riwayat perubahan nilai kontrol (maksimal 100 langkah secara default).
- **Notifikasi** — tumpukan maksimal 6 notifikasi dengan progress bar opsional, plus fallback ke notifikasi Roblox bawaan.
- **Manajemen resource** — semua koneksi, tween, dan Instance dibersihkan lewat scope berjenjang sehingga tidak ada kebocoran memori saat UI ditutup.
- **Tahan error** — operasi Instance dan callback dibungkus `pcall`/`xpcall` dan dilaporkan sebagai warning, bukan crash.

---

## Isi Repositori

```
JustHub-UI2/
├── JustHub2.lua   # Seluruh pustaka (14 modul, 1 file)
└── README.md      # Dokumentasi ini
```

---

## Arsitektur Modul

Walaupun berupa satu file, `JustHub2.lua` disusun sebagai 14 modul terpisah di dalam tabel `Modules`:

| Modul | Tanggung jawab |
|---|---|
| `Util` | Helper murni: cek angka finite, clamp, deep clone, sanitasi nama Instance, normalisasi array string, pemanggilan aman. |
| `ResourceManager` | Registry Instance, koneksi event, tween, task, dan `Scope` berjenjang untuk pembersihan otomatis. |
| `ThemeManager` | Token desain, 17 tema bawaan, binding properti Instance ke key tema, tema kustom, animasi chroma. |
| `UiKit` | Factory Instance (`make`, sudut, stroke, teks) dengan penanganan error terpusat. |
| `StateManager` | Registry nilai kontrol, alias ID, undo/redo, penerapan konfigurasi. |
| `StorageAdapter` | Abstraksi filesystem executor (`readfile`, `writefile`, `delfile`, `listfiles`, `makefolder`, `isfolder`) beserta deteksi kapabilitas dan sanitasi nama file. |
| `ConfigManager` | Profil konfigurasi JSON skema v4: serialisasi `Color3`, validasi, migrasi, save/load/delete/list. |
| `Localization` | Kamus bahasa, pelacakan teks yang bisa diterjemahkan, penggantian teks saat bahasa berganti. |
| `Permissions` | Hirarki role dan pengecekan rank. |
| `Sound` | Pemutaran efek suara tombol/slider dari asset ID. |
| `Components` | 12 builder komponen UI. |
| `Window` | Jendela utama: sidebar tab, pencarian, drag/resize/minimize/maximize, lock, transparansi. |
| `Notifications` | Tumpukan notifikasi kustom dan fallback `StarterGui`. |
| Inti `JustHub` | Singleton yang menyatukan semua modul menjadi API publik. |

Alur pemuatan: modul dasar (`Util`, `ResourceManager`, `ThemeManager`, `StateManager`, `StorageAdapter`) dimuat lebih dulu, lalu `ConfigManager`, `Localization`, `Permissions`, `Sound`, `Components`, `Window`, dan `Notifications`. Objek `JustHub` dibuat sekali sebagai singleton dan dikembalikan di akhir file.

---

## Persyaratan

- **Roblox Player** (client-side) — UI dibuat di `PlayerGui` atau `CoreGui`.
- **Eksekutor / lingkungan Luau** yang menyediakan `loadstring` (atau `getgenv`) untuk memuat skrip dari URL.
- **Filesystem executor** hanya diperlukan untuk fitur konfigurasi (`writefile`, `readfile`, `listfiles`, `delfile`, `makefolder`, `isfolder`). Tanpa itu, UI tetap berjalan dan `GetConfigCapabilities()` akan melaporkan kapabilitas yang tidak tersedia.

---

## Instalasi

### 1. Muat langsung dari GitHub (disarankan)

```lua
local JustHub = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Lilith-VnK/JustHub-UI2/main/JustHub2.lua"
))()
```

Simpan URL tersebut di satu tempat agar pembaruan cukup dilakukan di repositori.

### 2. Simpan sebagai file lokal

Unduh `JustHub2.lua`, lalu muat isinya dengan eksekutor Anda:

```lua
local JustHub = loadstring(readfile("JustHub2.lua"))()
```

### 3. Sebagai LocalScript (Studio)

Salin isi `JustHub2.lua` ke sebuah `LocalScript` di `StarterPlayerScripts`, lalu ganti baris terakhir `return JustHub` menjadi pemakaian langsung, misalnya:

```lua
local JustHub = ...
```

Cara termudah di Studio adalah tetap memakai `loadstring` pada file yang di-embed sebagai string, atau menempatkan `JustHub2.lua` sebagai ModuleScript dan mengubah `return JustHub` menjadi module return (ModuleScript sudah mengembalikan `JustHub` secara otomatis).

---

## Mulai Cepat

```lua
-- 1. Muat pustaka
local JustHub = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Lilith-VnK/JustHub-UI2/main/JustHub2.lua"
))()

-- 2. Buat jendela
local Window = JustHub:CreateWindow({
    Name = "JustHub Demo",          -- judul jendela (opsi bernama Name, bukan Title)
    Subtitle = "v2.1.0",
    Theme = "Darker",               -- nama tema bawaan atau tabel tema kustom
    Width = 760,
    Height = 520,
})

-- 3. Buat tab dan section
local MainTab = Window:addTab("Main", "home")
local PlayerSection = MainTab:addSection("Player")

-- 4. Tambahkan kontrol
PlayerSection:addToggle({
    Name = "Infinite Jump",
    Default = false,
    Callback = function(enabled)
        print("Infinite Jump:", enabled)
    end,
})

PlayerSection:addSlider({
    Name = "WalkSpeed",
    Min = 16,
    Max = 200,
    Step = 1,
    Default = 16,
    Callback = function(value)
        print("WalkSpeed:", value)
    end,
})

PlayerSection:addDropdown({
    Name = "Mode",
    Options = { "Normal", "Fast", "Slow" },
    Default = "Normal",
    Callback = function(selected)
        print("Mode:", selected)
    end,
})

PlayerSection:addButton({
    Name = "Reset Character",
    ButtonText = "Reset",
    Cooldown = 2,
    Callback = function()
        game.Players.LocalPlayer.Character:BreakJoints()
    end,
})

-- 5. Selesai — UI langsung tampil
```

---

## Referensi API

### Objek JustHub

`JustHub2.lua` mengembalikan **satu objek singleton**. Semua API publik dipanggil dengan titik dua (`JustHub:NamaMetode(...)`).

#### Properti

| Properti | Tipe | Keterangan |
|---|---|---|
| `Info` | table | `{ Name = "JustHub", Version = "2.1.0", SchemaVersion = 4 }` |
| `Save` | table | Pengaturan jendela tersimpan: `UISize = {760, 520}`, `TabSize = 168`, `Theme = "Darker"`, `Locked = false`, `Transparency = 0`. |
| `Themes` | table | Daftar tema (lihat [Tema](#tema)). |
| `DesignTokens` | table | Token desain: warna, tipografi, dimensi (lihat [Design Token](#design-token)). |
| `Icons` | table | Asset ID ikon: `activity`, `check`, `cog`, `folder`, `home`, dan lainnya. |
| `Localization` | table | Kamus bahasa yang aktif dimuat. |
| `CurrentLang` | string | Kode bahasa aktif (`"en"` atau `"id"`). |
| `UserRole` | string | Role pengguna saat ini (default `"member"`). |
| `UndoStack` / `RedoStack` | table | Riwayat perubahan nilai kontrol. |
| `Sounds` | table | `{ ButtonClick = 0, SliderMove = 0 }` — isi dengan asset ID untuk mengaktifkan suara. |
| `Window` | table | Objek jendela yang dibuat lewat `CreateWindow`. |
| `PromoNotifyEnabled` | boolean | Default `false`; harus diaktifkan sebelum `PromoNotify`. |

#### Metode

| Metode | Deskripsi |
|---|---|
| `CreateWindow(options)` | Membuat jendela utama. Mengembalikan `window` atau `nil, error`. Memanggil ulang saat jendela masih ada akan mengembalikan jendela lama. |
| `InitializeUI(options)` | Membuat UI sekaligus menampilkan loading screen. Mengembalikan `ok, window/err`. |
| `ShowLoadingScreen(duration, callback)` | Menampilkan loading screen 0–15 detik (default 1,5 detik) lalu memanggil `callback`. |
| `Notify(options)` | Menampilkan notifikasi. Lihat [Notifikasi](#notifikasi). |
| `PromoNotify(interval)` | Notifikasi promosi berkala; hanya berjalan jika `PromoNotifyEnabled = true`. |
| `StopPromoNotify()` | Menghentikan notifikasi promosi. |
| `ToggleUIVisibility()` | Menyembunyikan/menampilkan UI. Mengembalikan `boolean`. |
| `SetToggleKey(key)` | Menetapkan tombol global untuk menampilkan/menyembunyikan UI. |
| `RegisterControl(id, setter, metadata)` | Mendaftarkan kontrol manual ke registry nilai. |
| `UnregisterControl(id)` | Melepas kontrol dari registry. |
| `GetValue(id)` / `SetValue(id, value)` | Membaca/menetapkan nilai kontrol berdasarkan ID. |
| `SetUserRole(roleName)` | Mengganti role pengguna dan memperbarui visibilitas kontrol ber-role. |
| `RegisterRole(name, rank)` | Mendaftarkan role kustom dengan rank numerik. |
| `CheckRole(requiredRole)` | Mengembalikan `true` jika role pengguna memenuhi rank yang diminta. |
| `AddUndo(controlKey, oldValue, newValue)` | Mencatat satu langkah undo. |
| `Undo()` / `Redo()` | Membatalkan/mengulang perubahan terakhir. |
| `ApplyConfig(configData)` | Menerapkan nilai dari tabel konfigurasi. |
| `RegisterTheme(name, definition)` | Mendaftarkan tema baru. |
| `SetTheme(newTheme)` / `UpdateTheme(newTheme)` | Menerapkan tema berdasarkan nama atau tabel tema. |
| `GetThemeNames()` | Mengembalikan daftar nama tema terurut. |
| `UpdateThemeObject(instance, property, themeKey)` | Mengikat properti Instance ke key tema. |
| `ToggleChroma(enabled)` | Menyalakan/mematikan animasi chroma. |
| `UnregisterChroma(instance, property)` | Melepas binding chroma. |
| `SetLanguage(language)` | Mengganti bahasa UI. |
| `RegisterLanguage(language, dictionary)` | Mendaftarkan/menambah kamus bahasa. |
| `LocalizeText(textKey)` | Mengambil terjemahan sebuah key. |
| `SaveConfig(fileName)` | Menyimpan konfigurasi (default `JustHub_Config.json`). |
| `LoadConfig(fileName)` | Memuat konfigurasi. |
| `ListConfigs()` | Mengembalikan daftar profil tersimpan. |
| `DeleteConfig(fileName)` | Menghapus profil. |
| `GetConfigCapabilities()` | Melaporkan kapabilitas filesystem executor. |
| `RegisterTransparency(instance, baseValue, property)` | Mendaftarkan Instance untuk pengaturan transparansi global. |
| `SetTransparency(value)` | Mengatur transparansi UI (0–1). |
| `SetKey(key)` / `CheckKey(inputKey)` | Key system sederhana: menetapkan kunci dan memverifikasinya. |
| `PlaySound(name, volume)` | Memutar suara (`"ButtonClick"` atau `"SliderMove"`). |
| `IsAlive()` | `true` selama objek belum dihancurkan. |
| `Destroy()` | Menghancurkan seluruh UI dan membersihkan semua resource. |

---

### Window

#### Opsi `CreateWindow`

| Opsi | Tipe | Default | Keterangan |
|---|---|---|---|
| `Name` | string | `"JustHub"` | Judul yang tampil di header jendela. |
| `Subtitle` / `SubTitle` | string | `"v2.1.0"` | Teks kecil di bawah judul. |
| `Theme` | string \| table | tema tersimpan | Nama tema bawaan atau tabel tema kustom. |
| `Width` | number | 760 | Lebar jendela (px). |
| `Height` | number | 520 | Tinggi jendela (px). |
| `SidebarWidth` | number | 168 | Lebar sidebar tab. |
| `Parent` | Instance | otomatis | Induk GUI; default `PlayerGui`, atau `CoreGui` jika `UseCoreGui`. |
| `UseCoreGui` | boolean | `false` | Coba tempatkan di `CoreGui` (jika diizinkan lingkungan). |
| `DisplayOrder` | number | — | `DisplayOrder` ScreenGui. |
| `ToggleKey` | string | — | Tombol untuk menyembunyikan/menampilkan UI. |

#### Metode Window

| Metode | Deskripsi |
|---|---|
| `window:addTab(name, iconName)` | Menambahkan tab baru. `iconName` merujuk ke key di `JustHub.Icons`. |
| `window:SelectTab(tabName)` | Mengaktifkan tab berdasarkan nama. |
| `window:GetTab(tabName)` | Mengembalikan objek tab. |
| `window:ApplySearch()` | Menjalankan ulang filter kotak pencarian. |
| `window:SetLocked(value)` | Mengunci posisi/ukuran jendela (menonaktifkan drag dan resize). |
| `window:Destroy()` | Menghancurkan jendela beserta isinya. |
| `window:Toggle()` | Menyembunyikan/menampilkan jendela. |
| `window:SetTitle(text)` / `window:SetSubtitle(text)` | Mengubah judul/subjudul. |
| `window:SetSize(width, height)` / `window:SetPosition(x, y)` | Mengatur ukuran dan posisi. |
| `window:GetSize()` / `window:GetPosition()` | Membaca ukuran dan posisi saat ini. |
| `window:SetSidebarWidth(width)` | Mengatur lebar sidebar. |
| `window:IsVisible()` / `window:IsLocked()` | Status jendela. |

Transparansi global diatur lewat `JustHub:SetTransparency(value)`, bukan pada objek window. Minimize/maximize tersedia sebagai tombol header jendela.

Alias huruf besar juga tersedia: `window:AddTab(...)`.

---

### Tab dan Section

```lua
local Tab = Window:addTab("Combat", "activity")   -- nama tab, ikon
local Section = Tab:addSection("Aimbot")
```

| Metode | Deskripsi |
|---|---|
| `tab:addSection(name)` / `tab:AddSection(name)` | Membuat section baru. Section mewarisi semua metode komponen. |
| `tab:Select()` | Mengaktifkan tab. |
| `tab:Destroy()` | Menghancurkan tab. |
| `section:MakeControlId(controlName)` | Membuat ID kontrol unik dari nama tab, section, dan nama kontrol. |
| `section:Destroy()` | Menghancurkan section. |

ID kontrol dibuat otomatis; jika ada nama yang sama, diberi akhiran `#2`, `#3`, dan seterusnya. ID inilah yang dipakai `JustHub:GetValue(id)` dan `JustHub:SetValue(id, value)`.

---

### Komponen

Semua builder dipanggil dari **section** (bukan dari tab), dengan tabel opsi. Setiap kontrol menerima `Role` (string) untuk pembatasan role.

Sebagian besar builder mengembalikan dua nilai: `frame, handle`, dengan `handle:Get()` dan `handle:Set(value)`.

#### `addToggle`

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Toggle"` |
| `Default` | boolean | `false` |
| `Callback` | function(enabled) | — |
| `FireOnInit` | boolean | `false` |
| `Role` | string | — |

```lua
local frame, toggle = section:addToggle({
    Name = "Auto Farm",
    Default = false,
    Callback = function(on) print(on) end,
})
print(toggle:Get())
toggle:Set(true)
```

#### `addSlider`

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Slider"` |
| `Min` / `Max` | number | `0` / `100` |
| `Step` | number | `1` |
| `Float` | boolean | `false` |
| `Default` | number | `Min` |
| `Callback` | function(value) | — |
| `FireOnInit` | boolean | `false` |
| `Role` | string | — |

#### `addLabel`

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Label"` |
| `Height` | number | 28 (dibatasi 12–400) |
| `Role` | string | — |

Label mengembalikan `frame, handle` dengan `handle:SetText(text)` dan `handle:GetText()`.

#### `addButton`

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Action"` |
| `ButtonText` | string | `"Run"` |
| `Callback` | function() | — |
| `Cooldown` | number | `0` (0–60 detik) |
| `Role` | string | — |

#### `addTextBox`

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Input"` |
| `Placeholder` | string | `"Type here..."` |
| `Default` | string | `""` |
| `MaxLength` | number | — |
| `OnlyOnEnter` | boolean | `false` |
| `Callback` | function(text) | — |
| `Role` | string | — |

#### `addDropdown`

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Dropdown"` |
| `Options` / `Items` | tabel string | `{}` |
| `Default` | string | `""` |
| `Callback` | function(selected) | — |
| `FireOnInit` | boolean | `false` |
| `Role` | string | — |

Mengembalikan **tabel** `{ Frame, Handle, Refresh, Clear, GetValue, SetValue, Destroy }`:

```lua
local dropdown = section:addDropdown({
    Name = "Weapon",
    Options = { "Sword", "Bow", "Staff" },
    Default = "Sword",
    Callback = function(value) print(value) end,
})

dropdown:SetValue("Bow")
dropdown:Refresh({ "Sword", "Bow", "Staff", "Dagger" })  -- opsi baru
dropdown:Clear()
```

#### `addMultiDropdown`

Opsi sama dengan `addDropdown`; `Default` berupa tabel string. Nilai yang dikembalikan `GetValue()` adalah tabel pilihan.

```lua
local multi = section:addMultiDropdown({
    Name = "Targets",
    Options = { "Player", "NPC", "Chest" },
    Default = { "Player" },
    Callback = function(selected) print(table.concat(selected, ", ")) end,
})
```

#### `addColorPicker`

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Color"` |
| `Default` | Color3 | `Color3.fromRGB(80, 200, 160)` |
| `Callback` | function(color) | — |
| `FireOnInit` | boolean | `false` |
| `Role` | string | — |

#### `addScriptBox`

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Script"` |
| `Placeholder` | string | `"Paste text here..."` |
| `Default` | string | `""` |
| `Callback` | function(text) | — |
| `Role` | string | — |

Kotak teks multi-baris dengan tombol **Run**.

#### `addBind` (keybind)

| Opsi | Tipe | Default |
|---|---|---|
| `Name` | string | `"Keybind"` |
| `Default` | string | `"RightShift"` |
| `ChangedCallback` | function(key) | — |
| `Role` | string | — |

Tekan kontrol lalu tekan tombol untuk mengganti keybind. `Backspace`/`Delete` mengosongkan; `Escape` membatalkan. Nilai kosong disimpan sebagai `"None"`.

#### `addMenu`

`section:addMenu(name)` membuat baris menu bergaya judul di dalam section. `name` boleh berupa string atau tabel `{ Name = "...", Role = "..." }`. Mengembalikan `frame`. Baris ini ikut terkena filter kotak pencarian dan pembatasan role.

#### `addConfigManager`

Membuat panel profil konfigurasi siap pakai (input nama, tombol Save/Load/Delete, dan daftar profil).

```lua
local ConfigSection = Window:addTab("Config", "folder"):addSection("Profiles")
local frame, configUI = ConfigSection:addConfigManager()
configUI:Refresh()
```

Handle yang dikembalikan: `{ Frame, Input, Refresh(), List(), GetName(), SetName(value) }`.

#### `addChromaToggle`

Menambahkan toggle untuk menyalakan/mematikan animasi chroma pada tema yang mendukung.

---

### Notifikasi

```lua
JustHub:Notify({
    Title = "Berhasil",
    Message = "Konfigurasi disimpan.",
    Duration = 4,          -- 0–60 detik, default 4
    ShowProgress = true,   -- progress bar sisa waktu
    Callback = function() print("notifikasi ditutup") end,
})
```

- Maksimal **6** notifikasi tampil bersamaan; notifikasi tertua dihapus otomatis.
- Jika jendela belum dibuat, notifikasi dialihkan ke `StarterGui:SetCore("SendNotification")` (fallback Roblox).
- `JustHub:Notify` mengembalikan `nil` bila UI sudah dihancurkan.

---

### Tema

#### Tema bawaan (17)

`Darker`, `Dark`, `Purple`, `Light`, `Neon`, `Forest`, `Aqua`, `Crimson`, `Solar`, `Pastel`, `Cyber`, `Ocean`, `Desert`, `Galaxy`, `Vintage`, `Rainbow`, `Midnight`.

```lua
JustHub:SetTheme("Cyber")
print(table.concat(JustHub:GetThemeNames(), ", "))
```

#### Tema kustom

Tema wajib memiliki enam key inti:

| Key | Fungsi |
|---|---|
| `Color Hub 1` | Latar utama panel |
| `Color Hub 2` | Latar kontrol/sekunder |
| `Color Stroke` | Garis tepi |
| `Color Theme` | Warna aksen (tombol aktif, slider) |
| `Color Text` | Teks utama |
| `Color Dark Text` | Teks di atas warna aksen |

Tema hanya terdiri dari enam key di atas. Untuk mewarnai Instance kustom, ikat propertinya ke salah satu key tersebut dengan `JustHub:UpdateThemeObject`.

```lua
local MyTheme = {
    ["Color Hub 1"]      = Color3.fromRGB(24, 24, 28),
    ["Color Hub 2"]      = Color3.fromRGB(32, 32, 38),
    ["Color Stroke"]     = Color3.fromRGB(48, 48, 56),
    ["Color Theme"]      = Color3.fromRGB(120, 90, 255),
    ["Color Text"]       = Color3.fromRGB(240, 240, 245),
    ["Color Dark Text"]  = Color3.fromRGB(18, 18, 22),
}

local ok, err = JustHub:RegisterTheme("MyTheme", MyTheme)
JustHub:SetTheme("MyTheme")
-- atau langsung: JustHub:SetTheme(MyTheme)
```

#### Binding tema manual

```lua
JustHub:UpdateThemeObject(myFrame, "BackgroundColor3", "Color Theme")
```

#### Chroma

```lua
JustHub:ToggleChroma(true)   -- warna aksen berputar
```

---

### Lokalisasi

```lua
JustHub:SetLanguage("id")        -- "en" atau "id"
print(JustHub:LocalizeText("Run"))  -- "Jalankan"

JustHub:RegisterLanguage("es", {
    Run = "Ejecutar",
    SaveProfile = "Guardar perfil",
})
JustHub:SetLanguage("es")
```

Key yang tidak ditemukan akan dikembalikan apa adanya, sehingga aman untuk bertahap.

---

### Konfigurasi

```lua
local ok, err = JustHub:SaveConfig("PvP")
local loaded, report = JustHub:LoadConfig("PvP")
local profiles = JustHub:ListConfigs()
JustHub:DeleteConfig("PvP")
```

- Skema JSON **v4**; konfigurasi versi lama dimigrasikan otomatis dengan peringatan.
- Default file: `JustHub_Config.json`.
- Validasi: hanya tipe yang didukung (`string`, `number` finite, `boolean`, `Color3`, tabel), kedalaman maksimum 32, dan angka non-finite ditolak.
- Nama file disanitasi (karakter ilegal dan nama file reserved Windows ditolak).
- Konfigurasi juga menyimpan pengaturan jendela (`Save`: ukuran, tema, lock, transparansi) dan menerapkannya saat dimuat.
- `JustHub:GetConfigCapabilities()` memberi tahu apakah `writefile`/`readfile`/`listfiles`/`delfile`/`makefolder`/`isfolder` tersedia di eksekutor.

---

### Role dan Permission

Rank bawaan:

| Role | Rank |
|---|---|
| `guest` | 0 |
| `member` | 10 |
| `moderator` | 50 |
| `admin` | 100 |

```lua
JustHub:RegisterRole("vip", 30)
JustHub:SetUserRole("vip")

print(JustHub:CheckRole("moderator"))   -- false
print(JustHub:CheckRole("guest"))       -- true

section:addButton({
    Name = "Ban Player",
    Role = "moderator",   -- hanya tampil untuk rank >= 50
    Callback = function() end,
})
```

Kontrol dengan `Role` diberi atribut `JustHubRole` dan visibilitasnya diperbarui saat `SetUserRole` dipanggil.

---

### Undo/Redo dan State

- Riwayat default: **100** langkah (dapat diubah saat membuat `StateManager`, bukan dari API publik).
- `JustHub:AddUndo(id, oldValue, newValue)` mencatat perubahan; `Undo()` dan `Redo()` menerapkannya.
- `JustHub:SetValue(id, value)` memperbarui nilai tanpa menambah riwayat; gunakan `AddUndo` bila ingin bisa dibatalkan.
- Nilai kontrol juga dipakai oleh sistem konfigurasi (`SaveConfig`/`LoadConfig`).

---

### Suara

```lua
JustHub.Sounds.ButtonClick = 6895079853
JustHub.Sounds.SliderMove  = 6895079853

JustHub:PlaySound("ButtonClick", 0.6)   -- volume 0–1, default 0.6
```

Nilai `0` berarti suara nonaktif. Pemutaran dilakukan di `SoundService` dan dibersihkan otomatis.

---

## Design Token

`JustHub.DesignTokens` berisi nilai desain yang dipakai seluruh komponen:

| Grup | Contoh isi |
|---|---|
| `Typography` | `Title = 18`, `Subtitle = 11`, `Section = 14`, `Body = 13`, `Small = 11` |
| Warna | Token warna turunan tema |
| Dimensi | Tinggi kontrol, dropdown, config manager, dan lain-lain |

Token dapat dibaca untuk menyelaraskan UI kustom Anda dengan tema aktif:

```lua
local tokens = JustHub.DesignTokens
print(tokens.Typography.Section)
```

---

## Contoh Lanjutan

### Jendela dengan beberapa tab dan role

```lua
local JustHub = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Lilith-VnK/JustHub-UI2/main/JustHub2.lua"
))()

local Window = JustHub:CreateWindow({
    Name = "Aurora Hub",
    Subtitle = "build 2026.11",
    Theme = "Midnight",
    Width = 820,
    Height = 560,
})

local Combat = Window:addTab("Combat", "activity")
local Visuals = Window:addTab("Visuals", "home")
local Settings = Window:addTab("Settings", "cog")

-- Combat
local Aimbot = Combat:addSection("Aimbot")
Aimbot:addToggle({ Name = "Enable", Default = false, Callback = function(v) end })
Aimbot:addSlider({ Name = "FOV", Min = 10, Max = 360, Default = 90, Callback = function(v) end })
Aimbot:addBind({ Name = "Toggle Key", Default = "E", ChangedCallback = function(key) end })

-- Visuals
local ESP = Visuals:addSection("ESP")
ESP:addColorPicker({ Name = "Team Color", Default = Color3.fromRGB(0, 170, 255) })
ESP:addDropdown({
    Name = "Style",
    Options = { "Box", "Highlight", "Chams" },
    Default = "Box",
})

-- Settings
local Profiles = Settings:addSection("Profiles")
local _, configUI = Profiles:addConfigManager()

Settings:addSection("Appearance"):addChromaToggle()
Settings:addSection("Language"):addDropdown({
    Name = "Bahasa",
    Options = { "en", "id" },
    Default = JustHub.CurrentLang,
    Callback = function(lang) JustHub:SetLanguage(lang) end,
})
```

### Mengambil dan menetapkan nilai berdasarkan ID

```lua
local id = PlayerSection:MakeControlId("WalkSpeed")
PlayerSection:addSlider({ Name = "WalkSpeed", Min = 16, Max = 200, Default = 16 })

print(JustHub:GetValue(id))
JustHub:SetValue(id, 50)
```

### Membersihkan UI

```lua
JustHub:Destroy()
```

---

## Troubleshooting

| Gejala | Penyebab umum | Solusi |
|---|---|---|
| `JustHub requires a client context with Players.LocalPlayer` | Skrip dijalankan di server. | Jalankan di `LocalScript`/eksekutor client. |
| `JustHub could not find a valid GUI container` | Tidak ada `PlayerGui`/`CoreGui` yang bisa dipakai. | Buat jendela setelah pemain sepenuhnya masuk; set `UseCoreGui = true` bila didukung. |
| UI tidak muncul | `Destroy()` sudah dipanggil atau `ScreenGui` dihapus. | Panggil `IsAlive()` sebelum membuat UI. |
| Konfigurasi gagal disimpan | Eksekutor tidak menyediakan filesystem. | Cek `GetConfigCapabilities()`; gunakan eksekutor dengan `writefile`. |
| Notifikasi tidak tampil | Jendela belum dibuat dan `SetCore` gagal. | Buat jendela lebih dulu atau gunakan `StarterGui` fallback yang tersedia. |
| Tema baru ditolak | Enam key wajib tidak lengkap atau nilainya bukan `Color3`. | Lengkapi `Color Hub 1`, `Color Hub 2`, `Color Stroke`, `Color Theme`, `Color Text`, `Color Dark Text`. |
| Peringatan `Callback failed for '<id>'` | Error di dalam `Callback` Anda. | Periksa stack trace di output konsol; callback dibungkus `xpcall`. |
| Teks tetap bahasa Inggris | Key terjemahan tidak ada. | Tambahkan key lewat `RegisterLanguage`. |

Aktifkan **Output** di eksekutor untuk melihat warning berawalan `[JustHub]`; pustaka tidak pernah menelan error tanpa melaporkannya.

---

## Batasan dan Catatan Keamanan

- Pustaka ini **client-side** dan bergantung pada API eksekutor; perilakunya dapat berbeda antar eksekutor.
- `UseCoreGui` bergantung pada izin lingkungan; jika gagal, UI otomatis memakai `PlayerGui`.
- Fitur konfigurasi menulis file melalui filesystem eksekutor. Jangan memuat profil dari sumber yang tidak dipercaya.
- `CheckKey` adalah key system sederhana di sisi client — bukan mekanisme keamanan kriptografis, dan tidak boleh dijadikan satu-satunya proteksi lisensi.
- Semua data UI berada di memori client; pemain lain tidak melihatnya.
- Penggunaan pustaka ini tetap tunduk pada Ketentuan Layanan Roblox dan aturan game masing-masing.

---

## Changelog

### 2.1.0

- Skema konfigurasi v4 dengan migrasi otomatis dari skema lama.
- `ConfigManager` baru: serialisasi `Color3`, validasi kedalaman dan nilai finite, sanitasi nama file.
- `StorageAdapter` dengan deteksi kapabilitas filesystem.
- 17 tema bawaan dan animasi chroma.
- Lokalisasi `en`/`id` dengan `RegisterLanguage`/`LocalizeText`.
- Role dan permission (`guest`, `member`, `moderator`, `admin`, role kustom).
- Notifikasi dengan progress bar dan fallback `StarterGui`.
- Window: drag, resize, minimize/maximize, lock, transparansi, pencarian kontrol.
- 12 komponen UI termasuk multi-dropdown, color picker, script box, dan keybind.

---

## Kredit

Dibuat dan dipelihara oleh **Lilith-VnK**. Repositori: <https://github.com/Lilith-VnK/JustHub-UI2>.
