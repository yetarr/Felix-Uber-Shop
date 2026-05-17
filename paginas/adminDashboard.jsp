<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    // Verificar sessao
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    if (!"administrador".equals(sess.getAttribute("userRole"))) {
        response.sendRedirect("dashboard.jsp");
        response.sendRedirect("dashboard.jsp");
        return;
    }

    String adminName = (String) sess.getAttribute("userName");

    int clientesRegistados = 0;
    int clientesAtivos     = 0;
    int clientesInativos   = 0;
    int encPendentes       = 0;
    int produtosAtivos     = 0;
    int produtosSemStock   = 0;
    String saldoLoja       = "0,00 €";

    List<String[]> recentOrders = new ArrayList<>();
    List<String[]> recentUsers  = new ArrayList<>();

    try {
        Connection conn = getConnection();

        // Clientes registados / ativos / inativos
        PreparedStatement ps = conn.prepareStatement(
            "SELECT COUNT(*) AS total FROM utilizadores WHERE perfil = 'cliente'");
        ResultSet rs = ps.executeQuery();
        if (rs.next()) clientesRegistados = rs.getInt("total");
        rs.close(); ps.close();

        ps = conn.prepareStatement(
            "SELECT COUNT(*) AS total FROM utilizadores WHERE perfil = 'cliente' AND ativo = 1");
        rs = ps.executeQuery();
        if (rs.next()) clientesAtivos = rs.getInt("total");
        rs.close(); ps.close();
        clientesInativos = clientesRegistados - clientesAtivos;

        // Encomendas pendentes
        ps = conn.prepareStatement(
            "SELECT COUNT(*) AS total FROM encomenda WHERE estado = 'pendente'");
        rs = ps.executeQuery();
        if (rs.next()) encPendentes = rs.getInt("total");
        rs.close(); ps.close();

        // Produtos ativos e sem stock
        ps = conn.prepareStatement(
            "SELECT COUNT(*) AS total FROM produtos WHERE ativo = 1");
        rs = ps.executeQuery();
        if (rs.next()) produtosAtivos = rs.getInt("total");
        rs.close(); ps.close();

        ps = conn.prepareStatement(
            "SELECT COUNT(*) AS total FROM produtos WHERE ativo = 1 AND stock = 0");
        rs = ps.executeQuery();
        if (rs.next()) produtosSemStock = rs.getInt("total");
        rs.close(); ps.close();

        // Saldo da loja (soma das encomendas confirmadas)
        ps = conn.prepareStatement(
            "SELECT COALESCE(SUM(total), 0) AS saldo FROM encomenda WHERE estado = 'confirmada'");
        rs = ps.executeQuery();
        if (rs.next()) saldoLoja = String.format("%.2f €", rs.getDouble("saldo")).replace(".", ",");
        rs.close(); ps.close();

        // Ultimas 5 encomendas
        ps = conn.prepareStatement(
            "SELECT e.id_encomenda, u.nome, e.data_encomenda, e.total, e.estado " +
            "FROM encomenda e " +
            "LEFT JOIN utilizadores u ON u.id_utilizador = e.id_utilizador " +
            "ORDER BY e.data_encomenda DESC LIMIT 5");
        rs = ps.executeQuery();
        while (rs.next()) {
            recentOrders.add(new String[]{
                rs.getString("id_encomenda"),
                rs.getString("nome"),
                rs.getString("data_encomenda"),
                String.format("%.2f €", rs.getDouble("total")).replace(".", ","),
                rs.getString("estado")
            });
        }
        rs.close(); ps.close();

        // Ultimos 5 utilizadores registados
        ps = conn.prepareStatement(
            "SELECT nome, perfil, ativo FROM utilizadores ORDER BY id_utilizador DESC LIMIT 5");
        rs = ps.executeQuery();
        while (rs.next()) {
            recentUsers.add(new String[]{
                rs.getString("nome"),
                rs.getString("perfil"),
                rs.getBoolean("ativo") ? "Ativo" : "Inativo"
            });
        }
        rs.close(); ps.close();

        conn.close();
    } catch (Exception e) {
        // pagina renderiza com valores a zero em caso de erro de ligacao
    }

    String activePage = "dashboard";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>dashboardAdmin</title>
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
            letter-spacing: 0.4px;
        }

        .nav-right {
            display: flex;
            align-items: center;
            gap: 18px;
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
            text-transform: uppercase;
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

        .page-title {
            font-size: 1.35rem;
            font-weight: 700;
            color: #fff;
            margin-bottom: 20px;
        }

        .stat-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 14px;
            margin-bottom: 22px;
        }

        .stat-card {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 18px 20px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .stat-top {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
        }

        .stat-icon {
            width: 34px;
            height: 34px;
            border-radius: 8px;
            background: rgba(0, 206, 134, .1);
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .stat-icon svg {
            fill: #00CE86;
            width: 17px;
            height: 17px;
        }

        .stat-label {
            font-size: .68rem;
            font-weight: 700;
            letter-spacing: .8px;
            text-transform: uppercase;
            color: #555;
            margin-bottom: 4px;
        }

        .stat-value {
            font-size: 2rem;
            font-weight: 700;
            color: #fff;
            line-height: 1;
        }

        .stat-value.green {
            color: #00CE86;
            font-size: 1.6rem;
        }

        .stat-sub {
            font-size: .77rem;
            color: #666;
            margin-top: 2px;
        }

        .stat-sub .hi {
            color: #00CE86;
            font-weight: 600;
        }

        .stat-sub .warn {
            color: #e07070;
            font-weight: 600;
        }

        .stat-card.alert-card {
            border-color: rgba(245, 166, 35, .25);
        }

        .stat-card.alert-card .stat-icon {
            background: rgba(245, 166, 35, .1);
        }

        .stat-card.alert-card .stat-icon svg {
            fill: #f5a623;
        }

        .stat-card.alert-card .stat-value {
            color: #f5a623;
        }

        .dash-row {
            display: grid;
            grid-template-columns: 1fr 320px;
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
            padding: 13px 18px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .panel-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .panel-title svg {
            fill: #00CE86;
            width: 16px;
            height: 16px;
        }

        .btn-ver {
            background-color: #00CE86;
            color: #111;
            border: none;
            border-radius: 6px;
            padding: 6px 14px;
            font-size: .78rem;
            font-weight: 700;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 5px;
            transition: background .2s;
        }

        .btn-ver:hover {
            background: #00b876;
        }

        .orders-table {
            width: 100%;
            border-collapse: collapse;
        }

        .orders-table th {
            padding: 9px 18px;
            font-size: .71rem;
            font-weight: 700;
            letter-spacing: .6px;
            text-transform: uppercase;
            color: #555;
            text-align: left;
            border-bottom: 1px solid #333;
            background: #252525;
        }

        .orders-table td {
            padding: 12px 18px;
            font-size: .86rem;
            color: #bbb;
            border-bottom: 1px solid #2a2a2a;
            vertical-align: middle;
        }

        .orders-table tr:last-child td {
            border-bottom: none;
        }

        .orders-table tr:hover td {
            background: rgba(255, 255, 255, .02);
            cursor: pointer;
        }

        .order-id {
            font-weight: 700;
            color: #fff;
        }

        .client-cell {
            display: flex;
            align-items: center;
            gap: 9px;
        }

        .avatar-sm {
            width: 28px;
            height: 28px;
            border-radius: 50%;
            background: #383838;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            font-size: .72rem;
            font-weight: 700;
            color: #00CE86;
        }

        .badge {
            display: inline-block;
            padding: 3px 10px;
            border-radius: 20px;
            font-size: .71rem;
            font-weight: 700;
        }

        .badge-confirmada {
            background: rgba(0, 206, 134, .12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .3);
        }

        .badge-pendente {
            background: rgba(245, 166, 35, .10);
            color: #f5a623;
            border: 1px solid rgba(245, 166, 35, .25);
        }

        .badge-cancelada {
            background: rgba(220, 60, 60, .10);
            color: #e05555;
            border: 1px solid rgba(220, 60, 60, .25);
        }

        .badge-ativo {
            background: rgba(0, 206, 134, .12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .3);
        }

        .badge-inativo {
            background: rgba(220, 60, 60, .10);
            color: #e05555;
            border: 1px solid rgba(220, 60, 60, .25);
        }

        .badge-perfil {
            background: rgba(150, 150, 150, .1);
            color: #999;
            border: 1px solid rgba(150, 150, 150, .2);
        }

        .panel-footer {
            padding: 10px 18px;
            border-top: 1px solid #333;
            text-align: center;
        }

        .panel-footer a {
            font-size: .8rem;
            color: #00CE86;
            text-decoration: none;
        }

        .panel-footer a:hover {
            text-decoration: underline;
        }

        @media (max-width: 1100px) {
            .stat-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 860px) {
            .dash-row {
                grid-template-columns: 1fr;
            }
        }

        @media (max-width: 580px) {
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
                padding: 14px;
            }

            .stat-grid {
                grid-template-columns: 1fr;
            }

            .orders-table th:nth-child(3),
            .orders-table td:nth-child(3) {
                display: none;
            }
        }
    </style>
</head>
<body>

<nav class="topnav">
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-right">
        <span class="nav-role">Administrador</span>
        <div class="nav-user">
            <svg viewBox="0 0 24 24">
                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
            </svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= adminName %></strong>
        </div>
        <a href="login.jsp" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <aside class="sidebar">
        <div class="sidebar-label">Área Admin</div>
        <ul class="sidebar-nav">
            <li>
                <a href="adminDashboard.jsp" class="<%= "dashboard".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                    </svg>
                    <span>Dashboard</span>
                </a>
            </li>
            <li>
                <a href="encomendasAdmin.jsp" class="<%= "encomendas".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                    </svg>
                    <span>Encomendas</span>
                </a>
            </li>
            <li>
                <a href="saldoClientesAdmin.jsp" class="<%= "saldo".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                    </svg>
                    <span>Saldo clientes</span>
                </a>
            </li>
            <li>
                <a href="produtosAdmin.jsp" class="<%= "produtos".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 12H9v-2h6v2zm2-4H7V8h10v2z"/>
                    </svg>
                    <span>Produtos</span>
                </a>
            </li>
            <li>
                <a href="utilizadoresAdmin.jsp" class="<%= "utilizadores".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                    </svg>
                    <span>Utilizadores</span>
                </a>
            </li>
            <li>
                <a href="promocoesAdmin.jsp" class="<%= "promocoes".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M21.41 11.58l-9-9C12.05 2.22 11.55 2 11 2H4c-1.1 0-2 .9-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/>
                    </svg>
                    <span>Promoções</span>
                </a>
            </li>
            <li>
                <a href="auditoriaAdmin.jsp" class="<%= "auditoria".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                    </svg>
                    <span>Auditoria</span>
                </a>
            </li>
            <div class="sidebar-divider"></div>
            <li>
                <a href="perfilAdmin.jsp" class="<%= "perfil".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                    </svg>
                    <span>Perfil</span>
                </a>
            </li>
        </ul>
    </aside>

    <main class="main-content">
        <h1 class="page-title">Dashboard</h1>

        <div class="stat-grid">

            <!-- Clientes Registados -->
            <div class="stat-card">
                <div class="stat-top">
                    <div>
                        <div class="stat-label">Clientes Registados</div>
                        <div class="stat-value"><%= clientesRegistados %></div>
                    </div>
                    <div class="stat-icon">
                        <svg viewBox="0 0 24 24">
                            <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                        </svg>
                    </div>
                </div>
                <div class="stat-sub">
                    <span class="hi"><%= clientesAtivos %> ativos</span>
                    &nbsp;&middot;&nbsp;
                    <span class="warn"><%= clientesInativos %> inativos</span>
                </div>
            </div>

            <!-- Encomendas Pendentes -->
            <div class="stat-card alert-card">
                <div class="stat-top">
                    <div>
                        <div class="stat-label">Encomendas Pendentes</div>
                        <div class="stat-value"><%= encPendentes %></div>
                    </div>
                    <div class="stat-icon">
                        <svg viewBox="0 0 24 24">
                            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
                        </svg>
                    </div>
                </div>
                <div class="stat-sub">Aguardam validação</div>
            </div>

            <!-- Produtos Ativos -->
            <div class="stat-card">
                <div class="stat-top">
                    <div>
                        <div class="stat-label">Produtos Ativos</div>
                        <div class="stat-value"><%= produtosAtivos %></div>
                    </div>
                    <div class="stat-icon">
                        <svg viewBox="0 0 24 24">
                            <path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 12H9v-2h6v2zm2-4H7V8h10v2z"/>
                        </svg>
                    </div>
                </div>
                <div class="stat-sub">
                    <% if (produtosSemStock == 0) { %>
                        <span class="hi">0 sem stock</span>
                    <% } else { %>
                        <span class="warn"><%= produtosSemStock %> sem stock</span>
                    <% } %>
                </div>
            </div>

            <!-- Saldo FelixUberShop -->
            <div class="stat-card">
                <div class="stat-top">
                    <div>
                        <div class="stat-label">Saldo FelixUberShop</div>
                        <div class="stat-value green"><%= saldoLoja %></div>
                    </div>
                    <div class="stat-icon">
                        <svg viewBox="0 0 24 24">
                            <path d="M11.8 10.9c-2.27-.59-3-1.2-3-2.15 0-1.09 1.01-1.85 2.7-1.85 1.78 0 2.44.85 2.5 2.1h2.21c-.07-1.72-1.12-3.3-3.21-3.81V3h-3v2.16C9.56 5.67 8 6.84 8 8.75c0 2.31 1.91 3.46 4.7 4.13 2.5.6 3 1.48 3 2.41 0 .69-.49 1.79-2.7 1.79-2.06 0-2.87-.92-2.98-2.1H7.82c.12 2.19 1.76 3.42 3.68 3.83V21h3v-2.15c1.95-.37 3.5-1.5 3.5-3.55 0-2.84-2.43-3.81-4.7-4.4z"/>
                        </svg>
                    </div>
                </div>
                <div class="stat-sub">Carteira da loja</div>
            </div>

        </div>

        <div class="dash-row">

            <!-- ULTIMAS ENCOMENDAS -->
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                        </svg>
                        Últimas encomendas
                    </div>
                    <a href="encomendasAdmin.jsp" class="btn-ver">Ver todas</a>
                </div>
                <table class="orders-table">
                    <thead>
                    <tr>
                        <th>ID</th>
                        <th>Cliente</th>
                        <th>Data</th>
                        <th>Total</th>
                        <th>Estado</th>
                    </tr>
                    </thead>
                    <tbody>
                    <%
                        for (String[] o : recentOrders) {
                            String oid   = o[0];
                            String ocli  = o[1];
                            String odate = o[2];
                            String ototal = o[3];
                            String ostat = o[4];

                            String badgeClass = "badge-confirmada";
                            if ("Pendente".equalsIgnoreCase(ostat))  badgeClass = "badge-pendente";
                            if ("Cancelada".equalsIgnoreCase(ostat)) badgeClass = "badge-cancelada";

                            String[] parts = ocli.split(" ");
                            String initials = parts.length >= 2
                                    ? "" + parts[0].charAt(0) + parts[1].charAt(0)
                                    : "" + parts[0].charAt(0);
                    %>
                    <tr onclick="location.href='encomendasAdmin.jsp?id=<%= oid %>'">
                        <td class="order-id">#<%= oid %></td>
                        <td>
                            <div class="client-cell">
                                <div class="avatar-sm"><%= initials %></div>
                                <%= ocli %>
                            </div>
                        </td>
                        <td><%= odate %></td>
                        <td><strong><%= ototal %></strong></td>
                        <td><span class="badge <%= badgeClass %>"><%= ostat %></span></td>
                    </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>

            <!-- ULTIMOS UTILIZADORES -->
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                        </svg>
                        Últimos utilizadores
                    </div>
                    <a href="utilizadoresAdmin.jsp" class="btn-ver">Ver todos</a>
                </div>
                <table class="orders-table">
                    <thead>
                    <tr>
                        <th>Nome</th>
                        <th>Perfil</th>
                        <th>Estado</th>
                    </tr>
                    </thead>
                    <tbody>
                    <%
                        for (String[] u : recentUsers) {
                            String uname   = u[0];
                            String uperfil = u[1];
                            String uestado = u[2];

                            String estadoBadge = "Ativo".equalsIgnoreCase(uestado) ? "badge-ativo" : "badge-inativo";

                            String[] uparts = uname.split(" ");
                            String uinitials = uparts.length >= 2
                                    ? "" + uparts[0].charAt(0) + uparts[1].charAt(0)
                                    : "" + uparts[0].charAt(0);
                    %>
                    <tr onclick="location.href='utilizadoresAdmin.jsp'">
                        <td>
                            <div class="client-cell">
                                <div class="avatar-sm"><%= uinitials %></div>
                                <%= uname %>
                            </div>
                        </td>
                        <td><span class="badge badge-perfil"><%= uperfil %></span></td>
                        <td><span class="badge <%= estadoBadge %>"><%= uestado %></span></td>
                    </tr>
                    <% } %>
                    </tbody>
                </table>
                <div class="panel-footer">
                    <a href="utilizadoresAdmin.jsp">Ver todos os utilizadores →</a>
                </div>
            </div>

        </div>
    </main>

</div>

</body>
</html>

