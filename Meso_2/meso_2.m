clc; clear; close all;

% 1. 设置文件读取索引 (1-5号为A1-A5, 6-10号为B1-B5)
idx_A = [1, 2, 3, 4, 5]; 
idx_B = [6, 7, 8, 9, 10]; 

masksA = cell(1, 5);
masksB = cell(1, 5);
iouMatrix = zeros(5, 5);

% 2. 批量提取掩膜
fprintf('正在处理数据并计算交叉矩阵...\n');
for i = 1:5
    imgA = imread([num2str(idx_A(i)), '.png']);
    masksA{i} = extractYellowMask(imgA);
    imgB = imread([num2str(idx_B(i)), '.png']);
    masksB{i} = extractYellowMask(imgB);
end

% 3. 计算 5x5 全交叉 IoU 矩阵
for i = 1:5
    for j = 1:5
        mA = masksA{i}; mB = masksB{j};
        if size(mA) ~= size(mB), mB = imresize(mB, size(mA), 'nearest'); end
        iouMatrix(i,j) = sum(mA & mB, 'all') / sum(mA | mB, 'all');
    end
end

% --- 统计分析部分 ---
avgIoU = mean(iouMatrix, 'all');           % 计算矩阵中所有 25 个元素的平均值
stdIoU = std(iouMatrix(:));                % 计算全矩阵的标准差，反映一致性的稳定性
minIoU = min(iouMatrix, [], 'all');        % 找到最差的一组对比
maxIoU = max(iouMatrix, [], 'all');        % 找到最好的一组对比

fprintf('\n========= 标注一致性统计分析 =========\n');
fprintf('全交叉对比总数: %d 组\n', numel(iouMatrix));
fprintf('平均 IoU (Mean): %.4f\n', avgIoU);
fprintf('标准差 (SD):     %.4f\n', stdIoU);
fprintf('最小值 (Min):    %.4f\n', minIoU);
fprintf('最大值 (Max):    %.4f\n', maxIoU);
fprintf('======================================\n');

% --- 保存统计结果 TXT (文件名即平均值，不带小数点) ---
txtFileName = sprintf('%.0f.txt', avgIoU * 10000); % 例如 0.7099 保存为 7099.txt
fid = fopen(txtFileName, 'w');
fprintf(fid, 'Average IoU: %.4f\nStandard Deviation: %.4f\n', avgIoU, stdIoU);
fclose(fid);
fprintf('统计结果已保存至文件: %s\n', txtFileName);


%% --- 图 1：5x5 全交叉关联矩阵 ---
fig_matrix = figure('Color', 'w', 'Name', 'IoU Matrix Analysis');
h = heatmap({'B1','B2','B3','B4','B5'}, {'A1','A2','A3','A4','A5'}, iouMatrix);
h.Title = 'IoU matrix between Volunteer A (A1–A5) and Volunteer B (B1–B5)';
h.Colormap = summer;
saveas(fig_matrix, 'Result_IoU_Matrix.png'); % 保存矩阵图
fprintf('矩阵图已保存为 Result_IoU_Matrix.png\n');

%% --- 图 2-6：循环生成并保存各组对比图 ---
for i = 1:5
    % 文件名字符串
    figFileName = sprintf('Comparision_between_A%d_and_Volunteer_B', i);
    
    fig_comp = figure('Color', 'w', 'Name', figFileName, 'Units', 'normalized', 'Position', [0.1, 0.2, 0.8, 0.3]);
    
    t = tiledlayout(1, 5, 'TileSpacing', 'compact', 'Padding', 'tight');
    
    % --- 修复位置：添加 'Interpreter', 'none' ---
    % 同时把 figFileName 中的下划线替换成空格，显示更美观
    displayTitle = [strrep(figFileName, '_', ' '), ' (Green: A', num2str(i), ', Pink: B, White: overlap)'];
    title(t, displayTitle, 'FontSize', 14, 'Interpreter', 'none'); 
    
    for j = 1:5
        nexttile;
        imshowpair(masksA{i}, masksB{j}, 'falsecolor');
        
        % 这里的 A_i 和 B_j 如果想保留下标效果就不用改，
        % 如果也想让它们平齐显示，可以加上 'Interpreter', 'none'
        title(['A_', num2str(i), ' vs B_', num2str(j)], 'FontSize', 11, 'Interpreter', 'none');
        xlabel(['IoU: ', num2str(iouMatrix(i,j), '%.4f')], 'FontWeight', 'bold');
    end
    
    % 保存图片
    saveas(fig_comp, [figFileName, '.png']);
    fprintf('A%d 序列对比图已保存为 %s.png\n', i, figFileName);
end

%% 辅助函数：提取掩膜
function mask = extractYellowMask(img)
    if size(img, 3) == 4, img = img(:,:,1:3); end
    img = double(img);
    R = img(:,:,1); G = img(:,:,2); B = img(:,:,3);
    % 黄色提取阈值 (根据实际光照可微调)
    yellowPixels = (R > 135 & G > 135 & B < 130); 
    se = strel('disk', 2);
    binaryLine = imdilate(yellowPixels, se); 
    mask = imfill(binaryLine, 'holes');
    mask = bwareafilt(logical(mask), 1); 
end