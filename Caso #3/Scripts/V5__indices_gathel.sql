-- FOREIGN KEYS

CREATE INDEX IX_Files_mediaTypeId
ON dbo.Files(mediaTypeId);

CREATE INDEX IX_Countries_flagFileId
ON dbo.Countries(flagFileId);

CREATE INDEX IX_Players_avatarFileId
ON dbo.Players(avatarFileId);

CREATE INDEX IX_Players_playerStatusId
ON dbo.Players(playerStatusId);

CREATE INDEX IX_Players_countryId
ON dbo.Players(countryId);

CREATE INDEX IX_Wallets_playerId
ON dbo.Wallets(playerId);

CREATE INDEX IX_Wallets_currencyId
ON dbo.Wallets(currencyId);

CREATE INDEX IX_PlatformConfig_createdBy
ON dbo.PlatformConfig(createdBy);

CREATE INDEX IX_PlayerDevices_playerId
ON dbo.PlayerDevices(playerId);

CREATE INDEX IX_PlayerSessions_playerId
ON dbo.PlayerSessions(playerId);

CREATE INDEX IX_PlayerSessions_deviceId
ON dbo.PlayerSessions(deviceId);

CREATE INDEX IX_Transactions_walletId
ON dbo.Transactions(walletId);

CREATE INDEX IX_Transactions_transactionTypeId
ON dbo.Transactions(transactionTypeId);

CREATE INDEX IX_PaymentMethods_playerId
ON dbo.PaymentMethods(playerId);

CREATE INDEX IX_PaymentMethods_countryId
ON dbo.PaymentMethods(countryId);

CREATE INDEX IX_PaymentMethods_currencyId
ON dbo.PaymentMethods(currencyId);

CREATE INDEX IX_TransactionDetails_transactionId
ON dbo.TransactionDetails(transactionId);

CREATE INDEX IX_TransactionDetails_paymentMethodId
ON dbo.TransactionDetails(paymentMethodId);

CREATE INDEX IX_PaymentAttempts_playerId
ON dbo.PaymentAttempts(playerId);

CREATE INDEX IX_PaymentAttempts_paymentMethodId
ON dbo.PaymentAttempts(paymentMethodId);

CREATE INDEX IX_PaymentAttempts_transactionId
ON dbo.PaymentAttempts(transactionId);

CREATE INDEX IX_SocialAccounts_playerId
ON dbo.SocialAccounts(playerId);

CREATE INDEX IX_SocialAccounts_platformId
ON dbo.SocialAccounts(platformId);

CREATE INDEX IX_AIModels_providerId
ON dbo.AIModels(providerId);

CREATE INDEX IX_AIAnalysisJobs_aiJobTypeId
ON dbo.AIAnalysisJobs(aiJobTypeId);

CREATE INDEX IX_AIAnalysisJobs_modelId
ON dbo.AIAnalysisJobs(modelId);

CREATE INDEX IX_AIAnalysisJobs_aiJobStatusId
ON dbo.AIAnalysisJobs(aiJobStatusId);

CREATE INDEX IX_Propositions_creatorId
ON dbo.Propositions(creatorId);

CREATE INDEX IX_Propositions_subjectPlayerId
ON dbo.Propositions(subjectPlayerId);

CREATE INDEX IX_Propositions_propositionStatusId
ON dbo.Propositions(propositionStatusId);

CREATE INDEX IX_PropositionVotes_propositionId
ON dbo.PropositionVotes(propositionId);

CREATE INDEX IX_PropositionVotes_voterId
ON dbo.PropositionVotes(voterId);

CREATE INDEX IX_Predictions_propositionId
ON dbo.Predictions(propositionId);

CREATE INDEX IX_Predictions_predictorId
ON dbo.Predictions(predictorId);

CREATE INDEX IX_EvidenceSubmissions_propositionId
ON dbo.EvidenceSubmissions(propositionId);

CREATE INDEX IX_EvidenceSubmissions_submittedBy
ON dbo.EvidenceSubmissions(submittedBy);

CREATE INDEX IX_RewardDistributions_propositionId
ON dbo.RewardDistributions(propositionId);

CREATE INDEX IX_PenaltyTransactions_playerId
ON dbo.PenaltyTransactions(playerId);

CREATE INDEX IX_PointsRedemptions_playerId
ON dbo.PointsRedemptions(playerId);

CREATE INDEX IX_AuditLog_performedBy
ON dbo.AuditLog(performedBy);

CREATE INDEX IX_AuditLog_sessionId
ON dbo.AuditLog(sessionId);

-- Otros

CREATE INDEX IX_Players_username
ON dbo.Players(username);

CREATE INDEX IX_Players_email
ON dbo.Players(email);

CREATE INDEX IX_Transactions_createdAt
ON dbo.Transactions(createdAt);

CREATE INDEX IX_Propositions_createdAt
ON dbo.Propositions(createdAt);

CREATE INDEX IX_AuditLog_createdAt
ON dbo.AuditLog(occurredAt);