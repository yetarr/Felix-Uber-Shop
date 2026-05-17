<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null) { response.sendRedirect("login.jsp"); return; }
    if (!"administrador".equals(sess.getAttribute("userRole"))) { response.sendRedirect("dashboard.jsp"); return; }
    String adminName = (String) sess.getAttribute("userName");
    String activePage = "auditoria";

    int statCarteira   = 0;
    int statUtilizador = 0;
    int statProduto    = 0;
    int statEncomenda  = 0;
    int statPromocao   = 0;
    List<String[]> logs = new ArrayList<>();

    Connection _conn8 = null;
    PreparedStatement _ps8 = null;
    ResultSet _rs8 = null;
    try {
        _conn8 = getConnection();

        // Stats
        _ps8 = _conn8.prepareStatement("SELECT COUNT(*) FROM auditoria_carteira");
        _rs8 = _ps8.executeQuery();
        if (_rs8.next()) statCarteira = _rs8.getInt(1);
        closeAll(_rs8, _ps8, null);

        _ps8 = _conn8.prepareStatement("SELECT COUNT(*) FROM auditoria WHERE categoria='Utilizador'");
        _rs8 = _ps8.executeQuery();
        if (_rs8.next()) statUtilizador = _rs8.getInt(1);
        closeAll(_rs8, _ps8, null);

        _ps8 = _conn8.prepareStatement("SELECT COUNT(*) FROM auditoria WHERE categoria='Produto'");
        _rs8 = _ps8.executeQuery();
        if (_rs8.next()) statProduto = _rs8.getInt(1);
        closeAll(_rs8, _ps8, null);

        _ps8 = _conn8.prepareStatement("SELECT COUNT(*) FROM auditoria WHERE categoria='Encomenda'");
        _rs8 = _ps8.executeQuery();
        if (_rs8.next()) statEncomenda = _rs8.getInt(1);
        closeAll(_rs8, _ps8, null);

        _ps8 = _conn8.prepareStatement("SELECT COUNT(*) FROM auditoria WHERE categoria='Promoção'");
        _rs8 = _ps8.executeQuery();
        if (_rs8.next()) statPromocao = _rs8.getInt(1);
        closeAll(_rs8, _ps8, null);

        // Query 1: wallet movements
        _ps8 = _conn8.prepareStatement(
            "SELECT ac.data_operacao, ac.tipo_operacao, COALESCE(u.nome,'') as uname, " +
            "COALESCE(ac.descricao,'') as det, ac.valor " +
            "FROM auditoria_carteira ac " +
            "JOIN carteira c ON c.id_carteira = ac.id_carteira_origem OR c.id_carteira = ac.id_carteira_destino " +
            "JOIN utilizadores u ON u.id_utilizador = c.id_utilizador AND c.is_loja = 0 " +
            "ORDER BY ac.data_operacao DESC LIMIT 50");
        _rs8 = _ps8.executeQuery();
        while (_rs8.next()) {
            String tipo  = _rs8.getString("tipo_operacao");
            double valor = _rs8.getDouble("valor");
            boolean isDebit = "pagamento".equals(tipo) || "levantamento".equals(tipo);
            String sign = isDebit ? "-" : "+";
            String valorFmt = sign + String.format("%.2f €", valor).replace(".", ",");
            logs.add(new String[]{
                String.valueOf(_rs8.getTimestamp("data_operacao")),
                "Carteira",
                tipo,
                _rs8.getString("uname"),
                _rs8.getString("det"),
                valorFmt
            });
        }
        closeAll(_rs8, _ps8, null);

        // Query 2: general audit events
        _ps8 = _conn8.prepareStatement(
            "SELECT a.data_evento, a.categoria, a.acao, " +
            "COALESCE(u.nome,'Sistema') as uname, COALESCE(a.descricao,'') as det " +
            "FROM auditoria a " +
            "LEFT JOIN utilizadores u ON u.id_utilizador = a.id_utilizador " +
            "ORDER BY a.data_evento DESC LIMIT 50");
        _rs8 = _ps8.executeQuery();
        while (_rs8.next()) {
            logs.add(new String[]{
                String.valueOf(_rs8.getTimestamp("data_evento")),
                _rs8.getString("categoria"),
                _rs8.getString("acao"),
                _rs8.getString("uname"),
                _rs8.getString("det"),
                ""
            });
        }
        closeAll(_rs8, _ps8, null);

        // Sort combined list by date descending
        java.util.Collections.sort(logs, new java.util.Comparator<String[]>() {
            public int compare(String[] a, String[] b) {
                return b[0].compareTo(a[0]);
            }
        });
    } catch (Exception _e8) {
        // page renders with empty/zero data on error
    } finally {
        closeAll(_rs8, _ps8, _conn8);
    }

    String filterCat = request.getParameter("categoria") != null ? request.getParameter("categoria") : "";
    String filterDe  = request.getParameter("de")        != null ? request.getParameter("de")        : "";
    String filterAte = request.getParameter("ate")       != null ? request.getParameter("ate")       : "";
    String sortBy    = request.getParameter("sort")      != null ? request.getParameter("sort")      : "data";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>auditoriaAdmin</title>
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            background-color: #212121;
            color: #e0e0e0;
            font-family: 'Segoe UI', Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        /* ── TOPNAV ──────────────────────────────────────── */
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

        .nav-brand { font-size: 1.2rem; font-weight: 700; color: #00CE86; text-decoration: none; letter-spacing: .4px; }
        .nav-right  { display: flex; align-items: center; gap: 18px; }

        .nav-role {
            font-size: .68rem; font-weight: 700; letter-spacing: .6px;
            background: rgba(0,206,134,.12); color: #00CE86;
            border: 1px solid rgba(0,206,134,.25); padding: 2px 8px;
            border-radius: 20px; text-transform: uppercase;
        }

        .nav-user { display: flex; align-items: center; gap: 8px; font-size: .87rem; color: #bbb; }
        .nav-user svg { fill: #00CE86; width: 20px; height: 20px; }

        .btn-sair {
            background: none; border: 1px solid #555; color: #aaa;
            font-size: .8rem; padding: 5px 14px; border-radius: 6px;
            cursor: pointer; text-decoration: none; transition: border-color .2s, color .2s;
        }
        .btn-sair:hover { border-color: #e05555; color: #e05555; }

        .app-shell { display: flex; flex: 1; min-height: 0; }

        /* ── SIDEBAR ─────────────────────────────────────── */
        .sidebar {
            width: 215px; flex-shrink: 0; background: #111;
            border-right: 1px solid #1e1e1e;
            display: flex; flex-direction: column; padding: 24px 0 16px;
        }

        .sidebar-label {
            font-size: .67rem; font-weight: 700; letter-spacing: 1.2px;
            color: #3a3a3a; text-transform: uppercase; padding: 0 20px 14px;
        }

        .sidebar-nav { list-style: none; flex: 1; }

        .sidebar-nav li a {
            display: flex; align-items: center; gap: 11px;
            padding: 11px 20px; text-decoration: none;
            font-size: .88rem; color: #777;
            border-left: 3px solid transparent;
            transition: background .15s, color .15s, border-color .15s;
        }
        .sidebar-nav li a:hover { background: rgba(255,255,255,.04); color: #ddd; }
        .sidebar-nav li a.active {
            border-left-color: #00CE86; background: rgba(0,206,134,.07);
            color: #00CE86; font-weight: 600;
        }
        .sidebar-nav li a svg { width: 17px; height: 17px; fill: currentColor; flex-shrink: 0; }

        .sidebar-divider { height: 1px; background: #1e1e1e; margin: 10px 20px; }

        /* ── MAIN ────────────────────────────────────────── */
        .main-content { flex: 1; padding: 22px 24px 48px; overflow-y: auto; min-width: 0; }

        /* ── STATS ROW ───────────────────────────────────── */
        .stats-row {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 12px;
            margin-bottom: 20px;
        }

        .stat-card {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 14px 18px;
            text-align: center;
        }

        .stat-num {
            font-size: 1.6rem;
            font-weight: 800;
            line-height: 1.1;
        }

        .stat-label {
            font-size: .75rem;
            color: #666;
            margin-top: 4px;
        }

        .color-carteira   { color: #60a5fa; }
        .color-utilizador { color: #a78bfa; }
        .color-produto    { color: #fb923c; }
        .color-encomenda  { color: #4ade80; }
        .color-promocao   { color: #fbbf24; }

        /* ── AUDIT PANEL ─────────────────────────────────── */
        .audit-panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .audit-header {
            padding: 13px 18px;
            border-bottom: 1px solid #333;
        }

        .audit-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .audit-title svg { fill: #00CE86; width: 16px; height: 16px; }

        /* Filter bar */
        .filter-bar {
            padding: 11px 16px;
            border-bottom: 1px solid #2e2e2e;
            display: flex;
            gap: 8px;
            align-items: center;
            flex-wrap: wrap;
        }

        .search-wrap {
            flex: 1;
            min-width: 160px;
            position: relative;
        }

        .search-wrap svg {
            position: absolute; left: 10px; top: 50%; transform: translateY(-50%);
            fill: #555; width: 13px; height: 13px;
        }

        .search-input {
            width: 100%; background: #1e1e1e; border: 1px solid #3a3a3a;
            border-radius: 7px; color: #ddd; font-size: .84rem;
            padding: 7px 10px 7px 30px; outline: none; transition: border-color .2s;
        }
        .search-input::placeholder { color: #4a4a4a; }
        .search-input:focus { border-color: #00CE86; }

        .filter-select {
            background: #1e1e1e; border: 1px solid #3a3a3a; border-radius: 7px;
            color: #ddd; font-size: .84rem; padding: 7px 10px;
            outline: none; cursor: pointer; transition: border-color .2s;
        }
        .filter-select:focus { border-color: #00CE86; }
        .filter-select option { background: #1e1e1e; }

        .filter-date {
            background: #1e1e1e; border: 1px solid #3a3a3a; border-radius: 7px;
            color: #ddd; font-size: .84rem; padding: 7px 10px;
            outline: none; cursor: pointer; transition: border-color .2s;
            color-scheme: dark;
        }
        .filter-date:focus { border-color: #00CE86; }

        .sort-btns { display: flex; gap: 6px; }

        .btn-sort {
            background: none; border: 1px solid #3a3a3a; color: #888;
            border-radius: 7px; padding: 7px 12px; font-size: .82rem; font-weight: 600;
            cursor: pointer; white-space: nowrap; transition: border-color .2s, color .2s, background .2s;
        }
        .btn-sort:hover { border-color: #555; color: #bbb; }
        .btn-sort.active {
            border-color: #00CE86; color: #00CE86;
            background: rgba(0,206,134,.08);
        }

        /* Audit table */
        .audit-table { width: 100%; border-collapse: collapse; }

        .audit-table th {
            padding: 9px 14px; font-size: .71rem; font-weight: 700;
            letter-spacing: .6px; text-transform: uppercase; color: #555;
            text-align: left; border-bottom: 1px solid #333; background: #252525;
        }

        .audit-table td {
            padding: 10px 14px; font-size: .85rem; color: #bbb;
            border-bottom: 1px solid #272727; vertical-align: middle;
        }

        .audit-table tr:last-child td { border-bottom: none; }
        .audit-table tr:hover td { background: rgba(255,255,255,.02); }

        .col-data { color: #777; font-size: .82rem; white-space: nowrap; }
        .col-acao { color: #ccc; }
        .col-user { color: #aaa; }
        .col-detalhe { color: #888; font-size: .83rem; }

        .valor-neg  { color: #e05555; font-weight: 600; white-space: nowrap; }
        .valor-pos  { color: #00CE86; font-weight: 600; white-space: nowrap; }
        .valor-neu  { color: #ccc; font-weight: 600; white-space: nowrap; }
        .valor-dash { color: #3a3a3a; }

        /* Category badges */
        .cat-badge {
            display: inline-block; padding: 2px 9px; border-radius: 20px;
            font-size: .72rem; font-weight: 700; white-space: nowrap;
        }

        .cat-carteira   { background: rgba(96,165,250,.13); color: #60a5fa; border: 1px solid rgba(96,165,250,.25); }
        .cat-utilizador { background: rgba(167,139,250,.13); color: #a78bfa; border: 1px solid rgba(167,139,250,.25); }
        .cat-produto    { background: rgba(251,146,60,.13);  color: #fb923c; border: 1px solid rgba(251,146,60,.25); }
        .cat-encomenda  { background: rgba(74,222,128,.12);  color: #4ade80; border: 1px solid rgba(74,222,128,.25); }
        .cat-promocao   { background: rgba(251,191,36,.12);  color: #fbbf24; border: 1px solid rgba(251,191,36,.25); }

        /* Responsive */
        @media (max-width: 900px) {
            .stats-row { grid-template-columns: repeat(3, 1fr); }
        }

        @media (max-width: 580px) {
            .sidebar { width: 56px; }
            .sidebar-label, .sidebar-nav li a span { display: none; }
            .sidebar-nav li a { padding: 13px; justify-content: center; }
            .main-content { padding: 14px; }
            .stats-row { grid-template-columns: repeat(2, 1fr); }
            .audit-table th:nth-child(4), .audit-table td:nth-child(4),
            .audit-table th:nth-child(5), .audit-table td:nth-child(5) { display: none; }
        }
    </style>
</head>
<body>

<!-- TOP NAV -->
<nav class="topnav">
    <a href="index.jsp" class="nav-brand">FelixUberShop</a>
    <div class="nav-right">
        <span class="nav-role">Administrador</span>
        <div class="nav-user">
            <svg viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= adminName %></strong>
        </div>
        <a href="login.jsp" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">

    <!-- SIDEBAR -->
    <aside class="sidebar">
        <div class="sidebar-label">Área Admin</div>
        <ul class="sidebar-nav">
            <li>
                <a href="adminDashboard.jsp" class="<%= "dashboard".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/></svg>
                    <span>Dashboard</span>
                </a>
            </li>
            <li>
                <a href="encomendasAdmin.jsp" class="<%= "encomendas".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/></svg>
                    <span>Encomendas</span>
                </a>
            </li>
            <li>
                <a href="saldoClientesAdmin.jsp" class="<%= "saldo".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/></svg>
                    <span>Saldo clientes</span>
                </a>
            </li>
            <li>
                <a href="produtosAdmin.jsp" class="<%= "produtos".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-5 12H9v-2h6v2zm2-4H7V8h10v2z"/></svg>
                    <span>Produtos</span>
                </a>
            </li>
            <li>
                <a href="utilizadoresAdmin.jsp" class="<%= "utilizadores".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z"/></svg>
                    <span>Utilizadores</span>
                </a>
            </li>
            <li>
                <a href="promocoesAdmin.jsp" class="<%= "promocoes".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M21.41 11.58l-9-9C12.05 2.22 11.55 2 11 2H4c-1.1 0-2 .9-2 2v7c0 .55.22 1.05.59 1.42l9 9c.36.36.86.58 1.41.58.55 0 1.05-.22 1.41-.59l7-7c.37-.36.59-.86.59-1.41 0-.55-.23-1.06-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/></svg>
                    <span>Promoções</span>
                </a>
            </li>
            <li>
                <a href="auditoriaAdmin.jsp" class="<%= "auditoria".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/></svg>
                    <span>Auditoria</span>
                </a>
            </li>
            <div class="sidebar-divider"></div>
            <li>
                <%-- TODO: criar perfilAdmin.jsp --%>
                <a href="perfilAdmin.jsp" class="<%= "perfil".equals(activePage) ? "active" : "" %>">
                    <svg viewBox="0 0 24 24"><path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/></svg>
                    <span>Perfil</span>
                </a>
            </li>
        </ul>
    </aside>

    <!-- MAIN -->
    <main class="main-content">

        <!-- STATS -->
        <div class="stats-row">
            <div class="stat-card">
                <div class="stat-num color-carteira"><%= statCarteira %></div>
                <div class="stat-label">Carteira</div>
            </div>
            <div class="stat-card">
                <div class="stat-num color-utilizador"><%= statUtilizador %></div>
                <div class="stat-label">Utilizadores</div>
            </div>
            <div class="stat-card">
                <div class="stat-num color-produto"><%= statProduto %></div>
                <div class="stat-label">Produtos</div>
            </div>
            <div class="stat-card">
                <div class="stat-num color-encomenda"><%= statEncomenda %></div>
                <div class="stat-label">Encomendas</div>
            </div>
            <div class="stat-card">
                <div class="stat-num color-promocao"><%= statPromocao %></div>
                <div class="stat-label">Promoções</div>
            </div>
        </div>

        <!-- AUDIT LOG -->
        <div class="audit-panel">
            <div class="audit-header">
                <div class="audit-title">
                    <svg viewBox="0 0 24 24"><path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/></svg>
                    Auditoria geral da loja
                </div>
            </div>

            <!-- Filters -->
            <div class="filter-bar">
                <div class="search-wrap">
                    <svg viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
                    <input type="text" id="searchInput" class="search-input"
                           placeholder="Pesquisar..." oninput="filterTable()"/>
                </div>
                <select id="filterCat" class="filter-select" onchange="filterTable()">
                    <option value="">Todas as categorias</option>
                    <option value="Carteira">Carteira</option>
                    <option value="Utilizador">Utilizador</option>
                    <option value="Produto">Produto</option>
                    <option value="Encomenda">Encomenda</option>
                    <option value="Promoção">Promoção</option>
                </select>
                <input type="date" id="filterDe"  class="filter-date" value="<%= filterDe  %>" onchange="filterTable()"/>
                <input type="date" id="filterAte" class="filter-date" value="<%= filterAte %>" onchange="filterTable()"/>
                <div class="sort-btns">
                    <button class="btn-sort active" id="btnSortData"  onclick="setSort('data')">&#8593; Data</button>
                    <button class="btn-sort"        id="btnSortValor" onclick="setSort('valor')">&#8595; Valor</button>
                </div>
            </div>

            <!-- Table -->
            <table class="audit-table" id="auditTable">
                <thead>
                <tr>
                    <th>Data</th>
                    <th>Categoria</th>
                    <th>Ação</th>
                    <th>Utilizador</th>
                    <th>Detalhe</th>
                    <th>Valor</th>
                </tr>
                </thead>
                <tbody>
                <%
                    for (String[] log : logs) {
                        String lData    = log[0];
                        String lCat     = log[1];
                        String lAcao    = log[2];
                        String lUser    = log[3];
                        String lDetalhe = log[4];
                        String lValor   = log[5];

                        // Badge CSS class
                        String badgeClass = "cat-carteira";
                        if      ("Utilizador".equals(lCat)) badgeClass = "cat-utilizador";
                        else if ("Produto".equals(lCat))    badgeClass = "cat-produto";
                        else if ("Encomenda".equals(lCat))  badgeClass = "cat-encomenda";
                        else if ("Promoção".equals(lCat))   badgeClass = "cat-promocao";

                        // Valor CSS class
                        String valorClass = "valor-dash";
                        String valorDisplay = "&mdash;";
                        if (!lValor.isEmpty()) {
                            valorDisplay = lValor;
                            if (lValor.startsWith("-"))      valorClass = "valor-neg";
                            else if (lValor.startsWith("+")) valorClass = "valor-pos";
                            else                             valorClass = "valor-neu";
                        }

                        // data-valor for sort (strip symbols, use 0 if dash)
                        String valorNum = "0";
                        if (!lValor.isEmpty()) {
                            valorNum = lValor.replaceAll("[^0-9,\\-\\+]","").replace(",",".");
                        }
                %>
                <tr data-cat="<%= lCat %>"
                    data-data="<%= lData %>"
                    data-texto="<%= (lAcao + " " + lUser + " " + lDetalhe).toLowerCase() %>"
                    data-valor="<%= valorNum %>">
                    <td class="col-data"><%= lData %></td>
                    <td><span class="cat-badge <%= badgeClass %>"><%= lCat %></span></td>
                    <td class="col-acao"><%= lAcao %></td>
                    <td class="col-user"><%= lUser %></td>
                    <td class="col-detalhe"><%= lDetalhe %></td>
                    <td class="<%= valorClass %>"><%= valorDisplay %></td>
                </tr>
                <% } %>
                </tbody>
            </table>
        </div>

    </main>
</div>

<script>
    var currentSort = 'data';

    function filterTable() {
        var q      = document.getElementById('searchInput').value.toLowerCase();
        var cat    = document.getElementById('filterCat').value;
        var rows   = document.querySelectorAll('#auditTable tbody tr');

        rows.forEach(function(row) {
            var texto = row.dataset.texto || '';
            var rcat  = row.dataset.cat   || '';
            var matchQ   = !q   || texto.includes(q);
            var matchCat = !cat || rcat === cat;
            row.style.display = (matchQ && matchCat) ? '' : 'none';
        });
    }

    function setSort(field) {
        currentSort = field;
        document.getElementById('btnSortData').classList.toggle('active',  field === 'data');
        document.getElementById('btnSortValor').classList.toggle('active', field === 'valor');

        var tbody = document.querySelector('#auditTable tbody');
        var rows  = Array.from(tbody.querySelectorAll('tr'));

        rows.sort(function(a, b) {
            if (field === 'data') {
                return b.dataset.data.localeCompare(a.dataset.data);
            } else {
                return parseFloat(b.dataset.valor || 0) - parseFloat(a.dataset.valor || 0);
            }
        });

        rows.forEach(function(row) { tbody.appendChild(row); });
    }
</script>

</body>
</html>

