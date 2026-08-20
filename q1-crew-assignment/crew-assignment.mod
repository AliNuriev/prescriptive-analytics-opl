/*********************************************
 * OPL 22.1.2.0 Model
 * Author: alnur
 * Creation Date: 20 Aug 2026 at 23:09:47
 *********************************************/
range A = 1..7;
range L = 1..7;

int c[A][L] = ...;

// decision variable
dvar boolean x[A][L];

// objective function
minimize sum(i in A, j in L)c[i][j]*x[i][j];

// constraints
subject to{
  forall(i in A)
    sum(j in L)x[i][j] == 1;
    
  forall(j in L)
    sum(i in A)x[i][j] == 1;
}
 