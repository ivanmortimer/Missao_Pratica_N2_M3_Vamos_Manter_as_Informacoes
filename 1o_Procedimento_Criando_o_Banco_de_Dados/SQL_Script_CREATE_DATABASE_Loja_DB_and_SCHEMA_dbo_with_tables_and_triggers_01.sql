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
    cep CHAR(8) NOT NULL,
    logradouro VARCHAR(100) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    complemento VARCHAR(50) NULL,
    bairro VARCHAR(50) NULL,
    cidade VARCHAR(50) NOT NULL,
    estado CHAR(2) NOT NULL,
    telefone CHAR(11) NOT NULL,
    email VARCHAR(255) NOT NULL,
    idUsuario INT NOT NULL
);
GO

-- 7. Tabelas Pessoa_Fisica e Pessoa_Juridica (herança 1:1)
CREATE TABLE dbo.Pessoa_Fisica (
    idPessoaFisica INT NOT NULL PRIMARY KEY,
    cpf CHAR(11) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.Pessoa_Juridica (
    idPessoaJuridica INT NOT NULL PRIMARY KEY,
    cnpj CHAR(14) NOT NULL UNIQUE,
    idPessoa INT NULL
);
GO

-- 8. Tabela Usuario
CREATE TABLE dbo.Usuario (
    idUsuario INT IDENTITY(1,1) PRIMARY KEY,
    loginUsuario VARCHAR(255) NOT NULL UNIQUE,
    senhaUsuario VARCHAR(255) NOT NULL
);
GO

-- 9. Tabela Produto
CREATE TABLE dbo.Produto (
    idProduto INT IDENTITY(1,1) PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    quantidade INT NOT NULL,
    precoVenda NUMERIC(18,2) NOT NULL
);
GO

-- 10. Tabela Movimento_de_Compra
CREATE TABLE dbo.Movimento_de_Compra (
    idMovimentoDeCompra INT IDENTITY(1,1) PRIMARY KEY,
    idUsuario INT NOT NULL,
    idPessoaJuridica INT NOT NULL,
    idProduto INT NOT NULL,
    quantidadeDeProdutos INT NOT NULL,
    precoUnitario NUMERIC(18,2) NOT NULL
);
GO

-- 11. Tabela Movimento_de_Venda
CREATE TABLE dbo.Movimento_de_Venda (
    idMovimentoDeVenda INT IDENTITY(1,1) PRIMARY KEY,
    idUsuario INT NOT NULL,
    idPessoaFisica INT NOT NULL,
    idProduto INT NOT NULL,
    quantidadeDeProdutos INT NOT NULL,
    precoVenda NUMERIC(18,2) NOT NULL
);
GO

-- 12. Foreign Keys
ALTER TABLE dbo.Pessoa_Fisica
    ADD CONSTRAINT fk_Pessoa_Fisica_Pessoa FOREIGN KEY (idPessoaFisica) REFERENCES dbo.Pessoa(idPessoa);
GO

ALTER TABLE dbo.Pessoa_Juridica
    ADD CONSTRAINT fk_Pessoa_Juridica_Pessoa FOREIGN KEY (idPessoaJuridica) REFERENCES dbo.Pessoa(idPessoa);
GO

ALTER TABLE dbo.Movimento_de_Compra
    ADD CONSTRAINT fk_Compra_Usuario FOREIGN KEY (idUsuario) REFERENCES dbo.Usuario(idUsuario),
                CONSTRAINT fk_Compra_Pessoa_Juridica FOREIGN KEY (idPessoaJuridica) REFERENCES dbo.Pessoa_Juridica(idPessoaJuridica),
                CONSTRAINT fk_Compra_Produto FOREIGN KEY (idProduto) REFERENCES dbo.Produto(idProduto);
GO

ALTER TABLE dbo.Movimento_de_Venda
    ADD CONSTRAINT fk_Venda_Usuario FOREIGN KEY (idUsuario) REFERENCES dbo.Usuario(idUsuario),
                CONSTRAINT fk_Venda_Pessoa_Fisica FOREIGN KEY (idPessoaFisica) REFERENCES dbo.Pessoa_Fisica(idPessoaFisica),
                CONSTRAINT fk_Venda_Produto FOREIGN KEY (idProduto) REFERENCES dbo.Produto(idProduto);
GO

-- 13. Trigger para sincronizar precoVenda após INSERT
IF OBJECT_ID('dbo.trg_SetPrecoVenda', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_SetPrecoVenda;
GO
CREATE TRIGGER dbo.trg_SetPrecoVenda
ON dbo.Movimento_de_Venda
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE mv
    SET mv.precoVenda = p.precoVenda
    FROM dbo.Movimento_de_Venda mv
    JOIN inserted i ON mv.idMovimentoDeVenda = i.idMovimentoDeVenda
    JOIN dbo.Produto p ON p.idProduto = i.idProduto;
END;
GO

-- 14. Trigger para validação de precoVenda (não pode divergir do Produto)
IF OBJECT_ID('dbo.trg_ValidarPrecoVenda', 'TR') IS NOT NULL DROP TRIGGER dbo.trg_ValidarPrecoVenda;
GO
CREATE TRIGGER dbo.trg_ValidarPrecoVenda
ON dbo.Movimento_de_Venda
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN dbo.Produto p ON i.idProduto = p.idProduto
        WHERE i.precoVenda <> p.precoVenda
    )
    BEGIN
        RAISERROR('O precoVenda informado não corresponde ao precoVenda do Produto.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    IF EXISTS (SELECT * FROM inserted)
    BEGIN
        MERGE dbo.Movimento_de_Venda AS target
        USING inserted AS source
        ON target.idMovimentoDeVenda = source.idMovimentoDeVenda
        WHEN MATCHED THEN
            UPDATE SET
                idUsuario = source.idUsuario,
                idPessoaFisica = source.idPessoaFisica,
                idProduto = source.idProduto,
                quantidadeDeProdutos = source.quantidadeDeProdutos,
                precoVenda = source.precoVenda
        WHEN NOT MATCHED THEN
            INSERT (idUsuario, idPessoaFisica, idProduto, quantidadeDeProdutos, precoVenda)
            VALUES (source.idUsuario, source.idPessoaFisica, source.idProduto, source.quantidadeDeProdutos, source.precoVenda);
    END
END;
GO
