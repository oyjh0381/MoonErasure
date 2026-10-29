# 成本感知修复与故障域暴露分析

## 成本感知的修复读取计划

`Codec::plan_costed(present, costs)` 从已知完好的可用分片中选出至多 k 个，
使非负读取成本之和最小；成本相同时按分片编号稳定排序。结果保留缺失分片、
可用数量与恢复缺口。`CostedRepairPlan::total_cost()` 返回检查过溢出的 Int64 总成本。
长度错误、负成本与总成本溢出明确报错，不发起 I/O。

可用于对象存储跨区域读取、边缘缓存修复、分层介质的数据恢复。成本由宿主提供，
可以表示流量费或抽象权重，不代表实测时延。将选中的分片填入输入数组，再调用
`reconstruct_selected`；计划不能证明分片完整性，宿主仍需校验来源与校验和。
任意 k 个完好分片可恢复的 MDS 性质使选择最低 k 成本成立，无需枚举组合。
对于 n 个分片，排序选择 O(n log n) 时间、O(n) 空间；n 受现有编解码配置限制。

## 单故障域损失评估

`Codec::assess_domains(present, placement)` 按机架、区域或磁盘组标签聚合，
分别模拟每一个域完全损失。`DomainExposure` 给出 `lost_available`、`remaining`、
`spare` 和 `recoverable()`；`spare` 是剩余完好分片减 k，可为负。
已缺失分片不会重复计为新损失，全部域按名称排序，空标签与数组长度错误被拒绝。

适用于部署前检查集中放置风险、现有降级状态下的维护排程、跨区域容灾评估。
这是逐个域的确定性损失模型，不推断域独立概率，也不模拟多个域同时故障。
聚合 O(n)，对 d 个域排序 O(d log d)，空间 O(n+d)（含现有修复计划）。

## 验证范围

`placement_plan_test.mbt` 检查稳定并列成本、恢复缺口、负值、溢出、既有丢失，
并实际使用成本计划选出的校验分片恢复目标数据，不只验证计划字段。

## 本地复现

要求 moonc >= 0.10.16。在本地源码目录执行：

```sh
moon update
python tools/verify_toolchain.py
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run examples/placement --target wasm-gc --deny-warn
moon run examples/placement --target native --deny-warn
```

Windows 如遇 OCaml 扩展路径问题，使用仓库提供的 `tools/windows/moon.ps1`
代替 `moon`。

以上 API 从 **0.3.0** 起提供：`moon add oyjh0381/moonerasure@0.3.0`。
全部示例为可运行断言，不代表已有生产部署。
