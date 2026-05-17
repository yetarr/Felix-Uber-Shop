<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*" %>
<%@ page import="java.sql.*" %>
<%@ include file="../basedados/basedados.h" %>
<%
    // Verificacao da sessao
    if (session.getAttribute("userId") == null) {
        response.sendRedirect("login.jsp");
        return;
    }
    String clienteName = (String) session.getAttribute("userName");
    int userId = (Integer) session.getAttribute("userId");
    String orderId = request.getParameter("id") != null ? request.getParameter("id") : "0";
    int orderIdInt = 0;
    try { orderIdInt = Integer.parseInt(orderId); } catch (Exception _ex) {}

    String successMsg = (String) session.getAttribute("success");
    if (successMsg != null) session.removeAttribute("success");
    String errorMsg = null;

    // Processar atualizacao dos itens da encomenda
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        Connection uConn = null;
        PreparedStatement uPs = null;
        ResultSet uRs = null;
        try {
            int oid = Integer.parseInt(request.getParameter("orderId"));
            uConn = getConnection();
            uConn.setAutoCommit(false);

            uPs = uConn.prepareStatement(
                "SELECT estado FROM encomenda WHERE id_encomenda = ? AND id_utilizador = ?");
            uPs.setInt(1, oid); uPs.setInt(2, userId);
            uRs = uPs.executeQuery();
            if (!uRs.next()) {
                uConn.rollback();
                errorMsg = "Encomenda não encontrada.";
            } else if (!"pendente".equals(uRs.getString("estado"))) {
                uConn.rollback();
                errorMsg = "Só é possível editar encomendas pendentes.";
            } else {
                closeAll(uRs, uPs, null);

                uPs = uConn.prepareStatement("SELECT saldo FROM carteira WHERE id_utilizador = ?");
                uPs.setInt(1, userId);
                uRs = uPs.executeQuery();
                double saldoActual = uRs.next() ? uRs.getDouble("saldo") : 0;
                closeAll(uRs, uPs, null);

                uPs = uConn.prepareStatement("DELETE FROM encomenda_produto WHERE id_encomenda = ?");
                uPs.setInt(1, oid);
                uPs.executeUpdate();
                closeAll(null, uPs, null);

                double total = 0;
                int itemsCount = 0;
                for (java.util.Enumeration<String> params = request.getParameterNames(); params.hasMoreElements();) {
                    String param = params.nextElement();
                    if (!param.startsWith("produto_")) continue;
                    int pid;
                    int qty;
                    try {
                        pid = Integer.parseInt(param.substring("produto_".length()));
                        qty = Integer.parseInt(request.getParameter(param));
                    } catch (NumberFormatException nfe) { continue; }
                    if (qty <= 0) continue;

                    uPs = uConn.prepareStatement(
                        "SELECT p.preco, COALESCE(MAX(pr.desconto_percentagem),0) AS desc_pct " +
                        "FROM produtos p " +
                        "LEFT JOIN promocao_produto pp ON pp.id_produto = p.id_produto " +
                        "LEFT JOIN promocoes pr ON pr.id_promocao = pp.id_promocao " +
                        "  AND pr.ativo = 1 AND CURDATE() BETWEEN pr.data_inicio AND pr.data_fim " +
                        "WHERE p.id_produto = ? AND p.ativo = 1 " +
                        "GROUP BY p.id_produto, p.preco");
                    uPs.setInt(1, pid);
                    uRs = uPs.executeQuery();
                    if (!uRs.next()) { closeAll(uRs, uPs, null); continue; }
                    double preco = uRs.getDouble("preco");
                    double desc = uRs.getDouble("desc_pct");
                    double precoFinal = Math.round(preco * (100.0 - desc)) / 100.0;
                    closeAll(uRs, uPs, null);

                    uPs = uConn.prepareStatement(
                        "INSERT INTO encomenda_produto (id_encomenda, id_produto, quantidade, preco_unitario) " +
                        "VALUES (?, ?, ?, ?)");
                    uPs.setInt(1, oid);
                    uPs.setInt(2, pid);
                    uPs.setInt(3, qty);
                    uPs.setDouble(4, precoFinal);
                    uPs.executeUpdate();
                    closeAll(null, uPs, null);

                    total += precoFinal * qty;
                    itemsCount++;
                }

                if (itemsCount == 0) {
                    uConn.rollback();
                    errorMsg = "A encomenda deve conter pelo menos um produto.";
                } else if (total > saldoActual) {
                    uConn.rollback();
                    errorMsg = "Saldo insuficiente para concluir a encomenda.";
                } else {
                    uPs = uConn.prepareStatement("UPDATE encomenda SET total = ? WHERE id_encomenda = ?");
                    uPs.setDouble(1, total);
                    uPs.setInt(2, oid);
                    uPs.executeUpdate();
                    closeAll(null, uPs, null);

                    uConn.commit();
                    session.setAttribute("success", "Encomenda atualizada com sucesso.");
                    response.sendRedirect("editarEncomenda.jsp?id=" + oid);
                    return;
                }
            }
        } catch (Exception e) {
            errorMsg = "Erro: " + e.getMessage();
            if (uConn != null) try { uConn.rollback(); } catch (SQLException ignored) {}
        } finally {
            if (uConn != null) try { uConn.setAutoCommit(true); } catch (SQLException ignored) {}
            closeAll(uRs, uPs, uConn);
        }
    }

    String saldoCliente = "0,00";
    List<Object[]> catalogue = new ArrayList<>();
    String orderEstado = "";
    boolean orderFound = false;

    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        conn = getConnection();

        // Verificar estado da encomenda
        ps = conn.prepareStatement(
            "SELECT estado FROM encomenda WHERE id_encomenda = ? AND id_utilizador = ?");
        ps.setInt(1, orderIdInt);
        ps.setInt(2, userId);
        rs = ps.executeQuery();
        if (rs.next()) {
            orderFound = true;
            orderEstado = rs.getString("estado");
        }
        closeAll(rs, ps, null);

        // Obter saldo do cliente
        ps = conn.prepareStatement("SELECT saldo FROM carteira WHERE id_utilizador = ?");
        ps.setInt(1, userId);
        rs = ps.executeQuery();
        if (rs.next()) {
            saldoCliente = String.format("%.2f", rs.getDouble("saldo")).replace(".", ",");
        }
        closeAll(rs, ps, null);

        // Carregar catalogo de produtos disponiveis com descontos
        ps = conn.prepareStatement(
            "SELECT p.id_produto, p.nome, p.categoria, " +
            "CAST(p.preco*100 AS SIGNED) AS preco_orig_cents, " +
            "COALESCE(MAX(pr.desconto_percentagem),0) AS desc_pct, " +
            "COALESCE(ep.quantidade,0) AS qty_atual " +
            "FROM produtos p " +
            "LEFT JOIN promocao_produto pp ON pp.id_produto = p.id_produto " +
            "LEFT JOIN promocoes pr ON pr.id_promocao = pp.id_promocao " +
            "  AND pr.ativo = 1 AND CURDATE() BETWEEN pr.data_inicio AND pr.data_fim " +
            "LEFT JOIN encomenda_produto ep ON ep.id_produto = p.id_produto AND ep.id_encomenda = ? " +
            "WHERE p.ativo = 1 " +
            "GROUP BY p.id_produto, p.nome, p.categoria, p.preco, ep.quantidade " +
            "ORDER BY p.nome");
        ps.setInt(1, orderIdInt);
        rs = ps.executeQuery();
        while (rs.next()) {
            int priceOrig = (int) rs.getLong("preco_orig_cents");
            int discPct = (int) Math.round(rs.getDouble("desc_pct"));
            int priceFinal = discPct > 0
                ? (int) Math.round(priceOrig * (100.0 - discPct) / 100.0)
                : priceOrig;
            catalogue.add(new Object[]{
                String.valueOf(rs.getInt("id_produto")),
                rs.getString("nome"),
                rs.getString("categoria") != null ? rs.getString("categoria") : "",
                priceFinal,
                discPct,
                rs.getInt("qty_atual"),
                priceOrig
            });
        }
    } catch (Exception e) {
        // Catalogo fica vazio em caso de erro
    } finally {
        closeAll(rs, ps, conn);
    }

    boolean isEditable = orderFound && "pendente".equals(orderEstado);
    String activePage = "encomendas";
