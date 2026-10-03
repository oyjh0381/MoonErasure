# MoonErasure 0.1.0 发布记录

日期：2026-10-03；维护账号：`oyjh0381`。

## 发布配置

- 公开仓库：https://github.com/oyjh0381/MoonErasure
- 包名：`oyjh0381/moonerasure@0.1.0`；默认分支：`main`；Apache-2.0。
- 原 48 条未推送提交先保存并校验完整 bundle，再统一作者和提交者身份；源码内容、消息、父子关系及时间保持不变。原始 bundle 和映射存放在仓库外的本地发布备份中。
- 有效 MoonBit 总计 4,426 行，其中库实现 2,527 行，非测试含示例 2,747 行；其余为测试。统计排除空行、行注释、依赖和构建目录，不声明库实现超过 4k。

## 已执行本地验证

- 工具链：`moon 0.1.20260827`、`moonc v0.10.14+7d59c7ec9`。
- `moon check/build/test --target all --deny-warn` 通过，Wasm、Wasm-GC、JS、Native 每后端 82/82 项测试。
- `cmd/main`、transfer、scrub、range、stream、maintenance 六个入口在 Wasm-GC 上执行通过。
- `moon info && moon fmt` 后 `git diff --exit-code` 为零，公开接口和格式均一致。
- 发布源码：`fd94bea3287f50278f84df7530fd8b107e1e1bc1`。
- 发布源 CI：[37112757023](https://github.com/oyjh0381/MoonErasure/actions/runs/37112757023)，四后端检查、构建、测试、示例和接口一致性检查全部成功。
- Mooncakes：`moon publish` 打包与解包检查通过，服务端 `200 OK`；[公开包文档](https://mooncakes.io/docs/oyjh0381/moonerasure) HTTP 200。
- 发布 ZIP SHA-256：`24224bd6ac97f8d19f1897b5eda001349b94ceaea337f107a2ccafe378e09290`；107 个归档条目，无 `.git`、构建/依赖缓存或本地发布备份目录。
- 独立消费者用 `moon add oyjh0381/moonerasure@0.1.0` 从公共注册表下载，无本地路径依赖；严格检查与 Wasm-GC 运行通过，验证跨条带两片擦除恢复、缺片修复、CRC 拒绝损坏帧、目录批量失败回滚和可恢复区间读取。
- GitHub Release：[v0.1.0](https://github.com/oyjh0381/MoonErasure/releases/tag/v0.1.0)，非草稿；发布者及 annotated tag 的 tagger 均为 `oyjh0381`，标签指向发布源码。
- 发布后的 main 仅补录文档，不覆盖或重发 0.1.0；最新 CI 见 [Actions](https://github.com/oyjh0381/MoonErasure/actions)。

## 功能与申报边界

CRC-32C 只检测意外损坏；库恢复已知擦除，不负责网络/磁盘 I/O、节点放置、加密认证或持久化事务。目录原子批量操作仅覆盖同步内存状态。

本记录是技术自查与发布证据，不代表赛事组正式验收结论。申报资料的参赛者和联系方式保持空白，由申请人按十月章程核实并人工定稿。
