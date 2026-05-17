<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ include file="basedados/basedados.h" %>
<%
    String clientId = "";
    String clienteName = "";
    String saldoDisp = "";
    String totalEnc = "0";
    String totalGasto = "0";

    List<String[]> orders = new ArrayList<>();
    List<String[]> movements = new ArrayList<>();

    String carteiraAtiva = "";
    int pendentes = 0;
    int confirmadas = 0;

    HttpSession sess = request.getSession(false);
    if (sess != null) {
        clientId = String.valueOf(sess.getAttribute("userId"));
        clienteName = (String) sess.getAttribute("userName");
        saldoDisp = String.valueOf(sess.getAttribute("userSaldo"));

        try {
            // Obter encomendas da base de dados
            Connection conn = getConnection();
            String sql = "SELECT e.*, u.ativo " +
                    "FROM encomenda e " +
                    "LEFT JOIN utilizadores u ON u.id_utilizador = e.id_utilizador " +
                    "WHERE u.id_utilizador = ? " +
                    "LIMIT 10; ";
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setString(1, clientId);
            ResultSet rs = ps.executeQuery();

            while (rs.next()) {
                if (!rs.getBoolean("ativo")) {
                    sess.setAttribute("errorMsg", "Conta inativa. Contacte o suporte.");
                    response.sendRedirect("login.jsp");
                } else {
                    String id = (rs.getString("id_encomenda"));
                    String codigoUnico = (rs.getString("codigo_unico"));
                    String data = (rs.getString("data_encomenda"));
                    String estado = (rs.getString("estado"));
                    String total = (rs.getString("total"));
                    String notas = (rs.getString("notas"));
                    String[] order = {
                            id,
                            codigoUnico,
                            data,
                            estado,
                            total,
                            notas
                    };

                    totalEnc = String.valueOf(Integer.parseInt(totalEnc) + 1);
                    Double newTotal = Double.parseDouble(totalGasto) + Double.parseDouble(total);
                    totalGasto = String.format("%.2f", newTotal);
                    if (estado.equals("pendente")){
                        pendentes++;
                    } else if (estado.equals("confirmada")) {
                        confirmadas++;
                    }

                    orders.add(order);
                }
            }

            rs.close(); ps.close();

            // Obter movimentos da carteira
            sql = "SELECT a.* " +
                    "FROM auditoria_carteira a " +
                    "LEFT JOIN carteira c " +
                    "ON c.id_carteira = a.id_carteira_origem " +
                    "OR c.id_carteira = a.id_carteira_destino " +
                    "WHERE c.id_utilizador = ? " +
                    "ORDER BY a.data_operacao DESC " +
                    "LIMIT 4; ";
            ps = conn.prepareStatement(sql);
            ps.setString(1, clientId);
            rs = ps.executeQuery();

            while (rs.next()) {
                String id = (rs.getString("id_log"));
                String id_carteira_origem = (rs.getString("id_carteira_origem"));
                String id_carteira_destino = (rs.getString("id_carteira_destino"));
                String valor = (rs.getString("valor"));
                String descricao = (rs.getString("descricao"));
                String tipo_operacao = (rs.getString("tipo_operacao"));
                String data_operacao = (rs.getString("data_operacao"));

                if (tipo_operacao.equals("pagamento")){
                    valor = "-" + valor;
                } else {
                    valor = "+" + valor;
                }

                String[] movement = {
                        id,
                        id_carteira_origem,
                        id_carteira_destino,
                        valor,
                        descricao,
                        tipo_operacao,
                        data_operacao
                };

                movements.add(movement);
            }

            conn.close(); rs.close(); ps.close();
        } catch (Exception e) {
            sess.setAttribute("errorMsg", "Erro na dashboard: " + e.getMessage());
            response.sendRedirect("login.jsp");
        }
    } else {
        sess.setAttribute("errorMsg", "Nenhuma sessao encontrada");
        response.sendRedirect("login.jsp");
    }

    String activePage = "dashboard";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Área Cliente</title>
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
            letter-spacing: 0.4px;
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
            flex: 1;
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
            padding: 28px 28px 40px;
            overflow-y: auto;
            min-width: 0;
        }

        .page-title {
            font-size: 1.35rem;
            font-weight: 700;
            color: #fff;
            margin-bottom: 22px;
        }

        .stat-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 14px;
            margin-bottom: 24px;
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

        .stat-label {
            font-size: 0.72rem;
            font-weight: 700;
            letter-spacing: 0.8px;
            text-transform: uppercase;
            color: #666;
        }

        .stat-value {
            font-size: 1.6rem;
            font-weight: 700;
            color: #fff;
            line-height: 1;
        }

        .stat-icon {
            width: 32px;
            height: 32px;
            border-radius: 8px;
            background: rgba(0, 206, 134, 0.12);
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 4px;
        }

        .stat-icon svg {
            fill: #00CE86;
            width: 17px;
            height: 17px;
        }

        .dashboard-row {
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
            padding: 14px 18px;
            border-bottom: 1px solid #333;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .panel-title {
            font-size: 0.9rem;
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

        .btn-nova {
            background-color: #00CE86;
            color: #111;
            border: none;
            border-radius: 6px;
            padding: 6px 14px;
            font-size: 0.78rem;
            font-weight: 700;
            cursor: pointer;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 5px;
            transition: background 0.2s;
        }

        .btn-nova:hover {
            background: #00b876;
        }

        .btn-nova svg {
            fill: #111;
            width: 13px;
            height: 13px;
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
            color: #666;
            text-align: left;
            border-bottom: 1px solid #333;
            background: #252525;
        }

        .orders-table td {
            padding: 12px 18px;
            font-size: 0.87rem;
            color: #ccc;
            border-bottom: 1px solid #2a2a2a;
        }

        .orders-table tr:last-child td {
            border-bottom: none;
        }

        .orders-table tr:hover td {
            background: rgba(255, 255, 255, 0.02);
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
            background: rgba(255, 180, 0, 0.1);
            color: #f5a623;
            border: 1px solid rgba(255, 180, 0, 0.25);
        }

        .badge-cancelada {
            background: rgba(220, 60, 60, 0.1);
            color: #e05555;
            border: 1px solid rgba(220, 60, 60, 0.25);
        }

        .panel-footer {
            padding: 10px 18px;
            border-top: 1px solid #333;
            text-align: center;
        }

        .panel-footer a {
            font-size: 0.8rem;
            color: #00CE86;
            text-decoration: none;
        }

        .panel-footer a:hover {
            text-decoration: underline;
        }

        .wallet-summary {
            padding: 16px 18px;
            border-bottom: 1px solid #333;
            display: flex;
            flex-direction: column;
            gap: 6px;
        }

        .wallet-balance {
            font-size: 1.5rem;
            font-weight: 700;
            color: #fff;
        }

        .wallet-meta {
            display: flex;
            gap: 14px;
            font-size: 0.78rem;
        }

        .wallet-meta span {
            color: #777;
        }

        .wallet-meta .pend {
            color: #f5a623;
        }

        .wallet-meta .conf {
            color: #00CE86;
        }

        .movement-list {
            list-style: none;
        }

        .movement-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 18px;
            border-bottom: 1px solid #2a2a2a;
            transition: background 0.15s;
        }

        .movement-item:last-child {
            border-bottom: none;
        }

        .movement-item:hover {
            background: rgba(255, 255, 255, 0.02);
        }

        .mov-icon {
            width: 34px;
            height: 34px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }

        .mov-icon.credit {
            background: rgba(0, 206, 134, 0.12);
        }

        .mov-icon.credit svg {
            fill: #00CE86;
        }

        .mov-icon.debit {
            background: rgba(220, 80, 80, 0.1);
        }

        .mov-icon.debit svg {
            fill: #e07070;
        }

        .mov-icon svg {
            width: 16px;
            height: 16px;
        }

        .mov-info {
            flex: 1;
            min-width: 0;
        }

        .mov-desc {
            font-size: 0.85rem;
            font-weight: 600;
            color: #ddd;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .mov-date {
            font-size: 0.75rem;
            color: #666;
            margin-top: 2px;
        }

        .mov-amount {
            font-size: 0.92rem;
            font-weight: 700;
            flex-shrink: 0;
        }

        .mov-amount.credit {
            color: #00CE86;
        }

        .mov-amount.debit {
            color: #e07070;
        }

        @media (max-width: 860px) {
            .dashboard-row {
                grid-template-columns: 1fr;
            }

            .stat-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 600px) {
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

            .stat-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>

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

    <main class="main-content">
        <h1 class="page-title">Dashboard</h1>

        <div class="stat-grid">
            <div class="stat-card">
                <div class="stat-icon">
                    <svg viewBox="0 0 24 24">
                        <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                    </svg>
                </div>
                <div class="stat-label">Saldo Disponível</div>
                <div class="stat-value"><%= saldoDisp %>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                    </svg>
                </div>
                <div class="stat-label">Encomendas</div>
                <div class="stat-value"><%= totalEnc %>
                </div>
            </div>
            <div class="stat-card">
                <div class="stat-icon">
                    <svg viewBox="0 0 24 24">
                        <path d="M11.8 10.9c-2.27-.59-3-1.2-3-2.15 0-1.09 1.01-1.85 2.7-1.85 1.78 0 2.44.85 2.5 2.1h2.21c-.07-1.72-1.12-3.3-3.21-3.81V3h-3v2.16C9.56 5.67 8 6.84 8 8.75c0 2.31 1.91 3.46 4.7 4.13 2.5.6 3 1.48 3 2.41 0 .69-.49 1.79-2.7 1.79-2.06 0-2.87-.92-2.98-2.1H7.82c.12 2.19 1.76 3.42 3.68 3.83V21h3v-2.15c1.95-.37 3.5-1.5 3.5-3.55 0-2.84-2.43-3.81-4.7-4.4z"/>
                    </svg>
                </div>
                <div class="stat-label">Total Gasto</div>
                <div class="stat-value"><%= totalGasto %>
                </div>
            </div>
        </div>

        <div class="dashboard-row">

            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                        </svg>
                        Últimas encomendas
                    </div>
                    <a href="novaEncomendaCliente.jsp" class="btn-nova">
                        <svg viewBox="0 0 24 24">
                            <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                        </svg>
                        Nova encomenda
                    </a>
                </div>
                <table class="orders-table">
                    <thead>
                    <tr>
                        <th>ID</th>
                        <th>Data</th>
                        <th>Total</th>
                        <th>Estado</th>
                    </tr>
                    </thead>
                    <tbody>
                    <%
                        for (String[] o : orders) {
                            String oid = o[1];
                            String odate = o[2];
                            String ototal = o[4];
                            String ostatus = o[3];
                            String badgeClass = "badge-confirmada";
                            if ("Pendente".equalsIgnoreCase(ostatus)) badgeClass = "badge-pendente";
                            if ("Cancelada".equalsIgnoreCase(ostatus)) badgeClass = "badge-cancelada";
                    %>
                    <tr>
                        <td class="order-id"><%= oid %>
                        </td>
                        <td><%= odate %>
                        </td>
                        <td><strong><%= ototal %>
                        </strong></td>
                        <td><span class="badge <%= badgeClass %>"><%= ostatus %></span></td>
                    </tr>
                    <% } %>
                    </tbody>
                </table>
                <div class="panel-footer">
                    <a href="encomendas.jsp">Ver todas as encomendas →</a>
                </div>
            </div>

            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                        </svg>
                        Carteira
                    </div>
                </div>

                <div class="wallet-summary">
                    <div class="stat-label">Saldo Atual</div>
                    <div class="wallet-balance"><%= carteiraAtiva %>
                    </div>
                    <div class="wallet-meta">
                        <span class="pend"><%= pendentes %> pendente<%= pendentes != 1 ? "s" : "" %></span>
                        <span class="conf"><%= confirmadas %> confirmada<%= confirmadas != 1 ? "s" : "" %></span>
                    </div>
                </div>

                <div class="panel-header" style="padding:10px 18px;">
                    <div class="panel-title" style="font-size:0.82rem;">Últimos movimentos</div>
                </div>
                <ul class="movement-list">
                    <%
                        for (String[] m : movements) {
                            String mdesc = m[4];
                            String mdate = m[6];
                            String mamount = m[3];
                            boolean isCredit = mamount.startsWith("+");
                    %>
                    <li class="movement-item">
                        <div class="mov-icon <%= isCredit ? "credit" : "debit" %>">
                            <% if (isCredit) { %>
                            <svg viewBox="0 0 24 24">
                                <path d="M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z"
                                      transform="rotate(180,12,12)"/>
                            </svg>
                            <% } else { %>
                            <svg viewBox="0 0 24 24">
                                <path d="M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z"/>
                            </svg>
                            <% } %>
                        </div>
                        <div class="mov-info">
                            <div class="mov-desc"><%= mdesc %>
                            </div>
                            <div class="mov-date"><%= mdate %>
                            </div>
                        </div>
                        <div class="mov-amount <%= isCredit ? "credit" : "debit" %>"><%= mamount %>€
                        </div>
                    </li>
                    <% } %>
                </ul>
                <div class="panel-footer">
                    <a href="carteira.jsp">Ver carteira completa →</a>
                </div>
            </div>

        </div>
    </main>

</div>

</body>
</html>
