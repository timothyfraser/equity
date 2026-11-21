# The method in one page

Back to the [README](../README.md). The paper has the full description; the code is
[`index/functions.R`](../index/functions.R).

1. **Exposure zone.** Buffer every primary and secondary road (TIGER/Line, 2022) by 0.3 km.
2. **Who lives there.** Intersect census tracts (Census cartographic boundary polygons, 2022) with the zone and
   apportion each tract's ACS group counts by the share of the tract's area inside the zone (area weighting).
3. **Emissions per exposed resident.** Divide each county's on-road PM<sub>2.5</sub> (CAT, 2022) by the number of
   people living in its zones, so each exposed resident in a county carries the same share of that county's emissions.
4. **Relative burden.** Within a region, take each group's share of the emissions burden (*e<sub>g</sub>*, from its
   residents inside the zones) and its share of the region's population (*p<sub>g</sub>*, from county ACS totals).
   Divide *e<sub>g</sub>* by *p<sub>g</sub>* and rescale these ratios to sum to 1 across groups. Call the result
   *s<sub>g</sub>*. A group with no members in the region is left out, not scored zero.
5. **Index.** The equal-group index for *n* groups is
   *I* = 1 − *n* / (2(*n* − 1)) × Σ<sub>g</sub> |*s<sub>g</sub>* − 1/*n*|.
   It is 1 when every group carries the same relative burden and 0 when one group carries all of it
   (`get_index()` in [`index/functions.R`](../index/functions.R)). A population-weighted companion,
   1 − ½ Σ<sub>g</sub> |*e<sub>g</sub>* − *p<sub>g</sub>*| over each group's emissions and population shares, is also
   computed for reviewers; the paper reports the equal-group index. The overall score in Table 2 is the unweighted
   mean of the four dimension scores.
6. **Is it more than chance?** An exact permutation test shuffles group labels among residents while holding every
   tract's population and every group's total fixed (1,000 draws), and reports how often chance alone is as uneven as
   what we observe.
7. **How much is sampling error?** Every ACS cell is redrawn 500 times from its published margin of error, and the
   index is rescored to give a 95% interval.

The national extension repeats steps 1 to 7 for each multi-county MPO, assigning each tract to the MPO that contains
its interior point; a county partly inside an MPO keeps its whole-county emissions rate. Details:
[`national/README.md`](../national/README.md).
