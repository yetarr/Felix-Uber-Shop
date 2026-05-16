<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%

    String clienteName = "cliente de teste";

    String[][] orders = {
            {"3", "Cliente Teste", "04/05/2026 14:32", "1,78 €", "Pendente"},
            {"2", "Cliente Teste", "02/05/2026 09:55", "5,78 €", "Confirmada"},
            {"1", "Cliente Teste", "01/05/2026 08:00", "4,91 €", "Confirmada"},
    };

    Map<String, String[][]> details = new LinkedHashMap<>();
    details.put("3", new String[][]{
            {"Arroz 1kg", "0,89 €", "1", "0,89 €"},
            {"Leite 1L", "0,71 €", "1", "0,71 €"},
            {"Água 1.5L", "0,18 €", "1", "0,18 €"},
    });
    details.put("2", new String[][]{
            {"Azeite 750ml", "4,99 €", "1", "4,99 €"},
            {"Leite 1L", "0,79 €", "1", "0,79 €"},
    });
    details.put("1", new String[][]{
            {"Pão de forma", "0,99 €", "2", "1,98 €"},
            {"Água 1.5L", "0,49 €", "1", "0,49 €"},
            {"Leite 1L", "0,71 €", "1", "0,71 €"},
            {"Arroz 1kg", "0,89 €", "1", "0,89 €"},
    });

    String successMsg = (String) request.getAttribute("success");
    String errorMsg = (String) request.getAttribute("error");

    String openDetail = request.getParameter("detalhe");
    if (openDetail == null) openDetail = "3";

    String activePage = "encomendas";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Encomendas</title>
    <style>
        *, *::before, *::after {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            background-color: #212121;
            color: #e0e0e0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .topnav {
            background-color: #2a2a2a;
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
            font-size: 0.87rem;
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
            font-size: 0.8rem;
            padding: 5px 14px;
            border-radius: 6px;
            cursor: pointer;
            text-decoration: none;
            transition: border-color 0.2s, color 0.2s;
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
            width: 210px;
            flex-shrink: 0;
            background-color: #111;
            border-right: 1px solid #222;
            display: flex;
            flex-direction: column;
            padding: 24px 0 16px;
        }

        .sidebar-label {
            font-size: 0.68rem;
            font-weight: 700;
            letter-spacing: 1.2px;
            color: #444;
            text-transform: uppercase;
            padding: 0 20px 14px;
        }

        .sidebar-nav {
            list-style: none;
        }

        .sidebar-nav li a {
            display: flex;
            align-items: center;
            gap: 11px;
            padding: 11px 20px;
            text-decoration: none;
            font-size: 0.88rem;
            color: #888;
            border-left: 3px solid transparent;
            transition: background 0.15s, color 0.15s, border-color 0.15s;
        }

        .sidebar-nav li a:hover {
            background: rgba(255, 255, 255, 0.04);
            color: #ddd;
        }

        .sidebar-nav li a.active {
            border-left-color: #00CE86;
            background: rgba(0, 206, 134, 0.07);
            color: #00CE86;
            font-weight: 600;
        }

        .sidebar-nav li a svg {
            width: 17px;
            height: 17px;
            fill: currentColor;
            flex-shrink: 0;
        }

        .main-content {
            flex: 1;
            padding: 28px 28px 48px;
            overflow-y: auto;
            min-width: 0;
        }

        .page-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 6px;
        }

        .page-title {
            font-size: 1.35rem;
            font-weight: 700;
            color: #fff;
        }

        .btn-nova {
            background-color: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            padding: 9px 18px;
            font-size: 0.84rem;
            font-weight: 700;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            transition: background 0.2s;
        }

        .btn-nova:hover {
            background: #00b876;
        }

        .btn-nova svg {
            fill: #111;
            width: 14px;
            height: 14px;
        }

        .info-banner {
            background: rgba(0, 206, 134, 0.06);
            border: 1px solid rgba(0, 206, 134, 0.2);
            border-radius: 8px;
            padding: 9px 14px;
            font-size: 0.8rem;
            color: #888;
            display: flex;
            align-items: center;
            gap: 8px;
            margin-bottom: 18px;
        }

        .info-banner svg {
            fill: #00CE86;
            width: 15px;
            height: 15px;
            flex-shrink: 0;
        }

        .info-banner strong {
            color: #aaa;
        }

        .alert {
            border-radius: 8px;
            padding: 11px 16px;
            font-size: 0.86rem;
            margin-bottom: 18px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .alert svg {
            width: 17px;
            height: 17px;
            flex-shrink: 0;
        }

        .alert-success {
            background: rgba(0, 206, 134, 0.1);
            border: 1px solid rgba(0, 206, 134, 0.3);
            color: #00CE86;
        }

        .alert-error {
            background: rgba(220, 60, 60, 0.1);
            border: 1px solid rgba(220, 60, 60, 0.3);
            color: #f08080;
        }

        .panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
            margin-bottom: 16px;
        }

        .panel-header {
            padding: 13px 20px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .panel-title {
            font-size: 0.9rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .panel-title-icon {
            fill: #00CE86;
            width: 16px;
            height: 16px;
        }

        .orders-table {
            width: 100%;
            border-collapse: collapse;
        }

        .orders-table th {
            padding: 10px 18px;
            font-size: 0.72rem;
            font-weight: 700;
            letter-spacing: 0.6px;
            text-transform: uppercase;
            color: #555;
            text-align: left;
            border-bottom: 1px solid #333;
            background: #252525;
        }

        .orders-table td {
            padding: 13px 18px;
            font-size: 0.87rem;
            color: #ccc;
            border-bottom: 1px solid #2a2a2a;
            vertical-align: middle;
        }

        .orders-table tr:last-child td {
            border-bottom: none;
        }

        .orders-table tr.active-row td {
            background: rgba(0, 206, 134, 0.04);
        }

        .orders-table tr:hover td {
            background: rgba(255, 255, 255, 0.02);
            cursor: pointer;
        }

        .order-id {
            font-weight: 700;
            color: #fff;
        }

        .badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: 0.72rem;
            font-weight: 700;
        }

        .badge-confirmada {
            background: rgba(0, 206, 134, 0.12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, 0.3);
        }

        .badge-pendente {
            background: rgba(255, 180, 0, 0.10);
            color: #f5a623;
            border: 1px solid rgba(255, 180, 0, 0.25);
        }

        .badge-cancelada {
            background: rgba(220, 60, 60, 0.10);
            color: #e05555;
            border: 1px solid rgba(220, 60, 60, 0.25);
        }

        .action-btns {
            display: flex;
            gap: 7px;
            flex-wrap: wrap;
        }

        .btn-editar {
            background: none;
            border: 1px solid #555;
            color: #bbb;
            border-radius: 6px;
            padding: 5px 13px;
            font-size: 0.78rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: border-color 0.2s, color 0.2s;
        }

        .btn-editar:hover {
            border-color: #00CE86;
            color: #00CE86;
        }

        .btn-cancelar {
            background: none;
            border: 1px solid #6b3030;
            color: #e07070;
            border-radius: 6px;
            padding: 5px 13px;
            font-size: 0.78rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: background 0.2s, border-color 0.2s;
        }

        .btn-cancelar:hover {
            background: rgba(220, 60, 60, 0.1);
            border-color: #e05555;
        }

        .btn-detalhe {
            background: none;
            border: 1px solid #3a3a3a;
            color: #888;
            border-radius: 6px;
            padding: 5px 13px;
            font-size: 0.78rem;
            font-weight: 600;
            cursor: pointer;
            transition: border-color 0.2s, color 0.2s;
        }

        .btn-detalhe:hover {
            border-color: #555;
            color: #ccc;
        }

        .btn-detalhe.open {
            border-color: #00CE86;
            color: #00CE86;
        }

        .detail-panel {
            background: #222;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
            margin-bottom: 16px;
            display: none;
        }

        .detail-panel.visible {
            display: block;
        }

        .detail-header {
            padding: 13px 20px;
            border-bottom: 1px solid #2e2e2e;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .detail-title {
            font-size: 0.88rem;
            font-weight: 700;
            color: #ddd;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .detail-title svg {
            fill: #00CE86;
            width: 15px;
            height: 15px;
        }

        .detail-close {
            background: none;
            border: none;
            color: #666;
            font-size: 1.1rem;
            cursor: pointer;
            padding: 0;
            transition: color 0.2s;
            line-height: 1;
        }

        .detail-close:hover {
            color: #e05555;
        }

        .detail-table {
            width: 100%;
            border-collapse: collapse;
        }

        .detail-table th {
            padding: 9px 20px;
            font-size: 0.71rem;
            font-weight: 700;
            letter-spacing: 0.5px;
            text-transform: uppercase;
            color: #555;
            text-align: left;
            border-bottom: 1px solid #2e2e2e;
            background: #1e1e1e;
        }

        .detail-table td {
            padding: 11px 20px;
            font-size: 0.86rem;
            color: #bbb;
            border-bottom: 1px solid #272727;
        }

        .detail-table tr:last-child td {
            border-bottom: none;
        }

        .detail-table td:first-child {
            color: #ddd;
            font-weight: 600;
        }

        .detail-table td:last-child {
            color: #e0e0e0;
            font-weight: 600;
            text-align: right;
        }

        .detail-table th:last-child {
            text-align: right;
        }

        .detail-total {
            display: flex;
            justify-content: flex-end;
            align-items: center;
            gap: 14px;
            padding: 12px 20px;
            border-top: 1px solid #333;
            font-size: 0.95rem;
        }

        .detail-total .label {
            color: #777;
            font-weight: 600;
        }

        .detail-total .value {
            color: #00CE86;
            font-weight: 700;
            font-size: 1.05rem;
        }

        .empty-state {
            text-align: center;
            padding: 48px 20px;
            color: #555;
        }

        .empty-state svg {
            fill: #333;
            width: 48px;
            height: 48px;
            margin-bottom: 14px;
        }

        .empty-state p {
            font-size: 0.9rem;
        }

        @media (max-width: 640px) {
            .sidebar {
                width: 56px;
            }

            .sidebar-label, .sidebar-nav li a span {
                display: none;
            }

            .sidebar-nav li a {
                padding: 13px;
                justify-content: center;
            }

            .main-content {
                padding: 16px;
            }

            .orders-table th:nth-child(2),
            .orders-table td:nth-child(2) {
                display: none;
            }
        }
    </style>
</head>
<body>

<!-- TOP NAV -->
<nav class="topnav">
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-right">
        <div class="nav-user">
            <svg viewBox="0 0 24 24">
                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
            </svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= clienteName %>
        </strong>
        </div>
        <a href="LogoutServlet" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <!-- SIDEBAR -->
    <aside class="sidebar">
        <div class="sidebar-label">Área Cliente</div>
        <ul class="sidebar-nav">
            <li>
                <a href="dashboard.jsp" class="<%= "dashboard".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                    </svg>
                    <span>Dashboard</span>
                </a>
            </li>
            <li>
                <a href="perfil.jsp" class="<%= "perfil".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                    </svg>
                    <span>Perfil</span>
                </a>
            </li>
            <li>
                <a href="carteira.jsp" class="<%= "carteira".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                    </svg>
                    <span>Carteira</span>
                </a>
            </li>
            <li>
                <a href="encomendas.jsp" class="<%= "encomendas".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                    </svg>
                    <span>Encomendas</span>
                </a>
            </li>
        </ul>
    </aside>

    <!-- MAIN -->
    <main class="main-content">

        <!-- Header row -->
        <div class="page-header">
            <h1 class="page-title">As minhas encomendas</h1>
            <a href="NovaEncomendaServlet" class="btn-nova">
                <svg viewBox="0 0 24 24">
                    <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                </svg>
                Nova encomenda
            </a>
        </div>

        <!-- Info banner -->
        <div class="info-banner">
            <svg viewBox="0 0 24 24">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/>
            </svg>
            O identificador único de cada encomenda é composto por:
            <strong>ID &bull; Cliente &bull; Data &bull; Total</strong>
        </div>

        <!-- Flash messages -->
        <% if (successMsg != null && !successMsg.isEmpty()) { %>
        <div class="alert alert-success">
            <svg viewBox="0 0 24 24" fill="#00CE86">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14l-4-4 1.41-1.41L10 13.17l6.59-6.59L18 8l-8 8z"/>
            </svg>
            <%= successMsg %>
        </div>
        <% } %>

        <% if (errorMsg != null && !errorMsg.isEmpty()) { %>
        <div class="alert alert-error">
            <svg viewBox="0 0 24 24" fill="#f08080">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
            </svg>
            <%= errorMsg %>
        </div>
        <% } %>

        <!-- ORDERS TABLE -->
        <div class="panel">
            <div class="panel-header">
                <svg class="panel-title-icon" viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                </svg>
                <span class="panel-title">Encomendas</span>
            </div>

            <% if (orders.length == 0) { %>
            <div class="empty-state">
                <svg viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2z"/>
                </svg>
                <p>Ainda não tem encomendas. <a href="NovaEncomendaServlet" style="color:#00CE86;">Criar a primeira</a>
                </p>
            </div>
            <% } else { %>
            <table class="orders-table">
                <thead>
                <tr>
                    <th>ID</th>
                    <th>Cliente</th>
                    <th>Data</th>
                    <th>Total</th>
                    <th>Estado</th>
                    <th>Ações</th>
                </tr>
                </thead>
                <tbody>
                <%
                    for (String[] o : orders) {
                        String oid = o[0];
                        String ocliente = o[1];
                        String odata = o[2];
                        String ototal = o[3];
                        String ostatus = o[4];

                        String badgeClass = "badge-confirmada";
                        if ("Pendente".equalsIgnoreCase(ostatus)) badgeClass = "badge-pendente";
                        if ("Cancelada".equalsIgnoreCase(ostatus)) badgeClass = "badge-cancelada";

                        boolean isPendente = "Pendente".equalsIgnoreCase(ostatus);
                        boolean isOpenDetail = oid.equals(openDetail);
                %>
                <tr class="<%= isOpenDetail ? "active-row" : "" %>"
                    onclick="toggleDetail('<%= oid %>')" style="cursor:pointer;">
                    <td class="order-id">#<%= oid %>
                    </td>
                    <td><%= ocliente %>
                    </td>
                    <td><%= odata %>
                    </td>
                    <td><strong><%= ototal %>
                    </strong></td>
                    <td><span class="badge <%= badgeClass %>"><%= ostatus %></span></td>
                    <td>
                        <div class="action-btns" onclick="event.stopPropagation()">
                            <button class="btn-detalhe <%= isOpenDetail ? "open" : "" %>"
                                    id="btn-det-<%= oid %>"
                                    onclick="toggleDetail('<%= oid %>')">
                                Detalhe
                            </button>
                            <a href="EditarEncomendaServlet?id=<%= oid %>"
                               class="btn-editar">Editar</a>
                            <% if (isPendente) { %>
                            <a href="CancelarEncomendaServlet?id=<%= oid %>"
                               class="btn-cancelar"
                               onclick="return confirm('Cancelar encomenda #<%= oid %>?')">Cancelar</a>
                            <% } %>
                        </div>
                    </td>
                </tr>
                <% } %>
                </tbody>
            </table>
            <% } %>
        </div>

        <!-- DETAIL PANELS (one per order, shown/hidden by JS) -->
        <%
            for (String[] o : orders) {
                String oid = o[0];
                String ocli = o[1];
                String odata = o[2];
                String ototal = o[3];
                String[][] items = details.get(oid);
                boolean isOpen = oid.equals(openDetail);
        %>
        <div class="detail-panel <%= isOpen ? "visible" : "" %>" id="detail-<%= oid %>">
            <div class="detail-header">
                <div class="detail-title">
                    <svg viewBox="0 0 24 24">
                        <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                    </svg>
                    Detalhe da encomenda #<%= oid %>
                    &mdash; <%= ocli %> &mdash; <%= odata %> &mdash; <span style="color:#00CE86;"><%= ototal %></span>
                </div>
                <button class="detail-close" onclick="closeDetail('<%= oid %>')" title="Fechar">&times;</button>
            </div>

            <% if (items != null && items.length > 0) { %>
            <table class="detail-table">
                <thead>
                <tr>
                    <th>Produto</th>
                    <th>Preço unit.</th>
                    <th>Quantidade</th>
                    <th>Subtotal</th>
                </tr>
                </thead>
                <tbody>
                <% for (String[] item : items) { %>
                <tr>
                    <td><%= item[0] %>
                    </td>
                    <td><%= item[1] %>
                    </td>
                    <td><%= item[2] %>
                    </td>
                    <td><%= item[3] %>
                    </td>
                </tr>
                <% } %>
                </tbody>
            </table>
            <div class="detail-total">
                <span class="label">Total:</span>
                <span class="value"><%= ototal %></span>
            </div>
            <% } %>
        </div>
        <% } %>

    </main>
</div>

<script>
    let currentOpen = '<%= openDetail != null ? openDetail : "" %>';

    function toggleDetail(id) {
        if (currentOpen === id) {
            closeDetail(id);
        } else {
            if (currentOpen) closeDetail(currentOpen);
            openDetailPanel(id);
        }
    }

    function openDetailPanel(id) {
        const panel = document.getElementById('detail-' + id);
        const btn = document.getElementById('btn-det-' + id);
        if (panel) panel.classList.add('visible');
        if (btn) btn.classList.add('open');
        currentOpen = id;

        if (panel) panel.scrollIntoView({behavior: 'smooth', block: 'nearest'});
    }

    function closeDetail(id) {
        const panel = document.getElementById('detail-' + id);
        const btn = document.getElementById('btn-det-' + id);
        if (panel) panel.classList.remove('visible');
        if (btn) btn.classList.remove('open');
        if (currentOpen === id) currentOpen = '';
    }
</script>

</body>
</html>
