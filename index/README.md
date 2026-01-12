<!-- README.md (or any GitHub-rendered Markdown file) -->

<h1>
  <code style="font-size: 200%; font-weight: bold;">equity_index</code>
  <img src="https://github.coecis.cornell.edu/CAT/equity/assets/19536/74379b17-f711-4d4f-8ed5-73290f0afd46"
       width="260" align="right" alt="Equity Index logo">
</h1>


<ul>
  <li><strong>Lead Developers</strong>: Timothy Fraser</li>
  <li><strong>Contributors</strong>: Yeonkyeong Gina Park, Yifei Li, Yuchen Tang, Oliver Gao</li>
  <li><strong>Institution</strong>: Gao Labs @ Cornell University</li>
  <li><strong>Description</strong>: A toolkit for measuring demographic disparities
      in exposure to transportation emissions across New York State.</li>
</ul>



## Welcome!

Welcome to `equity_index`! This repository contains code and documentation to compute **population-adjusted exposure equity indices** for transportation-related air pollution. Developed by Gao Labs at Cornell, this framework helps environmental planners, policy analysts, and researchers identify disparities across:

- **Race and ethnicity**
- **Household income**
- **Educational attainment**
- **Age demographics**

These indices are calculated using:
- **CATSERVER emissions estimates**
- **American Community Survey (ACS) demographic data**
- **Spatial buffers of road networks (1km exposure zones)**

The methodology is fully documented in the following study:

> Fraser, T., Park, Y.G., Li, Y., Tang, Y., & Gao, H.O. (2025). *Measuring the Burden of Emissions Exposure in American Neighborhoods.*


## What is `equity_index` used for?

- **Policy equity monitoring** — Compare how clean transportation investments impact disadvantaged groups.
- **Regional diagnostics** — Identify counties or metro areas with high exposure disparity.
- **Academic research** — Supplement environmental justice frameworks with quantitative metrics.
- **Data science workflows** — Integrate emissions and ACS data in a reproducible way.

## How to use `equity_index`

You can use our outputs to support **statewide equity metrics**, generate **Justice40-style maps**, or prioritize **transport investments**.  
Run the code to generate your own equity scores in R, or extend the scripts for cross-state analysis.  
Our modular `.R` scripts support:

- ACS census downloads
- Spatial buffer generation (`sf`)
- Equity index computation
- Optional map visualization

### Script Descriptions

- `make_data.R`: Downloads ACS demographic data (e.g., race, income, education, age) and stores it locally for processing.
- `make_shapes.R`: Performs spatial visualization by creating shapefiles for map outputs.
- `run_ny.R`: Chains the entire analysis workflow (data loading → equity index calculation → visualization → summary output), making it easy to conduct full-batch analysis for all counties in New York.
- `Functions.R`: Contains reusable functions for data processing, equity index computation, and statistical summarization; works like a utility library.
- `api_proxy.sh`: Sets up a proxy for the CATAPI server locally, useful for debugging or connecting to cloud-based data endpoints during development.

See `make_data.R`, `make_shapes.R`, `run_ny.R`, and other scripts for full workflows.



## Setup

To use `equity_index`, you will need an active RStudio coding environment.

Install required R packages:

```r
install.packages(c("tidycensus", "sf", "dplyr", "tigris", "ggplot2", "tidyr", "stringr"))
```

## Register your Census API key:

```r
library(tidycensus)
census_api_key("YOUR_API_KEY", install = TRUE)
```

## Run the pipeline

These three scripts represent the core workflow of the `equity_index` tool:

```r
# Step 1: Download and process ACS demographic data
source("make_data.R")

# Step 2: Generate spatial shapefiles for mapping
source("make_shapes.R")

# Step 3: Run full pipeline (load data → compute equity index → visualize → summarize results)
source("run_ny.R")
```

# Citation
If you use this code or framework, please cite:

Fraser, T., Park, Y.G., Li, Y., Tang, Y., & Gao, H.O. (2025). Measuring the Burden of Emissions Exposure in American Neighborhoods.

# Links
GitHub Organization: https://github.com/Gao-Labs

Research Group Website: https://gao.cee.cornell.edu/
