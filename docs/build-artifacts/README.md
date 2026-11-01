# 可直接运行的模拟器 App 包

`CamCardClone-simulator.zip` 由 CI（[运行 18](https://github.com/Asorijin/Tongji-MobileAppDev/actions/runs/41312148832)，commit `5158fea`）产出的
`app-simulator` 工件原样复制而来，未做任何改动。

- 构建配置：Debug，`CODE_SIGNING_ALLOWED=NO`，目标 iOS 18.5 模拟器
- 来源：macOS 15 / Xcode 16.4 / iPhone SE (3rd generation) / iOS 18.5
- 工件校验值：7 150 139 B（zip），解压后为 `CamCardClone.app` 目录

## 在 Mac 上运行

```bash
git clone https://github.com/Asorijin/Tongji-MobileAppDev.git
cd Tongji-MobileAppDev

unzip docs/build-artifacts/CamCardClone-simulator.zip -d ~/Downloads/
xcrun simctl boot "iPhone SE (3rd generation)" 2>/dev/null || true
open -a Simulator
xcrun simctl install booted ~/Downloads/CamCardClone.app
xcrun simctl launch booted com.tongji.mobileappdev.camcardclone
```

若要换用别的模拟器机型，先 `xcrun simctl list devices available` 选一台并 `boot` 它，
再把上面的 `booted` 换成该设备的 UDID。

## 限制

- 这是**模拟器**构建，只能装进 iPhone 模拟器；真机需要 Apple 签名（另见 `test-suite.md` §3 的人工清单说明）。
- 需要 macOS 上的 Xcode 16.x（`xcodebuild -version` 确认）。iOS 18.5 运行时若未安装，
  在 Xcode → Settings → Components 里下载；或用 `xcrun simctl list runtimes` 看已有版本后改设备名。
- 包里带有 XCTest 注入用的 `Frameworks/libXCTestBundleInject.dylib`（构建时测试产物），
  不影响正常启动，可忽略。

## 手工验收

安装后按 `docs/test-suite.md` §3 的 M4–M6、M8–M10 逐项操作，结果填回该表；
其余 M1–M3、M7 需要真机相机。
