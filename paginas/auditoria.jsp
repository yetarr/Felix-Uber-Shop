<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ include file="basedados/basedados.h" %>
<%
    // Session check
    if (session.getAttribute("userId") == null || !"funcionario".equals(session.getAttribute("userPerfil"))) {
        response.sendRedirect("funcDashboard.jsp");
        return;
    }
    String funcName = (String) session.getAttribute("userName");

    List<String[]> logs = new ArrayList<>();

    Connection _conn7 = null;
    PreparedStatement _ps7 = null;
    ResultSet _rs7 = null;
    try {
        _conn7 = getConnection();
        _ps7 = _conn7.prepareStatement(
            "SELECT ac.data_operacao, 'Carteira' as categoria, ac.tipo_operacao as acao, " +
            "u.nome as utilizador, COALESCE(ac.descricao,'') as detalhe, " +
            "ac.valor, ac.id_carteira_origem, c.id_carteira as user_carteira " +
            "FROM auditoria_carteira ac " +
            "JOIN carteira c ON c.id_carteira = ac.id_carteira_origem OR c.id_carteira = ac.id_carteira_destino " +
            "JOIN utilizadores u ON u.id_utilizador = c.id_utilizador AND c.is_loja = 0 " +
            "ORDER BY ac.data_operacao DESC LIMIT 50");
        _rs7 = _ps7.executeQuery();
        while (_rs7.next()) {
            String tipo = _rs7.getString("acao");
            double valor = _rs7.getDouble("valor");
            boolean isDebit = "pagamento".equals(tipo) || "levantamento".equals(tipo);
            String sign = isDebit ? "-" : "+";
            String valorFmt = sign + String.format("%,.2f €", valor).replace(".", ",");
            logs.add(new String[]{
                String.valueOf(_rs7.getTimestamp("data_operacao")),
                "Carteira",
                tipo,
                _rs7.getString("utilizador") != null ? _rs7.getString("utilizador") : "",
                _rs7.getString("detalhe"),
                valorFmt
            });
        }
    } catch (Exception _e7) {
        // page renders with empty logs on error
    } finally {
        closeAll(_rs7, _ps7, _conn7);
    }

    Map<String, Integer> tabCounts = new LinkedHashMap<>();
    tabCounts.put("Carteira", logs.size());
    tabCounts.put("Utilizador", 0);
    tabCounts.put("Produto", 0);
    tabCounts.put("Encomenda", 0);
    tabCounts.put("Promoção", 0);

    String activeTab = request.getParameter("tab") != null ? request.getParameter("tab") : "";
    String filterSearch = request.getParameter("search") != null ? request.getParameter("search") : "";
    String filterCat = request.getParameter("categoria") != null ? request.getParameter("categoria") : "";
    String filterFrom = request.getParameter("de") != null ? request.getParameter("de") : "";
    String filterTo = request.getParameter("ate") != null ? request.getParameter("ate") : "";
    String sortBy = request.getParameter("sort") != null ? request.getParameter("sort") : "data";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Auditoria</title>
    <style>
        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0
        }

        body {
            background: #212121;
            color: #e0e0e0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column
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
            z-index: 200
        }

        .nav-brand {
            font-size: 1.2rem;
            font-weight: 700;
            color: #00CE86;
            text-decoration: none
        }

        .nav-right {
            display: flex;
            align-items: center;
            gap: 18px
        }

        .nav-user {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: .87rem;
            color: #bbb
        }

        .nav-user svg {
            fill: #00CE86;
            width: 20px;
            height: 20px
        }

        .nav-role {
            font-size: .68rem;
            font-weight: 700;
            letter-spacing: .6px;
            background: rgba(0, 206, 134, .12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .25);
            padding: 2px 8px;
            border-radius: 20px;
            text-transform: uppercase
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
            transition: border-color .2s, color .2s
        }

        .btn-sair:hover {
            border-color: #e05555;
            color: #e05555
        }

        .app-shell {
            display: flex;
            flex: 1;
            min-height: 0
        }

        .sidebar {
            width: 215px;
            flex-shrink: 0;
            background: #111;
            border-right: 1px solid #1e1e1e;
            display: flex;
            flex-direction: column;
            padding: 24px 0 16px
        }

        .sidebar-label {
            font-size: .67rem;
            font-weight: 700;
            letter-spacing: 1.2px;
            color: #3a3a3a;
            text-transform: uppercase;
            padding: 0 20px 14px
        }

        .sidebar-nav {
            list-style: none;
            flex: 1
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
            transition: background .15s, color .15s, border-color .15s
        }

        .sidebar-nav li a:hover {
            background: rgba(255, 255, 255, .04);
            color: #ddd
        }

        .sidebar-nav li a.active {
            border-left-color: #00CE86;
            background: rgba(0, 206, 134, .07);
            color: #00CE86;
            font-weight: 600
        }

        .sidebar-nav li a svg {
            width: 17px;
            height: 17px;
            fill: currentColor;
            flex-shrink: 0
        }

        .sidebar-divider {
            height: 1px;
            background: #1e1e1e;
            margin: 10px 20px
        }

        .main-content {
            flex: 1;
            padding: 26px 26px 48px;
            overflow-y: auto;
            min-width: 0
        }

        .page-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 18px
        }

        .page-title {
            font-size: 1.3rem;
            font-weight: 700;
            color: #fff
        }

        .btn-export {
            display: flex;
            align-items: center;
            gap: 6px;
            background: none;
            border: 1px solid #444;
            color: #888;
            border-radius: 7px;
            padding: 7px 14px;
            font-size: .82rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: border-color .2s, color .2s
        }

        .btn-export:hover {
            border-color: #00CE86;
            color: #00CE86
        }

        .btn-export svg {
            fill: currentColor;
            width: 14px;
            height: 14px
        }

        .cat-tabs {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 6px;
            margin-bottom: 14px;
            display: flex;
            gap: 4px;
            flex-wrap: wrap
        }

        .cat-tab {
            display: flex;
            align-items: center;
            gap: 7px;
            padding: 8px 14px;
            border-radius: 7px;
            border: none;
            font-size: .83rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            color: #777;
            background: none;
            transition: background .15s, color .15s
        }

        .cat-tab:hover {
            background: rgba(255, 255, 255, .04);
            color: #ccc
        }

        .cat-tab.active {
            background: rgba(0, 206, 134, .1);
            color: #00CE86
        }

        .cat-tab .ti {
            width: 15px;
            height: 15px;
            fill: currentColor
        }

        .tab-badge {
            background: #333;
            color: #888;
            font-size: .68rem;
            font-weight: 700;
            padding: 1px 6px;
            border-radius: 20px;
            min-width: 18px;
            text-align: center
        }

        .cat-tab.active .tab-badge {
            background: rgba(0, 206, 134, .2);
            color: #00CE86
        }

        .filters-bar {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 12px 16px;
            margin-bottom: 16px;
            display: flex;
            gap: 10px;
            align-items: center;
            flex-wrap: wrap
        }

        .fi, .fs, .fd {
            background: #1e1e1e;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #ddd;
            font-size: .84rem;
            padding: 8px 11px;
            outline: none;
            transition: border-color .2s, box-shadow .2s
        }

        .fi {
            flex: 1;
            min-width: 150px
        }

        .fi::placeholder {
            color: #4a4a4a
        }

        .fi:focus, .fs:focus, .fd:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .1)
        }

        .fs option {
            background: #1e1e1e
        }

        .fd {
            width: 138px
        }

        .date-sep {
            color: #555;
            font-size: .8rem;
            flex-shrink: 0
        }

        .sort-group {
            display: flex;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            overflow: hidden;
            flex-shrink: 0
        }

        .sort-btn {
            background: none;
            border: none;
            color: #777;
            font-size: .78rem;
            font-weight: 600;
            padding: 8px 12px;
            cursor: pointer;
            transition: background .15s, color .15s
        }

        .sort-btn:not(:last-child) {
            border-right: 1px solid #3a3a3a
        }

        .sort-btn.active {
            background: rgba(0, 206, 134, .1);
            color: #00CE86
        }

        .sort-btn:hover:not(.active) {
            background: rgba(255, 255, 255, .04);
            color: #ccc
        }

        .btn-filter {
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            padding: 8px 16px;
            font-size: .84rem;
            font-weight: 700;
            cursor: pointer;
            white-space: nowrap;
            transition: background .2s;
            flex-shrink: 0
        }

        .btn-filter:hover {
            background: #00b876
        }

        .panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden
        }

        .panel-header {
            padding: 12px 18px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            justify-content: space-between
        }

        .panel-title {
            font-size: .88rem;
            font-weight: 700;
            color: #e8e8e8;
            display: flex;
            align-items: center;
            gap: 8px
        }

        .panel-title svg {
            fill: #00CE86;
            width: 15px;
            height: 15px
        }

        .results-count {
            font-size: .78rem;
            color: #666
        }

        .at {
            width: 100%;
            border-collapse: collapse
        }

        .at th {
            padding: 9px 14px;
            font-size: .7rem;
            font-weight: 700;
            letter-spacing: .6px;
            text-transform: uppercase;
            color: #555;
            text-align: left;
            border-bottom: 1px solid #333;
            background: #252525;
            white-space: nowrap
        }

        .at th.sortable {
            cursor: pointer;
            user-select: none
        }

        .at th.sortable:hover {
            color: #00CE86
        }

        .at th.sorted {
            color: #00CE86
        }

        .at td {
            padding: 11px 14px;
            font-size: .84rem;
            color: #bbb;
            border-bottom: 1px solid #272727;
            vertical-align: middle
        }

        .at tr:last-child td {
            border-bottom: none
        }

        .at tr:hover td {
            background: rgba(255, 255, 255, .02)
        }

        .dc {
            color: #888;
            font-size: .79rem;
            white-space: nowrap
        }

        .dtl {
            color: #ccc;
            max-width: 260px
        }

        .uc {
            color: #aaa;
            font-size: .81rem;
            white-space: nowrap
        }

        .cb {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            padding: 3px 9px;
            border-radius: 6px;
            font-size: .71rem;
            font-weight: 700;
            white-space: nowrap
        }

        .cb svg {
            width: 11px;
            height: 11px;
            fill: currentColor
        }

        .c-cart {
            background: rgba(100, 180, 255, .1);
            color: #7aadff;
            border: 1px solid rgba(100, 180, 255, .2)
        }

        .c-util {
            background: rgba(180, 100, 255, .1);
            color: #c07aff;
            border: 1px solid rgba(180, 100, 255, .2)
        }

        .c-prod {
            background: rgba(255, 200, 50, .1);
            color: #ffc83a;
            border: 1px solid rgba(255, 200, 50, .2)
        }

        .c-enc {
            background: rgba(0, 206, 134, .1);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .2)
        }

        .c-prom {
            background: rgba(255, 120, 50, .1);
            color: #ff8c4a;
            border: 1px solid rgba(255, 120, 50, .2)
        }

        .vc {
            font-weight: 700;
            white-space: nowrap;
            text-align: right
        }

        .vp {
            color: #00CE86
        }

        .vn {
            color: #e07070
        }

        .vz {
            color: #444
        }

        @media (max-width: 700px) {
            .sidebar {
                width: 56px
            }

            .sidebar-label, .sidebar-nav li a span {
                display: none
            }

            .sidebar-nav li a {
                padding: 13px;
                justify-content: center
            }

            .main-content {
                padding: 14px
            }

            .at th:nth-child(4), .at td:nth-child(4) {
                display: none
            }
        }
    </style>
