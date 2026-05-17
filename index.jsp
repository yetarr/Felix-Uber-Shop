<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    // Obter os produtos ativos com as promocoes da base de dados
    String sqlGetOrders =
            "SELECT p.*, pp.desconto_percentagem, pp.data_inicio, pp.data_fim " +
                    "FROM produtos p " +
                    "LEFT JOIN promocao_produto pr ON pr.id_produto = p.id_produto " +
                    "LEFT JOIN promocoes pp ON pp.id_promocao = pr.id_promocao " +
                    "WHERE p.ativo = 1;";
    Connection con = getConnection();
    PreparedStatement ps = con.prepareStatement(sqlGetOrders);
    ResultSet rs = ps.executeQuery();

    // Adicionar todos os produtos a uma lista
    List<String[]> products = new ArrayList<>();

    while(rs.next())
    {
        String id = (rs.getString("id_produto"));
        String nome = (rs.getString("nome"));
        String descricao = (rs.getString("descricao"));
        String preco = (rs.getString("preco"));
        String stock = (rs.getString("stock"));
        String categoria = (rs.getString("categoria"));
        String desconto = rs.getString("desconto_percentagem");
        String precoDescontado = preco;

        // verificacao da existecia de uma promocao
        if (desconto != null) {
            double price = Double.parseDouble(preco);
            double discount = Double.parseDouble(desconto);

            double discounted = price - (price * discount / 100.0);
            precoDescontado = String.format("%.2f", discounted);
        } else {
            desconto = "0";
        }

        String[] product = {
                id,
                nome,
                descricao,
                preco,
                stock,
                categoria,
                desconto,
                precoDescontado
        };

        products.add(product);
    }

    // horario
    String[][] hours = {
            {"Segunda a sexta", "08h00 – 20h00"},
            {"Sábado", "09h00 – 18h00"},
            {"Domingo", "Encerrado"},
    };
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop</title>
    <style>
        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: #171717;
            color: #e0e0e0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        nav {
            background-color: #222;
            padding: 0 32px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            height: 54px;
            border-bottom: 1px solid #2e2e2e;
            position: sticky;
            top: 0;
            z-index: 100;
        }

        .nav-brand {
            font-size: 1.3rem;
            font-weight: 700;
            color: #00CE86;
            text-decoration: none;
            letter-spacing: 0.4px;
        }

        .nav-links {
            display: flex;
            gap: 10px;
            align-items: center;
        }

        .nav-links a {
            text-decoration: none;
            font-size: 0.82rem;
            font-weight: 600;
            letter-spacing: 0.6px;
            padding: 7px 16px;
            border-radius: 6px;
            transition: background 0.2s, color 0.2s;
        }

        .btn-login {
            color: #00CE86;
            border: 1px solid #00CE86;
        }

        .btn-login:hover {
            background: rgba(0, 206, 134, 0.1);
        }

        .btn-register {
            color: #111;
            background-color: #00CE86;
        }

        .btn-register:hover {
            background-color: #00b876;
        }

        main {
            flex: 1;
            display: grid;
            grid-template-columns: 1fr 320px;
            gap: 20px;
            max-width: 1100px;
            width: 100%;
            margin: 0 auto;
            padding: 28px 20px;
            align-items: start;
        }

        .section-title {
            font-size: 1rem;
            font-weight: 700;
            color: #ffffff;
            letter-spacing: 0.4px;
            margin-bottom: 14px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .section-title svg {
            fill: #00CE86;
            width: 18px;
            height: 18px;
            flex-shrink: 0;
        }

        .products-section {
        }

        .product-list {
            display: flex;
            flex-direction: column;
            gap: 10px;
        }

        .product-card {
            background-color: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 14px 16px;
            display: flex;
            align-items: center;
            gap: 16px;
            transition: border-color 0.2s;
        }

        .product-card:hover {
            border-color: #00CE86;
        }

        .product-img {
            width: 56px;
            height: 56px;
            border-radius: 8px;
            background-color: #383838;
            flex-shrink: 0;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }

        .product-img svg {
            width: 28px;
            height: 28px;
            fill: #555;
        }

        .product-img img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            border-radius: 8px;
        }

        .product-info {
            flex: 1;
            min-width: 0;
        }

        .product-name {
            font-size: 0.95rem;
            font-weight: 600;
            color: #e8e8e8;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .product-qty {
            font-size: 0.78rem;
            color: #777;
            margin-top: 2px;
        }

        .product-price {
            display: flex;
            flex-direction: column;
            align-items: flex-end;
            gap: 3px;
            flex-shrink: 0;
        }

        .price-final {
            font-size: 1.05rem;
            font-weight: 700;
            color: #00CE86;
        }

        .price-original {
            font-size: 0.78rem;
            color: #666;
            text-decoration: line-through;
        }

        .discount-badge {
            background-color: rgba(0, 206, 134, 0.15);
            border: 1px solid rgba(0, 206, 134, 0.35);
            color: #00CE86;
            font-size: 0.7rem;
            font-weight: 700;
            padding: 2px 7px;
            border-radius: 20px;
            letter-spacing: 0.3px;
        }

        .right-col {
            display: flex;
            flex-direction: column;
            gap: 16px;
        }

        .info-card {
            background-color: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 18px 20px;
        }

        .hours-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 4px;
        }

        .hours-table tr {
            border-bottom: 1px solid #333;
        }

        .hours-table tr:last-child {
            border-bottom: none;
        }

        .hours-table td {
            padding: 8px 0;
            font-size: 0.85rem;
        }

        .hours-table td:first-child {
            color: #aaa;
        }

        .hours-table td:last-child {
            text-align: right;
            font-weight: 600;
            color: #e0e0e0;
        }

        .hours-table .closed {
            color: #e05555 !important;
        }

        .contact-list {
            list-style: none;
            margin-top: 4px;
            display: flex;
            flex-direction: column;
            gap: 10px;
        }

        .contact-list li {
            display: flex;
            align-items: flex-start;
            gap: 10px;
            font-size: 0.85rem;
        }

        .contact-list .ci {
            width: 18px;
            height: 18px;
            fill: #00CE86;
            flex-shrink: 0;
            margin-top: 1px;
        }

        .contact-list .label {
            color: #777;
            font-size: 0.75rem;
            display: block;
            margin-bottom: 1px;
        }

        .contact-list .value {
            color: #e0e0e0;
        }

        footer {
            text-align: center;
            padding: 16px;
            font-size: 0.75rem;
            color: #3d3d3d;
            border-top: 1px solid #222;
        }

        @media (max-width: 680px) {
            main {
                grid-template-columns: 1fr;
            }

            nav {
                padding: 0 16px;
            }

            .nav-brand {
                font-size: 1.1rem;
            }
        }
    </style>
