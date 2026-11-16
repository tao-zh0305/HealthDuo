# 恢复日记（HealthDuo）

自用的 iPhone + Apple Watch 健康 App：看睡眠与恢复、记录训练、在手表上一键打卡。

- iPhone：今日恢复分、睡眠结构、训练列表、14 天趋势、设置
- Apple Watch：恢复分速览 + 三项主观打卡（疲劳 / 酸痛 / 睡眠感受）
- 数据：Apple 健康（只读）+ 本机 JSON 存储 + WatchConnectivity 直连同步

---

## 先说三件重要的事

1. **Windows 不能直接编译 iOS / watchOS App**，必须有 macOS + Xcode。这个项目走的是「GitHub Actions 的 macOS 机器代编 → 下载未签名 IPA → 用你的签名软件重签安装」。你的 Windows 只需要装 Git / GitHub Desktop。
2. **不再用 iCloud**。iCloud / CloudKit 需要付费开发者账号和对应权限，第三方签名基本拿不到。现在改为：健康数据只在手机本地保存，手表与手机之间用 WatchConnectivity 直连同步，不经过云端。
3. **手表 App 已经打进 IPA**，但第三方签名工具对「嵌套的 watchOS 包」重签成功率不稳定。如果装到手表后打不开，用按小时租的云 Mac（如 MacinCloud）连上手表直接装表端，成功率最高。

另外：这个项目**没有在 macOS / Xcode 上实际编译过**（当前环境是 Linux）。代码按可编译标准写，但首次跑 CI 仍可能暴露小问题，遇到红色报错把 Actions 日志发我。

---

## 项目结构

```
health-duo/
├── project.yml                 # XcodeGen 工程描述（两个 target）
├── Config/
│   ├── iOS.entitlements        # HealthKit 权限
│   ├── iOS-Info.plist          # 由 XcodeGen 生成
│   └── Watch-Info.plist        # 由 XcodeGen 生成
├── Shared/                     # 手机与手表共用
│   ├── Models.swift            # 快照、睡眠、训练、打卡、设置
│   ├── RecoveryEngine.swift    # 恢复分算法
│   ├── LocalStore.swift        # 本地 JSON 存储
│   ├── WatchSessionManager.swift
│   ├── Components.swift        # 圆环、进度条、配色
│   └── Formatters.swift
├── App/                        # iPhone 端
│   ├── HealthDuoApp.swift
│   ├── AppModel.swift
│   ├── HealthKitService.swift  # 读睡眠 / HRV / 静息心率 / 训练
│   ├── RootView.swift
│   ├── TodayView.swift
│   ├── SleepView.swift
│   ├── WorkoutsView.swift
│   ├── TrendsView.swift
│   └── SettingsView.swift
├── WatchApp/                   # 手表端
│   ├── HealthDuoWatchApp.swift
│   ├── WatchRootView.swift
│   └── WatchCheckInView.swift
└── .github/workflows/build.yml # 云端构建未签名 IPA
```

技术栈：SwiftUI + Swift Charts + HealthKit + WatchConnectivity，iOS 17+ / watchOS 10+。

---

## 第一次构建（Windows，全程不装 Xcode）

### 1. 改 Bundle ID

把 `com.example.healthduo` 换成你自己的，例如 `com.yourname.healthduo`。需要改三处：

- `project.yml` 里 iOS target 的 `PRODUCT_BUNDLE_IDENTIFIER`
- `project.yml` 里 watch target 的 `PRODUCT_BUNDLE_IDENTIFIER`（建议 `com.yourname.healthduo.watchkitapp`）
- `project.yml` 里 watch 的 `WKCompanionAppBundleIdentifier`（必须等于 iOS 的 Bundle ID）

> 手表 Bundle ID 必须以 iOS Bundle ID 为前缀，否则装不上。

### 2. 建仓库并推代码

在 GitHub 新建一个 **public** 仓库（公开仓库的 macOS Actions 分钟数免费），把 `health-duo` 里的文件推上去：

```bash
git init
git add .
git commit -m "init health duo"
git branch -M main
git remote add origin https://github.com/你的用户名/health-duo.git
git push -u origin main
```

### 3. 等云端编译

打开仓库的 **Actions → Build unsigned IPA**。首次会自动安装 XcodeGen、生成 Xcode 工程、编译并打包，大约几分钟。

成功后在该次运行页面底部下载 **Artifacts → HealthDuo-unsigned-ipa**，解压得到 `HealthDuo-unsigned.ipa`。

如果失败，下载 `xcodebuild-log` 看报错。

