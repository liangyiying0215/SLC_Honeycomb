# SLC_Honeycomb

This repository provides the implementation of a unified measurement framework for defect characterization across micro-, meso-, and macro-scales in discontinuous honeycomb structures. The framework is based on a structured light imaging system and supports consistent data acquisition and analysis within a unified coordinate system.

---

## Related Paper

This repository accompanies the following paper:

**[A multi-scale structured-light camera system for quantifying machining quality of honeycomb composites]**
*IEEE Transactions on Instrumentation and Measurement* (under review)

The code supports reproduction of the main results presented in:

* Microscale analysis: fractal-based burr characterization
* Mesoscale analysis: defect detection (tearing, crushing, deformation)
* Macroscale analysis: surface reconstruction and geometric evaluation

---

## Repository Structure

```
.
├── microscale/        % Fractal dimension (FD) computation and analysis
├── mesoscale/         % Defect detection and evaluation
├── macroscale/        % Surface reconstruction and fitting
├── data/              % Example datasets
├── results/           % Example outputs corresponding to paper figures
└── utils/             % Auxiliary functions
```

---

## Requirements

* MATLAB R2022a or later
* Image Processing Toolbox
* Python

---

## Quick Start

1. Clone the repository:

```bash
git clone https://github.com/yourname/yourrepo.git
```

2. Open MATLAB and set the working directory:

```matlab
cd('yourrepo')
```

3. Run example scripts:

```matlab
run('microscale/demo_fd.m')           % Microscale FD analysis
run('mesoscale/demo_detection.m')     % Mesoscale defect detection
run('macroscale/demo_reconstruction.m') % Macroscale reconstruction
```

---

## Module Description

### Microscale (Burr Characterization)

* Fractal Dimension (FD) is used to quantify burr morphology
* Includes binarization, contour extraction, and box-counting method
* Sensitivity to threshold and noise can be evaluated

### Mesoscale (Defect Detection)

* Supports detection of:

  * Tearing defects
  * Crushing defects
  * Cell deformation
* Includes both region-based and pixel-level evaluation
* Outputs accuracy, F1 score, and statistical consistency

### Macroscale (Surface Reconstruction)

* Surface fitting based on structured light data
* Provides geometric reconstruction and error evaluation (RMSE)
* Applicable to curved and inclined surfaces

---

## Data

Example datasets are provided in the `data/` folder.

Notes:

* The datasets included are representative samples.
* Full datasets used in the paper may be larger and are not fully included due to size limitations.
* Users can replace input data with their own measurements following the same format.

---

## Reproducibility

The following scripts correspond to representative results in the paper:

* Fig. X → `microscale/demo_fd.m`
* Fig. X → `mesoscale/demo_tearing.m`
* Fig. X → `mesoscale/demo_crushing.m`
* Fig. X → `macroscale/demo_surface.m`

Due to stochastic factors (e.g., threshold selection, noise), minor variations in numerical results may occur.



## Notes

* Some functions (e.g., ROI selection) may require manual interaction.
* Ensure all paths are correctly set before running scripts.
* Custom helper functions are located in the `utils/` directory.


## Citation

If you find this work useful, please cite.

## License

This project is licensed under the MIT License.
