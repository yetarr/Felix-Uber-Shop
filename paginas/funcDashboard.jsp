<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    // Verificacao da sessao e papel de funcionario
    if (session.getAttribute("userId") == null || !"funcionario".equals(session.getAttribute("userRole"))) {
        response.sendRedirect("login.jsp");
        return;
    }
    String funcName = (String) session.getAttribute("userName");

    int encPendentes = 0;
    int encHoje = 0;
    int encHojeCanceladas = 0;
    int encHojeConfirmadas = 0;
    int clientesRegistados = 0;
    List<String[]> recentOrders = new ArrayList<>();
    List<String[]> walletFeed = new ArrayList<>();

    Connection _conn3 = null;
    PreparedStatement _ps3 = null;
    ResultSet _rs3 = null;
    try {
        _conn3 = getConnection();

        // Contagens estatisticas para o dashboard
        _ps3 = _conn3.prepareStatement("SELECT COUNT(*) FROM encomenda WHERE estado='pendente'");
        _rs3 = _ps3.executeQuery();
        if (_rs3.next()) encPendentes = _rs3.getInt(1);
        closeAll(_rs3, _ps3, null);

        _ps3 = _conn3.prepareStatement("SELECT COUNT(*) FROM encomenda WHERE DATE(data_encomenda)=CURDATE()");
        _rs3 = _ps3.executeQuery();
        if (_rs3.next()) encHoje = _rs3.getInt(1);
        closeAll(_rs3, _ps3, null);

        _ps3 = _conn3.prepareStatement("SELECT COUNT(*) FROM encomenda WHERE DATE(data_encomenda)=CURDATE() AND estado='cancelado'");
        _rs3 = _ps3.executeQuery();
        if (_rs3.next()) encHojeCanceladas = _rs3.getInt(1);
        closeAll(_rs3, _ps3, null);

        _ps3 = _conn3.prepareStatement("SELECT COUNT(*) FROM encomenda WHERE DATE(data_encomenda)=CURDATE() AND estado='pronto'");
        _rs3 = _ps3.executeQuery();
        if (_rs3.next()) encHojeConfirmadas = _rs3.getInt(1);
        closeAll(_rs3, _ps3, null);

        _ps3 = _conn3.prepareStatement("SELECT COUNT(*) FROM utilizadores WHERE perfil='cliente'");
        _rs3 = _ps3.executeQuery();
        if (_rs3.next()) clientesRegistados = _rs3.getInt(1);
        closeAll(_rs3, _ps3, null);

        // Ultimas encomendas para o feed
        _ps3 = _conn3.prepareStatement(
            "SELECT e.id_encomenda, u.nome, e.data_encomenda, e.total, e.estado " +
            "FROM encomenda e JOIN utilizadores u ON u.id_utilizador=e.id_utilizador " +
            "ORDER BY e.data_encomenda DESC LIMIT 5");
        _rs3 = _ps3.executeQuery();
        while (_rs3.next()) {
            String totalFmt = String.format("%,.2f €", _rs3.getDouble("total")).replace(".", ",");
            recentOrders.add(new String[]{
                String.valueOf(_rs3.getInt("id_encomenda")),
                _rs3.getString("nome"),
                String.valueOf(_rs3.getTimestamp("data_encomenda")),
                totalFmt,
                _rs3.getString("estado")
            });
        }
        closeAll(_rs3, _ps3, null);

        // Movimentos recentes da carteira
        _ps3 = _conn3.prepareStatement(
            "SELECT ac.tipo_operacao, e.codigo_unico, u.nome, ac.data_operacao, ac.valor, ac.id_carteira_origem " +
            "FROM auditoria_carteira ac " +
            "JOIN carteira c ON c.id_carteira = ac.id_carteira_destino OR c.id_carteira = ac.id_carteira_origem " +
            "LEFT JOIN utilizadores u ON u.id_utilizador = c.id_utilizador AND c.is_loja=0 " +
            "LEFT JOIN encomenda e ON e.id_encomenda = ac.id_encomenda " +
            "ORDER BY ac.data_operacao DESC LIMIT 5");
        _rs3 = _ps3.executeQuery();
        while (_rs3.next()) {
            String tipo = _rs3.getString("tipo_operacao");
            String codigo = _rs3.getString("codigo_unico");
            if (codigo == null) codigo = "";
            String nome = _rs3.getString("nome");
            if (nome == null) nome = "";
            String dataOp = String.valueOf(_rs3.getTimestamp("data_operacao"));
            double valor = _rs3.getDouble("valor");
            boolean isDebit = "pagamento".equals(tipo) || "levantamento".equals(tipo);
            String sign = isDebit ? "-" : "+";
            String valorFmt = sign + String.format("%,.2f €", valor).replace(".", ",");
            walletFeed.add(new String[]{tipo, codigo, nome, dataOp, valorFmt});
        }
    } catch (Exception _e3) {
        // Pagina carrega com dados vazios em caso de erro
    } finally {
        closeAll(_rs3, _ps3, _conn3);
    }

    String activePage = "dashboard";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Dashboard Funcionário</title>
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
            grid-template-columns: repeat(3, 1fr);
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
            grid-template-columns: 1fr 300px;
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

        .panel-link {
            font-size: .78rem;
            color: #00CE86;
            text-decoration: none;
        }

        .panel-link:hover {
            text-decoration: underline;
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

        .feed-list {
            list-style: none;
        }

        .feed-item {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 18px;
            border-bottom: 1px solid #2a2a2a;
            transition: background .15s;
        }

        .feed-item:last-child {
            border-bottom: none;
        }

        .feed-item:hover {
            background: rgba(255, 255, 255, .02);
        }

        .feed-icon {
            width: 36px;
            height: 36px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }

        .feed-icon.credit {
            background: rgba(0, 206, 134, .1);
        }

        .feed-icon.credit svg {
            fill: #00CE86;
        }

        .feed-icon.debit {
            background: rgba(220, 80, 80, .1);
        }

        .feed-icon.debit svg {
            fill: #e07070;
        }

        .feed-icon.neutral {
            background: rgba(100, 150, 255, .1);
        }

        .feed-icon.neutral svg {
            fill: #7aadff;
        }

        .feed-icon svg {
            width: 16px;
            height: 16px;
        }

        .feed-info {
            flex: 1;
            min-width: 0;
        }

        .feed-desc {
            font-size: .84rem;
            font-weight: 600;
            color: #ddd;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }

        .feed-meta {
            font-size: .74rem;
            color: #555;
            margin-top: 2px;
        }

        .feed-meta .client-name {
            color: #888;
        }

        .feed-amount {
            font-size: .92rem;
            font-weight: 700;
            flex-shrink: 0;
        }

        .feed-amount.credit {
            color: #00CE86;
        }

        .feed-amount.debit {
            color: #e07070;
        }

        @media (max-width: 860px) {
            .dash-row {
                grid-template-columns: 1fr;
            }

            .stat-grid {
                grid-template-columns: repeat(2, 1fr);
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
        <span class="nav-role">Funcionário</span>
        <div class="nav-user">
            <svg viewBox="0 0 24 24">
                <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
            </svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= funcName %>
        </strong>
        </div>
        <a href="logout.jsp" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <!-- SIDEBAR -->
    <aside class="sidebar">
        <div class="sidebar-label">Área Funcionário</div>
        <ul class="sidebar-nav">
            <li>
                <a href="funcDashboard.jsp" class="<%= "dashboard".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                    </svg>
                    <span>Dashboard</span>
                </a>
            </li>
            <li>
                <a href="funcEncomendas.jsp" class="<%= "encomendas".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                    </svg>
                    <span>Encomendas</span>
                </a>
            </li>
            <li>
                <a href="saldoClientes.jsp" class="<%= "saldo".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                    </svg>
                    <span>Saldo clientes</span>
                </a>
            </li>
            <li>
                <a href="auditoria.jsp" class="<%= "auditoria".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                    </svg>
                    <span>Auditoria</span>
                </a>
            </li>
            <div class="sidebar-divider"></div>
            <li>
                <a href="funcPerfil.jsp" class="<%= "perfil".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24">
                        <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                    </svg>
                    <span>Perfil</span>
                </a>
            </li>
        </ul>
    </aside>

    <!-- MAIN -->
    <main class="main-content">
        <h1 class="page-title">Dashboard</h1>

        <!-- STAT CARDS -->
        <div class="stat-grid">

            <!-- Pendentes -->
            <div class="stat-card alert-card">
                <div class="stat-top">
                    <div>
                        <div class="stat-label">Encomendas Pendentes</div>
                        <div class="stat-value"><%= encPendentes %>
                        </div>
                    </div>
                    <div class="stat-icon">
                        <svg viewBox="0 0 24 24">
                            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
                        </svg>
                    </div>
                </div>
                <div class="stat-sub">Aguardam validação</div>
            </div>

            <!-- Encomendas hoje -->
            <div class="stat-card">
                <div class="stat-top">
                    <div>
                        <div class="stat-label">Encomendas Hoje</div>
                        <div class="stat-value"><%= encHoje %>
                        </div>
                    </div>
                    <div class="stat-icon">
                        <svg viewBox="0 0 24 24">
                            <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                        </svg>
                    </div>
                </div>
                <div class="stat-sub">
                    <span class="warn"><%= encHojeCanceladas %> canceladas</span>
                    &nbsp;&middot;&nbsp;
                    <span class="hi"><%= encHojeConfirmadas %> confirmadas</span>
                </div>
            </div>

            <!-- Clientes registados -->
            <div class="stat-card">
                <div class="stat-top">
                    <div>
                        <div class="stat-label">Clientes Registados</div>
                        <div class="stat-value"><%= clientesRegistados %>
                        </div>
                    </div>
                    <div class="stat-icon">
                        <svg viewBox="0 0 24 24">
                            <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/>
                        </svg>
                    </div>
                </div>
                <div class="stat-sub"><span class="hi">Contas ativas</span></div>
            </div>

        </div><!-- end stat-grid -->

        <!-- BOTTOM ROW -->
        <div class="dash-row">

            <!-- ORDERS TABLE -->
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                        </svg>
                        Encomendas recentes
                    </div>
                    <a href="funcEncomendas.jsp" class="panel-link">Ver todas →</a>
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
                            String oid = o[0];
                            String ocli = o[1];
                            String odate = o[2];
                            String ototal = o[3];
                            String ostat = o[4];

                            String badgeClass = "badge-confirmada";
                            if ("pendente".equalsIgnoreCase(ostat) || "processando".equalsIgnoreCase(ostat)) badgeClass = "badge-pendente";
                            if ("cancelado".equalsIgnoreCase(ostat)) badgeClass = "badge-cancelada";

                            String[] parts = ocli.split(" ");
                            String initials = parts.length >= 2
                                    ? "" + parts[0].charAt(0) + parts[1].charAt(0)
                                    : "" + parts[0].charAt(0);
                    %>
                    <tr onclick="location.href='funcEncomendas.jsp?detalhe=<%= oid %>'">
                        <td class="order-id">#<%= oid %>
                        </td>
                        <td>
                            <div class="client-cell">
                                <div class="avatar-sm"><%= initials %>
                                </div>
                                <%= ocli %>
                            </div>
                        </td>
                        <td><%= odate %>
                        </td>
                        <td><strong><%= ototal %>
                        </strong></td>
                        <td><span class="badge <%= badgeClass %>"><%= ostat %></span></td>
                    </tr>
                    <% } %>
                    </tbody>
                </table>
            </div>

            <!-- WALLET FEED -->
            <div class="panel">
                <div class="panel-header">
                    <div class="panel-title">
                        <svg viewBox="0 0 24 24">
                            <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                        </svg>
                        Últimos movimentos de carteira
                    </div>
                </div>
                <ul class="feed-list">
                    <%
                        for (String[] m : walletFeed) {
                            String mtype = m[0];
                            String mref = m[1];
                            String mcli = m[2];
                            String mdate = m[3];
                            String mamount = m[4];

                            boolean isCredit = mamount.startsWith("+");
                            String iconClass = isCredit ? "credit" : "debit";

                            String desc = "";
                            if ("pagamento".equals(mtype)) desc = "Pagamento " + mref;
                            else if ("deposito".equals(mtype)) desc = "Depósito";
                            else if ("devolucao".equals(mtype)) desc = "Devolução " + mref;
                    %>
                    <li class="feed-item">
                        <div class="feed-icon <%= iconClass %>">
                            <% if ("deposito".equals(mtype)) { %>
                            <svg viewBox="0 0 24 24">
                                <path d="M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z"
                                      transform="rotate(180,12,12)"/>
                            </svg>
                            <% } else if ("devolucao".equals(mtype)) { %>
                            <svg viewBox="0 0 24 24">
                                <path d="M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/>
                            </svg>
                            <% } else { %>
                            <svg viewBox="0 0 24 24">
                                <path d="M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z"/>
                            </svg>
                            <% } %>
                        </div>
                        <div class="feed-info">
                            <div class="feed-desc"><%= desc %>
                            </div>
                            <div class="feed-meta">
                                <span class="client-name"><%= mcli %></span>
                                &nbsp;&middot;&nbsp;<%= mdate %>
                            </div>
                        </div>
                        <div class="feed-amount <%= iconClass %>"><%= mamount %>
                        </div>
                    </li>
                    <% } %>
                </ul>
                <div style="padding:10px 18px; border-top:1px solid #333; text-align:center;">
                    <a href="auditoria.jsp" class="panel-link">Ver auditoria completa →</a>
                </div>
            </div>

        </div><!-- end dash-row -->
    </main>
</div>

</body>
</html>
