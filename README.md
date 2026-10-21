# 《储能优化配置与调度技术》课程设计 — 作业提交库 (`ESS-Course-Submissions`)

本仓库为南京工程学院《储能优化配置与调度技术》课程设计的**学生作业收集库**（仓库 B），专门用于接收全班同学通过 **Fork + Pull Request (PR)** 提交的课程设计代码、标准化结果数据与最终报告。

* **教学资源库（只读算例与模板下载）**：`https://github.com/wuhan-njit/ESS-Course-Materials`
* **作业提交库（本仓库，需 Fork 并提交 PR）**：`https://github.com/wuhan-njit/ESS-Course-Submissions`

---

## 一、 作业提交目录与命名规范（防冲突设计）

为确保全班同学向同一个 `main` 分支发起 Pull Request 时**零冲突（Able to merge）**，每位同学**严禁修改本仓库根目录下的任何公共文件或其他同学的文件夹**，必须在根目录下新建一个以 **`学号_姓名拼音`** 命名的独立子文件夹（参考根目录预置的示范文件夹 `242400000_Zhangsan/`）：

```text
ESS-Course-Submissions/               <-- 仓库 B：作业收集库 (学生需 Fork 并提交 PR)
├── .gitignore                        # 预置忽略规则：自动拦截 *.asv, *.mex*, *.log, gurobi.lic
├── README.md                         # PR 提交操作步骤说明与命名规范检查清单
└── 242400000_Zhangsan/                        # 教师预置的提交示范文件夹（请参照此格式建立个人文件夹）
    ├── Zhangsan_242400000_Week1.mlx           # 第一周实时脚本源文件
    ├── Zhangsan_242400000_Week1.m             # 导出的纯文本代码（供教师在 GitHub PR 网页端直接在线审阅）
    ├── Fig_Week1_Dispatch_242400000.png/.pdf/.fig # 第一周脚本自动导出的白底 600dpi PNG、矢量 PDF 与 FIG 图源文件
    ├── Zhangsan_242400000_Week2.mlx           # 第二周实时脚本源文件
    ├── Zhangsan_242400000_Week2.m             # 导出的纯文本代码
    ├── Fig_Week2_Planning_242400000.png/.pdf/.fig # 第二周脚本自动导出的白底 600dpi PNG、矢量 PDF 与 FIG 图源文件
    └── result_summary.mat                     # 脚本自动生成的标准化结果结构体（供教师端一键批改脚本读取）
```

> **重要提示**：由于 `.mlx` 实时脚本本质为二进制压缩包，无法在 GitHub 网页端直接预览代码，提交时**必须同时在 MATLAB 实时编辑器中点击 `保存 (Save) -> 导出为 (Export to)...` 生成同名的纯文本 `.m` 文件**放入个人文件夹中！

---

## 二、 GitHub Desktop 提交 Pull Request 六步操作指南

1. **Step 1：Fork（派生个人云端仓库）**
   登录个人 GitHub 账号，访问本仓库主页 `https://github.com/wuhan-njit/ESS-Course-Submissions`，点击右上角 **`Fork`** 按钮，将本仓库派生到你自己的 GitHub 账号下。
2. **Step 2：Clone（克隆到本地电脑）**
   打开 **GitHub Desktop**，点击 `File -> Clone repository`，选择你自己账号下的 `ESS-Course-Submissions` 仓库，克隆到本地无中文路径下（例如 `D:\ESS_CourseDesign\ESS-Course-Submissions`）。
3. **Step 3：创建个人专属文件夹并复制模板**
   在本地 `ESS-Course-Submissions` 根目录下新建以 `学号_姓名拼音` 命名的文件夹（例如 `242400038_LiSi`）。将教学资源库 `ESS-Course-Materials/templates/` 下的两个 `.mlx` 模板复制到你自己的文件夹中，并按规范重命名为 `姓名拼音_学号_Week1.mlx` 和 `姓名拼音_学号_Week2.mlx`。
4. **Step 4：编写调试代码并导出配套文件**
   在 MATLAB 中打开个人文件夹下的 `.mlx` 脚本，修改开头的 `Stu_ID` 为本人真实学号，补全优化模型代码并运行调试。运行成功后：
   * 确认个人文件夹下已自动生成 `result_summary.mat`；
   * 在 MATLAB 菜单栏将两个 `.mlx` 分别导出为同名纯文本 `.m` 代码文件；
   * 将最终撰写的课程设计报告导出为 `姓名拼音_学号_Report.pdf` 放入同一文件夹。
5. **Step 5：Commit & Push（本地提交并推送到个人云端）**
   打开 GitHub Desktop，在左侧 `Changes` 列表中检查变动文件（**确认所有新增文件均位于你自己的 `学号_姓名拼音/` 文件夹内**）。在左下角 `Summary` 填写提交说明（例如 `feat: 242400038 李四 完成课程设计提交`），点击 **`Commit to main`**，再点击右上角 **`Push origin`**。
6. **Step 6：Open Pull Request（向教师主仓库发起合并请求）**
   在浏览器中打开你个人 GitHub 账号下的 `ESS-Course-Submissions` 仓库页面，点击 **`Contribute -> Open pull request`**，将 PR 标题严格填写为：
   * **`[班级-学号-姓名] 储能优化规划与运行课程设计提交`**（例如：`[储能221-242400038-李四] 储能优化规划与运行课程设计提交`）
   点击 **`Create pull request`** 即可完成提交。若第一周提交 PR 后在第二周有新增修改，只需在本地继续 `Commit` 并 `Push origin`，已创建的 PR 会自动同步更新，无需重复新建 PR。

---

## 三、 提交前自检清单（Checklist）

- [ ] 个人文件夹命名是否严格符合 `学号_姓名拼音`（如 `242400000_Zhangsan`）？
- [ ] 代码中的 `Stu_ID` 是否已修改为本人真实 9 位学号？
- [ ] 文件夹内是否完整包含以下 6 个文件：
  - [ ] `姓名拼音_学号_Week1.mlx`
  - [ ] `姓名拼音_学号_Week1.m`
  - [ ] `姓名拼音_学号_Week2.mlx`
  - [ ] `姓名拼音_学号_Week2.m`
  - [ ] `result_summary.mat`
  - [ ] `姓名拼音_学号_Report.pdf`
- [ ] GitHub Desktop 的 `Changes` 列表中是否没有改动任何其他文件夹或公共文件？
