# Neural Network Architectures for SLC-MSM System

This documentation describes the deep learning models used for automated defect detection in Nomex Honeycomb Composites (NHCs) as presented in the TIM research paper.

## 1. Tearing Detection: Parallel FCN
A parallel Fully Convolutional Network (FCN) is used for pixel-level semantic segmentation of tearing defects[cite: 207, 891].

### Architectural Specifications
The network processes Y-shaped sub-images through three parallel branches with varying receptive fields to capture multi-scale features[cite: 208, 892].

| Stage | Branch 1 (Fine-grained) | Branch 2 (Mesoscale) | Branch 3 (Global) |
| :--- | :--- | :--- | :--- |
| **Preprocessing** | - | AdaptiveAvgPool(45, 50) | AdaptiveAvgPool(23, 25) |
| **Layer 1** | C(3, 64, 3, 1, 1) | C(3, 64, 5, 2, 1) | C(3, 64, 7, 3, 1) |
| **Layer 2** | C(64, 128, 3, 1, 1) | C(64, 128, 5, 2, 1) | C(64, 128, 7, 3, 1) |
| **Layer 3** | C(128, 256, 3, 1, 1) | C(128, 256, 5, 2, 1) | C(128, 256, 7, 3, 1) |
| **Post-scaling** | - | UP(360, 400) | UP(360, 400) |

*Notation: C(in, out, kernel, stride, padding); [cite_start]UP: Upsampling.* [cite: 185-197, 893]

### Feature Fusion & Output
- **Fusion:** The three branches are concatenated (768 channels) and passed through:
  - Conv2d(768, 256, 3, 1, 1) [cite: 197, 894]
  - Conv2d(256, 128, 3, 1, 1) [cite: 227, 894]
  - Conv2d(128, 64, 3, 1, 1) [cite: 237, 894]
- **Output Layer:** Conv2d(64, 3, 1, 0, 1) followed by Log-softmax for 3-class classification (Hollow, Wall, Tear)[cite: 211, 238, 894].
- **Model Size:** 21.2 MB[cite: 214, 895].

---

## 2. Crushing Detection: CNN Feature Extractor
For crushing defects, a CNN serves as a feature extractor to generate high-dimensional vectors for Gaussian anomaly detection[cite: 218, 902].

### Feature Extraction Layers
The input is a normalized $224 \times 224 \times 3$ RGB image[cite: 911].

1. **Conv-1:** Output $112 \times 112 \times 64$ (Convolution + ReLU + Pooling)[cite: 911].
2. **Conv-2:** Output $56 \times 56 \times 128$ (Convolution + ReLU + Pooling)[cite: 911].
3. **Conv-3:** Output $28 \times 28 \times 128$ (Convolution + ReLU + Pooling)[cite: 911].
4. **Conv-4:** Output $14 \times 14 \times 128$ (Convolution + ReLU + Pooling)[cite: 911].
5. **Flatten:** Vectorizes to 25,088 features[cite: 911].
6. **Dense-1:** 1000 nodes for feature integration[cite: 911].
7. **Dense-2 (Latent):** **64-dimensional feature vector** used for the Gaussian model.

---

## Performance Summary
- **Tearing Accuracy:** 96.6% [cite: 373, 1085]
- **Crushing Accuracy:** 98.9% [cite: 432, 1086]
- **Cell Deformation Accuracy:** 96.1% (Avg.) [cite: 480, 1087]
- **FCN Processing Time:** ~10s per image [cite: 417, 998]
