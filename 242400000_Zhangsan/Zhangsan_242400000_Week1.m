%% 第一周：计及配电网二阶锥潮流与充放电互斥约束 (MISOCP) 的储能日前优化调度
% 课程名称：《储能优化配置与调度技术》课程设计 | 作者：张三（学号：242400000）

%% 0. 任务说明与核心数学模型
% *任务说明*：
% 
% 本脚本构建基于支路潮流（DistFlow）二阶锥松弛与储能充放电状态互斥约束的混合整数二阶锥规划（MISOCP）日前有功优化调度模型，调用 MOSEK（或 Gurobi）求解器求解，校验充放电互斥性、二阶锥松弛间隙，并通过 MATPOWER 交流潮流回代检验节点电压安全性。
% 
% *核心数学模型*：
% 
% *1) 储能系统荷电状态（SoC）动态方程与充放电互斥约束*（已知单站额定功率 $P_i^{\mathrm{rated}}$、额定能量容量 $E_i^{\mathrm{rated}}$ 为常数，引入二进制互斥变量 $u_{i,t}^{\mathrm{ch}} \in \{0,1\}$）：
% 
% $$\mathrm{SoC}_{i,t} = \mathrm{SoC}_{i,t-1} + \frac{\eta_{\mathrm{ch}} P_{i,t}^{\mathrm{ch}} \Delta t}{E_i^{\mathrm{rated}}} - \frac{P_{i,t}^{\mathrm{dis}} \Delta t}{\eta_{\mathrm{dis}} E_i^{\mathrm{rated}}}, \quad \mathrm{SoC}_{\min} \le \mathrm{SoC}_{i,t} \le \mathrm{SoC}_{\max}$$
% 
% $$0 \le P_{i,t}^{\mathrm{ch}} \le u_{i,t}^{\mathrm{ch}} P_i^{\mathrm{rated}}, \quad 0 \le P_{i,t}^{\mathrm{dis}} \le \left(1 - u_{i,t}^{\mathrm{ch}}\right) P_i^{\mathrm{rated}}, \quad u_{i,t}^{\mathrm{ch}} \in \{0,1\}$$
% 
% *2) 配电网 DistFlow 支路潮流与旋转二阶锥松弛方程*（令 $U_{i,t} = V_{i,t}^2, L_{ij,t} = I_{ij,t}^2$）：
% 
% $$P_{ij,t} - r_{ij} L_{ij,t} - \sum_{k\in\delta(j)} P_{jk,t} = P_{j,t}^{\mathrm{load}} - P_{j,t}^{\mathrm{pv}} + P_{j,t}^{\mathrm{ch}} - P_{j,t}^{\mathrm{dis}}$$
% 
% $$Q_{ij,t} - x_{ij} L_{ij,t} - \sum_{k\in\delta(j)} Q_{jk,t} = Q_{j,t}^{\mathrm{load}}$$
% 
% $$U_{j,t} = U_{i,t} - 2\left(r_{ij} P_{ij,t} + x_{ij} Q_{ij,t}\right) + \left(r_{ij}^2 + x_{ij}^2\right) L_{ij,t}$$
% 
% $$\sqrt{\left(2P_{ij,t}\right)^2 + \left(2Q_{ij,t}\right)^2 + \left(L_{ij,t} - U_{i,t}\right)^2} \le L_{ij,t} + U_{i,t}, \quad \left(V_{\min}\right)^2 \le U_{i,t} \le \left(V_{\max}\right)^2$$

clear; clc; close all;
yalmip('clear');

%% 1. 自动检测并挂载教学资源库 cases 路径
% 自动检测 |case_nongcun.m| 是否在搜索路径中，实现跨仓库无缝调用。
if ~exist('case_nongcun.m', 'file')
    rel_case_dir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'ESS-Course-Materials', 'cases');
    if exist(rel_case_dir, 'dir')
        addpath(rel_case_dir);
    elseif exist(fullfile(pwd, 'ESS-Course-Materials', 'cases'), 'dir')
        addpath(fullfile(pwd, 'ESS-Course-Materials', 'cases'));
    else
        case_dir = uigetdir(pwd, '请选择教学资源库中的 cases 文件夹路径');
        if isequal(case_dir, 0)
            error('未选择 cases 文件夹，程序终止。');
        end
        addpath(case_dir);
    end
