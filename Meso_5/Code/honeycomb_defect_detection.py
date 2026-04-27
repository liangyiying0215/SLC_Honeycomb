import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np

# ==========================================
# 1. 撕裂缺陷检测：并联语义分割网络
# ==========================================
class ParallelTearSegmentationNet(nn.Module):
    def __init__(self, in_channels=1, num_classes=3):
        """
        针对芳纶纸蜂窝材料撕裂缺陷的并联语义分割网络
        :param in_channels: 输入图像通道数（单通道线图或灰度图设为1，RGB设为3）
        :param num_classes: 分类数（0:镂空, 1:正常壁, 2:撕裂）
        """
        super(ParallelTearSegmentationNet, self).__init__()
        
        # 分支1：浅层网络，保留较大的特征图，精细度高
        self.branch1 = nn.Sequential(
            nn.Conv2d(in_channels, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True)
        )
        
        # 分支2：中等深度，下采样获取中等感受野
        self.branch2 = nn.Sequential(
            nn.MaxPool2d(kernel_size=4, stride=4),
            nn.Conv2d(in_channels, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.Conv2d(64, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True)
        )
        
        # 分支3：深层网络，大幅下采样获取大感受野，正确度高
        self.branch3 = nn.Sequential(
            nn.MaxPool2d(kernel_size=8, stride=8),
            nn.Conv2d(in_channels, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),
            nn.Conv2d(128, 256, kernel_size=3, padding=1),
            nn.BatchNorm2d(256),
            nn.ReLU(inplace=True)
        )
        
        # 融合层：将三个分支的特征融合，输出分类结果
        self.fusion_conv = nn.Sequential(
            nn.Conv2d(64 + 128 + 256, 128, kernel_size=3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(inplace=True),
            nn.Conv2d(128, num_classes, kernel_size=1)
        )

    def forward(self, x):
        input_size = x.size()[2:] # 获取原始图像的 H, W
        
        # 获取三个并联分支的特征图
        out1 = self.branch1(x)
        out2 = self.branch2(x)
        out3 = self.branch3(x)
        
        # 将分支2和分支3的特征图上采样（双线性插值）到分支1的尺寸
        out2_up = F.interpolate(out2, size=input_size, mode='bilinear', align_corners=False)
        out3_up = F.interpolate(out3, size=input_size, mode='bilinear', align_corners=False)
        
        # 在通道维度拼接
        concat_features = torch.cat([out1, out2_up, out3_up], dim=1)
        
        # 融合
        logits = self.fusion_conv(concat_features)
        
        # 输出 LogSoftmax 分类结果
        return F.log_softmax(logits, dim=1)

# ==========================================
# 2. 压溃缺陷检测：异常检测特征提取网络
# ==========================================
class CrushFeatureExtractor(nn.Module):
    def __init__(self, in_channels=1):
        """
        压溃缺陷异常检测的特征提取网络 (串联结构)
        """
        super(CrushFeatureExtractor, self).__init__()
        
        self.features = nn.Sequential(
            nn.Conv2d(in_channels, 16, kernel_size=3, stride=2, padding=1),
            nn.BatchNorm2d(16),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2),
            
            nn.Conv2d(16, 32, kernel_size=3, stride=2, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(kernel_size=2, stride=2),
            
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.AdaptiveAvgPool2d((1, 1)) # 确保输出空间维度为 1x1
        )
        
        # 提取 64 维特征向量，用于后续拟合 64 维高斯模型
        self.fc_features = nn.Linear(64, 64) 
        
        # 二分类输出 (0: 异常压溃, 1: 正常)
        self.classifier = nn.Linear(64, 2) 

    def forward(self, x, extract_features=False):
        x = self.features(x)
        x = torch.flatten(x, 1)
        
        # 获取 64维特征向量
        feature_vector = self.fc_features(x) 
        
        if extract_features:
            # 实际推理/异常检测拟合时，只需返回此 64 维特征
            return feature_vector 
            
        # 训练时，输出分类结果进行 loss 计算
        logits = self.classifier(F.relu(feature_vector))
        return logits

# ==========================================
# 3. 指标评估工具
# ==========================================
def calculate_metrics(preds, template_based_targets, num_classes=3):
    """
    计算验证集上的 Accuracy, IoU, Precision
    :param preds: 模型的预测张量，形状为 (N, C, H, W) 或 (N, H, W)
    :param template_based_targets: 模板/三坐标基准的真实标签，形状为 (N, H, W)
    """
    if preds.dim() == 4:
        # 如果是模型输出的概率图，取概率最大的通道作为预测类别
        preds = torch.argmax(preds, dim=1)
        
    preds = preds.cpu().numpy().flatten()
    targets = template_based_targets.cpu().numpy().flatten()
    
    metrics = {}
    
    # 整体准确率 (Accuracy)
    accuracy = np.mean(preds == targets)
    metrics['Accuracy'] = accuracy
    
    # 计算每个类别的 IoU 和 Precision
    for cls in range(num_classes):
        tp = np.sum((preds == cls) & (targets == cls))
        fp = np.sum((preds == cls) & (targets != cls))
        fn = np.sum((preds != cls) & (targets == cls))
        
        # Precision = TP / (TP + FP)
        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        
        # IoU = TP / (TP + FP + FN)
        iou = tp / (tp + fp + fn) if (tp + fp + fn) > 0 else 0.0
        
        metrics[f'Class_{cls}_Precision'] = precision
        metrics[f'Class_{cls}_IoU'] = iou
        
    return metrics

# ==========================================
# 4. 运行与测试入口
# ==========================================
if __name__ == '__main__':
    def count_parameters(model):
        """计算模型总参数量，并转换为 Mb 大小 (粗略估计：1个float32占4字节)"""
        params = sum(p.numel() for p in model.parameters() if p.requires_grad)
        size_mb = params * 4 / (1024 ** 2)
        return params, size_mb

    print("=== 初始化芳纶纸蜂窝材料缺陷检测算法 ===")
    
    # 1. 测试撕裂缺陷并联网络
    print("\n[1] 正在测试撕裂缺陷并联网络 (ParallelTearSegmentationNet)...")
    tear_net = ParallelTearSegmentationNet(in_channels=1, num_classes=3)
    tear_params, tear_size = count_parameters(tear_net)
    print(f"    参数总量: {tear_params:,} 个")
    print(f"    估计体积: {tear_size:.2f} MB")
    
    # 模拟输入一个 360x400 的单通道 Y形结构 切片
    dummy_tear_input = torch.randn(1, 1, 360, 400) 
    tear_output = tear_net(dummy_tear_input)
    print(f"    输入维度: {dummy_tear_input.shape}")
    print(f"    输出维度: {tear_output.shape}  -> (Batch, Classes, Height, Width)")

    # 2. 测试压溃缺陷特征提取网络
    print("\n[2] 正在测试压溃缺陷特征提取网络 (CrushFeatureExtractor)...")
    crush_net = CrushFeatureExtractor(in_channels=1)
    
    # 模拟输入一个较小的子图
    dummy_crush_input = torch.randn(1, 1, 128, 128)
    
    # 训练模式输出
    train_output = crush_net(dummy_crush_input, extract_features=False)
    # 异常检测推理模式输出 (提取64维特征)
    feature_output = crush_net(dummy_crush_input, extract_features=True)
    
    print(f"    输入维度: {dummy_crush_input.shape}")
    print(f"    训练模式输出维度 (分类): {train_output.shape}")
    print(f"    推理模式输出维度 (特征): {feature_output.shape} -> (用于构建64维高斯模型)")

    # 3. 测试评价指标模块
    print("\n[3] 正在测试指标评估计算...")
    # 模拟预测结果和基于模板/CMM的基准数据 (比如尺寸 100x100 的切片)
    dummy_preds = torch.randint(0, 3, (1, 100, 100))
    dummy_targets = torch.randint(0, 3, (1, 100, 100))
    metrics_result = calculate_metrics(dummy_preds, dummy_targets, num_classes=3)
    
    print(f"    测试计算结果:")
    print(f"    - 整体 Accuracy: {metrics_result['Accuracy']:.4f}")
    print(f"    - 类别2(撕裂) IoU: {metrics_result['Class_2_IoU']:.4f}")
    print(f"    - 类别2(撕裂) Precision: {metrics_result['Class_2_Precision']:.4f}")
    print("\n测试完成，代码无运行错误。")