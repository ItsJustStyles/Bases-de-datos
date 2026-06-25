from sqlalchemy import (
    Column, Integer, BigInteger, String, DateTime, Numeric, Boolean, 
    ForeignKey, LargeBinary, UniqueConstraint, func
)
from sqlalchemy.orm import relationship, declarative_base

Base = declarative_base()

class TransactionTypes(Base):
    __tablename__ = 'TransactionTypes'
    transactionTypeId = Column(Integer, primary_key=True)
    code = Column(String(50), nullable=False, unique=True)
    description = Column(String(200), nullable=False)
    isDebit = Column(Boolean, default=True)
    createdAt = Column(DateTime, default=func.now())

class PropositionStatuses(Base):
    __tablename__ = 'PropositionStatuses'
    propositionStatusId = Column(Integer, primary_key=True)
    code = Column(String(50), nullable=False, unique=True)
    description = Column(String(200), nullable=False)

class PlayerStatuses(Base):
    __tablename__ = 'PlayerStatuses'
    playerStatusId = Column(Integer, primary_key=True)
    code = Column(String(50), nullable=False, unique=True)
    description = Column(String(200), nullable=False)

class PropositionOutcomes(Base):
    __tablename__ = 'PropositionOutcomes'
    outcomeId = Column(Integer, primary_key=True)
    code = Column(String(20), nullable=False, unique=True)
    description = Column(String(200), nullable=False)

class PropositionOutcomeRecords(Base):
    __tablename__ = 'PropositionOutcomeRecords'
    outcomeRecordId = Column(BigInteger, primary_key=True)
    propositionId = Column(BigInteger, ForeignKey('Propositions.propositionId'), nullable=False)
    outcomeId = Column(Integer, ForeignKey('PropositionOutcomes.outcomeId'), nullable=False)

    proposition = relationship("Propositions", back_populates="outcome_record")
    outcome = relationship("PropositionOutcomes")

class PredictionOptions(Base):
    __tablename__ = 'PredictionOptions'
    predictionOptionId = Column(Integer, primary_key=True)
    code = Column(String(10), nullable=False, unique=True)

    predictions = relationship("Predictions", back_populates="prediction_option")

class AIJobTypes(Base):
    __tablename__ = 'AIJobTypes'
    aiJobTypeId = Column(Integer, primary_key=True)
    code = Column(String(50), nullable=False, unique=True)
    description = Column(String(200), nullable=False)

class AIJobStatuses(Base):
    __tablename__ = 'AIJobStatuses'
    aiJobStatusId = Column(Integer, primary_key=True)
    code = Column(String(20), nullable=False, unique=True)

class PenaltyCatalog(Base):
    __tablename__ = 'PenaltyCatalog'
    penaltyCatalogId = Column(Integer, primary_key=True)
    code = Column(String(50), nullable=False, unique=True)
    description = Column(String(500), nullable=False)
    penaltyPercentage = Column(Numeric(5, 2))
    fixedPointsAmount = Column(BigInteger)
    effectiveFrom = Column(DateTime, default=func.now())
    effectiveTo = Column(DateTime)
    createdAt = Column(DateTime, default=func.now())

class MediaTypes(Base):
    __tablename__ = 'MediaTypes'
    mediaTypeId = Column(Integer, primary_key=True)
    mimeType = Column(String(100), nullable=False, unique=True)
    mediaExtension = Column(String(10), nullable=False)
    createdAt = Column(DateTime, default=func.now())

class Files(Base):
    __tablename__ = 'Files'
    fileId = Column(BigInteger, primary_key=True)
    mediaTypeId = Column(Integer, ForeignKey('MediaTypes.mediaTypeId'))
    fileName = Column(String(255), nullable=False)
    fileURL = Column(String(1000), nullable=False)
    fileSize = Column(BigInteger)
    createdAt = Column(DateTime, default=func.now())
    deletedAt = Column(DateTime)

class Countries(Base):
    __tablename__ = 'Countries'
    countryId = Column(Integer, primary_key=True)
    countryName = Column(String(100), nullable=False)
    isoCode = Column(String(3), nullable=False, unique=True)
    flagFileId = Column(BigInteger, ForeignKey('Files.fileId'))
    createdAt = Column(DateTime, default=func.now())

class Currencies(Base):
    __tablename__ = 'Currencies'
    currencyId = Column(Integer, primary_key=True)
    code = Column(String(10), nullable=False, unique=True)
    currencyName = Column(String(100), nullable=False)
    symbol = Column(String(10), nullable=False)
    isVirtual = Column(Boolean, default=False)
    decimalPlaces = Column(Integer, default=2)
    createdAt = Column(DateTime, default=func.now())

class Players(Base):
    __tablename__ = 'Players'
    playerId = Column(BigInteger, primary_key=True)
    username = Column(String(50), nullable=False, unique=True)
    email = Column(String(255), nullable=False, unique=True)
    passwordHash = Column(LargeBinary(64), nullable=False)
    passwordSalt = Column(LargeBinary(32), nullable=False)
    avatarFileId = Column(BigInteger, ForeignKey('Files.fileId'))
    playerStatusId = Column(Integer, ForeignKey('PlayerStatuses.playerStatusId'))
    countryId = Column(Integer, ForeignKey('Countries.countryId'))
    isVerified = Column(Boolean, default=False)
    createdAt = Column(DateTime, default=func.now())
    deletedAt = Column(DateTime)
    
    # Relaciones
    wallets = relationship("Wallets", back_populates="player")
    payment_methods = relationship("PaymentMethods", back_populates="player")

