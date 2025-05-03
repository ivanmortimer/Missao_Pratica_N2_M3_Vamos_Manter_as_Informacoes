
-- 1. Criação do banco de dados se não existir
IF DB_ID('Loja_DB') IS NULL EXECUTE('CREATE DATABASE [Loja_DB];');
GO

-- 2. Troca para o banco Loja_DB
USE [Loja_DB];
GO

-- 3. Criação do esquema dbo se não existir
IF SCHEMA_ID('dbo') IS NULL EXECUTE('CREATE SCHEMA [dbo];');
GO

-- 4. Criação do LOGIN e USER para 'loja'
IF NOT EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'loja')
BEGIN
    CREATE LOGIN loja WITH PASSWORD = 'loja', CHECK_POLICY = OFF;
END;
GO

USE [Loja_DB];
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'loja')
BEGIN
    CREATE USER loja FOR LOGIN loja;
    EXEC sp_addrolemember 'db_owner', 'loja';
END;
GO

-- 5. Criação da SEQUENCE para ID de pessoa
IF OBJECT_ID('dbo.Seq_idPessoa', 'SO') IS NULL
BEGIN
    CREATE SEQUENCE dbo.Seq_idPessoa
        START WITH 1
        INCREMENT BY 1;
END;
GO

-- 6. Tabela Pessoa
CREATE TABLE dbo.Pessoa (
    idPessoa INT NOT NULL PRIMARY KEY DEFAULT NEXT VALUE FOR dbo.Seq_idPessoa,
    nome VARCHAR(255) NOT NULL,
    logradouro VARCHAR(100) NOT NULL,
    cidade VARCHAR(50) NOT NULL,
    estado CHAR(2) NOT NULL,
    telefone CHAR(11) NOT NULL,
    email VARCHAR(255) NOT NULL
);
GO

