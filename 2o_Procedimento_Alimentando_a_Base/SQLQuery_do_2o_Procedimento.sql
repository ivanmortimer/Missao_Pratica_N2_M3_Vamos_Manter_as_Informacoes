-- Inserção dos operadores do sistema (sem criptografia)
INSERT INTO dbo.Usuario ([login], senha) VALUES 
('op1', 'op1'),
('op2', 'op2');

-- Inserção de produtos
INSERT INTO dbo.Produto (nome, quantidade, precoVenda) VALUES
('Banana', 100, 5.00),
('Pera', 50, 3.00),
('Laranja', 500, 2.00),
('Manga', 800, 4.00);

-- Deleção de um produtos (produto cuja idProduto = 2)
DELETE FROM dbo.Produto
WHERE idProduto = 2;


-- Obter o próximo valor da SEQUENCE
SELECT NEXT VALUE FOR dbo.Seq_idPessoa AS ProximoIdPessoa;

-- Supondo que o valor retornado pela sequence foi 7, inserir nova pessoa com idPessoa = 7
INSERT INTO dbo.Pessoa (
    idPessoa, nome, logradouro, cidade, estado, telefone, email
) VALUES (
    7, 'Joao', 'Rua 12, casa 3, Quitanda', 'Riacho do Sul', 'PA', '1111-1111', 'joao@riacho.com'
);

-- Inserir linha com idPessoa = 7 na tabela Pessoa_Fisica
INSERT INTO dbo.Pessoa_Fisica (idPessoa, cpf) VALUES
(7, '11111111111');

-- Obter o próximo valor da SEQUENCE (Supondo que o valor retornado seja 15)
SELECT NEXT VALUE FOR dbo.Seq_idPessoa AS ProximoIdPessoa;

-- Supondo que o valor retornado pela sequence foi 15, inserir nova pessoa com idPessoa = 15
INSERT INTO dbo.Pessoa (
    idPessoa, nome, logradouro, cidade, estado, telefone, email
) VALUES (
    15, 'JJC', 'Rua 11, Centro', 'Riacho do Norte', 'PA', '1212-1212', 'jjc@riacho.com'
);

-- Inserir linha com idPessoa = 15 na tabela Pessoa_Juridica
INSERT INTO dbo.Pessoa_Juridica (idPessoa, cnpj) VALUES
(15, '22222222222222');

-- 1.1 Saídas (tipo 'S')
-- Como idMovimento é IDENTITY(1,1), eu não irei informá-lo — ele será gerado automaticamente.
INSERT INTO dbo.Movimento (idUsuario, idPessoa, idProduto, quantidade, tipo, valorUnitario) VALUES
(1, 7, 1, 20, 'S', 4.00),  -- Joao comprando Banana
(1, 7, 3, 15, 'S', 2.00),  -- Joao comprando Laranja
(2, 7, 3, 10, 'S', 3.00);  -- Joao comprando Laranja por outro operador


-- 1.2 Saídas (tipo 'S')
-- Nova insersão de movimentações de venda mas agora sem incluir as linhas
-- (2, 7, 3, 10, 'S', 3.00) e (1, 7, 1, 20, 'S', 4.00), que gera um ROLLBACK TRANSACTION seguido de um RAISERROR.
INSERT INTO dbo.Movimento (idUsuario, idPessoa, idProduto, quantidade, tipo, valorUnitario) VALUES
(1, 7, 3, 15, 'S', 2.00);  -- Joao comprando Laranja

-- 2. Entradas (tipo 'E')
-- A mesma observação com relação ao fato de idMovimento ser IDENTITY(1,1) se aplica aqui.
INSERT INTO dbo.Movimento (idUsuario, idPessoa, idProduto, quantidade, tipo, valorUnitario) VALUES
(1, 15, 3, 15, 'E', 5.00), -- JJC fornecendo Laranja
(1, 15, 4, 20, 'E', 4.00); -- JJC fornecendo Manga
