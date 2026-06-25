-- Índices para optimizar el ordenamiento y el filtrado
CREATE INDEX idx_propositions_createdat ON Propositions (createdAt DESC);
CREATE INDEX idx_transactions_createdat ON Transactions (createdAt DESC);
CREATE INDEX idx_transactions_walletid ON Transactions (walletId);
CREATE INDEX idx_wallets_playerid ON Wallets (playerId);