</head>
<body>
<nav class="topnav">
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-right">
        <span class="nav-role">Funcionário</span>
        <div class="nav-user">
            <svg viewBox="0 0 24 24">
                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
            </svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= funcName %>
        </strong>
        </div>
        <a href="LogoutServlet" class="btn-sair">Sair</a>
    </div>
</nav>
<div class="app-shell">
    <aside class="sidebar">
        <div class="sidebar-label">Área Funcionário</div>
        <ul class="sidebar-nav">
            <li><a href="funcDashboard.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                </svg>
                <span>Dashboard</span></a></li>
            <li><a href="funcEncomendas.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                </svg>
                <span>Encomendas</span></a></li>
            <li><a href="saldoClientes.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                </svg>
                <span>Saldo clientes</span></a></li>
            <li><a href="auditoria.jsp" class="active">
                <svg viewBox="0 0 24 24">
                    <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                </svg>
                <span>Auditoria</span></a></li>
            <div class="sidebar-divider"></div>
            <li><a href="funcPerfil.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                </svg>
                <span>Perfil</span></a></li>
        </ul>
    </aside>
    <main class="main-content">
        <div class="page-header">
            <h1 class="page-title">Auditoria</h1>
            <a href="AuditoriaExportServlet" class="btn-export">
                <svg viewBox="0 0 24 24">
                    <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/>
                </svg>
                Exportar CSV
            </a>
        </div>

        <div class="cat-tabs">
            <a href="auditoria.jsp" class="cat-tab <%= "".equals(activeTab)          ? "active":"" %>" data-filter="">
                <svg class="ti" viewBox="0 0 24 24">
                    <path d="M3 13h2v-2H3v2zm0 4h2v-2H3v2zm0-8h2V7H3v2zm4 4h14v-2H7v2zm0 4h14v-2H7v2zM7 7v2h14V7H7z"/>
                </svg>
                Todos <span class="tab-badge"><%= logs.size() %></span>
            </a>
            <a href="auditoria.jsp?tab=Carteira" class="cat-tab <%= "Carteira".equals(activeTab)   ? "active":"" %>"
               data-filter="Carteira">
                <svg class="ti" viewBox="0 0 24 24">
                    <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                </svg>
                Carteira <span class="tab-badge"><%= tabCounts.getOrDefault("Carteira", 0) %></span>
            </a>
            <a href="auditoria.jsp?tab=Utilizador" class="cat-tab <%= "Utilizador".equals(activeTab) ? "active":"" %>"
               data-filter="Utilizador">
                <svg class="ti" viewBox="0 0 24 24">
                    <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                </svg>
                Utilizadores <span class="tab-badge"><%= tabCounts.getOrDefault("Utilizador", 0) %></span>
            </a>
            <a href="auditoria.jsp?tab=Produto" class="cat-tab <%= "Produto".equals(activeTab)    ? "active":"" %>"
               data-filter="Produto">
                <svg class="ti" viewBox="0 0 24 24">
                    <path d="M18.06 22.99h1.66c.84 0 1.53-.64 1.63-1.46L23 5.05h-5V1h-1.97v4.05h-4.97l.3 2.34c1.71.47 3.31 1.32 4.27 2.26 1.44 1.42 2.43 2.89 2.43 5.29v8.05zM1 21.99V21h15.03v.99c0 .55-.45 1-1.01 1H2.01c-.56 0-1.01-.45-1.01-1zm15.03-7c0-3.87-3.13-7-7-7S2 11.12 2 14.99v2h14.03v-2z"/>
                </svg>
                Produtos <span class="tab-badge"><%= tabCounts.getOrDefault("Produto", 0) %></span>
            </a>
            <a href="auditoria.jsp?tab=Encomenda" class="cat-tab <%= "Encomenda".equals(activeTab)  ? "active":"" %>"
               data-filter="Encomenda">
                <svg class="ti" viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1z"/>
                </svg>
                Encomendas <span class="tab-badge"><%= tabCounts.getOrDefault("Encomenda", 0) %></span>
            </a>
            <a href="auditoria.jsp?tab=Promoção" class="cat-tab <%= "Promoção".equals(activeTab)   ? "active":"" %>"
               data-filter="Promoção">
                <svg class="ti" viewBox="0 0 24 24">
                    <path d="M21.41 11.58l-9-9A2 2 0 0 0 11 2H4a2 2 0 0 0-2 2v7c0 .53.21 1.04.59 1.42l9 9A2 2 0 0 0 13 22a2 2 0 0 0 1.41-.59l7-7A2 2 0 0 0 22 13a2 2 0 0 0-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/>
                </svg>
                Promoções <span class="tab-badge"><%= tabCounts.getOrDefault("Promoção", 0) %></span>
            </a>
        </div>

        <form action="auditoria.jsp" method="get">
            <input type="hidden" name="tab" value="<%= activeTab %>"/>
            <div class="filters-bar">
                <input type="text" name="search" class="fi" placeholder="Pesquisar..." value="<%= filterSearch %>"/>
                <select name="categoria" class="fs">
                    <option value="">Todas as categorias</option>
                    <option value="Carteira"   <%= "Carteira".equals(filterCat) ? "selected" : "" %>>Carteira</option>
                    <option value="Utilizador" <%= "Utilizador".equals(filterCat) ? "selected" : "" %>>Utilizadores
                    </option>
                    <option value="Produto"    <%= "Produto".equals(filterCat) ? "selected" : "" %>>Produtos</option>
                    <option value="Encomenda"  <%= "Encomenda".equals(filterCat) ? "selected" : "" %>>Encomendas
                    </option>
                    <option value="Promoção"   <%= "Promoção".equals(filterCat) ? "selected" : "" %>>Promoções</option>
                </select>
                <input type="date" name="de" class="fd" value="<%= filterFrom %>"/>
                <span class="date-sep">→</span>
                <input type="date" name="ate" class="fd" value="<%= filterTo %>"/>
                <div class="sort-group">
                    <button type="submit" name="sort" value="data"
                            class="sort-btn <%= "data".equals(sortBy)  ?"active":"" %>">↕ Data
                    </button>
                    <button type="submit" name="sort" value="valor"
                            class="sort-btn <%= "valor".equals(sortBy) ?"active":"" %>">↕ Valor
                    </button>
                </div>
                <button type="submit" class="btn-filter">Filtrar</button>
            </div>
        </form>

        <div class="panel">
            <div class="panel-header">
                <div class="panel-title">
                    <svg viewBox="0 0 24 24">
                        <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                    </svg>
                    Registo geral da loja
                </div>
                <span class="results-count" id="rowCount"><%= logs.size() %> entradas</span>
            </div>
            <table class="at" id="auditTable">
                <thead>
                <tr>
                    <th class="sortable sorted" onclick="sortCol(0)">Data / Hora <span id="arr0">↓</span></th>
                    <th>Categoria</th>
                    <th>Ação</th>
                    <th>Utilizador</th>
                    <th>Detalhe</th>
                    <th class="sortable" onclick="sortCol(5)" style="text-align:right">Valor <span id="arr5">↕</span>
                    </th>
                </tr>
                </thead>
                <tbody id="auditBody">
                <%
                    for (String[] l : logs) {
                        String ldate = l[0], lcat = l[1], lact = l[2], luser = l[3], ldet = l[4], lval = l[5];
                        String cc = "c-enc", ci = "M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1z";
                        if ("Carteira".equals(lcat)) {
                            cc = "c-cart";
                            ci = "M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z";
                        } else if ("Utilizador".equals(lcat)) {
                            cc = "c-util";
                            ci = "M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z";
                        } else if ("Produto".equals(lcat)) {
                            cc = "c-prod";
                            ci = "M18.06 22.99h1.66c.84 0 1.53-.64 1.63-1.46L23 5.05h-5V1h-1.97v4.05h-4.97l.3 2.34c1.71.47 3.31 1.32 4.27 2.26 1.44 1.42 2.43 2.89 2.43 5.29v8.05zM1 21.99V21h15.03v.99c0 .55-.45 1-1.01 1H2.01c-.56 0-1.01-.45-1.01-1zm15.03-7c0-3.87-3.13-7-7-7S2 11.12 2 14.99v2h14.03v-2z";
                        } else if ("Promoção".equals(lcat)) {
                            cc = "c-prom";
                            ci = "M21.41 11.58l-9-9A2 2 0 0 0 11 2H4a2 2 0 0 0-2 2v7c0 .53.21 1.04.59 1.42l9 9A2 2 0 0 0 13 22a2 2 0 0 0 1.41-.59l7-7A2 2 0 0 0 22 13a2 2 0 0 0-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z";
                        }
                        String vc = lval.startsWith("+") ? "vp" : lval.startsWith("-") ? "vn" : (!lval.isEmpty() ? "vn" : "vz");
                        String detHtml = ldet.replace("->", "<span style='color:#00CE86'>&#8594;</span>");
                %>
                <tr data-cat="<%= lcat %>" data-search="<%= (lact+" "+luser+" "+ldet).toLowerCase() %>">
                    <td class="dc"><%= ldate %>
                    </td>
                    <td><span class="cb <%= cc %>"><svg viewBox="0 0 24 24"><path
                            d="<%= ci %>"/></svg><%= lcat %></span></td>
                    <td><%= lact %>
                    </td>
                    <td class="uc"><%= luser %>
                    </td>
                    <td class="dtl"><%= detHtml %>
                    </td>
                    <td class="vc <%= vc %>"><%= lval.isEmpty() ? "<span style='color:#333'>—</span>" : lval %>
                    </td>
                </tr>
                <% } %>
                </tbody>
            </table>
        </div>
    </main>
