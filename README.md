# 导学阶段-Rust 语言基础

基于 [LearningOS 2026s Rustlings 课程模板](https://github.com/LearningOS/2026s-rustling-classroom-template)，共 **110 题，每题 1 分，总分 110 分**。

## 使用流程

1. 加入 [OpenCamp 秋冬季训练营](https://opencamp.cn/os2edu/camp/2026fall)，并绑定自己的 GitHub 账号。
2. 点击[领取作业仓库](https://github.com/LearningOS/2026a-enroll/issues/new?template=rustlings.yml)，点击 **Create** 提交申请；等待机器人回复，然后接受仓库邀请。
3. 克隆分配的仓库，在 `main` 分支完成 `exercises/` 中的练习。
4. 提交并 push，在仓库 **Actions** 查看评测和上传结果，在 [OpenCamp 本阶段排行榜](https://opencamp.cn/os2edu/camp/2026fall/stage/2) 查看成绩。

本地安装 Git 和 [Rust](https://www.rust-lang.org/tools/install) 后，在自己的作业仓库中运行：

```sh
cargo run --locked -- watch
```

此命令使用仓库固定的依赖启动练习；按照终端提示修改题目，完成后移除该题的 `I AM NOT DONE` 注释。

完成一部分练习后提交：

```sh
git add exercises
git commit -m "Complete Rustlings exercises"
git push origin main
```

三条命令依次保存练习改动、创建提交、推送到 `main` 并触发自动评测。

## 计分规则

每次提交都会重新运行全部题目，以本次实际通过题数计分。编译、运行或测试失败及超时的题目记 0 分；其他已通过题目正常计分并上传。计分不按提交次数累加，也不只检查注释是否删除。

评测覆盖上游的编译运行、单元测试、Clippy 和构建脚本四类题目。单题限时 20 秒；评测工具构建失败或结果不完整时不上传成绩。

Actions 中 **Test exercises and calculate score** 变红表示还有未完成的题目；**Save measured score and upload to OpenCamp** 成功表示成绩同步成功。每道题的原始日志和成绩明细保存在该次运行的附件中。

[学员指南](docs/STUDENT_GUIDE.md)

## 练习顺序与教材章节

建议配合 [《Rust 程序设计语言》（Rust Book）](https://rustwiki.org/zh-CN/book/) 学习，按照下表顺序阅读教材并完成 `exercises/` 中的练习。

| 顺序 | 练习目录 | 对应教材内容 |
|---:|---|---|
| 1 | `intro` | §1.2：Hello, World! |
| 2 | `variables` | §3.1：变量与可变性 |
| 3 | `primitive_types` | §3.2：数据类型；切片部分结合 §4.3 |
| 4 | `functions` | §3.3：函数 |
| 5 | `if` | §3.5：控制流 |
| 6 | `move_semantics` | §4.1–4.2：所有权、引用与借用 |
| 7 | `structs` | 第 5 章：结构体 |
| 8 | `enums` | 第 6 章：枚举与模式匹配 |
| 9 | `options` | §6.1–6.3：`Option`、`match` 与 `if let` |
| 10 | `modules` | 第 7 章：包、Crate 与模块 |
| 11 | `vecs` | §8.1：Vector |
| 12 | `strings` | §8.2：字符串 |
| 13 | `hashmaps` | §8.3：HashMap |
| 14 | `error_handling` | 第 9 章：错误处理 |
| 15 | `generics` | §10.1：泛型数据类型 |
| 16 | `traits` | §10.2：Trait |
| 17 | `lifetimes` | §10.3：生命周期 |
| 18 | `tests` | 第 11 章：自动化测试，先完成 `tests1–4` |
| 19 | `iterators` | §13.2–13.4：迭代器 |
| 20 | `smart_pointers` | 第 15 章：智能指针；`Arc` 结合 §16.3 |
| 21 | `threads` | 第 16 章：并发编程 |
| 22 | `macros` | §19.5：宏 |
| 23 | `clippy` | 附录 D：开发工具 |
| 24 | `conversions` | 补充练习：类型转换，参考[标准库文档](https://doc.rust-lang.org/std/convert/index.html) |
| 25 | `algorithm` | 补充练习：数据结构与算法 |
