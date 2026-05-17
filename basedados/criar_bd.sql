DROP
DATABASE IF EXISTS felixubershop;

CREATE
DATABASE felixubershop
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE
felixubershop;

CREATE TABLE utilizadores
(
    id_utilizador INT AUTO_INCREMENT PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    perfil        ENUM('cliente','funcionario','administrador') NOT NULL DEFAULT 'cliente',
    telefone      VARCHAR(20),
    morada        VARCHAR(255),
    data_registo  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ativo         TINYINT(1)    NOT NULL DEFAULT 1
) ENGINE=InnoDB
  CHARACTER SET utf8mb4
  COMMENT='Utilizadores registados no sistema (clientes, funcionários, administradores)';

CREATE TABLE carteira
(
    id_carteira   INT AUTO_INCREMENT PRIMARY KEY,
    id_utilizador INT            NOT NULL UNIQUE,
    saldo         DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    is_loja       TINYINT(1)     NOT NULL DEFAULT 0,
    CONSTRAINT fk_carteira_utilizador
        FOREIGN KEY (id_utilizador)
            REFERENCES utilizadores (id_utilizador)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_saldo CHECK (saldo >= 0.00)
) ENGINE=InnoDB
  COMMENT='Carteira de saldo de cada utilizador e da loja';

CREATE TABLE produtos
(
    id_produto INT AUTO_INCREMENT PRIMARY KEY,
    nome       VARCHAR(150)   NOT NULL,
    descricao  TEXT,
    preco      DECIMAL(10, 2) NOT NULL,
    imagem     VARCHAR(255)   DEFAULT          'default.png',
    stock      INT            NOT NULL DEFAULT 0,
    categoria  VARCHAR(80),
    ativo      TINYINT(1)     NOT NULL DEFAULT 1,
    CONSTRAINT chk_preco_positivo CHECK (preco >= 0.00),
    CONSTRAINT chk_stock_positivo CHECK (stock >= 0)
) ENGINE=InnoDB
  COMMENT='Catálogo de produtos da mercearia';

CREATE TABLE encomenda
(
    id_encomenda   INT AUTO_INCREMENT PRIMARY KEY,
    codigo_unico   VARCHAR(20)    NOT NULL UNIQUE,
    id_utilizador  INT            NOT NULL,
    data_encomenda DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado         ENUM('pendente','processando','pronto','cancelado') NOT NULL DEFAULT 'pendente',
    total          DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    notas          TEXT,
    CONSTRAINT fk_encomenda_utilizador
        FOREIGN KEY (id_utilizador)
            REFERENCES utilizadores (id_utilizador)
            ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_total_positivo CHECK (total >= 0.00)
) ENGINE=InnoDB
  COMMENT='Encomendas realizadas pelos clientes';

CREATE TABLE encomenda_produto
(
    id_encomenda   INT            NOT NULL,
    id_produto     INT            NOT NULL,
    quantidade     INT            NOT NULL DEFAULT 1,
    preco_unitario DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (id_encomenda, id_produto),
    CONSTRAINT fk_ep_encomenda
        FOREIGN KEY (id_encomenda)
            REFERENCES encomenda (id_encomenda)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ep_produto
        FOREIGN KEY (id_produto)
            REFERENCES produtos (id_produto)
            ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_ep_quantidade CHECK (quantidade > 0),
    CONSTRAINT chk_ep_preco_unit CHECK (preco_unitario >= 0.00)
) ENGINE=InnoDB
  COMMENT='Produtos incluídos em cada encomenda (relação N:M)';

CREATE TABLE promocoes
(
    id_promocao          INT AUTO_INCREMENT PRIMARY KEY,
    titulo               VARCHAR(200)  NOT NULL,
    descricao            TEXT,
    desconto_percentagem DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    data_inicio          DATE          NOT NULL,
    data_fim             DATE          NOT NULL,
    ativo                TINYINT(1)     NOT NULL DEFAULT 1,
    CONSTRAINT chk_desconto_range CHECK (
        desconto_percentagem >= 0.00 AND desconto_percentagem <= 100.00
        ),
    CONSTRAINT chk_datas_validas CHECK (data_fim >= data_inicio)
) ENGINE=InnoDB
  COMMENT='Promoções e informações dinâmicas geridas pelos administradores';