end

%% 2. 学号哈希映射与配电网参数读取
% 根据学号末两位 $\mathrm{XY}$ 确定负荷乘子 $\alpha = 1 + 0.002 \times \mathrm{XY}$、配电网算例（由末位 $Y$ 决定）以及调度目标类型与储能接入节点（由倒数第二位 $X$ 决定）：
% 
% * $X \in \{0,1,2\}$：模型 A（最大化新能源消纳，含微网损正则项 $+10^{-2} E_{\mathrm{loss}}$）
% * $X \in \{3,4,5\}$：模型 B（最小化全网有功网损 $E_{\mathrm{loss}}$）
% * $X \in \{6,7,8,9\}$：模型 C（最小化主网购电成本 $C_{\mathrm{grid}}$）
Stu_ID  = 242400000;
XY      = mod(Stu_ID, 100);
X_digit = floor(XY / 10);
Y_digit = mod(XY, 10);
alpha   = 1 + 0.002 * XY;

if ismember(Y_digit, [0, 1, 2, 3])
    case_name = 'case_nongcun';
elseif ismember(Y_digit, [4, 5, 6])
    case_name = 'case_chengshi_A';
else
    case_name = 'case_kaifaqu_A';
end
mpc = loadcase(case_name);
load('profiles_24h.mat');

if ismember(X_digit, [0, 1, 2])
    ess_buses  = [4, 9, 14];
    model_type = 'A';
elseif ismember(X_digit, [3, 4, 5])
    ess_buses  = [5, 11, 16];
    model_type = 'B';
else
    ess_buses  = [6, 13, 17];
    model_type = 'C';
end
pv_buses = ess_buses;

%% 3. 标幺值基准转换与储能参数设置
% 设系统基准功率为 $S_{\mathrm{base}} = 100\;\mathrm{MVA}$，单站固定储能额定功率 $P_i^{\mathrm{rated}} = 1.5\;\mathrm{MW}$，额定容量 $E_i^{\mathrm{rated}} = 3.0\;\mathrm{MWh}$，单节点分布式光伏峰值装机容量为 $1.2\;\mathrm{MW}$。
Sbase = mpc.baseMVA;
N_bus = size(mpc.bus, 1);
N_br  = size(mpc.branch, 1);
N_ess = length(ess_buses);
N_pv  = length(pv_buses);

fbus = mpc.branch(:, 1);
tbus = mpc.branch(:, 2);
r_br = mpc.branch(:, 3);
x_br = mpc.branch(:, 4);

