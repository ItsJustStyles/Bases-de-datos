EXEC demo.usp_Demo_OnboardAndPropose @username = 'demoOk2', @email = 'ok@demo2.test', @forzarFallo = 0;
SELECT playerId, username FROM dbo.Players WHERE username = 'demoOk2';
SELECT propositionId, propositionText FROM dbo.Propositions WHERE propositionText LIKE 'Proposición de prueba 2%';


EXEC demo.usp_Demo_OnboardAndPropose @username = 'demoFail', @email = 'fail@demo.test', @forzarFallo = 1;
SELECT playerId, username FROM dbo.Players WHERE username = 'demoFail'; 