%>
<!DOCTYPE html>
<html lang="pt">
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>FelixUberShop – Editar Encomenda #<%= orderId %></title>
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
            width: 210px;
            flex-shrink: 0;
            background: #111;
            border-right: 1px solid #222;
            display: flex;
            flex-direction: column;
            padding: 24px 0 16px;
        }

        .sidebar-label {
            font-size: .68rem;
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
            font-size: .88rem;
            color: #888;
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

        .main-content {
            flex: 1;
            padding: 24px 24px 48px;
            overflow-y: auto;
            min-width: 0;
        }

        .breadcrumb {
            font-size: .8rem;
            color: #666;
            margin-bottom: 6px;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .breadcrumb a {
            color: #555;
            text-decoration: none;
        }

        .breadcrumb a:hover {
            color: #00CE86;
        }

        .breadcrumb svg {
            width: 12px;
            height: 12px;
            fill: #444;
        }

        .page-title {
            font-size: 1.3rem;
            font-weight: 700;
            color: #fff;
            margin-bottom: 20px;
        }

        .page-title span {
            color: #00CE86;
        }

        .alert {
            border-radius: 8px;
            padding: 11px 16px;
            font-size: .86rem;
            margin-bottom: 18px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .alert-error {
            background: rgba(220, 60, 60, .1);
            border: 1px solid rgba(220, 60, 60, .3);
            color: #f08080;
        }

        .alert-success {
            background: rgba(0, 206, 134, .1);
            border: 1px solid rgba(0, 206, 134, .3);
            color: #00CE86;
        }

        .alert-warn {
            background: rgba(245, 166, 35, .08);
            border: 1px solid rgba(245, 166, 35, .25);
            color: #f5a623;
        }

        .editor-grid {
            display: grid;
            grid-template-columns: 1fr 280px;
            gap: 18px;
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
            gap: 8px;
        }

        .panel-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .panel-icon {
            fill: #00CE86;
            width: 16px;
            height: 16px;
        }

        .product-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
            gap: 12px;
            padding: 16px;
            max-height: 460px;
            overflow-y: auto;
        }

        .product-grid::-webkit-scrollbar {
            width: 10px;
        }

        .product-grid::-webkit-scrollbar-track {
            background: #1e1e1e;
        }

        .product-grid::-webkit-scrollbar-thumb {
            background: #3a3a3a;
            border-radius: 6px;
        }

        .product-grid::-webkit-scrollbar-thumb:hover {
            background: #555;
        }

        .product-card {
            background: #1e1e1e;
            border: 2px solid #333;
            border-radius: 10px;
            padding: 14px 12px 12px;
            display: flex;
            flex-direction: column;
            align-items: center;
            gap: 5px;
            position: relative;
            transition: border-color .2s, box-shadow .2s;
        }

        .product-card.has-qty {
            border-color: #00CE86;
            box-shadow: 0 0 0 1px rgba(0, 206, 134, .2);
            background: rgba(0, 206, 134, .03);
        }

        .product-img {
            width: 64px;
            height: 64px;
            background: #2a2a2a;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 4px;
            color: #555;
            font-size: .7rem;
            gap: 4px;
        }

        .product-img svg {
            fill: #555;
            width: 16px;
            height: 16px;
        }

        .disc-badge {
            position: absolute;
            top: 8px;
            right: 8px;
            background: rgba(0, 206, 134, .15);
            border: 1px solid rgba(0, 206, 134, .3);
            color: #00CE86;
            font-size: .65rem;
            font-weight: 700;
            padding: 2px 6px;
            border-radius: 20px;
        }

        .product-name {
            font-size: .85rem;
            font-weight: 600;
            color: #ddd;
            text-align: center;
            line-height: 1.2;
        }

        .product-price-row {
            display: flex;
            align-items: baseline;
            gap: 6px;
        }

        .product-price {
            font-size: .95rem;
            font-weight: 700;
            color: #fff;
        }

        .product-price-orig {
            font-size: .75rem;
            color: #777;
            text-decoration: line-through;
        }

        .stepper {
            display: flex;
            align-items: center;
            background: #2a2a2a;
            border: 1px solid #3a3a3a;
            border-radius: 7px;
            overflow: hidden;
            margin-top: 4px;
        }

        .stepper button {
            width: 30px;
            height: 30px;
            background: none;
            border: none;
            color: #aaa;
            font-size: 1.1rem;
            font-weight: 700;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: background .15s, color .15s;
            flex-shrink: 0;
        }

        .stepper button:hover:not(:disabled) {
            background: #3a3a3a;
            color: #00CE86;
        }

        .stepper button:disabled {
            color: #444;
            cursor: not-allowed;
        }

        .stepper .qty-val {
            min-width: 32px;
            text-align: center;
            font-size: .9rem;
            font-weight: 700;
            color: #fff;
            border-left: 1px solid #3a3a3a;
            border-right: 1px solid #3a3a3a;
            padding: 0 4px;
            line-height: 30px;
        }

        .right-col {
            display: flex;
            flex-direction: column;
            gap: 14px;
        }

        .summary-panel {
            background: #262626;
            border: 1px solid #333;
            border-radius: 10px;
            overflow: hidden;
        }

        .summary-header {
            padding: 13px 16px;
            border-bottom: 1px solid #333;
        }

        .summary-title {
            font-size: .9rem;
            font-weight: 700;
            color: #e8e8e8;
        }

        .saldo-row {
            padding: 9px 16px;
            border-bottom: 1px solid #2e2e2e;
            display: flex;
            justify-content: space-between;
            font-size: .82rem;
            color: #777;
        }

        .saldo-row strong {
            color: #00CE86;
        }

        .order-items {
            min-height: 44px;
            max-height: 220px;
            overflow-y: auto;
        }

        .order-item {
            padding: 10px 16px;
            border-bottom: 1px solid #2a2a2a;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: .84rem;
        }

        .order-item .iname {
            color: #ccc;
        }

        .order-item .iqty {
            color: #777;
            font-size: .78rem;
            margin-left: 4px;
        }

        .order-item .iprice {
            color: #e0e0e0;
            font-weight: 600;
            flex-shrink: 0;
        }

        .empty-cart {
            padding: 20px 16px;
            text-align: center;
            font-size: .82rem;
            color: #555;
        }

        .total-row {
            padding: 12px 16px;
            border-top: 1px solid #333;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .total-label {
            font-size: .78rem;
            color: #888;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: .5px;
        }

        .total-value {
            font-size: 1.1rem;
            font-weight: 700;
            color: #00CE86;
        }

        .saldo-warn {
            padding: 8px 16px;
            font-size: .78rem;
            color: #f5a623;
            background: rgba(245, 166, 35, .08);
            border-top: 1px solid rgba(245, 166, 35, .2);
            display: none;
        }

        .action-btns {
            padding: 12px 16px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }

        .btn-confirmar {
            width: 100%;
            padding: 11px;
            background: #00CE86;
            color: #111;
            border: none;
            border-radius: 7px;
            font-size: .92rem;
            font-weight: 700;
            cursor: pointer;
            transition: background .2s, transform .1s;
        }

        .btn-confirmar:hover:not(:disabled) {
            background: #00b876;
        }

        .btn-confirmar:active:not(:disabled) {
            transform: scale(.98);
        }

        .btn-confirmar:disabled {
            background: #2a4a3a;
            color: #555;
            cursor: not-allowed;
        }

        .btn-cancelar-lnk {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 5px;
            color: #777;
            text-decoration: none;
            font-size: .84rem;
            padding: 6px;
            border-radius: 6px;
            transition: color .2s;
        }

        .btn-cancelar-lnk:hover {
            color: #e05555;
        }

        .btn-cancelar-lnk svg {
            fill: currentColor;
            width: 13px;
            height: 13px;
        }

        .promos-panel {
            background: #262626;
            border: 1px solid #2e2e2e;
            border-radius: 10px;
            overflow: hidden;
        }

        .promos-header {
            padding: 11px 16px;
            border-bottom: 1px solid #2e2e2e;
        }

        .promos-title {
            font-size: .82rem;
            font-weight: 700;
            color: #aaa;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .promos-title svg {
            fill: #00CE86;
            width: 14px;
            height: 14px;
        }

        .promo-list {
            list-style: none;
        }

        .promo-item {
            padding: 9px 16px;
            border-bottom: 1px solid #272727;
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: .82rem;
        }

        .promo-item:last-child {
            border-bottom: none;
        }

        .promo-item .pname {
            color: #bbb;
        }

        .promo-item .pbadge {
            background: rgba(0, 206, 134, .12);
            color: #00CE86;
            border: 1px solid rgba(0, 206, 134, .25);
            font-size: .7rem;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 20px;
        }

        .promo-empty {
            padding: 14px 16px;
            text-align: center;
            font-size: .78rem;
            color: #555;
        }

        @media (max-width: 750px) {
            .editor-grid {
                grid-template-columns: 1fr;
            }

            .right-col {
                flex-direction: row;
                flex-wrap: wrap;
            }

            .summary-panel, .promos-panel {
                flex: 1;
                min-width: 240px;
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

            .product-grid {
                grid-template-columns: repeat(2, 1fr);
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
            Olá, <strong style="color:#e0e0e0;margin-left:4px;"><%= clienteName %></strong>
        </div>
        <a href="logout.jsp" class="btn-sair">Sair</a>
    </div>
</nav>

<div class="app-shell">
    <aside class="sidebar">
        <div class="sidebar-label">Área Cliente</div>
        <ul class="sidebar-nav">
            <li><a href="dashboard.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z"/>
                </svg>
                <span>Dashboard</span></a></li>
            <li><a href="perfil.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z"/>
                </svg>
                <span>Perfil</span></a></li>
            <li><a href="carteira.jsp">
                <svg viewBox="0 0 24 24">
                    <path d="M21 7H3c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V9c0-1.1-.9-2-2-2zm-1 12H4V9h16v10zm-5-5a2 2 0 1 1 4 0 2 2 0 0 1-4 0zM3 5h16V3H3z"/>
                </svg>
                <span>Carteira</span></a></li>
            <li><a href="encomendas.jsp" class="active">
                <svg viewBox="0 0 24 24">
                    <path d="M20 6h-2.18A3 3 0 0 0 15 4H9a3 3 0 0 0-2.82 2H4c-1.1 0-2 .9-2 2v11c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-11 0h6c.55 0 1 .45 1 1s-.45 1-1 1H9c-.55 0-1-.45-1-1s.45-1 1-1zM8 13h8v1.5H8V13zm0 3h5v1.5H8V16z"/>
                </svg>
                <span>Encomendas</span></a></li>
        </ul>
    </aside>

    <main class="main-content">
        <div class="breadcrumb">
            <a href="encomendas.jsp">Encomendas</a>
            <svg viewBox="0 0 24 24">
                <path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6-6-6z"/>
            </svg>
            Editar encomenda #<%= orderId %>
        </div>

        <h1 class="page-title">Editar encomenda <span>#<%= orderId %></span></h1>

        <% if (successMsg != null && !successMsg.isEmpty()) { %>
        <div class="alert alert-success">
            <svg viewBox="0 0 24 24" width="17" height="17" fill="#00CE86">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 14l-4-4 1.41-1.41L10 13.17l6.59-6.59L18 8l-8 8z"/>
            </svg>
            <%= successMsg %>
        </div>
        <% } %>
        <% if (errorMsg != null && !errorMsg.isEmpty()) { %>
        <div class="alert alert-error">
            <svg viewBox="0 0 24 24" width="17" height="17" fill="#f08080">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
            </svg>
            <%= errorMsg %>
        </div>
        <% } %>
        <% if (!orderFound) { %>
        <div class="alert alert-error">
            <svg viewBox="0 0 24 24" width="17" height="17" fill="#f08080">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
            </svg>
            Encomenda não encontrada ou não pertence a este cliente.
        </div>
        <% } else if (!isEditable) { %>
        <div class="alert alert-warn">
            <svg viewBox="0 0 24 24" width="17" height="17" fill="#f5a623">
                <path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/>
            </svg>
            Esta encomenda está no estado &laquo;<%= orderEstado %>&raquo; e já não pode ser editada.
        </div>
        <% } %>

        <div class="editor-grid">

            <div class="panel">
                <div class="panel-header">
                    <svg class="panel-icon" viewBox="0 0 24 24">
                        <path d="M7 18c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm10 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zM7.17 14l.03-.12.9-1.88H17c.75 0 1.41-.41 1.75-1.03l3.86-7.01A1 1 0 0 0 21.75 2H5.21l-.94-2H1v2h2l3.6 7.59L5.25 11C4.52 11.37 4 12.13 4 13c0 1.1.9 2 2 2h12v-2H7.42c-.13 0-.25-.11-.25-.25z"/>
                    </svg>
                    <span class="panel-title">Escolher produtos</span>
                </div>

                <div class="product-grid">
                    <%
                        for (Object[] p : catalogue) {
                            String pid = (String) p[0];
                            String pname = (String) p[1];
                            String pqlbl = (String) p[2];
                            int price = (Integer) p[3];
                            int disc = (Integer) p[4];
                            int curQty = (Integer) p[5];
                            int priceOrig = (Integer) p[6];
                            String priceStr = String.format("%d,%02d €", price / 100, price % 100);
                            String priceOrigStr = String.format("%d,%02d €", priceOrig / 100, priceOrig % 100);
                            String fullName = pname + (!pqlbl.isEmpty() ? " " + pqlbl : "");
                            String safeName = fullName.replace("'", "\\'");
                            String disabledAttr = isEditable ? "" : "disabled";
                    %>
                    <div class="product-card <%= curQty > 0 ? "has-qty" : "" %>" id="card-<%= pid %>">
                        <% if (disc > 0) { %><span class="disc-badge">-<%= disc %>%</span><% } %>
                        <div class="product-img">
                            <svg viewBox="0 0 24 24">
                                <path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/>
                            </svg>
                            <span>foto</span>
                        </div>
                        <div class="product-name"><%= pname %></div>
                        <div class="product-price-row">
                            <span class="product-price"><%= priceStr %></span>
                            <% if (disc > 0) { %>
                            <span class="product-price-orig"><%= priceOrigStr %></span>
                            <% } %>
                        </div>
                        <div class="stepper">
                            <button type="button" <%= disabledAttr %>
                                    onclick="changeQty('<%= pid %>',-1,<%= price %>,'<%= safeName %>')">&#8722;</button>
                            <span class="qty-val" id="qty-<%= pid %>"><%= curQty %></span>
                            <button type="button" <%= disabledAttr %>
                                    onclick="changeQty('<%= pid %>',1,<%= price %>,'<%= safeName %>')">&#43;</button>
                        </div>
                    </div>
                    <% } %>
                    <% if (catalogue.isEmpty()) { %>
                    <div class="empty-cart" style="grid-column:1/-1;">Sem produtos disponíveis.</div>
                    <% } %>
                </div>
            </div>

            <div class="right-col">

                <div class="summary-panel">
                    <div class="summary-header">
                        <div class="summary-title">Resumo</div>
                    </div>
                    <div class="saldo-row">
                        <span>Saldo do cliente</span>
                        <strong><%= saldoCliente %> €</strong>
                    </div>
                    <div class="order-items" id="orderItems"></div>
                    <div class="total-row">
                        <span class="total-label">Total</span>
                        <span class="total-value" id="totalValue">0,00 €</span>
                    </div>
                    <div class="saldo-warn" id="saldoWarn">⚠ Saldo insuficiente.</div>
                    <div class="action-btns">
                        <form id="orderForm" action="editarEncomenda.jsp" method="post"
                              onsubmit="return prepareSubmit()">
                            <input type="hidden" name="orderId" value="<%= orderId %>"/>
                            <div id="hiddenInputs"></div>
                            <button type="submit" class="btn-confirmar" id="btnConfirmar" <%= isEditable ? "" : "disabled" %>>
                                Confirmar encomenda
                            </button>
                        </form>
                        <a href="encomendas.jsp" class="btn-cancelar-lnk">
                            <svg viewBox="0 0 24 24">
                                <path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/>
                            </svg>
                            Cancelar
                        </a>
                    </div>
                </div>

                <div class="promos-panel">
                    <div class="promos-header">
                        <div class="promos-title">
                            <svg viewBox="0 0 24 24">
                                <path d="M21.41 11.58l-9-9A2 2 0 0 0 11 2H4a2 2 0 0 0-2 2v7c0 .53.21 1.04.59 1.42l9 9A2 2 0 0 0 13 22a2 2 0 0 0 1.41-.59l7-7A2 2 0 0 0 22 13a2 2 0 0 0-.59-1.42zM5.5 7C4.67 7 4 6.33 4 5.5S4.67 4 5.5 4 7 4.67 7 5.5 6.33 7 5.5 7z"/>
                            </svg>
                            Promoções ativas
                        </div>
                    </div>
                    <%
                        boolean anyPromo = false;
                        for (Object[] p : catalogue) {
                            if ((Integer) p[4] > 0) { anyPromo = true; break; }
                        }
                    %>
                    <% if (!anyPromo) { %>
                    <div class="promo-empty">Sem promoções ativas no momento.</div>
                    <% } else { %>
                    <ul class="promo-list">
                        <%
                            for (Object[] p : catalogue) {
                                int disc = (Integer) p[4];
                                if (disc > 0) {
                                    String pn = (String) p[1];
                        %>
                        <li class="promo-item">
                            <span class="pname"><%= pn %></span>
                            <span class="pbadge">-<%= disc %>%</span>
                        </li>
                        <% }
                        } %>
                    </ul>
                    <% } %>
                </div>

            </div>
        </div>
    </main>
</div>

<script>
    const saldo = <%= saldoCliente.replace(",", ".") %>;
    const editable = <%= isEditable %>;
    const cart = {};

    <% for (Object[] p : catalogue) {
           String pid  = (String)  p[0];
           String pn   = (String)  p[1];
           String ql   = (String)  p[2];
           int price   = (Integer) p[3];
           int curQty  = (Integer) p[5];
           if (curQty > 0) {
               String safe = (pn + (!ql.isEmpty() ? " "+ql : "")).replace("'", "\\'");
    %>
    cart['<%= pid %>'] = {name: '<%= safe %>', price: <%= price %>, qty: <%= curQty %>};
    <% }} %>

    function fmt(cents) {
        return (cents / 100).toFixed(2).replace('.', ',') + ' €';
    }

    function changeQty(pid, delta, price, name) {
        if (!editable) return;
        const el = document.getElementById('qty-' + pid);
        const card = document.getElementById('card-' + pid);
        let qty = parseInt(el.textContent) + delta;
        if (qty < 0) qty = 0;
        el.textContent = qty;
        if (qty > 0) {
            cart[pid] = {name, price, qty};
            card.classList.add('has-qty');
        } else {
            delete cart[pid];
            card.classList.remove('has-qty');
        }
        render();
    }

    function render() {
        const items = Object.entries(cart);
        const box = document.getElementById('orderItems');
        const btn = document.getElementById('btnConfirmar');

        if (!items.length) {
            box.innerHTML = '<div class="empty-cart">Nenhum produto selecionado.</div>';
            document.getElementById('totalValue').textContent = '0,00 €';
            if (editable) btn.disabled = true;
            document.getElementById('saldoWarn').style.display = 'none';
            return;
        }

        let total = 0, html = '';
        items.forEach(([, item]) => {
            const sub = item.price * item.qty;
            total += sub;
            html += '<div class="order-item">' +
                    '<span><span class="iname">' + item.name + '</span>' +
                    '<span class="iqty">× ' + item.qty + '</span></span>' +
                    '<span class="iprice">' + fmt(sub) + '</span>' +
                    '</div>';
        });
        box.innerHTML = html;
        document.getElementById('totalValue').textContent = fmt(total);

        const insuf = total > Math.round(saldo * 100);
        document.getElementById('saldoWarn').style.display = insuf ? 'block' : 'none';
        if (editable) btn.disabled = insuf;
    }

    function prepareSubmit() {
        if (!editable) return false;
        const hi = document.getElementById('hiddenInputs');
        hi.innerHTML = '';
        const entries = Object.entries(cart);
        if (!entries.length) return false;
        entries.forEach(([pid, item]) => {
            hi.innerHTML += '<input type="hidden" name="produto_' + pid + '" value="' + item.qty + '"/>';
        });
        return true;
    }

    render();
</script>
</body>
</html>