</head>
<body>
<nav>
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-links">
        <a href="login.jsp" class="btn-login">LOGIN</a>
        <a href="register.jsp" class="btn-register">REGISTAR</a>
    </div>
</nav>

<main>

    <section class="products-section">
        <h2 class="section-title">
            <svg viewBox="0 0 24 24">
                <path d="M7 18c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm10 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zM7.17 14l.03-.12.9-1.88H17c.75 0 1.41-.41 1.75-1.03l3.86-7.01A1 1 0 0 0 21.75 2H5.21l-.94-2H1v2h2l3.6 7.59L5.25 11C4.52 11.37 4 12.13 4 13c0 1.1.9 2 2 2h12v-2H7.42c-.13 0-.25-.11-.25-.25z"/>
            </svg>
            Produtos &amp; Promoções
        </h2>

        <div class="product-list">
            <%
                // Apresenttar produtos
                for (String[] p : products) {
                    String name = p[1];
                    String quantity = p[4];
                    String originalPrice = p[3];
                    double discount = Double.parseDouble(p[6]);
                    String finalPrice = p[7];
                    boolean hasDiscount = discount > 0;
            %>
            <div class="product-card">

                <div class="product-img">
                    <svg viewBox="0 0 24 24">
                        <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 14l-5-5 1.41-1.41L12 14.17l7.59-7.59L21 8l-9 9z"/>
                    </svg>
                </div>

                <!-- Informacao do produto -->
                <div class="product-info">
                    <div class="product-name"><%= name %>
                    </div>
                    <% if (!quantity.isEmpty()) { %>
                    <div class="product-qty">qtd: <%= quantity %>
                    </div>
                    <% } %>
                </div>

                <!-- Informacao do preco do produto -->
                <div class="product-price">
                    <% if (hasDiscount) { %>
                    <span class="discount-badge">-<%= discount %>%</span>
                    <span class="price-original"><%= originalPrice %>€</span>
                    <% } %>
                    <span class="price-final"><%= finalPrice %>€</span>
                </div>

            </div>
            <% } %>
        </div>
    </section>

    <aside class="right-col">

        <div class="info-card">
            <h3 class="section-title">
                <svg viewBox="0 0 24 24">
                    <path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67V7z"/>
                </svg>
                Horários
            </h3>
            <!-- Tabela de horarios -->
            <table class="hours-table">
                <%
                    for (String[] h : hours) {
                        boolean closed = h[1].equalsIgnoreCase("Encerrado");
                %>
                <tr>
                    <td><%= h[0] %>
                    </td>
                    <td class="<%= closed ? "closed" : "" %>"><%= h[1] %>
                    </td>
                </tr>
                <% } %>
            </table>
        </div>

        <div class="info-card">
            <h3 class="section-title">
                <svg viewBox="0 0 24 24">
                    <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5S10.62 6.5 12 6.5s2.5 1.12 2.5 2.5S13.38 11.5 12 11.5z"/>
                </svg>
                Contactos e localização
            </h3>
            <ul class="contact-list">
                <li>
                    <svg class="ci" viewBox="0 0 24 24">
                        <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5S10.62 6.5 12 6.5s2.5 1.12 2.5 2.5S13.38 11.5 12 11.5z"/>
                    </svg>
                    <div>
                        <span class="label">Morada</span>
                        <span class="value">Rua Fictícia, 06</span>
                    </div>
                </li>
                <li>
                    <svg class="ci" viewBox="0 0 24 24">
                        <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5S10.62 6.5 12 6.5s2.5 1.12 2.5 2.5S13.38 11.5 12 11.5z"/>
                    </svg>
                    <div>
                        <span class="label">Localidade</span>
                        <span class="value">Castelo Branco</span>
                    </div>
                </li>
                <li>
                    <svg class="ci" viewBox="0 0 24 24">
                        <path d="M6.62 10.79a15.05 15.05 0 0 0 6.59 6.59l2.2-2.2c.27-.27.67-.36 1.02-.24 1.12.37 2.33.57 3.57.57.55 0 1 .45 1 1V20c0 .55-.45 1-1 1C10.28 21 3 13.72 3 4.5c0-.55.45-1 1-1H7c.55 0 1 .45 1 1 0 1.25.2 2.45.57 3.57.11.35.03.74-.24 1.02l-2.2 2.2z"/>
                    </svg>
                    <div>
                        <span class="label">Telefone</span>
                        <a href="tel:271000000" class="value" style="color:#e0e0e0;text-decoration:none;">271 000
                            000</a>
                    </div>
                </li>
                <li>
                    <svg class="ci" viewBox="0 0 24 24">
                        <path d="M20 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 4-8 5-8-5V6l8 5 8-5v2z"/>
                    </svg>
                    <div>
                        <span class="label">Email</span>
                        <a href="mailto:felixubershop@felixubershop.com" class="value"
                           style="color:#00CE86;text-decoration:none;word-break:break-all;">
                            felixubershop@felixubershop.com
                        </a>
                    </div>
                </li>
            </ul>
        </div>

    </aside>

</main>

<footer>
    &copy; <%= java.time.Year.now().getValue() %> FelixUberShop. Todos os direitos reservados.
</footer>

</body>
</html>
