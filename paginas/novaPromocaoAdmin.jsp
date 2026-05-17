<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    // Verificacao da sessao e perfil de administrador
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    if (!"administrador".equals(sess.getAttribute("userRole"))) {
        response.sendRedirect("adminDashboard.jsp");
        return;
    }
    String adminName = (String) sess.getAttribute("userName");
    if (adminName == null) adminName = "Administrador";
    String activePage = "promocoes";

    String errorMsg = null;

    // Processar submissao do formulario de nova promocao
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String titulo = request.getParameter("titulo");
        String descontoStr = request.getParameter("desconto");
        String dataInicio = request.getParameter("dataInicio");
        String dataFim = request.getParameter("dataFim");
        String[] prodIds = request.getParameterValues("produtos");

        if (titulo == null || titulo.trim().isEmpty() || descontoStr == null ||
                dataInicio == null || dataInicio.isEmpty() || dataFim == null || dataFim.isEmpty()) {
            errorMsg = "Todos os campos são obrigatórios.";
        } else {
            try {
                double desconto = Double.parseDouble(descontoStr.replace(",", "."));
                Connection conn = getConnection();
                PreparedStatement ps = conn.prepareStatement(
                        "INSERT INTO promocoes (titulo, desconto_percentagem, data_inicio, data_fim, ativo) VALUES (?,?,?,?,1)",
                        java.sql.Statement.RETURN_GENERATED_KEYS);
                ps.setString(1, titulo.trim());
                ps.setDouble(2, desconto);
                ps.setString(3, dataInicio);
                ps.setString(4, dataFim);
                ps.executeUpdate();
                ResultSet keys = ps.getGeneratedKeys();
                int newId = keys.next() ? keys.getInt(1) : -1;
                keys.close();
                ps.close();
                if (newId > 0 && prodIds != null) {
                    ps = conn.prepareStatement(
                            "INSERT INTO promocao_produto (id_promocao, id_produto) VALUES (?,?)");
                    for (String pid : prodIds) {
                        ps.setInt(1, newId);
                        ps.setInt(2, Integer.parseInt(pid));
                        ps.executeUpdate();
                    }
                    ps.close();
                }
                conn.close();
                logAuditoria("Promoção", "criada", "Promoção criada: " + titulo.trim(), newId > 0 ? newId : null, (Integer) sess.getAttribute("userId"));
                sess.setAttribute("success", "Promoção criada com sucesso.");
                response.sendRedirect("promocoesAdmin.jsp?promoId=" + newId);
                return;
            } catch (NumberFormatException e) {
                errorMsg = "Desconto inválido.";
            } catch (Exception e) {
                errorMsg = "Erro: " + e.getMessage();
            }
        }
    }

    // Carregar catalogo de produtos ativos disponiveis
    List<Object[]> catalogue = new ArrayList<>();
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        conn = getConnection();
        ps = conn.prepareStatement(
                "SELECT id_produto, nome, CAST(preco*100 AS SIGNED) as preco_cents " +
                        "FROM produtos WHERE ativo=1 ORDER BY nome");
        rs = ps.executeQuery();
        while (rs.next()) {
            catalogue.add(new Object[]{
                    String.valueOf(rs.getInt("id_produto")),
                    rs.getString("nome"),
                    (int) rs.getLong("preco_cents")
            });
        }
    } catch (Exception _e) {
    } finally {
        closeAll(rs, ps, conn);
    }
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>novaPromoçãoAdmin</title>
    <style>
        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background: #212121;
            color: #e0e0e0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .topnav {
            background: #2a2a2a;
            border-bottom: 1px solid #333;
            height: 52px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 24px;
            position: sticky;
            top: 0;
            z-index: 200;
        }

        .nav-brand {
            font-size: 1.2rem;
            font-weight: 700;
            color: #00CE86;
            text-decoration: none;
        }

        .nav-right {
            display: flex;
            align-items: center;
            gap: 18px;
        }

        .nav-user {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: .87rem;
            color: #bbb;
        }

        .nav-user svg {
            fill: #00CE86;
            width: 20px;
            height: 20px;
        }

        .btn-sair {
            background: none;
            border: 1px solid #555;
            color: #aaa;
            font-size: .8rem;
            padding: 5px 14px;
            border-radius: 6px;
            cursor: pointer;
            text-decoration: none;
            transition: border-color .2s, color .2s;
        }

        .btn-sair:hover {
            border-color: #e05555;
            color: #e05555;
        }

        .app-shell {
            display: flex;
            flex: 1;
            min-height: 0;
        }

        .sidebar {
            width: 215px;
            flex-shrink: 0;
            background: #111;
            border-right: 1px solid #1e1e1e;
            display: flex;
            flex-direction: column;
            padding: 24px 0 16px;
        }

        .sidebar-label {
            font-size: .67rem;
            font-weight: 700;
            letter-spacing: 1.2px;
            color: #3a3a3a;
            text-transform: uppercase;
            padding: 0 20px 14px;
        }

        .sidebar-nav {
            list-style: none;
            flex: 1;
        }

        .sidebar-nav li a {
            display: flex;
            align-items: center;
            gap: 11px;
            padding: 11px 20px;
            text-decoration: none;
            font-size: .88rem;
            color: #777;
            border-left: 3px solid transparent;
            transition: background .15s, color .15s, border-color .15s;
        }

        .sidebar-nav li a:hover {
            background: rgba(255, 255, 255, .04);
            color: #ddd;
        }

        .sidebar-nav li a.active {
            border-left-color: #00CE86;
            background: rgba(0, 206, 134, .07);
            color: #00CE86;
            font-weight: 600;
        }

        .sidebar-nav li a svg {
            width: 17px;
            height: 17px;
            fill: currentColor;
            flex-shrink: 0;
        }

        .sidebar-divider {
            height: 1px;
            background: #1e1e1e;
            margin: 10px 20px;
        }

        .main-content {
            flex: 1;
            padding: 26px 26px 48px;
            overflow-y: auto;
            min-width: 0;
        }

        .page-grid {
            display: grid;
            grid-template-columns: 1fr 280px;
            gap: 16px;
            align-items: start;
        }

        .panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .panel-header {
            padding: 14px 18px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            gap: 9px;
        }

        .panel-title {
            font-size: .95rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .panel-title svg {
            fill: #00CE86;
            width: 17px;
            height: 17px;
        }

        .alert {
            margin: 14px 18px 0;
            padding: 10px 14px;
            border-radius: 8px;
            font-size: .84rem;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .alert svg {
            width: 15px;
            height: 15px;
            flex-shrink: 0;
        }

        .alert-error {
            background: rgba(220, 60, 60, .1);
            border: 1px solid rgba(220, 60, 60, .3);
            color: #f08080;
        }

        .form-body {
            padding: 16px 18px 0;
        }

        .field-group {
            margin-bottom: 14px;
        }

        .field-label {
            font-size: .78rem;
            color: #888;
            margin-bottom: 5px;
            display: block;
        }

        .field-input {
            width: 100%;
            background: #1a1a1a;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #fff;
            font-size: .88rem;
            padding: 8px 11px;
            outline: none;
            font-family: inherit;
            transition: border-color .2s, box-shadow .2s;
        }

        .field-input:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .1);
        }

        input[type="date"].field-input {
            color-scheme: dark;
        }

        .dates-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-bottom: 14px;
        }

        .prods-label {
            font-size: .78rem;
            color: #888;
            margin-bottom: 6px;
            display: block;
        }

        .prod-list {
            border: 1px solid #2e2e2e;
            border-radius: 8px;
            overflow: hidden;
            margin-bottom: 18px;
        }

        .prod-item {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 9px 12px;
            border-bottom: 1px solid #242424;
            cursor: pointer;
            transition: background .15s;
        }

        .prod-item:last-child {
            border-bottom: none;
        }

        .prod-item:hover {
            background: rgba(255, 255, 255, .03);
        }

        .prod-item-left {
            display: flex;
            align-items: center;
            gap: 9px;
        }

        .prod-item input[type="checkbox"] {
            accent-color: #00CE86;
            width: 15px;
            height: 15px;
            cursor: pointer;
            flex-shrink: 0;
        }

        .prod-item-nome {
            font-size: .86rem;
            color: #ccc;
        }

        .prod-item-preco {
            font-size: .83rem;
            color: #666;
        }

        .prod-item-disc {
            font-size: .83rem;
            color: #00CE86;
            font-weight: 600;
        }

        .btn-criar {
            width: 100%;
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 8px;
            padding: 11px;
            font-size: .92rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s;
            margin-bottom: 10px;
        }

        .btn-criar:hover {
            background: #00b876;
        }

        .btn-voltar {
            display: block;
            text-align: center;
            color: #666;
            font-size: .84rem;
            text-decoration: none;
            padding: 8px;
            transition: color .2s;
            margin-bottom: 14px;
        }

        .btn-voltar:hover {
            color: #aaa;
        }

        /* Preview panel */
        .preview-panel {
            background: #262626;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .preview-header {
            padding: 12px 16px;
            border-bottom: 1px solid #333;
            font-size: .72rem;
            font-weight: 700;
            letter-spacing: .8px;
            text-transform: uppercase;
            color: #555;
        }

        .promo-card {
            margin: 14px 16px 10px;
            background: #00CE86;
            color: #111;
            border-radius: 8px;
            padding: 12px 14px;
        }

        .promo-card-title {
            font-size: .9rem;
            font-weight: 700;
            line-height: 1.3;
        }

        .promo-card-dates {
            font-size: .73rem;
            margin-top: 4px;
            opacity: .75;
        }

        .preview-prods-label {
            font-size: .75rem;
            color: #888;
            padding: 10px 16px 6px;
        }

        .preview-prod-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 6px 16px;
            border-top: 1px solid #2a2a2a;
        }

        .preview-prod-nome {
            font-size: .83rem;
            color: #ccc;
        }

        .preview-prod-prices {
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .price-orig {
            font-size: .78rem;
            color: #555;
            text-decoration: line-through;
        }

        .price-disc {
            font-size: .83rem;
            color: #00CE86;
            font-weight: 700;
        }

        .preview-empty {
            padding: 16px;
            font-size: .82rem;
            color: #555;
            font-style: italic;
            text-align: center;
        }

        @media (max-width: 860px) {
            .page-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>

<nav class="topnav">
    <a href="adminDashboard.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-right">
        <div class="nav-user">
            <svg viewBox="0 0 24 24">
                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
            </svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= adminName %>
        </strong>
        </div>
        <a href="login.jsp" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <aside class="sidebar">
        <div class="sidebar-label">Área Admin</div>
        <ul class="sidebar-nav">
            <li><a href="adminDashboard.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                </svg>
                <span>Dashboard</span></a></li>
            <li><a href="encomendasAdmin.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1z"/>
                </svg>
                <span>Encomendas</span></a></li>
            <li><a href="saldoClientesAdmin.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                </svg>
                <span>Saldo clientes</span></a></li>
            <li><a href="produtosAdmin.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 12H9v-2h6v2zm2-4H7V8h10v2z"/>
                </svg>
                <span>Produtos</span></a></li>
            <li><a href="utilizadoresAdmin.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                </svg>
                <span>Utilizadores</span></a></li>
            <li><a href="promocoesAdmin.jsp" class="active">
                <svg viewBox="0 0 24 24">
                    <path d="M21.41 11.58l-9-9C12.05 2.22 11.55 2 11 2H4c-1.1 0-2 .9-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/>
                </svg>
                <span>Promoções</span></a></li>
            <li><a href="auditoriaAdmin.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                </svg>
                <span>Auditoria</span></a></li>
            <div class="sidebar-divider"></div>
            <li><a href="perfilAdmin.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                </svg>
                <span>Perfil</span></a></li>
        </ul>
    </aside>

    <main class="main-content">
        <div class="page-grid">

            <!-- Formulario de nova promocao -->
            <div class="panel">
                <div class="panel-header">
                    <svg class="panel-title" viewBox="0 0 24 24"
                         style="fill:#00CE86;width:17px;height:17px;flex-shrink:0;">
                        <path d="M21.41 11.58l-9-9C12.05 2.22 11.55 2 11 2H4c-1.1 0-2 .9-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/>
                    </svg>
                    <span class="panel-title">Nova promoção</span>
                </div>

                <% if (errorMsg != null) { %>
                <div class="alert alert-error">
                    <svg viewBox="0 0 24 24" fill="#f08080">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
                    </svg>
                    <%= errorMsg %>
                </div>
                <% } %>

                <form action="novaPromocaoAdmin.jsp" method="post" onsubmit="return validar()">
                    <div class="form-body">

                        <div class="field-group">
                            <label class="field-label" for="fTitulo">Título da promoção</label>
                            <input type="text" id="fTitulo" name="titulo" class="field-input"
                                   placeholder="ex: Promoção de Verão" oninput="atualizarPreview()" required/>
                        </div>

                        <div class="field-group">
                            <label class="field-label" for="fDesconto">Desconto (%)</label>
                            <input type="number" id="fDesconto" name="desconto" class="field-input"
                                   placeholder="ex: 10" min="1" max="100" oninput="atualizarPreview()" required/>
                        </div>

                        <div class="dates-row">
                            <div>
                                <label class="field-label" for="fInicio">Data de início</label>
                                <input type="date" id="fInicio" name="dataInicio" class="field-input"
                                       onchange="atualizarPreview()" required/>
                            </div>
                            <div>
                                <label class="field-label" for="fFim">Data de fim</label>
                                <input type="date" id="fFim" name="dataFim" class="field-input"
                                       onchange="atualizarPreview()" required/>
                            </div>
                        </div>

                        <span class="prods-label">Produtos em promoção</span>
                        <div class="prod-list">
                            <%
                                for (Object[] cat : catalogue) {
                                    String catId = (String) cat[0];
                                    String catNome = (String) cat[1];
                                    int catPreco = (Integer) cat[2];
                                    String precoStr = String.format("%d,%02d", catPreco / 100, catPreco % 100);
                            %>
                            <label class="prod-item" id="item_<%= catId %>">
                                <div class="prod-item-left">
                                    <input type="checkbox" name="produtos" value="<%= catId %>"
                                           data-nome="<%= catNome %>" data-preco="<%= catPreco %>"
                                           onchange="atualizarPreview()"/>
                                    <span class="prod-item-nome"><%= catNome %></span>
                                </div>
                                <span class="prod-item-preco" id="preco_<%= catId %>"><%= precoStr %> &euro;</span>
                            </label>
                            <% } %>
                        </div>

                        <button type="submit" class="btn-criar">Criar promoção</button>
                        <a href="promocoesAdmin.jsp" class="btn-voltar">&#8592; Voltar à lista</a>
                    </div>
                </form>
            </div>

            <!-- RIGHT: PREVIEW -->
            <div class="preview-panel">
                <div class="preview-header">Pré-visualização no site</div>
                <div class="promo-card" id="prevCard">
                    <div class="promo-card-title" id="prevTitulo">Título da promoção — 0% desconto</div>
                    <div class="promo-card-dates" id="prevDatas">Válida de — até —</div>
                </div>
                <div class="preview-prods-label">Produtos com desconto:</div>
                <div id="prevProdos">
                    <div class="preview-empty">Nenhum produto selecionado.</div>
                </div>
            </div>

        </div>
    </main>
</div>

<script>
    function fmt(cents) {
        return (cents / 100).toFixed(2).replace('.', ',') + ' €';
    }

    function fmtDate(val) {
        if (!val) return '—';
        var p = val.split('-');
        if (p.length !== 3) return val;
        return p[2] + '/' + p[1] + '/' + p[0];
    }

    function atualizarPreview() {
        var titulo = document.getElementById('fTitulo').value.trim() || 'Título da promoção';
        var descPct = parseInt(document.getElementById('fDesconto').value) || 0;
        var inicio = document.getElementById('fInicio').value;
        var fim = document.getElementById('fFim').value;

        document.getElementById('prevTitulo').textContent =
            titulo + (descPct > 0 ? ' — ' + descPct + '% desconto' : '');
        document.getElementById('prevDatas').textContent =
            'Válida de ' + fmtDate(inicio) + ' até ' + fmtDate(fim);

        var caixas = document.querySelectorAll('input[name="produtos"]:checked');
        var html = '';
        for (var i = 0; i < caixas.length; i++) {
            var nome = caixas[i].getAttribute('data-nome');
            var preco = parseInt(caixas[i].getAttribute('data-preco'));
            var disc = descPct > 0 ? Math.round(preco * (1 - descPct / 100)) : preco;
            html += '<div class="preview-prod-item">' +
                '<span class="preview-prod-nome">' + nome + '</span>' +
                '<span class="preview-prod-prices">' +
                (descPct > 0 ? '<span class="price-orig">' + fmt(preco) + '</span>' : '') +
                '<span class="price-disc">' + fmt(disc) + '</span>' +
                '</span></div>';

            var precoSpan = document.getElementById('preco_' + caixas[i].value);
            if (precoSpan) {
                precoSpan.innerHTML = descPct > 0
                    ? '<span style="text-decoration:line-through;color:#555;">' + fmt(preco) + '</span> <span style="color:#00CE86;font-weight:700;">' + fmt(disc) + '</span>'
                    : fmt(preco);
            }
        }

        var allChk = document.querySelectorAll('input[name="produtos"]');
        for (var j = 0; j < allChk.length; j++) {
            if (!allChk[j].checked) {
                var ps = document.getElementById('preco_' + allChk[j].value);
                if (ps) {
                    var p2 = parseInt(allChk[j].getAttribute('data-preco'));
                    ps.textContent = fmt(p2);
                }
            }
        }

        document.getElementById('prevProdos').innerHTML =
            html || '<div class="preview-empty">Nenhum produto selecionado.</div>';
    }

    function validar() {
        var d = parseInt(document.getElementById('fDesconto').value);
        if (isNaN(d) || d < 1 || d > 100) {
            alert('O desconto deve ser um número entre 1 e 100.');
            return false;
        }
        var ini = document.getElementById('fInicio').value;
        var fim = document.getElementById('fFim').value;
        if (ini && fim && ini > fim) {
            alert('A data de início não pode ser posterior à data de fim.');
            return false;
        }
        return true;
    }
</script>
</body>
</html>
