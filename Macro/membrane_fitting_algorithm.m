function membrane_fitting_algorithm()
    %% 1. 生成模拟的“蜂窝材料”点云数据 (带有曲面、孔洞和侧壁)
    disp('正在生成模拟点云数据...');
    [X, Y] = meshgrid(0:0.1:10, 0:0.1:10);
    Z = sin(X)*0.5 + cos(Y)*0.5 + 5; % 基础曲面
    
    % 挖去孔洞，模拟蜂窝结构
    mask = false(size(X));
    for cx = 1:1.5:9
        for cy = 1:1.5:9
            dist = (X - cx).^2 + (Y - cy).^2;
            mask(dist < 0.4) = true; % 孔洞半径
        end
    end
    
    % 分离表面点和侧壁点
    X_surf = X(~mask); Y_surf = Y(~mask); Z_surf = Z(~mask);
    X_wall = X(mask);  Y_wall = Y(mask);  Z_wall = Z(mask) - 1.5; % 侧壁点Z值较低
    
    ptCloud = [X_surf(:), Y_surf(:), Z_surf(:); X_wall(:), Y_wall(:), Z_wall(:)];
    % 加入随机噪声
    ptCloud(:,3) = ptCloud(:,3) + randn(size(ptCloud(:,3))) * 0.03; 
    max_z_data = max(ptCloud(:,3));

    %% 2. 初始化“种子” (对应流程图：初始化“种子”)
    disp('初始化种子网格...');
    grid_res = 0.4; % 种子的数据密度，可自主设定
    x_edges = min(ptCloud(:,1)) : grid_res : max(ptCloud(:,1));
    y_edges = min(ptCloud(:,2)) : grid_res : max(ptCloud(:,2));
    [X_grid, Y_grid] = meshgrid(x_edges, y_edges);
    [Ny, Nx] = size(X_grid);
    
    % 初始化在点云面轮廓的下方
    Z_grid = ones(Ny, Nx) * (min(ptCloud(:,3)) - 0.5); 
    step_size = 0.1; % 步长选为0.1

    %% 3. 数据预处理：将点云分配到网格单元中，极大提升计算速度
    % 模拟流程图中的“某种子与周围四个构成的面”
    dx = grid_res; dy = grid_res;
    cell_data = cell(Ny-1, Nx-1);
    for c_i = 1:Nx-1
        for c_j = 1:Ny-1
            x_min = X_grid(1, c_i); x_max = X_grid(1, c_i+1);
            y_min = Y_grid(c_j, 1); y_max = Y_grid(c_j+1, 1);
            
            % 找到落入该网格单元的点
            idx = ptCloud(:,1) >= x_min & ptCloud(:,1) <= x_max & ...
                  ptCloud(:,2) >= y_min & ptCloud(:,2) <= y_max;
            pts = ptCloud(idx, :);
            
            if ~isempty(pts)
                % 计算局部归一化坐标 u, v (用于双线性插值表示膜的面Z)
                u = (pts(:,1) - x_min) / dx;
                v = (pts(:,2) - y_min) / dy;
                cell_data{c_j, c_i} = [pts(:,1), pts(:,2), pts(:,3), u, v];
            end
        end
    end

    %% 4. 迭代更新 (核心算法流程)
    disp('开始迭代更新种子...');
    active_seeds = true(Ny, Nx); % 需要更新的“种子”
    iter = 0;
    
    % 对应流程图：所有种子的更新度均为0 时退出循环
    while any(active_seeds(:))
        iter = iter + 1;
        
        for i = 1:Nx
            for j = 1:Ny
                if ~active_seeds(j,i)
                    continue; 
                end
                
                % 对应流程图：某“种子”Z坐标以0.1步长增长
                Z_grid(j,i) = Z_grid(j,i) + step_size;
                
                % 安全限制：防止大孔洞中心无限生长
                if Z_grid(j,i) > max_z_data + 0.5
                    Z_grid(j,i) = Z_grid(j,i) - step_size;
                    active_seeds(j,i) = false;
                    continue;
                end
                
                collision = false;
                
                % 对应流程图：判断 数据点Z > 膜面Z 
                % 检查该种子周围的4个网格单元（即相关的三角形/面）
                for c_i = max(1, i-1) : min(Nx-1, i)
                    for c_j = max(1, j-1) : min(Ny-1, j)
                        data = cell_data{c_j, c_i};
                        if isempty(data), continue; end
                        
                        z_data = data(:,3);
                        u = data(:,4); 
                        v = data(:,5);
                        
                        % 提取当前4个顶点的Z值
                        z00 = Z_grid(c_j, c_i);
                        z10 = Z_grid(c_j, c_i+1);
                        z01 = Z_grid(c_j+1, c_i);
                        z11 = Z_grid(c_j+1, c_i+1);
                        
                        % 计算膜在数据点(x,y)处的Z值 (双线性面拟合)
                        z_mem = (1-u).*(1-v).*z00 + u.*(1-v).*z10 + (1-u).*v.*z01 + u.*v.*z11;
                        
                        % 如果膜长得比数据点还高了（发生碰撞穿透）
                        if any(z_mem > z_data)
                            collision = true;
                            break;
                        end
                    end
                    if collision, break; end
                end
                
                % 对应流程图的分支处理
                if collision
                    % N, 退0.1，该种子完成更新
                    Z_grid(j,i) = Z_grid(j,i) - step_size;
                    active_seeds(j,i) = false;
                else
                    % Y，该种子这轮更新成功，等待下一轮继续
                end
            end
        end
    end
    disp(['迭代完成！共进行了 ', num2str(iter), ' 次全局迭代。']);

    %% 5. 提取面型点云 (把“膜”附近的有用点云数据保存)
    disp('正在提取有效面型点云...');
    extracted_pts = [];
    threshold = 0.3; % 膜附近的距离阈值
    
    for c_i = 1:Nx-1
        for c_j = 1:Ny-1
            data = cell_data{c_j, c_i};
            if isempty(data), continue; end
            
            x = data(:,1); y = data(:,2); z_data = data(:,3);
            u = data(:,4); v = data(:,5);
            
            z00 = Z_grid(c_j, c_i); z10 = Z_grid(c_j, c_i+1);
            z01 = Z_grid(c_j+1, c_i); z11 = Z_grid(c_j+1, c_i+1);
            z_mem = (1-u).*(1-v).*z00 + u.*(1-v).*z10 + (1-u).*v.*z01 + u.*v.*z11;
            
            % 筛选出距离膜较近的点，去除深孔侧壁点
            keep_idx = abs(z_data - z_mem) < threshold; 
            extracted_pts = [extracted_pts; x(keep_idx), y(keep_idx), z_data(keep_idx)];
        end
    end

    %% 6. 可视化结果
    figure('Color', 'w', 'Position', [100, 100, 900, 400]);
    
    % 子图1：原始点云与拟合的膜
    subplot(1,2,1);
    scatter3(ptCloud(:,1), ptCloud(:,2), ptCloud(:,3), 5, [0.6 0.6 0.6], 'filled'); % 灰色原点云
    hold on;
    surf(X_grid, Y_grid, Z_grid, 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', 'cyan');
    title('原始点云与拟合"膜"');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    view(-30, 45); grid on;
    
    % 子图2：提取出的干净面型点云
    subplot(1,2,2);
    scatter3(extracted_pts(:,1), extracted_pts(:,2), extracted_pts(:,3), 10, 'b', 'filled');
    title('最终提取的表面点云 (滤除侧壁)');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    view(-30, 45); grid on;
    axis([0 10 0 10 min(Z_surf(:))-1 max(Z_surf(:))+1]);
end