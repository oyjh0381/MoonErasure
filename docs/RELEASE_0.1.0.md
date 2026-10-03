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
- 远程 CI、Mooncakes 发布、独立消费者安装和 GitHub Release 将在本次发布完成后补录；链接本身不是成功证据。

## 功能与申报边界

CRC-32C 只检测意外损坏；库恢复已知擦除，不负责网络/磁盘 I/O、节点放置、加密认证或持久化事务。目录原子批量操作仅覆盖同步内存状态。

本记录是技术自查与发布证据，不代表赛事组正式验收结论。申报资料的参赛者和联系方式保持空白，由申请人按十月章程核实并人工定稿。
