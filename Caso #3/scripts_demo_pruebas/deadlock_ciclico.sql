EXEC demo.usp_Demo_DeadlockCiclico_T1 @walletR1 = 20002, @walletR2 = 20004;
EXEC demo.usp_Demo_DeadlockCiclico_T2 @walletR2 = 20004, @walletR3 = 20006;
EXEC demo.usp_Demo_DeadlockCiclico_T3 @walletR3 = 20006, @walletR1 = 20002;