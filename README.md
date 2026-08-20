  # Prescriptive Analytics and Decision Optimisation (OPL / CPLEX)

Two optimisation models built in **IBM ILOG CPLEX Optimization Studio** for BUSB7030 *Prescriptive Analytics and Decision Optimisation*, MSc Business Analytics, University of Kent.

Both tasks go the full route: business problem, formal mathematical formulation, implementation in OPL with data separated from the model, optimal solution, and interpretation of what the numbers mean for the decision maker.

![OPL](https://img.shields.io/badge/IBM%20ILOG-CPLEX%20OPL-052FAD)
![Model](https://img.shields.io/badge/models-MILP%20%7C%20Assignment%20%7C%20Facility%20Location-1f6feb)
![Data](https://img.shields.io/badge/data-Excel%20SheetConnection-217346)
![Status](https://img.shields.io/badge/status-submitted-success)

| | Task | Model class | Optimal value |
|:--|:--|:--|:--|
| **Q1** | Assigning airline crews to return flights | Binary assignment problem | **27 hours** of total layover |
| **Q2** | Locating temporary COVID-19 healthcare facilities | Mixed-integer facility location with Big M | **$1,521,653.42** total system cost |

---

## Repository structure

```
prescriptive-analytics-opl/
├── report/
│   └── nuriev-busb7030-report.pdf          Full written assessment
├── q1-crew-assignment/
│   ├── crew-assignment.mod                 Sets, decision variables, objective, constraints
│   ├── crew-assignment.dat                 Cost matrix read from Excel
│   ├── crew-assignment.ops                 Solver settings
│   └── data/layover-hours.xlsx             7x7 matrix of layover hours
└── q2-facility-location/
    ├── facility-location.mod               Shared model for both scenarios
    ├── facility-location.dat               Baseline scenario (demandMultiplier = 1.0)
    ├── facility-location-sensitivity.dat   +20% demand scenario (1.2)
    └── facility-location.ops
```

---

## Question 1. Assigning crews to flights at Omega Airlines

### Problem

Omega Airlines operates 7 outbound flights from Atlanta to Los Angeles and 7 return flights from Los Angeles to Atlanta. Every outbound crew must be assigned exactly one return flight, and every return flight must be covered by exactly one crew. Between landing in LAX and departing again the crew waits on the ground, and that layover costs the airline money in hotels, allowances and idle crew hours.

The task is to build the schedule that **minimises total crew layover time** while respecting the FAA one-hour minimum rest rule.

| Flight | Departs ATL | Arrives LAX | Flight | Departs LAX | Arrives ATL |
|:--|--:|--:|:--|--:|--:|
| A1 | 6:00 AM | 8:00 AM | L1 | 5:00 AM | 9:00 AM |
| A2 | 8:00 AM | 10:00 AM | L2 | 6:00 AM | 10:00 AM |
| A3 | 10:00 AM | 12:00 PM | L3 | 9:00 AM | 1:00 PM |
| A4 | 12:00 PM | 2:00 PM | L4 | 12:00 PM | 4:00 PM |
| A5 | 4:00 PM | 6:00 PM | L5 | 2:00 PM | 6:00 PM |
| A6 | 6:00 PM | 8:00 PM | L6 | 5:00 PM | 9:00 PM |
| A7 | 7:00 PM | 9:00 PM | L7 | 7:00 PM | 11:00 PM |

The layover cost `c[i][j]` is the waiting time between the arrival of outbound flight `i` in LAX and the departure of return flight `j`. Where the return flight has already left that day, the next-day departure is used, which is what produces the 20-plus hour entries in the cost matrix. Supply is 1 for every outbound flight and demand is 1 for every return flight, so the network is **balanced**: a classic assignment structure on a complete bipartite graph.

### Formulation

**Sets:** `A = {1..7}` outbound flights, indexed by `i`. `L = {1..7}` return flights, indexed by `j`.

**Parameter:** `c[i][j]` - layover hours.

**Decision variable**

```
x[i][j] = 1  if the crew of outbound flight i takes return flight j
        = 0  otherwise
```

**Objective**

```
min Z = sum(i in A, j in L) c[i][j] * x[i][j]
```

**Constraints**

```
sum(j in L) x[i][j] = 1     for all i in A      each crew gets exactly one return flight
sum(i in A) x[i][j] = 1     for all j in L      each return flight is flown exactly once
x[i][j] in {0,1}
```

### Implementation

```opl
range A = 1..7;
range L = 1..7;
int c[A][L] = ...;

dvar boolean x[A][L];

minimize sum(i in A, j in L) c[i][j] * x[i][j];

subject to {
  forall(i in A) sum(j in L) x[i][j] == 1;
  forall(j in L) sum(i in A) x[i][j] == 1;
}
```

The cost matrix is not hard-coded, so a new timetable can be solved without touching the model:

```opl
SheetConnection sheet("data/layover-hours.xlsx");
c from SheetRead(sheet, "Sheet1!C16:I22");
```

### Optimal solution

| Outbound | Return | Layover, hours |
|:--|:--|--:|
| A1 | L3 | 1 |
| A2 | L4 | 2 |
| A3 | L5 | 2 |
| A4 | L6 | 3 |
| A5 | L7 | 1 |
| A6 | L2 | 10 |
| A7 | L1 | 8 |
| | **Total** | **27** |

### Interpretation

Five of the seven crews turn around in 1 to 3 hours: each daytime arrival is paired with the next feasible departure, and every pairing clears the one-hour FAA rest requirement. All of the cost sits in the two evening arrivals. A6 lands at 8:00 PM and A7 at 9:00 PM, by which point no return flight is left that day, so both crews wait overnight for the early morning departures L2 and L1 and contribute 18 of the 27 hours between them.

That is where the managerial lever actually is. No reassignment can beat 27 hours, since the solution is provably optimal for this timetable. Any further saving has to come from the timetable itself: a late-night departure out of LAX, or basing a crew overnight in Los Angeles rather than flying them home.

---

## Question 2. Locating temporary COVID-19 healthcare facilities

### Problem

A public health agency must allocate COVID-19 patients from **9 counties** across **14 existing hospitals** and **9 potential temporary facilities**. Every patient has to be treated. Existing hospitals are capacity-capped, temporary sites can only receive patients if the agency pays to build them, and in the last resort emergency capacity can be added at a punitive cost.

Three decisions are made simultaneously: where each county's patients go, which temporary facilities to open, and how much emergency capacity to add.

### Formulation

**Sets:** counties `I = {1..9}`, existing facilities `E = {1..14}`, temporary facilities `T = {15..23}`, all facilities `J = E ∪ T`.

**Parameters:** demand `d[i]`, capacity `cap[j]`, fixed build cost `F = $500,000` per temporary site, penalty `P = $1,000,000` per unit of emergency capacity, and county/facility coordinates.

Distance is Euclidean, since locations are given as coordinate points. One coordinate unit is 10 miles and each 10 miles costs $5 per patient, so:

```
dist[i][j] = sqrt((X[i] - A[j])^2 + (Y[i] - B[j])^2)
c[i][j]    = 5 * dist[i][j]
```

**Decision variables**

```
x[i][j] >= 0   patients sent from county i to facility j
y[j] in {0,1}  1 if temporary facility j is built,  j in T
z[j] >= 0      emergency extra capacity added at temporary facility j,  j in T
```

**Objective**

```
min Z = sum(i in I, j in J) c[i][j]*x[i][j]  +  sum(j in T) F*y[j]  +  P * sum(j in T) z[j]
        transportation                          construction            penalty
```

**Constraints**

```
sum(j in J) x[i][j] = d[i]                     for all i in I    all patients treated
sum(i in I) x[i][j] <= cap[j]                  for all j in E    hospital capacity
sum(i in I) x[i][j] <= cap[j]*y[j] + z[j]      for all j in T    temporary capacity, only if built
z[j] <= M * y[j]                               for all j in T    no emergency capacity at a closed site
```

The Big M in the last constraint is set to total demand, the tightest safe bound available, which keeps the LP relaxation stronger than an arbitrary large constant would. The penalty `P` is deliberately two orders of magnitude above the build cost, so the solver only reaches for emergency capacity once genuinely nothing else is left.

### Implementation

Data and model are fully separated. The `.mod` file derives distances and costs from raw coordinates rather than taking a pre-computed matrix, so the geography can be changed in the `.dat` file alone:

```opl
range Counties   = 1..9;
range Facilities = 1..23;
range Existing   = 1..14;
range Temp       = 15..23;

float demand[i in Counties] = round(baseDemand[i] * demandMultiplier);
float totalDemand = sum(i in Counties) demand[i];      // used as Big M

float distance[i in Counties][j in Facilities] =
  sqrt((countyX[i] - facilityX[j])^2 + (countyY[i] - facilityY[j])^2);

dvar int+     x[Counties][Facilities];
dvar boolean  build[Temp];
dvar int+     extra[Temp];

minimize totalTransportCost + totalBuildCost + totalPenaltyCost;
```

The whole sensitivity scenario is driven by a single scalar, `demandMultiplier`, which is why running it needs a second `.dat` file and no code change at all.

### Results

**Baseline.** Total cost **$1,521,653.42**, split into $21,653.42 transport, $1,500,000 construction and $0 penalty. Three temporary facilities are opened (15, 17, 18), adding 300 places. All 3,539 patients are treated, so demand served is 100% with no emergency capacity.

**Sensitivity: demand +20%.** Total demand rises to 4,247 patients. Total cost jumps to **$71,525,513.31**: $25,513.31 transport, $4,500,000 construction and $67,000,000 penalty. All nine temporary facilities are opened, and 67 units of emergency capacity are still needed (40 at facility 15, 27 at facility 17). Demand served remains 100%.

| Indicator | Baseline | +20% demand | Change |
|:--|--:|--:|:--|
| Demand served | 3,539 (100%) | 4,247 (100%) | All demand met in both |
| Temporary facilities built | 3 (15, 17, 18) | 9 (15-23) | Every site needed |
| Construction cost | $1,500,000 | $4,500,000 | +$3,000,000 |
| Transportation cost | $21,653.42 | $25,513.31 | +18% |
| Emergency capacity | 0 | 67 units | Penalty triggered |
| Penalty cost | $0 | $67,000,000 | Dominant cost driver |
| **Total cost** | **$1,521,653.42** | **$71,525,513.31** | **47x** |

### Interpretation

The two scenarios have very different cost anatomies, and that is the real finding. In the baseline, over 98% of the total is construction: transportation is almost noise, because the network is dense enough that most patients are treated close to home. Under a 20% demand shock, transport still barely moves (+18%), while the penalty term alone reaches $67 million and accounts for 94% of the total.

The system is therefore **sensitive to capacity, not to distance**. A 20% rise in demand is absorbed feasibly, but the cost of absorbing it is 47 times higher, and almost all of that increase is the price of improvising capacity in an emergency. In planning terms, the model argues for building headroom before a surge rather than paying to conjure it during one: 67 pre-built places would have cost a fraction of the $67 million spent on the same beds under emergency conditions.

---

## How to run

1. Open IBM ILOG CPLEX Optimization Studio.
2. `File > Import > Existing OPL Projects` and select the task folder.
3. Check that the `SheetConnection` path in Q1 resolves to the local `data/` folder.
4. For Q2, pick the run configuration for the scenario you want: baseline or sensitivity.
5. Run. The solution appears in the Solutions tab and the Scripting log.

Built and tested on IBM ILOG CPLEX Optimization Studio (Windows).

---

## Skills demonstrated

- Translating operational business problems into formal optimisation models
- Binary, integer and mixed-integer linear programming
- Assignment problems on balanced bipartite networks
- Capacitated facility location with fixed opening costs, Big M linking constraints and penalty terms
- OPL modelling: ranges, parameters, `dexpr`, `dvar`, `forall` constraint families
- Model/data separation, Excel `SheetConnection` inputs, scenario-driven `.dat` files
- Sensitivity analysis and cost decomposition as the basis for a management recommendation

---

## Author

**Ali Nuriev** - MSc Business Analytics, University of Kent
[GitHub](https://github.com/AliNuriev)

Academic work submitted for BUSB7030, June 2026. Published for portfolio purposes.