### 4. 用签名软件重签安装

把 `HealthDuo-unsigned.ipa` 拖进你常用的签名工具：

- 确认 Bundle ID 与证书匹配；
- **如果工具支持自定义权限（entitlements），要勾选 HealthKit**，否则读不到健康数据；
- 装到 iPhone 后，第一次打开会要求读取健康数据，全部允许。

### 5. 手表端

正常情况下，iPhone 上的「Watch」App → 我的手表 → 可用 App 里会出现「恢复日记」，点安装。

如果装不上或打开闪退，说明嵌套包重签失败，改用云 Mac：连上你的手表，用 Xcode 直接跑 `HealthDuoWatch` scheme 到手表。

---

## 第一次使用

1. iPhone 打开 App → 点「去授权」→ 允许读取睡眠、HRV、静息心率、心率、训练。
2. 打开系统「健康」App → 睡眠 → 设置睡眠目标 / 开启睡眠追踪（戴表睡觉才会自动记录）。
3. 戴 Apple Watch 睡一晚。第二天打开 App 下拉刷新，就能看到恢复分、睡眠结构、HRV 基线。
4. 手机打开 App 或下拉刷新后，恢复分会自动推给手表；手表上可以看恢复分并打卡。

---

## 恢复分怎么算

```
恢复分 = 睡眠分 × 50% + HRV 分 × 30% + 静息心率分 × 20%
```

- **睡眠分**：昨晚睡着时长 / 目标时长，封顶 100。
- **HRV 分**：最近一次 HRV 与 28 天基线（可在设置里改 14/28/56 天）对比，高于基线加分，低于基线扣分。
- **静息心率分**：与基线对比，每高 1 bpm 扣 6 分，越低越好。

没有睡眠数据时，权重自动落到 HRV 与静息心率上；三项都没有就显示「还没有健康数据」。

分数区间：85+ 恢复良好 / 70–84 状态可用 / 50–69 需要缓一缓 / 50 以下优先恢复。

> 这个分数只用于观察自己的趋势，不做任何医疗判断。

---

## 数据存在哪

- 健康原始数据：仍在系统「健康」App，App 只读，不写入。
- App 缓存：手机沙盒 `Application Support/HealthDuo/*.json`（快照、睡眠、训练、趋势、打卡）。
- 手表缓存：同样的本地 JSON，只存最近一次恢复分。
- 同步：`WatchConnectivity`，手机推快照、手表送打卡，不走 iCloud。
- 设置页有「清空本机缓存」，不会删除健康 App 里的原始数据。

---

## 本地开发（有 Mac 时）

```bash
brew install xcodegen
cd health-duo
xcodegen generate
open HealthDuo.xcodeproj
```

用 Xcode 选 `HealthDuo` scheme 跑模拟器；手表端选 `HealthDuoWatch`，配对手表或模拟器。真机安装需要在 Signing & Capabilities 里选自己的 Team，并保留 HealthKit capability。

---

## 常见问题

**Actions 编译失败**
先看 `xcodebuild-log` artifact。最常见的是 Bundle ID / 签名设置或 Xcode 版本差异，把报错贴给我即可。

**手表上没有 App**
先确认 IPA 里是否有 `Payload/HealthDuo.app/Watch/HealthDuoWatch.app`。没有的话是嵌入失败，CI 日志里会有提示。

**手表一直显示「等待手机同步」**
先在 iPhone 打开一次 App，让手机把快照推过去；确认两台设备已配对、蓝牙/Wi-Fi 正常。手表不在身边时同步会自动排队。

**没有 HRV / 静息心率**
HRV 需要 Apple Watch 佩戴期间采集；静息心率也需要手表。只有 iPhone 时通常只能拿到睡眠（如果开了睡眠追踪）和少部分数据。

**重签后读不到健康数据**
签名证书/描述文件必须带 HealthKit 权限。免费个人 Apple ID 自签通常拿不到 HealthKit，需要付费开发者账号或带该权限的企业证书；部分签名工具可以在「注入权限」里手动勾选。

**7 天后打不开**
免费证书签名有效期 7 天，到期需要重新签名安装；付费开发者证书通常 1 年。

**改了名字或图标**
图标在 `App/Assets.xcassets/AppIcon.appiconset` 和 `WatchApp/...`，直接替换 1024×1024 PNG 即可；App 显示名在 `project.yml` 的 `CFBundleDisplayName`。

---

## 免责声明

本项目是个人自用工具，评分算法是简单的加权启发式，不构成医疗建议，也不用于诊断或治疗任何疾病。身体不适请咨询医生。
