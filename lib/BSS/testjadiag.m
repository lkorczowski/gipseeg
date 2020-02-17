format compact
C1 = [45 10   0   5   0   0
      10 45   5   0   0   0
       0  5  45  10   0   0
       5  0  10  45   0   0
       0  0   0   0 16.4 -4.8
       0  0   0   0 -4.8 13.6]
C2 = [ 27.5 -12.5   -.5 -4.5 -2.04   3.72
      -12.5  27.5  -4.5  -.5  2.04  -3.72
        -.5  -4.5  24.5 -9.5 -3.72  -2.04
       -4.5   -.5  -9.5 24.5  3.72   2.04
      -2.04  2.04 -3.72 3.72 54.76  -4.68
       3.72 -3.72 -2.04 2.04 -4.68 51.24]

logdet = log(det(C1)) + log(det(C2))
C = [C1 C2];
A = eye(6);
reply = 'y';
while (reply == 'y' | reply == 'Y')
  [C, crit, A, logdet, decr] = jadiag(C, A, logdet)
  reply = input('Continue (y/n) ? ','s');
end