class Wallets(Base):
    __tablename__ = 'Wallets'
    walletId = Column(BigInteger, primary_key=True)
    playerId = Column(BigInteger, ForeignKey('Players.playerId'), nullable=False)
    currencyId = Column(Integer, ForeignKey('Currencies.currencyId'), nullable=False)
    balance = Column(Numeric(18, 4), default=0)
    reservedBalance = Column(Numeric(18, 4), default=0)
    createdAt = Column(DateTime, default=func.now())
    
    __table_args__ = (UniqueConstraint('playerId', 'currencyId'),)

    player = relationship("Players", back_populates="wallets")
    currency = relationship("Currencies")

class PaymentMethods(Base):
    __tablename__ = 'PaymentMethods'
    # Si tu tabla está explícitamente en el esquema dbo, puedes añadir: __table_args__ = {'schema': 'dbo'}

    paymentMethodId = Column(BigInteger, primary_key=True)
    playerId = Column(BigInteger, ForeignKey('Players.playerId'), nullable=False)
    methodType = Column(String(50), nullable=False)
    alias = Column(String(255), nullable=True)
    isVerified = Column(Boolean, default=False) 

    player = relationship("Players", back_populates="payment_methods")


class Transactions(Base):
    __tablename__ = 'Transactions'
    transactionId = Column(BigInteger, primary_key=True)
    walletId = Column(BigInteger, ForeignKey('Wallets.walletId'), nullable=False)
    transactionTypeId = Column(Integer, ForeignKey('TransactionTypes.transactionTypeId'), nullable=False)
    amount = Column(Numeric(18, 4), nullable=False)
    balanceBefore = Column(Numeric(18, 4), nullable=False)
    balanceAfter = Column(Numeric(18, 4), nullable=False)
    referenceType = Column(String(50))
    referenceId = Column(BigInteger)
    description = Column(String(500))
    createdAt = Column(DateTime, default=func.now())

    wallet = relationship("Wallets")
    transaction_type = relationship("TransactionTypes")

class Propositions(Base):
    __tablename__ = 'Propositions'
    propositionId = Column(BigInteger, primary_key=True)
    creatorId = Column(BigInteger, ForeignKey('Players.playerId'), nullable=False)
    subjectPlayerId = Column(BigInteger, ForeignKey('Players.playerId'))
    propositionText = Column(String(1000), nullable=False)
    propositionStatusId = Column(Integer, ForeignKey('PropositionStatuses.propositionStatusId'), nullable=False)
    aiJobId = Column(BigInteger) # FK opcional a AIAnalysisJobs
    winningVoteId = Column(BigInteger)
    predictionsCloseAt = Column(DateTime)
    createdAt = Column(DateTime, default=func.now())
    acceptedAt = Column(DateTime, nullable=True)

    subject_player = relationship("Players", foreign_keys=[subjectPlayerId])
    creator = relationship("Players", foreign_keys=[creatorId])
    status = relationship("PropositionStatuses", foreign_keys=[propositionStatusId])
    outcome_record = relationship("PropositionOutcomeRecords", back_populates="proposition", uselist=False)
    predictions = relationship("Predictions", back_populates="proposition")

class Predictions(Base):
    __tablename__ = 'Predictions'
    predictionId = Column(BigInteger, primary_key=True)
    propositionId = Column(BigInteger, ForeignKey('Propositions.propositionId'), nullable=False)
    predictorId = Column(BigInteger, ForeignKey('Players.playerId'), nullable=False)
    predictionOptionId = Column(Integer, ForeignKey('PredictionOptions.predictionOptionId'), nullable=False)
    walletId = Column(BigInteger, ForeignKey('Wallets.walletId'), nullable=False)
    amountWagered = Column(Numeric(18, 4), nullable=False)
    createdAt = Column(DateTime, default=func.now())
    lockedAt = Column(DateTime, default=func.now())

    wallet = relationship("Wallets")
    prediction_result = relationship("PredictionResults", back_populates="prediction", uselist=False)
    proposition = relationship("Propositions", back_populates="predictions")
    prediction_option = relationship("PredictionOptions", back_populates="predictions")
    
    __table_args__ = (UniqueConstraint('propositionId', 'predictorId', 'walletId'),)

class PredictionResults(Base):
    __tablename__ = 'PredictionResults'
    predictionId = Column(BigInteger, ForeignKey('Predictions.predictionId'), primary_key=True)
    isWinner = Column(Boolean, default=False)
    amountEarned = Column(Numeric(18, 4), default=0)

    # Relación de vuelta a la predicción
    prediction = relationship("Predictions", back_populates="prediction_result")

class AIAnalysisJobs(Base):
    __tablename__ = 'AIAnalysisJobs'
    jobId = Column(BigInteger, primary_key=True)
    aiJobTypeId = Column(Integer, ForeignKey('AIJobTypes.aiJobTypeId'), nullable=False)
    aiJobStatusId = Column(Integer, ForeignKey('AIJobStatuses.aiJobStatusId'), nullable=False)
    inputPayload = Column(String) # String ilimitado en SQLAlchemy equivale a nvarchar(max)
    createdAt = Column(DateTime, default=func.now())

class AuditLog(Base):
    __tablename__ = 'AuditLog'
    auditId = Column(BigInteger, primary_key=True)
    entityName = Column(String(100), nullable=False)
    entityId = Column(String(50), nullable=False)
    operation = Column(String(6), nullable=False)
    oldSnapshot = Column(String)
    newSnapshot = Column(String)
    occurredAt = Column(DateTime, default=func.now())