</div>
<script>
    document.querySelectorAll('.cat-tab').forEach(tab => {
        tab.addEventListener('click', e => {
            e.preventDefault();
            document.querySelectorAll('.cat-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            const f = tab.dataset.filter;
            let n = 0;
            document.querySelectorAll('#auditBody tr').forEach(r => {
                const show = !f || r.dataset.cat === f;
                r.style.display = show ? '' : 'none';
                if (show) n++;
            });
            document.getElementById('rowCount').textContent = n + ' entrada' + (n !== 1 ? 's' : '');
        });
    });

    document.querySelector('input[name="search"]').addEventListener('input', function () {
        const q = this.value.toLowerCase();
        const cat = document.querySelector('select[name="categoria"]').value;
        let n = 0;
        document.querySelectorAll('#auditBody tr').forEach(r => {
            const show = (!q || r.dataset.search.includes(q)) && (!cat || r.dataset.cat === cat);
            r.style.display = show ? '' : 'none';
            if (show) n++;
        });
        document.getElementById('rowCount').textContent = n + ' entrada' + (n !== 1 ? 's' : '');
    });

    const sortState = {};

    function sortCol(idx) {
        const tbody = document.getElementById('auditBody');
        const rows = Array.from(tbody.querySelectorAll('tr'));
        const asc = !sortState[idx];
        Object.keys(sortState).forEach(k => delete sortState[k]);
        sortState[idx] = asc;
        rows.sort((a, b) => {
            const av = a.cells[idx]?.textContent.trim() ?? '';
            const bv = b.cells[idx]?.textContent.trim() ?? '';
            return asc ? av.localeCompare(bv, 'pt', {numeric: true}) : bv.localeCompare(av, 'pt', {numeric: true});
        });
        rows.forEach(r => tbody.appendChild(r));
        [0, 5].forEach(i => {
            const el = document.getElementById('arr' + i);
            if (el) el.textContent = i === idx ? (asc ? '↓' : '↑') : '↕';
        });
        document.querySelectorAll('.at th.sortable').forEach(th => th.classList.remove('sorted'));
        const ths = document.querySelectorAll('.at th.sortable');
        ths.forEach(th => {
            if (th.getAttribute('onclick')?.includes(idx)) th.classList.add('sorted');
        });
    }
</script>
</body>
</html>
