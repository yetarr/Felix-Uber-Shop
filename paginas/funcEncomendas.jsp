<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    HttpSession sess = request.getSession(false);
    if (sess == null || sess.getAttribute("userId") == null
            || !"funcionario".equalsIgnoreCase((String) sess.getAttribute("userRole"))) {
        response.sendRedirect("login.jsp");
        return;
    }

    String funcName = (String) sess.getAttribute("userName");

    if ("POST".equalsIgnoreCase(request.getMethod()) && "validar".equals(request.getParameter("action"))) {
        String eid = request.getParameter("id");
        try {
            Connection _vc = getConnection();
            PreparedStatement _vps = _vc.prepareStatement(
                "UPDATE encomenda SET estado='pronto' WHERE id_encomenda=? AND estado='pendente'");
            _vps.setInt(1, Integer.parseInt(eid));
            int rows = _vps.executeUpdate();
            closeAll(null, _vps, _vc);
            sess.setAttribute("success", rows > 0 ? "Encomenda #" + eid + " confirmada com sucesso." : "Encomenda não encontrada ou já confirmada.");
        } catch (Exception _ve) {
            sess.setAttribute("errorMsg", "Erro: " + _ve.getMessage());
        }
        response.sendRedirect("funcEncomendas.jsp"); return;
    }

    if ("POST".equalsIgnoreCase(request.getMethod()) && "cancelar".equals(request.getParameter("action"))) {
        String eid = request.getParameter("id");
        try {
            Connection _vc = getConnection();
            PreparedStatement _vps = _vc.prepareStatement(
                "UPDATE encomenda SET estado='cancelado' WHERE id_encomenda=? AND estado IN ('pendente','processando','pronto')");
            _vps.setInt(1, Integer.parseInt(eid));
            int rows = _vps.executeUpdate();
            closeAll(null, _vps, _vc);
            sess.setAttribute("success", rows > 0 ? "Encomenda #" + eid + " cancelada." : "Encomenda não encontrada ou já cancelada.");
        } catch (Exception _ve) {
            sess.setAttribute("errorMsg", "Erro: " + _ve.getMessage());
        }
        response.sendRedirect("funcEncomendas.jsp"); return;
    }

    String filterCliente = request.getParameter("cliente") != null ? request.getParameter("cliente") : "";
    String filterEstado  = request.getParameter("estado")  != null ? request.getParameter("estado")  : "";
    String filterData    = request.getParameter("data")    != null ? request.getParameter("data")    : "2026-05-04";

    List<String[]> allOrders = new ArrayList<>();
    Map<String, String[][]> details = new LinkedHashMap<>();

    String successMsg = (String) sess.getAttribute("success"); if (successMsg != null) sess.removeAttribute("success");
    String errorMsg   = (String) sess.getAttribute("errorMsg"); if (errorMsg != null) sess.removeAttribute("errorMsg");

    String openDetail = request.getParameter("detalhe");

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        conn = getConnection();

        // Load all orders with optional filters
        String sql = "SELECT e.id_encomenda, u.nome, e.data_encomenda, e.total, e.estado " +
                     "FROM encomenda e JOIN utilizadores u ON u.id_utilizador = e.id_utilizador " +
                     "WHERE (u.nome LIKE ? OR ? = '') " +
                     "  AND (e.estado = ? OR ? = '') " +
                     "ORDER BY e.data_encomenda DESC";
        ps = conn.prepareStatement(sql);
        String likeCliente = filterCliente.isEmpty() ? "" : "%" + filterCliente + "%";
        ps.setString(1, likeCliente);
        ps.setString(2, filterCliente);
        ps.setString(3, filterEstado);
        ps.setString(4, filterEstado);
        rs = ps.executeQuery();
        while (rs.next()) {
            String id     = rs.getString("id_encomenda");
            String nome   = rs.getString("nome");
            String data   = rs.getString("data_encomenda");
            String total  = String.format("%.2f €", rs.getDouble("total")).replace(".", ",");
            String estado = rs.getString("estado");
            allOrders.add(new String[]{id, nome, data, total, estado});
        }
        closeAll(rs, ps, null);
        rs = null; ps = null;

        // Determine which order detail to open
        if (openDetail == null && !allOrders.isEmpty()) openDetail = allOrders.get(0)[0];

        // Load items for ALL orders
        if (!allOrders.isEmpty()) {
            String placeholders = String.join(",", Collections.nCopies(allOrders.size(), "?"));
            String sqlItems = "SELECT ep.id_encomenda, p.nome, ep.preco_unitario, ep.quantidade " +
                              "FROM encomenda_produto ep JOIN produtos p ON p.id_produto = ep.id_produto " +
                              "WHERE ep.id_encomenda IN (" + placeholders + ")";
            ps = conn.prepareStatement(sqlItems);
            for (int _i = 0; _i < allOrders.size(); _i++) {
                ps.setInt(_i + 1, Integer.parseInt(allOrders.get(_i)[0]));
            }
            rs = ps.executeQuery();
            Map<String, List<String[]>> tempDetails = new LinkedHashMap<>();
            while (rs.next()) {
                String eid         = rs.getString("id_encomenda");
                String nome        = rs.getString("nome");
                double preco       = rs.getDouble("preco_unitario");
                int    qty         = rs.getInt("quantidade");
                String fmtPreco    = String.format("%.2f €", preco).replace(".", ",");
                String fmtSubtotal = String.format("%.2f €", preco * qty).replace(".", ",");
                if (!tempDetails.containsKey(eid)) tempDetails.put(eid, new ArrayList<String[]>());
                tempDetails.get(eid).add(new String[]{nome, fmtPreco, String.valueOf(qty), fmtSubtotal});
            }
            closeAll(rs, ps, null);
            rs = null; ps = null;
            for (Map.Entry<String, List<String[]>> entry : tempDetails.entrySet()) {
                details.put(entry.getKey(), entry.getValue().toArray(new String[0][]));
            }
        }
    } catch (Exception e) {
        // Page renders with empty lists on error
    } finally {
        closeAll(rs, ps, conn);
    }

    String activePage = "encomendas";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Gestão de Encomendas</title>
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

        .page-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 18px;
        }

        .page-title {
            font-size: 1.3rem;
            font-weight: 700;
            color: #fff;
        }

        .alert {
            border-radius: 8px;
            padding: 11px 16px;
            font-size: .86rem;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .alert svg {
            width: 16px;
            height: 16px;
            flex-shrink: 0;
        }

        .alert-success {
            background: rgba(0, 206, 134, .1);
            border: 1px solid rgba(0, 206, 134, .3);
            color: #00CE86;
        }

        .alert-error {
            background: rgba(220, 60, 60, .1);
            border: 1px solid rgba(220, 60, 60, .3);
            color: #f08080;
        }

        .filters-bar {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            padding: 14px 18px;
            margin-bottom: 16px;
            display: flex;
            gap: 12px;
            align-items: center;
            flex-wrap: wrap;
        }

        .filter-group {
            display: flex;
            align-items: center;
            gap: 8px;
            flex: 1;
            min-width: 160px;
        }

        .filter-group .ico {
            color: #555;
            display: flex;
        }

        .filter-group .ico svg {
            width: 15px;
            height: 15px;
            fill: currentColor;
        }

        .filter-input, .filter-select, .filter-date {
            background: #1e1e1e;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            color: #ddd;
            font-size: .85rem;
            padding: 8px 12px;
            outline: none;
            transition: border-color .2s, box-shadow .2s;
            width: 100%;
        }

        .filter-input::placeholder {
            color: #4a4a4a;
        }

        .filter-input:focus, .filter-select:focus, .filter-date:focus {
            border-color: #00CE86;
            box-shadow: 0 0 0 3px rgba(0, 206, 134, .12);
        }

        .filter-select option {
            background: #1e1e1e;
        }

        .btn-filter {
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            padding: 8px 18px;
            font-size: .85rem;
            font-weight: 700;
            cursor: pointer;
            white-space: nowrap;
            transition: background .2s;
        }

        .btn-filter:hover {
            background: #00b876;
        }

        .btn-clear {
            background: none;
            border: 1px solid #444;
            color: #888;
            border-radius: 7px;
            padding: 8px 14px;
            font-size: .82rem;
            cursor: pointer;
            white-space: nowrap;
            text-decoration: none;
            transition: border-color .2s, color .2s;
        }

        .btn-clear:hover {
            border-color: #666;
            color: #ccc;
        }

        .panel {
            background: #2b2b2b;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
            margin-bottom: 16px;
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

        .results-count {
            font-size: .78rem;
            color: #666;
        }

        .orders-table {
            width: 100%;
            border-collapse: collapse;
        }

        .orders-table th {
            padding: 9px 16px;
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
            padding: 11px 16px;
            font-size: .86rem;
            color: #bbb;
            border-bottom: 1px solid #272727;
            vertical-align: middle;
        }

        .orders-table tr:last-child td {
            border-bottom: none;
        }

        .orders-table tr.active-row td {
            background: rgba(0, 206, 134, .035);
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
            background: #333;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            font-size: .7rem;
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

        .action-btns {
            display: flex;
            gap: 6px;
            flex-wrap: nowrap;
        }

        .btn-validar {
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 6px;
            padding: 5px 12px;
            font-size: .76rem;
            font-weight: 700;
            cursor: pointer;
            text-decoration: none;
            transition: background .2s;
        }

        .btn-validar:hover {
            background: #00b876;
        }

        .btn-editar {
            background: none;
            border: 1px solid #555;
            color: #bbb;
            border-radius: 6px;
            padding: 5px 12px;
            font-size: .76rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: border-color .2s, color .2s;
        }

        .btn-editar:hover {
            border-color: #00CE86;
            color: #00CE86;
        }

        .btn-cancelar {
            background: none;
            border: 1px solid #5a2a2a;
            color: #e07070;
            border-radius: 6px;
            padding: 5px 12px;
            font-size: .76rem;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: background .2s, border-color .2s;
        }

        .btn-cancelar:hover {
            background: rgba(220, 60, 60, .1);
            border-color: #e05555;
        }

        .btn-detalhe {
            background: none;
            border: 1px solid #3a3a3a;
            color: #777;
            border-radius: 6px;
            padding: 5px 12px;
            font-size: .76rem;
            font-weight: 600;
            cursor: pointer;
            transition: border-color .2s, color .2s;
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
            padding: 12px 18px;
            border-bottom: 1px solid #2e2e2e;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .detail-title {
            font-size: .87rem;
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

        .detail-actions {
            display: flex;
            gap: 8px;
            align-items: center;
        }

        .detail-close {
            background: none;
            border: none;
            color: #555;
            font-size: 1.1rem;
            cursor: pointer;
            transition: color .2s;
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
            padding: 9px 18px;
            font-size: .71rem;
            font-weight: 700;
            letter-spacing: .5px;
            text-transform: uppercase;
            color: #555;
            text-align: left;
            border-bottom: 1px solid #2e2e2e;
            background: #1e1e1e;
        }

        .detail-table td {
            padding: 11px 18px;
            font-size: .86rem;
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

        .detail-table th:last-child, .detail-table td:last-child {
            text-align: right;
        }

        .detail-table td:last-child {
            color: #e0e0e0;
            font-weight: 600;
        }

        .detail-total {
            display: flex;
            justify-content: flex-end;
            align-items: center;
            gap: 12px;
            padding: 12px 18px;
            border-top: 1px solid #333;
        }

        .detail-total .lbl {
            color: #777;
            font-weight: 700;
            font-size: .82rem;
            text-transform: uppercase;
            letter-spacing: .5px;
        }

        .detail-total .val {
            color: #00CE86;
            font-weight: 700;
            font-size: 1rem;
        }

        .empty-state {
            text-align: center;
            padding: 48px 20px;
            color: #555;
        }

        .empty-state svg {
            fill: #2e2e2e;
            width: 48px;
            height: 48px;
            margin-bottom: 14px;
        }

        @media (max-width: 680px) {
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

            .filters-bar {
                flex-direction: column;
            }

            .orders-table th:nth-child(3),
            .orders-table td:nth-child(3) {
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
            <li><a href="funcDashboard.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                </svg>
                <span>Dashboard</span></a></li>
            <li><a href="funcEncomendas.jsp" class="active">
                <svg viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                </svg>
                <span>Encomendas</span></a></li>
            <li><a href="saldoClientes.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                </svg>
                <span>Saldo clientes</span></a></li>
            <li><a href="auditoria.jsp">
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

    <!-- MAIN -->
    <main class="main-content">

        <div class="page-header">
            <h1 class="page-title">Gestão de encomendas</h1>
        </div>

        <!-- Alerts -->
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

        <!-- FILTERS BAR -->
        <form action="funcEncomendas.jsp" method="get">
            <div class="filters-bar">

                <!-- Search -->
                <div class="filter-group">
                    <span class="ico"><svg viewBox="0 0 24 24"><path
                            d="M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg></span>
                    <input type="text" name="cliente" class="filter-input"
                           placeholder="Pesquisar cliente..."
                           value="<%= filterCliente %>"/>
                </div>

                <!-- Status dropdown -->
                <div class="filter-group" style="flex:0 0 auto;min-width:170px;">
                    <span class="ico"><svg viewBox="0 0 24 24"><path d="M3 18h6v-2H3v2zM3 6v2h18V6H3zm0 7h12v-2H3v2z"/></svg></span>
                    <select name="estado" class="filter-select">
                        <option value=""            <%= "".equals(filterEstado)              ? "selected" : "" %>>Todos os estados</option>
                        <option value="pendente"    <%= "pendente".equals(filterEstado)    ? "selected" : "" %>>Pendente</option>
                        <option value="processando" <%= "processando".equals(filterEstado) ? "selected" : "" %>>Processando</option>
                        <option value="pronto"      <%= "pronto".equals(filterEstado)      ? "selected" : "" %>>Pronto</option>
                        <option value="cancelado"   <%= "cancelado".equals(filterEstado)   ? "selected" : "" %>>Cancelado</option>
                    </select>
                </div>

                <!-- Date -->
                <div class="filter-group" style="flex:0 0 auto;min-width:160px;">
                    <span class="ico"><svg viewBox="0 0 24 24"><path
                            d="M19 3h-1V1h-2v2H8V1H6v2H5C3.9 3 3 3.9 3 5v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V9h14v10zM5 7V5h14v2H5zm2 4h10v2H7zm0 4h7v2H7z"/></svg></span>
                    <input type="date" name="data" class="filter-date"
                           value="<%= filterData %>"/>
                </div>

                <button type="submit" class="btn-filter">Filtrar</button>
                <a href="funcEncomendas.jsp" class="btn-clear">Limpar</a>
            </div>
        </form>

        <!-- ORDERS TABLE -->
        <div class="panel">
            <div class="panel-header">
                <div class="panel-title">
                    <svg viewBox="0 0 24 24">
                        <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                    </svg>
                    Encomendas
                </div>
                <span class="results-count"><%= allOrders.size() %> resultado<%= allOrders.size() != 1 ? "s" : "" %></span>
            </div>

            <% if (allOrders.isEmpty()) { %>
            <div class="empty-state">
                <svg viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2z"/>
                </svg>
                <p>Nenhuma encomenda encontrada.</p>
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
                    for (String[] o : allOrders) {
                        String oid = o[0];
                        String ocli = o[1];
                        String odate = o[2];
                        String otot = o[3];
                        String ostat = o[4];

                        String badgeClass = "badge-confirmada";
                        if ("pendente".equalsIgnoreCase(ostat) || "processando".equalsIgnoreCase(ostat)) badgeClass = "badge-pendente";
                        if ("cancelado".equalsIgnoreCase(ostat)) badgeClass = "badge-cancelada";

                        boolean isPendente   = "pendente".equalsIgnoreCase(ostat) || "processando".equalsIgnoreCase(ostat);
                        boolean isConfirmada = "pronto".equalsIgnoreCase(ostat);
                        boolean isCancelada  = "cancelado".equalsIgnoreCase(ostat);
                        boolean isOpen = oid.equals(openDetail);

                        String[] parts = ocli.split(" ");
                        String initials = parts.length >= 2
                                ? "" + parts[0].charAt(0) + parts[parts.length - 1].charAt(0)
                                : "" + parts[0].charAt(0);
                %>
                <tr class="<%= isOpen ? "active-row" : "" %>"
                    onclick="toggleDetail('<%= oid %>')" style="cursor:pointer;">
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
                    <td><strong><%= otot %>
                    </strong></td>
                    <td><span class="badge <%= badgeClass %>"><%= ostat %></span></td>
                    <td onclick="event.stopPropagation()">
                        <div class="action-btns">
                            <button class="btn-detalhe <%= isOpen ? "open" : "" %>"
                                    id="btn-det-<%= oid %>"
                                    onclick="toggleDetail('<%= oid %>')">
                                &#9660;
                            </button>
                            <% if (isPendente) { %>
                            <form method="post" action="funcEncomendas.jsp" style="display:inline;margin:0"
                                  onsubmit="return confirm('Confirmar encomenda #<%= oid %>?')">
                                <input type="hidden" name="action" value="validar"/>
                                <input type="hidden" name="id" value="<%= oid %>"/>
                                <button type="submit" class="btn-validar">Validar</button>
                            </form>
                            <% } %>
                            <% if (!isCancelada) { %>
                            <a href="funcEditarEncomenda.jsp?id=<%= oid %>"
                               class="btn-editar">Editar</a>
                            <% } %>
                            <% if (isPendente || isConfirmada) { %>
                            <form method="post" action="funcEncomendas.jsp" style="display:inline;margin:0"
                                  onsubmit="return confirm('Cancelar encomenda #<%= oid %>?')">
                                <input type="hidden" name="action" value="cancelar"/>
                                <input type="hidden" name="id" value="<%= oid %>"/>
                                <button type="submit" class="btn-cancelar">Cancelar</button>
                            </form>
                            <% } %>
                        </div>
                    </td>
                </tr>
                <% } %>
                </tbody>
            </table>
            <% } %>
        </div>

        <!-- DETAIL PANELS -->
        <%
            for (String[] o : allOrders) {
                String oid = o[0];
                String ocli = o[1];
                String odate = o[2];
                String otot = o[3];
                String ostat = o[4];
                String[][] items = details.get(oid);
                boolean isOpen = oid.equals(openDetail);
                boolean isPend = "pendente".equalsIgnoreCase(ostat) || "processando".equalsIgnoreCase(ostat);
                boolean isConf = "pronto".equalsIgnoreCase(ostat);
        %>
        <div class="detail-panel <%= isOpen ? "visible" : "" %>" id="detail-<%= oid %>">
            <div class="detail-header">
                <div class="detail-title">
                    <svg viewBox="0 0 24 24">
                        <path d="M9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4zm2 2H5V5h14v14zm0-16H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2z"/>
                    </svg>
                    Detalhe &mdash; #<%= oid %> &middot; <%= ocli %> &middot; <%= odate %>
                    &middot; <span style="color:#00CE86;"><%= otot %></span>
                </div>
                <div class="detail-actions">
                    <% if (isPend) { %>
                    <form method="post" action="funcEncomendas.jsp" style="display:inline;margin:0"
                          onsubmit="return confirm('Confirmar encomenda #<%= oid %>?')">
                        <input type="hidden" name="action" value="validar"/>
                        <input type="hidden" name="id" value="<%= oid %>"/>
                        <button type="submit" class="btn-validar" style="font-size:.78rem;">✓ Validar</button>
                    </form>
                    <% } %>
                    <% if (!("Cancelada".equalsIgnoreCase(ostat))) { %>
                    <a href="funcEditarEncomenda.jsp?id=<%= oid %>"
                       class="btn-editar" style="font-size:.78rem;">Editar</a>
                    <% } %>
                    <% if (isPend || isConf) { %>
                    <form method="post" action="funcEncomendas.jsp" style="display:inline;margin:0"
                          onsubmit="return confirm('Cancelar encomenda #<%= oid %>?')">
                        <input type="hidden" name="action" value="cancelar"/>
                        <input type="hidden" name="id" value="<%= oid %>"/>
                        <button type="submit" class="btn-cancelar" style="font-size:.78rem;">Cancelar</button>
                    </form>
                    <% } %>
                    <button class="detail-close" onclick="closeDetail('<%= oid %>')" title="Fechar">&times;</button>
                </div>
            </div>

            <% if (items != null) { %>
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
                <span class="lbl">Total</span>
                <span class="val"><%= otot %></span>
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
            return;
        }
        if (currentOpen) closeDetail(currentOpen);
        openPanel(id);
    }

    function openPanel(id) {
        const panel = document.getElementById('detail-' + id);
        const btn = document.getElementById('btn-det-' + id);
        if (panel) {
            panel.classList.add('visible');
            panel.scrollIntoView({behavior: 'smooth', block: 'nearest'});
        }
        if (btn) btn.classList.add('open');
        currentOpen = id;
    }

    function closeDetail(id) {
        const panel = document.getElementById('detail-' + id);
        const btn = document.getElementById('btn-det-' + id);
        if (panel) panel.classList.remove('visible');
        if (btn) btn.classList.remove('open');
        if (currentOpen === id) currentOpen = '';
    }

    document.querySelector('input[name="cliente"]').addEventListener('input', function () {
        const q = this.value.toLowerCase();
        document.querySelectorAll('.orders-table tbody tr').forEach(row => {
            const name = row.querySelector('.client-cell') ? row.querySelector('.client-cell').textContent.toLowerCase() : '';
            row.style.display = name.includes(q) ? '' : 'none';
        });
    });
</script>

</body>
</html>
