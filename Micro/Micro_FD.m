clear; clc; close all;

%% ================== 1. 读取图像 ==================
[file_name, folder_path] = uigetfile({'*.jpg;*.png;*.bmp;*.tif'}, '选择图像');
if isequal(file_name,0), return; end
img_rgb = imread(fullfile(folder_path, file_name));
img_full = uint8(img_rgb(:,:,1)); % 强制转单通道灰度

%% ================== 2. ROI 选择 (升级版) ==================
fprintf('\n--- ROI 选择模式 ---\n');
fprintf('1: 交互式拉框 (手动划定区域)\n');
fprintf('2: 快速粘贴坐标 (用于重复实验)\n');
fprintf('3: 自动读取上次 ROI\n');
mode = input('请选择模式: ');

if mode == 1
    fig_roi = figure('Name','请手动拉出一个正方形框','NumberTitle','off');
    imshow(img_full); title('鼠标拉出区域，双击框内确认');
    
    % 创建一个强制 1:1 比例的正方形拉框工具
    roi_tool = drawrectangle('AspectRatio', 1, 'Label', '双击确认');
    
    % 等待用户双击
    wait(roi_tool);
    pos = round(roi_tool.Position); % 获取 [x_min, y_min, width, height]
    close(fig_roi);
    
    % 转换成你习惯的 x1,y1,x2,y2 格式
    x1 = pos(1); y1 = pos(2);
    x2 = x1 + pos(3); y2 = y1 + pos(4);
    
    % ★ 核心：输出一串可以直接复制的格式
    fprintf('\n--------------------------------------------------\n');
    fprintf('★ 坐标已生成！下次选模式 2 直接粘贴下面括号里的内容：\n');
    fprintf('[%d, %d, %d, %d]\n', x1, y1, x2, y2);
    fprintf('--------------------------------------------------\n\n');

elseif mode == 2
    % ★ 核心：支持整串输入 [x1, y1, x2, y2]
    coords = input('请直接粘贴坐标数组 [x1, y1, x2, y2]: ');
    x1 = coords(1); y1 = coords(2); x2 = coords(3); y2 = coords(4);
    
elseif mode == 3
    if exist('roi_params.mat','file')
        load('roi_params.mat');
        r1=roi_params(1); r2=roi_params(2); c1=roi_params(3); c2=roi_params(4);
    else
        error('未找到历史ROI记录');
    end
end

% 统一计算裁剪区域并保存
if mode ~= 3
    L = round(min(abs(x2-x1), abs(y2-y1)));
    c1 = min(x1, x2); r1 = min(y1, y2);
    c2 = c1 + L; r2 = r1 + L;
    
    % 防越界
    [H, W] = size(img_full);
    c2 = min(c2, W); r2 = min(r2, H);
    
    roi_params = [r1, r2, c1, c2];
    save('roi_params.mat','roi_params');
end

img = img_full(r1:r2, c1:c2);
fprintf('成功裁剪 ROI: %d x %d 像素\n', size(img,2), size(img,1));

%% ================== 3. 图像预处理 (统一逻辑) ==================
baseline_T = 120;
img_bin_main = img <= baseline_T;
img_bin_main = bwareaopen(img_bin_main, 50); % 去除零星噪点

% 【关键：使用骨架化替代 Canny】
img_skel_main = bwmorph(img_bin_main, 'skel', Inf); 

figure('Name','特征提取预览','NumberTitle','off');
subplot(1,2,1); imshow(img); title('原始 ROI');
subplot(1,2,2); imshow(img_skel_main); title('骨架化边缘 (用于 FD)');

%% ================== 4. 主 FD 计算 ==================
fd_main = calculate_fd(img_skel_main, true); 
fprintf('\n>>> 原始图像主 FD = %.4f\n', fd_main);


%% ================== 5. 阈值敏感性 ==================
thresholds = [118 119 120 121 122];
for T = thresholds
    % 1. 二值化
    temp_bin = img <= T;
    % 2. 降噪
    temp_bin = bwareaopen(temp_bin, 50);
    % 3. 骨架化 (这是降到 1.2 的核心)
    temp_skel = bwmorph(temp_bin, 'skel', Inf);
    
    fd = calculate_fd(temp_skel, false);
    fprintf('阈值 T=%d \t %.4f\n', T, fd);
end

%% ================== 6. 光照变化 ==================
delta = 10;
% 变亮
bin_bright = bwmorph(bwareaopen(img + delta <= 120, 50), 'skel', Inf);
fd_bright = calculate_fd(bin_bright, false);
% 变暗
bin_dark = bwmorph(bwareaopen(img - delta <= 120, 50), 'skel', Inf);
fd_dark = calculate_fd(bin_dark, false);

fprintf('亮度 +10 \t %.4f\n', fd_bright);
fprintf('亮度 -10 \t %.4f\n', fd_dark);

%% ================== 7. 噪声干扰 ==================
sigma = 5;
noise_img = uint8(double(img) + sigma * randn(size(img)));
bin_noise = bwmorph(bwareaopen(noise_img <= 120, 50), 'skel', Inf);
fd_noise = calculate_fd(bin_noise, false);
fprintf('噪声干扰 \t %.4f\n', fd_noise);
fprintf('--- 数据输出完毕 ---\n');

%% =========================================================
% 函数区
% =========================================================
function fd = calculate_fd(img_binary, showPlot)
    img_binary = logical(img_binary);
    [rows, cols] = size(img_binary);
    
    logR = 0.8 : 0.1 : 2.3; 
    logN = zeros(size(logR));
    logInvR = zeros(size(logR));
    
    for k = 1:length(logR)
        R = round(10^(logR(k)));
        N = 0;
        nr = ceil(rows / R); nc = ceil(cols / R);
        for i = 1:nr
            for j = 1:nc
                r_idx = (i-1)*R+1 : min(i*R, rows);
                c_idx = (j-1)*R+1 : min(j*R, cols);
                if any(img_binary(r_idx, c_idx), 'all'), N = N + 1; end
            end
        end
        logN(k) = log10(N);
        logInvR(k) = -log10(R);
    end
    
    % 拟合
    idx = 5:length(logR)-2; % 选取中间线性度好的段
    p = polyfit(logInvR(idx), logN(idx), 1);
    fd = p(1);
    
    % 如果 showPlot 为真，则画图（解决你“图太多”的问题）
    if showPlot
        figure('Name','双对数拟合曲线','NumberTitle','off');
        plot(logInvR, logN, 'ko', 'MarkerFaceColor','w'); hold on;
        plot(logInvR(idx), polyval(p, logInvR(idx)), 'r-', 'LineWidth', 2);
        grid on; xlabel('-log(R)'); ylabel('log(N)');
        title(['Box-counting FD = ', num2str(fd)]);
    end
end