Pd_pu       = (mpc.bus(:, 3) * alpha / Sbase) * load_curve_pu';
Qd_pu       = (mpc.bus(:, 4) * alpha / Sbase) * load_curve_pu';
P_pv_max_pu = (1.2 / Sbase) * repmat(pv_curve_pu', N_pv, 1);

P_ess_rated_pu = 1.5 / Sbase; % 单站额定功率 1.5 MW (p.u.)
E_ess_rated_pu = 3.0 / Sbase; % 单站额定容量 3.0 MWh (p.u.)
eta_ch  = 0.90;
eta_dis = 0.95;
SoC_min = 0.20;
SoC_max = 0.80;
SoC_0   = 0.50;

%% 4. 声明 YALMIP 决策变量
U_bus  = sdpvar(N_bus, T, 'full'); % 节点电压幅值平方 U_{i,t} = V_{i,t}^2 (p.u.^2)
L_br   = sdpvar(N_br,  T, 'full'); % 支路电流幅值平方 L_{ij,t} = I_{ij,t}^2 (p.u.^2)
P_br   = sdpvar(N_br,  T, 'full'); % 支路首端有功潮流 P_{ij,t} (p.u.)
Q_br   = sdpvar(N_br,  T, 'full'); % 支路首端无功潮流 Q_{ij,t} (p.u.)
P_grid = sdpvar(1,     T, 'full'); % 关口购电有功功率 P_{grid,t} (p.u.)
Q_grid = sdpvar(1,     T, 'full'); % 关口无功功率 Q_{grid,t} (p.u.)
P_ch   = sdpvar(N_ess, T, 'full'); % 储能充电有功功率 P_{i,t}^{ch} (p.u.)
P_dis  = sdpvar(N_ess, T, 'full'); % 储能放电有功功率 P_{i,t}^{dis} (p.u.)
u_ch   = binvar(N_ess, T, 'full'); % 储能充放电互斥二进制变量 u_{i,t}^{ch} \in {0,1}
SoC    = sdpvar(N_ess, T, 'full'); % 储能荷电状态 SoC_{i,t}
P_pv   = sdpvar(N_pv,  T, 'full'); % 分布式光伏实际消纳出力 P_{i,t}^{pv} (p.u.)

%% 5. 构建储能动态与 DistFlow 二阶锥潮流约束
%%% 5.1 储能荷电状态（SoC）递推与充放电互斥边界约束
Constraints = [];
Constraints = [Constraints, 0 <= P_ch  <= P_ess_rated_pu * u_ch];
Constraints = [Constraints, 0 <= P_dis <= P_ess_rated_pu * (1 - u_ch)];
Constraints = [Constraints, SoC_min <= SoC <= SoC_max];
Constraints = [Constraints, SoC(:, T) == SoC_0];
Constraints = [Constraints, 0 <= P_pv <= P_pv_max_pu];

for t = 1:T
    if t == 1
        soc_prev = repmat(SoC_0, N_ess, 1);
    else
        soc_prev = SoC(:, t - 1);
    end
    Constraints = [Constraints, SoC(:, t) == soc_prev + ...
        (eta_ch * P_ch(:, t) - P_dis(:, t) / eta_dis) / E_ess_rated_pu];
end

%%% 5.2 节点有功/无功平衡、电压降落方程与二阶锥约束
% 利用稀疏关联矩阵 $\mathbf{A}_{\mathrm{from}}, \mathbf{A}_{\mathrm{to}}$ 实现全网节点功率平衡方程的向量化构建，并对每条支路施加二阶锥松弛约束 $\|(2P_{ij,t}, 2Q_{ij,t}, L_{ij,t}-U_{i,t})^{\mathrm{T}}\|_2 \le L_{ij,t}+U_{i,t}$。
A_from  = sparse(fbus, 1:N_br, 1, N_bus, N_br);
A_to    = sparse(tbus, 1:N_br, 1, N_bus, N_br);
A_ess   = sparse(ess_buses, 1:N_ess, 1, N_bus, N_ess);
A_pv    = sparse(pv_buses,  1:N_pv,  1, N_bus, N_pv);
A_slack = sparse(1, 1, 1, N_bus, 1);

P_loss_br = diag(r_br) * L_br;
Q_loss_br = diag(x_br) * L_br;

Constraints = [Constraints, A_to * (P_br - P_loss_br) - A_from * P_br + ...
    A_slack * P_grid + A_pv * P_pv + A_ess * (P_dis - P_ch) == Pd_pu];
Constraints = [Constraints, A_to * (Q_br - Q_loss_br) - A_from * Q_br + ...
    A_slack * Q_grid == Qd_pu];

Constraints = [Constraints, U_bus(1, :) == 1.0];
Constraints = [Constraints, (0.95^2) <= U_bus(2:end, :) <= (1.05^2)];
Constraints = [Constraints, L_br >= 0];

for b = 1:N_br
    i = fbus(b);
    j = tbus(b);
    Constraints = [Constraints, U_bus(j, :) == U_bus(i, :) - ...
        2 * (r_br(b) * P_br(b, :) + x_br(b) * Q_br(b, :)) + ...
        (r_br(b)^2 + x_br(b)^2) * L_br(b, :)];
    for t = 1:T
        Constraints = [Constraints, cone([2 * P_br(b, t); 2 * Q_br(b, t); ...
            L_br(b, t) - U_bus(i, t)], L_br(b, t) + U_bus(i, t))];
    end
end

%% 6. 构建目标函数并调用 MISOCP 求解器 (MOSEK / Gurobi)
% 本模型同时包含充放电互斥二进制变量 $u_{i,t}^{\mathrm{ch}}$ 与支路二阶锥约束，属于混合整数二阶锥规划（MISOCP），调用 MOSEK 或 Gurobi 求解。若使用 CVX 随附的 MOSEK，请仅将 |cvx/mosek| 子文件夹加入 MATLAB 路径（|addpath(genpath('.../cvx/mosek'))|），切勿运行 |cvx_setup| 或添加 |cvx| 根目录。
Total_Loss_MWh    = Sbase * sum(sum(P_loss_br));
Total_Curtail_MWh = Sbase * sum(sum(P_pv_max_pu - P_pv));
Total_Cost_Yuan   = sum((Sbase * P_grid') .* price_MWh);

if strcmp(model_type, 'A')
    Objective = Total_Curtail_MWh + 1e-2 * Total_Loss_MWh;
elseif strcmp(model_type, 'B')
    Objective = Total_Loss_MWh + 1e-4 * sum(sum(P_ch + P_dis));
else
    Objective = Total_Cost_Yuan;
end

if exist('mosekopt', 'file') ~= 0
    solver_name = 'mosek';
    ops = sdpsettings('solver', 'mosek', 'verbose', 1);
    ops.mosek.MSK_DPAR_MIO_MAX_TIME          = 120;
    ops.mosek.MSK_DPAR_MIO_TOL_REL_GAP       = 1e-6;
    ops.mosek.MSK_DPAR_MIO_TOL_ABS_GAP       = 1e-8;
    ops.mosek.MSK_DPAR_MIO_TOL_FEAS          = 1e-9;
    ops.mosek.MSK_DPAR_MIO_TOL_ABS_RELAX_INT = 1e-9;
    ops.mosek.MSK_DPAR_INTPNT_CO_TOL_PFEAS   = 1e-10;
    ops.mosek.MSK_DPAR_INTPNT_CO_TOL_DFEAS   = 1e-10;
    ops.mosek.MSK_DPAR_INTPNT_CO_TOL_REL_GAP = 1e-10;
elseif exist('gurobi', 'file') ~= 0
    solver_name = 'gurobi';
    ops = sdpsettings('solver', 'gurobi', 'verbose', 1);
    ops.gurobi.TimeLimit      = 120;
    ops.gurobi.MIPGap         = 1e-6;
    ops.gurobi.FeasibilityTol = 1e-9;
    ops.gurobi.IntFeasTol     = 1e-9;
    ops.gurobi.OptimalityTol  = 1e-8;
    ops.gurobi.BarQCPConvTol  = 1e-9;
else
    error(['未检测到支持 MISOCP 的求解器 (MOSEK 或 Gurobi)。', ...
           '请将独立安装的 MOSEK 或 CVX 下的 cvx/mosek 子目录加入路径：addpath(genpath(''.../cvx/mosek''))']);
end
sol = optimize(Constraints, Objective, ops);
if sol.problem ~= 0 && strcmp(solver_name, 'mosek') && exist('gurobi', 'file') ~= 0
    solver_name = 'gurobi';
    ops = sdpsettings('solver', 'gurobi', 'verbose', 1);
    ops.gurobi.TimeLimit      = 120;
    ops.gurobi.MIPGap         = 1e-6;
    ops.gurobi.FeasibilityTol = 1e-9;
    ops.gurobi.IntFeasTol     = 1e-9;
    ops.gurobi.OptimalityTol  = 1e-8;
    ops.gurobi.BarQCPConvTol  = 1e-9;
    sol = optimize(Constraints, Objective, ops);
end
if sol.problem ~= 0
    error('MISOCP 求解失败 (%s): %s', solver_name, sol.info);
end

%% 7. 二阶锥松弛精确性分析、交流潮流回代与《中国电机工程学报》规范绘图
% 定义二阶锥松弛最大间隙 $\Delta_{\mathrm{SOCP}}$ 为：
% 
% $$\Delta_{\mathrm{SOCP}} = \max_{(i,j)\in\Omega_{\mathrm{L}}, t\in\mathcal{T}} \left| L_{ij,t} U_{i,t} - \left( P_{ij,t}^2 + Q_{ij,t}^2 \right) \right|$$
socp_gap     = max(max(abs(value(L_br) .* value(U_bus(fbus, :)) - (value(P_br).^2 + value(Q_br).^2))));
simul_err_MW = max(max(min(value(P_ch), value(P_dis)))) * Sbase;

V_socp_pu     = sqrt(value(U_bus));
V_ac_ess      = zeros(N_bus, T);
Ploss_ac_MWh  = 0;
P_net_ess_MW  = Sbase * value(P_dis - P_ch);
P_pv_MW_val   = Sbase * value(P_pv);
mpopt = mpoption('verbose', 0, 'out.all', 0);
for t = 1:T
    mpc_t = mpc;
    mpc_t.bus(:, 3) = Pd_pu(:, t) * Sbase;
    mpc_t.bus(:, 4) = Qd_pu(:, t) * Sbase;
    mpc_t.bus(pv_buses,  3) = mpc_t.bus(pv_buses,  3) - P_pv_MW_val(:, t);
    mpc_t.bus(ess_buses, 3) = mpc_t.bus(ess_buses, 3) - P_net_ess_MW(:, t);
    res_t = runpf(mpc_t, mpopt);
    V_ac_ess(:, t) = res_t.bus(:, 8);
    Ploss_ac_MWh   = Ploss_ac_MWh + sum(real(get_losses(res_t)));
end
max_ac_v_err = max(max(abs(V_socp_pu - V_ac_ess)));

fprintf('\n================ 第一周：配电网储能 MISOCP 优化调度结果 ================\n');
fprintf('学号: %d | 算例: %s | 模型: %s | 求解器: %s\n', Stu_ID, case_name, model_type, solver_name);
fprintf('模型全天电能损耗: %.4f MWh | 交流潮流电能损耗: %.4f MWh | 弃光量: %.4f MWh | 关口购电成本: %.2f 元\n', ...
    value(Total_Loss_MWh), Ploss_ac_MWh, value(Total_Curtail_MWh), value(Total_Cost_Yuan));
fprintf('同时充放电最大重叠功率: %.2e MW | 最大二阶锥松弛间隙: %.2e p.u.\n', simul_err_MW, socp_gap);
fprintf('交流潮流节点电压范围: [%.4f, %.4f] p.u. | 模型与交流电压最大偏差: %.2e p.u.\n', ...
    min(V_ac_ess(:)), max(V_ac_ess(:)), max_ac_v_err);
if socp_gap > 1e-4
    fprintf('[教学提示] 当前模型(%s)目标函数不含网损正惩罚，高光伏时段节点电压触及上限，出现二阶锥松弛不精确与交流电压越限特例。\n', model_type);
end
fprintf('========================================================================\n');

P_net_MW_val = Sbase * value(P_dis - P_ch)';
SoC_pct_val  = value(SoC)' * 100;
line_styles  = {'-o', '-s', '-^'};
colors       = [0.00, 0.45, 0.74; 0.85, 0.33, 0.10; 0.47, 0.67, 0.19];

fig1 = figure('Name', '配电网储能日前SOCP调度结果', 'Color', 'w', 'Position', [120, 100, 720, 500]);
if isprop(fig1, 'Theme'), theme(fig1, 'light'); end

% 子图 (a)：各节点储能净放电有功功率
subplot(2, 1, 1);
hold on;
for k = 1:N_ess
    plot(1:T, P_net_MW_val(:, k), line_styles{k}, 'Color', colors(k, :), ...
        'LineWidth', 1.6, 'MarkerSize', 5, 'MarkerFaceColor', colors(k, :));
end
yline(0, '--k', 'LineWidth', 0.9);
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'FontName', 'Times New Roman', 'FontSize', 10.5, 'LineWidth', 1.0, ...
    'Box', 'on', 'TickDir', 'in', 'XTick', 0:4:24, 'GridLineStyle', '--', 'GridAlpha', 0.3, 'GridColor', [0.4, 0.4, 0.4]);
xlim([1, T]);
ylim([min([P_net_MW_val(:); -0.5]) - 0.25, max([P_net_MW_val(:); 0.5]) + 0.55]);
xlabel('\fontname{宋体}时间 \fontname{Times New Roman}{\itt}\rm{/h}', 'FontSize', 11.5, 'Color', 'k', 'Interpreter', 'tex');
ylabel('\fontname{宋体}储能净放电功率 \fontname{Times New Roman}{\itP}_{\rm{ess}}\rm{/MW}', 'FontSize', 11.5, 'Color', 'k', 'Interpreter', 'tex');
title(sprintf('\\fontname{宋体}(a) 各候选节点储能日前调度有功出力 (模型 \\fontname{Times New Roman}%s)', model_type), ...
    'FontSize', 11.5, 'FontWeight', 'normal', 'Color', 'k', 'Interpreter', 'tex');
leg_str_a = arrayfun(@(b) sprintf('\\fontname{宋体}节点 \\fontname{Times New Roman}%d \\fontname{宋体}储能', b), ...
    ess_buses, 'UniformOutput', false);
leg1 = legend(leg_str_a, 'Location', 'north', 'Orientation', 'horizontal', 'FontSize', 10, 'Interpreter', 'tex', 'Box', 'on');
set(leg1, 'Color', 'w', 'TextColor', 'k', 'EdgeColor', 'k');
grid on;

% 子图 (b)：各节点储能荷电状态 SoC 变化轨迹
subplot(2, 1, 2);
hold on;
for k = 1:N_ess
    plot(1:T, SoC_pct_val(:, k), line_styles{k}, 'Color', colors(k, :), ...
        'LineWidth', 1.6, 'MarkerSize', 5, 'MarkerFaceColor', colors(k, :));
end
yline(SoC_min * 100, ':k', 'LineWidth', 1.1);
yline(SoC_max * 100, ':r', 'LineWidth', 1.1);
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', 'FontName', 'Times New Roman', 'FontSize', 10.5, 'LineWidth', 1.0, ...
    'Box', 'on', 'TickDir', 'in', 'XTick', 0:4:24, 'GridLineStyle', '--', 'GridAlpha', 0.3, 'GridColor', [0.4, 0.4, 0.4]);
xlim([1, T]);
ylim([10, 98]);
xlabel('\fontname{宋体}时间 \fontname{Times New Roman}{\itt}\rm{/h}', 'FontSize', 11.5, 'Color', 'k', 'Interpreter', 'tex');
ylabel('\fontname{宋体}荷电状态 \fontname{Times New Roman}\rm{SoC}/%', 'FontSize', 11.5, 'Color', 'k', 'Interpreter', 'tex');
title('\fontname{宋体}(b) 各候选节点储能荷电状态 \fontname{Times New Roman}\rm{SoC} \fontname{宋体}时序变化曲线', ...
    'FontSize', 11.5, 'FontWeight', 'normal', 'Color', 'k', 'Interpreter', 'tex');
leg2 = legend(leg_str_a, 'Location', 'north', 'Orientation', 'horizontal', 'FontSize', 10, 'Interpreter', 'tex', 'Box', 'on');
set(leg2, 'Color', 'w', 'TextColor', 'k', 'EdgeColor', 'k');
grid on;

% 默认自动导出高质量白底 PNG (600 dpi)、矢量 PDF 与 MATLAB 源文件 FIG
exportgraphics(fig1, sprintf('Fig_Week1_Dispatch_%d.png', Stu_ID), 'Resolution', 600, 'BackgroundColor', 'white');
exportgraphics(fig1, sprintf('Fig_Week1_Dispatch_%d.pdf', Stu_ID), 'ContentType', 'vector', 'BackgroundColor', 'white');
savefig(fig1, sprintf('Fig_Week1_Dispatch_%d.fig', Stu_ID));
