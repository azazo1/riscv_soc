# Quartus 编译烧录

## 编辑 hex 后快速重编译

Processing -> Update Memory Initialize File

![](update-memory-contents.webp)

然后 Processing -> Start -> Start Assembler

![](start-assembler.webp)

就能直接产生新的 sof / jic 文件, 而不需要等待长久的综合与布局布线.
