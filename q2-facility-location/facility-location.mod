/*********************************************
 * OPL 22.1.2.0 Model
 * Author: alnur
 *********************************************/
// sets
range Counties = 1..9;
range Facilities = 1..23;
range Existing = 1..14;
range Temp = 15..23;

// data from .dat
int baseDemand[Counties] = ...;
float demandMultiplier = ...;

float countyX[Counties] = ...;
float countyY[Counties] = ...;

float facilityX[Facilities] = ...;
float facilityY[Facilities] = ...;

int capacity[Facilities] = ...;

float costPerDistanceUnit = ...;
float fixedBuildCost = ...;
int penaltyCost = ...;

// demand
float demand[i in Counties] = round(baseDemand[i] * demandMultiplier);

// total demand, used as Big M
float totalDemand = sum(i in Counties) demand[i];

// distance and transportation cost
float distance[i in Counties][j in Facilities] =
 sqrt((countyX[i] - facilityX[j]) * (countyX[i] - facilityX[j])
 + (countyY[i] - facilityY[j]) * (countyY[i] - facilityY[j]));

float transportCost[i in Counties][j in Facilities] =
 costPerDistanceUnit * distance[i][j];

// decision variables
dvar int+ x[Counties][Facilities]; // patients from county i to facility j
dvar boolean build[Temp]; // 1 if temporary facility j is built
dvar int+ extra[Temp]; // extra capacity added at temporary facility j

// objective parts
dexpr float totalTransportCost =
 sum(i in Counties, j in Facilities) transportCost[i][j] * x[i][j];

dexpr float totalBuildCost =
 sum(j in Temp) fixedBuildCost * build[j];

dexpr float totalPenaltyCost =
 penaltyCost * sum(j in Temp) extra[j];

dexpr int totalServed =
 sum(i in Counties, j in Facilities) x[i][j];

dexpr float percentageServed =
 100 * totalServed / totalDemand;

// objective function
minimize totalTransportCost + totalBuildCost + totalPenaltyCost;

// constraints
subject to {

 // each county demand must be fully satisfied
 forall(i in Counties)
 sum(j in Facilities) x[i][j] == demand[i];

 // existing facility capacity cannot be exceeded
 forall(j in Existing)
 sum(i in Counties) x[i][j] <= capacity[j];

 // temporary facility capacity can be used only if facility is built
 forall(j in Temp)
 sum(i in Counties) x[i][j] <= capacity[j] * build[j] + extra[j];

 // extra capacity can only be added if the temporary facility is built
 forall(j in Temp)
 extra[j] <= totalDemand * build[j];
}
 