CREATE TABLE promocao_produto
(
    id_promocao INT NOT NULL,
    id_produto  INT NOT NULL,
    PRIMARY KEY (id_promocao, id_produto),
    CONSTRAINT fk_pp_promocao
        FOREIGN KEY (id_promocao)
            REFERENCES promocoes (id_promocao)
            ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pp_produto
        FOREIGN KEY (id_produto)
            REFERENCES produtos (id_produto)
            ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB
  COMMENT='Produtos abrangidos por cada promoção (relação N:M)';

CREATE TABLE auditoria_carteira
(
    id_log              INT AUTO_INCREMENT PRIMARY KEY,
    id_carteira_origem  INT            NOT NULL,
    id_carteira_destino INT            NOT NULL,
    valor               DECIMAL(10, 2) NOT NULL,
    tipo_operacao       ENUM('deposito','levantamento','pagamento','reembolso') NOT NULL,
    data_operacao       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descricao           VARCHAR(255),
    id_encomenda        INT,
    CONSTRAINT fk_audit_origem
        FOREIGN KEY (id_carteira_origem)
            REFERENCES carteira (id_carteira)
            ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_audit_destino
        FOREIGN KEY (id_carteira_destino)
            REFERENCES carteira (id_carteira)
            ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_audit_encomenda
        FOREIGN KEY (id_encomenda)
            REFERENCES encomenda (id_encomenda)
            ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_valor_positivo CHECK (valor > 0.00)
) ENGINE=InnoDB
  COMMENT='Auditoria de todas as operações de carteira (imutável)';

INSERT INTO utilizadores (nome, email, password_hash, perfil, ativo)
VALUES ('FelixUberShop', 'sistema@felixubershop.pt', "70502ff6bb85356055ea52ff0a657afd09a52324a33734ccfb7bdedf05634925", 'administrador', 0);

INSERT INTO carteira (id_utilizador, saldo, is_loja)
VALUES (LAST_INSERT_ID(), 0.00, 1);

INSERT INTO utilizadores (nome, email, password_hash, perfil, telefone, morada)
VALUES ('Cliente Teste', 'cliente@felixubershop.pt', "a60b85d409a01d46023f90741e01b79543a3cb1ba048eaefbe5d7a63638043bf", 'cliente', '912 345 678',
        'Rua das Flores 1, Castelo Branco'),
       ('Funcionário Teste', 'funcionario@felixubershop.pt', "24d96a103e8552cb162117e5b94b1ead596b9c0a94f73bc47f7d244d279cacf2", 'funcionario', '923 456 789',
        'Av. Principal 10, Castelo Branco'),
       ('Administrador', 'admin@felixubershop.pt', "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918", 'administrador', '934 567 890',
        'Praça Central 5, Castelo Branco');

-- Criar carteiras iniciais para os utilizadores de teste
INSERT INTO carteira (id_utilizador, saldo, is_loja)
SELECT id_utilizador, 50.00, 0
FROM utilizadores
WHERE email IN (
                'cliente@felixubershop.pt',
                'funcionario@felixubershop.pt',
                'admin@felixubershop.pt'
    );

INSERT INTO produtos (nome, descricao, preco, stock, categoria)
VALUES ('Leite Meio-Gordo 1L', 'Leite pasteurizado meio-gordo', 0.89, 200, 'Lacticínios'),
       ('Pão de Forma Integral', 'Pão de forma integral 500g', 1.29, 150, 'Padaria'),
       ('Azeite Extra-Virgem 0.5L', 'Azeite virgem extra, acidez inferior a 0.3', 4.99, 80, 'Óleos'),
       ('Arroz Carolino 1kg', 'Arroz carolino nacional tipo 1', 1.49, 300, 'Mercearia Seca'),
       ('Frango Inteiro', 'Frango do campo, aproximadamente 1.2kg', 5.99, 50, 'Carnes'),
       ('Maçã Golden 1kg', 'Maçã golden portuguesa, calibre 60/70', 1.99, 120, 'Frutas'),
       ('Água Mineral 1.5L', 'Água mineral natural sem gás', 0.39, 500, 'Bebidas'),
       ('Detergente Loiça 500ml', 'Detergente líquido para loiça', 1.79, 90, 'Limpeza'),
       ('Massa Esparguete 500g', 'Massa de grano duro, cozedura 8 min', 0.99, 250, 'Mercearia Seca'),
       ('Iogurte Natural 4x125g', 'Iogurte natural sem açúcar, pack 4 unidades', 1.09, 180, 'Lacticínios');

INSERT INTO promocoes (titulo, descricao, desconto_percentagem, data_inicio, data_fim, ativo)
VALUES ('Promoção de Verão 2025',
        'Desconto especial de 10% em produtos selecionados. Aproveite enquanto dura!',
        10.00,
        '2025-06-01',
        '2025-08-31',
        1);

INSERT INTO promocao_produto (id_promocao, id_produto)
SELECT pr.id_promocao, p.id_produto
FROM promocoes pr,
     produtos p
WHERE pr.titulo = 'Promoção de Verão 2025'
  AND p.nome IN ('Leite Meio-Gordo 1L', 'Água Mineral 1.5L', 'Iogurte Natural 4x125g');

INSERT INTO encomenda (codigo_unico, id_utilizador, estado, total, notas)
SELECT 'FUS-2025-00001',
       u.id_utilizador,
       'pendente',
       7.27,
       'Entrega no período da manhã se possível.'
FROM utilizadores u
WHERE u.email = 'cliente@felixubershop.pt';

INSERT INTO encomenda_produto (id_encomenda, id_produto, quantidade, preco_unitario)
SELECT e.id_encomenda,
       p.id_produto,
       2,
       p.preco
FROM encomenda e,
     produtos p
WHERE e.codigo_unico = 'FUS-2025-00001'
  AND p.nome IN ('Leite Meio-Gordo 1L', 'Arroz Carolino 1kg', 'Água Mineral 1.5L');

INSERT INTO auditoria_carteira
(id_carteira_origem, id_carteira_destino, valor, tipo_operacao, descricao, id_encomenda)
SELECT c_cliente.id_carteira,
       c_loja.id_carteira,
       7.27,
       'pagamento',
       'Pagamento da encomenda FUS-2025-00001',
       e.id_encomenda
FROM carteira c_cliente
         JOIN utilizadores u ON u.id_utilizador = c_cliente.id_utilizador
         JOIN carteira c_loja ON c_loja.is_loja = 1
         JOIN encomenda e ON e.codigo_unico = 'FUS-2025-00001'
WHERE u.email = 'cliente@felixubershop.pt';
