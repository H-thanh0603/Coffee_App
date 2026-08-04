# Plan: Dark Mode Implementation

## Architecture
```
lib/
├── main.dart              ← Wrap with MaterialApp(themeMode: ...)
├── theme/
│   ├── app_theme.dart     ← ThemeData cho light + dark
│   └── theme_provider.dart ← State management (ChangeNotifier)
├── screens/
│   └── settings_screen.dart ← Toggle switch
```

## Các bước thực hiện

### Bước 1: Tạo theme definitions
- File: `lib/theme/app_theme.dart`
- Định nghĩa `lightTheme` và `darkTheme` dùng `ThemeData`
- Dùng `ColorScheme.fromSeed()` — Flutter tự sinh palette

### Bước 2: Tạo state management
- File: `lib/theme/theme_provider.dart`
- `ChangeNotifier` giữ `ThemeMode` hiện tại
- Load/Save qua `SharedPreferences`

### Bước 3: Tích hợp vào MaterialApp
- Sửa `main.dart`: thêm `theme`, `darkTheme`, `themeMode`
- Wrap với `ChangeNotifierProvider`

### Bước 4: Thêm toggle trong Settings
- Sửa `settings_screen.dart`: thêm `SwitchListTile`
- 3 chế độ: Light / Dark / System

### Bước 5: Kiểm tra tất cả màn hình
- Chạy `flutter analyze`
- Test visual từng màn hình ở cả 2 theme