-- 7. Tabelas Pessoa_Fisica e Pessoa_Juridica (herança 1:1)
CREATE TABLE dbo.Pessoa_Fisica (
    idPessoa INT NOT NULL PRIMARY KEY,
    cpf CHAR(11) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.Pessoa_Juridica (
    idPessoa INT NOT NULL PRIMARY KEY,
    cnpj CHAR(14) NOT NULL UNIQUE
);
GO

-- 8. Tabela Usuario
CREATE TABLE dbo.Usuario (
    idUsuario INT IDENTITY(1,1) PRIMARY KEY,
    login VARCHAR(255) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL
);
GO

-- 9. Tabela Produto
CREATE TABLE dbo.Produto (
    idProduto INT IDENTITY(1,1) PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    quantidade INT NOT NULL,
    precoVenda NUMERIC(18,2) NOT NULL,
    CONSTRAINT CHK_Produto_Quantidade CHECK (quantidade >= 0),
    CONSTRAINT CHK_Produto_PrecoVenda CHECK (precoVenda >= 0)
);
GO

-- 10. Tabela Movimento
CREATE TABLE dbo.Movimento (
    idMovimento INT IDENTITY(1,1) PRIMARY KEY,
    idUsuario INT NOT NULL,
    idPessoa INT NOT NULL,
    idProduto INT NOT NULL,
    quantidade INT NOT NULL,
    tipo CHAR(1),
    valorUnitario NUMERIC(18,2) NOT NULL,
    CONSTRAINT CHK_Tipo_Movimento CHECK (tipo IN ('E', 'S')),
    CONSTRAINT CHK_Movimento_Quantidade CHECK (quantidade >= 0),
    CONSTRAINT CHK_Movimento_ValorUnitario CHECK (valorUnitario >= 0)
);
GO

-- 11. Foreign Keys
ALTER TABLE dbo.Pessoa_Fisica
    ADD CONSTRAINT fk_Pessoa_Fisica_Pessoa FOREIGN KEY (idPessoa) REFERENCES dbo.Pessoa(idPessoa);
GO

ALTER TABLE dbo.Pessoa_Juridica
    ADD CONSTRAINT fk_Pessoa_Juridica_Pessoa FOREIGN KEY (idPessoa) REFERENCES dbo.Pessoa(idPessoa);
GO

ALTER TABLE dbo.Movimento
    ADD CONSTRAINT fk_Movimento_Usuario FOREIGN KEY (idUsuario) REFERENCES dbo.Usuario(idUsuario),
        CONSTRAINT fk_Movimento_Pessoa FOREIGN KEY (idPessoa) REFERENCES dbo.Pessoa(idPessoa),
        CONSTRAINT fk_Movimento_Produto FOREIGN KEY (idProduto) REFERENCES dbo.Produto(idProduto);
GO

-- 12. Trigger: Atualiza valorUnitario com precoVenda quando tipo = 'S'
IF OBJECT_ID('dbo.trg_SetPrecoVenda', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_SetPrecoVenda;
GO
CREATE TRIGGER dbo.trg_SetPrecoVenda
ON dbo.Movimento
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE tipo = 'S')
    BEGIN
        UPDATE mv
        SET mv.valorUnitario = p.precoVenda
        FROM dbo.Movimento mv
        JOIN inserted i ON mv.idMovimento = i.idMovimento
        JOIN dbo.Produto p ON p.idProduto = i.idProduto
        WHERE i.tipo = 'S';
    END
END;
GO

-- 13. Trigger: Valida valorUnitario com precoVenda quando tipo = 'S'
IF OBJECT_ID('dbo.trg_ValidarPrecoVenda', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_ValidarPrecoVenda;
GO
CREATE TRIGGER dbo.trg_ValidarPrecoVenda
ON dbo.Movimento
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Produto p ON i.idProduto = p.idProduto
        WHERE i.tipo = 'S' AND i.valorUnitario <> p.precoVenda
    )
    BEGIN
        RAISERROR('O valorUnitario informado não corresponde ao precoVenda do Produto.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    MERGE dbo.Movimento AS target
    USING inserted AS source
    ON target.idMovimento = source.idMovimento
    WHEN MATCHED THEN
        UPDATE SET
            idUsuario = source.idUsuario,
            idPessoa = source.idPessoa,
            idProduto = source.idProduto,
            quantidade = source.quantidade,
            tipo = source.tipo,
            valorUnitario = source.valorUnitario
    WHEN NOT MATCHED THEN
        INSERT (idUsuario, idPessoa, idProduto, quantidade, tipo, valorUnitario)
        VALUES (source.idUsuario, source.idPessoa, source.idProduto, source.quantidade, source.tipo, source.valorUnitario);
END;
GO

-- 14. Trigger: Atualiza estoque após entrada (tipo = 'E')
IF OBJECT_ID('dbo.trg_EntradaAtualizaEstoque', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_EntradaAtualizaEstoque;
GO
CREATE TRIGGER dbo.trg_EntradaAtualizaEstoque
ON dbo.Movimento
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE p
    SET p.quantidade = p.quantidade + i.quantidade
    FROM dbo.Produto p
    JOIN inserted i ON p.idProduto = i.idProduto
    WHERE i.tipo = 'E';
END;
GO

-- 15. Trigger: Atualiza estoque após saída (tipo = 'S') com validação
IF OBJECT_ID('dbo.trg_SaidaAtualizaEstoque', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_SaidaAtualizaEstoque;
GO
CREATE TRIGGER dbo.trg_SaidaAtualizaEstoque
ON dbo.Movimento
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Produto p ON i.idProduto = p.idProduto
        WHERE i.tipo = 'S' AND p.quantidade < i.quantidade
    )
    BEGIN
        RAISERROR('A quantidade solicitada excede o estoque disponível.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    UPDATE p
    SET p.quantidade = p.quantidade - i.quantidade
    FROM dbo.Produto p
    JOIN inserted i ON p.idProduto = i.idProduto
    WHERE i.tipo = 'S';
END;
GO
