EXEC demo.usp_Demo_DeadlockReadWrite_A @walletId1 = 20002, @walletId2 = 20004;
EXEC demo.usp_Demo_DeadlockReadWrite_B @walletId1 = 20002, @walletId2 = 20004;