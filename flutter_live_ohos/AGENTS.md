# Repository Guidelines

## Project Structure & Module Organization
这是一个 Flutter 多平台工程，核心业务代码放在 `lib/`，当前入口为 `lib/main.dart`。单元与组件测试放在 `test/`，现有示例为 `test/widget_test.dart`。原生平台目录包括 `android/`、`ios/` 和 `ohos/`；其中 OHOS 构建脚本位于 `ohos/hvigorfile.ts` 与 `ohos/entry/hvigorfile.ts`，配置文件位于 `ohos/build-profile.json5`。资源文件如后续新增，应统一放在根目录 `assets/` 并同步登记到 `pubspec.yaml`。

## Build, Test, and Development Commands
- `flutter pub get`：安装 Dart/Flutter 依赖。
- `flutter run`：在当前默认设备启动调试。
- `flutter run -d <device-id>`：指定设备运行，例如 OHOS 或模拟器。
- `flutter analyze`：执行静态检查；本仓库当前可通过。
- `flutter test`：运行测试；当前 `widget_test.dart` 已通过。
- `flutter build apk` / `flutter build ios`：生成 Android 或 iOS 构建产物。
- `cd ohos && hvigorw assembleHap`：构建 OHOS HAP；仅在本机已安装 Hvigor 与相关 SDK 时使用。

## Coding Style & Naming Conventions
遵循 `analysis_options.yaml` 中的 `flutter_lints`。使用 2 空格缩进，并在提交前运行 `dart format .`。类名使用 `UpperCamelCase`，方法、变量、文件名使用 `lowerCamelCase` 或 `snake_case.dart`；测试描述应直接说明行为，例如 `Counter increments smoke test`。避免未使用导入、调试残留和过长的 `build` 方法。

## Testing Guidelines
测试框架为 `flutter_test`。新增界面逻辑时，至少补充对应的 widget test；纯 Dart 逻辑优先写单元测试。测试文件命名采用 `<feature>_test.dart`，并与被测代码靠近对应模块。合并前至少运行 `flutter analyze` 和 `flutter test`。

## Commit & Pull Request Guidelines
当前目录未包含 `.git` 元数据，无法从历史提交中提炼既有规范。建议暂时使用 Conventional Commits，例如 `feat: add ohos launch config`、`fix: handle null title in home page`。PR 应说明改动目的、影响平台、验证命令；涉及 UI 的改动附截图，涉及配置的改动注明所需本地环境或 SDK 版本。

## Security & Configuration Tips
不要提交密钥、证书、签名文件或本机绝对路径。`ohos/package.json` 当前引用了本地 `flutter-hvigor-plugin` 路径，调整前应确认团队环境一致，避免将个人机器路径扩散到共享配置。
